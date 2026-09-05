"""Campbell CR1000 data logger driver, written against driver_sdk.py.

Sends HTTP GET requests to retrieve meteorological and system data in JSON format.
Parses the response JSON to extract values from the vals array and maps results
to configured channels by their DataArrayIdx (indices 4-17 contain system and weather data).

Requires ComunicationType: 7 (HTTP - see comm_manager.HTTPCommunicationChannel;
not part of the original VB.NET enum, added on top of it).
"""

import importlib.util
import json
import os
import urllib.error

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
        """Build the HTTP channel via comm_manager (see comm_manager.HTTPCommunicationChannel).

        HTTP is request/response, so there's no persistent connection to
        establish ahead of time - the actual GET happens on-demand in
        read_all_channels().
        """
        self._channel = driver_sdk.comm_manager.create_channel(self.module_config)
        self._channel.connect()
        self.log.info(f"[driver_campbell_cr1000] Configured with base URL: {self._channel.base_url}")

    def read_all_channels(self, channels):
        """Read all channels from Campbell CR1000 data logger.

        Sends an HTTP GET request to retrieve meteorological and system data
        in JSON format. Parses the response and extracts values from the vals array.

        Expected response format:
        {
            "data": [
                {
                    "vals": [val0, val1, ..., val19],
                    "time": "ISO timestamp"
                }
            ]
        }

        Data array indices 4-17 contain:
        - 4-6: System data (BattV, PTemp, CTemp)
        - 7-13: Weather data (Temperature, Humidity, Pressure, Wind, etc.)
        - 14-17: Alarms (Door, Power, PowerSupply, Temperature)

        Args:
            channels: List of channel configuration dictionaries with DataArrayIdx

        Returns:
            Dictionary mapping channel names to their values, or None values on error
        """
        results = {}

        try:
            # GET /data via the HTTP channel built in connect()
            self.log.info(f"[driver_campbell_cr1000] Sending HTTP GET to: {self._channel.base_url}/data")
            response_data = self._channel.get("/data", headers={"Accept": "application/json"}).decode("utf-8")

            self.log.debug(f"[driver_campbell_cr1000] Raw response: {response_data!r}")

            # Parse JSON response
            try:
                json_data = json.loads(response_data)
            except json.JSONDecodeError as e:
                self.log.error(f"[driver_campbell_cr1000] Failed to parse JSON: {e}")
                return {ch.get("Name"): None for ch in channels}

            # Extract data from response structure
            if "data" not in json_data or not json_data["data"]:
                self.log.warning("[driver_campbell_cr1000] No data array in response")
                return {ch.get("Name"): None for ch in channels}

            data_record = json_data["data"][0]
            if "vals" not in data_record:
                self.log.warning("[driver_campbell_cr1000] No vals array in data record")
                return {ch.get("Name"): None for ch in channels}

            vals = data_record["vals"]
            self.log.debug(f"[driver_campbell_cr1000] Extracted vals array: {vals}")

            # Map parsed values to requested channels by DataArrayIdx
            for channel_config in channels:
                name = channel_config.get("Name")
                arridx = int(channel_config.get("DataArrayIdx", -1))

                if 0 <= arridx < len(vals):
                    results[name] = vals[arridx]
                    self.log.debug(f"[driver_campbell_cr1000] Channel '{name}' (idx={arridx}): {results[name]}")
                else:
                    results[name] = None
                    self.log.warning(f"[driver_campbell_cr1000] Channel '{name}' index {arridx} out of range or not found")

        except urllib.error.HTTPError as e:
            self.log.error(f"[driver_campbell_cr1000] HTTP response error {e.code}: {e.reason}")
            results = {ch.get("Name"): None for ch in channels}
        except urllib.error.URLError as e:
            self.log.error(f"[driver_campbell_cr1000] HTTP error: {type(e).__name__}: {e}")
            results = {ch.get("Name"): None for ch in channels}
        except Exception as e:
            self.log.error(f"[driver_campbell_cr1000] Error reading channels: {type(e).__name__}: {e}", exc_info=True)
            results = {ch.get("Name"): None for ch in channels}

        return results

    def disconnect(self):
        """Disconnect from Campbell CR1000.

        For HTTP-based communication, this is a no-op since connections are
        stateless and closed automatically after each request.
        """
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()
        self.log.info("[driver_campbell_cr1000] Disconnecting (HTTP connection closed)")


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
