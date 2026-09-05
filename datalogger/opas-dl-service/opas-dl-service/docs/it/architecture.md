# Architettura

## Cos'è questo servizio

`opas-dl-service` è il backend di acquisizione dati per una stazione di
monitoraggio ambientale OPAS. Esegue uno o più processi **driver**, ognuno
dei quali interroga un singolo strumento ("modulo"), ed espone il loro stato
e i relativi controlli tramite una API HTTP locale. Ha un solo client:
l'app desktop Electron `opas-dl-neo`, in esecuzione sulla stessa macchina.
Vedi [driver-contract.md](driver-contract.md) per la parte relativa ai
driver, e [control-api.md](control-api.md) per la parte HTTP.

## Modello dei processi

```
service_master.py (processo di primo livello)
 ├─ output_broker_manager  → un processo "output-broker" (sempre avviato)
 ├─ shared_serial_ports    → zero o più processi "serial-broker-<COM>"
 │                            (solo per porte COM condivise da ≥2 moduli)
 ├─ driver_manager         → un processo per ogni modulo attivo (driver.py)
 └─ control_server         → FastAPI/uvicorn, thread daemon, 127.0.0.1:8080
```

Ognuno dei figli sopra è un processo di sistema operativo separato
(`multiprocessing.Process`), non un thread — driver, broker e il master non
devono (e non possono, con il metodo di avvio `spawn` di Windows) condividere
memoria o stato a livello di modulo. Il control server è l'unica eccezione:
gira come **thread** daemon dentro il processo master, perché ha bisogno di
accesso sincrono al registro in memoria di `driver_manager`.

### Sequenza di avvio (`service_master.main()`)

1. **Lock singleton.** Prima di ogni altra cosa, il processo di primo livello
   effettua il bind esclusivo di una porta TCP di loopback
   (`127.0.0.1:47990`), usata puramente come mutex cross-platform — non
   servita realmente. Un secondo avvio fallisce questo bind ed esce
   immediatamente, prima di toccare log o config. Questo controllo è protetto
   da `__name__ == "__main__" and multiprocessing.current_process().name ==
   "MainProcess"` — servono entrambe le condizioni: il solo controllo sul nome
   di processo esclude i processi figli driver/broker che il metodo `spawn`
   di Windows crea rieseguendo questo stesso modulo (che vedono comunque
   `__name__ == "__main__"`, ma mai `"MainProcess"`), mentre il controllo su
   `__name__` resta una difesa contro un *secondo* import di questo modulo,
   nello stesso processo, sotto il nome `"service_master"` (anziché
   `"__main__"`, il nome con cui è stato caricato la prima volta). Un simile
   reimport rieseguirebbe l'intero file da capo come modulo distinto, il cui
   `main()` non è mai stato chiamato — quindi `driver_manager`,
   `shared_serial_ports`, `output_broker_manager` (assegnati solo dentro
   `main()`) resterebbero `None` in quella copia, e `request_restart()`
   letta da lì fermerebbe `_stop_drivers_and_brokers()` con un `AttributeError`
   ad ogni tentativo (catturato e loggato, non fatale) — lasciando ogni
   driver/broker realmente in vita a tenersi il proprio duplicato ereditato
   del socket di lock, cosicché il processo appena ri-eseguito con `execv`
   non riesce a racquisire la porta 47990 ed esce subito con "un'altra
   istanza è già in esecuzione". Questo scenario si verificava perché
   l'handler `POST /service/restart` di `control_server.py` recuperava
   `request_restart` con un import lazy `from service_master import
   request_restart`, che Python risolve creando esattamente quel secondo
   modulo; ora invece lo recupera da `sys.modules["__main__"]`, cioè
   dall'istanza già in esecuzione il cui `main()` ha realmente popolato quello
   stato — quindi il reimport, e la catena di errori che ne derivava, non si
   verifica più (vedi [control-api.md](control-api.md)).
2. `service_init.configure()` crea le directory runtime (drivers, logs)
   e configura il logging tramite `logging.config.dictConfig`. Questo
   avviene **al momento dell'import del modulo**, non dentro `main()` — deve
   succedere prima di qualsiasi altro import che scrive log. È protetto dalla
   stessa identica condizione `__name__ == "__main__" and ... "MainProcess"`
   del lock singleton, per lo stesso motivo: senza quella guardia, un eventuale
   reimport nello stesso processo o ogni processo figlio driver/broker lo
   rieseguirebbero, cancellando e ricreando `GENERAL_LOG`/`WEB_LOG` mentre gli
   handler del processo reale li tengono ancora aperti — su Windows questo fa
   sollevare `PermissionError` (`WinError 32`) sull'`unlink()`, catturato e
   loggato come warning "Error setting up GENERAL_LOG/WEB_LOG". I processi
   figli non hanno bisogno dei suoi effetti collaterali: le directory che crea
   esistono già quando viene lanciato un figlio, e l'inserimento di
   `LIBS_DIR` in `sys.path` di cui hanno bisogno avviene incondizionatamente
   nel bootstrap a livello di modulo di `service_init.py`, indipendentemente
   da `configure()`.
3. `load_active_config()` risolve e analizza la config JSON attiva (vedi
   [Risoluzione della configurazione](#risoluzione-della-configurazione) più
   sotto).
4. L'output broker si avvia (`output_broker_manager.start()`) e
   `driver_manager.set_output_context()` collega ogni driver lanciato da qui
   in poi alla stessa `Queue` del broker.
5. `load_drivers_dict()` carica `opas_dl_commons/drivers/drivers_dict.json`,
   che mappa ogni codice `ModuleType` a un percorso di cartella driver
   (`driver_manager.resolve_driver_for_module()` risolve questo percorso
   relativamente a `drivers/`; può essere un nome semplice o un percorso
   annidato tipo `Acme/MyInstrument` per raggruppare i driver per
   marca/famiglia — vedi [Registrazione](driver-contract.md#8-registrazione)).
6. `shared_serial_ports.prepare_modules()` riscrive ogni modulo il cui
   `ComPortName` è condiviso da un altro modulo attivo affinché punti a un
   processo broker invece che alla porta seriale grezza (vedi
   [Porte COM condivise](#porte-com-condivise)).
7. Per ogni modulo attivo nella config, il `driver.py` corrispondente viene
   risolto tramite `drivers_dict` e lanciato come `multiprocessing.Process`,
   con la config JSON del modulo serializzata nella variabile d'ambiente
   `MODULE_CONFIG` (vedi [driver-contract.md](driver-contract.md)).
8. `start_control_server()` avvia FastAPI/uvicorn su un thread daemon.
9. Il loop principale registra gli handler `SIGINT`/`SIGTERM` e poi si limita
   a controllare ogni 30 secondi che i driver siano vivi, scrivendo un
   warning per ogni processo morto, finché un segnale di shutdown non imposta
   `shutdown_event`.

### Shutdown e riavvio

`SIGINT`/`SIGTERM` e `POST /service/restart` (vedi
[control-api.md](control-api.md)) confluiscono entrambi nella stessa routine
`_stop_drivers_and_brokers()`: ferma ogni driver tramite
`driver_manager.stop()`, poi `shared_serial_ports.shutdown()`, poi
`output_broker_manager.shutdown()`.

Questo è il percorso cooperativo, guidato dal processo padre.
Indipendentemente da esso, anche i processi dei broker (output broker e
serial-port broker: `output_broker.run_broker()`,
`serial_port_broker.run_broker()`) chiamano da soli
`common.setup_signal_handlers()`, come ogni processo driver basato su SDK —
su POSIX, il SIGINT di Ctrl+C raggiunge direttamente ogni processo del
gruppo in foreground, non solo il padre, quindi senza questa chiamata un
processo broker bloccato in una chiamata (`queue.get()`, `socket.accept()`)
subirebbe il comportamento di default di Python per SIGINT, sollevando un
`KeyboardInterrupt` non gestito invece di uscire dal suo loop normale (e dal
relativo `save_state()`/pulizia).

Un riavvio chiude inoltre il socket del
lock singleton e chiama `os.execv()` per sostituire l'immagine del processo
sul posto (stesso PID) invece di crearne uno nuovo con una fork — il socket
del lock deve essere chiuso esplicitamente prima, perché il sistema
operativo rilascia i descrittori `CLOEXEC` solo al momento dell'`exec`, e il
codice di primo livello della nuova immagine effettua di nuovo il bind di
quella stessa porta immediatamente.

## Risoluzione della configurazione

`resolve_active_config_path()` in `opas_dl_commons/libs/runtime_paths.py` è
l'unica fonte di verità, usata sia da `service_master.load_active_config()`
sia dagli endpoint di salvataggio canale/modulo del control server, in modo
che siano sempre d'accordo sullo stesso file:

1. Variabile d'ambiente `CONFIG_PATH` / `CONFIG_FILE` — un percorso file
   esplicito.
2. Variabile d'ambiente `CONFIG_DIR` / `CONFIG_ACTIVE_DIR` — una directory
   esplicita; viene usato il primo file `*.json` al suo interno (in ordine
   alfabetico).
3. Directory candidate di default relative alla root runtime, in ordine:
   `config/active` sotto la root runtime, il suo genitore e il suo
   "nonno", poi `./config/active` relativo alla directory di lavoro
   corrente.
4. `_MEIPASS/config/active` di PyInstaller, come fallback per le build
   compilate.

Non aggiungere un nuovo percorso di risoluzione se non in questa funzione —
ogni punto del codice che legge la config dipende dal fatto che sia
d'accordo con tutti gli altri.

## Risoluzione dei percorsi (`RuntimePaths`)

`opas_dl_commons/libs/runtime_paths.py` definisce anche `RuntimePaths`, un
singleton thread-safe che calcola la root runtime (la directory dello script
quando eseguito da sorgente, la directory dell'eseguibile sotto PyInstaller)
e carica `folder_config.json` per risolvere ogni altro percorso
(`OPAS_COMMONS_DIR`, `DRIVERS_DIR`, `CONFIG_ACTIVE_DIR`, `LOGS_DIR`,
`OUTPUT_DIR`, `OPAS_NEO_DATA_DIR`, `GENERAL_LOG`, `WEB_LOG`, ...) relativo ad
essa. `core/service_init.py` prepara `sys.path` in modo che questo modulo sia
importabile indipendentemente dal fatto che il chiamante si trovi in
`src/core/` o in `opas_dl_commons/libs/`, poi ri-esporta questi valori come
costanti a livello di modulo (`BASE_DIR`, `LOG_DIR`, `OUTPUT_DIR`, ...) perché
il resto della codebase li importi da `service_init` invece di ricalcolarli.

## Porte COM condivise

`core/shared_serial_ports.py` rileva i moduli con `ComunicationType == 0`
(seriale) che condividono lo stesso `ComPortName`. Quando ≥2 moduli attivi
collidono su una porta, avvia un singolo processo `serial_port_broker` per
quella porta e riscrive la config di ogni modulo in collisione affinché
sembri un normale modulo TCP/IP che punta a `127.0.0.1:<porta broker>` — i
driver e `comm_manager.py` non sanno mai che il broker esiste. I moduli che
non collidono con nulla passano invariati. Le impostazioni seriali del primo
modulo di ogni gruppo in collisione (baud rate, timeout, bit di
dati/parità/stop) vincono; una discrepanza da un altro modulo del gruppo
viene registrata come warning, non come errore.

## Formule (trasformazione della lettura grezza)

Prima di tutto quanto segue: se si usa l'SDK (`driver_sdk.run_driver()`),
`Channel["Formule"]` trasforma la lettura grezza dello strumento di un
canale nella misura reale (es. `"y=x/1000"`) subito dopo che
`read_channel()`/`read_all_channels()` restituisce un valore, prima ancora
che esista un `Reading` — quindi `output_manager`/`output_broker` (sotto)
non vedono mai il valore grezzo, solo quello già trasformato. Viene valutata
da un walker AST scritto a mano in `opas_dl_commons/libs/formula.py` (mai
`eval()`/`exec()` - solo una piccola grammatica aritmetica in whitelist),
non da nulla in questo livello di broker. Vedi
[driver-contract.md](driver-contract.md) sezione 3.2 per la grammatica
completa e le regole di gestione degli errori.

## Output broker

A differenza del broker delle porte COM, `core/output_broker_manager.py`
avvia **sempre** un processo "output-broker" per ogni istanza del servizio,
indipendentemente da quanti moduli siano configurati — perché il formato di
output OPAS NEO (`file_istantanei/<STATION_HEADER>.dat` ecc., vedi
[driver-contract.md](driver-contract.md) sezione 5) è un insieme di file per
stazione a cui un secondo modulo, o anche il semplice riavvio di un driver,
può iniziare a scrivere in qualsiasi momento. Ogni processo driver riceve la
stessa `multiprocessing.Queue` tramite `output_manager.configure()`, così
tutte le scritture su disco avvengono dall'unico processo broker e non si
verificano mai scritture concorrenti sullo stesso file.

### Medie orarie (`files_medie_csv` / `files_medie_dat`)

Oltre ai file istantanei, `output_broker.py` accumula e scrive anche le
medie orarie per canale ("targata anticipata": la riga delle `06:00:00`
riassume le letture dalle `06:00:00` alle `06:59:59` — vedi
[driver-contract.md](driver-contract.md) sezione 5 per il formato esatto
della riga). Ogni `Reading` porta ora con sé la config di canale necessaria
al calcolo (`mean_interval`, `polling_interval`, `readings_min_percentage`,
`detection_limit`, `allowed_min_value`/`allowed_max_value`,
`negative_value_set_to_zero`, `decimals`, `algorithm`), dato che il broker
vede solo oggetti `Reading` nudi, mai la config completa di un modulo.
`decimals` (da `Channel["Decimals"]`) arrotonda ogni valore scritto su
disco, ma il momento in cui questo avviene cambia a seconda del file: i
file istantanei arrotondano ogni lettura al momento della scrittura, mentre
`_HourBucket` accumula la somma/min/max/deviazione standard correnti senza
arrotondamento e arrotonda una sola volta, sulla media finita al cambio ora
— mai sulle letture che l'hanno alimentata.

`algorithm` (da `Channel["Algorithm"]`, l'enum legacy di VB.NET per
l'aggregazione — vedi `output_manager.Algorithm` e
[driver-contract.md](driver-contract.md) sezione 5.3.1 per la tabella
completa dei codici) sceglie quale delle statistiche correnti di
`_HourBucket` diventa `VAL`: una piccola funzione modulo-level per ciascun
algoritmo (`_agg_average`, `_agg_total`, `_agg_sample`, `_agg_bit_or`,
`_agg_counter_diff`, `_agg_max`, `_agg_min`) invece di un unico blocco a
branch, selezionata tramite `_ALGORITHM_HANDLERS`, così ognuna è chiamabile
e testabile in isolamento. `MIN`/`MAX`/`STDDEV` restano sempre le vere
statistiche indipendentemente da `algorithm`; i codici senza una funzione
dedicata (`WindVectorSpeed`, `WindVectorDir`, `RainType`) fanno fallback a
`_agg_average` con un warning di log invece di rompere il canale.

Un `_HourBucket` in memoria per canale accumula somme via via (nessuna
lettura grezza viene mai salvata) finché la sua ora non è provabilmente
conclusa — o perché quello stesso canale produce una lettura successiva con
un'ora più avanti, o perché il loop di lettura di `run_broker()`
(`in_queue.get(timeout=1.0)`, l'unico meccanismo di scheduling presente in
questo codebase) controlla a ogni passaggio se qualche bucket ha superato
la propria ora, così un canale che tace per un'intera ora produce comunque
una riga (tutti i campi vuoti/zero, `P.COD` include `128`) invece di essere
semplicemente ignorato.

Poiché il broker gira come processo separato, un bucket in corso andrebbe
altrimenti perso a ogni riavvio del servizio. `run_broker()` persiste tutti
i bucket aperti in `{PYOUT_DIR}/hourly_buckets_state.json` a una chiusura
pulita e li ricarica al successivo avvio — ma riprende un bucket solo se la
sua ora è ancora quella corrente; un bucket per un'ora già trascorsa è
incompleto e viene scartato invece di essere scritto o ripreso.

Vengono impostati solo i bit `P.COD` che hanno un valore di config reale a
supporto: `0` (valido), `128` (copertura sotto `ReadingsMinPercentage`),
`512`/`1024` (banda `DetectionLimit`), `2048`/`4096`
(`AllowedMinValue`/`AllowedMaxValue` superato da almeno una lettura
istantanea nell'ora). `S.COD` è sempre `0`. I bit `1`/`2`/`4`/`8` (tolleranza
span/zero), `16`/`32`/`64` (calibrazione/manutenzione) e `8192` (variazione
istantanea) sono riservati dallo spec ma non vengono mai emessi — nessun
valore di soglia/tolleranza esiste da nessuna parte nello schema di config
per calcolarli in modo onesto (vedi [driver-contract.md](driver-contract.md)
sezione 5 per la motivazione completa).

## Livello di log

`LogLevel` è un default a livello di stazione con un secondo livello
per-modulo e senza riavvio automatico. Il default di stazione
(`Config["LogLevel"]`, default `"INFO"`) si imposta dalla pagina
"Impostazioni" dell'UI Electron tramite `GET|POST /logging` (vedi
[control-api.md](control-api.md)) e si applica immediatamente, in-place, ai
log del service-master (`service_init.set_log_level()` — chiama solo
`setLevel()` su logger/handler già costruiti, mai di nuovo
`logging.config.dictConfig()`, che riaprirebbe e troncherebbe
`service.log`/`web.log`).

Questo default **non** viene copiato in anticipo nella config di ogni
modulo — ogni processo driver vede sempre e solo il proprio `Module`, mai la
config di stazione (vedi [driver-contract.md](driver-contract.md) §3.2 per
il vincolo che questo crea), e cablare il default in anticipo diventerebbe
stantio non appena cambia. Invece, un singolo modulo può portare un proprio `LogLevel`
sovrascritto, e `driver_manager.launch_driver()` — l'unico choke point in
cui convergono `start()`, `restart()`, e il lancio iniziale all'avvio del
servizio — risolve "override, altrimenti il default di stazione corrente
letto fresco da disco" nel momento esatto in cui un processo viene
spawnato, senza modificare il `module_config` (ancora non risolto) salvato
nel registry. Quindi un cambio del default di stazione, o un cambio
dell'override per-modulo (modificabile come qualunque altro campo di modulo
tramite `POST /modules/{module_id}`), hanno effetto entrambi allo stesso
modo di qualunque altro cambio di config a livello di modulo: al prossimo
riavvio di quel modulo, non immediatamente.

## I due canali di comunicazione con Electron

1. **File system (dati di misura), sola lettura da Electron.** I driver
   scrivono tramite l'output broker in
   `{opasDlPath}/src/py_out/data/` (`file_istantanei`, `files_letture_csv`,
   `files_letture_dat`, `files_medie_csv`, `files_medie_dat`) nel formato
   OPAS NEO — un contratto di rete fisso
   consumato anche da un parser "centro" esterno, quindi il layout delle
   righe non deve mai guadagnare o perdere una colonna. Il
   `resourceManager.ts` di Electron interroga
   `file_istantanei/<DataFileHeader>.dat` ogni secondo. Un file parallelo
   `file_istantanei_raw/<DataFileHeader>.dat` (stesso formato riga, stesso
   polling) porta la lettura raw pre-`Formule`, mostrata in UI accanto al
   valore convertito — **non** fa parte del contratto di rete con il centro
   (vedi driver-contract.md §5.4). Esiste ancora un file
   legacy `.txt`/`.csv` per modulo sotto `{opasDlPath}/src/py_out/output/`
   per i driver che lo scrivono (vedi driver-contract.md §5.2) ed è usato da
   Electron solo come fallback quando non viene ancora trovato alcun file
   OPAS NEO.
2. **API di controllo HTTP (stato e controllo dei driver),
   `127.0.0.1:8080`.** Chiamata direttamente dal **processo main** di
   Electron (mai dal renderer) — vedi [control-api.md](control-api.md) per
   ogni endpoint.

La config scorre in un'unica direzione: Electron legge `Config-*.json` dalla
cartella di questo servizio ma non la scrive mai direttamente. L'unica
eccezione è la modifica dei campi di un canale o di un modulo dalla UI di
dettaglio dello strumento, che passa per `POST /modules/{id}` /
`POST /modules/{id}/channels/{id}` — questo servizio resta l'unico scrittore
del file, unendo la patch e aggiornando anche la config in memoria del
driver se è attualmente in esecuzione.

**Layout dei file di config: esattamente una attiva, tutte le altre in
samples/.** `config/active/` contiene sempre esattamente un file — la config
in vigore per il processo corrente/al prossimo avvio. Ogni altro file di
config — i template inclusi e qualunque config l'utente duplichi, crei vuota,
o importi dalla pagina Configurazioni — vive in `config/samples/`. Cambiare
quale sia attiva (`POST /configs/{filename}/activate`, vedi
[control-api.md](control-api.md)) scambia le due posizioni invece di
copiare: il file che era in `active/` si sposta in `samples/`, e il file di
`samples/` scelto si sposta in `active/`. I tre endpoint di modifica
modulo/canale sopra (`POST /modules`, `POST /modules/{id}`,
`POST /modules/{id}/channels/{id}`) accettano tutti un `?config=` opzionale
con il nome del file, così la pagina Configurazioni può aggiungere/modificare
strumenti su qualunque config, non solo quella attiva — la sincronizzazione
in memoria del driver viene saltata ogni volta che il bersaglio non è la
config attiva, dato che il registro di `driver_manager` riflette solo i
driver effettivamente lanciati da essa. Creare una config (`POST /configs`)
scrive sempre e solo in `samples/`, mai in `active/`.
