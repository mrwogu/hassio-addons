#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
SLUG_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def load_manifest(root: Path = ROOT) -> tuple[list[str], dict[str, dict[str, str]]]:
    path = root / "addons.yaml"
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: mapping required")

    raw_addons = data.get("addons")
    if not isinstance(raw_addons, dict) or not raw_addons:
        raise ValueError(f"{path}: non-empty addons mapping required")

    raw_architectures = data.get("architectures")
    if raw_architectures != ["aarch64", "amd64"]:
        raise ValueError(f"{path}: architectures must be [aarch64, amd64]")

    addons: dict[str, dict[str, str]] = {}
    for slug, metadata in raw_addons.items():
        if not isinstance(slug, str) or not SLUG_PATTERN.fullmatch(slug):
            raise ValueError(f"{path}: invalid add-on slug {slug!r}")
        if not isinstance(metadata, dict):
            raise ValueError(f"{path}: {slug} metadata must be a mapping")
        normalized: dict[str, str] = {}
        for key in ("image", "dockerfile", "test_script"):
            value = metadata.get(key)
            if not isinstance(value, str) or not value or Path(value).is_absolute():
                raise ValueError(f"{path}: {slug}.{key} must be a relative string")
            normalized[key] = value
        expected_image = f"ghcr.io/mrwogu/hassio-{slug}"
        if normalized["image"] != expected_image:
            raise ValueError(f"{path}: {slug}.image must be {expected_image}")
        if normalized["dockerfile"] != f"{slug}/Dockerfile":
            raise ValueError(f"{path}: {slug}.dockerfile must be {slug}/Dockerfile")
        if normalized["test_script"] != f"{slug}/tests/run.sh":
            raise ValueError(f"{path}: {slug}.test_script must be {slug}/tests/run.sh")
        addons[slug] = normalized

    return list(addons), addons


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "format",
        choices=("list", "json", "test-scripts", "directories", "metadata-files"),
    )
    args = parser.parse_args()

    slugs, addons = load_manifest()
    if args.format == "list":
        print("\n".join(slugs))
    elif args.format == "json":
        print(json.dumps(slugs, separators=(",", ":")))
    elif args.format == "test-scripts":
        print("\n".join(addons[slug]["test_script"] for slug in slugs))
    elif args.format == "directories":
        print("\n".join(slugs))
    else:
        for slug in slugs:
            print(f"{slug}/Dockerfile")
            print(f"{slug}/config.yaml")
            print(f"{slug}/upstream.yaml")
            print(f"{slug}/CHANGELOG.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
