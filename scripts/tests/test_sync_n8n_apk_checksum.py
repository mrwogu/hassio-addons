from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.sync_n8n_apk_checksum import synchronize


class N8nChecksumSyncTest(unittest.TestCase):
    def test_updates_both_architecture_checksums(self) -> None:
        dockerfile = f"""\
ARG APK_TOOLS_VERSION="3.0.7-r0"
ARG ALPINE_VERSION="v3.24"
ARG APK_TOOLS_SHA256_X86_64="{"0" * 64}"
ARG APK_TOOLS_SHA256_AARCH64="{"1" * 64}"
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Dockerfile"
            path.write_text(dockerfile, encoding="utf-8")
            with patch(
                "scripts.sync_n8n_apk_checksum.download_digest",
                side_effect=["a" * 64, "b" * 64],
            ):
                self.assertTrue(synchronize(path))
            content = path.read_text(encoding="utf-8")

        self.assertIn(f'ARG APK_TOOLS_SHA256_X86_64="{"a" * 64}"', content)
        self.assertIn(f'ARG APK_TOOLS_SHA256_AARCH64="{"b" * 64}"', content)

    def test_returns_false_when_checksums_are_current(self) -> None:
        digest = "a" * 64
        dockerfile = f"""\
ARG APK_TOOLS_VERSION="3.0.7-r0"
ARG ALPINE_VERSION="v3.24"
ARG APK_TOOLS_SHA256_X86_64="{digest}"
ARG APK_TOOLS_SHA256_AARCH64="{digest}"
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Dockerfile"
            path.write_text(dockerfile, encoding="utf-8")
            with patch(
                "scripts.sync_n8n_apk_checksum.download_digest",
                return_value=digest,
            ):
                self.assertFalse(synchronize(path))


if __name__ == "__main__":
    unittest.main()
