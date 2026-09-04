"""Shared helpers for the bootstrap every driver.py needs to reach libs/.

Driver folders are loaded in isolation via `runpy` (see driver_manager.py's
_process_runner / docs/en/driver-contract.md section 8) - a driver.py is
never imported as part of the `opas_dl_commons` package, so it can't `import`
anything from here directly. It still needs a short, self-contained walk-up
inline to locate *this* file in the first place (see any existing driver.py,
e.g. ADAM_4013/driver.py, for the exact snippet) - that part genuinely can't
move into libs/, since it's what finds libs/ before anything here is
reachable. Everything downstream of that - locating and loading further
libs/ modules by name - lives here instead, so there is exactly one place to
fix if it ever changes, and `find_libs_dir` below is the canonical,
documented version of the walk-up (non-isolated code, e.g. driver_manager.py,
can import and reuse it directly; a driver.py can only mirror its logic
inline).
"""

import importlib.util
import os
import sys


def find_libs_dir(start):
    """Walk upward from `start` to find opas_dl_commons/libs/.

    Driver folders can be nested under drivers/ for grouping (e.g.
    drivers/API/API_XXX/driver.py) or sit directly under it
    (drivers/MyInstrument/driver.py) - the number of parent hops to libs/
    isn't fixed, so walk up instead of hardcoding a fixed depth.
    """
    current = start
    for _ in range(10):  # generous bound against unexpectedly deep/broken paths
        candidate = os.path.join(current, "libs")
        if os.path.isdir(candidate):
            return candidate
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
    raise RuntimeError(f"Could not locate opas_dl_commons/libs/ starting from {start}")


def load_module(libs_dir, module_name, filename=None, register=False):
    """Load `<libs_dir>/<filename or module_name + '.py'>` via spec_from_file_location.

    Centralizes the exec_module boilerplate every driver.py otherwise repeats
    once per shared module (driver_sdk.py, common.py, comm_manager.py,
    output_manager.py, ...). Returns the loaded module, or None if the file
    doesn't exist - mirrors the "optional dependency" pattern driver.py files
    use for common.py et al. (missing file is not fatal, a bad file still
    raises normally out of exec_module).

    `register=True` additionally sets `sys.modules[module_name]` *before*
    executing the module (matching the order `output_manager.py` needs: its
    `Reading` instances cross into the output broker process via
    `multiprocessing.Queue`, so `module_name` must already resolve to this
    exact module object - including for any self-import inside it during
    exec - for pickling to match up across processes).
    """
    path = os.path.join(libs_dir, filename or f"{module_name}.py")
    if not os.path.exists(path):
        return None
    spec = importlib.util.spec_from_file_location(module_name, path)
    module = importlib.util.module_from_spec(spec)
    if register:
        sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module
