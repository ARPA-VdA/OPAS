import os
import sys
import logging
import logging.config
import shutil
from pathlib import Path

# Bootstrap: calculate libs directory path and add to sys.path BEFORE importing RuntimePaths
# Use inline logic (identical to compute_runtime_root in runtime_paths.py)
try:
    if getattr(sys, 'frozen', False):
        # PyInstaller executable - get the directory of the executable
        _bootstrap_root = Path(sys.executable).resolve().parent
        logging.debug(f"[service_init] Bootstrap: PyInstaller mode, exe dir: {_bootstrap_root}")
    else:
        # Python script: This file is either:
        # - src/core/service_init.py when running service_master directly
        # - src/opas_dl_commons/libs/runtime_paths.py when called from there
        # We need to find opas_dl_commons/libs to add to sys.path
        current_file = Path(__file__).resolve()
        logging.debug(f"[service_init] Bootstrap: Python script mode, this file: {current_file}")
        
        # Check if we're in opas_dl_commons/libs/ or src/core/
        if "opas_dl_commons/libs" in str(current_file) or "opas_dl_commons\\libs" in str(current_file):
            # We're in opas_dl_commons/libs - runtime_root is 2 levels up
            _bootstrap_root = current_file.parent.parent.parent  # libs -> opas_dl_commons -> src
            logging.debug(f"[service_init] Bootstrap: Called from opas_dl_commons/libs, root: {_bootstrap_root}")
        elif "core" in str(current_file) or "core" in str(current_file):
            # We're in src/core - runtime_root is parent (src/)
            _bootstrap_root = current_file.parent.parent  # core -> src
            logging.debug(f"[service_init] Bootstrap: Called from core/, root: {_bootstrap_root}")
        else:
            # Unknown location, default to parent
            _bootstrap_root = current_file.parent.parent
            logging.debug(f"[service_init] Bootstrap: Unknown location, defaulting to: {_bootstrap_root}")
    
    _libs_dir = _bootstrap_root / "opas_dl_commons" / "libs"
    logging.debug(f"[service_init] Bootstrap: libs_dir calculated as: {_libs_dir}")
    if _libs_dir.exists() and str(_libs_dir) not in sys.path:
        sys.path.insert(0, str(_libs_dir))
        logging.debug(f"[service_init] Bootstrap: Added {_libs_dir} to sys.path")
    elif not _libs_dir.exists():
        logging.warning(f"[service_init] Bootstrap: libs_dir not found at {_libs_dir}")
except Exception as e:
    logging.warning(f"[service_init] Bootstrap error: {e}")
    pass

# Now we can safely import RuntimePaths (and compute_runtime_root)
try:
    from runtime_paths import RuntimePaths, compute_runtime_root
    logging.debug(f"[service_init] Imported RuntimePaths and compute_runtime_root")
    _base_dir = compute_runtime_root()  # Get the actual base_dir using robust logic
    logging.info(f"[service_init] compute_runtime_root returned: {_base_dir}")
    _runtime_paths = RuntimePaths(_base_dir)
    logging.info(f"[service_init] RuntimePaths initialized with base_dir: {_base_dir}")
except ImportError as e:
    # Fallback: if RuntimePaths is not available, use standalone logic
    logging.warning(f"[service_init] Failed to import RuntimePaths: {e}")
    _runtime_paths = None
    try:
        from runtime_paths import compute_runtime_root
        _base_dir = compute_runtime_root()
        logging.info(f"[service_init] Fallback compute_runtime_root returned: {_base_dir}")
    except ImportError:
        # Last resort: calculate locally
        logging.warning(f"[service_init] compute_runtime_root import failed, using local logic")
        if getattr(sys, 'frozen', False):
            _base_dir = Path(sys.executable).resolve().parent
        else:
            _base_dir = Path(__file__).resolve().parent.parent
        logging.info(f"[service_init] Local calculation returned base_dir: {_base_dir}")
except Exception as e:
    logging.exception(f"[service_init] Exception initializing RuntimePaths: {e}")
    _runtime_paths = None
    _base_dir = Path(__file__).resolve().parent.parent


# Initialize paths from RuntimePaths singleton (if available)
if _runtime_paths is not None:
    BASE_DIR = _runtime_paths.base_dir
    OPAS_COMMONS_DIR = _runtime_paths.opas_commons_dir
    CONFIG_ACTIVE_DIR = _runtime_paths.config_active_dir
    DRIVERS_DIR = _runtime_paths.drivers_dir
    SOURCE_DRIVERS_DIR = _runtime_paths.source_drivers_dir
    LIBS_DIR = _runtime_paths.libs_dir
    PYOUT_DIR = _runtime_paths.pyout_dir
    LOGS_DIR = _runtime_paths.logs_dir
    OUTPUT_DIR = _runtime_paths.output_dir
    LOG_DIR = LOGS_DIR
    GENERAL_LOG = _runtime_paths.general_log
    WEB_LOG = _runtime_paths.web_log
    
    logging.debug(f"[service_init] Exported paths from RuntimePaths:")
    logging.debug(f"[service_init]   BASE_DIR = {BASE_DIR}")
    logging.debug(f"[service_init]   OPAS_COMMONS_DIR = {OPAS_COMMONS_DIR}")
    logging.debug(f"[service_init]   CONFIG_ACTIVE_DIR = {CONFIG_ACTIVE_DIR}")
    logging.debug(f"[service_init]   DRIVERS_DIR = {DRIVERS_DIR}")
    logging.debug(f"[service_init]   LOGS_DIR = {LOGS_DIR}")
    logging.debug(f"[service_init]   OUTPUT_DIR = {OUTPUT_DIR}")
else:
    # Fallback: compute paths standalone
    BASE_DIR = _base_dir
    OPAS_COMMONS_DIR = BASE_DIR / "opas_dl_commons" if not (BASE_DIR / "opas_dl_commons").exists() and (BASE_DIR.parent / "opas_dl_commons").exists() else BASE_DIR / "opas_dl_commons" if (BASE_DIR / "opas_dl_commons").exists() else BASE_DIR.parent / "opas_dl_commons"
    CONFIG_ACTIVE_DIR = OPAS_COMMONS_DIR / "config" / "active"
    DRIVERS_DIR = OPAS_COMMONS_DIR / "drivers"
    SOURCE_DRIVERS_DIR = OPAS_COMMONS_DIR / "drivers"
    LIBS_DIR = OPAS_COMMONS_DIR / "libs"
    PYOUT_DIR = BASE_DIR / "py_out"
    LOGS_DIR = PYOUT_DIR / "logs"
    OUTPUT_DIR = PYOUT_DIR / "output"
    LOG_DIR = LOGS_DIR
    GENERAL_LOG = LOGS_DIR / "service.log"
    WEB_LOG = LOGS_DIR / "web.log"
    
    logging.warning(f"[service_init] Using fallback paths (RuntimePaths not available)")
    logging.debug(f"[service_init]   BASE_DIR = {BASE_DIR}")
    logging.debug(f"[service_init]   OPAS_COMMONS_DIR = {OPAS_COMMONS_DIR}")
    logging.debug(f"[service_init]   CONFIG_ACTIVE_DIR = {CONFIG_ACTIVE_DIR}")
    logging.debug(f"[service_init]   DRIVERS_DIR = {DRIVERS_DIR}")
    logging.debug(f"[service_init]   LOGS_DIR = {LOGS_DIR}")
    logging.debug(f"[service_init]   OUTPUT_DIR = {OUTPUT_DIR}")


LOGGING_CONFIG = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "standard": {"format": "%(asctime)s [%(levelname)s] %(name)s: %(message)s"},
    },
    "handlers": {
        "general_rotating": {
            "class": "logging.handlers.RotatingFileHandler",
            "level": "INFO",
            "formatter": "standard",
            "filename": str(GENERAL_LOG),
            "maxBytes": 10 * 1024 * 1024,
            "backupCount": 5,
            "encoding": "utf-8",
        },
        "web_rotating": {
            "class": "logging.handlers.RotatingFileHandler",
            "level": "INFO",
            "formatter": "standard",
            "filename": str(WEB_LOG),
            "maxBytes": 10 * 1024 * 1024,
            "backupCount": 5,
            "encoding": "utf-8",
        },
        "web_console": {
            "class": "logging.StreamHandler",
            "level": "INFO",
            "formatter": "standard",
        },
        "console": {"class": "logging.StreamHandler", "level": "INFO", "formatter": "standard"},
    },
    "root": {"handlers": ["general_rotating", "console"], "level": "INFO"},
    "loggers": {
        "service_master": {"handlers": ["general_rotating"], "level": "INFO", "propagate": False},
        "uvicorn": {"handlers": ["web_rotating", "web_console"], "level": "INFO", "propagate": False},
        "uvicorn.error": {"handlers": ["web_rotating", "web_console"], "level": "ERROR", "propagate": False},
        "uvicorn.access": {"handlers": ["web_rotating", "web_console"], "level": "INFO", "propagate": False},
        "uvicorn.asgi": {"handlers": ["web_rotating", "web_console"], "level": "INFO", "propagate": False},
    },
}



def set_log_level(level: str) -> bool:
    """Adjust the level of every logger/handler already configured by
    configure() (dictConfig), in place - safe to call any time after
    configure() has run, including while the service is already up.

    Deliberately does NOT call logging.config.dictConfig() again: that would
    recreate the RotatingFileHandlers, reopening (and, per configure()'s own
    setup, truncating) GENERAL_LOG/WEB_LOG while whatever already holds them
    open keeps its old handle - the same WinError 32 configure() itself
    guards against (see CLAUDE.md's Python coding rules). setLevel() on
    already-constructed loggers/handlers carries none of that risk.

    Returns False (and logs a warning) if `level` isn't a valid logging
    level name; True otherwise.
    """
    numeric_level = getattr(logging, level.upper(), None)
    if not isinstance(numeric_level, int):
        logging.warning(f"[service_init] Unknown log level '{level}', ignoring")
        return False

    root = logging.getLogger()
    root.setLevel(numeric_level)
    for handler in root.handlers:
        handler.setLevel(numeric_level)

    for name in LOGGING_CONFIG["loggers"]:
        logger = logging.getLogger(name)
        logger.setLevel(numeric_level)
        for handler in logger.handlers:
            handler.setLevel(numeric_level)

    logging.info(f"[service_init] Log level set to {level.upper()}")
    return True


def configure():
    """Create runtime directories, configure logging and clear output dir.

    Call this early in `service_master` before importing modules that log.

    OUTPUT_DIR (the legacy per-driver output/ folder - see driver-contract.md
    §5.2) is intentionally NOT created here: no driver in this codebase writes
    to it anymore (ADAM_4013/ADAM_4052 were the last two, now OPAS NEO-only),
    so pre-creating it unconditionally on every startup just left an empty,
    unused folder behind. Any driver that still relies on it (in-tree or
    third-party) creates it itself on first write, same as every other
    driver-owned output path.
    """
    logging.debug(f"[service_init] configure() called")
    logging.debug(f"[service_init] Creating runtime directories:")
    logging.debug(f"[service_init]   DRIVERS_DIR: {DRIVERS_DIR}")
    logging.debug(f"[service_init]   LOGS_DIR: {LOGS_DIR}")

    try:
        os.makedirs(DRIVERS_DIR, exist_ok=True)
        os.makedirs(LOGS_DIR, exist_ok=True)
        logging.debug(f"[service_init] Runtime directories created successfully")
    except Exception as e:
        logging.warning(f"[service_init] Error creating directories: {e}")
        pass

    # prefer local libs if present (already in sys.path from bootstrap, but re-add to be sure)
    try:
        if os.path.exists(LIBS_DIR):
            if str(LIBS_DIR) not in sys.path:
                sys.path.insert(0, str(LIBS_DIR))
                logging.debug(f"[service_init] Added LIBS_DIR to sys.path: {LIBS_DIR}")
    except Exception as e:
        logging.warning(f"[service_init] Error managing LIBS_DIR: {e}")
        pass

    # Ensure log files and their parent directories exist before applying dictConfig
    try:
        GENERAL_LOG.parent.mkdir(parents=True, exist_ok=True)
        logging.debug(f"[service_init] Created parent dir for GENERAL_LOG: {GENERAL_LOG.parent}")
        if GENERAL_LOG.exists():
            GENERAL_LOG.unlink()
            logging.debug(f"[service_init] Removed existing GENERAL_LOG file")
        # Create an empty general log file (will be opened immediately by handler)
        GENERAL_LOG.touch()
        logging.debug(f"[service_init] Created GENERAL_LOG: {GENERAL_LOG}")
    except Exception as e:
        logging.warning(f"[service_init] Error setting up GENERAL_LOG: {e}")
        pass
    
    try:
        WEB_LOG.parent.mkdir(parents=True, exist_ok=True)
        logging.debug(f"[service_init] Created parent dir for WEB_LOG: {WEB_LOG.parent}")
        if WEB_LOG.exists():
            WEB_LOG.unlink()
            logging.debug(f"[service_init] Removed existing WEB_LOG file")
        # Create an empty web log file (will be opened immediately by handler)
        WEB_LOG.touch()
        logging.debug(f"[service_init] Created WEB_LOG: {WEB_LOG}")
    except Exception as e:
        logging.warning(f"[service_init] Error setting up WEB_LOG: {e}")
        pass

    try:
        logging.config.dictConfig(LOGGING_CONFIG)
        logging.info(f"[service_init] Logging configured via dictConfig")
    except Exception as e:
        logging.warning(f"[service_init] Error applying dictConfig: {e}")
        # fallback to a basic config
        try:
            logging.basicConfig(level=logging.INFO)
            logging.info(f"[service_init] Logging configured with basicConfig")
        except Exception:
            pass

    # No pre-wipe: Electron polls the output directory continuously.
    # Wiping here creates a race window where Electron reads nothing mid-restart.
    # Drivers always overwrite their own output files on each polling cycle.


__all__ = [
    "configure",
    "set_log_level",
    "BASE_DIR",
    "OPAS_COMMONS_DIR",
    "CONFIG_ACTIVE_DIR",
    "DRIVERS_DIR",
    "SOURCE_DRIVERS_DIR",
    "LIBS_DIR",
    "PYOUT_DIR",
    "LOGS_DIR",
    "OUTPUT_DIR",
    "LOG_DIR",
    "GENERAL_LOG",
    "WEB_LOG",
    "LOGGING_CONFIG",
]

