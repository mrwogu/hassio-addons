#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path
from urllib.request import Request, urlopen

ARCHITECTURES = {
    "X86_64": "x86_64",
    "AARCH64": "aarch64",
}
VERSION_PATTERN = re.compile(r"^[0-9A-Za-z.+_-]+$")
ALPINE_PATTERN = re.compile(r"^v[0-9.]+$")


def read_value(content: str, name: str) -> str:
    match = re.search(rf'^ARG {name}="([^"]+)"$', content, re.MULTILINE)
    if not match:
        raise ValueError(f"Missing {name} argument")
    return match.group(1)


def download_digest(
    alpine_version: str,
    apk_tools_version: str,
    architecture: str,
) -> str:
    package = f"apk-tools-static-{apk_tools_version}.apk"
    url = (
        f"https://dl-cdn.alpinelinux.org/alpine/{alpine_version}/main/"
        f"{architecture}/{package}"
    )
    request = Request(url, headers={"User-Agent": "hassio-addons-checksum-sync/1"})
    digest = hashlib.sha256()
    with urlopen(request, timeout=30) as response:
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def synchronize(path: Path) -> bool:
    content = path.read_text(encoding="utf-8")
    apk_tools_version = read_value(content, "APK_TOOLS_VERSION")
    alpine_version = read_value(content, "ALPINE_VERSION")
    if not VERSION_PATTERN.fullmatch(apk_tools_version):
        raise ValueError("APK_TOOLS_VERSION contains unsupported characters")
    if not ALPINE_PATTERN.fullmatch(alpine_version):
        raise ValueError("ALPINE_VERSION contains unsupported characters")

    updated = content
    for suffix, architecture in ARCHITECTURES.items():
        name = f"APK_TOOLS_SHA256_{suffix}"
        digest = download_digest(alpine_version, apk_tools_version, architecture)
        pattern = re.compile(rf'(^ARG {name}=")[0-9a-f]{{64}}(")$', re.MULTILINE)
        updated, count = pattern.subn(rf"\g<1>{digest}\g<2>", updated)
        if count != 1:
            raise ValueError(f"Expected one {name} argument")

    if updated == content:
        return False
    path.write_text(updated, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    path = args.root / "n8n" / "Dockerfile"
    try:
        changed = synchronize(path)
    except (OSError, ValueError, TimeoutError) as err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 1
    print("Updated n8n apk-tools checksums" if changed else "n8n apk-tools checksums are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
