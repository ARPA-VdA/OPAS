import os
import sys
import json
import threading
import logging
from pathlib import Path


def compute_runtime_root(base_dir: Path = None) -> Path:
    """
    Detect runtime root without external dependencies.
    
    Returns the script/executable directory:
    - For PyInstaller: the exe's parent directory
    - For Python script: the parent directory (opas_dl_commons)
    
    This function is used by RuntimePaths singleton and can be imported
    standalone for bootstrap purposes.
    """
    if base_dir is not None:
        logging.debug(f"[RuntimePaths] compute_runtime_root: base_dir provided explicitly: {base_dir}")
        return Path(base_dir).resolve()
    
    if getattr(sys, 'frozen', False):
        # Running in PyInstaller executable - return the directory of the executable
        exe_dir = Path(sys.executable).resolve().parent
        logging.debug(f"[RuntimePaths] Running as PyInstaller executable. Exe dir: {exe_dir}")
        return exe_dir
    else:
        # Running as Python script
        # (assumes this file is in opas_dl_commons/libs/)
        current_file = Path(__file__).resolve()
        libs_dir = current_file.parent
        commons_dir = libs_dir.parent
        root_dir = commons_dir.parent
        logging.debug(f"[RuntimePaths] Running as Python script. Current file: {current_file}")
        logging.debug(f"[RuntimePaths]   -> libs_dir: {libs_dir}")
        logging.debug(f"[RuntimePaths]   -> commons_dir: {commons_dir}")
        logging.debug(f"[RuntimePaths]   -> runtime_root: {root_dir}")
        # Go up: libs/ -> opas_dl_commons/ -> root
        return root_dir


class RuntimePaths:
    """
    Singleton class to manage all runtime paths for the service.
    
    Handles detection of runtime root (Python script vs PyInstaller executable),
    loads folder configuration from folder_config.json, and provides access to all paths.
    Thread-safe singleton pattern.
    """
    
    _instance = None
    _lock = threading.Lock()
    
    def __new__(cls, base_dir: Path = None):
        """Singleton pattern: only one instance ever created."""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super(RuntimePaths, cls).__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self, base_dir: Path = None):
        """Initialize RuntimePaths singleton (only happens once)."""
        if self._initialized:
            logging.debug(f"[RuntimePaths] Already initialized, skipping re-initialization")
            return
        
        with self._lock:
            if self._initialized:
                return
            
            logging.debug(f"[RuntimePaths] Initializing RuntimePaths singleton...")
            # Compute runtime root using the standalone function
            self._base_dir = compute_runtime_root(base_dir)
            logging.info(f"[RuntimePaths] base_dir resolved to: {self._base_dir}")
            
            # Load folder configuration
            self._paths_dict = self._load_config()
            logging.debug(f"[RuntimePaths] Paths loaded from config: {list(self._paths_dict.keys())}")
            
            self._initialized = True
            logging.info(f"[RuntimePaths] Initialization complete")
    
    def _load_config(self) -> dict:
        """Load folder configuration from folder_config.json."""
        config_file = self._base_dir / "folder_config.json"
        logging.debug(f"[RuntimePaths] Looking for folder_config.json at: {config_file}")
        if not config_file.exists():
            logging.error(f"[RuntimePaths] folder_config.json not found at {config_file}")
            raise FileNotFoundError(f"folder_config.json not found at {config_file}")
        
        logging.debug(f"[RuntimePaths] Found folder_config.json, loading...")
        try:
            with open(config_file, "r", encoding="utf-8") as f:
                relative_config = json.load(f)
        except json.JSONDecodeError as e:
            logging.error(f"[RuntimePaths] JSON decode error: {e}")
            raise ValueError(f"folder_config.json is not valid JSON: {e}")
        
        logging.debug(f"[RuntimePaths] Loaded relative config keys: {list(relative_config.keys())}")

        # Convert relative paths to absolute paths
        paths = {"BASE_DIR": self._base_dir}
        for key, relative_path in relative_config.items():
            abs_path = self._base_dir / relative_path
            paths[key] = abs_path
            logging.debug(f"[RuntimePaths]   {key}: {relative_path} -> {abs_path}")
        
        logging.info(f"[RuntimePaths] Absolute paths resolved:")
        for key, path in paths.items():
            logging.info(f"[RuntimePaths]   {key} = {path}")
        
        return paths
    
    # ========== Public Properties ==========
    @property
    def base_dir(self) -> Path:
        logging.debug(f"[RuntimePaths] Accessing base_dir: {self._base_dir}")
        return self._base_dir
    
    @property
    def opas_commons_dir(self) -> Path:
        path = self._paths_dict["OPAS_COMMONS_DIR"]
        logging.debug(f"[RuntimePaths] Accessing opas_commons_dir: {path}")
        return path
    
    @property
    def drivers_dir(self) -> Path:
        path = self._paths_dict["DRIVERS_DIR"]
        logging.debug(f"[RuntimePaths] Accessing drivers_dir: {path}")
        return path
    
    @property
    def source_drivers_dir(self) -> Path:
        path = self._paths_dict["SOURCE_DRIVERS_DIR"]
        logging.debug(f"[RuntimePaths] Accessing source_drivers_dir: {path}")
        return path
    
    @property
    def config_active_dir(self) -> Path:
        path = self._paths_dict["CONFIG_ACTIVE_DIR"]
        logging.debug(f"[RuntimePaths] Accessing config_active_dir: {path}")
        return path
    
    @property
    def libs_dir(self) -> Path:
        path = self._paths_dict["LIBS_DIR"]
        logging.debug(f"[RuntimePaths] Accessing libs_dir: {path}")
        return path
    
    @property
    def pyout_dir(self) -> Path:
        path = self._paths_dict["PYOUT_DIR"]
        logging.debug(f"[RuntimePaths] Accessing pyout_dir: {path}")
        return path
    
    @property
    def logs_dir(self) -> Path:
        path = self._paths_dict["LOGS_DIR"]
        logging.debug(f"[RuntimePaths] Accessing logs_dir: {path}")
        return path
    
    @property
    def output_dir(self) -> Path:
        path = self._paths_dict["OUTPUT_DIR"]
        logging.debug(f"[RuntimePaths] Accessing output_dir: {path}")
        return path

    @property
    def opas_neo_data_dir(self) -> Path:
        path = self._paths_dict["OPAS_NEO_DATA_DIR"]
        logging.debug(f"[RuntimePaths] Accessing opas_neo_data_dir: {path}")
        return path

    @property
    def general_log(self) -> Path:
        path = self._paths_dict["GENERAL_LOG"]
        logging.debug(f"[RuntimePaths] Accessing general_log: {path}")
        return path
    
    @property
    def web_log(self) -> Path:
        path = self._paths_dict["WEB_LOG"]
        logging.debug(f"[RuntimePaths] Accessing web_log: {path}")
        return path
    
    def to_dict(self) -> dict:
        """Return all paths as a dictionary."""
        return dict(self._paths_dict)


def _first_json_in(dir_path: Path):
    """Return the first *.json file found directly inside dir_path, or None."""
    if dir_path.exists() and dir_path.is_dir():
        files = sorted(f for f in dir_path.iterdir() if f.suffix.lower() == ".json")
        return files[0] if files else None
    return None


def resolve_config_active_dir() -> Path:
    """Resolve the directory that holds (or should hold) the active config file.

    Same search order as resolve_active_config_path() below, but returns the
    directory itself rather than the JSON file inside it - needed by config-
    management endpoints (create/activate) that must know the directory even
    before any file exists there yet (e.g. right after a fresh install).
    """
    cfg_dir_env = os.environ.get("CONFIG_DIR") or os.environ.get("CONFIG_ACTIVE_DIR")
    if cfg_dir_env:
        return Path(cfg_dir_env)

    rp = RuntimePaths()
    candidates = [
        rp.config_active_dir,
        rp.base_dir / "config" / "active",
        rp.base_dir.parent / "config" / "active",
        rp.base_dir.parent.parent / "config" / "active",
        Path.cwd() / "config" / "active",
    ]
    for cand in candidates:
        if cand.is_dir():
            return cand
    return rp.config_active_dir


def resolve_config_samples_dir() -> Path:
    """Directory holding every config file that is NOT currently active.

    Sibling of resolve_config_active_dir()'s result: active/ always holds
    exactly the one live config, everything else (bundled templates, and any
    config the user duplicates/creates/imports) lives here - see
    docs/*/architecture.md's config-management section.
    """
    return resolve_config_active_dir().parent / "samples"


def resolve_active_config_path():
    """Resolve the path to the active OPAS JSON config file.

    Single source of truth for locating the active config, shared by
    service_master.load_active_config() and control_server's channel-save
    endpoint so both agree on the same file. Mirrors the search order that
    used to be embedded in load_active_config():
      1) CONFIG_PATH / CONFIG_FILE env var (explicit file)
      2) CONFIG_DIR / CONFIG_ACTIVE_DIR env var (explicit directory)
      3) default candidate directories relative to the runtime root
      4) PyInstaller MEIPASS fallback

    Returns a Path, or None if no config file can be found.
    """
    env_file = os.environ.get("CONFIG_PATH") or os.environ.get("CONFIG_FILE")
    if env_file:
        p = Path(env_file)
        return p if p.exists() else None

    cfg_dir_env = os.environ.get("CONFIG_DIR") or os.environ.get("CONFIG_ACTIVE_DIR")
    if cfg_dir_env:
        cfg_dir = Path(cfg_dir_env)
        if cfg_dir.is_dir():
            return _first_json_in(cfg_dir)
        if cfg_dir.is_file() and cfg_dir.suffix.lower() == ".json":
            return cfg_dir
        return None

    rp = RuntimePaths()
    candidates = [
        rp.config_active_dir,
        rp.base_dir / "config" / "active",
        rp.base_dir.parent / "config" / "active",
        rp.base_dir.parent.parent / "config" / "active",
        Path.cwd() / "config" / "active",
    ]
    for cand in candidates:
        found = _first_json_in(cand)
        if found:
            return found

    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        found = _first_json_in(Path(meipass) / "config" / "active")
        if found:
            return found

    return None