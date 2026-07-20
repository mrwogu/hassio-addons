from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml

from scripts.bump_addon_revision import bump, normalize_message


class BumpAddonRevisionTest(unittest.TestCase):
    def make_addon(
        self,
        package_version: str = "1.2.3-2",
        metadata_version: str = "v1.2.3",
        metadata_digest: str = "sha256:current",
    ) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        addon = Path(temporary.name)
        (addon / "Dockerfile").write_text(
            'ARG UPSTREAM_VERSION="v1.2.3"\n'
            'ARG UPSTREAM_DIGEST="sha256:current"\n'
            "FROM example:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}\n",
            encoding="utf-8",
        )
        (addon / "config.yaml").write_text(
            f'---\nversion: "{package_version}"\n',
            encoding="utf-8",
        )
        (addon / "upstream.yaml").write_text(
            yaml.safe_dump(
                {
                    "version": metadata_version,
                    "digest": metadata_digest,
                },
                sort_keys=False,
                explicit_start=True,
            ),
            encoding="utf-8",
        )
        (addon / "CHANGELOG.md").write_text(
            "# Changelog\n\n## 1.2.3-2\n\n- Previous change.\n",
            encoding="utf-8",
        )
        return addon

    def test_bump_increments_revision_and_prepends_changelog(self) -> None:
        addon = self.make_addon()

        self.assertEqual(bump(addon, "Harden add-on configuration."), "1.2.3-3")
        self.assertIn('version: "1.2.3-3"', (addon / "config.yaml").read_text())
        metadata = yaml.safe_load((addon / "upstream.yaml").read_text())
        self.assertEqual(metadata["package_version"], "1.2.3-3")
        changelog = (addon / "CHANGELOG.md").read_text()
        self.assertLess(changelog.index("## 1.2.3-3"), changelog.index("## 1.2.3-2"))
        self.assertIn("- Harden add-on configuration.", changelog)

    def test_bump_rejects_unsynchronized_source(self) -> None:
        addon = self.make_addon(metadata_digest="sha256:stale")

        with self.assertRaisesRegex(ValueError, "digest is not synchronized"):
            bump(addon, "Change packaging.")

    def test_bump_rejects_unsynchronized_package_version(self) -> None:
        addon = self.make_addon(package_version="1.2.2-4")

        with self.assertRaisesRegex(ValueError, "package version is not synchronized"):
            bump(addon, "Change packaging.")

    def test_bump_preflight_prevents_partial_update(self) -> None:
        addon = self.make_addon()
        (addon / "CHANGELOG.md").write_text(
            "# Changelog\n\n## 1.2.3-3\n\n- Existing change.\n",
            encoding="utf-8",
        )
        original_config = (addon / "config.yaml").read_text()
        original_upstream = (addon / "upstream.yaml").read_text()

        with self.assertRaisesRegex(ValueError, "already contains"):
            bump(addon, "Change packaging.")

        self.assertEqual((addon / "config.yaml").read_text(), original_config)
        self.assertEqual((addon / "upstream.yaml").read_text(), original_upstream)

    def test_message_validation(self) -> None:
        for message in ("", "first\nsecond", "x" * 161):
            with self.subTest(message=message), self.assertRaises(ValueError):
                normalize_message(message)


if __name__ == "__main__":
    unittest.main()
