# OPAS DL Service — indice della documentazione

Questa cartella contiene la documentazione di `opas-dl-service`, il backend
Python di acquisizione dati dell'applicazione desktop OPAS DL. Viene
consultata dal client Electron (opas-dl-neo) in *Impostazioni →
Documentazione*, e può anche essere letta direttamente come markdown.

| Documento | Contenuto |
|---|---|
| [install.md](install.md) | Come mettere in funzione una stazione a partire da una cartella pacchettizzata (o dal sorgente): avviare il servizio, avviare il client desktop, dove guardare in caso di problemi. |
| [architecture.md](architecture.md) | Modello dei processi, sequenza di avvio, risoluzione della configurazione, i due canali di comunicazione con il client Electron. |
| [control-api.md](control-api.md) | Ogni endpoint della API di controllo HTTP (`127.0.0.1:8080`): formato di richieste/risposte, casi di errore. |
| [driver-contract.md](driver-contract.md) | Il contratto autosufficiente che un `driver.py` deve rispettare — variabili d'ambiente, formato dei file di output, l'SDK opzionale. Scritto per terze parti che hanno bisogno solo di questo file. |
| [sdk-guide.md](sdk-guide.md) | Spiegazione schematica di `driver_sdk.py` (`BaseDriver` + `run_driver()`) per chi costruisce un driver sopra l'SDK opzionale invece del contratto grezzo, con un esempio pratico. |

Questa è la copia italiana — vedi [../en/](../en/README.md) per l'inglese.
Mantenere le due versioni allineate quando una delle due cambia.

## Come mantenerla aggiornata

Questi documenti descrivono *comportamenti*, non solo strutture — devono
restare accurati man mano che `service_master.py`, `control_server.py`,
`driver_manager.py` e l'SDK dei driver evolvono, e le due lingue devono
restare allineate tra loro. Quando una modifica tocca un comportamento
documentato, aggiorna il documento pertinente, in entrambe le lingue,
nello stesso cambiamento.
