import os
import json
import re
import sys
import signal
import time
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path


def get_runtime_root() -> Path:
    """
    Return the actual runtime root directory:
    - the script folder when running with Python
    - the executable's folder when packaged with PyInstaller (onedir)
    - the executable's folder when packaged with PyInstaller (onefile)
    Works correctly in child processes as well.
    """
    if getattr(sys, 'frozen', False):
        # launch PyInstaller - return exe's directory
        return Path(sys.executable).resolve().parent
    else:
        # launch Python
        return Path(__file__).resolve().parent


def load_service_paths(base_dir=None):
    """Load all service paths from folder_config.json.
    
    This function is shared between service_master.py and drivers.
    It reads the centralized configuration and computes absolute paths.
    
    Args:
        base_dir: optional service root directory (defaults to get_runtime_root())
    
    Returns:
        dict with Path objects for all configured directories:
        {
            'BASE_DIR': Path(...),
            'OPAS_COMMONS_DIR': Path(...),
            'DRIVERS_DIR': Path(...),
            'SOURCE_DRIVERS_DIR': Path(...),
            'CONFIG_ACTIVE_DIR': Path(...),
            'LIBS_DIR': Path(...),
            'PYOUT_DIR': Path(...),
            'LOGS_DIR': Path(...),
            'OUTPUT_DIR': Path(...),
            'GENERAL_LOG': Path(...),
            'WEB_LOG': Path(...),
        }
    
    Raises:
        FileNotFoundError: if folder_config.json is not found
        json.JSONDecodeError: if folder_config.json contains invalid JSON
    """
    if base_dir is None:
        base_dir = get_runtime_root()
    else:
        base_dir = Path(base_dir).resolve()
    
    config_file = base_dir / "folder_config.json"
    if not config_file.exists():
        raise FileNotFoundError(f"folder_config.json not found at {config_file}")
    
    try:
        with open(config_file, "r", encoding="utf-8") as f:
            relative_config = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"folder_config.json is not valid JSON: {e}")
    
    # Convert relative paths to absolute paths
    paths = {"BASE_DIR": base_dir}
    for key, relative_path in relative_config.items():
        paths[key] = base_dir / relative_path
    
    return paths


# def make_output_filepath(base_dir, module_config=None, instrument_id=None):
#     """Return (output_dir, output_file) for a driver.

#     base_dir: directory of the driver.py file
#     module_config: dict or None (if None will try to read MODULE_CONFIG env var)
#     instrument_id: fallback identifier
#     """
#     # determine py_out root via helper (respects PY_OUT); default is three
#     # levels above driver base_dir (../../.. / py_out)
#     py_out_root = get_py_out_root(base_dir)

#     # output directory lives under py_out/output
#     output_dir = os.path.join(py_out_root, "output")

#     mc = module_config
#     if mc is None:
#         mc_raw = os.environ.get("MODULE_CONFIG")
#         if mc_raw:
#             try:
#                 mc = json.loads(mc_raw)
#             except Exception:
#                 mc = None

#     module_name = None
#     module_id = None
#     if isinstance(mc, dict):
#         module_name = mc.get("Name") or mc.get("name")
#         module_id = mc.get("ID") or mc.get("Id") or mc.get("id")

#     if not module_id:
#         module_id = instrument_id

#     if not module_name:
#         module_name = instrument_id

#     safe_name = re.sub(r"[^A-Za-z0-9_\-]", "_", str(module_name)).strip("_")
#     filename = f"{safe_name}_{module_id}.txt"
#     output_file = os.path.join(output_dir, filename)
#     return output_dir, output_file


def get_py_out_root(base_dir):
    """Return the py_out root directory for a given base_dir.

    Does not create directories; caller may create them.
    """
    env_out = os.environ.get("PY_OUT") or os.environ.get("OPAS_PY_OUT")
    if env_out:
        return os.path.abspath(env_out)
    # legacy-like behavior: place py_out three levels above the driver base_dir
    return os.path.normpath(os.path.join(base_dir, "..", "..", "..", "py_out"))


def get_instrument_id(fallback_base_dir=None):
    """Get the current driver's instrument ID from environment.
    
    Each driver process receives a unique INSTRUMENT_ID via os.environ set by driver_manager.
    This helper centralizes the retrieval logic.
    
    Args:
        fallback_base_dir: optional directory to infer name if INSTRUMENT_ID env not set
    
    Returns:
        Instrument ID string
    """
    instrument_id = os.environ.get("INSTRUMENT_ID")
    if instrument_id:
        return instrument_id
    # Fallback: try to infer from directory name
    if fallback_base_dir:
        return os.path.basename(fallback_base_dir)
    return "unknown_instrument"



# Graceful shutdown helpers for drivers
_RUNNING = True

def _signal_handler(signum, frame):
    global _RUNNING
    _RUNNING = False


def setup_signal_handlers():
    """Register signal handlers to allow drivers to exit cleanly.

    Call this early in driver processes.
    """
    try:
        signal.signal(signal.SIGINT, _signal_handler)
    except Exception:
        pass
    try:
        signal.signal(signal.SIGTERM, _signal_handler)
    except Exception:
        pass


def should_run():
    """Return True while the process should continue running."""
    return bool(_RUNNING)


def graceful_sleep(seconds):
    """Sleep in small increments while reacting to shutdown requests.

    This avoids blocking a long sleep and allows clean exit when a signal
    arrives (used instead of time.sleep in drivers).
    """
    interval = 0.1
    end = time.time() + float(seconds)
    while time.time() < end and should_run():
        time.sleep(min(interval, end - time.time()))


def configure_driver_logging(base_dir=None, instrument_id=None, driver_log_env="DRIVER_LOG", maxBytes=5 * 1024 * 1024, backupCount=3, level="INFO"):
    """Configure a per-driver rotating file logger.

    Priority for log file path:
    1. `DRIVER_LOG` environment variable (or name set by `driver_log_env`).
    2. `<py_out_root>/logs/<instrument_id>.log` where `py_out_root` is determined
       via `get_py_out_root(base_dir)`.

    This function replaces the root logger's handlers with a single
    `RotatingFileHandler` writing to the chosen file. Returns the path used.
    """
    try:
        log_path = os.environ.get(driver_log_env)
        if log_path:
            log_file = os.path.abspath(log_path)
            os.makedirs(os.path.dirname(log_file), exist_ok=True)
        else:
            py_out_root = get_py_out_root(base_dir or os.getcwd())
            log_dir = os.path.join(py_out_root, "logs")
            os.makedirs(log_dir, exist_ok=True)
            iid = instrument_id or os.environ.get("INSTRUMENT_ID") or os.path.basename(base_dir or os.getcwd())
            log_file = os.path.join(log_dir, f"{iid}.log")

        handler = RotatingFileHandler(log_file, maxBytes=maxBytes, backupCount=backupCount, encoding="utf-8")
        fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")
        handler.setFormatter(fmt)
        root = logging.getLogger()
        root.setLevel(getattr(logging, level.upper(), logging.INFO))
        # Replace handlers to avoid duplicates in frozen/embedded environments
        root.handlers = [handler]
        return log_file
    except Exception:
        # If anything fails, fall back to a basic console logger
        try:
            logging.basicConfig(level=getattr(logging, level.upper(), logging.INFO))
        except Exception:
            pass
        return None
