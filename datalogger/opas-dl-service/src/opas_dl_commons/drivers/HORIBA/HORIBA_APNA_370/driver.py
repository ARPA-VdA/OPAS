"""HORIBA APNA 370 driver, written against driver_sdk.py.

Sends a single "DA" command to retrieve all parameters (NO, NO2, NOx) in one response.
Parses the response using a regex pattern to extract mantissa and exponent values,
calculates actual measurements (mantissa * 10^exponent), and maps results to configured
channels by their DataArrayIdx.
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

    def read_all_channels(self, channels):
        """Read all channels from HORIBA APNA 370 instrument.

        Sends a single DA command and parses the response to extract
        NO, NO2, and NOx values with their exponents.

        Args:
            channels: List of channel configuration dictionaries

        Returns:
            Dictionary mapping channel names to their values, or None values on error
        """
        results = {}

        try:
            # Build and send command
            stx = "\x02"
            cr = "\r"
            command = f"{stx}DA{cr}"
            self.log.info(f"[driver_horiba_apna_370] Sending command: {command!r}")

            self._channel.send(command.encode())
            response = self._channel.recv(1024, timeout=2.0)

            if not response:
                self.log.warning("[driver_horiba_apna_370] No response received")
                return {ch.get("Name"): None for ch in channels}

            response_text = response.decode("utf-8", errors="ignore")
            self.log.debug(f"[driver_horiba_apna_370] Raw response: {response_text!r}")

            # Define regex pattern to extract NO, NO2, NOx with their mantissa and exponent
            regex_pattern = (
                r"MD\d\d\s"
                r"011\s([-+]?\d\d\d\d)([-+]?\d\d)\s(\d\d)\s(\w\w)\s\d\d\d\s000000\s"  # NO  (G1, G2, G3, G4)
                r"012\s([-+]?\d\d\d\d)([-+]?\d\d)\s(\d\d)\s(\w\w)\s\d\d\d\s000000\s"  # NO2 (G5, G6, G7, G8)
                r"013\s([-+]?\d\d\d\d)([-+]?\d\d)\s(\d\d)\s(\w\w)\s\d\d\d\s000000"    # NOx (G9, G10, G11, G12)
            )

            match = re.search(regex_pattern, response_text)

            if not match:
                self.log.warning("[driver_horiba_apna_370] Response pattern not matched")
                return {ch.get("Name"): None for ch in channels}

            # Parse extracted values: mantissa * 10^exponent
            def calc_value(mantissa_idx, exponent_idx):
                """Calculate value from mantissa and exponent groups."""
                try:
                    mantissa = float(match.group(mantissa_idx))
                    exponent = int(match.group(exponent_idx))
                    return mantissa * (10 ** exponent)
                except (ValueError, TypeError, IndexError):
                    return None

            # Extract parameter values
            parsed_values = {
                "0": calc_value(1, 2),    # NO
                "1": calc_value(5, 6),    # NO2
                "2": calc_value(9, 10),   # NOx
                "3": match.group(3),      # NO status
                "4": match.group(7),      # NO2 status
                "5": match.group(11),     # NOx status
            }

            self.log.debug(f"[driver_horiba_apna_370] Parsed values: {parsed_values}")

            # Map parsed values to requested channels
            for channel_config in channels:
                name = channel_config.get("Name")
                arridx = str(channel_config.get("DataArrayIdx", "-1"))

                if arridx in parsed_values:
                    results[name] = parsed_values[arridx]
                    self.log.debug(f"[driver_horiba_apna_370] Channel '{name}' (idx={arridx}): {results[name]}")
                else:
                    results[name] = None
                    self.log.warning(f"[driver_horiba_apna_370] Channel '{name}' index {arridx} not found in parsed values")

        except Exception as e:
            self.log.error(f"[driver_horiba_apna_370] Error reading channels: {type(e).__name__}: {e}", exc_info=True)
            results = {ch.get("Name"): None for ch in channels}

        #self.log.info(f"[driver_horiba_apna_370] Read results: {results}")
        return results

    def disconnect(self):
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
