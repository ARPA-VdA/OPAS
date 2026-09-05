"""ADAM-4013 driver, written against driver_sdk.py.

Sends a single "#02" (module address 02) read-data command per polling cycle
and parses each active channel's value out of the one reply using the
channel's own RegularExpression. One request answers every channel at once,
so this overrides read_all_channels() rather than read_channel().
"""

import importlib.util
import os
import re

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

ADAM_4013_ADDR = "02"


def parse_response(response_text, regex_pattern):
    """Extract the captured value from an instrument response.

    Returns the raw string from the regex's first capture group, or None if
    the pattern doesn't match (or there is no pattern - see read_all_channels).
    """
    if not regex_pattern or not response_text:
        return None
    try:
        match = re.search(regex_pattern, response_text)
        if match:
            return match.group(1)
    except Exception:
        pass
    return None


class ADAM4013Driver(driver_sdk.BaseDriver):
    def connect(self):
        self._channel = driver_sdk.comm_manager.create_channel(self.module_config)
        self._channel.connect()

    def read_all_channels(self, channels):
        command_bytes = (f"#{ADAM_4013_ADDR}\r").encode("ascii")

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
        if not response.startswith(">"):
            self.log.warning(f"Response does not start with '>': {response!r}")
            return {ch.get("Name"): None for ch in channels}

        # Typical response: ">+025.41"
        response_text = response[1:]
        results = {}
        for ch in channels:
            name = ch.get("Name", "UnknownChannel")
            regex_pattern = ch.get("RegularExpression")
            if regex_pattern:
                results[name] = parse_response(response_text, regex_pattern)
            else:
                results[name] = response_text.replace("\r\n", " ").replace("\r", " ").replace("\n", " ").strip()
        return results

    def disconnect(self):
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(ADAM4013Driver)
