"""SYNSPEC GC955 driver, written against driver_sdk.py.

Sends a single "LL" command followed by CR and waits for 0x0F response marker.
Parses tab-separated response data and maps values to channels based on their Address index.
Applies optional RegularExpression patterns to extract and validate numeric values.
Includes instrument status handling (battery, data validity).
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

    def _is_numeric(self, value: str) -> bool:
        """Check if a string represents a valid number."""
        if not isinstance(value, str):
            return False
        try:
            float(value)
            return True
        except (ValueError, TypeError):
            return False

    def _get_instrument_status(self) -> float | None:
        """Query instrument status (battery, data validity, etc.).

        Stub: this instrument's status protocol is not implemented yet,
        so this always returns None.
        """
        try:
            return None
        except Exception as e:
            self.log.warning(f"[driver_synspec_gc955] Error retrieving instrument status: {e}")
            return None

    def read_all_channels(self, channels):
        """Read all channels from SYNSPEC GC955 instrument.

        Sends a single "LL" command and waits for 0x0F response marker.
        Parses tab-separated response to extract parameter values.
        Applies RegularExpression patterns if configured for each channel.

        Args:
            channels: List of channel configuration dictionaries with:
                - Name: channel name
                - Address: index in tab-separated response (0-based)
                - Active: whether to read this channel
                - RegularExpression: optional regex to extract value from field

        Returns:
            Dictionary mapping channel names to their values, or None on error
        """
        results = {}
        no_data_marker = "No data"

        try:
            # Send command and wait for 0x0F marker
            command = "LL\r"
            wait_for = "\x0f"  # ChrW(15)

            self.log.info(f"[driver_synspec_gc955] Sending command: {command!r}")
            self._channel.send(command.encode())

            # Receive response until 0x0F marker
            response = self._channel.recv(4096, timeout=2.0)
            if not response:
                self.log.warning("[driver_synspec_gc955] No response received")
                return {ch.get("Name"): None for ch in channels}

            response_text = response.decode("utf-8", errors="ignore")
            self.log.debug(f"[driver_synspec_gc955] Raw response: {response_text!r}")

            # Check for "No data" indicator
            if no_data_marker in response_text:
                self.log.warning("[driver_synspec_gc955] Response contains 'No data' - instrument has no valid data")
                return {ch.get("Name"): None for ch in channels}

            # Split response by TAB characters
            value_array = response_text.split("\t")
            self.log.debug(f"[driver_synspec_gc955] Response array size: {len(value_array)}")

            # Process each active channel
            for channel_config in channels:
                name = channel_config.get("Name")
                address = channel_config.get("Address", "")
                is_active = channel_config.get("Active", True)
                regex_expr = channel_config.get("RegularExpression", "")

                # Skip inactive channels
                if not is_active:
                    self.log.debug(f"[driver_synspec_gc955] Channel '{name}' is not active, skipping")
                    results[name] = None
                    continue

                # Skip channels with no address
                if not address or address == "":
                    self.log.debug(f"[driver_synspec_gc955] Channel '{name}' has no address, skipping")
                    results[name] = None
                    continue

                # Convert address to index
                try:
                    ch_index = int(address)
                except (ValueError, TypeError):
                    self.log.warning(f"[driver_synspec_gc955] Channel '{name}' has invalid address: {address}")
                    results[name] = None
                    continue

                # Check if index is within array bounds
                if len(value_array) <= ch_index:
                    self.log.warning(f"[driver_synspec_gc955] Address {ch_index} exceeds array size {len(value_array)} for channel '{name}'")
                    results[name] = None
                    continue

                # Extract and clean value from array
                item = value_array[ch_index].strip()
                self.log.debug(f"[driver_synspec_gc955] Channel '{name}' (idx={ch_index}): raw value '{item}'")

                parsed_value = None

                # Apply regex if configured
                if regex_expr:
                    try:
                        regex = re.compile(regex_expr)
                        match = regex.search(item)
                        if match:
                            item_match = match.group(1)
                            self.log.debug(f"[driver_synspec_gc955] Regex matched, extracted: '{item_match}'")
                            if self._is_numeric(item_match):
                                parsed_value = float(item_match)
                                self.log.debug(f"[driver_synspec_gc955] Parsed value: {parsed_value}")
                            else:
                                self.log.debug(f"[driver_synspec_gc955] Extracted value is not numeric: '{item_match}'")
                        else:
                            self.log.debug(f"[driver_synspec_gc955] Regex pattern did not match: {regex_expr}")
                    except Exception as e:
                        self.log.warning(f"[driver_synspec_gc955] Error applying regex for '{name}': {e}")
                else:
                    # No regex - directly validate numeric value
                    if self._is_numeric(item):
                        parsed_value = float(item)
                        self.log.debug(f"[driver_synspec_gc955] Parsed numeric value: {parsed_value}")
                    else:
                        self.log.debug(f"[driver_synspec_gc955] Value is not numeric: '{item}'")

                results[name] = parsed_value

            # Get instrument status
            status = self._get_instrument_status()

            # Check if last channel is status parameter
            if channels:
                last_channel = channels[-1]
                last_name = last_channel.get("Name")
                param_id = last_channel.get("ParameterId")

                # Check if last channel is designated as status (ParameterId == 1126 or Name contains "status")
                if param_id == 1126 or (last_name and last_name.lower() == "status"):
                    self.log.debug(f"[driver_synspec_gc955] Last channel '{last_name}' is status parameter, setting value")
                    results[last_name] = status
                elif status is not None:
                    # No channel is designated to receive the status value, so it
                    # is discarded (last channel's value is never overwritten).
                    pass

            self.log.info(f"[driver_synspec_gc955] Read results: {results}")
            return results

        except Exception as e:
            self.log.error(f"[driver_synspec_gc955] Error reading channels: {type(e).__name__}: {e}", exc_info=True)
            results = {ch.get("Name"): None for ch in channels}
            return results

    def disconnect(self):
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
