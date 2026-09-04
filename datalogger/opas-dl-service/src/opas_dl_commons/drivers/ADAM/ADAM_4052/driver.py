"""ADAM-4052 driver, written against driver_sdk.py.

Sends a single "$016" (module address 01, read digital-input status) command
per polling cycle and maps each active channel's DataArrayIdx to a bit in the
16-bit status word returned. One request answers every channel at once, so
this overrides read_all_channels() rather than read_channel().
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

ADAM_4052_ADDR = "01"


class ADAM4052Driver(driver_sdk.BaseDriver):
    def connect(self):
        self._channel = driver_sdk.comm_manager.create_channel(self.module_config)
        self._channel.connect()

    def read_all_channels(self, channels):
        command_bytes = (f"${ADAM_4052_ADDR}6\r").encode("ascii")

        try:
            if driver_sdk.comm_manager.is_serial(self._channel):
                self._channel.send(command_bytes)
                raw_data = self._channel.recv_until(b"\r")
            elif driver_sdk.comm_manager.is_tcp(self._channel):
                self._channel.send(command_bytes)
                raw_data = self._channel.recv(1024, timeout=2.0)
            else:
                self.log.warning(f"Unsupported channel type: {self._channel.channel_type}")
                return {ch.get("Name"): None for ch in channels}
        except Exception as e:
            self.log.warning(f"Channel communication error: {e}")
            return {ch.get("Name"): None for ch in channels}

        response = raw_data.decode("ascii", errors="ignore").strip()
        if not response.startswith("!"):
            self.log.warning(f"Response does not start with '!': {response!r}")
            return {ch.get("Name"): None for ch in channels}

        # Typical response: "!XXXX00" - XXXX is the hex value of the 16 digital inputs.
        try:
            status_word = int(response[1:5], 16)
        except ValueError:
            self.log.warning(f"Could not parse hex status word from response: {response!r}")
            return {ch.get("Name"): None for ch in channels}
        bits = [1 if (status_word & (1 << i)) else 0 for i in range(16)]

        results = {}
        for ch in channels:
            name = ch.get("Name", "UnknownChannel")
            try:
                bit_index = int(ch.get("DataArrayIdx"))
            except (TypeError, ValueError):
                self.log.error(f"Channel '{name}' has an invalid non-integer DataArrayIdx: {ch.get('DataArrayIdx')!r}")
                results[name] = None
                continue
            if 0 <= bit_index < len(bits):
                results[name] = bits[bit_index]
            else:
                self.log.warning(f"Channel '{name}' DataArrayIdx {bit_index} is out of range (0-15)")
                results[name] = None
        return results

    def disconnect(self):
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(ADAM4052Driver)
