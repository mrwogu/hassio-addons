#!/usr/bin/env python3

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import stat
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

import yaml

ARG_PATTERN = re.compile(
    r'^ARG UPSTREAM_(VERSION|DIGEST)=["\']?([^"\'\s]+)["\']?\s*$',
    re.MULTILINE,
)
CONFIG_VERSION_PATTERN = re.compile(
    r'^(version:[ \t]*)["\']?([^"\'\s]+)["\']?[ \t]*$',
    re.MULTILINE,
)
TRANSACTION_FILE = ".version-transaction.json"
LOCK_DIRECTORY = Path(tempfile.gettempdir()) / "hassio-addons-version-locks"


def read_docker_source(path: Path) -> tuple[str, str]:
    values = dict(ARG_PATTERN.findall(path.read_text(encoding="utf-8")))
    try:
        return values["VERSION"], values["DIGEST"]
    except KeyError as err:
        raise ValueError(f"{path}: missing UPSTREAM_{err.args[0]} argument") from err


def read_packaging_version(path: Path) -> tuple[str, int]:
    match = CONFIG_VERSION_PATTERN.search(path.read_text(encoding="utf-8"))
    if not match:
        raise ValueError(f"{path}: version field not found")
    return parse_packaging_version(match.group(2), str(path))


def parse_packaging_version(value: str, source: str) -> tuple[str, int]:
    try:
        upstream, revision = value.rsplit("-", 1)
        parsed_revision = int(revision)
        if not upstream or parsed_revision < 1:
            raise ValueError
        return upstream, parsed_revision
    except (ValueError, TypeError) as err:
        raise ValueError(f"{source}: unsupported version {value!r}") from err


@contextmanager
def addon_version_lock(addon_dir: Path) -> Iterator[None]:
    LOCK_DIRECTORY.mkdir(mode=0o700, parents=True, exist_ok=True)
    identity = hashlib.sha256(str(addon_dir.resolve()).encode()).hexdigest()
    lock_path = LOCK_DIRECTORY / f"{identity}.lock"
    with lock_path.open("a+", encoding="utf-8") as lock:
        os.chmod(lock_path, 0o600)
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def write_config_version(path: Path, version: str) -> None:
    content = render_config_version(path.read_text(encoding="utf-8"), path, version)
    write_text_transaction({path: content})


def render_config_version(content: str, path: Path, version: str) -> str:
    updated, count = CONFIG_VERSION_PATTERN.subn(
        lambda match: f'{match.group(1)}"{version}"',
        content,
        count=1,
    )
    if count != 1:
        raise ValueError(f"{path}: could not update version")
    return updated


def render_upstream(data: dict[str, str]) -> str:
    return yaml.safe_dump(
        data,
        sort_keys=False,
        default_flow_style=False,
        explicit_start=True,
    )


def render_changelog(
    content: str,
    version: str,
    upstream_version: str,
    url: str,
    release_tag: str,
) -> str:
    heading = f"## {version}"
    if heading in content:
        return content
    entry = (
        f"{heading}\n\n"
        f"- Update upstream to [{upstream_version}]({url.rstrip('/')}/{release_tag}).\n\n"
    )
    if content.startswith("# Changelog\n"):
        content = f"# Changelog\n\n{entry}{content[12:].lstrip()}"
    else:
        content = f"# Changelog\n\n{entry}{content.lstrip()}"
    return content


def write_text_transaction(updates: dict[Path, str]) -> None:
    parent_directories = {path.parent for path in updates}
    if len(parent_directories) != 1:
        raise ValueError("transaction files must share a directory")
    directory = next(iter(parent_directories))
    journal_path = directory / TRANSACTION_FILE
    if journal_path.exists():
        raise ValueError(f"{journal_path}: pending transaction must be recovered")

    originals = {
        path: path.read_text(encoding="utf-8") if path.exists() else None
        for path in updates
    }
    staged: dict[Path, Path] = {}
    staged_journal: Path | None = None
    replaced: list[Path] = []
    try:
        for path, content in updates.items():
            with tempfile.NamedTemporaryFile(
                "w",
                encoding="utf-8",
                dir=path.parent,
                prefix=f".{path.name}.",
                delete=False,
            ) as handle:
                handle.write(content)
                staged[path] = Path(handle.name)
            if path.exists():
                os.chmod(staged[path], stat.S_IMODE(path.stat().st_mode))
            else:
                os.chmod(staged[path], 0o644)

        journal_data = {
            "version": 1,
            "updates": {path.name: content for path, content in updates.items()},
        }
        with tempfile.NamedTemporaryFile(
            "w",
            encoding="utf-8",
            dir=directory,
            prefix=f".{TRANSACTION_FILE}.",
            delete=False,
        ) as handle:
            json.dump(journal_data, handle)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
            staged_journal = Path(handle.name)
        os.chmod(staged_journal, 0o600)
        staged_journal.replace(journal_path)

        for path, temporary in staged.items():
            temporary.replace(path)
            replaced.append(path)
        journal_path.unlink()
    except Exception:
        for path in reversed(replaced):
            original = originals[path]
            if original is None:
                path.unlink(missing_ok=True)
            else:
                path.write_text(original, encoding="utf-8")
        journal_path.unlink(missing_ok=True)
        raise
    finally:
        for temporary in staged.values():
            temporary.unlink(missing_ok=True)
        if staged_journal is not None:
            staged_journal.unlink(missing_ok=True)


def recover_text_transaction(directory: Path) -> bool:
    journal_path = directory / TRANSACTION_FILE
    if not journal_path.exists():
        return False
    try:
        journal = json.loads(journal_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as err:
        raise ValueError(f"{journal_path}: invalid transaction journal") from err
    raw_updates = journal.get("updates") if isinstance(journal, dict) else None
    if (
        not isinstance(journal, dict)
        or journal.get("version") != 1
        or not isinstance(raw_updates, dict)
    ):
        raise ValueError(f"{journal_path}: unsupported transaction journal")

    updates: dict[Path, str] = {}
    for name, content in raw_updates.items():
        if (
            not isinstance(name, str)
            or Path(name).name != name
            or not isinstance(content, str)
        ):
            raise ValueError(f"{journal_path}: unsafe transaction entry")
        updates[directory / name] = content

    staged: dict[Path, Path] = {}
    try:
        for path, content in updates.items():
            with tempfile.NamedTemporaryFile(
                "w",
                encoding="utf-8",
                dir=directory,
                prefix=f".{path.name}.",
                delete=False,
            ) as handle:
                handle.write(content)
                staged[path] = Path(handle.name)
            if path.exists():
                os.chmod(staged[path], stat.S_IMODE(path.stat().st_mode))
            else:
                os.chmod(staged[path], 0o644)
        for path, temporary in staged.items():
            temporary.replace(path)
        journal_path.unlink()
    finally:
        for temporary in staged.values():
            temporary.unlink(missing_ok=True)
    return True


def sync_locked(addon_dir: Path) -> str | None:
    recover_text_transaction(addon_dir)
    docker_version, docker_digest = read_docker_source(addon_dir / "Dockerfile")
    config_path = addon_dir / "config.yaml"
    upstream_path = addon_dir / "upstream.yaml"
    changelog_path = addon_dir / "CHANGELOG.md"
    config_content = config_path.read_text(encoding="utf-8")
    upstream_content = upstream_path.read_text(encoding="utf-8")
    changelog_content = (
        changelog_path.read_text(encoding="utf-8")
        if changelog_path.exists()
        else "# Changelog\n"
    )
    metadata = yaml.safe_load(upstream_content)
    if not isinstance(metadata, dict):
        raise ValueError(f"{upstream_path}: mapping required")

    old_version = str(metadata.get("version", ""))
    old_digest = str(metadata.get("digest", ""))
    recorded_package = str(metadata.get("package_version", ""))
    packaged_upstream, revision = read_packaging_version(config_path)
    normalized_version = docker_version.removeprefix("v")
    source_changed = old_version != docker_version or old_digest != docker_digest
    if source_changed:
        if old_version != docker_version or packaged_upstream != normalized_version:
            revision = 1
        else:
            revision += 1
        package_version = f"{normalized_version}-{revision}"
    elif recorded_package:
        recorded_upstream, recorded_revision = parse_packaging_version(
            recorded_package,
            f"{upstream_path}: package_version",
        )
        if recorded_upstream != normalized_version:
            raise ValueError(f"{upstream_path}: package_version differs from upstream")
        package_version = f"{recorded_upstream}-{recorded_revision}"
    else:
        if packaged_upstream != normalized_version:
            raise ValueError(f"{addon_dir}: package version is not synchronized")
        package_version = f"{packaged_upstream}-{revision}"

    metadata["version"] = docker_version
    metadata["digest"] = docker_digest
    metadata["package_version"] = package_version

    release_base = str(metadata.get("release_url", "")).strip()
    if not release_base:
        raise ValueError(f"{upstream_path}: release_url required")
    tag_prefix = str(metadata.get("release_tag_prefix", ""))
    release_tag = docker_version
    if tag_prefix and not release_tag.startswith(tag_prefix):
        release_tag = f"{tag_prefix}{release_tag}"
    updated_config = render_config_version(config_content, config_path, package_version)
    updated_changelog = render_changelog(
        changelog_content,
        package_version,
        docker_version,
        release_base,
        release_tag,
    )
    upstream_changed = (
        old_version != docker_version
        or old_digest != docker_digest
        or recorded_package != package_version
    )
    updated_upstream = render_upstream(metadata) if upstream_changed else upstream_content
    updates = {
        config_path: updated_config,
        upstream_path: updated_upstream,
        changelog_path: updated_changelog,
    }
    changed = any(
        originals != updated
        for originals, updated in (
            (config_content, updated_config),
            (upstream_content, updated_upstream),
            (changelog_content, updated_changelog),
        )
    )
    if not changed:
        return None
    write_text_transaction(updates)
    return package_version


def sync(addon_dir: Path) -> str | None:
    with addon_version_lock(addon_dir):
        return sync_locked(addon_dir)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("addon", type=Path)
    args = parser.parse_args()

    version = sync(args.addon.resolve())
    if version:
        print(f"Updated {args.addon} to {version}")
    else:
        print(f"No source change for {args.addon}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
