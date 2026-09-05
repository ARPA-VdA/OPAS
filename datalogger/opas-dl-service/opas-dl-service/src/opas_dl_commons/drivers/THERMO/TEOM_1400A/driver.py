"""THERMO TEOM 1400a Mass Monitor driver, written against driver_sdk.py.

Communicates with THERMO TEOM 1400a instrument via serial port.
Sends requests for individual registers and parses responses using regex patterns.
Protocol uses STX (0x02) and ETX (0x03) frame delimiters.

Command format: STX + "4AREG K0 <register>" + ETX + CRLF
Response format: STX + "4AREG K0 <register> <value>" + ETX + CRLF

Supported registers:
- K0 7:  Mass Rate (µg/m³/h)
- K0 8:  Mass Concentration (µg/m³) - main parameter
- K0 9:  Total mass (µg)
- K0 26: Current air temperature (°C)
- K0 35: Filter loading (%)
- K0 39: Current main flow (L/min)
- K0 40: Current auxiliary flow (L/min)
- K0 41: Status condition
- K0 58: Read hour average mass (µg/m³)
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

# TEOM 1400a protocol constants
STX = chr(0x02)  # Start of Text
ETX = chr(0x03)  # End of Text

# TEOM 1400a Register mappings
REGISTER_NAMES = {
    "K0 7":  "Mass Rate",
    "K0 8":  "Mass Concentration",
    "K0 9":  "Total mass",
    "K0 26": "Current air temperature",
    "K0 35": "Filter loading",
    "K0 39": "Current main flow",
    "K0 40": "Current auxiliary flow",
    "K0 41": "Status condition",
    "K0 58": "Read hour average mass",
}


def parse_response(response_text, regex_pattern):
    """Extract the captured value from a TEOM 1400a response.

    The response includes STX, ETX, and CRLF delimiters.
    Regex pattern should capture the value part.

    Returns the raw string from the regex's first capture group, or None if
    the pattern doesn't match.
    """
    if not regex_pattern or not response_text:
        return None
    try:
        match = re.search(regex_pattern, response_text)
        if match:
            return match.group(1)
    except Exception as e:
        return None
    return None


class APIDriver(driver_sdk.BaseDriver):
    def connect(self):
        """Initialize serial channel connection."""
        self._channel = driver_sdk.comm_manager.create_channel(self.module_config)
        self._channel.connect()

    def read_all_channels(self, channels):
        """Read measurements from TEOM 1400a instrument.

        Iterates through each requested channel, sends the appropriate
        register request, and parses the response using the channel's
        RegularExpression.

        Args:
            channels: List of channel configuration dictionaries

        Returns:
            Dictionary mapping channel names to their values, or None values on error
        """
        results = {}

        try:
            if not self._channel:
                self.log.error("[driver_teom_1400a] Channel not initialized")
                return {ch.get("Name"): None for ch in channels}

            for channel_config in channels:
                name = channel_config.get("Name", "UnknownChannel")
                addr = channel_config.get("Address", "UnknownChannel")
                regex_pattern = channel_config.get("RegularExpression")

                self.log.debug(f"[driver_teom_1400a] Reading channel: {name}, Address: {addr}")

                try:
                    # Build TEOM 1400a command
                    # Format: STX + "4AREG K0 <register>" + ETX + CRLF
                    # Address should be in format "K0 X" where X is the register number
                    command = f"{STX}4AREG {addr}{ETX}\r\n"

                    self.log.debug(f"[driver_teom_1400a] Sending command: {command!r}")

                    # Send command
                    self._channel.send(command.encode("utf-8"))

                    # Receive response
                    response = self._channel.recv(1024, timeout=2.0)

                    if not response:
                        self.log.warning(f"[driver_teom_1400a] No response for channel {name}")
                        results[name] = None
                        continue

                    response_text = response.decode("utf-8", errors="ignore")
                    self.log.debug(f"[driver_teom_1400a] Raw response: {response_text!r}")

                    # Parse response using regex pattern
                    if regex_pattern:
                        value_str = parse_response(response_text, regex_pattern)
                        if value_str is not None:
                            try:
                                value = float(value_str)
                                results[name] = value
                                self.log.debug(f"[driver_teom_1400a] Channel '{name}': {value}")
                            except ValueError:
                                self.log.warning(f"[driver_teom_1400a] Could not convert '{value_str}' to float for {name}")
                                results[name] = None
                        else:
                            self.log.warning(f"[driver_teom_1400a] Regex pattern did not match for {name}")
                            results[name] = None
                    else:
                        # No regex pattern - return raw response, collapsed
                        value = response_text.replace("\r\n", " ").replace("\r", " ").replace("\n", " ").strip()
                        results[name] = value
                        self.log.debug(f"[driver_teom_1400a] Channel '{name}' (raw): {value}")

                except Exception as e:
                    self.log.error(f"[driver_teom_1400a] Error reading channel {name}: {type(e).__name__}: {e}", exc_info=True)
                    results[name] = None

        except Exception as e:
            self.log.error(f"[driver_teom_1400a] Error in read_all_channels: {type(e).__name__}: {e}", exc_info=True)
            results = {ch.get("Name"): None for ch in channels}

        return results

    def disconnect(self):
        """Close serial channel connection."""
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
