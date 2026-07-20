#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path

import yaml

if __package__:
    from .sync_addon_version import (
        addon_version_lock,
        read_docker_source,
        read_packaging_version,
        recover_text_transaction,
        render_config_version,
        render_upstream,
        write_text_transaction,
    )
else:
    from sync_addon_version import (
        addon_version_lock,
        read_docker_source,
        read_packaging_version,
        recover_text_transaction,
        render_config_version,
        render_upstream,
        write_text_transaction,
    )


def normalize_message(message: str) -> str:
    normalized = message.strip()
    if not normalized:
        raise ValueError("change message cannot be empty")
    if "\n" in normalized or "\r" in normalized:
        raise ValueError("change message must use one line")
    if len(normalized) > 160:
        raise ValueError("change message cannot exceed 160 characters")
    return normalized


def render_packaging_change(content: str, version: str, message: str) -> str:
    heading = f"## {version}"
    if heading in content:
        raise ValueError(f"changelog already contains {version}")
    entry = f"{heading}\n\n- {message}\n\n"
    if content.startswith("# Changelog\n"):
        content = f"# Changelog\n\n{entry}{content[12:].lstrip()}"
    else:
        content = f"# Changelog\n\n{entry}{content.lstrip()}"
    return content


def bump_locked(addon_dir: Path, message: str) -> str:
    recover_text_transaction(addon_dir)
    message = normalize_message(message)
    config_path = addon_dir / "config.yaml"
    upstream_path = addon_dir / "upstream.yaml"
    docker_version, docker_digest = read_docker_source(addon_dir / "Dockerfile")
    metadata = yaml.safe_load(upstream_path.read_text(encoding="utf-8"))
    if not isinstance(metadata, dict):
        raise ValueError(f"{upstream_path}: mapping required")
    if metadata.get("version") != docker_version:
        raise ValueError(f"{addon_dir}: upstream version is not synchronized")
    if metadata.get("digest") != docker_digest:
        raise ValueError(f"{addon_dir}: upstream digest is not synchronized")

    packaged_upstream, revision = read_packaging_version(config_path)
    normalized_upstream = docker_version.removeprefix("v")
    if packaged_upstream != normalized_upstream:
        raise ValueError(f"{addon_dir}: package version is not synchronized")

    package_version = f"{normalized_upstream}-{revision + 1}"
    metadata["package_version"] = package_version
    changelog_path = addon_dir / "CHANGELOG.md"
    config_content = config_path.read_text(encoding="utf-8")
    changelog_content = (
        changelog_path.read_text(encoding="utf-8")
        if changelog_path.exists()
        else "# Changelog\n"
    )
    updated_config = render_config_version(config_content, config_path, package_version)
    updated_changelog = render_packaging_change(
        changelog_content,
        package_version,
        message,
    )
    updated_upstream = render_upstream(metadata)
    write_text_transaction(
        {
            config_path: updated_config,
            upstream_path: updated_upstream,
            changelog_path: updated_changelog,
        }
    )
    return package_version


def bump(addon_dir: Path, message: str) -> str:
    with addon_version_lock(addon_dir):
        return bump_locked(addon_dir, message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("addon", type=Path)
    parser.add_argument("--message", required=True)
    args = parser.parse_args()

    version = bump(args.addon.resolve(), args.message)
    print(f"Bumped {args.addon} to {version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
