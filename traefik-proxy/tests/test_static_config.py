#!/usr/bin/env python3

from __future__ import annotations

import argparse
import importlib.util
import tempfile
import unittest
from pathlib import Path

import yaml


ADDON_DIR = Path(__file__).resolve().parents[1]
SCRIPT = ADDON_DIR / "static-config.py"
SPEC = importlib.util.spec_from_file_location("static_config", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Could not load static config renderer")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

DEFAULT_HEADERS = {
    "CF-Connecting-IP": "keep",
    "X-Forwarded-For": "keep",
    "X-Real-IP": "keep",
}


def render_config(access_log_headers: str = "", read_timeout: str = "60s") -> dict:
    with tempfile.TemporaryDirectory() as temporary:
        output = Path(temporary) / "static.yml"
        MODULE.render(
            argparse.Namespace(
                source=ADDON_DIR / "traefik.yml",
                output=output,
                web_address=":80",
                websecure_address=":443",
                health_address="127.0.0.1:8082",
                dynamic_directory="/config/traefik/dynamic-active",
                access_log_path="/share/traefik/logs/access.jsonl",
                log_level="info",
                access_log_format="json",
                access_log_headers=access_log_headers,
                read_timeout=read_timeout,
                trusted_proxy_ips="",
                acme_enabled="false",
                acme_email="",
                acme_storage="/config/traefik/acme.json",
            )
        )
        return yaml.safe_load(output.read_text(encoding="utf-8"))


def render_header_fields(access_log_headers: str) -> dict:
    return render_config(access_log_headers)["accessLog"]["fields"]["headers"]


class StaticConfigTest(unittest.TestCase):
    def test_access_log_headers_extend_allowlist(self) -> None:
        headers = render_header_fields("X-Authentik-Username,X-Authentik-Email")

        self.assertEqual("drop", headers["defaultMode"])
        self.assertEqual(
            {
                **DEFAULT_HEADERS,
                "X-Authentik-Username": "keep",
                "X-Authentik-Email": "keep",
            },
            headers["names"],
        )

    def test_empty_access_log_headers_keep_defaults(self) -> None:
        headers = render_header_fields("")

        self.assertEqual("drop", headers["defaultMode"])
        self.assertEqual(DEFAULT_HEADERS, headers["names"])

    def test_read_timeout_is_set_on_public_entrypoints_only(self) -> None:
        entrypoints = render_config(read_timeout="0s")["entryPoints"]

        for name in ("web", "websecure"):
            timeouts = entrypoints[name]["transport"]["respondingTimeouts"]
            self.assertEqual({"readTimeout": "0s"}, timeouts)
        self.assertNotIn("transport", entrypoints["health"])


if __name__ == "__main__":
    unittest.main()
