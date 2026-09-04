"""Pipe CSV driver, written against driver_sdk.py.

Reads data from a CSV file specified in configuration (PipeFileName).
Parses the CSV file splitting by semicolon (;) and maps values to configured
channels by their DataArrayIdx.
"""

import importlib.util
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Minimal walk-up to locate opas_dl_commons/libs/ - this can't itself live in
# libs/ (it's what finds libs/ before anything there is reachable). See
# libs/driver_bootstrap.py's find_libs_dir() for the documented, canonical
# version of this same walk; everything after this delegates to it.
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

class APIDriver(driver_sdk.BaseDriver):
    def connect(self):
        """Build the PipeFile channel (see comm_manager.PipeFileChannel).

        Nothing is opened ahead of time - the file is read fresh on each
        polling cycle in read_all_channels().
        """
        self._channel = driver_sdk.comm_manager.create_channel(self.module_config)
        self.log.info(f"[driver_pipe_csv] Configured to read from: {self._channel.path}")

    def read_all_channels(self, channels):
        """Read all channels from the pipe file via comm_manager.PipeFileChannel.

        Expected file format: val0;val1;val2;...;valN, mapped to channels by
        their DataArrayIdx. The channel logs its own file-not-found/parse
        outcome; comm_manager.PipeFileChannel.read_values() never raises.

        Returns:
            Dictionary mapping channel names to their values, or None on error
        """
        return self._channel.read_values(channels)

    def disconnect(self):
        """Disconnect from CSV pipe.

        No-op since CSV file reading is stateless.
        """
        self.log.info("[driver_pipe_csv] Disconnecting")


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
