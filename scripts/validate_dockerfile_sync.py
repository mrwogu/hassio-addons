#!/usr/bin/env python3

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

try:
    from scripts.addon_manifest import load_manifest
except ModuleNotFoundError:
    from addon_manifest import load_manifest

REQUIRED_METADATA = ("config.yaml", "upstream.yaml", "CHANGELOG.md")


def validate_changed_files(
    addons: dict[str, dict[str, str]],
    changed_files: list[str],
) -> list[str]:
    changed = set(changed_files)
    errors: list[str] = []
    for slug, metadata in addons.items():
        dockerfile = metadata["dockerfile"]
        if dockerfile not in changed:
            continue
        missing = [
            f"{slug}/{relative}"
            for relative in REQUIRED_METADATA
            if f"{slug}/{relative}" not in changed
        ]
        if missing:
            errors.append(
                f"{dockerfile}: Dockerfile changes require synchronized metadata: "
                + ", ".join(missing)
            )
    return errors


def changed_files(root: Path, base: str, head: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...{head}"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("base")
    parser.add_argument("head")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    try:
        _, addons = load_manifest(root)
        errors = validate_changed_files(addons, changed_files(root, args.base, args.head))
    except (OSError, TypeError, ValueError, subprocess.CalledProcessError) as err:
        print(f"ERROR: could not validate Dockerfile synchronization: {err}", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Dockerfile metadata synchronization passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
