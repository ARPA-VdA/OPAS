"""Communication channel manager for drivers.

Handles different communication types (TCP/IP, Serial, etc.) in a unified way.
Drivers receive an already-connected channel object.
"""

import os
import socket
import struct
import threading
import time
import logging
import urllib.request
import urllib.error
from abc import ABC, abstractmethod

try:
    import serial
    PYSERIAL_AVAILABLE = True
except ImportError:
    PYSERIAL_AVAILABLE = False
    logging.warning("pyserial not available; serial communication will not work")

try:
    from pymodbus.client import ModbusSerialClient, ModbusTcpClient
    PYMODBUS_AVAILABLE = True
except ImportError:
    PYMODBUS_AVAILABLE = False
    logging.warning("pymodbus not available; Modbus communication will not work")


class CommunicationChannel(ABC):
    """Abstract base class for communication channels."""

    channel_type = None

    @abstractmethod
    def send(self, data: bytes) -> None:
        """Send data through the channel."""
        pass

    @abstractmethod
    def recv(self, bufsize: int = 1024, timeout: float = None) -> bytes:
        """Receive data from the channel (blocking, with optional timeout)."""
        pass

    @abstractmethod
    def close(self) -> None:
        """Close the channel."""
        pass

    @abstractmethod
    def is_open(self) -> bool:
        """Return True if the channel is open."""
        pass

    def recv_until(self, delimiter: bytes, timeout: float = None, bufsize: int = 1024) -> bytes:
        """Read from the channel one byte at a time until delimiter is seen.

        Args:
            delimiter: byte sequence marking the end of the response
            timeout: per-byte read timeout in seconds (None = use channel default)
            bufsize: safety cap on the number of bytes read

        Returns:
            bytes read, including the delimiter if it was found; whatever was
            read so far if the channel stopped returning data before bufsize
        """
        buf = b""
        while len(buf) < bufsize:
            chunk = self.recv(1, timeout=timeout)
            if not chunk:
                break
            buf += chunk
            if buf.endswith(delimiter):
                break
        return buf


class TCPCommunicationChannel(CommunicationChannel):
    """TCP/IP communication channel."""

    channel_type = "tcp"

    def __init__(self, host: str, port: int, timeout: float = 10.0):
        """
        Initialize TCP channel (does not connect immediately).

        Args:
            host: server address or IP
            port: server port
            timeout: socket timeout in seconds
        """
        self.host = host
        self.port = port
        self.timeout = timeout
        self._socket = None
        self._lock = threading.Lock()

    def connect(self) -> None:
        """Establish the TCP connection."""
        with self._lock:
            if self._socket is not None:
                raise RuntimeError("Already connected")
            self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self._socket.settimeout(self.timeout)
            logging.info(f"Connecting to {self.host}:{self.port}")
            self._socket.connect((self.host, self.port))
            logging.info(f"Connected to {self.host}:{self.port}")

    def send(self, data: bytes) -> None:
        """Send data."""
        with self._lock:
            if self._socket is None:
                raise RuntimeError("Channel not connected")
            self._socket.sendall(data)

    def recv(self, bufsize: int = 1024, timeout: float = None) -> bytes:
        """Receive data (blocking with timeout)."""
        with self._lock:
            if self._socket is None:
                raise RuntimeError("Channel not connected")
            old_timeout = self._socket.gettimeout()
            if timeout is not None:
                self._socket.settimeout(timeout)
            try:
                data = self._socket.recv(bufsize)
            finally:
                if timeout is not None:
                    self._socket.settimeout(old_timeout)
            return data

    def close(self) -> None:
        """Close the channel."""
        with self._lock:
            if self._socket is not None:
                try:
                    self._socket.close()
                except Exception:
                    pass
                self._socket = None

    def is_open(self) -> bool:
        """Check if the channel is open."""
        with self._lock:
            return self._socket is not None


class UDPCommunicationChannel(CommunicationChannel):
    """UDP ("Ethernet UDP") communication channel.

    Same host/port/timeout configuration as TCPCommunicationChannel (both are
    "Ethernet" transports in the module schema) - only the socket type differs.
    connect() calls socket.connect() to fix the default destination, so
    send()/recv() behave like a connected stream even though UDP itself is
    connectionless.
    """

    channel_type = "udp"

    def __init__(self, host: str, port: int, timeout: float = 10.0):
        self.host = host
        self.port = port
        self.timeout = timeout
        self._socket = None
        self._lock = threading.Lock()

    def connect(self) -> None:
        with self._lock:
            if self._socket is not None:
                raise RuntimeError("Already connected")
            self._socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self._socket.settimeout(self.timeout)
            self._socket.connect((self.host, self.port))
            logging.info(f"UDP channel ready: {self.host}:{self.port}")

    def send(self, data: bytes) -> None:
        with self._lock:
            if self._socket is None:
                raise RuntimeError("Channel not connected")
            self._socket.send(data)

    def recv(self, bufsize: int = 1024, timeout: float = None) -> bytes:
        with self._lock:
            if self._socket is None:
                raise RuntimeError("Channel not connected")
            old_timeout = self._socket.gettimeout()
            if timeout is not None:
                self._socket.settimeout(timeout)
            try:
                data = self._socket.recv(bufsize)
            finally:
                if timeout is not None:
                    self._socket.settimeout(old_timeout)
            return data

    def close(self) -> None:
        with self._lock:
            if self._socket is not None:
                try:
                    self._socket.close()
                except Exception:
                    pass
                self._socket = None

    def is_open(self) -> bool:
        with self._lock:
            return self._socket is not None


class SerialCommunicationChannel(CommunicationChannel):
    """Serial communication channel using pyserial."""

    channel_type = "serial"

    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 1.0,
                 bytesize: int = 8, parity: str = 'N', stopbits: int = 1):
        """Initialize serial channel (does not connect immediately).
        
        Args:
            port: COM port name (e.g., 'COM1' on Windows, '/dev/ttyUSB0' on Linux, stored as integer '1,2')
            baudrate: baud rate (default 115200)
            timeout: read timeout in seconds (default 1.0)
            bytesize: number of data bits (default 8)
            parity: parity type ('N'=None, 'E'=Even, 'O'=Odd, default 'N')
            stopbits: number of stop bits (default 1)
        """
        if not PYSERIAL_AVAILABLE:
            raise RuntimeError("pyserial is not installed; cannot create serial channel")
        
        self.port = f"COM{port}"
        self.baudrate = baudrate
        self.timeout = timeout
        self.bytesize = bytesize
        self.parity = parity
        self.stopbits = stopbits
        self._serial = None
        self._lock = threading.Lock()
        logging.debug(f"Serial channel initialized: {port} @ {baudrate} baud")

    def connect(self) -> None:
        """Establish serial connection."""
        with self._lock:
            if self._serial is not None:
                raise RuntimeError("Already connected")
            
            try:
                self._serial = serial.Serial(
                    port=self.port,
                    baudrate=self.baudrate,
                    bytesize=self.bytesize,
                    parity=self.parity,
                    stopbits=self.stopbits,
                    timeout=self.timeout,
                    write_timeout=self.timeout
                )
                logging.info(f"Serial connection established: {self.port} @ {self.baudrate} baud")
            except serial.SerialException as e:
                self._serial = None
                raise RuntimeError(f"Failed to open serial port {self.port}: {e}")

    def send(self, data: bytes) -> None:
        """Send data through the serial port."""
        with self._lock:
            if self._serial is None:
                raise RuntimeError("Channel not connected")
            try:
                bytes_written = self._serial.write(data)
                if bytes_written != len(data):
                    logging.warning(f"Partial write: {bytes_written}/{len(data)} bytes")
                self._serial.flush()  # ensure data is sent
            except serial.SerialException as e:
                raise RuntimeError(f"Failed to send serial data: {e}")

    def recv(self, bufsize: int = 1024, timeout: float = None) -> bytes:
        """Receive data from the serial port (blocking with timeout).
        
        Args:
            bufsize: maximum number of bytes to read
            timeout: read timeout in seconds (None = use default, 0 = non-blocking)
        
        Returns:
            bytes: data received (may be empty if timeout occurs)
        """
        with self._lock:
            if self._serial is None:
                raise RuntimeError("Channel not connected")
            
            old_timeout = self._serial.timeout
            if timeout is not None:
                self._serial.timeout = timeout
            
            try:
                data = self._serial.read(bufsize)
                return data
            except serial.SerialException as e:
                raise RuntimeError(f"Failed to receive serial data: {e}")
            finally:
                if timeout is not None:
                    self._serial.timeout = old_timeout

    def close(self) -> None:
        """Close the serial connection."""
        with self._lock:
            if self._serial is not None:
                try:
                    self._serial.close()
                except Exception as e:
                    logging.warning(f"Error closing serial port: {e}")
                finally:
                    self._serial = None

    def is_open(self) -> bool:
        """Check if the serial connection is open."""
        with self._lock:
            return self._serial is not None and self._serial.is_open


class ModbusCommunicationChannel:
    """Modbus RTU (serial) or TCP channel, built on pymodbus.

    Not a CommunicationChannel subclass: Modbus is a register-addressed
    request/response protocol, not a byte stream, so send()/recv() don't fit -
    callers use read_registers() instead. Still constructed via the single
    create_channel() factory like every other type.
    """

    channel_type = "modbus"

    def __init__(self, client, unit_id: int):
        self._client = client
        self.unit_id = unit_id

    def connect(self) -> None:
        if not self._client.connect():
            raise RuntimeError("Failed to connect Modbus client")

    def close(self) -> None:
        try:
            self._client.close()
        except Exception:
            pass

    def is_open(self) -> bool:
        return self._client is not None and self._client.is_socket_open()

    def read_registers(self, function_code: int, address: int, quantity: int = 1) -> list:
        """Read `quantity` values starting at `address` using `function_code`.

        function_code: 1=Coils, 2=DiscreteInputs, 3=HoldingRegisters, 4=InputRegisters.
        Coils/DiscreteInputs results expose `.bits` (booleans), Holding/Input
        Registers expose `.registers` (16-bit ints) - a prior one-off Modbus
        driver read `.registers` unconditionally, which meant Coils/
        DiscreteInputs silently never worked (no such attribute on that
        result type). Returns plain ints (0/1 for bits) either way.
        """
        if function_code == 1:
            result = self._client.read_coils(address, quantity, slave=self.unit_id)
            raw = result.bits if not result.isError() else None
        elif function_code == 2:
            result = self._client.read_discrete_inputs(address, quantity, slave=self.unit_id)
            raw = result.bits if not result.isError() else None
        elif function_code == 3:
            result = self._client.read_holding_registers(address, quantity, slave=self.unit_id)
            raw = result.registers if not result.isError() else None
        elif function_code == 4:
            result = self._client.read_input_registers(address, quantity, slave=self.unit_id)
            raw = result.registers if not result.isError() else None
        else:
            raise ValueError(f"Unsupported Modbus function code: {function_code}")

        if raw is None:
            raise RuntimeError(f"Modbus read failed (function_code={function_code}, address={address})")
        return [int(v) for v in raw]


def decode_modbus_value(registers: list, register_type: int = 0, register_order: int = 1):
    """Convert raw Modbus register(s) into the channel's numeric value.

    register_type: 0=Float (needs 2 registers, IEEE-754 via struct), 1=Integer
    (uses the first register/bit as-is). register_order (float only):
    0=LowHigh, 1=HighLow word order. Returns None on missing/insufficient data.
    """
    if not registers:
        return None
    if register_type == 1:
        return float(registers[0])
    if len(registers) < 2:
        return None
    try:
        if register_order == 1:  # HighLow
            return struct.unpack("!f", struct.pack("!HH", registers[0], registers[1]))[0]
        return struct.unpack("!f", struct.pack("!HH", registers[1], registers[0]))[0]  # LowHigh
    except Exception:
        return None


class PipeFileChannel:
    """PipeFile channel: not a live connection, but a file on disk that the
    instrument (or its own acquisition software) writes readings into.

    Not a CommunicationChannel subclass - there's no send/recv, just a batch
    read of whatever's currently in the file. Generalizes the logic that used
    to live directly in opas_dl_commons/drivers/PIPE/CSV/driver.py.
    """

    channel_type = "pipefile"

    def __init__(self, path: str, missing_is_error: bool = True):
        self.path = path
        self.missing_is_error = missing_is_error

    def connect(self) -> None:
        pass

    def close(self) -> None:
        pass

    def is_open(self) -> bool:
        return True

    def read_values(self, channels: list) -> dict:
        """Read the pipe file, split on ';', map by each channel's DataArrayIdx.

        Deletes the file after a successful read (the instrument/writer is
        expected to produce a fresh one before the next poll). A missing file
        reports every channel as None rather than raising - PipeFileMissingError
        only controls whether that's logged as a warning or at debug level.
        """
        if not os.path.isfile(self.path):
            log_fn = logging.warning if self.missing_is_error else logging.debug
            log_fn(f"Pipe file not found: {self.path}")
            return {ch.get("Name"): None for ch in channels}

        with open(self.path, "r", encoding="utf-8") as f:
            content = f.read().strip()
        values = content.split(";")

        results = {}
        for ch in channels:
            name = ch.get("Name")
            try:
                idx = int(ch.get("DataArrayIdx", -1))
            except (TypeError, ValueError):
                idx = -1
            if 0 <= idx < len(values):
                try:
                    results[name] = float(values[idx])
                except ValueError:
                    results[name] = values[idx]
            else:
                results[name] = None

        try:
            os.remove(self.path)
        except OSError as e:
            logging.error(f"Failed to delete pipe file {self.path}: {e}")

        return results


class HTTPCommunicationChannel:
    """HTTP channel: ComunicationType 7 - NOT part of the original VB.NET
    EnumModuleComunicationType (0 Seriale/1 TCP/IP/3 PipeFile/4 UDP/5 Modbus
    Seriale/6 Modbus Ethernet); added on top of it so HTTP-based drivers (e.g.
    opas_dl_commons/drivers/CAMPBELL/CR1000/driver.py) can also go through
    this single factory instead of building urllib requests themselves.

    Not a CommunicationChannel subclass - HTTP is one-shot request/response
    against a base URL, not a persistent byte stream; there's nothing to hold
    "open" between requests. connect()/close()/is_open() exist only so it
    fits the same connect()-then-use()-then-close() shape every other channel
    has; `get()` is the actual read operation.
    """

    channel_type = "http"

    def __init__(self, host: str, port: int, timeout: float = 10.0, scheme: str = "http"):
        self.base_url = f"{scheme}://{host}:{port}"
        self.timeout = timeout
        self._open = False

    def connect(self) -> None:
        self._open = True

    def close(self) -> None:
        self._open = False

    def is_open(self) -> bool:
        return self._open

    def get(self, path: str = "", headers: dict | None = None) -> bytes:
        """GET base_url + path, returning the raw response body.

        Raises urllib.error.URLError/HTTPError on failure, same as calling
        urllib.request.urlopen() directly - callers catch those exactly as
        they did before this was centralized here.
        """
        request = urllib.request.Request(f"{self.base_url}{path}", method="GET")
        for key, value in (headers or {}).items():
            request.add_header(key, value)
        with urllib.request.urlopen(request, timeout=self.timeout) as response:
            return response.read()


def normalize_comunication_type(module_config: dict) -> int:
    """Resolve a module's effective ComunicationType, migrating the retired
    generic Modbus value (2) to the new explicit Modbus Seriale (5) / Modbus
    Ethernet (6) split.

    Legacy "2" never distinguished serial from TCP itself - callers decided at
    runtime by inspecting TCPIPAddress/ComPortName (the same heuristic the
    original VB.NET app used): TCPIPAddress unset/"0.0.0.0" and a real
    ComPortName means Modbus was running over serial, otherwise TCP. Called
    from create_channel() itself (so it's correct even if a "2" reaches it
    un-migrated) and from service_master's startup migration, which persists
    the resolved value back to the config file.
    """
    comm_type = module_config.get("ComunicationType", 1)
    if comm_type != 2:
        return comm_type

    tcpip_address = module_config.get("TCPIPAddress")
    com_port = module_config.get("ComPortName")
    is_serial = (tcpip_address in (None, "", "0.0.0.0")) and bool(com_port)
    return 5 if is_serial else 6


_PARITY_MAP = {0: 'N', 1: 'E', 2: 'O', 3: 'M', 4: 'S'}  # 0=None, 1=Even, 2=Odd, 3=Mark, 4=Space


def create_channel(module_config: dict):
    """Factory function to create the appropriate communication channel.

    Args:
        module_config: configuration dict from the config JSON

    Returns:
        An initialized (but not yet connected) channel object. Serial/TCP/UDP
        return a CommunicationChannel (send/recv/close/is_open); Modbus
        (Seriale/Ethernet) returns a ModbusCommunicationChannel
        (read_registers instead of send/recv); PipeFile returns a
        PipeFileChannel (read_values instead of send/recv). All three
        families are still built through this single factory.

    Raises:
        ValueError if ComunicationType is unsupported.
        RuntimeError if the type needs a library (pyserial/pymodbus) that
        isn't installed.
    """
    comm_type = normalize_comunication_type(module_config)
    timeout = module_config.get("TimeoutAnswer", 1000) / 1000.0

    if comm_type == 0:
        # Serial communication
        com_port = module_config.get("ComPortName", "COM1")
        baudrate = module_config.get("ComPortBauds", 115200)
        bytesize = module_config.get("ComPortDataBits", 8)
        parity = _PARITY_MAP.get(module_config.get("ComPortParity", 0), 'N')
        stopbits = module_config.get("ComPortStopBits", 1)

        logging.info(f"Creating serial channel: {com_port} @ {baudrate} baud, "
                     f"parity={parity}, bytesize={bytesize}, stopbits={stopbits}")
        return SerialCommunicationChannel(com_port, baudrate, timeout, bytesize, parity, stopbits)

    elif comm_type == 1:
        # TCP/IP communication
        host = module_config.get("TCPIPAddress", "127.0.0.1")
        port = module_config.get("TCPIPPort", 3004)
        logging.info(f"Creating TCP channel: {host}:{port}")
        return TCPCommunicationChannel(host, port, timeout)

    elif comm_type == 3:
        # PipeFile: not a live connection, a file the instrument itself writes
        path = module_config.get("PipeFileName", "")
        missing_is_error = module_config.get("PipeFileMissingError", True)
        logging.info(f"Creating pipe file channel: {path}")
        return PipeFileChannel(path, missing_is_error)

    elif comm_type == 4:
        # Ethernet UDP - same addressing as TCP/IP, different socket type
        host = module_config.get("TCPIPAddress", "127.0.0.1")
        port = module_config.get("TCPIPPort", 3004)
        logging.info(f"Creating UDP channel: {host}:{port}")
        return UDPCommunicationChannel(host, port, timeout)

    elif comm_type in (5, 6):
        # Modbus Seriale (5) / Modbus Ethernet (6)
        if not PYMODBUS_AVAILABLE:
            raise RuntimeError("pymodbus is not installed; cannot create Modbus channel")
        try:
            unit_id = int(module_config.get("Address") or 1)
        except (TypeError, ValueError):
            unit_id = 1

        if comm_type == 5:
            com_port = module_config.get("ComPortName", "COM1")
            baudrate = module_config.get("ComPortBauds", 19200)
            bytesize = module_config.get("ComPortDataBits", 8)
            parity = _PARITY_MAP.get(module_config.get("ComPortParity", 0), 'N')
            stopbits = module_config.get("ComPortStopBits", 1)
            logging.info(f"Creating Modbus Seriale channel: COM{com_port} @ {baudrate} baud, unit={unit_id}")
            client = ModbusSerialClient(port=f"COM{com_port}", baudrate=baudrate, timeout=timeout,
                                         bytesize=bytesize, parity=parity, stopbits=stopbits)
        else:
            host = module_config.get("TCPIPAddress", "127.0.0.1")
            port = module_config.get("TCPIPPort", 502)
            logging.info(f"Creating Modbus Ethernet channel: {host}:{port}, unit={unit_id}")
            client = ModbusTcpClient(host=host, port=port, timeout=timeout)

        return ModbusCommunicationChannel(client, unit_id)

    elif comm_type == 7:
        # HTTP - not part of the original VB.NET enum, added on top of it
        # (see HTTPCommunicationChannel's docstring)
        host = module_config.get("TCPIPAddress", "127.0.0.1")
        port = module_config.get("TCPIPPort", 80)
        logging.info(f"Creating HTTP channel: http://{host}:{port}")
        return HTTPCommunicationChannel(host, port, timeout)

    else:
        raise ValueError(f"Unsupported communication type: {comm_type}")


def is_serial(channel: CommunicationChannel) -> bool:
    """Return True if the channel is a serial communication channel."""
    return isinstance(channel, SerialCommunicationChannel)


def is_tcp(channel: CommunicationChannel) -> bool:
    """Return True if the channel is a TCP/IP communication channel."""
    return isinstance(channel, TCPCommunicationChannel)
