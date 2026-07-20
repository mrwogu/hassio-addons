from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml

from scripts.render_release_notes import render, write_github_output


class RenderReleaseNotesTest(unittest.TestCase):
    def make_addon(self) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        addon = Path(temporary.name)
        (addon / "config.yaml").write_text(
            "---\n"
            "name: Bonds\n"
            "slug: bonds\n"
            'version: "1.2.3-2"\n'
            "image: ghcr.io/example/bonds\n",
            encoding="utf-8",
        )
        (addon / "upstream.yaml").write_text(
            yaml.safe_dump(
                {
                    "version": "1.2.3",
                    "release_url": "https://example.invalid/releases/tag",
                    "release_tag_prefix": "v",
                },
                sort_keys=False,
                explicit_start=True,
            ),
            encoding="utf-8",
        )
        (addon / "CHANGELOG.md").write_text(
            "# Changelog\n\n"
            "## 1.2.3-2\n\n"
            "- Current release change.\n\n"
            "## 1.2.3-1\n\n"
            "- Previous release change.\n",
            encoding="utf-8",
        )
        return addon

    def test_render_uses_current_changelog_and_manifest(self) -> None:
        addon = self.make_addon()
        digest = f"sha256:{'a' * 64}"

        metadata = render(addon, digest)

        self.assertEqual(metadata.tag, "bonds/1.2.3-2")
        self.assertEqual(metadata.title, "Bonds 1.2.3-2")
        self.assertIn("- Current release change.", metadata.notes)
        self.assertNotIn("Previous release change", metadata.notes)
        self.assertIn(f"ghcr.io/example/bonds@{digest}", metadata.notes)
        self.assertIn("/tag/v1.2.3", metadata.notes)

    def test_write_github_output(self) -> None:
        addon = self.make_addon()
        digest = f"sha256:{'b' * 64}"
        metadata = render(addon, digest)
        output = addon / "github-output"

        write_github_output(output, metadata)

        values = dict(
            line.split("=", 1)
            for line in output.read_text(encoding="utf-8").splitlines()
        )
        self.assertEqual(values["tag"], "bonds/1.2.3-2")
        self.assertEqual(values["digest"], digest)

    def test_render_rejects_invalid_digest(self) -> None:
        with self.assertRaisesRegex(ValueError, "manifest digest"):
            render(self.make_addon(), "sha256:invalid")

    def test_render_requires_current_changelog_section(self) -> None:
        addon = self.make_addon()
        (addon / "config.yaml").write_text(
            (addon / "config.yaml")
            .read_text(encoding="utf-8")
            .replace("1.2.3-2", "1.2.3-3"),
            encoding="utf-8",
        )

        with self.assertRaisesRegex(ValueError, "changelog section"):
            render(addon, f"sha256:{'c' * 64}")


if __name__ == "__main__":
    unittest.main()
