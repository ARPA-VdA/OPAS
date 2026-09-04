import os
import sys
import time
import signal
import multiprocessing
import threading
import logging
import logging.config
import shutil
import json

# Read by control_server.py's GET /status (via sys.modules["__main__"], same
# pattern as restart_service()'s request_restart lookup - service_master.py
# always runs as __main__, see that function's docstring) to report the
# master process's own uptime in the Sistema page.
SERVICE_START_TIME = time.time()

# Handle module imports for both frozen and non-frozen environments
if getattr(sys, 'frozen', False):
    # Running as compiled executable (PyInstaller)
    # Add the runtime location to sys.path so we can import service_init, etc.
    if hasattr(sys, '_MEIPASS'):
        # onedir mode: files are in _MEIPASS/core
        core_path = os.path.join(sys._MEIPASS, 'core')
        if os.path.exists(core_path):
            sys.path.insert(0, core_path)
    else:
        # Single-file mode fallback
        import tempfile
        base_path = os.path.abspath(os.path.dirname(sys.executable))
        sys.path.insert(0, base_path)
else:
    # Running as Python script: add src/core to path
    core_path = os.path.dirname(os.path.abspath(__file__))
    if core_path not in sys.path:
        sys.path.insert(0, core_path)

from service_init import (
    configure,
    set_log_level,
    BASE_DIR,
    OPAS_COMMONS_DIR,
    DRIVERS_DIR,
    SOURCE_DRIVERS_DIR,
    LOG_DIR,
    OUTPUT_DIR
)
from runtime_paths import resolve_active_config_path

# driver_manager and control_server are imported after logging is configured
driver_manager = None
start_control_server = None
shared_serial_ports = None
output_broker_manager = None

# Set once in main() once the control server is up, so request_restart() (called
# from control_server.py, a different module/thread) can flag it to stop too.
_control_server_ref = None


def _acquire_singleton_lock(port: int):
    """Bind an exclusive loopback TCP port to use as a cross-platform mutex.

    No extra dependency needed: the OS guarantees only one process can hold
    this bind, so a second launch of the service fails here immediately -
    before configure() touches shared logs/directories or any driver/output
    broker is started. Returns the bound socket (the caller must keep a
    reference alive for the process lifetime; the OS releases the port on
    exit) or None if another instance already holds it.
    """
    import socket

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    if hasattr(socket, "SO_EXCLUSIVEADDRUSE"):
        # Windows: closes the double-bind gap SO_REUSEADDR would otherwise leave.
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
    try:
        sock.bind(("127.0.0.1", port))
        sock.listen(1)
    except OSError:
        sock.close()
        return None
    return sock


# Fixed loopback-only port used purely as a startup mutex (never actually served).
# Guarded by current_process().name so only the top-level launch checks it, not
# the driver/output-broker child processes multiprocessing spawns from this same
# module - those would otherwise fail this same bind on Windows, where 'spawn'
# re-executes this module's top-level code in every child (the same reason
# multiprocessing.freeze_support() must sit behind `if __name__ == "__main__"`
# below rather than run unconditionally).
#
# __name__ == "__main__" is ALSO required, not just current_process().name: this
# same module gets re-imported a second time, still inside the one true main
# process, whenever control_server.py's POST /service/restart handler does its
# lazy `from service_master import request_restart` (Python has no record of
# this file already being loaded under the name "service_master" - it was only
# ever loaded as "__main__" - so a plain `import` genuinely re-executes this
# entire file from scratch). Without this second condition, that re-import hits
# the already-bound port, gets None back, and calls sys.exit(1) - which raises
# SystemExit (a BaseException, not an Exception, so control_server.py's
# `except Exception` never catches it) before request_restart() is ever called,
# turning every restart request into an unhandled 500 that never actually
# restarts anything. Spawned children still get excluded exactly as before,
# since current_process().name there is never "MainProcess".
_SINGLETON_LOCK_PORT = 47990
_singleton_lock_socket = None
if __name__ == "__main__" and multiprocessing.current_process().name == "MainProcess":
    _singleton_lock_socket = _acquire_singleton_lock(_SINGLETON_LOCK_PORT)
    if _singleton_lock_socket is None:
        print(
            f"ERRORE: un'altra istanza del servizio OPAS DL è già in esecuzione "
            f"(lock port {_SINGLETON_LOCK_PORT} già occupata). Uscita.",
            file=sys.stderr,
        )
        sys.exit(1)

# perform runtime directory creation and logging setup.
#
# Guarded the same way as the singleton lock above, for the same underlying
# reason: this call runs once for the real top-level process, but this
# module's top-level code re-executes - re-running configure() too if it
# weren't guarded - in two other situations: (a) control_server.py's POST
# /service/restart handler re-imports this file fresh under the name
# "service_master" (see the singleton lock comment above), and (b) every
# driver/output-broker child process multiprocessing spawns on Windows
# reconstructs this same "__main__" module to recreate global state. In both
# cases configure() would run again *inside the one real process* (for (a)) or
# in a child sharing the same log files (for (b)), while the real run's
# logging handlers still hold GENERAL_LOG/WEB_LOG open - its
# `GENERAL_LOG.unlink()`/`WEB_LOG.unlink()` then hit a live handle and raise
# PermissionError (WinError 32) on Windows, surfacing as the "Error setting up
# GENERAL_LOG/WEB_LOG" warning. Children don't need configure()'s side effects
# anyway: the runtime directories it creates already exist by the time any
# child is spawned (only main() spawns children, after configure() has run in
# the real process), and the LIBS_DIR sys.path insertion they might need
# happens unconditionally in service_init.py's own module-level bootstrap,
# independent of configure().
if __name__ == "__main__" and multiprocessing.current_process().name == "MainProcess":
    configure()

# =========================
# Functions
# =========================

def load_active_config(path=None):
    """Load a JSON configuration from `config/active`.

    If `path` is provided it is used directly. Otherwise the function looks
    for JSON files inside `CONFIG_ACTIVE_DIR` and picks the most recently
    modified one. Returns an empty dict on error or if no config is found.
    """
    # If a specific path/file is provided use it. Otherwise resolve it via the
    # shared lookup (env vars, then default candidate directories, then MEIPASS).
    if path is None:
        logging.debug(f"[service_master] load_active_config: searching for config...")
        logging.debug(f"[service_master]   BASE_DIR = {BASE_DIR}")
        logging.debug(f"[service_master]   OPAS_COMMONS_DIR = {OPAS_COMMONS_DIR}")

        resolved = resolve_active_config_path()
        if resolved is None:
            logging.error(f"[service_master] Active config file not found in any known location.")
            logging.warning("You can set CONFIG_PATH to a specific file or CONFIG_DIR to a folder containing the active JSON config.")
            return {}
        path = str(resolved)
        logging.info(f"[service_master] Config found: {path}")

    if not os.path.exists(path):
        logging.warning(f"Config file not found: {path}")
        return {}

    try:
        with open(path, "r", encoding="utf-8-sig") as f:
            cfg = json.load(f)
        logging.info(f"Config loaded successfully: {path}")
        return cfg
    except Exception as e:
        logging.exception(f"Error parsing config {path}: {e}")
        return {}


def _migrate_legacy_modbus_types(active_config):
    """Rewrite any module still using the retired generic Modbus type (2) to
    the new explicit Modbus Seriale (5) / Modbus Ethernet (6) split (see
    comm_manager.normalize_comunication_type for the serial-vs-ethernet
    heuristic), persisting the change back to the active config file so this
    only has to run once per config, not be re-interpreted on every load.

    No-op if there's nothing to migrate (including if the active config path
    can't be resolved to write back to - the in-memory dict this process
    launches drivers from is still correct either way, since
    comm_manager.create_channel() re-normalizes ComunicationType itself).
    """
    if not isinstance(active_config, dict):
        return
    modules = active_config.get("Modules")
    if not isinstance(modules, list):
        return

    import comm_manager

    changed = False
    for mod in modules:
        if not isinstance(mod, dict) or mod.get("ComunicationType") != 2:
            continue
        new_type = comm_manager.normalize_comunication_type(mod)
        mod["ComunicationType"] = new_type
        changed = True
        logging.info(f"[service_master] Migrated legacy Modbus type (2) to {new_type} "
                     f"for module {mod.get('Name') or mod.get('ID')}")

    if not changed:
        return

    path = resolve_active_config_path()
    if path is None:
        logging.warning("[service_master] Could not persist Modbus type migration: active config path not found")
        return

    try:
        tmp_path = str(path) + ".tmp"
        with open(tmp_path, "w", encoding="utf-8-sig") as f:
            json.dump(active_config, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, path)
        logging.info(f"[service_master] Persisted Modbus type migration to {path}")
    except Exception as e:
        logging.exception(f"[service_master] Failed to persist Modbus type migration: {e}")


def load_drivers_dict(path=None):
    """Load the drivers/drivers_dict.json file that maps ModuleType -> driver(s).

    Returns an empty dict on absence/error.
    """
    if path is None:
        path = os.path.join(DRIVERS_DIR, "drivers_dict.json")
        logging.debug(f"[service_master] load_drivers_dict: default path: {path}")

    # if it does not exist in the runtime drivers folder (e.g. dist), try alternate paths
    if not os.path.exists(path):
        logging.debug(f"[service_master] drivers_dict not found at default, checking alternates...")
        alt_paths = [
            os.path.join(BASE_DIR, "drivers", "drivers_dict.json"),
            os.path.join(BASE_DIR, "..", "drivers", "drivers_dict.json"),
            os.path.join(BASE_DIR, "..", "..", "drivers", "drivers_dict.json"),
        ]
        for i, alt in enumerate(alt_paths):
            logging.debug(f"[service_master] Checking alternate [{i}]: {alt}")
            if os.path.exists(alt):
                path = alt
                logging.debug(f"[service_master] Found at alternate [{i}]: {alt}")
                break

    if not os.path.exists(path):
        logging.warning(f"drivers_dict not found: {path}")
        return {}

    try:
        with open(path, "r", encoding="utf-8") as f:
            dd = json.load(f)
        logging.info(f"drivers_dict loaded: {path}")
        return dd if isinstance(dd, dict) else {}
    except Exception as e:
        logging.exception(f"Error loading drivers_dict: {e}")
        return {}


def _stop_drivers_and_brokers():
    """Stop every running driver, the shared-COM-port brokers, and the output broker.

    Shared by the SIGTERM/SIGINT shutdown handler (process exiting for good)
    and request_restart() (process about to re-exec itself in place).
    """
    try:
        regs = driver_manager.get_registry()
        for iid, info in regs.items():
            proc = info.get("process")
            if proc is not None and getattr(proc, "is_alive", lambda: False)():
                try:
                    logging.info(f"Stopping driver {iid} during shutdown")
                    driver_manager.stop(iid)
                except Exception:
                    logging.exception(f"Failed to stop driver {iid} during shutdown")
    except Exception:
        logging.exception("Error while stopping drivers during shutdown")
    try:
        shared_serial_ports.shutdown()
    except Exception:
        logging.exception("Error while stopping shared serial port brokers")
    try:
        output_broker_manager.shutdown()
    except Exception:
        logging.exception("Error while stopping output broker")


def request_restart(delay: float = 0.5):
    """Gracefully stop everything, then re-exec this same process to restart clean.

    Called from the control API's POST /service/restart. Runs on a background
    thread so the HTTP response confirming the request can be flushed to the
    client before the process image is replaced by os.execv - execv does not
    fork a new process, it replaces this one in place (same PID), which is
    also why the singleton lock socket must be closed explicitly first: the OS
    only auto-closes CLOEXEC descriptors at the moment of exec, and we want
    the port free the instant the new image's top-level code re-binds it.
    """
    def _do_restart():
        time.sleep(delay)
        logging.info("Service restart requested via control API")
        try:
            if _control_server_ref is not None:
                setattr(_control_server_ref, "should_exit", True)
        except Exception:
            logging.exception("Error while stopping control server for restart")

        _stop_drivers_and_brokers()

        global _singleton_lock_socket
        if _singleton_lock_socket is not None:
            try:
                _singleton_lock_socket.close()
            except Exception:
                logging.exception("Error while releasing singleton lock for restart")
            _singleton_lock_socket = None

        # Frozen (PyInstaller) builds: sys.executable IS the program, so argv[0]
        # is already that same path - re-adding sys.executable would duplicate it.
        # Source runs: sys.executable is the interpreter, argv[0] is the script
        # path passed to it - both pieces are needed to reproduce the invocation.
        if getattr(sys, "frozen", False):
            args = [sys.executable] + sys.argv[1:]
        else:
            args = [sys.executable] + sys.argv
        os.execv(sys.executable, args)

    threading.Thread(target=_do_restart, daemon=True).start()


def launch_driver(driver_path, instrument_id, module_config=None, driver_log=None):
    """Start a single driver in a separate process, passing the module config via an env var.

    `driver_log` (optional): path to the driver's log file (string or Path). If provided
    it will be forwarded to the child process via the `DRIVER_LOG` env var.
    """
    # legacy shim: delegate to driver_manager.manager
    return driver_manager.launch_driver(driver_path, instrument_id, module_config=module_config, driver_log=driver_log)


def main():
    # Import modules that may configure logging after logging is initialized
    global driver_manager, start_control_server, shared_serial_ports, output_broker_manager, _control_server_ref
    if driver_manager is None:
        from driver_manager import manager as driver_manager
    if start_control_server is None:
        from control_server import start_control_server
    if shared_serial_ports is None:
        from shared_serial_ports import manager as shared_serial_ports
    if output_broker_manager is None:
        from output_broker_manager import manager as output_broker_manager

    logging.info("Service master started")
    logging.info(f"Base paths in use:")
    logging.info(f"  BASE_DIR = {BASE_DIR}")
    logging.info(f"  OPAS_COMMONS_DIR = {OPAS_COMMONS_DIR}")
    logging.info(f"  DRIVERS_DIR = {DRIVERS_DIR}")
    logging.info(f"  LOG_DIR = {LOG_DIR}")
    logging.info(f"  OUTPUT_DIR = {OUTPUT_DIR}")

    # Determine runtime drivers folder:
    # - when running from source, prefer the project `drivers/` or the SOURCE_DRIVERS_DIR
    # - when running frozen (PyInstaller), expect drivers to be present in DRIVERS_DIR
    if getattr(sys, "_MEIPASS", False):
        runtime_drivers_dir = DRIVERS_DIR
        logging.debug(f"[service_master] Running as frozen executable (PyInstaller), using DRIVERS_DIR")
    else:
        proj_drivers = os.path.join(BASE_DIR, "drivers")
        if os.path.exists(proj_drivers) and os.path.isdir(proj_drivers):
            runtime_drivers_dir = proj_drivers
            logging.debug(f"[service_master] Running from source, found project drivers folder")
        elif os.path.exists(SOURCE_DRIVERS_DIR) and os.path.isdir(SOURCE_DRIVERS_DIR):
            runtime_drivers_dir = SOURCE_DRIVERS_DIR
            logging.debug(f"[service_master] Running from source, using SOURCE_DRIVERS_DIR")
        else:
            runtime_drivers_dir = DRIVERS_DIR
            logging.debug(f"[service_master] Using DRIVERS_DIR as fallback")

    logging.info(f"Using drivers folder: {runtime_drivers_dir}")

    # load the active configuration into a Python object
    active_config = load_active_config()
    _migrate_legacy_modbus_types(active_config)
    set_log_level(active_config.get("LogLevel", "INFO"))

    # Start the OPAS NEO output broker for this station and bind driver_manager
    # to it, so every driver launched below writes through the same broker
    # (see output_broker_manager.py for why this always starts, unlike the
    # shared-COM-port broker which only starts when modules actually collide).
    try:
        output_queue, output_station_header = output_broker_manager.start(active_config)
        driver_manager.set_output_context(output_queue, output_station_header)
    except Exception:
        logging.exception("Failed to start output broker")

    # load the mapping of supported drivers (drivers_dict)
    drivers_dict = load_drivers_dict(path=os.path.join(runtime_drivers_dir, "drivers_dict.json"))
    driver_manager.set_driver_resolution_context(runtime_drivers_dir, drivers_dict)

    # --- Driver startup (logic embedded in job_drivers) ---

    if not os.path.exists(runtime_drivers_dir):
        logging.warning(f"Drivers folder not found: {runtime_drivers_dir}")
    else:
        # If the config contains a list of modules, use it to decide what to launch.
        modules = active_config.get("Modules") if isinstance(active_config, dict) else None

        # Modules that share the same physical COM port are rewritten here to
        # point at a shared serial_port_broker process instead of opening the
        # port directly (see shared_serial_ports.py).
        if isinstance(modules, list):
            modules = shared_serial_ports.prepare_modules(modules)

        if isinstance(modules, list) and len(modules) > 0:
            for mod in modules:
                if not isinstance(mod, dict):
                    logging.warning(f"Invalid Modules entry in config: {mod}")
                    continue

                # Skip inactive modules
                if mod.get("Active") is False:
                    logging.info(f"Module inactive, skipping: {mod.get('Name') or mod.get('ID')}")
                    continue

                # Read ModuleType and use drivers_dict to obtain the associated driver(s)
                for driver_file, instrument_id in driver_manager.resolve_driver_for_module(mod):
                    # Note: channel creation now happens inside the driver process (see driver.py)
                    # This avoids issues with multiprocessing on Windows (spawn doesn't share memory)
                    # launch_driver registers the process in driver_manager
                    driver_log = LOG_DIR / f"driver_{instrument_id}.log"
                    p = launch_driver(driver_file, instrument_id, module_config=mod, driver_log=str(driver_log))
        else:
            # No modules defined: do not start drivers not mapped to modules
            logging.info("No modules defined in config; no drivers started")

    # start control server so the service is interrogable
    control_server = None
    try:
        control_server = start_control_server()
        _control_server_ref = control_server
    except Exception as e:
        logging.exception("Failed to start control server: %s", e)

    # Setup graceful shutdown handling
    shutdown_event = threading.Event()

    def _shutdown(signum, frame):
        logging.info(f"Shutdown signal received: {signum}")
        shutdown_event.set()
        # stop control server
        try:
            if control_server is not None:
                # uvicorn.Server listens to `should_exit` flag
                setattr(control_server, "should_exit", True)
        except Exception:
            logging.exception("Error while stopping control server")
        _stop_drivers_and_brokers()

    # register signal handlers
    try:
        signal.signal(signal.SIGINT, _shutdown)
        signal.signal(signal.SIGTERM, _shutdown)
    except Exception:
        logging.exception("Could not register signal handlers")

    # --- Main service loop ---
    try:
        while not shutdown_event.is_set():
            # optional: monitor driver processes and log status
            try:
                for iid, info in driver_manager.list_drivers().items():
                    if not info.get("alive"):
                        logging.warning(f"Driver {iid} not alive (pid={info.get('pid')})")
            except Exception:
                logging.exception("Error while monitoring drivers")
            shutdown_event.wait(30)
    except KeyboardInterrupt:
        logging.info("KeyboardInterrupt received, initiating shutdown")
        _shutdown(signal.SIGINT, None)


if __name__ == "__main__":
    # Required when using multiprocessing in a frozen executable on Windows
    try:
        multiprocessing.freeze_support()
    except Exception:
        pass
    main()
