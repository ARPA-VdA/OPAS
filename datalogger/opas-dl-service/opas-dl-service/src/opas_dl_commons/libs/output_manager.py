"""Driver-facing output interface for the OPAS NEO instant-reading format.

Same shape as comm_manager.py: an ABC + factory. Drivers never touch disk
directly for this format - they hand off Reading objects to whichever
OutputWriter the factory returns, exactly like they hand a CommunicationChannel
bytes instead of opening a socket themselves.

Multiple driver processes belonging to the same station must never write the
same per-station file concurrently (see core/output_broker_manager.py), so the
normal path is a QueueOutputWriter that hands readings to a dedicated broker
process. DirectOutputWriter is a same-process fallback used only when no
broker has been configured (e.g. running a driver standalone for testing) -
it delegates to output_broker's own row-formatting class so the two paths
can never format rows differently.
"""

import logging
import os
import sys
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from enum import IntEnum

# Ensure this module's own directory (opas_dl_commons/libs) is on sys.path so
# the sibling bare imports below (output_broker, runtime_paths) resolve
# regardless of how this module itself was loaded (package import vs. the
# direct file-spec fallback used by drivers in frozen/standalone contexts).
_LIBS_DIR = os.path.dirname(os.path.abspath(__file__))
if _LIBS_DIR not in sys.path:
    sys.path.insert(0, _LIBS_DIR)


class Algorithm(IntEnum):
    """Channel["Algorithm"]: which hourly aggregation produces files_medie_*'s
    VAL for this channel. Numeric values and names are the legacy VB.NET
    enum, kept verbatim (including the gap at values not used by this
    codebase) so existing config files' numbers keep meaning what they always
    meant.

    Only a subset has aggregation logic in output_broker._HourBucket (see
    _ALGORITHM_HANDLERS there) - the rest are recognized (named, never crash)
    but fall back to AVERAGE with a logged warning until implemented.
    """
    AVERAGE = 0             # Average
    TOTAL = 1               # Total (sum)
    SAMPLE = 2              # Sample (last value of the hour)
    BIT_OR = 3              # Bitwise OR
    WIND_VECTOR_SPEED = 4   # Vector wind speed - not implemented
    WIND_VECTOR_DIR = 5     # Vector wind direction - not implemented
    COUNTER_DIFF = 6        # Difference between last and first value (rain gauge counters)
    MAX = 7                 # Maximum (used for alarms)
    MIN = 8                 # Minimum (used for ping, or ok status)
    RAIN_TYPE = 9           # Precipitation type - not implemented


@dataclass
class Reading:
    channel_id: int          # -> "ID" field in the .dat format = Channel["DatabaseId"] from config
    channel_name: str        # -> file name in files_letture_csv
    value: float | None
    # Value as read from the instrument before Channel["Formule"] transforms it
    # (see driver_sdk.run_driver()). None when there is no real reading
    # (instrument not connected). Feeds only file_istantanei_raw
    # (output_broker._StationWriter) - does not participate in hourly means.
    raw_value: float | None = None
    timestamp: datetime | None = None
    # Channel config the broker needs to compute hourly means
    # (files_medie_csv/files_medie_dat - see formato-opas-v2.txt). The broker
    # only receives bare Reading objects, never the full module_config, so
    # these values travel here. All optional/defaulted to stay compatible
    # with driver-contract.md §5.1(a), which builds a Reading without them.
    mean_interval: int = 3600                    # Channel["MeanInterval"], seconds
    polling_interval: int | None = None          # Module["PollingInterval"], seconds
    readings_min_percentage: float = 75.0        # Channel["ReadingsMinPercentage"]
    detection_limit: float | None = None         # Channel["DetectionLimit"]
    allowed_min_value: float | None = None       # Channel["AllowedMinValue"]
    allowed_max_value: float | None = None       # Channel["AllowedMaxValue"]
    negative_value_set_to_zero: bool = False     # Channel["NegativeValueSetToZero"]
    # Channel["Decimals"]. Rounding is applied by the broker at write time, not
    # here: instant/letture readings are rounded as received, but hourly means
    # accumulate from unrounded values and are only rounded once the mean
    # itself is computed (see output_broker._HourBucket.compute).
    decimals: int | None = None
    # Channel["Algorithm"] - see the Algorithm enum above for what each code
    # means and which ones output_broker._HourBucket actually computes.
    algorithm: int | None = None

    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()


class OutputWriter(ABC):
    """Abstract base class for OPAS NEO instant-reading output writers."""

    @abstractmethod
    def write(self, reading: Reading) -> None:
        """Emit one channel reading. Must never raise: implementations catch
        and log their own errors so a write failure never interrupts a
        driver's polling loop."""
        pass

    @abstractmethod
    def close(self) -> None:
        """Release any resources held by this writer."""
        pass


# Process-local state set once by configure(), read by create_output_writer().
# Set directly (not via env var, unlike MODULE_CONFIG/INSTRUMENT_ID) because a
# multiprocessing.Queue cannot be serialized into a string; driver_manager's
# _process_runner calls configure() in the child process before running the
# driver's own code.
_queue = None
_station_header = None


def configure(queue, station_header: str) -> None:
    """Bind this process to a running output broker.

    Called once per driver process by driver_manager._process_runner, before
    the driver's own module code runs.
    """
    global _queue, _station_header
    _queue = queue
    _station_header = station_header


class QueueOutputWriter(OutputWriter):
    """Hands readings to the output broker process via a multiprocessing.Queue."""

    def __init__(self, queue):
        self._queue = queue

    def write(self, reading: Reading) -> None:
        try:
            self._queue.put(reading)
        except Exception as e:
            logging.warning(f"[output_manager] Failed to enqueue reading for {reading.channel_name}: {e}")

    def close(self) -> None:
        # the queue and broker process are owned by the service, not by this driver
        pass


class DirectOutputWriter(OutputWriter):
    """Fallback used when no broker has been configured (e.g. standalone driver run).

    Writes directly to disk using output_broker's own row-formatting class, so
    the output format never diverges between the queued and direct paths.
    """

    def __init__(self, station_header: str):
        import output_broker  # local import: only needed for this fallback path
        from runtime_paths import RuntimePaths

        data_root = RuntimePaths().opas_neo_data_dir
        self._writer = output_broker._StationWriter(data_root, station_header)

    def write(self, reading: Reading) -> None:
        try:
            self._writer.write(reading)
        except Exception as e:
            logging.warning(f"[output_manager] Failed to write reading for {reading.channel_name}: {e}")

    def close(self) -> None:
        pass


def create_output_writer() -> OutputWriter:
    """Factory mirroring comm_manager.create_channel(): returns whichever
    OutputWriter fits how this driver process was configured.
    """
    if _queue is not None:
        return QueueOutputWriter(_queue)

    station_header = _station_header or "unknown-station"
    logging.warning(
        "[output_manager] No output broker configured; falling back to direct disk writes "
        f"for station '{station_header}'. Expected only when running a driver standalone."
    )
    return DirectOutputWriter(station_header)
