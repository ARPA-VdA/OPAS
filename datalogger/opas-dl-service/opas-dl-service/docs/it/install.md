# Installare e avviare OPAS DL Neo

Questa guida spiega come mettere in funzione una stazione a partire da un
pacchetto creato con `pack_service.py` (vedi il `README.md` alla radice per
come generarne uno) — il servizio Python più, se è stato compilato insieme,
il client desktop Electron alla stessa versione.

## Cosa c'è nel pacchetto

```
opas-dl-service-<versione>/
  src/                  sorgente del servizio (driver, config, output)
  start.bat / start.sh  avviano il servizio (creano l'ambiente virtuale al primo avvio)
  requirements.txt      dipendenze Python, generate al momento del packaging
  docs/                 questa documentazione
  OPAS DL Neo <versione>.exe   installer del client desktop (se compilato insieme al servizio)
```

## Requisiti

- Python 3 installato e presente nel PATH di sistema (verificabile con
  `python --version` o `python3 --version`)
- Connessione internet la prima volta che avvii il servizio, per installare
  le sue dipendenze Python
- almeno 8 GB di RAM

## 1. Avviare il servizio

**Windows**: doppio clic su `start.bat` (oppure eseguilo da un prompt dei comandi).
**macOS/Linux**: `bash start.sh`

Al primo avvio lo script crea un virtual environment locale (`venv/`) e
installa le dipendenze da `requirements.txt` - può richiedere qualche
minuto. Agli avvii successivi parte subito, senza reinstallare nulla.

Il servizio resta in esecuzione nella finestra del terminale aperta da
questi script: lasciala aperta finché ti serve il servizio attivo, chiudila
(o Ctrl+C) per fermarlo. Non è possibile avviare due copie del servizio
insieme sulla stessa macchina: una seconda copia si accorge della prima ed
esce subito con un errore, senza toccare quella già in esecuzione (vedi
[architecture.md](architecture.md) per la sequenza di avvio, incluso questo
controllo).

## 2. Avviare il client desktop

Avvia il file `.exe` incluso nel pacchetto. Al primo avvio, apri
Impostazioni e imposta il percorso di **questa cartella** (quella che
contiene `src/`, `start.bat`/`start.sh`) come `opasDlPath` - è quello che
permette al client di trovare la config, i log e i dati del servizio.