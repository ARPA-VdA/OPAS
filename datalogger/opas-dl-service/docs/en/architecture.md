# Architecture

## What this service is

`opas-dl-service` is the data-acquisition backend for an OPAS environmental
monitoring station. It runs one or more **driver** processes, each polling a
single instrument ("module"), and exposes their status and controls over a
local HTTP API. It has one client: the `opas-dl-neo` Electron desktop app,
running on the same machine. See [driver-contract.md](driver-contract.md) for
the driver side of this, and [control-api.md](control-api.md) for the HTTP
side.

## Process model

```
service_master.py (top-level process)
 ├─ output_broker_manager  → one "output-broker" process (always started)
 ├─ shared_serial_ports    → zero or more "serial-broker-<COM>" processes
 │                            (only for COM ports shared by ≥2 modules)
 ├─ driver_manager         → one process per active module (driver.py)
 └─ control_server         → FastAPI/uvicorn, daemon thread, 127.0.0.1:8080
```

Every child above is a separate OS process (`multiprocessing.Process`), not a
thread — drivers, brokers, and the master must not (and cannot, on Windows'
`spawn` start method) share memory or module-level state. The control server
is the one exception: it runs as a daemon **thread** inside the master
process, because it needs synchronous access to `driver_manager`'s in-memory
registry.

### Startup sequence (`service_master.main()`)

1. **Singleton lock.** Before anything else, the top-level process binds an
   exclusive loopback TCP port (`127.0.0.1:47990`) purely as a cross-platform
   mutex — never actually served. A second launch fails this bind and exits
   immediately, before touching logs or config. This check is guarded by
   `__name__ == "__main__" and multiprocessing.current_process().name ==
   "MainProcess"` — both conditions are needed: the process-name check alone
   excludes the driver/broker child processes Windows' `spawn` creates by
   re-executing this same module (those still see `__name__ == "__main__"`,
   but never `"MainProcess"`), while the `__name__` check remains a defense
   against a *second*, same-process import of this module under the name
   `"service_master"` (as opposed to `"__main__"`, the name it was first
   loaded under). Such a reimport would re-execute this whole file from
   scratch as a distinct module whose `main()` never ran — so
   `driver_manager`, `shared_serial_ports`, `output_broker_manager` (only
   assigned inside `main()`) would read back as `None` there, and
   `request_restart()` read off that copy would have
   `_stop_drivers_and_brokers()` raise `AttributeError` on every stop attempt
   (caught and logged, not fatal) — leaving every actually-running
   driver/broker holding its own inherited duplicate of the lock socket, so
   the freshly `execv`'d process fails to reacquire port 47990 and
   immediately exits with "another instance is already running". This used
   to happen because `control_server.py`'s `POST /service/restart` handler
   fetched `request_restart` via a lazy `from service_master import
   request_restart`, which is exactly what makes Python create that second
   module; it now fetches it from `sys.modules["__main__"]` instead — the
   already-running instance whose `main()` actually populated that state —
   so the reimport, and the error chain it caused, no longer happens (see
   [control-api.md](control-api.md)).
2. `service_init.configure()` creates the runtime directories (drivers, logs)
   and configures logging via `logging.config.dictConfig`. This runs
   at **module import time**, not inside `main()` — it must happen before any
   other import that logs. It's guarded by the exact same `__name__ ==
   "__main__" and ... "MainProcess"` condition as the singleton lock, for the
   same reason: without it, a same-process reimport (were one to happen) or
   every driver/broker child process would re-run it too, deleting and recreating `GENERAL_LOG`/`WEB_LOG`
   while the real process's handlers still hold them open — on Windows this
   raises `PermissionError` (`WinError 32`) on the `unlink()`, caught and
   logged as an "Error setting up GENERAL_LOG/WEB_LOG" warning. Children don't
   need its side effects: the directories it creates already exist by the time
   any child is spawned, and the `LIBS_DIR` `sys.path` insertion they need
   happens unconditionally in `service_init.py`'s own module-level bootstrap,
   independent of `configure()`.
3. `load_active_config()` resolves and parses the active JSON config (see
   [Config resolution](#config-resolution) below).
4. The output broker starts (`output_broker_manager.start()`) and
   `driver_manager.set_output_context()` binds every driver launched from
   here on to the same broker `Queue`.
5. `load_drivers_dict()` loads `opas_dl_commons/drivers/drivers_dict.json`,
   mapping each `ModuleType` code to a driver folder path
   (`driver_manager.resolve_driver_for_module()` resolves this relative to
   `drivers/`; it can be a bare name or a nested path like
   `Acme/MyInstrument` to group drivers by brand/family — see
   [Registration](driver-contract.md#8-registration)).
6. `shared_serial_ports.prepare_modules()` rewrites any module whose
   `ComPortName` is shared by another active module to point at a broker
   process instead of the raw serial port (see
   [Shared COM ports](#shared-com-ports)).
7. For each active module in the config, the matching `driver.py` is resolved
   via `drivers_dict` and launched as a `multiprocessing.Process`, with the
   module's own JSON config serialized into the `MODULE_CONFIG` environment
   variable (see [driver-contract.md](driver-contract.md)).
8. `start_control_server()` starts FastAPI/uvicorn on a daemon thread.
9. The main loop registers `SIGINT`/`SIGTERM` handlers and then just polls
   driver liveness every 30 seconds, logging a warning for any dead process,
   until a shutdown signal sets `shutdown_event`.

### Shutdown and restart

`SIGINT`/`SIGTERM` and `POST /service/restart` (see
[control-api.md](control-api.md)) both funnel into the same
`_stop_drivers_and_brokers()` routine: stop every driver via
`driver_manager.stop()`, then `shared_serial_ports.shutdown()`, then
`output_broker_manager.shutdown()`.

That's the cooperative path, driven by the parent. Independently of it, the
output broker and serial-port broker processes (`output_broker.run_broker()`,
`serial_port_broker.run_broker()`) also call
`common.setup_signal_handlers()` themselves, same as every SDK-based driver
process - on POSIX, Ctrl+C's SIGINT reaches every process in the foreground
process group directly, not just the parent, so without this a broker
process hitting a blocking call (`queue.get()`, `socket.accept()`) would take
Python's default SIGINT behavior and raise an uncaught `KeyboardInterrupt`
instead of exiting through its normal loop (and its `save_state()`/cleanup).

A restart additionally closes the
singleton lock socket and calls `os.execv()` to replace the process image in
place (same PID) rather than forking a new one — the lock socket must be
closed explicitly first since the OS only releases `CLOEXEC` descriptors at
the moment of `exec`, and the new image's top-level code re-binds that same
port immediately.

## Config resolution

`resolve_active_config_path()` in `opas_dl_commons/libs/runtime_paths.py` is
the single source of truth, used by both `service_master.load_active_config()`
and the control server's channel/module-save endpoints so they always agree
on the same file:

1. `CONFIG_PATH` / `CONFIG_FILE` env var — an explicit file path.
2. `CONFIG_DIR` / `CONFIG_ACTIVE_DIR` env var — an explicit directory; the
   first `*.json` file inside it (sorted) is used.
3. Default candidate directories relative to the runtime root, in order:
   `config/active` under the runtime root, its parent, and its
   grandparent, then `./config/active` relative to the current working
   directory.
4. PyInstaller's `_MEIPASS/config/active`, as a frozen-build fallback.

Do not add a new resolution path anywhere except this function — every
config-reading call site depends on it agreeing with every other.

## Path resolution (`RuntimePaths`)

`opas_dl_commons/libs/runtime_paths.py` also defines `RuntimePaths`, a
thread-safe singleton that computes the runtime root (the script directory
when run from source, the executable's directory under PyInstaller) and
loads `folder_config.json` to resolve every other path
(`OPAS_COMMONS_DIR`, `DRIVERS_DIR`, `CONFIG_ACTIVE_DIR`, `LOGS_DIR`,
`OUTPUT_DIR`, `OPAS_NEO_DATA_DIR`, `GENERAL_LOG`, `WEB_LOG`, ...) relative to
it. `core/service_init.py` bootstraps `sys.path` so this module is importable
regardless of whether the caller lives in `src/core/` or
`opas_dl_commons/libs/`, then re-exports these as module-level constants
(`BASE_DIR`, `LOG_DIR`, `OUTPUT_DIR`, ...) for the rest of the codebase to
import from `service_init` rather than recomputing them.

## Shared COM ports

`core/shared_serial_ports.py` detects modules with `ComunicationType == 0`
(serial) that share the same `ComPortName`. When ≥2 active modules collide on
one port, it starts a single `serial_port_broker` process for that port and
rewrites every colliding module's config to look like a normal TCP/IP module
pointing at `127.0.0.1:<broker port>` instead — drivers and `comm_manager.py`
never know the broker exists. Modules that don't collide with anything pass
through unchanged. The first module in each colliding group's serial settings
(baud rate, timeout, data/parity/stop bits) win; a mismatch from another
module in the group is logged as a warning, not an error.

## Formule (raw-reading transform)

Before any of the below: if the SDK (`driver_sdk.run_driver()`) is used,
`Channel["Formule"]` transforms a channel's raw instrument reading into the
real measurement (e.g. `"y=x/1000"`) right after `read_channel()`/
`read_all_channels()` returns a value, before a `Reading` even exists - so
`output_manager`/`output_broker` (below) never see the raw value, only the
transformed one. It's evaluated by a hand-written AST walker in
`opas_dl_commons/libs/formula.py` (never `eval()`/`exec()` - only a small
whitelisted arithmetic grammar), not by anything in this broker layer. See
[driver-contract.md](driver-contract.md) section 3.2 for the full grammar
and failure-handling rules.

## Output broker

Unlike the COM-port broker, `core/output_broker_manager.py` **always**
starts one `output-broker` process per service instance, regardless of how
many modules are configured — because the OPAS NEO output format
(`file_istantanei/<STATION_HEADER>.dat` etc., see
[driver-contract.md](driver-contract.md) section 5) is a per-station file
set that a second module, or even a single driver restart, can start writing
to at any time. Every driver process receives the same `multiprocessing.Queue`
via `output_manager.configure()`, so all writes to disk happen from the one
broker process and concurrent writes to the same file never occur.

### Hourly means (`files_medie_csv` / `files_medie_dat`)

Alongside the instantaneous files, `output_broker.py` also accumulates and
writes hourly per-channel averages ("targata anticipata": the `06:00:00` row
summarizes readings from `06:00:00` to `06:59:59` — see
[driver-contract.md](driver-contract.md) section 5 for the exact row format).
Each `Reading` now carries its channel's averaging config
(`mean_interval`, `polling_interval`, `readings_min_percentage`,
`detection_limit`, `allowed_min_value`/`allowed_max_value`,
`negative_value_set_to_zero`, `decimals`, `algorithm`) since the broker only
ever sees bare `Reading` objects, never a module's full config. `decimals`
(from `Channel["Decimals"]`) rounds every value written to disk, but the
timing differs by file: instantaneous files round each reading as it's
written, while `_HourBucket` accumulates its running sum/min/max/stddev
unrounded and only rounds once, on the finished mean at the hour boundary —
never on the readings that fed it.

`algorithm` (from `Channel["Algorithm"]`, the legacy VB.NET aggregation enum
— see `output_manager.Algorithm` and [driver-contract.md](driver-contract.md)
section 5.3.1 for the full code table) picks which of `_HourBucket`'s
streaming statistics becomes `VAL`: a small module-level function per
algorithm (`_agg_average`, `_agg_total`, `_agg_sample`, `_agg_bit_or`,
`_agg_counter_diff`, `_agg_max`, `_agg_min`) rather than one branching block,
dispatched through `_ALGORITHM_HANDLERS`, so each is independently callable
and testable. `MIN`/`MAX`/`STDDEV` are always the true statistics regardless
of `algorithm`; codes without a handler (`WindVectorSpeed`, `WindVectorDir`,
`RainType`) fall back to `_agg_average` with a logged warning instead of
breaking the channel.

An in-memory `_HourBucket` per channel accumulates streaming sums (no raw
reading is stored) until its hour is provably over — either because that
same channel's next reading arrives with a later hour, or because
`run_broker()`'s own read loop (`in_queue.get(timeout=1.0)`, the only
scheduler primitive in this codebase) checks on every pass whether any
bucket's hour has elapsed, so a channel that goes silent for a whole hour
still gets a flushed row (all fields empty/zero, `P.COD` includes `128`)
instead of being silently skipped.

Because the broker is a separate process, an in-progress bucket would
otherwise be lost on every service restart. `run_broker()` persists all
open buckets to `{PYOUT_DIR}/hourly_buckets_state.json` on a clean shutdown
and reloads it on the next startup — but only resumes a bucket whose hour is
still the current one; a bucket for an hour that has already elapsed is
incomplete and is discarded rather than flushed or resumed.

Only the `P.COD` bits with an actual config value behind them are ever set:
`0` (valid), `128` (coverage below `ReadingsMinPercentage`), `512`/`1024`
(`DetectionLimit` band), `2048`/`4096` (`AllowedMinValue`/`AllowedMaxValue`
breached by any instant reading in the hour). `S.COD` is always `0`. Bits
`1`/`2`/`4`/`8` (span/zero tolerance), `16`/`32`/`64` (calibration/maintenance),
and `8192` (instant variation) are reserved by the format spec but never
emitted — no tolerance/threshold values exist anywhere in the config schema
to source them honestly (see [driver-contract.md](driver-contract.md)
section 5 for the full rationale).

## Log level

`LogLevel` is a station-wide default with a second, per-module layer and no
auto-restart. The station-wide default (`Config["LogLevel"]`, default
`"INFO"`) is set from the Electron UI's "Impostazioni" page via
`GET|POST /logging` (see [control-api.md](control-api.md)) and applied
immediately, in place, to the service-master's own logs
(`service_init.set_log_level()` - it only calls `setLevel()` on
already-constructed loggers/handlers, never `logging.config.dictConfig()`
again, which would reopen and truncate `service.log`/`web.log`).

This default is **not** copied into every module's config ahead of time -
each driver process only ever sees its own `Module`, never the station
config (see [driver-contract.md](driver-contract.md) §3.2 for the constraint
this creates), and baking the default in early would go stale the moment it
changes. Instead, an individual module may carry its own `LogLevel`
override, and `driver_manager.launch_driver()` - the single choke point
`start()`, `restart()`, and the initial startup launch all go through -
resolves "override, else the current station default read fresh from disk"
at the exact moment a process is spawned, without mutating the registry's
stored (still-unresolved) `module_config`. So a station-default change, or a
per-module override change (edited like any other module field via `POST
/modules/{module_id}`), both take effect the same way as any other
module-level config change: on that module's next restart, not immediately.

## The two communication channels with Electron

1. **File system (measurement data), read-only from Electron.** Drivers
   write through the output broker to
   `{opasDlPath}/src/py_out/data/` (`file_istantanei`, `files_letture_csv`,
   `files_letture_dat`, `files_medie_csv`, `files_medie_dat`) in the OPAS NEO
   format — a fixed network contract
   also consumed by an external "centro" parser, so the row layout must
   never gain or lose a column. Electron's `resourceManager.ts` polls
   `file_istantanei/<DataFileHeader>.dat` every second. A parallel
   `file_istantanei_raw/<DataFileHeader>.dat` (same row format, same polling)
   carries the pre-`Formule` raw reading for display next to the converted
   value in the UI — it is **not** part of the centro network contract (see
   driver-contract.md §5.4). A legacy per-module
   `.txt`/`.csv` file under `{opasDlPath}/src/py_out/output/` still exists
   for drivers that write it (see driver-contract.md §5.2) and is used by
   Electron only as a fallback when no OPAS NEO file is found yet.
2. **HTTP control API (driver status and control), `127.0.0.1:8080`.** Called
   directly by the Electron **main process** (never the renderer) — see
   [control-api.md](control-api.md) for every endpoint.

Config flows one way: Electron reads `Config-*.json` from this service's
folder but never writes it directly. The one exception is editing a
channel's or module's fields from the instrument detail UI, which goes
through `POST /modules/{id}` / `POST /modules/{id}/channels/{id}` — this
service remains the sole writer of the file, merging the patch in and
updating the driver's in-memory config too if it's currently running.

**Config file layout: exactly one active, everything else in samples/.**
`config/active/` always holds exactly one file — the config in effect for
the current/next process start. Every other config file — bundled templates
and anything the user duplicates, creates blank, or imports from the
Configurazioni page — lives in `config/samples/`. Switching which one is
active (`POST /configs/{filename}/activate`, see
[control-api.md](control-api.md)) swaps the two locations rather than
copying: the file previously in `active/` moves into `samples/`, and the
chosen `samples/` file moves into `active/`. The three module/channel-editing
endpoints above (`POST /modules`, `POST /modules/{id}`,
`POST /modules/{id}/channels/{id}`) all accept an optional `?config=`
filename so the Configurazioni page can add/edit instruments on any config
file, not only the active one — in-memory driver sync is skipped whenever
the target isn't the active config, since `driver_manager`'s registry only
ever reflects drivers actually launched from it. Creating a config
(`POST /configs`) only ever writes into `samples/`, never `active/`.
