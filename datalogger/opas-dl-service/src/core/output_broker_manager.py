"""Output broker orchestration.

Starts a single dedicated process (see opas_dl_commons/libs/output_broker.py)
that owns all disk writes for the OPAS NEO instant-reading files
(file_istantanei, files_letture_csv, files_letture_dat). Every driver process
of this station is handed the same Queue via output_manager.configure(), so
concurrent writes to the same per-station file never happen.

Unlike shared_serial_ports.py (which only starts a broker when >=2 modules
share a COM port), the output broker always starts: OPAS NEO's per-station
file layout means the sharing problem exists as soon as there is one module,
because a second module (or a driver restart) can join at any time.

    queue, station_header = output_broker_manager.start(active_config)
    ...
    output_broker_manager.shutdown()
"""

import logging
from multiprocessing import Process, Queue, Event

import output_broker


class OutputBrokerManager:
    """Owns the single broker process started for this service's station."""

    def __init__(self):
        self._process = None
        self._stop_event = None
        self._queue = None
        self._station_header = None

    def start(self, active_config: dict):
        """Start the broker process for this service's station.

        Returns (queue, station_header) to be forwarded to driver_manager via
        set_output_context(). Safe to call more than once: returns the
        existing queue/station_header if the broker is already running.
        """
        if self._process is not None and self._process.is_alive():
            return self._queue, self._station_header

        station_header = (active_config or {}).get("DataFileHeader")
        if not station_header:
            logging.warning(
                "[output_broker_manager] Active config has no DataFileHeader; "
                "OPAS NEO output files will use 'unknown-station' as their name."
            )
            station_header = "unknown-station"

        from runtime_paths import RuntimePaths
        data_root = RuntimePaths().opas_neo_data_dir

        self._queue = Queue()
        self._stop_event = Event()
        self._station_header = station_header
        self._process = Process(
            target=output_broker.run_broker,
            args=(data_root, station_header, self._queue, self._stop_event),
            name="output-broker",
            daemon=True,
        )
        self._process.start()
        logging.info(f"[output_broker_manager] Started output broker for station '{station_header}'")
        return self._queue, self._station_header

    def shutdown(self):
        """Stop the broker process, if running."""
        if self._process is None:
            return
        if self._stop_event is not None:
            self._stop_event.set()
        self._process.join(5)
        if self._process.is_alive():
            logging.warning("[output_broker_manager] Broker did not exit in time; terminating")
            self._process.terminate()
            self._process.join(5)
            if self._process.is_alive():
                logging.warning("[output_broker_manager] Broker did not exit after SIGTERM; sending SIGKILL")
                self._process.kill()
                self._process.join()
        self._process = None
        self._queue = None
        self._station_header = None


# singleton instance to be imported by other modules
manager = OutputBrokerManager()
