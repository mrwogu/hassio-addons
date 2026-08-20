from __future__ import annotations

import unittest

from scripts.addon_manifest import load_manifest


class AddonManifestTest(unittest.TestCase):
    def test_manifest_contains_expected_addon_contract(self) -> None:
        slugs, addons = load_manifest()

        self.assertEqual(slugs, sorted(slugs))
        self.assertEqual(addons["gluetun"]["image"], "ghcr.io/mrwogu/hassio-gluetun")
        self.assertEqual(addons["tududi"]["test_script"], "tududi/tests/run.sh")

    def test_manifest_has_no_absolute_paths(self) -> None:
        _, addons = load_manifest()

        for metadata in addons.values():
            for path in (metadata["dockerfile"], metadata["test_script"]):
                self.assertFalse(path.startswith("/"))
        for slug, metadata in addons.items():
            self.assertEqual(metadata["dockerfile"], f"{slug}/Dockerfile")
            self.assertEqual(metadata["test_script"], f"{slug}/tests/run.sh")
            self.assertEqual(metadata["image"], f"ghcr.io/mrwogu/hassio-{slug}")


if __name__ == "__main__":
    unittest.main()
