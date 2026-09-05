"""Minimal worked example of a driver written against driver_sdk.py.

This folder is intentionally NOT referenced by drivers_dict.json, so it is
never launched by the service - it exists only as a living reference for
docs/en/driver-contract.md (section 6) and as a smoke-test target you can run
standalone:

    INSTRUMENT_ID=example \
    MODULE_CONFIG={"PollingInterval":1,"Channels":[{"Name":"DEMO","DatabaseId":1,"Active":true}]} \
    python driver.py

connect() below always fails on purpose (there is no real instrument to
reach), so every reading comes out missing (P.COD=128). See
docs/en/driver-contract.md section 3.
"""

import os
import importlib.util

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Minimal walk-up to locate opas_dl_commons/libs/ - this can't itself live in
# libs/ (it's what finds libs/ before anything there is reachable), so it
# must stay inline here and in every other driver.py. This makes the snippet
# copy-paste safe regardless of where you place your driver folder (directly
# under drivers/, or nested for grouping - see docs/en/driver-contract.md
# section 8). See libs/driver_bootstrap.py's find_libs_dir() for the
# documented, canonical version of this same walk; everything after this
# delegates to it.
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


class ExampleDriver(driver_sdk.BaseDriver):
    """Stands in for a real instrument SDK/socket/serial connection."""

    def connect(self):
        # Replace with e.g. my_instrument_sdk.open(self.module_config["TCPIPAddress"]).
        raise ConnectionError("no real instrument configured in this example")

    def read_channel(self, channel_config):
        # Replace with e.g. my_instrument_sdk.query(self._handle, channel_config["Address"]).
        raise NotImplementedError("unreachable: connect() always fails in this example")

    def disconnect(self):
        pass


if __name__ == "__main__":
    driver_sdk.run_driver(ExampleDriver)
