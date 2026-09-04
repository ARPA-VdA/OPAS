# Scrivere un driver con l'SDK

[driver-contract.md](driver-contract.md) è il contratto completo, indipendente
dall'SDK, che un `driver.py` deve rispettare. Questo documento è una
spiegazione schematica di `opas_dl_commons/libs/driver_sdk.py` — lo strato
opzionale di comodità che implementa quel contratto — per chi vuole
costruire un nuovo driver appoggiandosi ad esso invece di scrivere a mano il
loop grezzo. Viene usato
[`API_400/driver.py`](../../src/opas_dl_commons/drivers/API_400/driver.py)
come esempio pratico lungo tutto il documento.

## 1. I due elementi fondamentali

`driver_sdk.py` esporta esattamente due cose necessarie:

| Nome | Cos'è |
|---|---|
| `BaseDriver` | Una classe base da estendere. Vanno sovrascritti i suoi metodi di I/O; da sola non fa nulla. |
| `run_driver(MyDriver)` | Una funzione che istanzia la classe e gestisce: loop di polling, logging, gestione dei segnali, scrittura dell'output, riporto del valore mancante quando lo strumento è irraggiungibile. |

`driver.py` ha bisogno di una sola riga per avviare tutto:
`driver_sdk.run_driver(MyDriver)` dentro
`if __name__ == "__main__":`.

## 2. `BaseDriver`: cosa sovrascrivere

| Metodo | Obbligatorio? | Chiamato | Scopo |
|---|---|---|---|
| `connect(self)` | opzionale (default: no-op) | una volta, prima che il loop di polling parta | apre la connessione allo strumento |
| `disconnect(self)` | opzionale (default: no-op) | una volta, quando il loop termina (anche allo shutdown) | chiude la connessione |
| `read_channel(self, channel_config)` | almeno uno tra questi due | una volta per canale attivo, ogni ciclo | restituisce il valore di quel canale (o solleva un'eccezione) |
| `read_all_channels(self, channels)` | almeno uno tra questi due | una volta per ciclo, con la config di ogni canale attivo | restituisce `{nome_canale: valore, ...}` per tutti insieme |

Note che contano nella pratica:

- **Va sovrascritto almeno uno** tra `read_channel`/`read_all_channels`.
  `run_driver()` lo controlla all'avvio (confrontando il metodo collegato
  della sottoclasse con quello proprio di `BaseDriver` — vedere
  `_overrides()` nel sorgente) e solleva subito `RuntimeError`, prima di
  qualsiasi I/O, se nessuno dei due è sovrascritto.
- **Se vengono sovrascritti entrambi, vince `read_all_channels`** — viene
  controllato per primo e decide `batch_mode` per tutta la durata
  dell'esecuzione.
- **L'isolamento dei fallimenti è diverso tra i due.** In modalità per-canale,
  un'eccezione da `read_channel()` per un canale rende mancante solo la
  lettura di *quel* canale in questo ciclo — gli altri canali non ne
  risentono. In modalità batch, un'eccezione da `read_all_channels()` perde
  *l'intero* ciclo: ogni canale viene riportato come mancante, perché i
  singoli canali non possono essere isolati a posteriori da un'unica
  chiamata batch fallita.
- **Nessuna riconnessione automatica.** Se `connect()` solleva un'eccezione,
  il driver continua a girare per il resto della vita del processo riportando
  valori mancanti a ogni ciclo (vedere punto 7 più sotto) — non
  riprova mai più `connect()`. Un driver che vuole una logica di retry deve
  implementarla da sé, tipicamente in modo lazy dentro
  `read_channel()`/`read_all_channels()`.

## 3. Cosa fa `run_driver()`, passo per passo

Questa è la parte che implementa
[driver-contract.md](driver-contract.md). Nell'ordine del sorgente:

1. **Risolve `instrument_id`/`module_config`.** Li legge dalle variabili
   d'ambiente `INSTRUMENT_ID`/`MODULE_CONFIG` a meno che non vengano passati
   esplicitamente (passarli esplicitamente è ciò che rende il loop testabile
   senza un vero sottoprocesso).
2. **Configura logging e gestione dei segnali** —
   `common.configure_driver_logging()` e `common.setup_signal_handlers()`,
   entrambe prima che qualsiasi altra cosa venga eseguita.
3. **Valida la sottoclasse** come descritto nella sezione 2, e decide
   `batch_mode`.
4. **Istanzia la classe driver** con `(module_config, instrument_id)`.
5. **Calcola `active_channels`** (solo le voci di `Channels` con
   `"Active": true`) e `polling_interval` (da `PollingInterval`, default `1`
   secondo se assente o non valido).
6. **Crea l'output writer** tramite `output_manager.create_output_writer()` —
   lo stesso helper descritto in driver-contract.md §5.1(a). È quello che
   scriverà davvero i file OPAS NEO più avanti nel loop.
7. **Chiama `connect()` una volta.** Se solleva un'eccezione, `connected`
   resta `False` per il resto dell'esecuzione (vedere la nota "nessuna
   riconnessione automatica" sopra).
8. **Il loop di polling**, finché `common.should_run()` è `True`:
   - Legge i valori: una chiamata a `read_all_channels()` in modalità batch,
     oppure una chiamata a `read_channel()` per ogni canale attivo altrimenti
     (ognuna avvolta nel proprio try/except — vedere la nota sull'isolamento
     dei fallimenti sopra).
   - Per ogni canale attivo: risolve il suo `DatabaseId` (registrando un
     warning una tantum e usando `0` come fallback se manca), sceglie il
     valore (la lettura reale se connesso, `None` altrimenti), e scrive una
     `Reading` sull'output writer — questo *è* il contratto dei file di
     output della sezione 5 di driver-contract.md, gestito automaticamente.
   - `common.graceful_sleep(polling_interval)` — dorme a piccoli incrementi
     così un segnale di shutdown viene notato rapidamente invece di bloccare
     per l'intero intervallo.
9. **All'uscita** (`finally`): chiama `disconnect()`, poi
   `output_writer.close()` — ognuno avvolto separatamente così un fallimento
   nell'uno non impedisce l'esecuzione dell'altro.

## 4. Esempio pratico: `API_400/driver.py`

Questo driver (analizzatore di O3 Teledyne API 400) sovrascrive `connect`,
`read_channel` e `disconnect` — non `read_all_channels`, quindi gira in
modalità per-canale.

- **Importare l'SDK**: dato che i driver vivono nella propria cartella
  invece che come pacchetto installato, il file carica `driver_sdk.py` per
  percorso file tramite
  `importlib.util.spec_from_file_location(...)` invece di un normale
  `import driver_sdk`. Questo è boilerplate copiabile parola per parola in
  un nuovo driver — solo il percorso relativo
  (`"..", "..", "libs", "driver_sdk.py"`) deve restare corretto in base a
  dove si trova la cartella driver.
- **`connect()`** chiama `comm_manager.create_channel(self.module_config)`,
  che legge `ComunicationType` dalla config del modulo e restituisce un
  canale seriale oppure TCP/IP — il codice del driver stesso non fa mai un
  branch su quale dei due ha ricevuto.
- **`read_channel()`** costruisce un comando `"T <NomeCanale>"`, lo invia,
  riceve la risposta, ed estrae il valore o tramite la `RegularExpression`
  propria del canale (`parse_response()`, un piccolo wrapper di
  `re.search()` che restituisce il primo gruppo catturato), oppure, se non è
  configurato nessun pattern, il testo grezzo della risposta con i fine riga
  collassati in spazi.
- **`disconnect()`** si limita a chiudere il canale.
- **`if __name__ == "__main__": driver_sdk.run_driver(API400Driver)`** è
  l'unica riga che avvia tutto ciò che è descritto nella sezione 3.

## 5. Scheletro minimo per un nuovo driver

```python
import importlib.util, os

_SDK = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "libs", "driver_sdk.py"
))
_spec = importlib.util.spec_from_file_location("driver_sdk", _SDK)
driver_sdk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(driver_sdk)


class MyDriver(driver_sdk.BaseDriver):
    def connect(self):
        ...  # aprire la connessione, es. tramite driver_sdk.comm_manager.create_channel(self.module_config)

    def read_channel(self, channel_config):
        ...  # interrogare lo strumento per questo singolo canale, restituire un valore o None

    def disconnect(self):
        ...  # chiudere la connessione


if __name__ == "__main__":
    driver_sdk.run_driver(MyDriver)
```

## Vedere anche

- [driver-contract.md](driver-contract.md) — il contratto completo,
  indipendente dall'uso di questo SDK.
- [architecture.md](architecture.md) — dove si inserisce un processo driver
  nel resto del servizio (output broker, modello dei processi, sequenza di
  avvio).
