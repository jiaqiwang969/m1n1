import importlib.util
import os
from pathlib import Path
import sys
import types
import unittest
import uuid


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "redroid" / "tools" / "redroid_viewer.py"
ADB_SERIAL_ENV = "REDROID_VIEWER_ADB_SERIAL"


def load_viewer_module(serial: str | None):
    previous = os.environ.get(ADB_SERIAL_ENV)
    previous_tkinter = sys.modules.get("tkinter")
    try:
        if serial is None:
            os.environ.pop(ADB_SERIAL_ENV, None)
        else:
            os.environ[ADB_SERIAL_ENV] = serial

        sys.modules["tkinter"] = types.ModuleType("tkinter")

        spec = importlib.util.spec_from_file_location(
            f"redroid_viewer_{uuid.uuid4().hex}",
            SCRIPT,
        )
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)
        return module
    finally:
        if previous is None:
            os.environ.pop(ADB_SERIAL_ENV, None)
        else:
            os.environ[ADB_SERIAL_ENV] = previous
        if previous_tkinter is None:
            sys.modules.pop("tkinter", None)
        else:
            sys.modules["tkinter"] = previous_tkinter


class RedroidViewerTest(unittest.TestCase):
    def test_defaults_to_primary_adb_serial(self) -> None:
        module = load_viewer_module(None)
        self.assertEqual(module.ADB, ["adb", "-s", "127.0.0.1:5555"])

    def test_honors_env_override_for_adb_serial(self) -> None:
        module = load_viewer_module("127.0.0.1:5556")
        self.assertEqual(module.ADB, ["adb", "-s", "127.0.0.1:5556"])


if __name__ == "__main__":
    unittest.main()
