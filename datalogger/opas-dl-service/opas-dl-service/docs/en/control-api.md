# API

FastAPI/uvicorn server started by `core/control_server.py`, bound to
`127.0.0.1:8080` only (never exposed beyond localhost). Started as a daemon
thread from `service_master.main()` so it shares the same process — and the
same `driver_manager` in-memory registry — as the rest of the service. Called
directly by the Electron **main process** (`main.ts`); the renderer never
reaches it directly, it always goes through an IPC channel. See
[architecture.md](architecture.md) for how this fits into the rest of the
service.

All error responses are `HTTPException` with a JSON body `{"detail": "..."}`.

## `GET /drivers`

Returns every registered driver's status, keyed by instrument ID.

```jsonc
{
  "1": {
    "instrument_id": "1",
    "name": "API 400",
    "alive": true,
    "pid": 12345,
    "model": "API 400",            // from drivers_dict.json, keyed by ModuleType
    "brand": "Teledyne",
    "driver_version": "1.0.0",
    "start_time": "2026-07-24T14:32:10",  // ISO 8601, null if never started
    "uptime_seconds": 3600,               // null unless alive
    "connection": {
      "type": "TCP/IP",                   // "TCP/IP" | "UDP" | "Modbus Ethernet" | "HTTP" | "Serial" | "Modbus Seriale" | "PipeFile" | null
      "host": "192.168.1.10",             // TCPIPAddress (Ethernet/HTTP types), "COM<n>" (Serial types), or PipeFileName (PipeFile)
      "port": 3000,                       // TCPIPPort, null for anything else
      "baud_rate": null                   // ComPortBauds, null for anything but Serial/Modbus Seriale
    },
    "driver_file": "API_400/driver.py",   // relative to the drivers/ folder
    "shared_com_port": null,              // set when this module was rewritten onto a shared_serial_ports.py broker (the real COM port name); null otherwise
    "shared_with": []                     // instrument IDs of the other modules sharing that same port, empty when not shared
  }
}
```

The underlying `ComunicationType` is resolved via `comm_manager.normalize_comunication_type()` before building `connection` — the same helper `create_channel()` uses — so a not-yet-migrated legacy `ComunicationType: 2` (generic Modbus, see comm_manager.py) is correctly reported as `"Modbus Seriale"` or `"Modbus Ethernet"` here too, not just when actually creating the channel.

`shared_com_port`/`shared_with` only ever appear for modules whose `ComunicationType` was `0` (plain Serial) *and* whose `ComPortName` collides with another active module's — `shared_serial_ports.py` tags the rewritten module config with `_SharedComPortName` before it's handed to `launch_driver`, and `list_drivers()` just surfaces that tag plus the sibling grouping. `connection` for a shared module still reports `type: "TCP/IP"` pointing at the broker's `127.0.0.1:<port>` (that's genuinely how the driver process talks to it) — `shared_com_port` is what tells you it's actually a relayed serial port underneath. Modbus Seriale (`5`) is deliberately never part of this — see the comment in `shared_serial_ports.py` for why the broker can't carry Modbus framing.

## `GET /driver-catalog`

Lists every driver **folder** under `drivers/` — installed driver code on
disk, regardless of whether any module in the active config currently uses
it. Distinct from `GET /drivers` above, which lists currently *registered*
driver processes (only modules already in the active config). Read-only: no
process is started, stopped, or otherwise touched. Powers the UI's driver
exploration page.

Built by `driver_manager.get_driver_catalog()`: walks `drivers/` for every
`driver.py`, cross-references each folder's path against `drivers_dict.json`'s
`Drivers` values (one folder can serve several `ModuleType`s — e.g.
`API/API_XXX` covers 100/200/300/400), and cross-references those
`ModuleType`s against the active config's `Modules[]` to list which
instruments currently resolve to that folder. A folder with no
`drivers_dict.json` entry still appears, with empty `moduleTypes`/
`instruments` — useful for spotting orphaned driver folders. The one
exception: any folder (at any depth) whose name starts with `_` is pruned
from the walk entirely and never appears in the catalog — e.g. `_examples/`,
a documentation fixture `drivers_dict.json` deliberately never references
(see its `sdk_example_driver/driver.py` docstring), not an installed driver.

```jsonc
{
  "drivers": [
    {
      "path": "API/API_XXX",       // relative to drivers/, "/"-separated -
                                    // matches drivers_dict.json's "Drivers" value
      "group": "API",              // first path segment - the natural
                                    // brand/family grouping for the UI
      "folderName": "API_XXX",     // last path segment
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

- `200` always — an unresolvable active config (missing/corrupt) degrades to
  an empty `instruments` list per driver rather than failing the whole
  request, since the catalog is still useful without it.

`model`/`brand`/`driver_version` come from `drivers_dict.json`'s
`Name`/`Producer`/`Version` fields for that module's `ModuleType`, not from
the driver process itself — a driver never has to report its own identity.

## `GET /drivers/{driver_id}/start`

Starts a currently-stopped driver using its last-known `driver_file` and
`module_config` from the registry.

- `200 {"result": "started", "pid": <int|null>}`
- `404` — driver ID not in the registry.
- `409` — already running (`RuntimeError` from `driver_manager.start()`).

## `GET /drivers/{driver_id}/stop`

Terminates a running driver: `SIGTERM`-equivalent, 5 s grace period, then
`SIGKILL`-equivalent if still alive (see
[driver-contract.md](driver-contract.md) §9 for what this means for the
driver on Windows).

- `200 {"result": "stopped"}`
- `404` — driver ID not in the registry.
- `409` — not currently running.

## `GET /drivers/{driver_id}/restart`

Stops (if running) then relaunches the driver with its current in-memory
`module_config` — which reflects any channel/module patch applied since it
was last started, even if the patch happened while it was running.

- `200 {"result": "restarted", "pid": <int|null>}`
- `404` — driver ID not in the registry.

## `POST /modules/{module_id}/channels/{channel_id}?config={filename}`

Patches one channel's fields and persists them to a config file. Body is a
partial JSON object of the fields to change (raw PascalCase keys, same shape
as the config file — see `opasConfigManager.ts` on the Electron side for the
camelCase↔PascalCase mapping). This service is the sole writer of the config
file; the read-merge-write is not atomic across concurrent requests.

`config` (query param, optional) targets one specific filename instead of the
active config — the active file if its name matches, otherwise a file in the
samples library (see `POST /configs` and `POST /configs/{filename}/activate`
below). Omitted, it targets the active config exactly as before — every
pre-existing caller (the Strumenti page) never sends it. In-memory driver
sync (below) only happens when the target actually is the active config:
`driver_manager`'s registry only ever reflects drivers launched from the real
active config, so syncing it for an arbitrary samples/ file could collide
with an unrelated `module_id`/`channel_id` that happens to also exist there.

Flow: read the target config → find `module_id` in `Modules[]` → find
`channel_id` in that module's `Channels[]` → `dict.update(patch)` → write to
a `.tmp` file and `os.replace()` it over the original (atomic on both POSIX
and Windows) → if targeting the active config and the module's driver is
currently registered, also patch its in-memory `module_config` (so a later
restart picks up the new value without needing to reread the file).

```jsonc
// Request body example
{ "Active": false, "PollingInterval": 30 }
```

- `200 {"success": true, "channel": {...}}` — the full channel object after
  the patch.
- `404` — config file not found, module not found, or channel not found.

## `POST /modules/{module_id}?config={filename}`

Same read-merge-write flow as the channel endpoint, but for the module's own
fields (not its channels). The `Channels` key is stripped from the patch
before applying it — this endpoint cannot be used to bulk-replace a module's
channel list. Same optional `config` query param as the channel endpoint
above (in-memory driver sync only applies when targeting the active config).

When targeting the active config, if the patched module's `Active` flag is
now on (or was already on) and it has no registry entry yet, the driver is
*registered* here too — the same `resolve_driver_for_module()` +
`register_driver()` step `POST /modules` does for a brand-new module (see
below), so re-enabling a module that was `Active: false` at service startup
(and therefore skipped by the startup loop entirely, see architecture.md)
doesn't need a full service restart to become startable. This only registers
(alive: false placeholder); nothing is launched here — the Electron "enable
instrument" switch always follows this save with a call to
`GET /drivers/{id}/restart` (above), which relaunches whenever the registered
entry isn't currently running, including a freshly-registered one that was
never launched at all. Skipped if the module is already registered, since
re-registering would overwrite the registry entry and could orphan an
already-running process reference.

- `200 {"success": true, "module": {...}}`
- `404` — config file not found or module not found.

## `POST /modules?config={filename}`

Creates a brand new module (instrument) and appends it to a config file.
Unlike the two endpoints above (which patch an existing module/channel), the
request body is a *full* module object — including its `Channels` array —
typically built on the Electron side by merging `drivers_dict.json`'s
`FullConfig` template with the chosen instrument type's `DefaultConfig` (see
`opasConfigManager.ts`'s `getNewInstrumentDraft()`). Same optional `config`
query param as above — targets a samples/ file (e.g. one not yet activated)
instead of the active config.

The server remains the sole writer and guarantees uniqueness of the three
fields that matter for correctness *within that file*: it recomputes the
module's own `ID`, and within it, each channel's `ID` (sequential, 1-based
within the new module) and `DatabaseId` (sequential, continuing from the
highest `DatabaseId` already used anywhere in that file) — any values sent by
the client for these three fields are ignored and overwritten. Every other
field, including each channel's `Position`, is written exactly as sent.

When (and only when) targeting the active config, the driver is *registered*
but not launched: this endpoint resolves the new module's `ModuleType`
through `drivers_dict.json` the same way `service_master.py`'s startup
sequence does for every module, via `driver_manager.resolve_driver_for_module()`,
then calls `driver_manager.register_driver()` so it immediately shows up in
`GET /drivers` with `alive: false` — i.e.
controllable from the UI's start icon — without launching the process and
without touching any other already-running driver. A separate call to
`GET /drivers/{id}/start` (above) is what actually launches it; no full
service restart is needed just to make a new instrument startable. Skipped
(no registration) if the module is inactive (`Active: false`) or its
`ModuleType` doesn't resolve to a known driver — same as a full restart would
do for that module. A module created in a samples/ file becomes registrable
this same way once `POST /configs/{filename}/activate` makes that file active
(followed by a restart, or a repeat of this call).

```jsonc
// Request body example (abbreviated)
{ "ModuleType": 100, "Name": "SO2 Analyzer", "Channels": [ { "Name": "SO2", "Unit": "ppb", ... } ], ... }
```

- `200 {"success": true, "module": {...}}` — the full module object as
  written, including the server-assigned `ID`/`Channels[].ID`/`Channels[].DatabaseId`.
- `404` — config file not found.

## `POST /configs/{filename}/station`

Patches a config's station-level fields — `Name`, `StationLocation`,
`DataFileHeader`, `StationLatitude`/`StationLongitude`/`StationAltitude`, and
so on — never its `Modules` list (stripped from the patch, same guard
`POST /modules/{id}` applies to `Channels`). `filename` is always required:
unlike the module/channel endpoints, there is no pre-existing caller that
assumes "the active config" implicitly — the Configurazioni page always knows
which file it's editing, active or in the samples library.

No driver in-memory sync happens here (unlike `save_module`/`save_channel`):
station-level fields aren't part of any driver's own `MODULE_CONFIG` env var,
so there's nothing on a running driver to keep in sync — the effect is
purely on the file (and, for the active config, on how Electron displays it
next read).

```jsonc
// Request body example
{ "Name": "Backup Site", "StationLocation": "Plouves", "DataFileHeader": "backup" }
```

- `200 {"success": true, "data": {...}}` — the full config object after the patch.
- `400` — invalid filename.
- `404` — config file not found.

## `POST /configs`

Creates a new config file in the samples library — never directly active,
see `POST /configs/{filename}/activate` for that. Listing/reading configs has
no HTTP endpoint: like the active config today, Electron reads the samples
library directly off disk (`opasConfigManager.ts`), since these are plain
reads and the two-channel architecture only routes *writes* through this API
(see [architecture.md](architecture.md)).

Three modes, chosen by `body.mode`:

- `"duplicate"` — copies `body.sourceFilename` (the active file, or one
  already in the samples library), then applies `body.fields` (optional) as a
  shallow overlay of station-level keys (e.g. `Name`/`StationLocation`/
  `DataFileHeader`).
- `"blank"` — starts from `{"Modules": []}` and applies `body.fields` on top.
- `"import"` — `body.content` is a full config object already read
  client-side (e.g. from a file picker) and saved as-is except for the
  filename.

`body.filename` is always required: a bare name (no path separators — rejects
path traversal outside the samples directory) ending in `.json`, and must not
collide with an existing file (active or already in samples/).

```jsonc
// Request body example (duplicate)
{ "mode": "duplicate", "filename": "Config-Backup-Site.json",
  "sourceFilename": "Config-Neo-Demo.json",
  "fields": { "Name": "Backup Site", "DataFileHeader": "backup" } }
```

- `200 {"success": true, "filename": "..."}`
- `400` — invalid/missing filename, invalid `mode`, missing `sourceFilename`
  for `mode="duplicate"`, or non-object `content` for `mode="import"`.
- `404` — `mode="duplicate"` and `sourceFilename` doesn't exist.
- `409` — a config with that filename already exists.

## `POST /configs/{filename}/activate`

Makes `filename` (currently in the samples library) the active config: swaps
the two locations — whatever is currently in `active/` moves into the
samples library (keeping its own filename), and `filename` moves from
samples/ into `active/`. `active/` always holds exactly one file; every other
config, whether a bundled template or one the user created, lives in
samples/.

This only changes which file the *next* full restart (`POST /service/restart`)
or newly-launched driver reads — already-running drivers keep whatever config
they were launched with, same "requires restart to take effect" precedent as
the module/channel patch endpoints above. The Electron UI is expected to ask
the user whether to restart now.

- `200 {"success": true, "activeFilename": "..."}`
- `400` — invalid filename.
- `404` — `filename` not found in the samples library (e.g. it's already the
  active one).

## `GET /logging`

Reads the station-level default log level (`Config["LogLevel"]`) from the
active config.

- `200 {"level": "INFO"}` — `"INFO"` (not an error) if the config file cannot
  be found or has no `LogLevel` set.

## `POST /logging`

Sets the station-level default log level, persists it, and applies it
**immediately** to the service-master's own logs (`service.log`/`web.log`) -
no restart needed for that part.

This does **not** touch already-running driver processes: a module without
its own `LogLevel` override picks up the new default the next time *it*
restarts (same "requires restart to take effect"
precedent as a module/channel patch, see `POST /modules/{module_id}` above),
resolved fresh at that moment by `driver_manager.launch_driver()` - not
propagated here. A single instrument's log level can be overridden
independently of this station-wide default via its own `Module["LogLevel"]`
field, patched through the ordinary `POST /modules/{module_id}` endpoint like
any other module field (e.g. `PollingInterval`) - there is no dedicated
endpoint for the per-module override.

```jsonc
// Request body
{ "level": "DEBUG" }
```

```jsonc
// Response
{ "success": true, "level": "DEBUG" }
```

- `400` — `level` is not one of `DEBUG`, `INFO`, `WARNING`, `ERROR`.
- `404` — config file not found.

## `POST /service/restart`

Restarts the **whole master process**, not a single driver: stops every
driver and broker cleanly, then `os.execv()`s the same process image back
into existence (see [architecture.md](architecture.md#shutdown-and-restart)).
The HTTP response is sent before the process image is replaced (the restart
runs on a background thread with a short delay), so the caller reliably sees
the `"restarting"` result even though the process that sent it is about to
disappear.

- `200 {"result": "restarting"}`
