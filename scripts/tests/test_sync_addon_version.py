from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import yaml

from scripts.sync_addon_version import recover_text_transaction, sync


class SyncAddonVersionTest(unittest.TestCase):
    def make_addon(
        self,
        docker_version: str,
        docker_digest: str,
        metadata_version: str,
        metadata_digest: str,
        package_version: str,
        release_tag_prefix: str = "",
        metadata_package_version: str | None = None,
    ) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        addon = Path(temporary.name)
        (addon / "Dockerfile").write_text(
            f'ARG UPSTREAM_VERSION="{docker_version}"\n'
            f'ARG UPSTREAM_DIGEST="{docker_digest}"\n'
            "FROM example:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}\n",
            encoding="utf-8",
        )
        (addon / "config.yaml").write_text(
            f'---\nversion: "{package_version}"\n',
            encoding="utf-8",
        )
        metadata = {
            "version": metadata_version,
            "digest": metadata_digest,
            "package_version": metadata_package_version or package_version,
            "release_url": "https://example.invalid/releases/tag",
        }
        if release_tag_prefix:
            metadata["release_tag_prefix"] = release_tag_prefix
        (addon / "upstream.yaml").write_text(
            yaml.safe_dump(metadata, sort_keys=False),
            encoding="utf-8",
        )
        (addon / "CHANGELOG.md").write_text(
            f"# Changelog\n\n## {package_version}\n\n- Existing change.\n",
            encoding="utf-8",
        )
        return addon

    def test_new_upstream_version_resets_revision(self) -> None:
        addon = self.make_addon(
            "v2.0.0",
            "sha256:new",
            "v1.0.0",
            "sha256:old",
            "1.0.0-4",
            "v",
        )

        self.assertEqual(sync(addon), "2.0.0-1")
        self.assertIn('version: "2.0.0-1"', (addon / "config.yaml").read_text())
        changelog = (addon / "CHANGELOG.md").read_text()
        self.assertIn("## 2.0.0-1", changelog)
        self.assertIn("/tag/v2.0.0", changelog)

    def test_digest_update_increments_revision(self) -> None:
        addon = self.make_addon(
            "v1.0.0",
            "sha256:new",
            "v1.0.0",
            "sha256:old",
            "1.0.0-2",
        )

        self.assertEqual(sync(addon), "1.0.0-3")

    def test_unchanged_source_is_noop(self) -> None:
        addon = self.make_addon(
            "v1.0.0",
            "sha256:same",
            "v1.0.0",
            "sha256:same",
            "1.0.0-1",
        )

        self.assertIsNone(sync(addon))

    def test_interrupted_sync_repairs_config_and_changelog(self) -> None:
        addon = self.make_addon(
            "v2.0.0",
            "sha256:new",
            "v2.0.0",
            "sha256:new",
            "1.0.0-4",
            metadata_package_version="2.0.0-1",
        )

        self.assertEqual(sync(addon), "2.0.0-1")
        self.assertIn('version: "2.0.0-1"', (addon / "config.yaml").read_text())
        self.assertIn("## 2.0.0-1", (addon / "CHANGELOG.md").read_text())

    def test_transaction_journal_recovers_all_files(self) -> None:
        addon = self.make_addon(
            "v1.0.0",
            "sha256:same",
            "v1.0.0",
            "sha256:same",
            "1.0.0-1",
        )
        updates = {
            "config.yaml": '---\nversion: "1.0.0-2"\n',
            "upstream.yaml": "---\npackage_version: 1.0.0-2\n",
            "CHANGELOG.md": "# Changelog\n\n## 1.0.0-2\n\n- Recovered.\n",
        }
        journal = addon / ".version-transaction.json"
        journal.write_text(
            json.dumps({"version": 1, "updates": updates}),
            encoding="utf-8",
        )

        self.assertTrue(recover_text_transaction(addon))
        for name, content in updates.items():
            self.assertEqual((addon / name).read_text(), content)
        self.assertFalse(journal.exists())
        self.assertFalse(recover_text_transaction(addon))


if __name__ == "__main__":
    unittest.main()
