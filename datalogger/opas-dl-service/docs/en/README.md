# OPAS DL Service — documentation index

This folder is the documentation for `opas-dl-service`, the Python
data-acquisition backend of the OPAS DL desktop application. It is consulted
from the Electron client (opas-dl-neo) under *Impostazioni → Documentazione*,
and can be read directly as markdown.

| Document | Covers |
|---|---|
| [install.md](install.md) | Getting a station running from a packaged folder (or from source): starting the service, starting the desktop client, where to look when something's wrong. |
| [architecture.md](architecture.md) | Process model, startup sequence, config resolution, the two communication channels with the Electron client. |
| [control-api.md](control-api.md) | Every endpoint of the HTTP control API (`127.0.0.1:8080`): request/response shapes, error cases. |
| [driver-contract.md](driver-contract.md) | The self-contained contract a `driver.py` must satisfy — environment variables, output file format, the optional SDK. Written for third parties who only need this one file. |
| [sdk-guide.md](sdk-guide.md) | Schematic walkthrough of `driver_sdk.py` (`BaseDriver` + `run_driver()`) for anyone building a driver on top of the optional SDK instead of the raw contract, with a worked example. |

This is the English copy — see [../it/](../it/README.md) for Italiano. Keep
both in sync when either changes.

## Keeping this up to date

These documents describe *behavior*, not just structure — they need to stay
accurate as `service_master.py`, `control_server.py`, `driver_manager.py`,
and the driver SDK evolve, and both language copies need to stay in sync
with each other. When a change touches documented behavior, update the
relevant doc(s), in both languages, as part of that same change.
