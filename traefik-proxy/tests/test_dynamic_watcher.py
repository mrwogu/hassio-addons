#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "dynamic-watcher.py"
INVALID_FIXTURE = Path(__file__).resolve().parent / "fixtures" / "dynamic-invalid.txt"
SPEC = importlib.util.spec_from_file_location("dynamic_watcher", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Could not load dynamic watcher")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DynamicWatcherTest(unittest.TestCase):
    def test_invalid_file_does_not_replace_active_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            active = root / "active"
            log = root / "traefik.log"
            source.mkdir()

            good = source / "services.yml"
            good.write_text(
                "http:\n  services:\n    stable:\n      loadBalancer: {}\n",
                encoding="utf-8",
            )
            seen = MODULE.sync_once(source, active, log, {})
            active_good = (active / "services.yml").read_text(encoding="utf-8")

            broken = source / "broken.yml"
            broken.write_text(INVALID_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
            MODULE.sync_once(source, active, log, seen)

            self.assertEqual(
                active_good,
                (active / "services.yml").read_text(encoding="utf-8"),
            )
            self.assertFalse((active / "broken.yml").exists())
            self.assertIn("Rejected invalid dynamic file", log.read_text(encoding="utf-8"))

    def test_invalid_edit_preserves_active_file_after_watcher_restart(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            active = root / "active"
            log = root / "traefik.log"
            source.mkdir()
            good = source / "services.yml"
            good.write_text("http:\n  routers: {}\n", encoding="utf-8")
            MODULE.sync_once(source, active, log, {})
            expected = (active / "services.yml").read_bytes()

            good.write_text(INVALID_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
            restarted_seen = MODULE.discover_active(active)
            MODULE.sync_once(source, active, log, restarted_seen)

            self.assertEqual(expected, (active / "services.yml").read_bytes())

    def test_valid_edit_replaces_previous_file_atomically(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            active = root / "active"
            log = root / "traefik.log"
            source.mkdir()
            file_path = source / "routes.yml"
            file_path.write_text("http:\n  routers: {}\n", encoding="utf-8")
            seen = MODULE.sync_once(source, active, log, {})

            file_path.write_text(
                "http:\n  routers:\n    changed:\n      rule: Host(`example.invalid`)\n",
                encoding="utf-8",
            )
            MODULE.sync_once(source, active, log, seen)
            self.assertIn("changed", (active / "routes.yml").read_text(encoding="utf-8"))

            file_path.unlink()
            MODULE.sync_once(source, active, log, seen)
            self.assertFalse((active / "routes.yml").exists())

    def test_missing_source_does_not_remove_active_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            active = root / "active"
            log = root / "traefik.log"
            source.mkdir()
            file_path = source / "routes.yml"
            file_path.write_text("http:\n  routers: {}\n", encoding="utf-8")
            seen = MODULE.sync_once(source, active, log, {})
            file_path.unlink()
            source.rmdir()

            MODULE.sync_once(source, active, log, seen)

            self.assertTrue((active / "routes.yml").exists())
            self.assertIn("Could not inspect dynamic source directory", log.read_text())


if __name__ == "__main__":
    unittest.main()
