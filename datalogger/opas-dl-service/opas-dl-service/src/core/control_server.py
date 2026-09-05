from fastapi import FastAPI, HTTPException
import json
import logging
import logging.handlers
import os
import sys
import threading
import uvicorn

from driver_manager import manager as driver_manager

app = FastAPI(title="Service Control API")


@app.get("/drivers")
def list_drivers():
    return driver_manager.list_drivers()


@app.get("/status")
def get_status():
    """Service-level metadata not tied to any particular driver - currently just
    the master process's own start time (seconds since epoch), used by the
    Electron UI's Sistema page to show "Servizio avviato" next to the UI's own
    start time. Read via sys.modules["__main__"] for the same reason
    restart_service() below does - service_master.py always runs as __main__,
    so `from service_master import SERVICE_START_TIME` would read a second,
    unrelated module object whose value is irrelevant.
    """
    start_time = getattr(sys.modules.get("__main__"), "SERVICE_START_TIME", None)
    return {"start_time": start_time}


@app.get("/driver-catalog")
def get_driver_catalog():
    """List every driver folder under drivers/, grouped by brand/family, with
    drivers_dict.json metadata and which instruments in the active config use
    each one - see driver_manager.get_driver_catalog for the exact shape.

    Read-only: no process is started, stopped, or otherwise touched. This is
    the "installed driver folders" catalog (what's on disk / usable), distinct
    from GET /drivers above (which lists currently *registered* driver
    processes, i.e. modules already in the active config).
    """
    from runtime_paths import resolve_active_config_path

    modules = []
    try:
        path = resolve_active_config_path()
        if path is not None:
            with open(path, "r", encoding="utf-8-sig") as f:
                data = json.load(f)
            modules = data.get("Modules", []) if isinstance(data, dict) else []
    except Exception as e:
        logging.warning(f"driver-catalog: failed to read active config: {e}")

    return {"drivers": driver_manager.get_driver_catalog(modules)}


@app.get("/drivers/{driver_id}/stop")
def stop_driver(driver_id: str):
    try:
        driver_manager.stop(driver_id)
        return {"result": "stopped"}
    except KeyError:
        raise HTTPException(status_code=404, detail="driver not found")
    except RuntimeError as e:
        raise HTTPException(status_code=409, detail=str(e))
    except Exception as e:
        logging.exception("Control action error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/drivers/{driver_id}/start")
def start_driver(driver_id: str):
    try:
        p = driver_manager.start(driver_id)
        return {"result": "started", "pid": getattr(p, "pid", None)}
    except KeyError:
        raise HTTPException(status_code=404, detail="driver not found")
    except RuntimeError as e:
        raise HTTPException(status_code=409, detail=str(e))
    except Exception as e:
        logging.exception("Control action error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/drivers/{driver_id}/restart")
def restart_driver(driver_id: str):
    try:
        p = driver_manager.restart(driver_id)
        return {"result": "restarted", "pid": getattr(p, "pid", None)}
    except KeyError:
        raise HTTPException(status_code=404, detail="driver not found")
    except Exception as e:
        logging.exception("Control action error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


def _resolve_target_config_path(config_filename: str | None):
    """Resolve which config file a module/channel-mutation endpoint should target.

    None (the default - every pre-existing caller, i.e. the Strumenti page, never
    passes this) means "the active config", preserving prior behavior exactly.
    A filename targets one specific file: the active one if its name matches,
    otherwise a file in the samples library - this is what lets the
    Configurazioni page add/edit instruments on a config that isn't currently
    running (see docs/*/architecture.md's config-management section).

    Returns (path, is_active) - is_active tells the caller whether it's safe to
    sync a live driver's in-memory config / register a new driver, since
    driver_manager's registry only ever reflects the config that is actually
    active; doing so for an arbitrary samples/ file could collide with an
    unrelated module_id/channel_id already used by the real active config.
    """
    from runtime_paths import resolve_active_config_path, resolve_config_samples_dir

    active_path = resolve_active_config_path()
    if config_filename is None:
        return active_path, active_path is not None
    if active_path is not None and active_path.name == config_filename:
        return active_path, True
    candidate = resolve_config_samples_dir() / config_filename
    return (candidate if candidate.is_file() else None), False


@app.post("/modules/{module_id}/channels/{channel_id}")
def save_channel(module_id: int, channel_id: int, patch: dict, config: str | None = None):
    """Patch a single channel's config fields and persist them to a config file.

    The service remains the sole writer of the config file (Electron never writes to
    the service folder): Electron calls this endpoint with the fields to change, we
    merge them into the on-disk JSON and, if the owning driver is currently running,
    into its in-memory module_config too (so a later /restart picks up the new values).

    `config` (query param, optional) targets a specific filename instead of the
    active config - see _resolve_target_config_path.
    """
    try:
        path, is_active = _resolve_target_config_path(config)
        if path is None:
            raise HTTPException(status_code=404, detail="config file not found")

        with open(path, "r", encoding="utf-8-sig") as f:
            data = json.load(f)

        module = next((m for m in data.get("Modules", []) if m.get("ID") == module_id), None)
        if module is None:
            raise HTTPException(status_code=404, detail="module not found")

        channel = next((c for c in module.get("Channels", []) if c.get("ID") == channel_id), None)
        if channel is None:
            raise HTTPException(status_code=404, detail="channel not found")

        channel.update(patch)

        tmp_path = str(path) + ".tmp"
        with open(tmp_path, "w", encoding="utf-8-sig") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, path)

        if is_active:
            driver_manager.update_module_config_channel(module_id, channel_id, patch)

        return {"success": True, "channel": channel}
    except HTTPException:
        raise
    except Exception as e:
        logging.exception("Save channel error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/modules/{module_id}")
def save_module(module_id: int, patch: dict, config: str | None = None):
    """Patch a module's own config fields (not its channels) and persist them to a config file.

    Same read-merge-write flow as save_channel: the service is the sole writer of the
    config file, and the running driver's in-memory module_config is updated too (only
    when targeting the active config - see _resolve_target_config_path) so a later
    /restart picks up the new values.

    If this patch (or an earlier one) turns the module's own Active flag on and it has
    no registry entry yet - e.g. it was Active: false at service startup, so
    service_master's startup loop skipped it entirely (see service_master.py), or it
    was disabled after being registered and is now being re-enabled - register it here,
    exactly like create_module does for a brand-new module. This only *registers*
    (alive=false placeholder), it doesn't launch anything; the Electron "abilita
    strumento" switch already follows this save with a driverAction(restart), and
    DriverManager.restart() launches the process itself when info["process"] is None
    (see driver_manager.py), so no separate launch call is needed here. Skipped if
    already registered - register_driver() unconditionally overwrites the registry
    entry (including resetting "process" to None), which would orphan an
    already-running process reference.
    """
    try:
        path, is_active = _resolve_target_config_path(config)
        if path is None:
            raise HTTPException(status_code=404, detail="config file not found")

        with open(path, "r", encoding="utf-8-sig") as f:
            data = json.load(f)

        module = next((m for m in data.get("Modules", []) if m.get("ID") == module_id), None)
        if module is None:
            raise HTTPException(status_code=404, detail="module not found")

        patch.pop("Channels", None)
        module.update(patch)

        tmp_path = str(path) + ".tmp"
        with open(tmp_path, "w", encoding="utf-8-sig") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, path)

        if is_active:
            driver_manager.update_module_config(module_id, patch)

            if module.get("Active") is not False and not driver_manager.is_registered(module_id):
                from service_init import LOG_DIR

                for driver_file, instrument_id in driver_manager.resolve_driver_for_module(module):
                    driver_log = LOG_DIR / f"driver_{instrument_id}.log"
                    driver_manager.register_driver(instrument_id, driver_file,
                                                     module_config=module, driver_log=str(driver_log))

        return {"success": True, "module": module}
    except HTTPException:
        raise
    except Exception as e:
        logging.exception("Save module error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/modules")
def create_module(module: dict, config: str | None = None):
    """Create a brand new module (instrument) and append it to a config file.

    Unlike save_module/save_channel (patch an existing entry), this appends a full
    module object built client-side by Electron (opasConfigManager.getNewInstrumentDraft
    merges drivers_dict.json's FullConfig template with the chosen type's DefaultConfig).
    The server remains the sole writer and guarantees the three globally-unique fields:
    it recomputes the module's own ID and, within it, each channel's ID and DatabaseId
    (client-supplied values for these three are ignored/overwritten, unique only within
    this file). Every other field, including each channel's Position, is written
    exactly as sent by the client.

    `config` (query param, optional) targets a specific filename instead of the
    active config - see _resolve_target_config_path. Driver registration below only
    happens when targeting the active config: a module added to a samples/ file isn't
    running anything, so there is nothing to register yet (it becomes registrable the
    normal way - a full restart, or this same call repeated after the file is
    activated - once /configs/{filename}/activate makes it the active file).

    When targeting the active config, the driver is registered (not launched) here,
    using the same ModuleType -> drivers_dict.json -> driver.py resolution
    service_master.py's startup sequence applies to every module (see
    driver_manager.resolve_driver_for_module). Registering makes it show up in
    GET /drivers with alive=false, i.e. controllable from the UI's start icon,
    without launching the process and without touching any other already-running
    driver -- a full service restart is no longer required just to make a newly
    created instrument startable. Skipped if the module is inactive (Active: false)
    or if its ModuleType can't be resolved to a driver, mirroring what a full restart
    would do for the same module.
    """
    try:
        path, is_active = _resolve_target_config_path(config)
        if path is None:
            raise HTTPException(status_code=404, detail="config file not found")

        with open(path, "r", encoding="utf-8-sig") as f:
            data = json.load(f)

        modules = data.setdefault("Modules", [])

        new_id = max((m.get("ID", 0) for m in modules), default=0) + 1
        next_db_id = max(
            (c.get("DatabaseId", 0) for m in modules for c in m.get("Channels", [])),
            default=0,
        ) + 1

        module["ID"] = new_id
        channels = module.get("Channels", [])
        for i, ch in enumerate(channels):
            ch["ID"] = i + 1
            ch["DatabaseId"] = next_db_id + i
        module["Channels"] = channels

        modules.append(module)

        tmp_path = str(path) + ".tmp"
        with open(tmp_path, "w", encoding="utf-8-sig") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, path)

        if is_active and module.get("Active") is not False:
            # service_init (unlike service_master) is never run as `__main__`, so
            # it has a single consistent module identity everywhere it's imported
            # - see driver_manager.DriverManager.set_driver_resolution_context for
            # why the equivalent isn't true of service_master.
            from service_init import LOG_DIR

            for driver_file, instrument_id in driver_manager.resolve_driver_for_module(module):
                driver_log = LOG_DIR / f"driver_{instrument_id}.log"
                driver_manager.register_driver(instrument_id, driver_file,
                                                 module_config=module, driver_log=str(driver_log))

        return {"success": True, "module": module}
    except HTTPException:
        raise
    except Exception as e:
        logging.exception("Create module error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/configs/{filename}/station")
def save_station_fields(filename: str, patch: dict):
    """Patch a config's station-level fields (Name, StationLocation,
    DataFileHeader, StationLatitude/Longitude/Altitude, ...) - never its
    Modules list (stripped from the patch, same guard as save_module for
    Channels). Unlike the module/channel endpoints, `filename` is always
    required here: this endpoint is new, so there is no pre-existing caller
    that assumes "active config" implicitly the way the Strumenti page does
    for /modules - the Configurazioni page always knows which file it's
    editing.

    No driver in-memory sync happens here (unlike save_module/save_channel):
    station-level fields aren't part of any driver's own MODULE_CONFIG env
    var, so there is nothing on a running driver to keep in sync.
    """
    from runtime_paths import resolve_active_config_path, resolve_config_samples_dir
    from datetime import datetime

    if os.path.basename(filename) != filename:
        raise HTTPException(status_code=400, detail="invalid filename")

    try:
        active_path = resolve_active_config_path()
        if active_path is not None and active_path.name == filename:
            path = active_path
        else:
            path = resolve_config_samples_dir() / filename
            if not path.is_file():
                raise HTTPException(status_code=404, detail="config file not found")

        with open(path, "r", encoding="utf-8-sig") as f:
            data = json.load(f)

        patch = dict(patch)
        patch.pop("Modules", None)
        data.update(patch)
        data["ConfigLastUpdate"] = datetime.now().astimezone().isoformat()

        tmp_path = str(path) + ".tmp"
        with open(tmp_path, "w", encoding="utf-8-sig") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, path)

        return {"success": True, "data": data}
    except HTTPException:
        raise
    except Exception as e:
        logging.exception("Save station fields error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/configs")
def create_config(body: dict):
    """Create a new config file in the samples library (never directly active -
    see /configs/{filename}/activate for that).

    Three modes, chosen by body["mode"]:
      - "duplicate": copy body["sourceFilename"] (the active file, or one already
        in the samples library), then apply body.get("fields", {}) as a shallow
        overlay of station-level keys (e.g. Name/StationLocation/DataFileHeader).
      - "blank": start from {"Modules": []} and apply body["fields"] on top.
      - "import": body["content"] is a full config dict already read client-side
        (e.g. from a file picker) and saved as-is except for the filename.

    body["filename"] is always required, must be a bare name (no path separators -
    rejects path traversal outside the samples directory) ending in ".json", and
    must not collide with an existing file (active or in samples/).
    """
    from runtime_paths import resolve_active_config_path, resolve_config_samples_dir
    from datetime import datetime

    filename = body.get("filename")
    if not filename or os.path.basename(filename) != filename or not filename.lower().endswith(".json"):
        raise HTTPException(status_code=400, detail="invalid filename")

    mode = body.get("mode")
    if mode not in ("duplicate", "blank", "import"):
        raise HTTPException(status_code=400, detail="mode must be 'duplicate', 'blank', or 'import'")

    try:
        active_path = resolve_active_config_path()
        samples_dir = resolve_config_samples_dir()
        samples_dir.mkdir(parents=True, exist_ok=True)

        target_path = samples_dir / filename
        if target_path.exists() or (active_path is not None and active_path.name == filename):
            raise HTTPException(status_code=409, detail="a config with this filename already exists")

        if mode == "import":
            content = body.get("content")
            if not isinstance(content, dict):
                raise HTTPException(status_code=400, detail="content must be a JSON object")
            data = content
        else:
            if mode == "duplicate":
                source_filename = body.get("sourceFilename")
                if not source_filename:
                    raise HTTPException(status_code=400, detail="sourceFilename is required for mode=duplicate")
                if active_path is not None and active_path.name == source_filename:
                    source_path = active_path
                else:
                    source_path = samples_dir / source_filename
                if not source_path.is_file():
                    raise HTTPException(status_code=404, detail="source config not found")
                with open(source_path, "r", encoding="utf-8-sig") as f:
                    data = json.load(f)
            else:  # blank
                data = {"Modules": []}

            fields = body.get("fields")
            if isinstance(fields, dict):
                data.update(fields)

        data["ConfigLastUpdate"] = datetime.now().astimezone().isoformat()

        tmp_path = str(target_path) + ".tmp"
        with open(tmp_path, "w", encoding="utf-8-sig") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, target_path)

        return {"success": True, "filename": filename}
    except HTTPException:
        raise
    except Exception as e:
        logging.exception("Create config error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/configs/{filename}/activate")
def activate_config(filename: str):
    """Make `filename` (currently in the samples library) the active config.

    Swaps the two locations: whatever is currently in active/ moves into the
    samples library (keeping its own filename - active/ always holds exactly
    the one live config, everything else lives in samples/, see
    docs/*/architecture.md), and `filename` moves from samples/ into active/.

    This only changes which file the *next* full restart (POST /service/restart)
    or newly launched driver reads - already-running drivers keep whatever
    config they were launched with (same "requires restart to take effect"
    precedent as save_module/save_channel above). The Electron UI is expected
    to ask the user whether to restart now.
    """
    from runtime_paths import resolve_active_config_path, resolve_config_active_dir, resolve_config_samples_dir

    if os.path.basename(filename) != filename:
        raise HTTPException(status_code=400, detail="invalid filename")

    try:
        samples_dir = resolve_config_samples_dir()
        source_path = samples_dir / filename
        if not source_path.is_file():
            raise HTTPException(status_code=404, detail="config not found in samples library")

        active_dir = resolve_config_active_dir()
        active_dir.mkdir(parents=True, exist_ok=True)
        current_active = resolve_active_config_path()

        if current_active is not None:
            samples_dir.mkdir(parents=True, exist_ok=True)
            os.replace(current_active, samples_dir / current_active.name)

        os.replace(source_path, active_dir / filename)

        return {"success": True, "activeFilename": filename}
    except HTTPException:
        raise
    except Exception as e:
        logging.exception("Activate config error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


_VALID_LOG_LEVELS = {"DEBUG", "INFO", "WARNING", "ERROR"}


@app.get("/logging")
def get_log_level():
    """Read the station-level default log level from the active config file.

    Default "INFO" when absent. This is only the *default* - an individual
    module can override it (Module["LogLevel"] in the active config, edited
    via POST /modules/{module_id} like any other module field), resolved
    against this default by driver_manager.launch_driver() at the moment
    that module's driver process actually starts.
    """
    from runtime_paths import resolve_active_config_path

    try:
        path = resolve_active_config_path()
        if path is None:
            return {"level": "INFO"}
        with open(path, "r", encoding="utf-8-sig") as f:
            data = json.load(f)
        return {"level": data.get("LogLevel", "INFO")}
    except Exception as e:
        logging.exception("Get log level error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/logging")
def set_log_level_endpoint(body: dict):
    """Persist the station-level default log level and apply it immediately
    to the service-master's own logs (service.log/web.log).

    This does NOT touch the driver registry: a module without its own
    LogLevel override picks up this new default on its own next restart
    (same as any other module-level config change,
    e.g. PollingInterval), resolved fresh by driver_manager.launch_driver()
    - nothing here needs to propagate to already-running drivers for that to
    work correctly.
    """
    from service_init import set_log_level as apply_log_level
    from runtime_paths import resolve_active_config_path

    level = str(body.get("level", "")).upper()
    if level not in _VALID_LOG_LEVELS:
        raise HTTPException(status_code=400, detail=f"invalid level: {level!r}")

    try:
        path = resolve_active_config_path()
        if path is None:
            raise HTTPException(status_code=404, detail="config file not found")

        with open(path, "r", encoding="utf-8-sig") as f:
            data = json.load(f)

        data["LogLevel"] = level

        tmp_path = str(path) + ".tmp"
        with open(tmp_path, "w", encoding="utf-8-sig") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, path)

        apply_log_level(level)

        return {"success": True, "level": level}
    except HTTPException:
        raise
    except Exception as e:
        logging.exception("Set log level error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/service/restart")
def restart_service():
    """Restart the whole master process (not just one driver).

    Stops every driver/broker cleanly, then re-execs the master process in
    place (same PID) so it comes back up with a fresh state.

    request_restart is fetched from sys.modules["__main__"] rather than via
    `from service_master import request_restart`: service_master.py is always
    launched as __main__ (both from source and in the PyInstaller build, see
    service_master.spec), and a plain `import`/`from ... import` targeting the
    module name "service_master" makes Python re-execute the entire file from
    scratch as a *second*, distinct module object - one whose main() never
    ran, so request_restart's closure over driver_manager/shared_serial_ports/
    output_broker_manager (module-level globals only assigned inside main())
    reads back as None there. Calling that copy's request_restart() then has
    _stop_drivers_and_brokers() raise AttributeError on every stop attempt
    (caught and logged, not fatal) - every driver/broker process survives the
    "restart" and keeps holding its own inherited duplicate of the singleton
    lock socket, so the freshly exec'd process fails to reacquire port 47990
    and immediately exits with "un'altra istanza è già in esecuzione".
    sys.modules["__main__"] is the one already-running module instance whose
    main() actually populated that state, so this sidesteps the reimport (and
    the AttributeError/leaked-children chain) entirely.
    """
    request_restart = sys.modules["__main__"].request_restart

    try:
        request_restart()
        return {"result": "restarting"}
    except Exception as e:
        logging.exception("Restart service error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


def _configure_uvicorn_logging():
    """Configure uvicorn loggers to use the web.log file.
    
    This ensures uvicorn writes to our rotated web.log instead of just stdout.
    Must be called before uvicorn.Server is created.
    """
    try:
        from service_init import WEB_LOG
        from pathlib import Path
        
        # Ensure WEB_LOG directory exists
        Path(WEB_LOG).parent.mkdir(parents=True, exist_ok=True)
        
        # Configure each uvicorn logger
        for logger_name in ["uvicorn", "uvicorn.error", "uvicorn.access", "uvicorn.asgi"]:
            logger = logging.getLogger(logger_name)
            logger.setLevel(logging.ERROR if logger_name == "uvicorn.error" else logging.INFO)
            logger.propagate = False
            
            # Remove any existing handlers to avoid duplicates. Explicitly close()
            # each one first: service_init.configure()'s dictConfig already attached
            # a RotatingFileHandler on the same WEB_LOG path to these loggers, and
            # just dropping the reference (logger.handlers = []) leaves that handler's
            # OS-level file handle open until garbage collection gets around to it -
            # on Windows, two live handles on the same file is exactly the kind of
            # thing that turns a later rollover (os.rename) into a PermissionError
            # (WinError 32, "file in use by another process").
            for old_handler in logger.handlers:
                try:
                    old_handler.close()
                except Exception:
                    pass
            logger.handlers = []
            
            # Add rotating file handler
            handler = logging.handlers.RotatingFileHandler(
                str(WEB_LOG),
                maxBytes=10 * 1024 * 1024,
                backupCount=5,
                encoding="utf-8"
            )
            formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            
    except Exception as e:
        logging.error(f"Failed to configure uvicorn logging: {e}")


def start_control_server(host: str = "127.0.0.1", port: int = 8080):
    """Start uvicorn server in a background thread and return the server thread object.

    Requires `uvicorn` and `fastapi` to be installed in the environment.
    """
    # Configure uvicorn logging before creating the server
    _configure_uvicorn_logging()

    # log_config=None is required, not just an optimization: uvicorn.Config.__init__
    # calls self.configure_logging() internally (uvicorn/config.py), which - unless
    # log_config is explicitly None - runs logging.config.dictConfig() on uvicorn's
    # own default LOGGING_CONFIG (console-only StreamHandlers) for the exact same
    # "uvicorn"/"uvicorn.error"/"uvicorn.access" loggers _configure_uvicorn_logging()
    # just attached a RotatingFileHandler to, one line above - silently discarding it
    # before the server ever starts. That's why web.log stayed empty while the console
    # kept getting output: our file handler never survived past this constructor call.
    config = uvicorn.Config(app, host=host, port=port, log_level="info", access_log=True, log_config=None)
    server = uvicorn.Server(config)

    t = threading.Thread(target=server.run, daemon=True)
    t.start()
    logging.info(f"Control server (FastAPI/uvicorn) started on {host}:{port}")
    return server

