"""THERMO 42i,43i,48i,49i driver, written against driver_sdk.py.

Sends one "<ChannelAddress>" query per active channel and parses the reply
with the channel's own RegularExpression (falls back to the raw, whitespace-
collapsed response text if a channel has none configured).
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


def parse_response(response_text, regex_pattern):
    """Extract the captured value from an instrument response.

    Returns the raw string from the regex's first capture group, or None if
    the pattern doesn't match (or there is no pattern - see read_channel).
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


class APIDriver(driver_sdk.BaseDriver):
    def connect(self):
        self._channel = driver_sdk.comm_manager.create_channel(self.module_config)
        self._channel.connect()

    def read_channel(self, channel_config):
        name = channel_config.get("Name", "UnknownChannel")
        addr = channel_config.get("Address", "UnknownChannel")
        regex_pattern = channel_config.get("RegularExpression")

        command = f"{addr}"
        self.log.debug(f"[driver_thermo_xxx] Sending command: {command!r}")
        self._channel.send((command + "\r\n").encode())
        response = self._channel.recv(1024, timeout=2.0)
        if not response:
            return None

        response_text = response.decode("utf-8", errors="ignore")
        if regex_pattern:
            # Parsed before any stripping, so the pattern can match \r\n if it needs to.
            return parse_response(response_text, regex_pattern)
        return response_text.replace("\r\n", " ").replace("\r", " ").replace("\n", " ").strip()

    def disconnect(self):
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
