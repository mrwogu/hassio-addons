#!/usr/bin/env python3
"""Render effective Traefik static configuration atomically."""

from __future__ import annotations

import argparse
import os
import tempfile
from pathlib import Path
from typing import Any

import yaml


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--web-address", required=True)
    parser.add_argument("--websecure-address", required=True)
    parser.add_argument("--health-address", required=True)
    parser.add_argument("--dynamic-directory", required=True)
    parser.add_argument("--access-log-path", required=True)
    parser.add_argument("--log-level", required=True)
    parser.add_argument("--access-log-format", required=True)
    parser.add_argument("--trusted-proxy-ips", default="")
    parser.add_argument("--acme-enabled", required=True)
    parser.add_argument("--acme-email", default="")
    parser.add_argument("--acme-storage", required=True)
    return parser.parse_args()


def mapping(value: Any, name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"Static configuration section is not a mapping: {name}")
    return value


def render(args: argparse.Namespace) -> None:
    source = yaml.safe_load(args.source.read_text(encoding="utf-8"))
    root = mapping(source, "root")
    entrypoints = mapping(root.get("entryPoints"), "entryPoints")
    for name, address in (
        ("web", args.web_address),
        ("websecure", args.websecure_address),
        ("health", args.health_address),
    ):
        entrypoint = mapping(entrypoints.get(name), f"entryPoints.{name}")
        entrypoint["address"] = address
        if name != "health":
            forwarded = mapping(
                entrypoint.setdefault("forwardedHeaders", {}),
                "forwardedHeaders",
            )
            trusted = [
                item for item in args.trusted_proxy_ips.split(",") if item
            ]
            forwarded.pop("trustedIPs", None)
            if trusted:
                forwarded["trustedIPs"] = trusted

    providers = mapping(root.get("providers"), "providers")
    file_provider = mapping(providers.get("file"), "providers.file")
    file_provider["directory"] = args.dynamic_directory
    file_provider["watch"] = True

    log = mapping(root.get("log"), "log")
    log["level"] = args.log_level
    log.pop("filePath", None)

    access_log = mapping(root.get("accessLog"), "accessLog")
    access_log["filePath"] = args.access_log_path
    access_log["format"] = args.access_log_format

    if args.acme_enabled == "true":
        root["certificatesResolvers"] = {
            "letsencrypt": {
                "acme": {
                    "email": args.acme_email,
                    "storage": args.acme_storage,
                    "dnsChallenge": {"provider": "cloudflare"},
                }
            }
        }
    else:
        root.pop("certificatesResolvers", None)

    args.output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=args.output.parent,
            prefix=f".{args.output.name}.",
            delete=False,
        ) as temporary:
            temporary.write(yaml.safe_dump(root, sort_keys=False))
            temporary.flush()
            os.fsync(temporary.fileno())
            temporary_path = Path(temporary.name)
        os.chmod(temporary_path, 0o600)
        os.replace(temporary_path, args.output)
        temporary_path = None
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


if __name__ == "__main__":
    render(parse_args())
