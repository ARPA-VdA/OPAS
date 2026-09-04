# Drivers

This document is the entire contract between a driver process and the rest
of the OPAS NEO service. You do not need access to any other file in this
repository to write, test, and ship a driver — everything you need to know
is here.

Using the optional SDK described in section 6 is never required. You can
write a `driver.py` from scratch, with zero imports from this codebase, as
long as it follows sections 2–5.

## 1. What a driver is

A driver is a single Python file, `driver.py`, that polls one instrument
("module" in the station config) on an interval and reports its readings.
One driver **process** exists per configured module instance — if a station
has two of the same instrument, two separate processes run your `driver.py`,
each with its own environment (section 3).

## 2. How your `driver.py` is invoked

The service starts your file roughly as:

```python
runpy.run_path("driver.py", run_name="__main__")
```

In practice this is equivalent to running `python driver.py` from the
command line:

- Your module-level code runs top to bottom immediately.
- `__name__ == "__main__"` is `True`, so your `if __name__ == "__main__":`
  block runs.
- There is **no `sys.argv`** — nothing is passed as a command-line argument.
- **stdout/stderr are not captured** by the service. Anything you `print()`
  is lost or mixed into a shared console, depending on how the service
  itself was started. **You must set up your own file logging** if you want
  logs (or use `common.configure_driver_logging()` / the SDK, which does
  this for you — see section 6).

## 3. Environment variables you receive

| Variable | Meaning |
|---|---|
| `INSTRUMENT_ID` | Stable string identifier for this module instance (e.g. its configured `ID` or `Name`). |
| `DRIVER_LOG` | Absolute file path you should log to, if you're doing your own logging. |
| `MODULE_CONFIG` | JSON-encoded object describing **this module only** — never the whole station config, never other modules. |

Nothing else is injected into your process. No database connection, no
network handle, no shared memory — only these three environment variables.

### `MODULE_CONFIG` field reference

```jsonc
{
  "ID": 1,
  "Name": "API 400",
  "ModuleType": "400",
  "Active": true,
  "PollingInterval": 10,                 // seconds between polling cycles
  "LogLevel": "INFO",                    // resolved (own value, or the station default) by driver_manager before launch - see section 3.2 — SDK only
  "ComunicationType": 1,                 // 0=Seriale, 1=Ethernet TCP/IP, 3=PipeFile, 4=Ethernet UDP, 5=Modbus Seriale, 6=Modbus Ethernet, 7=HTTP — only relevant if you use comm_manager.create_channel() or talk transport yourself. 7 (HTTP) is NOT part of the original VB.NET EnumModuleComunicationType (0/1/3/4/5/6) - added on top of it for drivers that talk HTTP (e.g. CAMPBELL/CR1000/driver.py) so they can also go through comm_manager instead of building requests themselves. The retired generic "2" (Modbus, serial-vs-ethernet auto-detected) is migrated to 5/6 by service_master at startup before you ever see it - see comm_manager.normalize_comunication_type().
  "TCPIPAddress": "192.168.1.10",
  "TCPIPPort": 3000,
  "ComPortName": 6,
  "ComPortBauds": 115200,
  "PipeFileName": "",                    // path to the file the instrument/its own software writes readings into - ComunicationType 3 only
  "PipeFileMissingError": true,          // whether a missing pipe file logs as a warning (true) or debug (false)
  "Channels": [
    {
      "ID": 1,
      "Name": "O3",
      "DatabaseId": 53,                  // -> the "ID" field in the output files, see section 5
      "Address": "PHOTOMEAS",            // instrument-specific, meaning is up to you (Modbus: register address)
      "RegularExpression": "...",        // instrument-specific, meaning is up to you
      "RegisterFunctionCode": 4,         // Modbus only: 1=Coils, 2=DiscreteInputs, 3=HoldingRegisters, 4=InputRegisters
      "RegisterType": 0,                 // Modbus only: 0=Float (2 registers), 1=Integer (1 register/bit)
      "RegisterQuantity": 2,             // Modbus only: registers to read
      "RegisterOrder": 1,                // Modbus only, Float only: 0=LowHigh, 1=HighLow word order
      "Active": true,
      "MeanInterval": 3600,              // seconds per hourly-mean bucket, see section 5.3 — SDK only
      "ReadingsMinPercentage": 75,        // % coverage below which the hourly P.COD gets bit 128 — SDK only
      "DetectionLimit": null,            // -> P.COD 512/1024 in the hourly mean — SDK only
      "AllowedMinValue": null,           // -> P.COD 2048 in the hourly mean if any instant reading is below it — SDK only
      "AllowedMaxValue": null,           // -> P.COD 4096 in the hourly mean if any instant reading is above it — SDK only
      "NegativeValueSetToZero": false,   // clamps a negative reading to 0 before it's used anywhere — SDK only
      "Decimals": 1,                     // rounds VAL (and, in the hourly mean, VAL/MIN/MAX/STDDEV) — SDK only
      "Algorithm": 0,                    // which aggregation produces the hourly mean's VAL — see 5.3.1 — SDK only
      "Formule": "y=x"                   // transforms the raw reading before anything else sees it — see 3.1 — SDK only
    }
  ]
}
```

Only poll channels with `"Active": true`. `DatabaseId` is what must go into
the `ID` column of the output files (section 5) — it is not the same as the
channel's own `ID`. The last nine fields shown above only matter if you use
the SDK's `run_driver()` (section 6) — it reads them off this same dict to
compute the hourly means in section 5.3 (and, for `Formule`, to transform
the reading itself — see 3.1); a from-scratch driver (section 7) that writes
the output files itself is free to ignore them.

An unreachable instrument must always be reported as a missing value
(P.COD 128) — this codebase has no concept of a driver fabricating a
plausible reading to fill the gap.

### 3.1 `Formule`: transforming the raw reading before anything else sees it

`Channel["Formule"]` turns the raw instrument reading (`x`) into the real
measurement (`y`) — e.g. a driver that reads millivolts but the station wants
volts uses `"y=x/1000"`. If you use the SDK, this is applied immediately
after your `read_channel()`/`read_all_channels()` returns a value and
*before* a `Reading` is even constructed — so the transformed value is what
`Decimals` rounds, what `Algorithm` aggregates (section 5.3.1), and what
ends up in every output file. `output_manager`/`output_broker` never see the
raw value at all.

Only the shape `"y=<expr>"` is recognized; anything else (missing, blank,
not starting with `y=`) means "no transform" and the raw reading is used
unmodified — this includes the identity `"y=x"`, the overwhelmingly common
value in existing configs. `<expr>` is a small arithmetic expression over the
single variable `x`:

- Operators: `+ - * / // % **`, unary `+`/`-`, parentheses.
- Functions: `abs`, `min`, `max`, `round`, `sqrt`.
- Numeric literals only. Nothing else - no attribute access, subscripts,
  comprehensions, other names, or other function calls.

This is implemented in `opas_dl_commons/libs/formula.py` as a hand-written
AST walker (`opas_dl_commons.libs.formula.parse_formula`), **never**
`eval()`/`exec()`: the parsed expression tree is checked node-by-node against
an explicit whitelist before it is ever evaluated, so a `Formule` string that
isn't a supported arithmetic expression is rejected outright rather than
silently running arbitrary Python.

Failure handling, both logged once per channel (not once per polling cycle):
- A `Formule` string that fails to parse (bad syntax, or a node/function not
  in the whitelist) is treated as if it were absent — the raw reading is used
  unmodified for that channel for the rest of the driver's run.
- A `Formule` string that parses but fails to *evaluate* for a specific
  reading (e.g. `"y=1/x"` when `x` is `0`) causes that single reading to be
  reported as missing (P.COD 128), not the driver to crash.

`Channel["DataFormule"]` is a distinct, currently-unused config field —
always `null` in every known config, no established meaning, not
implemented by the SDK.

`Channel["Formule"]` is entirely your own responsibility to interpret if you
write the OPAS NEO files yourself (section 5.1, option b) — nothing here
applies to you.

### 3.2 `LogLevel`: two-level log verbosity

`Module["LogLevel"]` controls the verbosity of that module's own driver log
(`driver_{id}.log`) - one of `DEBUG`/`INFO`/`WARNING`/`ERROR`. There are two
levels: a station-wide default (`Config["LogLevel"]`, set from the
Impostazioni page in the Electron UI, or `GET`/`POST /logging` -
[control-api.md](control-api.md)) and an optional per-module override, edited
like any other module field via `POST /modules/{module_id}`.

A driver process only ever receives its own `Module` via `MODULE_CONFIG`,
never the station config (same constraint documented for `DataFileHeader` in
`output_manager.py`), so "override if set, otherwise the current station
default" cannot be resolved inside your driver code, and is not baked into
the config file ahead of time either (that would go stale the moment the
station default changes). It is resolved **once, at the moment a driver
process actually launches**, by `driver_manager.launch_driver()` - the single
place `start()`, `restart()`, and the initial launch at service startup all
go through. If you use the SDK, `run_driver()` reads the already-resolved
value off `module_config["LogLevel"]` and passes it to
`common.configure_driver_logging()`; nothing else to do.

Because resolution happens at launch time, not when the station default
changes, an already-running driver keeps its current level until it is next
restarted - same "requires a restart to take effect" behavior as every other
module-level config field.

If you write the OPAS NEO files yourself (section 5.1, option b) or otherwise
bypass the SDK, `LogLevel` is not applied for you - `common.
configure_driver_logging(level=...)` is available if you want the same
behavior, but you must call it yourself.

## 4. What you must not assume

- No `sys.argv`.
- No captured stdout/stderr — set up your own logging.
- No persistent state across restarts. Every start of your process is a
  brand-new Python interpreter; module-level globals do not survive a
  restart. If you need to remember something across restarts, persist it to
  disk yourself.
- No guaranteed cleanup callback on shutdown — see section 9.
- No health check, ping, or heartbeat is asked of you. The service only
  checks whether your OS process is still alive.

## 5. The one hard requirement: the output file contract

This is the only thing that determines whether your driver "works" from the
system's point of view. It is a **fixed network contract**: a downstream
parser validates every row with a fixed-field regex, so an extra or missing
column breaks ingestion, not just cosmetics.

Every reading you produce must result in rows being written to these files,
under a data root directory and a station header string you do not choose
(both come from the running service — see 5.2 for how to avoid needing to
know either):

| File | Written | Row format |
|---|---|---|
| `file_istantanei/<STATION_HEADER>.dat` | Full rewrite every update, one line per channel (latest known value) | `DATA+ORA,ID,VAL,P.COD` |
| `files_letture_dat/<YYYYMM>/<STATION_HEADER>-<YYYY-MM-DD>.dat` | Appended | `DATA+ORA,ID,VAL,P.COD` |
| `files_letture_dat/<STATION_HEADER>-<YYYY-MM-DD-HH>-00-00.dat` (directly under `files_letture_dat`, no month subfolder) | Appended | `DATA+ORA,ID,VAL,P.COD` |
| `files_letture_csv/<YYYYMM>/<ChannelName>-<YYYY-MM-DD>.csv` | Appended, only when a value is present | `DATA;VALORE` |
| `files_medie_dat/<YYYYMM>/<STATION_HEADER>-<YYYY-MM-DD>.dat` | Appended, one row per channel per elapsed hour (see 5.3) | `DATA+ORA,ID,VAL,P.COD,S.COD,PERC,MIN,H.MIN,MAX,H.MAX,STDDEV` |
| `files_medie_dat/<STATION_HEADER>-<YYYY-MM-DD-HH>-00-00.dat` (directly under `files_medie_dat`, no month subfolder) | Appended | `DATA+ORA,ID,VAL,P.COD,S.COD,PERC,MIN,H.MIN,MAX,H.MAX,STDDEV` |
| `files_medie_csv/<YYYYMM>/<ChannelName>-<YYYY-MM-DD>.csv` | Appended, one row per channel per elapsed hour, always written (even when the hour has no valid readings) | `DATA;VALORE;P.COD` |

Exact formats:

- `DATA+ORA` in the `.dat` files: `YYYY-MM-DD HH:MM:SS` (e.g. `2026-07-24 14:32:10`).
- `ID`: the channel's `DatabaseId` from `MODULE_CONFIG` (section 3), not its own `ID`.
- `VAL`: the reading, rounded to the channel's `Decimals` config field (or
  left unrounded if `Decimals` isn't supplied), or empty string if missing.
  Decimal point `.`.
- `P.COD` in `file_istantanei`/`files_letture_*`: `0` = valid, `128` = value missing.
- `P.COD` in `files_medie_*` (hourly means, see 5.3) can additionally be `512`/`1024` (`DetectionLimit` band) or `2048`/`4096` (`AllowedMinValue`/`AllowedMaxValue` breached), OR'd together with `128` as a bitmask. Bits `1`/`2`/`4`/`8` (span/zero tolerance), `16`/`32`/`64` (calibration/maintenance), and `8192` (instant variation) are reserved by the network format but never emitted by this service — see 5.3.
- `S.COD` (station status, `files_medie_*` only): always `0` — no station-health signal (disk space, software errors, restarts) exists anywhere in this codebase today.
- `DATA` in the `.csv` file: `DD/MM/YYYY HH:MM:SS` (e.g. `24/07/2026 14:32:10`).
- `VALORE` in the `.csv` file: the reading with a **comma** as decimal
  separator (e.g. `42,5`), and the row is only written when the value is
  not missing (the `.dat` files already carry P.COD=128 for that case, so
  no information is lost by omitting it here).
- `file_istantanei/<STATION_HEADER>.dat` must be rewritten **atomically**
  (write to a temp file, then rename/replace) — the UI reads it live and
  must never see a half-written file.
- Channel filenames in `files_letture_csv` have `/` and `\` replaced with
  `_`.
- The `.dat` files never carry a header row; rows in `file_istantanei` are
  sorted by channel `ID`.

**Example rows**, for a channel with `DatabaseId=53`, reading `42.5` at
2026-07-24 14:32:10:

```
# file_istantanei / files_letture_dat
2026-07-24 14:32:10,53,42.5,0

# files_letture_csv
24/07/2026 14:32:10;42,5
```

### 5.1 Two equally valid ways to satisfy this

**(a) Use the provided helper (recommended, zero setup required).** By the
time your driver code runs, the process is already wired up to the service's
output broker. Import `output_manager` (a bare module name — it will resolve
because the service puts it on `sys.path` before running you) and call:

```python
import output_manager

writer = output_manager.create_output_writer()   # once, at startup
writer.write(output_manager.Reading(
    channel_id=channel_config["DatabaseId"],
    channel_name=channel_config["Name"],
    value=42.5,          # or None if missing
    decimals=channel_config.get("Decimals"),   # rounds VAL; leave unset for no rounding
))
writer.close()            # once, at shutdown
```

This handles the exact formatting, atomic writes, and concurrent-write
safety (multiple driver processes at the same station never write these
files directly themselves — they hand readings to one broker process) for
you. `Reading` also takes an optional `raw_value` — see section 5.4.

**(b) Write the four files yourself, by hand, with no imports from this
codebase at all.** This is fully supported and not a lesser path — it is
exactly what `output_manager`'s own fallback does internally when no broker
is available, so the format above is proven self-contained. Follow section
5's format precisely; there is no other requirement.

If two of your own driver processes could ever run for the same station at
the same time (not the normal case — normally it's one process per module),
you are responsible for not writing these files concurrently. If you go with
option (a), the service already handles this for you.

### 5.2 The legacy per-driver status file (optional, cosmetic only)

No driver in this codebase writes this file anymore (ADAM_4013 and ADAM_4052,
the last two that did, were migrated to OPAS NEO-only output). It remains
documented here because the desktop UI still reads it as a fallback, for any
driver - in-tree or third-party - that predates the OPAS NEO output broker
and hasn't been migrated: a per-driver CSV under `<py_out>/output/` named
`<safe_instrument_name>_<module_id>.csv`, overwritten every cycle with a
header row and exactly one data row:

```
timestamp,instrument_id,<channel1>,<channel2>,...
2026-07-24 14:32:10,1,42.5,...
```

This file is **not** part of the network contract above, and only read by
the desktop UI when the modern `file_istantanei/<STATION_HEADER>.dat` file
doesn't exist yet. A driver that correctly satisfies section 5 does not need
to write this file at all.

### 5.3 Hourly means (`files_medie_csv` / `files_medie_dat`)

Separately from the instantaneous files above, one row per channel is
written for every elapsed hour ("targata anticipata": the `06:00:00` row
summarizes readings from `06:00:00` to `06:59:59`), even if the hour has no
valid readings at all (in which case `VAL`/`MIN`/`MAX` are empty,
`H.MIN`/`H.MAX` are `00:00:00`, `STDDEV` is `0`, and `P.COD` includes
`128`).

If you use the SDK (section 6), this is computed and written for you
automatically — you only need to populate the eight extra `Channels[]` fields
shown in section 3's `MODULE_CONFIG` example (`MeanInterval`,
`ReadingsMinPercentage`, `DetectionLimit`, `AllowedMinValue`,
`AllowedMaxValue`, `NegativeValueSetToZero`, `Decimals`, `Algorithm`);
everything else (streaming mean/min/max/stddev, the hour-boundary flush, and
resuming an in-progress hour across a service restart) happens inside the
output broker, not your driver code.

`Decimals` rounding only ever touches the finished numbers: every reading
that feeds the running sum/min/max/stddev for the hour stays unrounded, and
`VAL`/`MIN`/`MAX`/`STDDEV` are rounded once, after the mean is computed at
the hour boundary — never per-reading. This differs from the instantaneous
files above, where each `VAL` is rounded as it's written.

If you write the OPAS NEO files yourself (5.1 option b), you are responsible
for this file pair too if you want it populated — there is no code-level
fallback for a driver that bypasses `output_manager` entirely, same as for
the instantaneous files.

#### 5.3.1 `Algorithm`: which aggregation produces `VAL`

`MIN`/`MAX`/`STDDEV` are always the real statistics of the hour's readings,
regardless of `Algorithm` — only `VAL` changes basis. `Algorithm` is the
legacy VB.NET enum, kept verbatim (`output_manager.Algorithm`); the SDK
implements a subset today, and falls back to `Average` (with a logged
warning) for any code it doesn't implement, so a channel using an
unimplemented code still gets a sensible `VAL` instead of a broken driver:

| Code | Name | `VAL` is | Implemented? |
|---|---|---|---|
| 0 | Average | mean of the hour's readings | yes |
| 1 | Total | sum of the hour's readings | yes |
| 2 | Sample | the last valid reading of the hour | yes |
| 3 | BitOr | bitwise OR of the readings, each rounded to the nearest int | yes |
| 4 | WindVectorSpeed | — | no (falls back to Average) |
| 5 | WindVectorDir | — | no (falls back to Average) |
| 6 | CounterDiff | last reading minus first reading of the hour | yes |
| 7 | Max | same value as the `MAX` column | yes |
| 8 | Min | same value as the `MIN` column | yes |
| 9 | RainType | — | no (falls back to Average) |

If you write the OPAS NEO files yourself (5.1 option b), `Algorithm` is
entirely your own responsibility to interpret — nothing here applies to you.

### 5.4 The raw-value companion file (optional, UI-only)

`file_istantanei_raw/<STATION_HEADER>.dat` is written alongside
`file_istantanei` with the identical `DATA+ORA,ID,VAL,P.COD` row format and
full rewrite-every-update behavior, but `VAL` here is the reading **before**
`Channel["Formule"]` is applied — the value as read off the instrument, never
rounded to `Decimals`. It is **not** part of the network contract in section
5's table: no downstream `centro` parser reads it, it exists solely so the
desktop UI can show the raw reading next to the converted one. A driver that
never produces a raw value (e.g. it only has a converted reading to offer)
can simply not write this file — the UI treats a missing raw value/file as
"no raw data available", never an error.

If you use the SDK (option a), pass `raw_value` on `Reading` and this file is
written for you automatically:

```python
writer.write(output_manager.Reading(
    channel_id=channel_config["DatabaseId"],
    channel_name=channel_config["Name"],
    value=42.5,          # after Formule
    raw_value=41.2,       # before Formule, or None if no real reading exists
    decimals=channel_config.get("Decimals"),
))
```

`P.COD` for this file is derived from `raw_value` independently of `value` —
a formula error that nulls out `value` does not null out an otherwise-valid
`raw_value`. If you write the OPAS NEO files
yourself (5.1 option b), this file is entirely optional and outside the hard
requirement in section 5.

## 6. The SDK is optional

`opas_dl_commons/libs/driver_sdk.py` provides `BaseDriver` (a base class with
`connect()`, `disconnect()`, `read_channel()`/`read_all_channels()`) and
`run_driver()` (a function that runs the polling loop, handles shutdown
signals, and writes the output files for you via section 5.1's option (a)).
Use it if you want to write less code; ignore it entirely if you'd rather
write your own loop.

```python
import os, importlib.util

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Minimal walk-up to locate opas_dl_commons/libs/ - your driver folder may sit
# directly under drivers/ or be nested for grouping (see section 8), so this
# can't be a hardcoded "../.." depth. This bit can't move into libs/ itself
# (it's what finds libs/ before anything there is reachable), but everything
# after it delegates to libs/driver_bootstrap.py, which has the documented,
# canonical version of this same walk plus a load_module() helper that saves
# you repeating this exec_module dance for every further libs/ module you load.
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

If your instrument answers with several channels in a single response
instead of one command per channel, override `read_all_channels(channels)`
instead of `read_channel(channel)` — see the docstring in `driver_sdk.py`
for details.

You need to implement at least one of `read_channel`/`read_all_channels`;
`connect()`/`disconnect()` are optional.

If you don't want to manage your own socket/serial/pymodbus/file handling,
`driver_sdk.comm_manager` (re-exported from `opas_dl_commons/libs/comm_manager.py`)
provides `create_channel(self.module_config)`, a single factory that reads
`ComunicationType` and returns the right channel for all seven supported values:
Serial (0), TCP/IP (1), PipeFile (3), UDP (4), Modbus Seriale (5), Modbus
Ethernet (6), and HTTP (7, not part of the original VB.NET enum - see below).
Serial/TCP/IP/UDP channels share a `send()`/`recv()`/`close()`/`is_open()`
interface; Modbus channels expose `read_registers(function_code, address,
quantity)` plus the module-level `decode_modbus_value(registers, register_type,
register_order)` helper instead; PipeFile channels expose `read_values(channels)`
(a batch read, meant for `read_all_channels()`) instead; HTTP channels expose
`get(path, headers=None)` (returns the raw response body, raises
`urllib.error.URLError`/`HTTPError` same as calling `urlopen()` directly) instead.
See `opas_dl_commons/drivers/PALAS/FIDAS_200/driver.py` (Modbus),
`opas_dl_commons/drivers/PIPE/CSV/driver.py` (PipeFile), and
`opas_dl_commons/drivers/CAMPBELL/CR1000/driver.py` (HTTP) for working examples.

## 7. A from-scratch example (no imports from this codebase)

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

# You choose the data root and station header (ask the system owner for
# these two values when your driver is registered - see section 8).
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
    # ... file_istantanei (atomic rewrite) and files_letture_csv omitted for
    # brevity - see section 5 for their exact format.


while True:
    for ch in active_channels:
        value = None  # replace with your own instrument read
        write_reading(ch["DatabaseId"], value)
    time.sleep(polling_interval)
```

## 8. Registration

You do not edit any file in this repository. You deliver a driver folder
(your `driver.py`, plus anything else it needs) and tell the system owner:

- the folder path you want it placed under, relative to `drivers/` (e.g.
  `MyInstrument`, or `Acme/MyInstrument` to group it under a brand/family
  folder alongside other drivers from the same maker),
- a `ModuleType` code that isn't already in use,
- a display name and producer name for the UI.

The system owner adds one entry to the shared driver registry:

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

`Drivers` is resolved relative to `drivers/`, joined component by component —
it can be a bare folder name (`MyInstrument`) or a `/`-separated path of any
depth (`Acme/MyInstrument`) to group drivers by brand/family; `driver_manager`
doesn't assume a fixed nesting depth (see `resolve_driver_for_module` /
`_read_drivers_dict` in `driver_manager.py`). Your `driver.py` must live at
exactly that path, e.g. `Acme/MyInstrument/driver.py` — that exact filename,
at the top level of the folder you deliver.

## 9. Shutdown contract

When the service stops your driver, it calls the OS equivalent of "please
terminate," waits up to 5 seconds, and then force-kills the process if it's
still running.

**Be honest with yourself about what this means on Windows**: on this
platform, "please terminate" is `TerminateProcess` — an unconditional kill,
not a signal your code can catch. Handling `SIGTERM`/`SIGINT` (as
`common.setup_signal_handlers()`/the SDK do) is harmless but gives you no
real grace period on Windows. **Assume you get no guaranteed cleanup
callback at all.**

Practical implications:

- Never leave an output file partially written — always write to a
  temporary file and rename/replace, never write in place (section 5.1's
  option (a) already does this for you).
- Don't hold an external lock or mutex that would stay locked forever if
  your process vanished mid-operation. If you must coordinate with the
  instrument itself (e.g. a "who's talking to me" lock on its side), give it
  its own timeout rather than relying on your Python exit path running.
