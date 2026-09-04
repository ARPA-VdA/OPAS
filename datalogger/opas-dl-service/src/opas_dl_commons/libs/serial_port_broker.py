"""Serial port broker process.

Allows multiple driver processes to share a single physical COM port by
centralizing access to it in one dedicated process. The broker opens the
serial port once and exposes it to drivers as a local TCP socket
(127.0.0.1:<dynamic port>), so drivers can keep using the existing
TCPCommunicationChannel/comm_manager code paths unchanged.

This module is self-contained: it only depends on `comm_manager` for the
actual serial connection. All "shared COM port" orchestration (detecting
which ports need a broker, starting/stopping broker processes, rewriting
driver configs) lives in `core/shared_serial_ports.py`.
"""

import logging
import socket
import threading

import comm_manager
import common

# Port used by the service's own control_server (core/control_server.py).
# The broker's local TCP socket must never end up bound to this port.
RESERVED_PORTS = {8080}


def _handle_client(conn: socket.socket, channel, lock: threading.Lock) -> None:
    """Forward one driver's request/response pairs to the shared serial channel.

    Each driver connection is expected to follow the same send-then-receive
    pattern used by CommunicationChannel: write a command, then read a
    response. Access to the physical serial port is serialized via `lock`
    so only one request is in flight at a time across all drivers.
    """
    try:
        while True:
            data = conn.recv(4096)
            if not data:
                break
            with lock:
                channel.send(data)
                try:
                    response = channel.recv(4096, timeout=channel.timeout)
                except Exception as e:
                    logging.warning(f"[serial_port_broker] recv error: {e}")
                    response = b""
            if response:
                conn.sendall(response)
    except (ConnectionResetError, OSError):
        pass
    finally:
        try:
            conn.close()
        except Exception:
            pass


def run_broker(serial_config: dict, ready_queue, stop_event=None) -> None:
    """Open a serial port and serve it over a local TCP socket.

    Intended to be used as a `multiprocessing.Process` target.

    Args:
        serial_config: dict with the same serial-related keys accepted by
            `comm_manager.create_channel` for ComunicationType == 0
            (ComPortName, ComPortBauds, TimeoutAnswer, ComPortDataBits,
            ComPortParity, ComPortStopBits).
        ready_queue: a `multiprocessing.Queue`. On success the broker puts
            `("ok", port)` with the bound TCP port number. On failure it
            puts `("error", message)` and returns without serving.
        stop_event: optional `multiprocessing.Event`; when set, the broker
            stops accepting new connections and shuts down.
    """
    # Same reasoning as output_broker.run_broker(): this is a fresh child
    # process, and without a handler installed here, Ctrl+C's SIGINT (sent to
    # every process in the foreground process group on POSIX, not just the
    # parent) raises an unhandled KeyboardInterrupt out of the blocking
    # server.accept() below instead of being noticed by the `stop_event`/
    # should_run() checks in the loop.
    common.setup_signal_handlers()

    channel_config = dict(serial_config)
    channel_config["ComunicationType"] = 0

    try:
        channel = comm_manager.create_channel(channel_config)
        channel.connect()
    except Exception as e:
        logging.error(f"[serial_port_broker] Failed to open serial port: {e}")
        ready_queue.put(("error", str(e)))
        return

    server = None
    port = None
    try:
        # Bind to an OS-assigned port, retrying if it happens to collide
        # with a reserved port (e.g. the control server's port).
        for _ in range(10):
            candidate = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            candidate.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            candidate.bind(("127.0.0.1", 0))
            bound_port = candidate.getsockname()[1]
            if bound_port in RESERVED_PORTS:
                candidate.close()
                continue
            server = candidate
            port = bound_port
            break
        if server is None:
            raise OSError(f"Could not bind to a free port outside of {RESERVED_PORTS}")
        server.listen(8)
        server.settimeout(1.0)
    except Exception as e:
        logging.error(f"[serial_port_broker] Failed to bind local TCP socket: {e}")
        channel.close()
        ready_queue.put(("error", str(e)))
        return
    com_port = serial_config.get("ComPortName")
    logging.info(f"[serial_port_broker] Serving {com_port} on 127.0.0.1:{port}")
    ready_queue.put(("ok", port))

    lock = threading.Lock()
    client_threads = []
    try:
        while (stop_event is None or not stop_event.is_set()) and common.should_run():
            try:
                conn, _ = server.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            t = threading.Thread(target=_handle_client, args=(conn, channel, lock), daemon=True)
            t.start()
            client_threads.append(t)
    finally:
        logging.info(f"[serial_port_broker] Shutting down broker for {com_port}")
        try:
            server.close()
        except Exception:
            pass
        try:
            channel.close()
        except Exception:
            pass
