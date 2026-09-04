"""SILENA GAMMA 600CE driver, written against driver_sdk.py.

Communicates with SILENA GAMMA 600CE gamma spectrometer via serial port.
Implements a 4-step handshake protocol to query and retrieve gamma measurements.

Protocol:
- Step 1 & 2: Send initialization commands, verify ACK at position 7
- Step 3: Send data request command, extract gamma value from positions 9-16
- Step 4: Send closure command
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
        self._channel = driver_sdk.comm_manager.create_channel(self.module_config)
        self._channel.connect()

    def _send_and_receive(self, command_str, timeout=2.0):
        """Send command and receive response.

        Args:
            command_str: Command string (will be encoded to latin-1)
            timeout: Receive timeout in seconds

        Returns:
            Decoded response string or None if error
        """
        try:
            self.log.debug(f"[driver_silena_gamma_600ce] Sending: {command_str!r}")
            self._channel.send(command_str.encode("latin-1"))
            response = self._channel.recv(1024, timeout=timeout)
            if response:
                response_text = response.decode("latin-1", errors="ignore")
                self.log.debug(f"[driver_silena_gamma_600ce] Received: {response_text!r}")
                return response_text
            return None
        except Exception as e:
            self.log.error(f"[driver_silena_gamma_600ce] Send/receive error: {type(e).__name__}: {e}")
            return None

    def read_all_channels(self, channels):
        """Read gamma measurement from SILENA GAMMA 600CE using 4-step protocol.

        Protocol:
        1. Send initialization message 1: STX + "7001A@30" + ETX + CR + LF
        2. Send initialization message 2: STX + "7001CI3B" + ETX + CR + LF
           (Both must have ACK at position 7)
        3. Send data request: STX + "7001F" + ACK + "71" + ETX + CR + LF
           (Response must have "I" at position 7 and "M" at position 19)
           Extract value from positions 9-16 (8 characters)
        4. Send closure: STX + "7001H" + ACK + "7F" + ETX + CR + LF

        Args:
            channels: List of channel configuration dictionaries

        Returns:
            Dictionary mapping channel names to their values, or None values on error
        """
        results = {ch.get("Name"): None for ch in channels}

        try:
            if not self._channel:
                self.log.error("[driver_silena_gamma_600ce] Channel not initialized")
                return results

            # Protocol constants
            STX = chr(0x02)
            ACK = chr(0x06)
            ETX = chr(0x03)
            CR = chr(0x0D)
            LF = chr(0x0A)

            # Step 1 & 2: Initialization messages
            for step_num, msg_content in enumerate([
                "7001A@30",  # Step 1
                "7001CI3B"   # Step 2
            ], start=1):
                command = STX + msg_content + ETX + CR + LF
                response = self._send_and_receive(command)

                if not response:
                    self.log.error(f"[driver_silena_gamma_600ce] Step {step_num}: No response")
                    # Send closure command before returning
                    closure_cmd = STX + "7001H" + ACK + "7F" + ETX + CR + LF
                    self._send_and_receive(closure_cmd)
                    return results

                # Verify ACK at position 7 (index 6)
                if len(response) < 7 or response[6] != ACK:
                    self.log.error(
                        f"[driver_silena_gamma_600ce] Step {step_num}: "
                        f"Invalid response (ACK not at position 7): {response!r}"
                    )
                    # Send closure command before returning
                    closure_cmd = STX + "7001H" + ACK + "7F" + ETX + CR + LF
                    self._send_and_receive(closure_cmd)
                    return results

                self.log.info(f"[driver_silena_gamma_600ce] Step {step_num} OK")

            # Step 3: Data request
            command_step3 = STX + "7001F" + ACK + "71" + ETX + CR + LF
            response_step3 = self._send_and_receive(command_step3)

            if not response_step3:
                self.log.error("[driver_silena_gamma_600ce] Step 3: No response")
                # Send closure command before returning
                closure_cmd = STX + "7001H" + ACK + "7F" + ETX + CR + LF
                self._send_and_receive(closure_cmd)
                return results

            # Verify "I" at position 7 and "M" at position 19 (indices 6 and 18)
            if (len(response_step3) < 19 or
                response_step3[6] != "I" or
                response_step3[18] != "M"):
                self.log.error(
                    f"[driver_silena_gamma_600ce] Step 3: Invalid response "
                    f"(expected 'I' at pos 7 and 'M' at pos 19): {response_step3!r}"
                )
                # Send closure command before returning
                closure_cmd = STX + "7001H" + ACK + "7F" + ETX + CR + LF
                self._send_and_receive(closure_cmd)
                return results

            self.log.info("[driver_silena_gamma_600ce] Step 3 OK")

            # Extract value from positions 9-16 (8 characters, indices 8-15)
            # In VB.NET: Mid(sValue, 9, 8)
            try:
                value_str = response_step3[8:16].strip()
                value = float(value_str)
                self.log.info(f"[driver_silena_gamma_600ce] Gamma value extracted: {value}")
            except (ValueError, IndexError) as e:
                self.log.error(
                    f"[driver_silena_gamma_600ce] Could not extract value from response "
                    f"(indices 8-15): {response_step3!r}: {e}"
                )
                value = None

            # Step 4: Closure command
            closure_cmd = STX + "7001H" + ACK + "7F" + ETX + CR + LF
            self._send_and_receive(closure_cmd)
            self.log.info("[driver_silena_gamma_600ce] Step 4 OK (closure)")

            # Assign value to all requested channels
            for channel_config in channels:
                name = channel_config.get("Name")
                results[name] = value
                self.log.debug(f"[driver_silena_gamma_600ce] Channel '{name}': {value}")

        except Exception as e:
            self.log.error(f"[driver_silena_gamma_600ce] Error reading channels: {type(e).__name__}: {e}", exc_info=True)

        return results

    def disconnect(self):
        channel = getattr(self, "_channel", None)
        if channel is not None:
            channel.close()


if __name__ == "__main__":
    driver_sdk.run_driver(APIDriver)
