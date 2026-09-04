"""SILENA GAMMA driver, written against driver_sdk.py.

Communicates with SILENA GAMMA instrument via serial port.
Sends a "001MI" command with XOR checksum and parses the response to extract measurement value.
Response format: <STX>01009MIK<value><ETX>
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

class APIDriver(driver_sdk.BaseDriver):
    def connect(self):
        self._channel = driver_sdk.comm_manager.create_channel(self.module_config)
        self._channel.connect()

    def _calculate_checksum(self, data):
        """Calculate XOR checksum for SILENA GAMMA protocol.

        Args:
            data: String to calculate checksum for

        Returns:
            Checksum as a single character
        """
        checksum = 0
        for char in data:
            checksum ^= ord(char)
        return chr(checksum)

    def read_all_channels(self, channels):
        """Read measurement from SILENA GAMMA instrument.

        Sends "001MI" command with checksum and parses the response to extract
        the measurement value.

        Args:
            channels: List of channel configuration dictionaries (typically single channel)

        Returns:
            Dictionary mapping channel names to their values, or None values on error
        """
        results = {}

        try:
            if not self._channel:
                self.log.error("[driver_silena_gamma] Channel not initialized")
                return {ch.get("Name"): None for ch in channels}

            # Prepare command
            command_data = "001MI"
            checksum = self._calculate_checksum(command_data)

            # Build full command: STX(0x82) + 0(0xB0) + 1(0xB1) + data + checksum + ETX(0x03) + CR(0x0D)
            stx = chr(0x82)           # STX with high bit set (2 + 128)
            zero_byte = chr(0xB0)     # '0' with high bit set (48 + 128)
            one_byte = chr(0xB1)      # '1' with high bit set (49 + 128)
            etx = chr(0x03)           # ETX
            cr = chr(0x0D)            # CR

            command = stx + zero_byte + one_byte + command_data + checksum + etx + cr

            self.log.info(f"[driver_silena_gamma] Sending command: {command!r}")

            # Send command and receive response
            self._channel.send(command.encode("latin-1"))
            response = self._channel.recv(1024, timeout=2.0)

            if not response:
                self.log.warning("[driver_silena_gamma] No response received")
                return {ch.get("Name"): None for ch in channels}

            response_text = response.decode("latin-1", errors="ignore")
            self.log.debug(f"[driver_silena_gamma] Raw response: {response_text!r}")

            # Parse response: pattern is ".+MIK(.+)(..)"
            # Example: <STX>01009MIK0000.145D<ETX>
            regex_pattern = r".+MIK(.+)(..)"
            match = re.search(regex_pattern, response_text)

            if not match:
                self.log.warning(f"[driver_silena_gamma] Response pattern not matched. Response: {response_text!r}")
                return {ch.get("Name"): None for ch in channels}

            # Extract the value (group 1)
            value_str = match.group(1).strip()

            try:
                value = float(value_str)
                self.log.debug(f"[driver_silena_gamma] Parsed value: {value}")
            except ValueError:
                self.log.error(f"[driver_silena_gamma] Could not convert value '{value_str}' to float")
                value = None

            # Map value to requested channels
            for channel_config in channels:
                name = channel_config.get("Name")
                results[name] = value
                self.log.debug(f"[driver_silena_gamma] Channel '{name}': {value}")

        except Exception as e:
            self.log.error(f"[driver_silena_gamma] Error reading channels: {type(e).__name__}: {e}", exc_info=True)
            results = {ch.get("Name"): None for ch in channels}

        return results

    def disconnect(self):
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
