"""Optional convenience SDK for writing OPAS NEO instrument drivers.

Nothing here is required. A driver.py is free to satisfy the raw contract
(env vars in, OPAS NEO output files out - see docs/en/driver-contract.md) with
zero imports from this package, including no imports of this module or of
common.py. BaseDriver + run_driver() exist only to remove the boilerplate
that would otherwise be hand-written per driver: the polling loop, signal
handling, output-writer lifecycle, and missing-value reporting when the
instrument is unreachable.

Usage (production - runs until the process is asked to stop):

    class MyDriver(driver_sdk.BaseDriver):
        def connect(self):
            self._sock = my_instrument_sdk.open(self.module_config["TCPIPAddress"])
        def read_channel(self, ch):
            return my_instrument_sdk.query(self._sock, ch["Address"])
        def disconnect(self):
            self._sock.close()

    if __name__ == "__main__":
        driver_sdk.run_driver(MyDriver)
"""

import json
import logging
import os
import sys
from abc import ABC
from typing import Callable

# Ensure this module's own directory (opas_dl_commons/libs) is on sys.path so
# the sibling bare imports below (common, output_manager, comm_manager)
# resolve regardless of how this module itself was loaded (package import vs.
# the direct file-spec fallback used by drivers in frozen/standalone contexts)
# - same pattern as output_manager.py.
_LIBS_DIR = os.path.dirname(os.path.abspath(__file__))
if _LIBS_DIR not in sys.path:
    sys.path.insert(0, _LIBS_DIR)

import common
import output_manager
import comm_manager  # noqa: F401  re-exported for drivers that want TCP/serial transport; never used automatically here
import formula

Reading = output_manager.Reading


class BaseDriver(ABC):
    """Subclass this and override read_channel() and/or read_all_channels().

    - read_channel(channel_config) -> value: called once per active channel,
      per polling cycle. Use this when the instrument answers one command
      per channel (e.g. a Teledyne API-style "T <PARAM>" query per reading).
    - read_all_channels(channels) -> {channel_name: value, ...}: called once
      per cycle with every active channel's config. Use this when a single
      request returns several channels at once (e.g. an ADAM-style batch
      response parsed with one regex per channel out of one reply). A raised
      exception here loses the whole cycle - every channel is reported
      missing - since individual channels can't be isolated after the fact.
      If both are overridden, read_all_channels() takes priority.

    Implement at least one of the two. run_driver() checks this at startup
    and raises RuntimeError before doing any I/O if neither is overridden.

    connect()/disconnect() are optional (default: no-op). connect() is
    called once before the polling loop starts; if it raises, the driver
    keeps running and reports missing values (P.COD 128) every cycle -
    there is no automatic reconnect. A driver that wants retry semantics
    implements them itself, e.g. lazily inside
    read_channel()/read_all_channels().
    """

    def __init__(self, module_config: dict, instrument_id: str):
        self.module_config = module_config
        self.instrument_id = instrument_id
        self.log = logging.getLogger(f"driver_sdk.{instrument_id}")

    def connect(self) -> None:
        pass

    def disconnect(self) -> None:
        pass

    def read_channel(self, channel_config: dict) -> float | None:
        raise NotImplementedError

    def read_all_channels(self, channels: list) -> dict:
        raise NotImplementedError


def _overrides(cls, method_name: str) -> bool:
    return getattr(cls, method_name) is not getattr(BaseDriver, method_name)


def _to_float_or_none(value):
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _to_int_or_none(value):
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _channel_reading_kwargs(ch: dict) -> dict:
    """Extracts the per-channel Reading fields output_broker needs to compute
    hourly means (see output_manager.Reading) from a Channels[] config dict.

    Computed once per channel at startup (not per polling cycle) since
    module_config never changes over a driver process's lifetime.
    """
    mean_interval = _to_int_or_none(ch.get("MeanInterval"))
    if mean_interval is None:
        mean_interval = 3600

    readings_min_percentage = _to_float_or_none(ch.get("ReadingsMinPercentage"))
    if readings_min_percentage is None:
        readings_min_percentage = 75.0

    return dict(
        mean_interval=mean_interval,
        readings_min_percentage=readings_min_percentage,
        detection_limit=_to_float_or_none(ch.get("DetectionLimit")),
        allowed_min_value=_to_float_or_none(ch.get("AllowedMinValue")),
        allowed_max_value=_to_float_or_none(ch.get("AllowedMaxValue")),
        negative_value_set_to_zero=bool(ch.get("NegativeValueSetToZero", False)),
        decimals=_to_int_or_none(ch.get("Decimals")),
        algorithm=_to_int_or_none(ch.get("Algorithm")),
    )


def run_driver(
    driver,
    *,
    module_config: dict | None = None,
    instrument_id: str | None = None,
    max_cycles: int | None = None,
) -> None:
    """Run a BaseDriver's polling loop until stopped.

    `driver` may be a BaseDriver subclass (the normal case - run_driver(MyDriver)
    instantiates it with (module_config, instrument_id)) or an already-built
    instance (useful for tests that need to pre-seed state).

    module_config/instrument_id default to being parsed from the environment
    driver_manager sets before running a driver (MODULE_CONFIG, INSTRUMENT_ID).
    Pass them explicitly to run without env vars or a subprocess - this is
    what makes the loop unit-testable.

    max_cycles is test-only: pass an integer to make the loop return after
    that many iterations instead of running until common.should_run() is
    False (which happens on SIGINT/SIGTERM - see docs/en/driver-contract.md for
    the Windows caveat about terminate() not delivering a real signal).
    """
    log = logging.getLogger(f"driver_sdk.{instrument_id}")

    if instrument_id is None:
        instrument_id = common.get_instrument_id()

    if module_config is None:
        raw = os.environ.get("MODULE_CONFIG")
        try:
            module_config = json.loads(raw) if raw else {}
        except Exception as e:
            log.warning(f"[driver_sdk] Failed to parse MODULE_CONFIG: {e}")
            module_config = {}

    # LogLevel is already resolved (own override, or the station default as
    # of launch time) by driver_manager.launch_driver() before this process
    # ever starts - `or "INFO"` guards the case where module_config was built
    # by hand (section 5.1(a) of driver-contract.md) without going through
    # that resolution at all, not just a missing key.
    common.configure_driver_logging(instrument_id=instrument_id, level=module_config.get("LogLevel") or "INFO")
    common.setup_signal_handlers()

    driver_cls = driver if isinstance(driver, type) else type(driver)
    has_read_channel = _overrides(driver_cls, "read_channel")
    has_read_all_channels = _overrides(driver_cls, "read_all_channels")
    if not (has_read_channel or has_read_all_channels):
        raise RuntimeError(
            f"{driver_cls.__name__} must override read_channel() or read_all_channels()"
        )
    batch_mode = has_read_all_channels

    instance = driver(module_config, instrument_id) if isinstance(driver, type) else driver

    active_channels = [
        ch for ch in module_config.get("Channels", [])
        if isinstance(ch, dict) and ch.get("Active") is True
    ]
    # Keyed by Name, same as `values` below - computed once here rather than
    # per polling cycle since module_config never changes over this process's
    # lifetime.
    reading_kwargs_by_name = {
        ch.get("Name", "UnknownChannel"): _channel_reading_kwargs(ch)
        for ch in active_channels
    }
    # Channel["Formule"] compiled once per channel, same reasoning - a bad
    # formula string is a config problem, not a per-cycle one, so it's
    # logged once here rather than on every polling cycle below.
    formula_by_name: dict[str, Callable[[float], float] | None] = {}
    for ch in active_channels:
        name = ch.get("Name", "UnknownChannel")
        try:
            formula_by_name[name] = formula.parse_formula(ch.get("Formule"))
        except Exception as e:
            log.warning(f"Formula for channel '{name}' is invalid ({e}); using the raw reading unmodified")
            formula_by_name[name] = None
    try:
        polling_interval = int(module_config.get("PollingInterval", 1))
    except (TypeError, ValueError):
        polling_interval = 1

    output_writer = output_manager.create_output_writer()

    connected = True
    try:
        instance.connect()
    except Exception as e:
        connected = False
        log.warning(f"connect() failed; reporting missing values for this run: {e}")

    warned_missing_database_id = set()
    warned_formula_errors = set()
    cycles = 0
    try:
        while common.should_run() and (max_cycles is None or cycles < max_cycles):
            cycles += 1
            values = {}

            if connected and batch_mode:
                try:
                    result = instance.read_all_channels(active_channels)
                    values = result if isinstance(result, dict) else {}
                except Exception as e:
                    log.warning(f"read_all_channels() failed; all channels missing this cycle: {e}")
                    values = {}
            elif connected:
                for ch in active_channels:
                    name = ch.get("Name", "UnknownChannel")
                    try:
                        values[name] = instance.read_channel(ch)
                    except Exception as e:
                        log.warning(f"read_channel() failed for '{name}': {e}")
                        values[name] = None

            for ch in active_channels:
                name = ch.get("Name", "UnknownChannel")
                database_id = ch.get("DatabaseId")
                if database_id is None:
                    if name not in warned_missing_database_id:
                        log.warning(f"Channel '{name}' has no DatabaseId configured; using 0 for the OPAS NEO ID field")
                        warned_missing_database_id.add(name)
                    database_id = 0

                if connected:
                    value = _to_float_or_none(values.get(name))
                    raw_value = value  # dato letto dallo strumento, prima di Formule
                else:
                    value = None
                    raw_value = None

                # Formule transforms the raw instrument reading into the real
                # measurement - only meaningful for an actual reading, not a
                # missing one, and must happen before this value reaches
                # output_writer.write() so everything downstream (instant
                # files, letture files, hourly Algorithm) sees only the
                # transformed value.
                if value is not None:
                    apply_formula = formula_by_name.get(name)
                    if apply_formula is not None:
                        try:
                            value = apply_formula(value)
                        except Exception as e:
                            if name not in warned_formula_errors:
                                log.warning(
                                    f"Formula for channel '{name}' failed on value {value} ({e}); "
                                    "reporting this reading as missing"
                                )
                                warned_formula_errors.add(name)
                            value = None

                try:
                    output_writer.write(output_manager.Reading(
                        channel_id=database_id,
                        channel_name=name,
                        value=value,
                        raw_value=raw_value,
                        polling_interval=polling_interval,
                        **reading_kwargs_by_name[name],
                    ))
                except Exception as e:
                    log.warning(f"Failed to emit reading for '{name}': {e}")

            common.graceful_sleep(polling_interval)
    finally:
        try:
            instance.disconnect()
        except Exception as e:
            log.warning(f"disconnect() failed: {e}")
        try:
            output_writer.close()
        except Exception as e:
            log.warning(f"output_writer.close() failed: {e}")
