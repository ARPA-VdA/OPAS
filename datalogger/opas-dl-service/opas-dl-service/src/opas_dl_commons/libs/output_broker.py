"""Output broker process for OPAS NEO instant-reading and hourly-mean files.

Centralizes writes to file_istantanei/files_letture_csv/files_letture_dat/
files_medie_csv/files_medie_dat so multiple driver processes of the same
station never write to the same per-station file concurrently. Mirrors
serial_port_broker.py's role for shared COM ports: driver processes stay
unaware of this layer, they only see the OutputWriter interface in
output_manager.py.

Field layout is a fixed network contract (see docs/formato-opas-v2.txt):
every row written here has exactly the columns shown below, never more, never
fewer - a centro parser validates records with a fixed-field regex, so an
extra or missing column breaks ingestion, not just cosmetics.

    file_istantanei\\<FILE-HEADER>.dat                       DATA+ORA,ID,VAL,P.COD
    file_istantanei_raw\\<FILE-HEADER>.dat                    DATA+ORA,ID,VAL,P.COD (VAL = raw value,
                                                               pre-Formule; see output_manager.Reading.raw_value).
                                                               NOT part of the network contract with the centro
                                                               (docs/formato-opas-v2.txt) - consumed only by the
                                                               Electron client to show the raw value in the UI.
    files_letture_csv\\<YYYYMM>\\<ChannelName>-<data>.csv     DATA;VALORE
    files_letture_dat\\<YYYYMM>\\<FILE-HEADER>-<data>.dat     DATA+ORA,ID,VAL,P.COD
    files_letture_dat\\<FILE-HEADER>-<data-ora>.dat           DATA+ORA,ID,VAL,P.COD
    files_medie_csv\\<YYYYMM>\\<ChannelName>-<data>.csv       DATA;VALORE;P.COD
    files_medie_dat\\<YYYYMM>\\<FILE-HEADER>-<data>.dat       DATA+ORA,ID,VAL,P.COD,S.COD,PERC,MIN,H.MIN,MAX,H.MAX,STDDEV
    files_medie_dat\\<FILE-HEADER>-<data-ora>.dat             DATA+ORA,ID,VAL,P.COD,S.COD,PERC,MIN,H.MIN,MAX,H.MAX,STDDEV

files_medie_* holds hourly averages per channel ("targata anticipata": the
06:00:00 row summarizes readings from 06:00:00 to 06:59:59 - see
docs/formato-opas-v2.txt). Only the P.COD bits with an actual config field
behind them are ever set: 0 (valid), 128 (coverage below
ReadingsMinPercentage), 512/1024 (DetectionLimit band), 2048/4096
(AllowedMinValue/AllowedMaxValue breached by any instant reading in the
hour). Bits 1/2/4/8 (span/zero tolerance), 16/32/64
(calibration/maintenance) and 8192 (instant variation) are reserved by the
spec but never emitted here - no tolerance/threshold values exist anywhere in
the config schema to source them honestly (see docs/driver-contract.md §5).
S.COD is always 0 for the same reason: no station-health signal exists
anywhere in this codebase today.
"""

import json
import logging
import math
import os
import queue as queue_module
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
from pathlib import Path

import common
import output_manager

# Grace period past the top of the hour before a bucket is considered due for
# flush - tolerates a reading timestamped just before the boundary but
# delivered to the broker a moment after it, due to process/queue scheduling
# jitter. A tuning knob, not a hard architectural constant.
_FLUSH_GRACE = timedelta(seconds=30)

# One broker process = one station (see output_broker_manager.py), so a single
# fixed filename is enough - no need to key it by station_header.
_STATE_FILENAME = "hourly_buckets_state.json"


def _status_code_for_value(value: float | None) -> int:
    """P.COD: missing value (128) or valid (0).

    Factored out of _status_code() so the same rule applies to
    reading.raw_value independently of reading.value - a formula error can
    null out value while raw_value stays a valid grezzo reading, so each
    needs its own status code (see _StationWriter.write()).
    """
    return 128 if value is None else 0  # invalid reading / valid


def _status_code(reading: "output_manager.Reading") -> int:
    return _status_code_for_value(reading.value)


def _format_value(value: float | None, decimal_sep: str = ".") -> str:
    if value is None:
        return ""
    text = str(value)
    if decimal_sep != ".":
        text = text.replace(".", decimal_sep)
    return text


def _round_value(value: float | None, decimals: int | None) -> float | None:
    """Round to Channel["Decimals"], or pass through unchanged if unset.

    Callers decide *when* to round: instant/letture readings are rounded as
    received, while hourly means (_HourBucket) accumulate raw values and only
    call this once, on the finished mean - never on the readings that feed it.
    """
    if value is None or decimals is None:
        return value
    return round(value, decimals)


def _replace_with_retry(tmp_path, dest_path, attempts: int = 5, initial_delay: float = 0.02) -> None:
    """os.replace(), retrying if the destination is transiently locked.

    On Windows, MoveFileEx (what os.replace() uses under the hood) fails with
    WinError 5 "Accesso negato" if something else has dest_path open without
    FILE_SHARE_DELETE at that exact instant - a real-time antivirus scan, a
    search indexer, an editor/file-watcher tab on the file, a sync client,
    etc. The write to tmp_path already succeeded; only this final atomic
    rename lost a momentary race. POSIX rename() has no such restriction, so
    this is a no-op retry loop there in practice.
    """
    delay = initial_delay
    for attempt in range(1, attempts + 1):
        try:
            os.replace(tmp_path, dest_path)
            return
        except OSError:
            if attempt == attempts:
                raise
            time.sleep(delay)
            delay *= 2


# ---- Hourly VAL selection (Channel["Algorithm"], see output_manager.Algorithm) ----
#
# One small function per algorithm rather than a single branching block: each
# is independently callable/testable (e.g. `_agg_total(bucket, mean=None)` in
# a unit test with a hand-built bucket, no _StationWriter/queue/disk needed),
# and a bug in one shows up under its own name in a traceback instead of a
# line number inside a shared if/elif chain. Every function takes the bucket
# plus the already-computed hourly `mean` (only _agg_average uses it, but the
# uniform signature keeps them freely interchangeable in the dispatch dict
# below) and returns the unrounded VAL - _HourBucket.compute() rounds once,
# after dispatch, same as it already does for MIN/MAX/STDDEV.

def _agg_average(bucket: "_HourBucket", mean: float | None) -> float | None:
    return mean


def _agg_total(bucket: "_HourBucket", mean: float | None) -> float | None:
    return bucket.sum_value


def _agg_sample(bucket: "_HourBucket", mean: float | None) -> float | None:
    return bucket.last_value


def _agg_bit_or(bucket: "_HourBucket", mean: float | None) -> float | None:
    return float(bucket.bit_or_value) if bucket.bit_or_value is not None else None


def _agg_counter_diff(bucket: "_HourBucket", mean: float | None) -> float | None:
    if bucket.first_value is None or bucket.last_value is None:
        return None
    return bucket.last_value - bucket.first_value


def _agg_max(bucket: "_HourBucket", mean: float | None) -> float | None:
    return bucket.max_value


def _agg_min(bucket: "_HourBucket", mean: float | None) -> float | None:
    return bucket.min_value


# Codes without a handler here (WIND_VECTOR_SPEED, WIND_VECTOR_DIR, RAIN_TYPE,
# and anything not in output_manager.Algorithm at all) fall back to
# _agg_average in compute(), with a logged warning - see there.
_ALGORITHM_HANDLERS = {
    output_manager.Algorithm.AVERAGE: _agg_average,
    output_manager.Algorithm.TOTAL: _agg_total,
    output_manager.Algorithm.SAMPLE: _agg_sample,
    output_manager.Algorithm.BIT_OR: _agg_bit_or,
    output_manager.Algorithm.COUNTER_DIFF: _agg_counter_diff,
    output_manager.Algorithm.MAX: _agg_max,
    output_manager.Algorithm.MIN: _agg_min,
}


@dataclass
class _HourBucket:
    """In-progress hourly aggregate for one channel.

    Built entirely from streaming sums - no raw reading is ever stored - so
    memory use stays flat regardless of polling interval. See this module's
    docstring for which P.COD bits this can produce.
    """

    channel_name: str
    hour_start: datetime
    mean_interval: int
    polling_interval: int | None
    readings_min_percentage: float
    decimals: int | None = None
    algorithm: int | None = None
    count_valid: int = 0
    count_total: int = 0
    sum_value: float = 0.0
    sum_sq: float = 0.0
    min_value: float | None = None
    min_time: datetime | None = None
    max_value: float | None = None
    max_time: datetime | None = None
    first_value: float | None = None   # -> Algorithm.COUNTER_DIFF
    last_value: float | None = None    # -> Algorithm.SAMPLE, Algorithm.COUNTER_DIFF
    bit_or_value: int | None = None    # -> Algorithm.BIT_OR
    any_in_detection_band: bool = False     # -> P.COD 512
    any_below_neg_detection: bool = False   # -> P.COD 1024
    any_below_allowed_min: bool = False     # -> P.COD 2048
    any_above_allowed_max: bool = False     # -> P.COD 4096

    def ingest(self, reading: "output_manager.Reading", ts: datetime) -> None:
        value = reading.value
        if value is not None and reading.negative_value_set_to_zero and value < 0:
            value = 0.0

        self.count_total += 1
        if value is None:
            return

        self.count_valid += 1
        self.sum_value += value
        self.sum_sq += value * value

        if self.min_value is None or value < self.min_value:
            self.min_value, self.min_time = value, ts
        if self.max_value is None or value > self.max_value:
            self.max_value, self.max_time = value, ts

        if self.first_value is None:
            self.first_value = value
        self.last_value = value  # assumes in-order delivery, same as min/max above

        # Assumption: BIT_OR channels carry already-integral bit-flag readings
        # (status/alarm masks), so nearest-int rounding is a safe cast, not a
        # lossy one - see output_manager.Algorithm.BIT_OR.
        int_value = int(round(value))
        self.bit_or_value = int_value if self.bit_or_value is None else (self.bit_or_value | int_value)

        dl = reading.detection_limit
        if dl:
            if -dl <= value <= dl:
                self.any_in_detection_band = True
            elif value < -dl:
                self.any_below_neg_detection = True
        if reading.allowed_min_value is not None and value < reading.allowed_min_value:
            self.any_below_allowed_min = True
        if reading.allowed_max_value is not None and value > reading.allowed_max_value:
            self.any_above_allowed_max = True

    def is_due(self, now: datetime) -> bool:
        return now >= self.hour_start + timedelta(hours=1) + _FLUSH_GRACE

    def compute(self):
        """Returns (val, p_cod, s_cod, perc, min_value, min_time, max_value, max_time, stddev)."""
        expected = (self.mean_interval / self.polling_interval) if self.polling_interval else 0
        if expected > 0:
            perc = round(100 * self.count_valid / expected)
        else:
            perc = 100 if self.count_valid else 0
        perc = max(0, min(100, perc))

        if self.count_valid:
            mean = self.sum_value / self.count_valid
            variance = max(0.0, self.sum_sq / self.count_valid - mean * mean)
            stddev = math.sqrt(variance)

            handler = _ALGORITHM_HANDLERS.get(self.algorithm)
            if handler is None:
                if self.algorithm not in (None, output_manager.Algorithm.AVERAGE):
                    logging.warning(
                        f"[output_broker] Algorithm {self.algorithm} not implemented for "
                        f"channel '{self.channel_name}'; falling back to Average"
                    )
                handler = _agg_average
            val = handler(self, mean)
        else:
            val = None
            stddev = 0.0

        # Rounded only now, on the finished mean/min/max/stddev - every value
        # that fed them (sum_value, sum_sq, min_value, max_value above) stayed
        # unrounded through the whole hour.
        val = _round_value(val, self.decimals)
        min_value = _round_value(self.min_value, self.decimals)
        max_value = _round_value(self.max_value, self.decimals)
        stddev = _round_value(stddev, self.decimals)

        p_cod = 0
        if self.count_valid == 0 or perc < self.readings_min_percentage:
            p_cod |= 128
        if self.any_in_detection_band:
            p_cod |= 512
        if self.any_below_neg_detection:
            p_cod |= 1024
        if self.any_below_allowed_min:
            p_cod |= 2048
        if self.any_above_allowed_max:
            p_cod |= 4096

        s_cod = 0  # no real station status signal exists today

        return val, p_cod, s_cod, perc, min_value, self.min_time, max_value, self.max_time, stddev

    def to_dict(self) -> dict:
        d = asdict(self)
        d["hour_start"] = self.hour_start.isoformat()
        d["min_time"] = self.min_time.isoformat() if self.min_time else None
        d["max_time"] = self.max_time.isoformat() if self.max_time else None
        return d

    @classmethod
    def from_dict(cls, d: dict) -> "_HourBucket":
        d = dict(d)
        d["hour_start"] = datetime.fromisoformat(d["hour_start"])
        d["min_time"] = datetime.fromisoformat(d["min_time"]) if d.get("min_time") else None
        d["max_time"] = datetime.fromisoformat(d["max_time"]) if d.get("max_time") else None
        return cls(**d)


class _StationWriter:
    """Formats and writes one station's OPAS NEO instant-reading and hourly-mean files.

    Owns the "last known reading per channel" state needed to rewrite
    file_istantanei in full on every update, even when only one channel
    changed, plus the in-progress hourly-mean accumulator per channel (see
    _HourBucket). Shared by the broker process (one instance per station, fed
    by every driver process of that station) and DirectOutputWriter (a
    same-process fallback used when no broker is configured).
    """

    def __init__(self, data_root, station_header: str):
        self._data_root = Path(data_root)
        self._station_header = station_header
        self._last_known = {}  # channel_id -> (timestamp, value, p_cod)
        self._last_known_raw = {}  # channel_id -> (timestamp, raw_value, p_cod)
        self._buckets: dict[int, _HourBucket] = {}  # channel_id -> in-progress hour

    def write(self, reading: "output_manager.Reading") -> None:
        ts = reading.timestamp or datetime.now()
        p_cod = _status_code(reading)
        # Rounded for every file this instant reading reaches; the hourly-mean
        # path below ingests reading.value itself (unrounded) instead.
        display_value = _round_value(reading.value, reading.decimals)
        self._last_known[reading.channel_id] = (ts, display_value, p_cod)

        try:
            self._write_instant_file()
        except Exception as e:
            logging.warning(f"[output_broker] Failed writing file_istantanei: {e}")

        # Raw value is never rounded via Channel["Decimals"] - that's a display
        # concern for the converted value; file_istantanei_raw keeps full
        # precision and any decimal cap is applied client-side (Electron UI).
        raw_p_cod = _status_code_for_value(reading.raw_value)
        self._last_known_raw[reading.channel_id] = (ts, reading.raw_value, raw_p_cod)

        try:
            self._write_instant_raw_file()
        except Exception as e:
            logging.warning(f"[output_broker] Failed writing file_istantanei_raw: {e}")

        try:
            self._append_letture_dat(reading.channel_id, ts, display_value, p_cod)
        except Exception as e:
            logging.warning(f"[output_broker] Failed writing files_letture_dat: {e}")

        # files_letture_csv is DATA;VALORE only (no status field in the spec),
        # so a missing value has no way to be represented there other than
        # omitting the row entirely; the .dat files above already carry P.COD
        # for this case, so no data is lost.
        if display_value is not None:
            try:
                self._append_letture_csv(reading.channel_name, ts, display_value)
            except Exception as e:
                logging.warning(f"[output_broker] Failed writing files_letture_csv: {e}")

        try:
            self._ingest_hourly(reading, ts)
        except Exception as e:
            logging.warning(f"[output_broker] Failed ingesting hourly mean: {e}")

    def _write_instant_file(self) -> None:
        path = self._data_root / "file_istantanei" / f"{self._station_header}.dat"
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = str(path) + ".tmp"
        lines = [
            f"{ts:%Y-%m-%d %H:%M:%S},{channel_id},{_format_value(value)},{p_cod}"
            for channel_id, (ts, value, p_cod) in sorted(self._last_known.items())
        ]
        with open(tmp_path, "w", newline="") as f:
            f.write("\n".join(lines) + ("\n" if lines else ""))
        _replace_with_retry(tmp_path, path)

    def _write_instant_raw_file(self) -> None:
        path = self._data_root / "file_istantanei_raw" / f"{self._station_header}.dat"
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = str(path) + ".tmp"
        lines = [
            f"{ts:%Y-%m-%d %H:%M:%S},{channel_id},{_format_value(value)},{p_cod}"
            for channel_id, (ts, value, p_cod) in sorted(self._last_known_raw.items())
        ]
        with open(tmp_path, "w", newline="") as f:
            f.write("\n".join(lines) + ("\n" if lines else ""))
        _replace_with_retry(tmp_path, path)

    def _append_letture_dat(self, channel_id, ts, value, p_cod) -> None:
        row = f"{ts:%Y-%m-%d %H:%M:%S},{channel_id},{_format_value(value)},{p_cod}\n"

        daily_dir = self._data_root / "files_letture_dat" / f"{ts:%Y%m}"
        daily_dir.mkdir(parents=True, exist_ok=True)
        daily_path = daily_dir / f"{self._station_header}-{ts:%Y-%m-%d}.dat"
        with open(daily_path, "a", newline="") as f:
            f.write(row)

        # Hourly file lives directly under files_letture_dat\, not in a
        # <YYYYMM> subfolder (see spec directory example); never deleted by
        # the broker - that's the responsibility of whatever sends it.
        hourly_dir = self._data_root / "files_letture_dat"
        hourly_dir.mkdir(parents=True, exist_ok=True)
        hourly_path = hourly_dir / f"{self._station_header}-{ts:%Y-%m-%d-%H}-00-00.dat"
        with open(hourly_path, "a", newline="") as f:
            f.write(row)

    def _append_letture_csv(self, channel_name, ts, value) -> None:
        safe_name = str(channel_name).replace("/", "_").replace("\\", "_")
        csv_dir = self._data_root / "files_letture_csv" / f"{ts:%Y%m}"
        csv_dir.mkdir(parents=True, exist_ok=True)
        csv_path = csv_dir / f"{safe_name}-{ts:%Y-%m-%d}.csv"
        row = f"{ts:%d/%m/%Y %H:%M:%S};{_format_value(value, ',')}\n"
        with open(csv_path, "a", newline="") as f:
            f.write(row)

    # ---- Hourly means (files_medie_csv / files_medie_dat) ----

    def _new_bucket(self, reading: "output_manager.Reading", hour_start: datetime) -> "_HourBucket":
        return _HourBucket(
            channel_name=reading.channel_name,
            hour_start=hour_start,
            mean_interval=reading.mean_interval,
            polling_interval=reading.polling_interval,
            readings_min_percentage=reading.readings_min_percentage,
            decimals=reading.decimals,
            algorithm=reading.algorithm,
        )

    def _ingest_hourly(self, reading: "output_manager.Reading", ts: datetime) -> None:
        this_hour = ts.replace(minute=0, second=0, microsecond=0)
        bucket = self._buckets.get(reading.channel_id)

        if bucket is None:
            bucket = self._new_bucket(reading, this_hour)
            self._buckets[reading.channel_id] = bucket
        elif this_hour > bucket.hour_start:
            # The old hour is provably over: this channel's own clock just
            # produced a reading in the next hour.
            self._flush_hourly_bucket(reading.channel_id, bucket)
            bucket = self._new_bucket(reading, this_hour)
            self._buckets[reading.channel_id] = bucket
        elif this_hour < bucket.hour_start:
            logging.warning(
                f"[output_broker] Out-of-order reading for channel {reading.channel_id} "
                f"({this_hour}) is older than its already-open bucket ({bucket.hour_start}); dropping."
            )
            return

        bucket.ingest(reading, ts)

    def flush_due_hourly_buckets(self, now: datetime | None = None) -> None:
        """Flush any channel's bucket whose hour has elapsed, even if no new
        reading arrives to trigger it (e.g. a driver that stops entirely) -
        called from run_broker()'s own idle tick, the only scheduler
        primitive available in this codebase.
        """
        now = now or datetime.now()
        due = [cid for cid, b in self._buckets.items() if b.is_due(now)]
        for channel_id in due:
            bucket = self._buckets.pop(channel_id)
            self._flush_hourly_bucket(channel_id, bucket)

    def _flush_hourly_bucket(self, channel_id: int, bucket: "_HourBucket") -> None:
        val, p_cod, s_cod, perc, min_value, min_time, max_value, max_time, stddev = bucket.compute()

        try:
            self._append_medie_csv(bucket.channel_name, bucket.hour_start, val, p_cod)
        except Exception as e:
            logging.warning(f"[output_broker] Failed writing files_medie_csv: {e}")

        try:
            self._append_medie_dat(channel_id, bucket.hour_start, val, p_cod, s_cod, perc,
                                    min_value, min_time, max_value, max_time, stddev)
        except Exception as e:
            logging.warning(f"[output_broker] Failed writing files_medie_dat: {e}")

    def _append_medie_csv(self, channel_name, hour_start, val, p_cod) -> None:
        safe_name = str(channel_name).replace("/", "_").replace("\\", "_")
        csv_dir = self._data_root / "files_medie_csv" / f"{hour_start:%Y%m}"
        csv_dir.mkdir(parents=True, exist_ok=True)
        csv_path = csv_dir / f"{safe_name}-{hour_start:%Y-%m-%d}.csv"
        row = f"{hour_start:%d/%m/%Y %H:%M:%S};{_format_value(val, ',')};{p_cod}\n"
        with open(csv_path, "a", newline="") as f:
            f.write(row)

    def _append_medie_dat(self, channel_id, hour_start, val, p_cod, s_cod, perc,
                           min_value, min_time, max_value, max_time, stddev) -> None:
        h_min = f"{min_time:%H:%M:%S}" if min_time is not None else "00:00:00"
        h_max = f"{max_time:%H:%M:%S}" if max_time is not None else "00:00:00"
        row = (f"{hour_start:%Y-%m-%d %H:%M:%S},{channel_id},{_format_value(val)},{p_cod},"
               f"{s_cod},{perc},{_format_value(min_value)},{h_min},"
               f"{_format_value(max_value)},{h_max},{_format_value(stddev)}\n")

        daily_dir = self._data_root / "files_medie_dat" / f"{hour_start:%Y%m}"
        daily_dir.mkdir(parents=True, exist_ok=True)
        with open(daily_dir / f"{self._station_header}-{hour_start:%Y-%m-%d}.dat", "a", newline="") as f:
            f.write(row)

        # Hourly file, directly under files_medie_dat\ like its files_letture_dat
        # sibling - never deleted by the broker, that's the responsibility of
        # whatever sends it to the centro.
        hourly_dir = self._data_root / "files_medie_dat"
        hourly_dir.mkdir(parents=True, exist_ok=True)
        with open(hourly_dir / f"{self._station_header}-{hour_start:%Y-%m-%d-%H}-00-00.dat", "a", newline="") as f:
            f.write(row)

    # ---- Persistence of in-progress buckets across a clean broker restart ----

    def save_state(self, state_path: Path) -> None:
        """Persist in-progress hourly buckets so a clean restart mid-hour can
        resume them instead of losing that hour's data, or double-counting it
        by starting a second bucket for the same hour.
        """
        if not self._buckets:
            return
        try:
            state_path.parent.mkdir(parents=True, exist_ok=True)
            data = {str(cid): b.to_dict() for cid, b in self._buckets.items()}
            tmp_path = str(state_path) + ".tmp"
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(data, f)
            _replace_with_retry(tmp_path, state_path)
            logging.info(f"[output_broker] Saved {len(data)} in-progress hourly bucket(s) to {state_path}")
        except Exception as e:
            logging.warning(f"[output_broker] Failed saving hourly bucket state: {e}")

    def load_state(self, state_path: Path) -> None:
        """Restore in-progress hourly buckets saved by a previous clean
        shutdown, but only for the hour that is still current - a bucket for
        an hour that has already elapsed is incomplete and would produce a
        wrong/stale row, so it is discarded rather than flushed.
        """
        if not state_path.exists():
            return
        try:
            with open(state_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            logging.warning(f"[output_broker] Failed reading hourly bucket state: {e}")
            data = {}

        current_hour = datetime.now().replace(minute=0, second=0, microsecond=0)
        restored = 0
        for cid_str, bucket_dict in data.items():
            try:
                bucket = _HourBucket.from_dict(bucket_dict)
            except Exception as e:
                logging.warning(f"[output_broker] Skipping unreadable saved bucket for channel {cid_str}: {e}")
                continue
            if bucket.hour_start == current_hour:
                self._buckets[int(cid_str)] = bucket
                restored += 1
            else:
                logging.info(
                    f"[output_broker] Discarding saved hourly bucket for channel {cid_str} "
                    f"(hour {bucket.hour_start} has already elapsed)"
                )

        if restored:
            logging.info(f"[output_broker] Resumed {restored} in-progress hourly bucket(s) from {state_path}")

        try:
            state_path.unlink()
        except Exception:
            pass


def run_broker(data_root, station_header: str, in_queue, stop_event=None) -> None:
    """Consume Reading objects from `in_queue` and write them to disk.

    Intended to be used as a `multiprocessing.Process` target. Runs until
    `stop_event` is set, following the same shutdown convention as
    `serial_port_broker.run_broker`.
    """
    # Started via multiprocessing.Process, so this is a fresh child process -
    # without this, Ctrl+C's SIGINT (which POSIX delivers to every process in
    # the foreground process group, not just the parent) hits Python's
    # default handler here and raises KeyboardInterrupt straight out of the
    # blocking in_queue.get() below. That's a BaseException, not an
    # Exception, so it isn't caught by the `except Exception` there either -
    # it would escape run_broker() entirely, print an unhandled-exception
    # traceback, and skip writer.save_state(). Same fix as driver_sdk.
    # run_driver() already applies for driver processes.
    common.setup_signal_handlers()

    writer = _StationWriter(data_root, station_header)
    state_path = Path(data_root) / _STATE_FILENAME
    writer.load_state(state_path)
    logging.info(f"[output_broker] Started for station '{station_header}', writing under {data_root}")

    while (stop_event is None or not stop_event.is_set()) and common.should_run():
        try:
            reading = in_queue.get(timeout=1.0)
        except queue_module.Empty:
            reading = None
        except Exception as e:
            logging.warning(f"[output_broker] Error reading from queue: {e}")
            reading = None

        if reading is not None:
            try:
                writer.write(reading)
            except Exception as e:
                logging.warning(f"[output_broker] Unexpected error writing reading: {e}")

        # Runs every pass (not only when the queue was empty) so a channel
        # that has gone silent still gets its hour flushed on time even while
        # its neighbors keep reporting.
        try:
            writer.flush_due_hourly_buckets()
        except Exception as e:
            logging.warning(f"[output_broker] Error flushing hourly buckets: {e}")

    writer.save_state(state_path)
    logging.info(f"[output_broker] Shutting down for station '{station_header}'")
