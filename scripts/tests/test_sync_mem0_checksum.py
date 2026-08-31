from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.sync_mem0_checksum import synchronize


class Mem0ChecksumSyncTest(unittest.TestCase):
    def test_updates_source_checksum(self) -> None:
        dockerfile = f"""\
# renovate: datasource=github-releases depName=mem0ai/mem0 versioning=semver
ARG UPSTREAM_VERSION="2.0.20"
ARG UPSTREAM_DIGEST="sha256:{"0" * 64}"
FROM python:3.12-slim@${{UPSTREAM_DIGEST}}

ARG MEM0_SOURCE_SHA256="{"1" * 64}"
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Dockerfile"
            path.write_text(dockerfile, encoding="utf-8")
            with patch(
                "scripts.sync_mem0_checksum.download_digest",
                return_value="a" * 64,
            ):
                self.assertTrue(synchronize(path))
            content = path.read_text(encoding="utf-8")

        self.assertIn(f'ARG MEM0_SOURCE_SHA256="{"a" * 64}"', content)

    def test_returns_false_when_checksum_is_current(self) -> None:
        digest = "a" * 64
        dockerfile = f"""\
ARG UPSTREAM_VERSION="2.0.19"
ARG UPSTREAM_DIGEST="sha256:{"0" * 64}"
FROM python:3.12-slim@${{UPSTREAM_DIGEST}}

ARG MEM0_SOURCE_SHA256="{digest}"
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Dockerfile"
            path.write_text(dockerfile, encoding="utf-8")
            with patch(
                "scripts.sync_mem0_checksum.download_digest",
                return_value=digest,
            ):
                self.assertFalse(synchronize(path))

    def test_rejects_unsupported_version(self) -> None:
        dockerfile = """\
ARG UPSTREAM_VERSION="../../etc"
ARG MEM0_SOURCE_SHA256="aaa"
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Dockerfile"
            path.write_text(dockerfile, encoding="utf-8")
            with self.assertRaises(ValueError):
                synchronize(path)


if __name__ == "__main__":
    unittest.main()
