"""MAGEE AE33 Aethalometer driver, written against driver_sdk.py.

Communicates with MAGEE AE33 Aethalometer instrument via serial port.
Sends "$AE33:D1" command (for BB in %) and parses the response to extract measurement values.
Response format: space-separated values with 71 fields containing date, time, timebase,
channel data (ref, sen1, sen2), flows, pressure, temperature, BB, status values, BC values,
K calibration coefficients, tape advance count, and additional parameters.

Data field indices (0-based):
- 0: Date (YYYY/MM/DD)
- 1: Time (HH:MM:SS)
- 2: Timebase
- 3-23: 7 channels x (Ref, Sen1, Sen2)
- 24-26: Flow1, Flow2, FlowC
- 27: Pressure (Pa)
- 28: Temperature (°C)
- 29: BB (% or ng/m3)
- 30: ContTemp
- 31: SupplyTemp
- 32: Status
- 33: ContStatus
- 34: DetectStatus
- 35: LedStatus
- 36: ValveStatus
- 37: LedTemp
- 38-59: BC values (7 channels x (BC1, BC2, BC_sum))
- 60-66: K values (K1-K7)
- 67: TapeAdvCount
- 68-70: ID communication values
- 71: Total field count
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
        """Initialize serial channel connection."""
        self._channel = driver_sdk.comm_manager.create_channel(self.module_config)
        self._channel.connect()

    def read_all_channels(self, channels):
        """Read measurement from MAGEE AE33 Aethalometer.

        Sends "$AE33:D1" command to request measurement data with BB in % format.
        Parses the space-separated response containing 71+ fields of measurement data.
        Then sends "$AE33:A" command to get tape advance count.

        Args:
            channels: List of channel configuration dictionaries

        Returns:
            Dictionary mapping channel names to their values, or None values on error
        """
        results = {}

        try:
            if not self._channel:
                self.log.error("[driver_magee_ae33] Channel not initialized")
                return {ch.get("Name"): None for ch in channels}

            # Step 1: Request measurement data with BB in %
            command = "$AE33:D1\r"
            self.log.info(f"[driver_magee_ae33] Sending command: {command!r}")

            self._channel.send(command.encode("utf-8"))
            response = self._channel.recv(4096, timeout=2.0)

            if not response:
                self.log.warning("[driver_magee_ae33] No response received for D1 command")
                return {ch.get("Name"): None for ch in channels}

            response_text = response.decode("utf-8", errors="ignore").strip()
            self.log.debug(f"[driver_magee_ae33] Raw response D1: {response_text[:200]!r}...")

            # Parse response
            data_fields = response_text.split()
            self.log.debug(f"[driver_magee_ae33] Parsed {len(data_fields)} fields")

            if len(data_fields) < 66:
                self.log.error(f"[driver_magee_ae33] Response has insufficient fields: {len(data_fields)} < 66")
                return {ch.get("Name"): None for ch in channels}

            # Extract values according to VB.NET client logic
            parsed_values = {}

            # BC values from 7 channels (indices 40, 43, 46, 49, 52, 55, 58)
            # These are BC_sum values (third value of each triplet)
            bc_channels = []
            bcidx = 40
            for ch_idx in range(7):
                try:
                    bc_value = float(data_fields[bcidx])
                    bc_channels.append(bc_value)
                    self.log.debug(f"[driver_magee_ae33] BC{ch_idx + 1} (idx {bcidx}): {bc_value}")
                except (ValueError, IndexError) as e:
                    self.log.warning(f"[driver_magee_ae33] Could not parse BC{ch_idx + 1} at index {bcidx}: {e}")
                    bc_channels.append(None)
                bcidx += 3

            parsed_values["BC_channels"] = bc_channels

            # Diagnostic values
            diagnostic_indices = {
                "FlowC": 26,
                "Pressure": 27,
                "Temperature": 28,
                "BB": 29,
                "ContTemp": 30,
                "SupplyTemp": 31,
                "Status": 32,
                "ContStatus": 33,
                "DetectStatus": 34,
                "LedStatus": 35,
                "ValveStatus": 36,
                "LedTemp": 37,
            }

            for param_name, idx in diagnostic_indices.items():
                try:
                    value = float(data_fields[idx])
                    parsed_values[param_name] = value
                    self.log.debug(f"[driver_magee_ae33] {param_name} (idx {idx}): {value}")
                except (ValueError, IndexError) as e:
                    self.log.warning(f"[driver_magee_ae33] Could not parse {param_name} at index {idx}: {e}")
                    parsed_values[param_name] = None

            # Step 2: Request tape advance count
            command = "$AE33:A\r"
            self.log.info(f"[driver_magee_ae33] Sending command: {command!r}")

            self._channel.send(command.encode("utf-8"))
            response = self._channel.recv(1024, timeout=2.0)

            if response:
                tape_count_text = response.decode("utf-8", errors="ignore").strip()
                try:
                    tape_count = float(tape_count_text)
                    parsed_values["TapeAdvCount"] = tape_count
                    self.log.debug(f"[driver_magee_ae33] TapeAdvCount: {tape_count}")
                except ValueError as e:
                    self.log.warning(f"[driver_magee_ae33] Could not parse TapeAdvCount: {e}")
                    parsed_values["TapeAdvCount"] = None
            else:
                self.log.warning("[driver_magee_ae33] No response received for A command")
                parsed_values["TapeAdvCount"] = None

            # Step 3: Additional fields from index 70 onwards
            additional_values = []
            if len(data_fields) >= 70:
                self.log.debug("[driver_magee_ae33] Adding additional fields from index 70")
                for idx in range(70, len(data_fields)):
                    try:
                        value = float(data_fields[idx])
                        additional_values.append(value)
                        self.log.debug(f"[driver_magee_ae33] Additional field @ index {idx}: {value}")
                    except ValueError as e:
                        self.log.warning(f"[driver_magee_ae33] Could not parse field at index {idx}: {e}")
                        additional_values.append(None)

            parsed_values["Additional"] = additional_values

            # Map parsed values to requested channels
            for channel_config in channels:
                name = channel_config.get("Name", "")
                self.log.debug(f"[driver_magee_ae33] Processing channel: {name}")

                # Try to match channel name to parsed values
                value = None

                # Check if it's a BC channel (BC1, BC2, ..., BC7)
                if name.startswith("BC") and len(name) == 3:
                    try:
                        bc_idx = int(name[2]) - 1  # BC1 -> index 0
                        if 0 <= bc_idx < len(bc_channels):
                            value = bc_channels[bc_idx]
                    except (ValueError, IndexError):
                        pass

                # Check diagnostic parameters
                if value is None and name in parsed_values:
                    value = parsed_values[name]

                results[name] = value
                self.log.debug(f"[driver_magee_ae33] Channel '{name}': {value}")

        except Exception as e:
            self.log.error(f"[driver_magee_ae33] Error reading channels: {type(e).__name__}: {e}", exc_info=True)
            results = {ch.get("Name"): None for ch in channels}

        return results

    def disconnect(self):
        """Close serial channel connection."""
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
