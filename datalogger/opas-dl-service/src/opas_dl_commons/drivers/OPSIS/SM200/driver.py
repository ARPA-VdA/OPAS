"""OPSIS SM200 driver, written against driver_sdk.py.

Sends #206 command to get buffer position, then #207 command to retrieve data.
Parses comma-separated response data (30 fields) and maps values to channels based on their Address index.
Applies optional RegularExpression patterns to extract and validate numeric values.
Includes instrument status handling (pneumatic status, beta status).
Includes data age validation (data must not be older than 55 hours).
"""

import importlib.util
import os
import re
import time
from datetime import datetime, timedelta

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
        self.log.info("[driver_opsis_sm200] Serial connection established")

    def _is_numeric(self, value: str) -> bool:
        """Check if a string represents a valid number."""
        if not isinstance(value, str):
            return False
        try:
            float(value)
            return True
        except (ValueError, TypeError):
            return False

    def _get_sm200_datetime_unix(self, date_str: str) -> int | None:
        """Convert OPSIS SM200 date string (YYYYMMDD format) to unix timestamp.

        Args:
            date_str: Date string in format YYYYMMDD (e.g., "20231003")

        Returns:
            Unix timestamp as integer, or None if parsing fails
        """
        try:
            # Parse date string in format YYYYMMDD
            if len(date_str) != 8:
                self.log.warning(f"[driver_opsis_sm200] Invalid date string length: {date_str}")
                return None

            dt = datetime.strptime(date_str, "%Y%m%d")
            # Convert to unix timestamp
            epoch = datetime(1970, 1, 1)
            timestamp = int((dt - epoch).total_seconds())
            self.log.debug(f"[driver_opsis_sm200] Converted date {date_str} to timestamp {timestamp}")
            return timestamp
        except Exception as e:
            self.log.warning(f"[driver_opsis_sm200] Error converting date string '{date_str}': {e}")
            return None

    def _get_buffer_position(self) -> float | None:
        """Query instrument to get current buffer position.

        Sends #206 command and expects response like:
        #206,   24, 2047,20151102,0000,8249

        Returns:
            Buffer position as float, or None if error
        """
        try:
            command = "#206\r"
            regex_pattern = r"^#206,(.+?),.+,.+,.+,.+"

            self.log.debug(f"[driver_opsis_sm200] Getting buffer position, sending: {command!r}")
            self._channel.send(command.encode())

            # Receive response until CR
            self.log.debug("[driver_opsis_sm200] Receive response until CR")
            response = self._channel.recv(4096, timeout=2.0)
            self.log.debug("[driver_opsis_sm200] Done")
            if not response:
                self.log.warning("[driver_opsis_sm200] No response to #206 command")
                return None

            response_text = response.decode("utf-8", errors="ignore").strip()
            self.log.debug(f"[driver_opsis_sm200] Buffer position response: {response_text!r}")

            # Extract position using regex
            regex = re.compile(regex_pattern)
            match = regex.search(response_text)
            if match:
                pos_str = match.group(1).strip()
                if self._is_numeric(pos_str):
                    pos = float(pos_str)
                    self.log.debug(f"[driver_opsis_sm200] Buffer position: {pos}")
                    return pos
                else:
                    self.log.warning(f"[driver_opsis_sm200] Position value not numeric: {pos_str}")
                    return None
            else:
                self.log.warning(f"[driver_opsis_sm200] Position regex pattern did not match response")
                return None

        except Exception as e:
            self.log.error(f"[driver_opsis_sm200] Error getting buffer position: {type(e).__name__}: {e}")
            return None

    def _get_target_concentration(self, pos: float) -> list | None:
        """Query instrument to get target concentration data for given buffer position.

        Sends #207 command with buffer position and expects 30 comma-separated fields.

        Args:
            pos: Buffer position from _get_buffer_position()

        Returns:
            List of 30 string values (comma-separated fields), or None if error
        """
        try:
            # Format position with 5 digits, zero-padded
            pos_str = f"{int(pos):05d}"
            command = f"#207{pos_str}\r"
            regex_pattern = r"^#207,(.+)"

            self.log.debug(f"[driver_opsis_sm200] Getting target concentration, sending: {command!r}")
            self._channel.send(command.encode())

            # Receive response until CR
            response = self._channel.recv(4096, timeout=2.0)
            if not response:
                self.log.warning("[driver_opsis_sm200] No response to #207 command")
                return None

            response_text = response.decode("utf-8", errors="ignore").strip()
            self.log.debug(f"[driver_opsis_sm200] Target concentration response: {response_text!r}")

            # Extract data using regex
            regex = re.compile(regex_pattern)
            match = regex.search(response_text)
            if not match:
                self.log.warning(f"[driver_opsis_sm200] Data regex pattern did not match response")
                return None

            # Split by comma
            data = match.group(1).strip()
            #self.log.trace(f"[driver_opsis_sm200] Response data: {data}")

            value_array = data.split(",")
            self.log.debug(f"[driver_opsis_sm200] Response array size: {len(value_array)}")
            #self.log.trace(f"[driver_opsis_sm200] Response array: {value_array}")

            if len(value_array) != 29:
                self.log.warning(f"[driver_opsis_sm200] Expected 30 fields, got {len(value_array)}")
                return None

            return value_array

        except Exception as e:
            self.log.error(f"[driver_opsis_sm200] Error getting target concentration: {type(e).__name__}: {e}")
            return None

    def read_all_channels(self, channels):
        """Read all channels from OPSIS SM200 instrument.

        Sends #206 command to get buffer position, then #207 command to retrieve data.
        Parses comma-separated response (30 fields) and extracts parameter values.

        Data validation includes:
        - Pneumatic status check (Bit flags)
        - Beta status check (Bit flags)
        - Data age validation (must be within 55 hours)

        Args:
            channels: List of channel configuration dictionaries with:
                - Name: channel name
                - DataArrayIdx: index in comma-separated response (0-based)
                - Active: whether to read this channel

        Returns:
            Dictionary mapping channel names to their values, or None on error
        """
        results = {}

        try:
            # Step 1: Get buffer position
            self.log.info(f"[driver_opsis_sm200] Get buffer position")
            pos = self._get_buffer_position()
            if pos is None or pos < 0:
                self.log.error("[driver_opsis_sm200] Invalid buffer position")
                return {ch.get("Name"): None for ch in channels}

            # Step 2: Get target concentration data
            self.log.info(f"[driver_opsis_sm200] Get target concentration data")
            value_array = self._get_target_concentration(pos)
            if value_array is None:
                self.log.error("[driver_opsis_sm200] Failed to get target concentration data")
                return {ch.get("Name"): None for ch in channels}

            #self.log.debug(f"[driver_opsis_sm200] value_array: {value_array}")

            # Step 3: Validate data - check status flags
            self.log.info(f"[driver_opsis_sm200] Validate target concentration data")
            # Pneumatic status is at index 26 (27th field), Beta status at index 27 (28th field)
            try:
                pneumatic_status = int(value_array[27].strip())
                beta_status = int(value_array[28].strip())

                self.log.info(f"[driver_opsis_sm200] Pneumatic status: {pneumatic_status}, Beta status: {beta_status}")

                # Status 128 indicates invalid data (only certain bits set)
                if pneumatic_status == 128 and beta_status == 128:
                    self.log.warning("[driver_opsis_sm200] Data invalid - discarding (status = 128)")
                    return {ch.get("Name"): None for ch in channels}
            except (ValueError, IndexError) as e:
                self.log.warning(f"[driver_opsis_sm200] Could not parse status fields: {e}")

            # Step 4: Validate data age
            try:
                # Date is at index 2 (sampling start date in YYYYMMDD format)
                date_str = value_array[1].strip()
                self.log.debug(f"[driver_opsis_sm200] Date '{date_str}'")
                timestamp = self._get_sm200_datetime_unix(date_str)
                self.log.debug(f"[driver_opsis_sm200] Timestamp '{timestamp}'")

                if timestamp is not None:
                    dt = datetime.fromtimestamp(timestamp)
                    hours_diff = int((datetime.now() - dt).total_seconds() / 3600)
                    self.log.info(f"[driver_opsis_sm200] Data age: {hours_diff} hours")

                    # Data older than 55 hours is discarded
                    if hours_diff > 55:
                        self.log.warning(f"[driver_opsis_sm200] Data too old ({hours_diff} hours) - discarding")
                        return {ch.get("Name"): None for ch in channels}

                    # To be stored for data file
                    # # Set datetime for all channels
                    # for ch in channels:
                    #     ch_obj = driver_sdk.ClassChannel(ch)  # Create channel object if needed
                    #     # Store datetime (this would need proper integration with channel objects)

            except Exception as e:
                self.log.warning(f"[driver_opsis_sm200] Error validating data age: {e}")

            # Step 5: Process each active channel
            for idx, channel_config in enumerate(channels):
                name = channel_config.get("Name")
                #address = channel_config.get("Address", "")
                array_idx = int(channel_config.get("DataArrayIdx"))
                is_active = channel_config.get("Active", True)

                # Skip inactive channels
                if not is_active:
                    self.log.debug(f"[driver_opsis_sm200] Channel '{name}' is not active, skipping")
                    results[name] = None
                    continue

                # # Skip channels with no address
                # if not address or address == "":
                #     self.log.debug(f"[driver_opsis_sm200] Channel '{name}' has no address, skipping")
                #     results[name] = None
                #     continue

                # # Convert address to index
                # try:
                #     array_idx = int(address)
                # except (ValueError, TypeError):
                #     self.log.warning(f"[driver_opsis_sm200] Channel '{name}' has invalid address: {address}")
                #     results[name] = None
                #     continue

                # Check if index is within array bounds
                if len(value_array) <= array_idx:
                    self.log.warning(f"[driver_opsis_sm200] Address {array_idx} exceeds array size {len(value_array)} for channel '{name}'")
                    results[name] = None
                    continue

                # Extract and clean value from array
                item = value_array[array_idx].strip()
                self.log.debug(f"[driver_opsis_sm200] Channel '{name}' (array_idx={array_idx}): raw value '{item}'")

                # Directly validate numeric value
                parsed_value = None
                if self._is_numeric(item):
                    parsed_value = float(item)
                    self.log.debug(f"[driver_opsis_sm200] Parsed numeric value: {parsed_value}")
                else:
                    self.log.debug(f"[driver_opsis_sm200] Value is not numeric: '{item}'")

                results[name] = parsed_value

                # if array_idx == 0:  # Special case for channel index 2 (e.g., Down time)
                #     self.log.debug(f"[driver_opsis_sm200] Down time channel, setting timestamp: {timestamp}")
                #     results[name] = timestamp
                # else:
                #     results[name] = parsed_value

            # Step 6: Add buffer position as last value if configured
            # if channels:
            #     last_channel = channels[-1]
            #     last_name = last_channel.get("Name")
            #     param_id = last_channel.get("ParameterId")

            #     # Check if last channel should contain buffer position (special ParameterId)
            #     if param_id == 9999:  # Special ID for buffer position
            #         results[last_name] = pos
            #         self.log.debug(f"[driver_opsis_sm200] Set buffer position for last channel '{last_name}': {pos}")

            #self.log.trace(f"[driver_opsis_sm200] Read results: {results}")
            return results

        except Exception as e:
            self.log.error(f"[driver_opsis_sm200] Error reading channels: {type(e).__name__}: {e}", exc_info=True)
            results = {ch.get("Name"): None for ch in channels}
            return results

    def disconnect(self):
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
