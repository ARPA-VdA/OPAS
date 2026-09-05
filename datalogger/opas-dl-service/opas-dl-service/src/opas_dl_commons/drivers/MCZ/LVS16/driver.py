"""MCZ LVS16 Heating System driver, written against driver_sdk.py.

Bayern Hessen protocol: Sends "DA\r" command to retrieve 10 parameters.
Parses MD10/MD04 response using regex to extract mantissa and exponent for each ID (001-010),
calculates actual measurements (mantissa * 10^exponent) and applies parameter-specific scales,
then maps results to configured channels by their DataArrayIdx.

Parameters:
0  ID-Flow    (Flow / 1000)
1  ID-Temp    (Temperature / 1000)
2  ID-Press   (Pressure / 1000)
3  ID-Umid    (Humidity)
4  ID-T.Filt  (Filtered Temperature / 10)
5  ID-T.Stor  (Storage Temperature / 1000)
6  ID-probe   (Probe / 1000)
7  ID-ActVol  (Active Volume / 10000)
8  ID-lp.Vol  (Loop Volume / 10000)
9  ID-P.Diff  (Pressure Difference / 10000)
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
        """Read all channels from MCZ LVS16 heating system.

        Sends DA command via Bayern Hessen protocol and parses MD10/MD04 response.
        Extracts 10 parameters with mantissa and exponent, calculates actual values,
        applies parameter-specific scales, and maps results to channels by DataArrayIdx.

        Args:
            channels: List of channel configuration dictionaries with:
                - Name: channel name
                - DataArrayIdx: index 0-9 for the 10 parameters
                - Active: whether to read this channel

        Returns:
            Dictionary mapping channel names to their scaled float values, or None on error
        """
        results = {}

        try:
            # Send Bayern Hessen protocol command: "DA\r"
            command = "DA\r"
            self.log.info(f"[driver_mcz_lvs16] Sending command: {command!r}")
            self._channel.send(command.encode())

            # Receive response until CR terminator
            response = self._channel.recv(2048, timeout=2.0)
            if not response:
                self.log.warning("[driver_mcz_lvs16] No response received")
                return {ch.get("Name"): None for ch in channels}

            response_text = response.decode("utf-8", errors="ignore")
            self.log.debug(f"[driver_mcz_lvs16] Raw response: {response_text!r}")

            # Bayern Hessen regex: Extract 10 IDs (001-010) with mantissa and exponent
            # Format: ID value exponent status1 status2 serial spare
            regex_pattern = (
                r"MD\d{2}\s"  # Match MD10 or MD04
                r"(\d{3})\s([-+]?\d{4})([-+]?\d{2})\s\d{2}\s\d{2}\s\d{3}\s\d{6}\s"  # ID 001 (G1, G2, G3)
                r"(\d{3})\s([-+]?\d{4})([-+]?\d{2})\s\d{2}\s\d{2}\s\d{3}\s\d{6}\s"  # ID 002 (G4, G5, G6)
                r"(\d{3})\s([-+]?\d{4})([-+]?\d{2})\s\d{2}\s\d{2}\s\d{3}\s\d{6}\s"  # ID 003 (G7, G8, G9)
                r"(\d{3})\s([-+]?\d{4})([-+]?\d{2})\s\d{2}\s\d{2}\s\d{3}\s\d{6}\s"  # ID 004 (G10, G11, G12)
                r"(\d{3})\s([-+]?\d{4})([-+]?\d{2})\s\d{2}\s\d{2}\s\d{3}\s\d{6}\s"  # ID 005 (G13, G14, G15)
                r"(\d{3})\s([-+]?\d{4})([-+]?\d{2})\s\d{2}\s\d{2}\s\d{3}\s\d{6}\s"  # ID 006 (G16, G17, G18)
                r"(\d{3})\s([-+]?\d{4})([-+]?\d{2})\s\d{2}\s\d{2}\s\d{3}\s\d{6}\s"  # ID 007 (G19, G20, G21)
                r"(\d{3})\s([-+]?\d{4})([-+]?\d{2})\s\d{2}\s\d{2}\s\d{3}\s\d{6}\s"  # ID 008 (G22, G23, G24)
                r"(\d{3})\s([-+]?\d{4})([-+]?\d{2})\s\d{2}\s\d{2}\s\d{3}\s\d{6}\s"  # ID 009 (G25, G26, G27)
                r"(\d{3})\s([-+]?\d{4})([-+]?\d{2})\s\d{2}\s\d{2}\s\d{3}\s\d{6}"    # ID 010 (G28, G29, G30)
            )

            match = re.search(regex_pattern, response_text)
            if not match:
                self.log.warning("[driver_mcz_lvs16] Response pattern not matched")
                return {ch.get("Name"): None for ch in channels}

            # Scales to apply for each parameter (0-9)
            scales = [1000, 1000, 1000, 1, 10, 1000, 1000, 10000, 10000, 10000]

            # Parse values: groups are arranged as (ID, mantissa, exponent) * 10
            # Group indices: 2,3,5,6,8,9,11,12,14,15,17,18,20,21,23,24,26,27,29,30
            param_indices = [
                (2, 3),    # ID 001 - Flow        -> divide by 1000
                (5, 6),    # ID 002 - Temp        -> divide by 1000
                (8, 9),    # ID 003 - Press       -> divide by 1000
                (11, 12),  # ID 004 - Umid        -> no scale
                (14, 15),  # ID 005 - T.Filt      -> divide by 10
                (17, 18),  # ID 006 - T.Stor      -> divide by 1000
                (20, 21),  # ID 007 - probe       -> divide by 1000
                (23, 24),  # ID 008 - ActVol      -> divide by 10000
                (26, 27),  # ID 009 - lp.Vol      -> divide by 10000
                (29, 30),  # ID 010 - P.Diff      -> divide by 10000
            ]

            parsed_values = []
            for idx, (mant_group, exp_group) in enumerate(param_indices):
                try:
                    mantissa = float(match.group(mant_group))
                    exponent = int(match.group(exp_group))
                    value = mantissa * (10 ** exponent)
                    # Apply scale
                    value = value / scales[idx]
                    parsed_values.append(value)
                    self.log.debug(f"[driver_mcz_lvs16] ID {idx+1:03d}: {mantissa} * 10^{exponent} / {scales[idx]} = {value}")
                except (ValueError, TypeError, IndexError) as e:
                    self.log.warning(f"[driver_mcz_lvs16] Error calculating value for ID {idx+1:03d}: {e}")
                    parsed_values.append(None)

            # Map parsed values to channels by DataArrayIdx
            for channel_config in channels:
                name = channel_config.get("Name")
                is_active = channel_config.get("Active", True)

                if not is_active:
                    results[name] = None
                    continue

                try:
                    arridx = int(channel_config.get("DataArrayIdx", -1))
                except (ValueError, TypeError):
                    arridx = -1

                if 0 <= arridx < len(parsed_values):
                    results[name] = parsed_values[arridx]
                    self.log.debug(f"[driver_mcz_lvs16] Channel '{name}' (idx={arridx}): {results[name]}")
                else:
                    results[name] = None
                    self.log.warning(f"[driver_mcz_lvs16] Channel '{name}' index {arridx} out of range [0-{len(parsed_values)-1}]")

        except Exception as e:
            self.log.error(f"[driver_mcz_lvs16] Error reading channels: {type(e).__name__}: {e}", exc_info=True)
            results = {ch.get("Name"): None for ch in channels}

        self.log.info(f"[driver_mcz_lvs16] Read results: {results}")
        return results

    def disconnect(self):
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
