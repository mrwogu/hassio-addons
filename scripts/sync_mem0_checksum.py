#!/usr/bin/env python3

"""Synchronize the mem0 source checksum with the pinned upstream version.

The mem0 add-on builds from the upstream source tarball because upstream
publishes no versioned multi-architecture image. Renovate bumps the version
argument only; this script computes the checksum of the matching tarball so
the synchronized Renovate branch builds cleanly. The build verifies the
checksum again before extracting.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path
from urllib.request import Request, urlopen

VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
DIGEST_PATTERN = re.compile(r"^[0-9a-f]{64}$")
TARBALL_URL = "https://github.com/mem0ai/mem0/archive/refs/tags/v{version}.tar.gz"


def read_value(content: str, name: str) -> str:
    match = re.search(rf'^ARG {name}="([^"]+)"$', content, re.MULTILINE)
    if not match:
        raise ValueError(f"Missing {name} argument")
    return match.group(1)


def download_digest(version: str) -> str:
    url = TARBALL_URL.format(version=version)
    request = Request(url, headers={"User-Agent": "hassio-addons-checksum-sync/1"})
    digest = hashlib.sha256()
    with urlopen(request, timeout=120) as response:
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def synchronize(path: Path) -> bool:
    content = path.read_text(encoding="utf-8")
    version = read_value(content, "UPSTREAM_VERSION")
    if not VERSION_PATTERN.fullmatch(version):
        raise ValueError(f"UPSTREAM_VERSION contains unsupported characters: {version}")
    read_value(content, "MEM0_SOURCE_SHA256")

    digest = download_digest(version)
    if not DIGEST_PATTERN.fullmatch(digest):
        raise ValueError("Computed digest has an unexpected format")
    pattern = re.compile(r'(^ARG MEM0_SOURCE_SHA256=")[0-9a-f]{64}(")$', re.MULTILINE)
    updated, count = pattern.subn(rf"\g<1>{digest}\g<2>", content)
    if count != 1:
        raise ValueError("Expected one MEM0_SOURCE_SHA256 argument")

    if updated == content:
        return False
    path.write_text(updated, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    path = args.root / "mem0" / "Dockerfile"
    try:
        changed = synchronize(path)
    except (OSError, ValueError, TimeoutError) as err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 1
    print("Updated mem0 source checksum" if changed else "mem0 source checksum is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
