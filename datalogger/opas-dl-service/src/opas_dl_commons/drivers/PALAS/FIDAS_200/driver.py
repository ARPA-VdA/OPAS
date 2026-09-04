"""PALAS FIDAS 200 driver, written against driver_sdk.py.

Connects to instrument via Modbus (Seriale RTU or Ethernet, resolved from
ComunicationType/comm_manager.create_channel - see comm_manager.py).
Reads channel values from Holding or Input registers (integer or float).
Applies optional RegularExpression patterns to validate and extract numeric values.
"""

import importlib.util
import os
import re
from math import isnan

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Minimal walk-up to locate opas_dl_commons/libs/ - this can't itself live in
# libs/ (it's what finds libs/ before anything there is reachable). See
# libs/driver_bootstrap.py's find_libs_dir() for the documented, canonical
# version of this same walk; everything after this delegates to it. This
# driver lives two levels under drivers/ (PALAS/FIDAS_200/), not one - a
# previous hardcoded "../.." here landed on drivers/libs/ (which doesn't
# exist) instead of opas_dl_commons/libs/, so it never actually loaded.
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
comm_manager = driver_sdk.comm_manager


class APIDriver(driver_sdk.BaseDriver):
    def connect(self):
        """Establish the Modbus connection via comm_manager (Seriale or Ethernet,
        resolved from the module's ComunicationType - see
        comm_manager.create_channel)."""
        try:
            self._channel = comm_manager.create_channel(self.module_config)
            self._channel.connect()
            self.log.info("[driver_palas_fidas200] Modbus connection established")
        except Exception as e:
            self.log.error(f"[driver_palas_fidas200] Error during connection: {type(e).__name__}: {e}")
            self._channel = None

    def _is_numeric(self, value) -> bool:
        """Check if value is a valid number (not NaN or None)."""
        if value is None:
            return False
        if isinstance(value, float):
            return not isnan(value)
        if isinstance(value, int):
            return True
        if isinstance(value, str):
            try:
                float(value)
                return True
            except (ValueError, TypeError):
                return False
        return False

    def read_channel(self, channel_config: dict) -> float | None:
        """Read a single channel value from Modbus registers using channel-specific configuration.

        Channel configuration parameters:
        - Name: channel name
        - Address: register address (0-based)
        - RegisterFunctionCode: 1=Coils, 2=DiscreteInputs, 3=HoldingRegisters, 4=InputRegisters
        - RegisterType: 0=Float, 1=Integer
        - RegisterQuantity: number of registers to read (1 for integer, 2 for float)
        - RegisterOrder: 0=LowHigh, 1=HighLow (for float conversion)
        - RegularExpression: optional regex to validate/extract value

        Returns:
            Float value or None if read fails
        """
        if not self._channel or not self._channel.is_open():
            self.log.warning("[driver_palas_fidas200] Modbus channel not connected")
            return None

        name = channel_config.get("Name", "UnknownChannel")
        address_str = channel_config.get("Address", "")
        regex_pattern = channel_config.get("RegularExpression")

        function_code = channel_config.get("RegisterFunctionCode", 4)  # Default: InputRegisters
        register_type = channel_config.get("RegisterType", 0)  # 0=Float, 1=Integer
        register_quantity = channel_config.get("RegisterQuantity", 1)
        register_order = channel_config.get("RegisterOrder", 1)  # 0=LowHigh, 1=HighLow

        if not address_str or address_str == "":
            self.log.debug(f"[driver_palas_fidas200] Channel '{name}' has no address, skipping")
            return None

        try:
            register_id = int(address_str)
        except (ValueError, TypeError):
            self.log.warning(f"[driver_palas_fidas200] Channel '{name}' has invalid address: {address_str}")
            return None

        try:
            raw_registers = self._channel.read_registers(function_code, register_id, register_quantity)
        except Exception as e:
            self.log.warning(f"[driver_palas_fidas200] Modbus read failed for channel '{name}': {e}")
            return None

        register_value = comm_manager.decode_modbus_value(raw_registers, register_type, register_order)
        self.log.debug(f"[driver_palas_fidas200] Converted value for '{name}': {register_value}")

        if not self._is_numeric(register_value):
            self.log.debug(f"[driver_palas_fidas200] Register value is NaN or invalid: {register_value}")
            return None

        # Apply regex pattern if configured
        if regex_pattern:
            try:
                match = re.search(regex_pattern, str(register_value))
                if match and match.group(1):
                    extracted_value = match.group(1)
                    if self._is_numeric(extracted_value):
                        register_value = float(extracted_value)
                        self.log.debug(f"[driver_palas_fidas200] Regex extracted: {register_value}")
                    else:
                        self.log.debug(f"[driver_palas_fidas200] Regex pattern matched but value is not numeric: {extracted_value}")
                        return None
                else:
                    self.log.debug(f"[driver_palas_fidas200] Regex pattern did not match: {regex_pattern}")
                    return None
            except Exception as e:
                self.log.warning(f"[driver_palas_fidas200] Error applying regex pattern: {e}")
                return None

        self.log.debug(f"[driver_palas_fidas200] Channel '{name}' final value: {register_value}")
        return float(register_value)

    def disconnect(self):
        """Disconnect from the Modbus device."""
        if getattr(self, "_channel", None):
            try:
                self._channel.close()
                self.log.info("[driver_palas_fidas200] Modbus connection closed")
            except Exception as e:
                self.log.warning(f"[driver_palas_fidas200] Error closing Modbus connection: {e}")


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
