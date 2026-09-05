import os
import json
import logging
import runpy
import time
from datetime import datetime
from multiprocessing import Process
import threading


def _relative_driver_path(driver_file: str) -> str | None:
    if not driver_file:
        return None
    normalized = driver_file.replace("\\", "/")
    marker = "/drivers/"
    idx = normalized.rfind(marker)
    if idx == -1:
        return None
    return normalized[idx + len(marker):]


def _process_runner(driver_path, instrument_id, module_config, driver_log=None,
                     output_queue=None, station_header=None):
    """Module-level runner used as Process target so the DriverManager
    instance (and its locks) are not pickled on Windows 'spawn'.
    """
    os.environ["INSTRUMENT_ID"] = str(instrument_id)
    if driver_log is not None:
        try:
            os.environ["DRIVER_LOG"] = str(driver_log)
        except Exception:
            pass
    if module_config is not None:
        try:
            os.environ["MODULE_CONFIG"] = json.dumps(module_config)
        except Exception:
            os.environ["MODULE_CONFIG"] = str(module_config)
    if output_queue is not None:
        try:
            import output_manager
            output_manager.configure(output_queue, station_header)
        except Exception as e:
            logging.warning(f"[driver_manager] Failed to configure output_manager: {e}")
    runpy.run_path(driver_path, run_name="__main__")


class DriverManager:
    def __init__(self):
        self._registry = {}  # instrument_id -> {process, driver_file, module_config, ...}
        self._lock = threading.Lock()
        self._output_queue = None
        self._station_header = None
        self._runtime_drivers_dir = None
        self._drivers_dict = None

    def set_output_context(self, queue, station_header):
        """Bind future driver launches to the running output broker.

        Called once by service_master after starting output_broker_manager,
        before any driver is launched. launch_driver/start/restart all read
        this state, so no other call site needs to change.
        """
        with self._lock:
            self._output_queue = queue
            self._station_header = station_header

    def set_driver_resolution_context(self, runtime_drivers_dir, drivers_dict):
        """Bind the ModuleType -> driver.py resolution used by resolve_driver_for_module.

        Called once by service_master.main() after it computes the runtime
        drivers folder and loads drivers_dict.json. This state deliberately
        lives here (on the DriverManager singleton) rather than as module-level
        state on service_master itself: service_master.py is launched as
        `__main__`, so a later `from service_master import ...` (e.g. from
        control_server.py) re-executes the whole file as a *second*, distinct
        module object under the name "service_master" - one whose own main()
        never ran, so any state set only inside main() would read back as None
        there. driver_manager.py is never run as `__main__`, so `manager` (this
        singleton) is the one piece of state guaranteed to be the same object
        everywhere it's imported.
        """
        with self._lock:
            self._runtime_drivers_dir = runtime_drivers_dir
            self._drivers_dict = drivers_dict

    def resolve_driver_for_module(self, mod):
        """Resolve the driver file(s) + instrument_id for a single module dict.

        Mirrors the ModuleType -> drivers_dict.json -> driver.py resolution
        service_master.main()'s startup loop applies to every module, using
        the context set once via set_driver_resolution_context(). Lets
        control_server.py's create_module register (not launch) the driver for
        a module created after the service already started, without a full
        restart.

        Returns a list of (driver_file, instrument_id) pairs - a module can map
        to more than one driver name in drivers_dict.json. Empty if the module
        can't be resolved (bad/missing ModuleType, no drivers_dict entry,
        driver.py not found) or if called before set_driver_resolution_context.
        """
        with self._lock:
            runtime_drivers_dir = self._runtime_drivers_dir
            drivers_dict = self._drivers_dict

        if not isinstance(mod, dict) or not isinstance(drivers_dict, dict) or not runtime_drivers_dir:
            return []

        module_type = mod.get("ModuleType")
        if module_type is None:
            logging.warning(f"Module without ModuleType: {mod.get('Name') or mod.get('ID')}")
            return []

        entry = drivers_dict.get(str(module_type)) or drivers_dict.get(module_type)
        if not isinstance(entry, dict):
            logging.warning(f"No drivers_dict entry for ModuleType {module_type}")
            return []

        drv = entry.get("Drivers") or entry.get("Driver") or entry.get("driver")
        if isinstance(drv, list):
            driver_names = [d for d in drv if isinstance(d, str)]
        elif isinstance(drv, str):
            driver_names = [drv]
        else:
            logging.warning(f"Invalid driver entry in drivers_dict for ModuleType {module_type}")
            return []

        out = []
        for driver_name in driver_names:
            # "Drivers" values may be a plain folder name ("API_100") or a "/"-
            # separated path ("API/API_100") to group drivers under a brand/family
            # folder - split explicitly rather than relying on os.path.join to
            # interpret the embedded separator so this behaves the same on every OS.
            driver_file = os.path.join(runtime_drivers_dir, *driver_name.split("/"), "driver.py")
            if not os.path.exists(driver_file):
                logging.warning(f"Driver defined in drivers_dict not found: {driver_file}")
                continue
            instrument_id = str(mod.get("ID") or mod.get("Name") or driver_name)
            out.append((driver_file, instrument_id))
        return out

    def get_driver_catalog(self, modules=None):
        """Build a read-only catalog of every driver folder under drivers/, for
        the UI's driver exploration page - which folders exist, what
        drivers_dict.json says about each (grouped by ModuleType, since one
        driver folder can serve several, e.g. API/API_XXX covers ModuleTypes
        100/200/300/400), and which modules in the currently active config
        (passed in by the caller - control_server.py reads the config file,
        this class has no config-reading responsibility of its own) resolve to
        it via the same "/"-split path used by resolve_driver_for_module.

        Returns a list of dicts, one per folder containing a driver.py, sorted
        by path:
            {
                "path": "API/API_XXX",       # relative to drivers/, "/"-separated -
                                              # matches drivers_dict.json's "Drivers" value
                "group": "API",              # first path segment - the natural
                                              # brand/family grouping for the UI
                "folderName": "API_XXX",     # last path segment
                "moduleTypes": [{"moduleType": 100, "name": ..., "producer": ...,
                                  "description": ..., "version": ...}, ...],
                "instruments": [{"id": 1, "name": "SO2 Analyzer"}, ...],
            }
        A folder with no drivers_dict.json entry still appears, with empty
        moduleTypes/instruments - useful for spotting orphaned driver folders.
        Empty list if called before set_driver_resolution_context.
        """
        with self._lock:
            runtime_drivers_dir = self._runtime_drivers_dir
            drivers_dict = self._drivers_dict

        if not runtime_drivers_dir or not isinstance(drivers_dict, dict):
            return []

        # 1. Walk drivers/ for every driver.py, recording its folder's path
        #    relative to drivers/, "/"-separated to match drivers_dict.json's
        #    "Drivers" convention regardless of OS. Folders (at any depth) whose
        #    name starts with "_" are pruned from the walk entirely - e.g.
        #    _examples/, which drivers_dict.json deliberately never references
        #    (see its sdk_example_driver/driver.py docstring) because it's a
        #    documentation fixture, not an installed driver.
        driver_paths = []
        for root, dirs, files in os.walk(runtime_drivers_dir):
            dirs[:] = [d for d in dirs if not d.startswith("_")]
            if "driver.py" not in files:
                continue
            rel = os.path.relpath(root, runtime_drivers_dir).replace(os.sep, "/")
            driver_paths.append(rel)

        # 2. Invert drivers_dict.json: driver path -> list of (ModuleType key, entry).
        #    Several ModuleType keys can share the same "Drivers" path (e.g. API_XXX).
        path_to_types: dict[str, list] = {}
        for key, entry in drivers_dict.items():
            if key == "FullConfig" or not isinstance(entry, dict):
                continue
            drv = entry.get("Drivers") or entry.get("Driver") or entry.get("driver")
            names = drv if isinstance(drv, list) else [drv] if isinstance(drv, str) else []
            for name in names:
                if isinstance(name, str):
                    path_to_types.setdefault(name, []).append((key, entry))

        # 3. Index active-config modules by ModuleType (string keys, matching
        #    drivers_dict.json's convention).
        modules_by_type: dict[str, list] = {}
        for mod in modules or []:
            if not isinstance(mod, dict):
                continue
            module_type = mod.get("ModuleType")
            if module_type is None:
                continue
            modules_by_type.setdefault(str(module_type), []).append(mod)

        # 4. Assemble, sorted so the UI's grouping/ordering is stable across calls.
        catalog = []
        for rel_path in sorted(driver_paths):
            entries = path_to_types.get(rel_path, [])
            seen_ids = set()
            instruments = []
            for key, _entry in entries:
                for mod in modules_by_type.get(str(key), []):
                    module_id = mod.get("ID")
                    if module_id in seen_ids:
                        continue
                    seen_ids.add(module_id)
                    instruments.append({"id": module_id, "name": mod.get("Name")})
            parts = rel_path.split("/")
            catalog.append({
                "path": rel_path,
                "group": parts[0],
                "folderName": parts[-1],
                "moduleTypes": [
                    {
                        "moduleType": int(key) if str(key).isdigit() else key,
                        "name": entry.get("Name"),
                        "producer": entry.get("Producer"),
                        "description": entry.get("Description"),
                        "version": entry.get("Version"),
                    }
                    for key, entry in entries
                ],
                "instruments": instruments,
            })
        return catalog

    # Note: do NOT use an instance method as the Process target on Windows
    # because the spawn start method will pickle `self` (which contains
    # a `threading.Lock`) and that is not picklable. Use the module-level
    # `_process_runner` instead.

    @staticmethod
    def _read_drivers_dict(driver_file):
        """Read drivers_dict.json from the drivers/ folder that contains driver_file.

        Driver folders can be nested for grouping (e.g. drivers/API/API_100/driver.py
        to group by brand/family - see resolve_driver_for_module), so the number of
        levels between driver_file and the drivers/ folder isn't fixed. Walk upward
        from driver_file's directory looking for drivers_dict.json, stopping at the
        first match. Returns an empty dict on any error or if none is found.
        """
        try:
            current = os.path.dirname(os.path.abspath(driver_file))
            for _ in range(10):  # generous bound against unexpectedly deep/broken paths
                dict_path = os.path.join(current, "drivers_dict.json")
                if os.path.exists(dict_path):
                    with open(dict_path, "r", encoding="utf-8") as f:
                        return json.load(f)
                parent = os.path.dirname(current)
                if parent == current:
                    break
                current = parent
        except Exception as e:
            logging.debug(f"[DriverManager] Could not read drivers_dict.json: {e}")
        return {}

    def launch_driver(self, driver_path, instrument_id, module_config=None, driver_log=None):
        logging.info(f"Starting driver {instrument_id}: {driver_path}")
        iid = str(instrument_id)
        with self._lock:
            existing = self._registry.get(iid)
            if driver_log is None and existing is not None:
                driver_log = existing.get("driver_log")
            output_queue = self._output_queue
            station_header = self._station_header

        # A driver process only ever receives its own Module via MODULE_CONFIG,
        # never the station config (same constraint as DataFileHeader, see
        # output_manager.py) - so a per-module LogLevel override, if absent,
        # can only be resolved against the station-level default right here,
        # at actual launch time. Read fresh from disk (not cached) so a
        # station-level default changed via POST /logging is picked up by the
        # next restart of any module without its own override, without this
        # class needing to know when that default changes. Only the copy
        # handed to the new process is resolved - self._registry below keeps
        # the original, still-unresolved module_config, so the *next* launch
        # re-resolves against whatever the station default is by then instead
        # of reusing a value frozen at this launch.
        process_config = module_config
        if isinstance(module_config, dict) and not module_config.get("LogLevel"):
            try:
                from runtime_paths import resolve_active_config_path
                path = resolve_active_config_path()
                if path is not None:
                    with open(path, "r", encoding="utf-8-sig") as f:
                        station_data = json.load(f)
                    process_config = dict(module_config, LogLevel=station_data.get("LogLevel", "INFO"))
            except Exception as e:
                logging.warning(f"[driver_manager] Failed to resolve station LogLevel default for {iid}: {e}")

        p = Process(target=_process_runner,
                     args=(driver_path, instrument_id, process_config, driver_log, output_queue, station_header))
        p.start()
        with self._lock:
            self._registry[iid] = {
                "process": p,
                "driver_file": driver_path,
                "module_config": module_config,
                "driver_log": driver_log,
                "start_time": time.time(),
            }
        return p

    def register_driver(self, instrument_id, driver_file, module_config=None, driver_log=None):
        with self._lock:
            self._registry[str(instrument_id)] = {
                "process": None,
                "driver_file": driver_file,
                "module_config": module_config,
                "driver_log": driver_log,
            }

    def is_registered(self, instrument_id) -> bool:
        """Whether instrument_id already has a registry entry (running or not).

        Callers that might register a module a second time (e.g. control_server's
        save_module, when a module is toggled from Active: false to true) must
        check this first: register_driver() unconditionally overwrites the entry,
        including setting "process" back to None, which would orphan an already-
        running process reference for a module that turns out to be registered already.
        """
        with self._lock:
            return str(instrument_id) in self._registry

    def stop(self, instrument_id, timeout=5):
        iid = str(instrument_id)
        with self._lock:
            info = self._registry.get(iid)
        if not info:
            raise KeyError("driver not found")
        proc = info.get("process")
        if proc is None or not proc.is_alive():
            raise RuntimeError("not running")
        proc.terminate()
        proc.join(timeout)
        if proc.is_alive():
            logging.warning(f"Driver {iid} did not exit after SIGTERM; sending SIGKILL")
            proc.kill()
            proc.join()
        with self._lock:
            if iid in self._registry:
                self._registry[iid]["process"] = None
        return True

    def start(self, instrument_id):
        iid = str(instrument_id)
        with self._lock:
            info = self._registry.get(iid)
        if not info:
            raise KeyError("driver not found")
        if info.get("process") and info.get("process").is_alive():
            raise RuntimeError("already running")
        p = self.launch_driver(info.get("driver_file"), iid,
                               module_config=info.get("module_config"),
                               driver_log=info.get("driver_log"))
        return p

    def restart(self, instrument_id):
        iid = str(instrument_id)
        with self._lock:
            info = self._registry.get(iid)
        if not info:
            raise KeyError("driver not found")
        proc = info.get("process")
        try:
            if proc and proc.is_alive():
                proc.terminate()
                proc.join(5)
                if proc.is_alive():
                    logging.warning(f"Driver {iid} did not exit after SIGTERM; sending SIGKILL")
                    proc.kill()
                    proc.join()
        except Exception:
            pass
        p = self.launch_driver(info.get("driver_file"), iid,
                               module_config=info.get("module_config"),
                               driver_log=info.get("driver_log"))
        return p

    def list_drivers(self):
        now = time.time()
        out = {}
        shared_groups = {}  # ComPortName -> [instrument_id, ...], for modules sharing a physical port
        with self._lock:
            for iid, info in self._registry.items():
                proc = info.get("process")
                module_config = info.get("module_config") or {}
                driver_file = info.get("driver_file") or ""

                # Driver name from active config
                name = module_config.get("Name") or module_config.get("name")
                if not name:
                    try:
                        name = os.path.basename(os.path.dirname(driver_file)) or iid
                    except Exception:
                        name = iid

                alive = bool(proc.is_alive()) if proc is not None else False

                # Start time and uptime
                start_time_ts = info.get("start_time")
                start_time_iso = datetime.fromtimestamp(start_time_ts).isoformat() if start_time_ts else None
                uptime_seconds = int(now - start_time_ts) if (alive and start_time_ts is not None) else None

                # Connection details from active config. Uses
                # comm_manager.normalize_comunication_type() rather than the
                # raw field so a not-yet-migrated legacy "2" (generic Modbus,
                # see comm_manager.py) still resolves to the right type here
                # too, same as create_channel() does.
                import comm_manager
                comm_type = comm_manager.normalize_comunication_type(module_config)
                com_port = module_config.get("ComPortName")
                com_port_display = f"COM{com_port}" if com_port not in (None, "") else None

                if comm_type == 1:
                    connection = {"type": "TCP/IP", "host": module_config.get("TCPIPAddress") or None,
                                  "port": module_config.get("TCPIPPort") or None, "baud_rate": None}
                elif comm_type == 4:
                    connection = {"type": "UDP", "host": module_config.get("TCPIPAddress") or None,
                                  "port": module_config.get("TCPIPPort") or None, "baud_rate": None}
                elif comm_type == 6:
                    connection = {"type": "Modbus Ethernet", "host": module_config.get("TCPIPAddress") or None,
                                  "port": module_config.get("TCPIPPort") or None, "baud_rate": None}
                elif comm_type == 0:
                    connection = {"type": "Serial", "host": com_port_display,
                                  "port": None, "baud_rate": module_config.get("ComPortBauds") or None}
                elif comm_type == 5:
                    connection = {"type": "Modbus Seriale", "host": com_port_display,
                                  "port": None, "baud_rate": module_config.get("ComPortBauds") or None}
                elif comm_type == 3:
                    connection = {"type": "PipeFile", "host": module_config.get("PipeFileName") or None,
                                  "port": None, "baud_rate": None}
                elif comm_type == 7:
                    connection = {"type": "HTTP", "host": module_config.get("TCPIPAddress") or None,
                                  "port": module_config.get("TCPIPPort") or None, "baud_rate": None}
                else:
                    connection = None

                # Model and brand from drivers_dict.json, keyed by ModuleType
                module_type = module_config.get("ModuleType")
                dict_entry = {}
                if driver_file and module_type is not None:
                    drivers_dict = self._read_drivers_dict(driver_file)
                    dict_entry = (drivers_dict.get(str(module_type))
                                  or drivers_dict.get(module_type)
                                  or {})

                # Modules sharing a physical COM port are rewritten by
                # shared_serial_ports.py to point at a broker, tagging the
                # rewritten config with _SharedComPortName (the real port
                # name) before it's ever passed to launch_driver - so it's
                # already sitting in module_config here, no separate lookup
                # into shared_serial_ports needed.
                shared_com_port = module_config.get("_SharedComPortName")
                if shared_com_port:
                    shared_groups.setdefault(shared_com_port, []).append(iid)

                out[iid] = {
                    "instrument_id": iid,
                    "name": name,
                    "alive": alive,
                    "pid": getattr(proc, "pid", None),
                    "model": dict_entry.get("Name") or None,
                    "brand": dict_entry.get("Producer") or None,
                    "driver_version": dict_entry.get("Version") or None,
                    "start_time": start_time_iso,
                    "uptime_seconds": uptime_seconds,
                    "connection": connection,
                    "driver_file": _relative_driver_path(driver_file),
                    "shared_com_port": shared_com_port or None,
                    "shared_with": [],  # filled in below once every group is known
                }

        for com_port, ids in shared_groups.items():
            for iid in ids:
                out[iid]["shared_with"] = [other for other in ids if other != iid]

        return out

    def update_module_config_channel(self, instrument_id, channel_id: int, patch: dict) -> bool:
        """Patch a channel's config in-memory for a registered driver.

        Keeps the in-memory module_config (used by start/restart to relaunch
        the driver process) in sync with an edit just written to the on-disk
        config file, so a subsequent restart picks up the new values.
        Returns False (not an error) if the driver isn't registered/running,
        since the on-disk file remains the source of truth for the next launch.
        """
        iid = str(instrument_id)
        with self._lock:
            entry = self._registry.get(iid)
            if not entry or not isinstance(entry.get("module_config"), dict):
                return False
            channels = entry["module_config"].get("Channels", [])
            for ch in channels:
                if ch.get("ID") == channel_id:
                    ch.update(patch)
                    return True
        return False

    def update_module_config(self, instrument_id, patch: dict) -> bool:
        """Patch a registered driver's in-memory module_config fields (not Channels).

        Mirrors update_module_config_channel: keeps the in-memory config used by
        start/restart in sync with an edit just written to the on-disk config file.
        Returns False (not an error) if the driver isn't registered/running.
        """
        iid = str(instrument_id)
        with self._lock:
            entry = self._registry.get(iid)
            if not entry or not isinstance(entry.get("module_config"), dict):
                return False
            safe_patch = {k: v for k, v in patch.items() if k != "Channels"}
            entry["module_config"].update(safe_patch)
            return True

    def get_registry(self):
        with self._lock:
            out = {}
            for k, v in self._registry.items():
                module_config = v.get("module_config")
                name = None
                if isinstance(module_config, dict):
                    name = module_config.get("Name") or module_config.get("name")
                if not name:
                    df = v.get("driver_file") or ""
                    try:
                        name = os.path.basename(os.path.dirname(df)) or k
                    except Exception:
                        name = k
                out[k] = {
                    "driver_file": v.get("driver_file"),
                    "module_config": v.get("module_config"),
                    "pid": getattr(v.get("process"), "pid", None),
                    "name": name,
                }
            return out


# singleton instance to be imported by other modules
manager = DriverManager()
