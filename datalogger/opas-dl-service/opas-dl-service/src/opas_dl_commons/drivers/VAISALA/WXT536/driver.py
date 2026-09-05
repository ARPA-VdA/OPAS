"""Vaisala WXT536 Weather Transmitter driver, written against driver_sdk.py.

Sends three commands (R1, R2, R3) to query wind, air, and rain data.
Parses responses and applies RegularExpression patterns for each channel.
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
    the pattern doesn't match (or there is no pattern).
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
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Device address for Vaisala WXT536 (configurable via module_config)
        self._device_address = self.module_config.get("DeviceAddress", "0")

    def connect(self):
        self._channel = driver_sdk.comm_manager.create_channel(self.module_config)
        self._channel.connect()

    def _is_numeric(self, value: str) -> bool:
        """Check if a string represents a valid number."""
        if not isinstance(value, str):
            return False
        try:
            float(value)
            return True
        except (ValueError, TypeError):
            return False

    def _send_command(self, command_code):
        """Send command and receive response.

        Args:
            command_code: R1 (wind), R2 (air), or R3 (rain)

        Returns:
            Decoded response string, or None on error
        """
        command = f"{self._device_address}{command_code}\r\n"
        self.log.debug(f"[driver_wxt536] Sending: {command!r}")
        self._channel.send(command.encode())
        response = self._channel.recv(1024, timeout=2.0)
        if not response:
            return None
        response_text = response.decode("utf-8", errors="ignore")
        self.log.debug(f"[driver_wxt536] Response: {response_text!r}")
        return response_text

    def read_all_channels(self, channels):
        """Read all channels from Vaisala WXT536 instrument.

        Sends R1 (wind), R2 (air), and R3 (rain) commands and parses
        responses using RegularExpression patterns for each channel.

        Args:
            channels: List of channel configuration dictionaries with:
                - Name: channel name
                - Address: command to send (R1, R2, or R3)
                - Active: whether to read this channel
                - RegularExpression: regex to extract numeric value from response

        Returns:
            Dictionary mapping channel names to their float values or None
        """
        results = {}
        command_responses = {}

        try:
            # Send all commands and cache responses
            for cmd in ["R1", "R2", "R3"]:
                response = self._send_command(cmd)
                if response:
                    command_responses[cmd] = response
                else:
                    self.log.warning(f"[driver_wxt536] No response for command {cmd}")
                    command_responses[cmd] = ""

            # Process each channel
            for channel_config in channels:
                name = channel_config.get("Name", "UnknownChannel")
                address = channel_config.get("Address", "")
                is_active = channel_config.get("Active", True)
                regex_expr = channel_config.get("RegularExpression", "")

                # Skip inactive channels
                if not is_active:
                    self.log.debug(f"[driver_wxt536] Channel '{name}' is not active")
                    results[name] = None
                    continue

                # Skip channels with no address
                if not address or address not in ["R1", "R2", "R3"]:
                    self.log.warning(f"[driver_wxt536] Channel '{name}' has invalid address: {address}")
                    results[name] = None
                    continue

                # Get response for this command
                response_text = command_responses.get(address, "")
                if not response_text:
                    self.log.debug(f"[driver_wxt536] No response for channel '{name}' (command {address})")
                    results[name] = None
                    continue

                parsed_value = None

                # Apply regex to extract value
                if regex_expr:
                    try:
                        extracted = parse_response(response_text, regex_expr)
                        if extracted is not None:
                            self.log.debug(f"[driver_wxt536] Channel '{name}': regex matched, extracted '{extracted}'")
                            if self._is_numeric(extracted):
                                parsed_value = float(extracted)
                            else:
                                self.log.debug(f"[driver_wxt536] Extracted value not numeric: '{extracted}'")
                        else:
                            self.log.debug(f"[driver_wxt536] Channel '{name}': regex didn't match")
                    except Exception as e:
                        self.log.warning(f"[driver_wxt536] Error applying regex for '{name}': {e}")
                else:
                    # No regex - return raw response (cleaned)
                    parsed_value = response_text.replace("\r\n", " ").replace("\r", " ").replace("\n", " ").strip()

                results[name] = parsed_value
                self.log.debug(f"[driver_wxt536] Channel '{name}' = {parsed_value}")

            self.log.info(f"[driver_wxt536] Read results: {results}")
            return results

        except Exception as e:
            self.log.error(f"[driver_wxt536] Error reading channels: {type(e).__name__}: {e}", exc_info=True)
            return {ch.get("Name"): None for ch in channels}

    def disconnect(self):
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()



if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
