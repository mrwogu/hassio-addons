#!/usr/bin/env python3
"""Validate user dynamic files before publishing them to Traefik."""

from __future__ import annotations

import argparse
import os
import sys
import tempfile
import time
from pathlib import Path

import yaml


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--active", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--interval", type=float, default=1.0)
    parser.add_argument("--once", action="store_true")
    return parser.parse_args()


def write_log(path: Path, message: str) -> None:
    try:
        with path.open("a", encoding="utf-8") as output:
            output.write(f"[traefik-proxy] {message}\n")
    except OSError:
        print(f"[traefik-proxy] {message}", file=sys.stderr)


def signature(path: Path) -> tuple[int, int]:
    stat = path.stat()
    return stat.st_mtime_ns, stat.st_size


def discover(source: Path) -> dict[str, Path]:
    return {
        path.name: path
        for path in source.iterdir()
        if path.is_file() and not path.is_symlink() and path.suffix in {".yml", ".yaml"}
    }


def discover_active(active: Path) -> dict[str, tuple[int, int]]:
    return {
        path.name: (-1, -1)
        for path in active.iterdir()
        if path.is_file() and not path.is_symlink() and path.suffix in {".yml", ".yaml"}
    }


def valid_content(path: Path) -> bytes | None:
    try:
        content = path.read_bytes()
        document = yaml.safe_load(content.decode("utf-8"))
    except (OSError, UnicodeError, yaml.YAMLError):
        return None
    if not isinstance(document, dict):
        return None
    return content


def publish(active: Path, name: str, content: bytes) -> None:
    active.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="wb",
        dir=active,
        prefix=f".{name}.",
        delete=False,
    ) as temporary:
        temporary.write(content)
        temporary.flush()
        os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)
    os.chmod(temporary_path, 0o600)
    temporary_path.replace(active / name)


def sync_once(
    source: Path,
    active: Path,
    log_path: Path,
    seen: dict[str, tuple[int, int]],
) -> dict[str, tuple[int, int]]:
    try:
        current = discover(source)
    except OSError as err:
        write_log(log_path, f"Could not inspect dynamic source directory: {err}")
        return seen
    for name, path in current.items():
        try:
            current_signature = signature(path)
        except OSError:
            continue
        if seen.get(name) == current_signature:
            continue
        content = valid_content(path)
        if content is None:
            write_log(
                log_path,
                f"Rejected invalid dynamic file without changing active state: {name}",
            )
            seen[name] = current_signature
            continue
        try:
            publish(active, name, content)
        except OSError as err:
            write_log(log_path, f"Could not publish dynamic file {name}: {err}")
            continue
        seen[name] = current_signature
        write_log(log_path, f"Published dynamic file: {name}")

    for name in set(seen) - set(current):
        try:
            (active / name).unlink(missing_ok=True)
        except OSError as err:
            write_log(log_path, f"Could not remove dynamic file {name}: {err}")
            continue
        del seen[name]
        write_log(log_path, f"Removed dynamic file: {name}")
    return seen


def main() -> int:
    args = parse_args()
    try:
        args.source.mkdir(mode=0o750, parents=True, exist_ok=True)
        args.active.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(args.source, 0o750)
        os.chmod(args.active, 0o700)
        seen = discover_active(args.active)
    except OSError as err:
        write_log(args.log, f"Could not initialize dynamic directories: {err}")
        return 1
    while True:
        try:
            if not args.source.is_dir():
                write_log(
                    args.log,
                    "Dynamic source directory is unavailable; keeping active state",
                )
                if args.once:
                    return 1
                time.sleep(max(args.interval, 0.1))
                continue
            args.active.mkdir(mode=0o700, parents=True, exist_ok=True)
            seen = sync_once(args.source, args.active, args.log, seen)
        except OSError as err:
            write_log(args.log, f"Dynamic watcher recovered from filesystem error: {err}")
        if args.once:
            return 0
        time.sleep(max(args.interval, 0.1))


if __name__ == "__main__":
    raise SystemExit(main())
