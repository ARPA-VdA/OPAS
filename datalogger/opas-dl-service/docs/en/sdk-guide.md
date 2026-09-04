# Writing a driver with the SDK

[driver-contract.md](driver-contract.md) is the full, SDK-independent contract
a `driver.py` must satisfy. This document is a schematic walkthrough of
`opas_dl_commons/libs/driver_sdk.py` — the optional convenience layer that
implements that contract for you — for anyone building a new driver on top of
it instead of writing the raw loop by hand. It uses
[`API_400/driver.py`](../../src/opas_dl_commons/drivers/API_400/driver.py) as
a worked example throughout.

## 1. The two building blocks

`driver_sdk.py` exports exactly two things you need:

| Name | What it is |
|---|---|
| `BaseDriver` | A base class you subclass. You override its I/O methods; it does nothing on its own. |
| `run_driver(YourDriverClass)` | A function that instantiates your class and drives it: polling loop, logging, signal handling, output writing, missing-value reporting when the instrument is unreachable. |

Your `driver.py` only ever needs one line to start everything:
`driver_sdk.run_driver(YourDriverClass)` inside `if __name__ == "__main__":`.

## 2. `BaseDriver`: what you override

| Method | Required? | Called | Purpose |
|---|---|---|---|
| `connect(self)` | optional (default: no-op) | once, before the polling loop starts | open the connection to the instrument |
| `disconnect(self)` | optional (default: no-op) | once, when the loop ends (including on shutdown) | close the connection |
| `read_channel(self, channel_config)` | one of these two, minimum | once per active channel, every cycle | return that channel's value (or raise) |
| `read_all_channels(self, channels)` | one of these two, minimum | once per cycle, with every active channel's config | return `{channel_name: value, ...}` for all of them at once |

Notes that matter in practice:

- **You must override at least one** of `read_channel`/`read_all_channels`.
  `run_driver()` checks this at startup (by comparing your subclass's bound
  method to `BaseDriver`'s own — see `_overrides()` in the source) and raises
  `RuntimeError` immediately, before any I/O, if neither is overridden.
- **If you override both, `read_all_channels` wins** — it's checked first and
  decides `batch_mode` for the whole run.
- **Failure isolation differs between the two.** In per-channel mode, an
  exception from `read_channel()` for one channel only makes *that* channel's
  reading missing this cycle — other channels are unaffected. In batch mode,
  an exception from `read_all_channels()` loses the *entire* cycle: every
  channel is reported missing, because individual channels can't be isolated
  after the fact from one failed batch call.
- **No automatic reconnect.** If `connect()` raises, the driver keeps running
  for the rest of the process lifetime reporting missing values every cycle
  (see step 7 below) — it never retries `connect()` again. A
  driver that wants retry semantics has to implement them itself, typically
  lazily inside `read_channel()`/`read_all_channels()`.

## 3. What `run_driver()` does, step by step

This is the part that actually implements
[driver-contract.md](driver-contract.md) for you. In source order:

1. **Resolve `instrument_id`/`module_config`.** Read from the `INSTRUMENT_ID`/
   `MODULE_CONFIG` environment variables unless passed explicitly (passing
   them explicitly is what makes the loop unit-testable without a real
   subprocess).
2. **Set up logging and signal handling** — `common.configure_driver_logging()`
   and `common.setup_signal_handlers()`, both before anything else runs.
3. **Validate your subclass** as described in section 2, and decide
   `batch_mode`.
4. **Instantiate your driver class** with `(module_config, instrument_id)`.
5. **Compute `active_channels`** (only `Channels` entries with
   `"Active": true`) and `polling_interval` (from `PollingInterval`, default
   `1` second if absent or invalid).
6. **Create the output writer** via `output_manager.create_output_writer()` —
   the same helper described in driver-contract.md §5.1(a). This is what
   actually writes the OPAS NEO files later in the loop.
7. **Call `connect()` once.** If it raises, `connected` stays `False` for the
   rest of the run (see the "no automatic reconnect" note above).
8. **The polling loop**, while `common.should_run()` is `True`:
   - Read values: one `read_all_channels()` call in batch mode, or one
     `read_channel()` call per active channel otherwise (each wrapped in its
     own try/except — see the failure-isolation note above).
   - For each active channel: resolve its `DatabaseId` (logging a one-time
     warning and falling back to `0` if it's missing), pick the value (the
     real reading if connected, `None` otherwise), and write a `Reading` to
     the output writer — this *is* the output file contract from
     driver-contract.md §5, handled for you.
   - `common.graceful_sleep(polling_interval)` — sleeps in small increments
     so a shutdown signal is noticed quickly instead of blocking for the
     full interval.
9. **On exit** (`finally`): call `disconnect()`, then `output_writer.close()`
   — each wrapped separately so a failure in one doesn't prevent the other
   from running.

## 4. Worked example: `API_400/driver.py`

This driver (Teledyne API 400 O3 analyzer) overrides `connect`,
`read_channel`, and `disconnect` — not `read_all_channels`, so it runs in
per-channel mode.

- **Importing the SDK**: since drivers live in their own folder rather than
  as an installed package, the file loads `driver_sdk.py` by file path via
  `importlib.util.spec_from_file_location(...)` instead of a normal
  `import driver_sdk`. This is boilerplate you can copy verbatim into a new
  driver — only the relative path (`"..", "..", "libs", "driver_sdk.py"`)
  needs to stay correct for wherever your driver folder sits.
- **`connect()`** calls `comm_manager.create_channel(self.module_config)`,
  which reads `ComunicationType` from the module config and returns either a
  serial or a TCP/IP channel — the driver code itself never branches on which
  one it got.
- **`read_channel()`** builds a `"T <ChannelName>"` command, sends it,
  receives the reply, and extracts the value either via the channel's own
  `RegularExpression` (`parse_response()`, a small `re.search()` wrapper
  returning the first capture group) or, if no pattern is configured, the
  raw reply text with line endings collapsed to spaces.
- **`disconnect()`** just closes the channel.
- **`if __name__ == "__main__": driver_sdk.run_driver(API400Driver)`** is the
  only line that starts everything in section 3.

## 5. Minimal skeleton for a new driver

```python
import importlib.util, os

_SDK = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "libs", "driver_sdk.py"
))
_spec = importlib.util.spec_from_file_location("driver_sdk", _SDK)
driver_sdk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(driver_sdk)


class MyDriver(driver_sdk.BaseDriver):
    def connect(self):
        ...  # open the connection, e.g. via driver_sdk.comm_manager.create_channel(self.module_config)

    def read_channel(self, channel_config):
        ...  # query the instrument for this one channel, return a value or None

    def disconnect(self):
        ...  # close the connection


if __name__ == "__main__":
    driver_sdk.run_driver(MyDriver)
```

## See also

- [driver-contract.md](driver-contract.md) — the full contract, independent
  of whether you use this SDK.
- [architecture.md](architecture.md) — where a driver process fits into the
  rest of the service (output broker, process model, startup sequence).
