# API

Server FastAPI/uvicorn avviato da `core/control_server.py`, in ascolto solo su
`127.0.0.1:8080` (mai esposto oltre localhost). Avviato come thread daemon da
`service_master.main()`, quindi condivide lo stesso processo — e lo stesso
registro in memoria di `driver_manager` — con il resto del servizio. Chiamata
direttamente dal **processo main** di Electron (`main.ts`); il renderer non
la raggiunge mai direttamente, passa sempre attraverso un canale IPC. Vedi
[architecture.md](architecture.md) per come si inserisce nel resto del
servizio.

Tutte le risposte di errore sono `HTTPException` con corpo JSON
`{"detail": "..."}`.

## `GET /drivers`

Restituisce lo stato di ogni driver registrato, indicizzato per ID
strumento.

```jsonc
{
  "1": {
    "instrument_id": "1",
    "name": "API 400",
    "alive": true,
    "pid": 12345,
    "model": "API 400",            // da drivers_dict.json, indicizzato per ModuleType
    "brand": "Teledyne",
    "driver_version": "1.0.0",
    "start_time": "2026-07-24T14:32:10",  // ISO 8601, null se mai avviato
    "uptime_seconds": 3600,               // null a meno che sia vivo
    "connection": {
      "type": "TCP/IP",                   // "TCP/IP" | "UDP" | "Modbus Ethernet" | "HTTP" | "Serial" | "Modbus Seriale" | "PipeFile" | null
      "host": "192.168.1.10",             // TCPIPAddress (tipi Ethernet/HTTP), "COM<n>" (tipi Seriale), o PipeFileName (PipeFile)
      "port": 3000,                       // TCPIPPort, null per tutto il resto
      "baud_rate": null                   // ComPortBauds, null per tutto tranne Seriale/Modbus Seriale
    },
    "driver_file": "API_400/driver.py",   // relativo alla cartella drivers/
    "shared_com_port": null,              // valorizzato quando questo modulo è stato rescritto su un broker di shared_serial_ports.py (il nome reale della porta COM); altrimenti null
    "shared_with": []                     // ID strumento degli altri moduli che condividono quella stessa porta, vuoto se non condivisa
  }
}
```

Il `ComunicationType` sottostante viene risolto tramite `comm_manager.normalize_comunication_type()` prima di costruire `connection` — lo stesso helper usato da `create_channel()` — quindi un `ComunicationType: 2` legacy non ancora migrato (Modbus generico, vedi comm_manager.py) viene correttamente riportato come `"Modbus Seriale"` o `"Modbus Ethernet"` anche qui, non solo al momento di creare il canale.

`shared_com_port`/`shared_with` compaiono solo per moduli con `ComunicationType` `0` (Seriale semplice) il cui `ComPortName` coincide con quello di un altro modulo attivo — `shared_serial_ports.py` marca il modulo riscritto con `_SharedComPortName` prima di passarlo a `launch_driver`, e `list_drivers()` si limita a far emergere quel tag più il raggruppamento dei "fratelli". `connection` per un modulo condiviso continua a riportare `type: "TCP/IP"` puntato al broker su `127.0.0.1:<port>` (è davvero così che il processo driver ci parla) — `shared_com_port` è ciò che indica che sotto c'è in realtà una porta seriale relayata. Modbus Seriale (`5`) ne resta deliberatamente fuori — vedi il commento in `shared_serial_ports.py` sul perché il broker non può veicolare il framing Modbus.

## `GET /driver-catalog`

Elenca ogni **cartella** driver sotto `drivers/` — codice driver installato su
disco, indipendentemente dal fatto che un modulo della config attiva lo usi
attualmente. Diverso da `GET /drivers` sopra, che elenca i processi driver
attualmente *registrati* (solo i moduli già presenti nella config attiva).
Sola lettura: nessun processo viene avviato, fermato o toccato in alcun modo.
Alimenta la pagina di esplorazione driver dell'interfaccia.

Costruito da `driver_manager.get_driver_catalog()`: percorre `drivers/` alla
ricerca di ogni `driver.py`, incrocia il percorso di ogni cartella con i
valori `Drivers` di `drivers_dict.json` (una cartella può servire più
`ModuleType` — es. `API/API_XXX` copre 100/200/300/400), e incrocia quei
`ModuleType` con i `Modules[]` della config attiva per elencare quali
strumenti risolvono attualmente a quella cartella. Una cartella senza voce in
`drivers_dict.json` compare comunque, con `moduleTypes`/`instruments` vuoti —
utile per individuare cartelle driver orfane. Un'unica eccezione: qualunque
cartella (a qualsiasi profondità) il cui nome inizia con `_` viene esclusa
dalla scansione e non compare mai nel catalogo — es. `_examples/`, un fixture
di documentazione che `drivers_dict.json` non referenzia mai deliberatamente
(vedi il docstring di `sdk_example_driver/driver.py`), non un driver
installato.

```jsonc
{
  "drivers": [
    {
      "path": "API/API_XXX",       // relativo a drivers/, separato da "/" -
                                    // corrisponde al valore "Drivers" in drivers_dict.json
      "group": "API",              // primo segmento del percorso - il
                                    // raggruppamento naturale per marca/famiglia nella UI
      "folderName": "API_XXX",     // ultimo segmento del percorso
      "moduleTypes": [
        { "moduleType": 100, "name": "API 100", "producer": "Teledyne", "description": "Module API 100", "version": "1.0.0" },
        { "moduleType": 200, "name": "API 200", "producer": "Teledyne", "description": "Module API 200", "version": "1.0.0" }
      ],
      "instruments": [
        { "id": 1, "name": "SO2 Analyzer" }
      ]
    }
  ]
}
```

- `200` sempre — una config attiva non risolvibile (mancante/corrotta)
  degrada a una lista `instruments` vuota per ogni driver invece di far
  fallire l'intera richiesta, dato che il catalogo resta comunque utile
  senza di essa.

`model`/`brand`/`driver_version` provengono dai campi `Name`/`Producer`/
`Version` di `drivers_dict.json` per il `ModuleType` di quel modulo, non dal
processo driver stesso — un driver non deve mai riportare la propria
identità.

## `GET /drivers/{driver_id}/start`

Avvia un driver attualmente fermo usando il suo ultimo `driver_file` e
`module_config` noti dal registro.

- `200 {"result": "started", "pid": <int|null>}`
- `404` — ID driver non presente nel registro.
- `409` — già in esecuzione (`RuntimeError` da `driver_manager.start()`).

## `GET /drivers/{driver_id}/stop`

Termina un driver in esecuzione: equivalente a `SIGTERM`, 5 s di grazia, poi
equivalente a `SIGKILL` se ancora vivo (vedi
[driver-contract.md](driver-contract.md) §9 per cosa significa questo per il
driver su Windows).

- `200 {"result": "stopped"}`
- `404` — ID driver non presente nel registro.
- `409` — non attualmente in esecuzione.

## `GET /drivers/{driver_id}/restart`

Ferma (se in esecuzione) e poi rilancia il driver con il suo `module_config`
attuale in memoria — che riflette qualsiasi patch a canale/modulo applicata
da quando è stato avviato l'ultima volta, anche se la patch è avvenuta
mentre era in esecuzione.

- `200 {"result": "restarted", "pid": <int|null>}`
- `404` — ID driver non presente nel registro.

## `POST /modules/{module_id}/channels/{channel_id}?config={filename}`

Applica una patch ai campi di un canale e li persiste in un file di config.
Il corpo è un oggetto JSON parziale con i campi da cambiare (chiavi
PascalCase grezze, stessa forma del file di config — vedi
`opasConfigManager.ts` sul lato Electron per la mappatura
camelCase↔PascalCase). Questo servizio è l'unico scrittore del file di
config; il ciclo lettura-merge-scrittura non è atomico tra richieste
concorrenti.

`config` (parametro query, opzionale) punta a un file specifico invece della
config attiva — il file attivo se il nome corrisponde, altrimenti un file
nella libreria samples (vedi `POST /configs` e
`POST /configs/{filename}/activate` sotto). Se omesso, punta alla config
attiva esattamente come prima — nessun chiamante preesistente (la pagina
Strumenti) lo invia mai. La sincronizzazione in memoria del driver (sotto)
avviene solo quando il bersaglio è effettivamente la config attiva: il
registro di `driver_manager` riflette solo i driver lanciati dalla vera
config attiva, quindi sincronizzarlo per un file arbitrario in samples/
potrebbe collidere con un `module_id`/`channel_id` che esiste anche lì per
puro caso.

Flusso: legge la config bersaglio → trova `module_id` in `Modules[]` → trova
`channel_id` nei `Channels[]` di quel modulo → `dict.update(patch)` → scrive
su un file `.tmp` e lo sostituisce con `os.replace()` sopra l'originale
(atomico sia su POSIX che su Windows) → se il bersaglio è la config attiva e
il driver del modulo è attualmente registrato, applica la patch anche al suo
`module_config` in memoria (così un riavvio successivo recepisce il nuovo
valore senza dover rileggere il file).

```jsonc
// Esempio di corpo della richiesta
{ "Active": false, "PollingInterval": 30 }
```

- `200 {"success": true, "channel": {...}}` — l'oggetto canale completo dopo
  la patch.
- `404` — file di config non trovato, modulo non trovato, o canale non
  trovato.

## `POST /modules/{module_id}?config={filename}`

Stesso flusso lettura-merge-scrittura dell'endpoint dei canali, ma per i
campi del modulo stesso (non i suoi canali). La chiave `Channels` viene
rimossa dalla patch prima di applicarla — questo endpoint non può essere
usato per sostituire in blocco la lista dei canali di un modulo. Stesso
parametro query opzionale `config` dell'endpoint canali sopra (la
sincronizzazione in memoria del driver si applica solo quando il bersaglio è
la config attiva).

Quando il bersaglio è la config attiva, se dopo la patch il flag `Active` del
modulo risulta acceso (o lo era già) e il modulo non ha ancora una voce nel
registro, il driver viene *registrato* anche qui — lo stesso passaggio
`resolve_driver_for_module()` + `register_driver()` che `POST /modules` esegue
per un modulo appena creato (vedi sotto): così riabilitare un modulo che era
`Active: false` all'avvio del servizio (e quindi saltato del tutto dal ciclo
di avvio, vedi architecture.md) non richiede un riavvio completo del servizio
per tornare avviabile. Qui viene solo registrato (placeholder `alive: false`),
non lanciato nulla — lo switch "abilita strumento" lato Electron fa sempre
seguire a questo salvataggio una chiamata a `GET /drivers/{id}/restart`
(sopra), che rilancia ogni volta che la voce registrata non è attualmente in
esecuzione, incluso il caso di una voce appena registrata e mai lanciata
prima. La registrazione viene saltata se il modulo è già registrato, perché
registrarlo di nuovo sovrascriverebbe la voce nel registro e potrebbe far
perdere il riferimento a un processo già in esecuzione.

- `200 {"success": true, "module": {...}}`
- `404` — file di config non trovato o modulo non trovato.

## `POST /modules?config={filename}`

Crea un nuovo modulo (strumento) e lo aggiunge a un file di config.
Diversamente dai due endpoint precedenti (che applicano una patch a un
modulo/canale esistente), il corpo della richiesta è un oggetto modulo
*completo* — incluso il suo array `Channels` — tipicamente costruito lato
Electron unendo il template `FullConfig` di `drivers_dict.json` con il
`DefaultConfig` del tipo di strumento scelto (vedi `getNewInstrumentDraft()`
in `opasConfigManager.ts`). Stesso parametro query opzionale `config` di
sopra — punta a un file in samples/ (es. uno non ancora attivato) invece
della config attiva.

Il servizio resta l'unico scrittore e garantisce l'unicità dei tre campi che
contano per la correttezza *all'interno di quel file*: ricalcola l'`ID` del
modulo e, al suo interno, l'`ID` di ogni canale (sequenziale, a partire da 1
all'interno del nuovo modulo) e il `DatabaseId` (sequenziale, a partire dal
`DatabaseId` più alto già usato in quel file) — i valori eventualmente
inviati dal client per questi tre campi vengono ignorati e sovrascritti. Ogni
altro campo, incluso il `Position` di ciascun canale, viene scritto
esattamente come inviato.

Solo quando il bersaglio è la config attiva, il driver viene *registrato* ma
non avviato: questo endpoint risolve il `ModuleType` del nuovo modulo tramite
`drivers_dict.json` nello stesso modo in cui lo fa la sequenza di avvio di
`service_master.py` per ogni modulo, tramite
`driver_manager.resolve_driver_for_module()`, poi chiama
`driver_manager.register_driver()` così che compaia subito in `GET /drivers`
con `alive: false` — cioè controllabile dall'icona di avvio nell'interfaccia —
senza avviare il processo e senza toccare nessun altro driver già in
esecuzione. Ad avviarlo effettivamente è una chiamata separata a
`GET /drivers/{id}/start` (sopra); non serve un riavvio completo del servizio
solo per rendere avviabile un nuovo strumento. La registrazione viene saltata
se il modulo è inattivo (`Active: false`) o se il suo `ModuleType` non si
risolve a un driver noto — lo stesso comportamento che avrebbe un riavvio
completo per quel modulo. Un modulo creato in un file di samples/ diventa
registrabile allo stesso modo non appena `POST /configs/{filename}/activate`
rende attivo quel file (seguito da un riavvio, o da una ripetizione di questa
chiamata).

```jsonc
// Esempio di corpo della richiesta (abbreviato)
{ "ModuleType": 100, "Name": "SO2 Analyzer", "Channels": [ { "Name": "SO2", "Unit": "ppb", ... } ], ... }
```

- `200 {"success": true, "module": {...}}` — l'oggetto modulo completo come
  scritto, inclusi `ID`/`Channels[].ID`/`Channels[].DatabaseId` assegnati dal
  server.
- `404` — file di config non trovato.

## `POST /configs/{filename}/station`

Applica una patch ai campi di una config a livello di stazione — `Name`,
`StationLocation`, `DataFileHeader`, `StationLatitude`/`StationLongitude`/
`StationAltitude`, ecc. — mai alla sua lista `Modules` (rimossa dalla patch,
stessa protezione che `POST /modules/{id}` applica a `Channels`). `filename`
è sempre obbligatorio: diversamente dagli endpoint di modulo/canale, non
esiste un chiamante preesistente che assume implicitamente "la config
attiva" — la pagina Configurazioni sa sempre quale file sta modificando, sia
esso attivo o nella libreria samples.

Nessuna sincronizzazione in memoria del driver avviene qui (diversamente da
`save_module`/`save_channel`): i campi a livello di stazione non fanno parte
del `MODULE_CONFIG` env var di alcun driver, quindi non c'è nulla su un
driver in esecuzione da tenere sincronizzato — l'effetto è solo sul file (e,
per la config attiva, su come Electron la mostra alla prossima lettura).

```jsonc
// Esempio di corpo della richiesta
{ "Name": "Backup Site", "StationLocation": "Plouves", "DataFileHeader": "backup" }
```

- `200 {"success": true, "data": {...}}` — l'oggetto config completo dopo la patch.
- `400` — filename non valido.
- `404` — file di config non trovato.

## `POST /configs`

Crea un nuovo file di config nella libreria samples — mai direttamente
attivo, vedi `POST /configs/{filename}/activate` per quello. Elencare/leggere
le config non ha un endpoint HTTP: come per la config attiva oggi, Electron
legge la libreria samples direttamente da disco (`opasConfigManager.ts`),
dato che sono semplici letture e l'architettura a due canali instrada solo le
*scritture* attraverso questa API (vedi [architecture.md](architecture.md)).

Tre modalità, scelte da `body.mode`:

- `"duplicate"` — copia `body.sourceFilename` (il file attivo, o uno già
  nella libreria samples), poi applica `body.fields` (opzionale) come
  sovrapposizione superficiale dei campi a livello di stazione (es.
  `Name`/`StationLocation`/`DataFileHeader`).
- `"blank"` — parte da `{"Modules": []}` e applica `body.fields` sopra.
- `"import"` — `body.content` è un oggetto config completo già letto lato
  client (es. da un selettore di file) e salvato così com'è, tranne il nome
  del file.

`body.filename` è sempre obbligatorio: un nome semplice (senza separatori di
percorso — rifiuta il path traversal fuori dalla cartella samples) che
termina in `.json`, e non deve collidere con un file già esistente (attivo o
già in samples/).

```jsonc
// Esempio di corpo della richiesta (duplicate)
{ "mode": "duplicate", "filename": "Config-Backup-Site.json",
  "sourceFilename": "Config-Neo-Demo.json",
  "fields": { "Name": "Backup Site", "DataFileHeader": "backup" } }
```

- `200 {"success": true, "filename": "..."}`
- `400` — filename non valido o mancante, `mode` non valido, `sourceFilename`
  mancante per `mode="duplicate"`, o `content` non oggetto per
  `mode="import"`.
- `404` — `mode="duplicate"` e `sourceFilename` non esiste.
- `409` — esiste già una config con quel filename.

## `POST /configs/{filename}/activate`

Rende `filename` (attualmente nella libreria samples) la config attiva:
scambia le due posizioni — quella attualmente in `active/` si sposta nella
libreria samples (mantenendo il proprio nome file), e `filename` si sposta da
samples/ ad `active/`. `active/` contiene sempre esattamente un file; ogni
altra config, sia essa un template incluso nell'app o una creata
dall'utente, vive in samples/.

Questo cambia solo quale file legge il *prossimo* riavvio completo
(`POST /service/restart`) o un driver appena lanciato — i driver già in
esecuzione mantengono qualunque config con cui sono stati avviati, stesso
precedente "richiede un riavvio per avere effetto" degli endpoint di patch
modulo/canale sopra. Ci si aspetta che la UI Electron chieda all'utente se
riavviare subito.

- `200 {"success": true, "activeFilename": "..."}`
- `400` — filename non valido.
- `404` — `filename` non trovato nella libreria samples (es. è già quello
  attivo).

## `GET /logging`

Legge il livello di log di default a livello di stazione
(`Config["LogLevel"]`) dalla config attiva.

- `200 {"level": "INFO"}` — `"INFO"` (non un errore) se il file di config non
  viene trovato o non ha `LogLevel` impostato.

## `POST /logging`

Imposta il livello di log di default a livello di stazione, lo persiste e lo
applica **immediatamente** ai log del service-master (`service.log`/
`web.log`) — nessun riavvio necessario per quella parte.

Questo **non** tocca i processi driver già in esecuzione: un modulo senza un
proprio `LogLevel` recepisce il nuovo default al suo prossimo riavvio (stesso
precedente "richiede un riavvio per
avere effetto" delle patch a modulo/canale, vedi `POST /modules/{module_id}`
sopra), risolto fresco in quel momento da `driver_manager.launch_driver()` —
non propagato qui. Il livello di log di un singolo strumento può essere
sovrascritto indipendentemente da questo default di stazione tramite il suo
campo `Module["LogLevel"]`, modificabile tramite l'ordinario `POST
/modules/{module_id}` come qualunque altro campo di modulo (es.
`PollingInterval`) — non esiste un endpoint dedicato per l'override
per-modulo.

```jsonc
// Corpo della richiesta
{ "level": "DEBUG" }
```

```jsonc
// Risposta
{ "success": true, "level": "DEBUG" }
```

- `400` — `level` non è uno tra `DEBUG`, `INFO`, `WARNING`, `ERROR`.
- `404` — file di config non trovato.

## `POST /service/restart`

Riavvia **l'intero processo master**, non un singolo driver: ferma ogni
driver e broker in modo pulito, poi ricrea con `os.execv()` la stessa
immagine di processo (vedi
[architecture.md](architecture.md#shutdown-e-riavvio)). La risposta HTTP
viene inviata prima che l'immagine del processo venga sostituita (il riavvio
gira su un thread in background con un breve ritardo), quindi il chiamante
vede in modo affidabile il risultato `"restarting"` anche se il processo che
lo ha inviato sta per scomparire.

- `200 {"result": "restarting"}`
