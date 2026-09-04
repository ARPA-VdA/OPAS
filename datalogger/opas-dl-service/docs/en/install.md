# Installing and running OPAS DL Neo

This covers getting a station up and running from a package produced by
`pack_service.py` (see the root `README.md` for how to build one) — the
Python service plus, if it was built alongside it, the Electron desktop
client at the same version.

## What's in the package

```
opas-dl-service-<version>/
  src/                  service source (drivers, config, output)
  start.bat / start.sh  start the service (create the virtual environment on first run)
  requirements.txt      Python dependencies, generated at packaging time
  docs/                 this documentation
  OPAS DL Neo <version>.exe   desktop client installer (if built alongside the service)
```

## Requirements

- Python 3 installed and on the system PATH (check with `python --version` or
  `python3 --version`)
- An internet connection the first time you start the service, to install
  its Python dependencies
- 8 GB of RAM

## 1. Start the service

**Windows**: double-click `start.bat` (or run it from a command prompt).
**macOS/Linux**: `bash start.sh`

On the first run the script creates a local virtual environment (`venv/`)
and installs the dependencies from `requirements.txt` - this can take a
couple of minutes. Later runs start immediately, without reinstalling
anything.

The service keeps running in the terminal window these scripts open: leave
it open for as long as you need the service active, close it (or Ctrl+C) to
stop it. Only one copy of the service can run on a machine at a time - a
second copy detects the first one and exits immediately with an error,
without touching the one already running (see [architecture.md](architecture.md)
for the startup sequence, including this singleton check).

## 2. Start the desktop client

Run the `.exe` included in the package. On first launch, open Settings and
set the path of **this folder** (the one containing `src/`,
`start.bat`/`start.sh`) as `opasDlPath` - that's what lets the client find
the service's config, logs, and data.
