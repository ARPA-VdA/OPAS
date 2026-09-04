"""Shared COM port orchestration.

Detects modules in the active config that point at the same physical COM
port (ComunicationType == 0, same ComPortName) and arranges for them to
share it through a `serial_port_broker` process instead of each driver
opening the port independently.

This module is the single place to touch for changes to "shared COM port"
behavior. Integration with the rest of the service is intentionally a single
call from `service_master.py`:

    modules = shared_serial_ports.manager.prepare_modules(modules)
    ...
    shared_serial_ports.manager.shutdown()  # on service shutdown

Drivers and `comm_manager.py` are unaware of this layer: modules assigned to
a broker simply receive a rewritten config that looks like a normal TCP/IP
module (ComunicationType == 1, pointing at 127.0.0.1:<broker_port>).

Deliberately serial-only (ComunicationType == 0), not Modbus Seriale (5) too:
this mechanism works because generic drivers talk raw bytes through
CommunicationChannel (TCPCommunicationChannel/SerialCommunicationChannel), so
redirecting them to a byte-relay broker impersonating plain TCP is
transparent. Modbus doesn't go through CommunicationChannel at all -
ModbusCommunicationChannel wraps pymodbus's own ModbusSerialClient/
ModbusTcpClient, which manage their own socket/serial framing internally. A
ModbusTcpClient pointed at this broker would speak Modbus-TCP (MBAP header)
framing to a relay that's just forwarding raw bytes to a real serial port -
a guaranteed protocol mismatch. True Modbus RTU multi-drop sharing (several
slaves, one physical connection, addressed by unit_id) is a different,
Modbus-aware coordination problem, not something this raw-byte relay can
provide as-is - it isn't handled here.
"""

import copy
import logging
from multiprocessing import Process, Queue, Event

import serial_port_broker

# Serial settings that must match across modules sharing the same COM port.
# The first module in each group provides the values used to open the port.
_SERIAL_SETTING_FIELDS = [
    "ComPortBauds",
    "TimeoutAnswer",
    "ComPortDataBits",
    "ComPortParity",
    "ComPortStopBits",
]

# How long to wait for a broker process to open the serial port and report
# back its local TCP port before giving up on sharing it.
_BROKER_READY_TIMEOUT = 10.0


class SharedSerialPortManager:
    """Owns the broker processes started for shared COM ports."""

    def __init__(self):
        self._brokers = {}  # ComPortName -> {"process", "stop_event", "port"}

    def prepare_modules(self, modules):
        """Return a copy of `modules` with shared-COM-port modules rewritten.

        Modules whose `ComPortName` (ComunicationType == 0) is used by more
        than one active module are pointed at a broker process instead of
        the raw serial port. All other modules are returned unchanged.
        """
        if not isinstance(modules, list):
            return modules

        groups = {}
        for mod in modules:
            if not isinstance(mod, dict) or mod.get("Active") is False:
                continue
            if mod.get("ComunicationType") != 0:
                continue
            com_port = mod.get("ComPortName")
            if not com_port:
                continue
            groups.setdefault(com_port, []).append(mod)

        shared_ports = {name: mods for name, mods in groups.items() if len(mods) > 1}
        if not shared_ports:
            return modules

        out = []
        for mod in modules:
            com_port = mod.get("ComPortName") if isinstance(mod, dict) else None
            if com_port in shared_ports:
                rewritten = self._rewrite_for_broker(mod, com_port, shared_ports[com_port])
                out.append(rewritten)
            else:
                out.append(mod)
        return out

    def _rewrite_for_broker(self, module_config, com_port, group):
        port = self._get_or_start_broker(com_port, group)
        if port is None:
            # Broker failed to start; leave the module pointing at the real
            # port so it falls back to today's (non-shared) behavior.
            return module_config

        rewritten = copy.deepcopy(module_config)
        rewritten["_SharedComPortName"] = com_port
        rewritten["ComunicationType"] = 1
        rewritten["TCPIPAddress"] = "127.0.0.1"
        rewritten["TCPIPPort"] = port
        return rewritten

    def _get_or_start_broker(self, com_port, group):
        existing = self._brokers.get(com_port)
        if existing is not None:
            return existing["port"]

        serial_config = self._merged_serial_config(com_port, group)

        ready_queue = Queue()
        stop_event = Event()
        process = Process(
            target=serial_port_broker.run_broker,
            args=(serial_config, ready_queue, stop_event),
            name=f"serial-broker-{com_port}",
            daemon=True,
        )
        process.start()

        try:
            status, payload = ready_queue.get(timeout=_BROKER_READY_TIMEOUT)
        except Exception:
            logging.error(f"[shared_serial_ports] Broker for {com_port} did not respond; "
                           f"falling back to direct access")
            stop_event.set()
            process.terminate()
            return None

        if status != "ok":
            logging.error(f"[shared_serial_ports] Broker for {com_port} failed to start: {payload}")
            stop_event.set()
            process.terminate()
            return None

        port = payload
        logging.info(f"[shared_serial_ports] {len(group)} modules sharing {com_port} "
                      f"via broker on 127.0.0.1:{port}")
        self._brokers[com_port] = {"process": process, "stop_event": stop_event, "port": port}
        return port

    def _merged_serial_config(self, com_port, group):
        """Build the serial config used to open the port, from the first
        module in the group. Logs a warning if other modules in the group
        disagree on serial settings (the first module's settings win).
        """
        first = group[0]
        config = {"ComPortName": com_port}
        for field in _SERIAL_SETTING_FIELDS:
            config[field] = first.get(field)

        for mod in group[1:]:
            for field in _SERIAL_SETTING_FIELDS:
                if mod.get(field) != first.get(field):
                    logging.warning(
                        f"[shared_serial_ports] Module '{mod.get('Name', mod.get('ID'))}' "
                        f"has {field}={mod.get(field)!r} which differs from "
                        f"'{first.get('Name', first.get('ID'))}' ({first.get(field)!r}) "
                        f"on shared port {com_port}; using the latter."
                    )
        return config

    def shutdown(self):
        """Stop all running broker processes."""
        for com_port, info in self._brokers.items():
            info["stop_event"].set()
            process = info["process"]
            process.join(5)
            if process.is_alive():
                logging.warning(f"[shared_serial_ports] Broker for {com_port} did not exit; killing")
                process.terminate()
                process.join(5)
                if process.is_alive():
                    logging.warning(f"[shared_serial_ports] Broker for {com_port} did not exit after SIGTERM; sending SIGKILL")
                    process.kill()
                    process.join()
        self._brokers.clear()


# singleton instance to be imported by other modules
manager = SharedSerialPortManager()
