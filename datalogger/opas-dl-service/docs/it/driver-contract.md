# Drivers

Questo documento è l'intero contratto tra un processo driver e il resto del
servizio OPAS NEO.

Usare l'SDK opzionale descritto nella sezione 6 non è mai obbligatorio. Si
può scrivere un `driver.py` da zero, con zero import da questa codebase,
purché rispetti le sezioni 2–5.

## 1. Cos'è un driver

Un driver è un singolo file Python, `driver.py`, che interroga uno strumento
("modulo" nella config della stazione) a intervalli e ne riporta le letture.
Esiste un **processo** driver per ogni istanza di modulo configurata — se
una stazione ha due strumenti identici, due processi separati eseguono
`driver.py`, ognuno con il proprio ambiente (sezione 3).

## 2. Come viene invocato `driver.py`

Il servizio avvia il file più o meno come:

```python
runpy.run_path("driver.py", run_name="__main__")
```

In pratica è equivalente a eseguire `python driver.py` da riga di comando:

- Il codice a livello di modulo viene eseguito dall'alto in basso
  immediatamente.
- `__name__ == "__main__"` è `True`, quindi il blocco
  `if __name__ == "__main__":` viene eseguito.
- **Non c'è `sys.argv`** — non viene passato nulla come argomento da riga di
  comando.
- **stdout/stderr non vengono catturati** dal servizio. Qualsiasi cosa venga
  stampata con `print()` va persa o si mescola in una console condivisa, a
  seconda di come è stato avviato il servizio stesso. **Serve configurare un
  logging su file proprio** per avere dei log (oppure si usa
  `common.configure_driver_logging()` / l'SDK, che lo fa automaticamente —
  vedere sezione 6).

## 3. Le variabili d'ambiente ricevute

| Variabile | Significato |
|---|---|
| `INSTRUMENT_ID` | Identificatore stringa stabile per questa istanza di modulo (es. il suo `ID` o `Name` configurato). |
| `DRIVER_LOG` | Percorso file assoluto su cui scrivere i log, in caso di logging proprio. |
| `MODULE_CONFIG` | Oggetto codificato in JSON che descrive **solo questo modulo** — mai l'intera config della stazione, mai altri moduli. |

Nient'altro viene iniettato nel processo. Nessuna connessione al
database, nessun handle di rete, nessuna memoria condivisa — solo queste tre
variabili d'ambiente.

### Reference dei campi di `MODULE_CONFIG`

```jsonc
{
  "ID": 1,
  "Name": "API 400",
  "ModuleType": "400",
  "Active": true,
  "PollingInterval": 10,                 // secondi tra un ciclo di polling e l'altro
  "LogLevel": "INFO",                    // risolto (valore proprio, o il default di stazione) da driver_manager prima del lancio — vedere sezione 3.2 — solo SDK
  "ComunicationType": 1,                 // 0=Seriale, 1=Ethernet TCP/IP, 3=PipeFile, 4=Ethernet UDP, 5=Modbus Seriale, 6=Modbus Ethernet, 7=HTTP — rilevante solo se si usa comm_manager.create_channel() o si gestisce direttamente il trasporto. Il 7 (HTTP) NON fa parte dell'EnumModuleComunicationType originale di VB.NET (0/1/3/4/5/6) - aggiunto in cima per i driver che parlano HTTP (es. CAMPBELL/CR1000/driver.py) così da poter passare anch'essi da comm_manager invece di costruirsi le richieste da soli. Il vecchio "2" generico (Modbus, seriale-vs-ethernet auto-rilevato) viene migrato a 5/6 da service_master all'avvio prima di diventare mai visibile — vedere comm_manager.normalize_comunication_type().
  "TCPIPAddress": "192.168.1.10",
  "TCPIPPort": 3000,
  "ComPortName": 6,
  "ComPortBauds": 115200,
  "PipeFileName": "",                    // percorso del file in cui lo strumento (o il suo software di acquisizione) scrive le letture - solo ComunicationType 3
  "PipeFileMissingError": true,          // se un file pipe mancante va loggato come warning (true) o a livello debug (false)
  "Channels": [
    {
      "ID": 1,
      "Name": "O3",
      "DatabaseId": 53,                  // -> il campo "ID" nei file di output, vedere sezione 5
      "Address": "PHOTOMEAS",            // specifico dello strumento, il significato è definito dal driver (Modbus: indirizzo registro)
      "RegularExpression": "...",        // specifico dello strumento, il significato è definito dal driver
      "RegisterFunctionCode": 4,         // solo Modbus: 1=Coils, 2=DiscreteInputs, 3=HoldingRegisters, 4=InputRegisters
      "RegisterType": 0,                 // solo Modbus: 0=Float (2 registri), 1=Integer (1 registro/bit)
      "RegisterQuantity": 2,             // solo Modbus: numero di registri da leggere
      "RegisterOrder": 1,                // solo Modbus, solo Float: 0=LowHigh, 1=HighLow ordine delle word
      "Active": true,
      "MeanInterval": 3600,              // secondi per bucket di media oraria, vedere sezione 5.3 — solo SDK
      "ReadingsMinPercentage": 75,        // % di copertura sotto la quale il P.COD orario ottiene il bit 128 — solo SDK
      "DetectionLimit": null,            // -> P.COD 512/1024 nella media oraria — solo SDK
      "AllowedMinValue": null,           // -> P.COD 2048 nella media oraria se una lettura istantanea è sotto — solo SDK
      "AllowedMaxValue": null,           // -> P.COD 4096 nella media oraria se una lettura istantanea è sopra — solo SDK
      "NegativeValueSetToZero": false,   // azzera una lettura negativa prima che venga usata ovunque — solo SDK
      "Decimals": 1,                     // arrotonda VAL (e, nella media oraria, VAL/MIN/MAX/STDDEV) — solo SDK
      "Algorithm": 0,                    // quale aggregazione produce il VAL della media oraria — vedere 5.3.1 — solo SDK
      "Formule": "y=x"                   // trasforma la lettura grezza prima che chiunque altro la veda — vedere 3.1 — solo SDK
    }
  ]
}
```

Vengono interrogati solo i canali con `"Active": true`. `DatabaseId` è ciò che
deve finire nella colonna `ID` dei file di output (sezione 5) — non è lo
stesso valore dell'`ID` proprio del canale. Gli ultimi nove campi sopra
contano solo se si usa `run_driver()` dell'SDK (sezione 6) — legge questi
valori dallo stesso dict per calcolare le medie orarie della sezione 5.3 (e,
per `Formule`, per trasformare la lettura stessa — vedere 3.1); un driver
scritto da zero (sezione 7) che scrive da sé i file di output è libero di
ignorarli.

Uno strumento irraggiungibile deve sempre essere riportato come valore
mancante (P.COD 128) — questa codebase non ha alcun concetto di un driver
che fabbrica una lettura plausibile per riempire il vuoto.

### 3.1 `Formule`: trasformare la lettura grezza prima che chiunque altro la veda

`Channel["Formule"]` trasforma la lettura grezza dello strumento (`x`) nella
misura reale (`y`) — es. un driver che legge millivolt ma la stazione vuole
volt usa `"y=x/1000"`. Se si usa l'SDK, questo viene applicato subito dopo
che `read_channel()`/`read_all_channels()` restituisce un valore e *prima*
che venga costruito un `Reading` — quindi il valore trasformato è quello che
`Decimals` arrotonda, quello che `Algorithm` aggrega (sezione 5.3.1), e
quello che finisce in ogni file di output. `output_manager`/`output_broker`
non vedono mai il valore grezzo.

Viene riconosciuta solo la forma `"y=<espr>"`; qualunque altra cosa
(mancante, vuota, che non inizia con `y=`) significa "nessuna
trasformazione" e la lettura grezza viene usata invariata — questo include
l'identità `"y=x"`, il valore di gran lunga più comune nelle config
esistenti. `<espr>` è una piccola espressione aritmetica sulla singola
variabile `x`:

- Operatori: `+ - * / // % **`, unario `+`/`-`, parentesi.
- Funzioni: `abs`, `min`, `max`, `round`, `sqrt`.
- Solo letterali numerici. Nient'altro - niente accesso ad attributi,
  subscript, comprehension, altri nomi o altre chiamate a funzione.

Questo è implementato in `opas_dl_commons/libs/formula.py` come un walker
AST scritto a mano (`opas_dl_commons.libs.formula.parse_formula`), **mai**
`eval()`/`exec()`: l'albero dell'espressione parsata viene controllato nodo
per nodo contro una whitelist esplicita prima di essere mai valutato, quindi
una stringa `Formule` che non è un'espressione aritmetica supportata viene
respinta apertamente invece di eseguire silenziosamente Python arbitrario.

Gestione degli errori, entrambe loggate una volta per canale (non una volta
per ciclo di polling):
- Una stringa `Formule` che non riesce a essere parsata (sintassi errata, o
  un nodo/funzione non in whitelist) viene trattata come se fosse assente —
  la lettura grezza viene usata invariata per quel canale per il resto
  dell'esecuzione del driver.
- Una stringa `Formule` che viene parsata ma fallisce nella *valutazione*
  per una lettura specifica (es. `"y=1/x"` quando `x` è `0`) fa sì che
  quella singola lettura venga riportata come mancante (P.COD 128), non che
  il driver vada in crash.

`Channel["DataFormule"]` è un campo di config distinto e attualmente non
utilizzato — sempre `null` in ogni config nota, nessun significato
consolidato, non implementato dall'SDK.

`Channel["Formule"]` è interamente a carico di chi scrive i file OPAS NEO
direttamente (sezione 5.1, opzione b) — non riguarda quel caso.

### 3.2 `LogLevel`: verbosità di log a due livelli

`Module["LogLevel"]` controlla la verbosità del log di quel modulo
(`driver_{id}.log`) — uno tra `DEBUG`/`INFO`/`WARNING`/`ERROR`. Ci sono due
livelli: un default a livello di stazione (`Config["LogLevel"]`, impostabile
dalla pagina Impostazioni dell'UI Electron, o via `GET`/`POST /logging` —
vedere [control-api.md](control-api.md)) e un override per-modulo opzionale,
modificabile come qualunque altro campo di modulo tramite `POST
/modules/{module_id}`.

Un processo driver riceve solo il proprio `Module` via `MODULE_CONFIG`, mai
la config di stazione (stesso vincolo già documentato per `DataFileHeader`
in `output_manager.py`), quindi "override se impostato, altrimenti il
default di stazione corrente" non può essere risolto dentro il codice del
driver, né viene cablato nel file di config in anticipo (diventerebbe
stantio non appena il default di stazione cambia). Viene risolto **una sola
volta, nel momento in cui un processo driver viene effettivamente lanciato**,
da `driver_manager.launch_driver()` — l'unico punto in cui convergono
`start()`, `restart()`, e il lancio iniziale all'avvio del servizio. Se si
usa l'SDK, `run_driver()` legge il valore già risolto da
`module_config["LogLevel"]` e lo passa a
`common.configure_driver_logging()`; nient'altro da fare.

Poiché la risoluzione avviene al momento del lancio, non quando cambia il
default di stazione, un driver già in esecuzione mantiene il suo livello
attuale finché non viene riavviato — stesso comportamento "richiede un
riavvio per avere effetto" di qualunque altro campo di config a livello di
modulo.

Per chi scrive direttamente i file OPAS NEO (sezione 5.1, opzione b) o
comunque aggira l'SDK, `LogLevel` non viene applicato automaticamente —
`common.configure_driver_logging(level=...)` è disponibile per ottenere lo
stesso comportamento, ma va chiamata esplicitamente.

## 4. Cosa non va dato per scontato

- Nessun `sys.argv`.
- Nessuno stdout/stderr catturato — va configurato un logging proprio.
- Nessuno stato persistente tra i riavvii. Ogni avvio del processo è un
  interprete Python nuovo di zecca; le variabili globali a livello di modulo
  non sopravvivono a un riavvio. Per ricordare qualcosa tra i riavvii, va
  persistito su disco.
- Nessun callback di cleanup garantito allo shutdown — vedere sezione 9.
- Non è richiesto nessun health check, ping o heartbeat. Il servizio
  controlla solo se il processo di sistema operativo è ancora vivo.

## 5. L'unico requisito rigido: il contratto dei file di output

Questa è l'unica cosa che determina se il driver "funziona" dal punto di
vista del sistema. È un **contratto di rete fisso**: un parser a valle
valida ogni riga con una regex a campi fissi, quindi una colonna in più o in
meno rompe l'ingestione, non solo l'estetica.

Ogni lettura prodotta deve risultare in righe scritte in questi file, sotto
una directory radice dei dati e una stringa di intestazione di stazione che
non sono scelte dal driver (entrambe provengono dal servizio in esecuzione —
vedere 5.2 per come evitare di doverle conoscere):

| File | Scrittura | Formato riga |
|---|---|---|
| `file_istantanei/<STATION_HEADER>.dat` | Riscritto per intero a ogni aggiornamento, una riga per canale (ultimo valore noto) | `DATA+ORA,ID,VAL,P.COD` |
| `files_letture_dat/<YYYYMM>/<STATION_HEADER>-<YYYY-MM-DD>.dat` | Aggiunto in coda | `DATA+ORA,ID,VAL,P.COD` |
| `files_letture_dat/<STATION_HEADER>-<YYYY-MM-DD-HH>-00-00.dat` (direttamente sotto `files_letture_dat`, nessuna sottocartella mensile) | Aggiunto in coda | `DATA+ORA,ID,VAL,P.COD` |
| `files_letture_csv/<YYYYMM>/<ChannelName>-<YYYY-MM-DD>.csv` | Aggiunto in coda, solo quando è presente un valore | `DATA;VALORE` |
| `files_medie_dat/<YYYYMM>/<STATION_HEADER>-<YYYY-MM-DD>.dat` | Aggiunto in coda, una riga per canale per ogni ora trascorsa (vedere 5.3) | `DATA+ORA,ID,VAL,P.COD,S.COD,PERC,MIN,H.MIN,MAX,H.MAX,STDDEV` |
| `files_medie_dat/<STATION_HEADER>-<YYYY-MM-DD-HH>-00-00.dat` (direttamente sotto `files_medie_dat`, nessuna sottocartella mensile) | Aggiunto in coda | `DATA+ORA,ID,VAL,P.COD,S.COD,PERC,MIN,H.MIN,MAX,H.MAX,STDDEV` |
| `files_medie_csv/<YYYYMM>/<ChannelName>-<YYYY-MM-DD>.csv` | Aggiunto in coda, una riga per canale per ogni ora trascorsa, scritta sempre (anche se l'ora non ha letture valide) | `DATA;VALORE;P.COD` |

Formati esatti:

- `DATA+ORA` nei file `.dat`: `YYYY-MM-DD HH:MM:SS` (es. `2026-07-24 14:32:10`).
- `ID`: il `DatabaseId` del canale da `MODULE_CONFIG` (sezione 3), non il suo `ID` proprio.
- `VAL`: la lettura, arrotondata al campo config `Decimals` del canale (non
  arrotondata se `Decimals` non è fornito), o stringa vuota se mancante.
  Punto decimale `.`.
- `P.COD` in `file_istantanei`/`files_letture_*`: `0` = valido, `128` = valore mancante.
- `P.COD` in `files_medie_*` (medie orarie, vedere 5.3) può includere anche `512`/`1024` (banda `DetectionLimit`) o `2048`/`4096` (`AllowedMinValue`/`AllowedMaxValue` superato), combinati in OR con `128` come bitmask. I bit `1`/`2`/`4`/`8` (tolleranza span/zero), `16`/`32`/`64` (calibrazione/manutenzione) e `8192` (variazione istantanea) sono riservati dal formato di rete ma non vengono mai emessi da questo servizio — vedere 5.3.
- `S.COD` (stato stazione, solo `files_medie_*`): sempre `0` — nessun segnale reale di stato stazione (spazio disco, errori software, riavvii) esiste da nessuna parte in questo codebase oggi.
- `DATA` nel file `.csv`: `DD/MM/YYYY HH:MM:SS` (es. `24/07/2026 14:32:10`).
- `VALORE` nel file `.csv`: la lettura con la **virgola** come separatore
  decimale (es. `42,5`), e la riga viene scritta solo quando il valore non è
  mancante (i file `.dat` portano già P.COD=128 per quel caso, quindi non si
  perde informazione omettendolo qui).
- `file_istantanei/<STATION_HEADER>.dat` deve essere riscritto **in modo
  atomico** (scrivere su un file temporaneo, poi rinominare/sostituire) — la
  UI lo legge dal vivo e non deve mai vedere un file scritto a metà.
- Nei nomi dei file di `files_letture_csv`, `/` e `\` nel nome del canale
  vengono sostituiti con `_`.
- I file `.dat` non portano mai una riga di intestazione; le righe in
  `file_istantanei` sono ordinate per `ID` di canale.

**Righe di esempio**, per un canale con `DatabaseId=53`, lettura `42.5` alle
2026-07-24 14:32:10:

```
# file_istantanei / files_letture_dat
2026-07-24 14:32:10,53,42.5,0

# files_letture_csv
24/07/2026 14:32:10;42,5
```

### 5.1 Due modi ugualmente validi per soddisfare questo requisito

**(a) Usare l'helper fornito (consigliato, zero configurazione richiesta).**
Nel momento in cui il codice del driver viene eseguito, il processo è già
collegato all'output broker del servizio. Si importa `output_manager` (un
nome di modulo nudo — si risolve perché il servizio lo mette su `sys.path`
prima dell'esecuzione) e si chiama:

```python
import output_manager

writer = output_manager.create_output_writer()   # una volta, all'avvio
writer.write(output_manager.Reading(
    channel_id=channel_config["DatabaseId"],
    channel_name=channel_config["Name"],
    value=42.5,          # o None se mancante
    decimals=channel_config.get("Decimals"),   # arrotonda VAL; ometti per nessun arrotondamento
))
writer.close()            # una volta, allo shutdown
```

Questo gestisce automaticamente la formattazione esatta, le scritture
atomiche e la sicurezza rispetto a scritture concorrenti (più processi
driver della stessa stazione non scrivono mai direttamente questi file da
soli — passano le letture a un unico processo broker). `Reading` accetta
anche un `raw_value` opzionale — vedere sezione 5.4.

**(b) Scrivere direttamente i quattro file, a mano, senza alcun import da
questa codebase.** Questo è completamente supportato e non è una via di
serie B — è esattamente ciò che fa internamente il fallback proprio di
`output_manager` quando non è disponibile alcun broker, quindi il formato
sopra è dimostrato autosufficiente. Va seguito con precisione il formato
della sezione 5; non c'è nessun altro requisito.

Se due processi driver potessero mai essere in esecuzione per la stessa
stazione contemporaneamente (non il caso normale — normalmente è un
processo per modulo), la responsabilità di non scrivere questi file in modo
concorrente ricade sul driver. Scegliendo l'opzione (a), il servizio se ne
occupa già.

### 5.2 Il file di stato legacy per driver (opzionale, solo cosmetico)

Nessun driver di questo codebase scrive più questo file (ADAM_4013 e
ADAM_4052, gli ultimi due a farlo, sono stati migrati a scrivere solo nel
formato OPAS NEO). Resta documentato qui perché la UI desktop lo legge
ancora come fallback, per qualsiasi driver - in questo codebase o di terze
parti - che preceda l'output broker OPAS NEO e non sia stato migrato: un CSV
per driver sotto `<py_out>/output/` chiamato
`<safe_instrument_name>_<module_id>.csv`, sovrascritto a ogni ciclo con una
riga di intestazione ed esattamente una riga di dati:

```
timestamp,instrument_id,<channel1>,<channel2>,...
2026-07-24 14:32:10,1,42.5,...
```

Questo file **non** fa parte del contratto di rete sopra descritto, ed è
letto dalla UI desktop solo quando il moderno file
`file_istantanei/<STATION_HEADER>.dat` non esiste ancora. Un driver che
soddisfa correttamente la sezione 5 non ha alcun bisogno di scrivere questo
file.

### 5.3 Medie orarie (`files_medie_csv` / `files_medie_dat`)

Separatamente dai file istantanei sopra, viene scritta una riga per canale
per ogni ora trascorsa ("targata anticipata": la riga delle `06:00:00`
riassume le letture dalle `06:00:00` alle `06:59:59`), anche se l'ora non ha
alcuna lettura valida (nel qual caso `VAL`/`MIN`/`MAX` sono vuoti,
`H.MIN`/`H.MAX` sono `00:00:00`, `STDDEV` è `0`, e `P.COD` include `128`).

Se si usa l'SDK (sezione 6), questo viene calcolato e scritto
automaticamente — basta popolare gli otto campi extra di `Channels[]`
mostrati nell'esempio di `MODULE_CONFIG` della sezione 3 (`MeanInterval`,
`ReadingsMinPercentage`, `DetectionLimit`, `AllowedMinValue`,
`AllowedMaxValue`, `NegativeValueSetToZero`, `Decimals`, `Algorithm`); tutto
il resto (media/min/max/deviazione standard calcolati via streaming, il
flush al cambio ora, e la ripresa di un'ora in corso attraverso un riavvio
del servizio) avviene dentro l'output broker, non nel codice del driver.

L'arrotondamento a `Decimals` tocca solo i numeri finali: ogni lettura che
alimenta la somma/min/max/deviazione standard dell'ora resta non
arrotondata, e `VAL`/`MIN`/`MAX`/`STDDEV` vengono arrotondati una sola volta,
dopo che la media è stata calcolata al cambio ora — mai lettura per lettura.
Questo differisce dai file istantanei sopra, dove ogni `VAL` viene arrotondato
al momento della scrittura.

Per chi scrive direttamente i file OPAS NEO (5.1 opzione b), la
responsabilità si estende anche a questa coppia di file se serve che sia
popolata — non esiste un fallback a livello di codice per un driver che
aggira `output_manager` del tutto, come già per i file istantanei.

#### 5.3.1 `Algorithm`: quale aggregazione produce `VAL`

`MIN`/`MAX`/`STDDEV` sono sempre le vere statistiche delle letture dell'ora,
indipendentemente da `Algorithm` — cambia solo la base di `VAL`. `Algorithm`
è l'enum legacy di VB.NET, mantenuto identico (`output_manager.Algorithm`);
l'SDK oggi ne implementa un sottoinsieme e fa fallback ad `Average` (con
warning di log) per qualunque codice non implementato, così un canale con un
codice non ancora supportato produce comunque un `VAL` sensato invece di
rompere il driver:

| Codice | Nome | `VAL` è | Implementato? |
|---|---|---|---|
| 0 | Average | media delle letture dell'ora | sì |
| 1 | Total | somma delle letture dell'ora | sì |
| 2 | Sample | l'ultima lettura valida dell'ora | sì |
| 3 | BitOr | OR bit a bit delle letture, ciascuna arrotondata all'intero più vicino | sì |
| 4 | WindVectorSpeed | — | no (fallback ad Average) |
| 5 | WindVectorDir | — | no (fallback ad Average) |
| 6 | CounterDiff | ultima lettura meno prima lettura dell'ora | sì |
| 7 | Max | stesso valore della colonna `MAX` | sì |
| 8 | Min | stesso valore della colonna `MIN` | sì |
| 9 | RainType | — | no (fallback ad Average) |

Per chi scrive direttamente i file OPAS NEO (5.1 opzione b), `Algorithm` è
interamente a proprio carico da interpretare — non riguarda quel caso.

### 5.4 Il file parallelo del valore raw (opzionale, solo per la UI)

`file_istantanei_raw/<STATION_HEADER>.dat` viene scritto accanto a
`file_istantanei`, con lo stesso identico formato riga `DATA+ORA,ID,VAL,P.COD`
e lo stesso comportamento di riscrittura completa a ogni aggiornamento, ma
`VAL` qui è la lettura **prima** che `Channel["Formule"]` venga applicata —
il valore così com'è letto dallo strumento, mai arrotondato a `Decimals`.
**Non** fa parte del contratto di rete della tabella della sezione 5: nessun
parser `centro` a valle lo legge, esiste solo perché la UI desktop possa
mostrare la lettura raw accanto a quella convertita. Un driver che non
produce mai un valore raw (es. dispone solo di una lettura già convertita)
può semplicemente non scrivere questo file — la UI tratta un valore/file raw
mancante come "nessun dato raw disponibile", mai come un errore.

Se si usa l'SDK (opzione a), basta passare `raw_value` su `Reading` e questo
file viene scritto automaticamente:

```python
writer.write(output_manager.Reading(
    channel_id=channel_config["DatabaseId"],
    channel_name=channel_config["Name"],
    value=42.5,          # dopo Formule
    raw_value=41.2,       # prima di Formule, o None se non esiste una lettura reale
    decimals=channel_config.get("Decimals"),
))
```

`P.COD` per questo file è derivato da `raw_value` indipendentemente da
`value` — un errore di formula che azzera `value` non azzera un `raw_value`
altrimenti valido. Per chi scrive direttamente i file OPAS NEO (5.1 opzione
b), questo file è interamente opzionale e fuori dal requisito vincolante
della sezione 5.

## 6. L'SDK è opzionale

`opas_dl_commons/libs/driver_sdk.py` fornisce `BaseDriver` (una classe base
con `connect()`, `disconnect()`, `read_channel()`/`read_all_channels()`) e
`run_driver()` (una funzione che esegue il loop di polling, gestisce i
segnali di shutdown, e scrive i file di output tramite l'opzione (a) della
sezione 5.1). Va usata per scrivere meno codice; può essere ignorata del
tutto per chi preferisce scrivere un proprio loop.

```python
import os, importlib.util

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Risalita minima per individuare opas_dl_commons/libs/ - la cartella
# driver può stare direttamente sotto drivers/ oppure essere annidata per
# raggruppamento (vedere sezione 8), quindi non può essere una profondità
# "../.." fissa. Questa parte non può vivere dentro libs/ (è ciò che trova
# libs/ prima che qualunque cosa lì dentro sia raggiungibile), ma tutto il
# resto delega a libs/driver_bootstrap.py, che ha la versione documentata e
# canonica di questa stessa risalita più un helper load_module() che evita
# di ripetere questa danza exec_module per ogni ulteriore modulo di libs/
# caricato.
_dir = BASE_DIR
while not os.path.isdir(os.path.join(_dir, "libs")):
    _parent = os.path.dirname(_dir)
    if _parent == _dir:
        raise RuntimeError(f"Could not locate opas_dl_commons/libs/ starting from {BASE_DIR}")
    _dir = _parent
LIBS_DIR = os.path.join(_dir, "libs")

_bootstrap_spec = importlib.util.spec_from_file_location(
    "driver_bootstrap", os.path.join(LIBS_DIR, "driver_bootstrap.py"))
driver_bootstrap = importlib.util.module_from_spec(_bootstrap_spec)
_bootstrap_spec.loader.exec_module(driver_bootstrap)

driver_sdk = driver_bootstrap.load_module(LIBS_DIR, "driver_sdk")


class MyDriver(driver_sdk.BaseDriver):
    def connect(self):
        self._sock = my_instrument_sdk.open(self.module_config["TCPIPAddress"])

    def read_channel(self, ch):
        return my_instrument_sdk.query(self._sock, ch["Address"])

    def disconnect(self):
        self._sock.close()


if __name__ == "__main__":
    driver_sdk.run_driver(MyDriver)
```

Se lo strumento risponde con più canali in un'unica risposta invece che con
un comando per canale, va sovrascritto `read_all_channels(channels)` invece
di `read_channel(channel)` — vedere la docstring in `driver_sdk.py` per i
dettagli.

Va implementato almeno uno tra `read_channel`/`read_all_channels`;
`connect()`/`disconnect()` sono opzionali.

Per chi non vuole gestire direttamente socket/seriale/pymodbus/file,
`driver_sdk.comm_manager` (ri-esportato da `opas_dl_commons/libs/comm_manager.py`)
offre `create_channel(self.module_config)`, un'unica factory che legge
`ComunicationType` e ritorna il canale giusto per tutti e sette i valori
supportati: Seriale (0), TCP/IP (1), PipeFile (3), UDP (4), Modbus Seriale
(5), Modbus Ethernet (6) e HTTP (7, non nell'enum VB.NET originale - vedere
sotto). I canali Seriale/TCP/IP/UDP condividono un'interfaccia
`send()`/`recv()`/`close()`/`is_open()`; i canali Modbus espongono invece
`read_registers(function_code, address, quantity)` più l'helper di modulo
`decode_modbus_value(registers, register_type, register_order)`; i canali
PipeFile espongono invece `read_values(channels)` (una lettura in blocco,
pensata per `read_all_channels()`); i canali HTTP espongono invece
`get(path, headers=None)` (ritorna il corpo grezzo della risposta, solleva
`urllib.error.URLError`/`HTTPError` come chiamare `urlopen()` direttamente).
Vedere `opas_dl_commons/drivers/PALAS/FIDAS_200/driver.py` (Modbus),
`opas_dl_commons/drivers/PIPE/CSV/driver.py` (PipeFile) e
`opas_dl_commons/drivers/CAMPBELL/CR1000/driver.py` (HTTP) per esempi funzionanti.

## 7. Un esempio da zero (nessun import da questa codebase)

```python
import json
import os
import socket
import time
from datetime import datetime

module_config = json.loads(os.environ["MODULE_CONFIG"])
instrument_id = os.environ["INSTRUMENT_ID"]
polling_interval = int(module_config.get("PollingInterval", 1))
active_channels = [c for c in module_config.get("Channels", []) if c.get("Active")]

# La radice dei dati e l'intestazione di stazione sono a scelta (chiedere al
# proprietario del sistema questi due valori quando il driver viene
# registrato - vedere sezione 8).
DATA_ROOT = "/path/to/py_out/data"
STATION_HEADER = "my-station"


def write_reading(channel_id, value):
    now = datetime.now()
    p_cod = 0 if value is not None else 128
    val_text = "" if value is None else str(value)
    row = f"{now:%Y-%m-%d %H:%M:%S},{channel_id},{val_text},{p_cod}\n"

    daily_dir = f"{DATA_ROOT}/files_letture_dat/{now:%Y%m}"
    os.makedirs(daily_dir, exist_ok=True)
    with open(f"{daily_dir}/{STATION_HEADER}-{now:%Y-%m-%d}.dat", "a", newline="") as f:
        f.write(row)
    # ... file_istantanei (riscrittura atomica) e files_letture_csv omessi
    # per brevità - vedere sezione 5 per il loro formato esatto.


while True:
    for ch in active_channels:
        value = None  # sostituire con la lettura effettiva dello strumento
        write_reading(ch["DatabaseId"], value)
    time.sleep(polling_interval)
```

## 8. Registrazione

Non va modificato nessun file di questo repository. Va consegnata una
cartella driver (`driver.py`, più tutto ciò di cui ha bisogno) comunicando
al proprietario del sistema:

- il percorso della cartella sotto cui deve essere collocato, relativo a
  `drivers/` (es. `MyInstrument`, oppure `Acme/MyInstrument` per raggrupparlo
  sotto una cartella di marca/famiglia insieme ad altri driver dello stesso
  produttore),
- un codice `ModuleType` non ancora in uso,
- un nome visualizzato e un nome del produttore per la UI.

Il proprietario del sistema aggiunge una voce al registro condiviso dei
driver:

```json
{
  "<ModuleType>": {
    "Name": "My Instrument",
    "Producer": "Acme Corp",
    "Drivers": "Acme/MyInstrument",
    "DefaultConfig": {}
  }
}
```

`Drivers` viene risolto relativamente a `drivers/`, componendo il percorso
pezzo per pezzo — può essere un nome di cartella semplice (`MyInstrument`) o
un percorso separato da `/` di profondità qualsiasi (`Acme/MyInstrument`) per
raggruppare i driver per marca/famiglia; `driver_manager` non assume una
profondità di annidamento fissa (vedere `resolve_driver_for_module` /
`_read_drivers_dict` in `driver_manager.py`). `driver.py` deve trovarsi
esattamente a quel percorso, es. `Acme/MyInstrument/driver.py` — esattamente
questo nome file, al primo livello della cartella consegnata.

## 9. Contratto di shutdown

Quando il servizio ferma il driver, chiama l'equivalente del sistema
operativo di "per favore termina", aspetta fino a 5 secondi, e poi termina
forzatamente il processo se è ancora in esecuzione.

**È importante essere chiari su cosa significhi questo su Windows**: su
questa piattaforma, "per favore termina" è `TerminateProcess` — un kill
incondizionato, non un segnale che il codice può catturare. Gestire
`SIGTERM`/`SIGINT` (come fanno `common.setup_signal_handlers()`/l'SDK) è
innocuo ma non dà nessun vero periodo di grazia su Windows. **Va assunto di
non avere nessun callback di cleanup garantito.**

Implicazioni pratiche:

- Non lasciare mai un file di output scritto parzialmente — scrivere sempre
  su un file temporaneo e rinominare/sostituire, non scrivere mai sul posto
  (l'opzione (a) della sezione 5.1 lo fa già automaticamente).
- Non tenere un lock o mutex esterno che resterebbe bloccato per sempre se
  il processo sparisse a metà operazione. In caso di coordinamento con lo
  strumento stesso (es. un lock "chi mi sta parlando" dal suo lato), va
  previsto un timeout proprio invece di affidarsi al fatto che il percorso
  di uscita Python venga eseguito.
