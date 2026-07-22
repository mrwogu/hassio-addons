#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from datetime import date, timedelta
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parent.parent
ADDONS = {
    "authentik": "ghcr.io/mrwogu/hassio-authentik",
    "bonds": "ghcr.io/mrwogu/hassio-bonds",
    "gluetun": "ghcr.io/mrwogu/hassio-gluetun",
}
REQUIRED_ADDON_FILES = (
    "config.yaml",
    "Dockerfile",
    "README.md",
    "DOCS.md",
    "CHANGELOG.md",
    "LICENSE.upstream",
    "icon.png",
    "logo.png",
    "upstream.yaml",
    "translations/en.yaml",
    "translations/pl.yaml",
    ".trivyignore.yaml",
    "rootfs/usr/local/bin/addon-entrypoint",
    "tests/run.sh",
)
VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+(?:[.-][0-9A-Za-z.-]+)*-[1-9]\d*$")
PACKAGE_VERSION_PATTERN = re.compile(r"^(.+)-([1-9]\d*)$")
ACTION_PATTERN = re.compile(r"^\s*uses:\s*([^./\s][^@\s]*)@([^\s#]+)")
SHA_PATTERN = re.compile(r"^[0-9a-f]{40}$")
UPSTREAM_ARG_PATTERN = re.compile(
    r'^ARG UPSTREAM_(VERSION|DIGEST)=["\']?([^"\'\s]+)["\']?\s*$',
    re.MULTILINE,
)


class UniqueKeyLoader(yaml.SafeLoader):
    pass


def construct_mapping(
    loader: UniqueKeyLoader,
    node: yaml.nodes.MappingNode,
    deep: bool = False,
) -> dict[str, Any]:
    mapping: dict[str, Any] = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise yaml.constructor.ConstructorError(
                "while constructing a mapping",
                node.start_mark,
                f"found duplicate key {key!r}",
                key_node.start_mark,
            )
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    construct_mapping,
)


def load_yaml(path: Path, errors: list[str]) -> Any:
    try:
        return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueKeyLoader)
    except (OSError, UnicodeError, yaml.YAMLError) as err:
        errors.append(f"{path.relative_to(ROOT)}: invalid YAML: {err}")
        return None


def package_version_matches_upstream(
    package_version: str,
    upstream_version: str,
) -> bool:
    match = PACKAGE_VERSION_PATTERN.fullmatch(package_version)
    return bool(
        match
        and match.group(1) == upstream_version.removeprefix("v")
    )


def validate_repository(errors: list[str]) -> None:
    path = ROOT / "repository.yaml"
    data = load_yaml(path, errors)
    if not isinstance(data, dict):
        return
    for key in ("name", "url", "maintainer"):
        if not data.get(key):
            errors.append(f"repository.yaml: missing {key}")
    if data.get("url") != "https://github.com/mrwogu/hassio-addons":
        errors.append("repository.yaml: unexpected repository URL")


def validate_addon(slug: str, expected_image: str, errors: list[str]) -> None:
    directory = ROOT / slug
    for relative in REQUIRED_ADDON_FILES:
        path = directory / relative
        if not path.is_file() or path.stat().st_size == 0:
            errors.append(f"{slug}/{relative}: required non-empty file missing")

    config_path = directory / "config.yaml"
    config = load_yaml(config_path, errors)
    if not isinstance(config, dict):
        return

    required_keys = ("name", "version", "slug", "description", "url", "arch", "init", "image")
    for key in required_keys:
        if key not in config:
            errors.append(f"{slug}/config.yaml: missing {key}")

    if config.get("slug") != slug:
        errors.append(f"{slug}/config.yaml: slug must be {slug!r}")
    if config.get("image") != expected_image:
        errors.append(f"{slug}/config.yaml: image must be {expected_image!r}")
    if config.get("arch") != ["aarch64", "amd64"]:
        errors.append(f"{slug}/config.yaml: arch must be [aarch64, amd64]")
    if config.get("init") is not False:
        errors.append(f"{slug}/config.yaml: init must be false")
    package_version = str(config.get("version", ""))
    if not VERSION_PATTERN.fullmatch(package_version):
        errors.append(
            f"{slug}/config.yaml: version must use <upstream-version>-<revision>"
        )
    changelog_path = directory / "CHANGELOG.md"
    if changelog_path.is_file():
        changelog = changelog_path.read_text(encoding="utf-8")
        version_heading = rf"^## {re.escape(str(config.get('version', '')))}$"
        if not re.search(version_heading, changelog, re.MULTILINE):
            errors.append(f"{slug}/CHANGELOG.md: current version section required")

    maps = config.get("map", [])
    has_addon_config = any(
        item == "addon_config:rw"
        or (
            isinstance(item, dict)
            and item.get("type") == "addon_config"
            and item.get("read_only") is False
        )
        for item in maps
    )
    if not has_addon_config:
        errors.append(f"{slug}/config.yaml: addon_config:rw mapping required")

    for unsafe_key in ("full_access", "host_network"):
        if config.get(unsafe_key):
            errors.append(f"{slug}/config.yaml: {unsafe_key} must not be enabled")

    privileged = config.get("privileged", [])
    if slug == "gluetun":
        if privileged != ["NET_ADMIN"]:
            errors.append("gluetun/config.yaml: only NET_ADMIN is allowed")
        if config.get("devices") != ["/dev/net/tun"]:
            errors.append("gluetun/config.yaml: only /dev/net/tun device is allowed")
    elif privileged:
        errors.append(f"{slug}/config.yaml: privileged capabilities are forbidden")

    dockerfile_path = directory / "Dockerfile"
    if dockerfile_path.is_file():
        dockerfile = dockerfile_path.read_text(encoding="utf-8")
        if re.search(r"^\s*FROM\s+\S+:latest(?:\s|$)", dockerfile, re.MULTILINE):
            errors.append(f"{slug}/Dockerfile: latest base image is forbidden")
        docker_source = dict(UPSTREAM_ARG_PATTERN.findall(dockerfile))
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", docker_source.get("DIGEST", "")):
            errors.append(f"{slug}/Dockerfile: valid upstream image digest required")
        if not re.search(r"^FROM\s+\S+@\$\{UPSTREAM_DIGEST\}\s*$", dockerfile, re.MULTILINE):
            errors.append(f"{slug}/Dockerfile: FROM must use UPSTREAM_DIGEST")
        upstream_path = directory / "upstream.yaml"
        upstream = load_yaml(upstream_path, errors) if upstream_path.is_file() else None
        if not isinstance(upstream, dict):
            errors.append(f"{slug}/upstream.yaml: metadata mapping required")
        else:
            for key in (
                "version",
                "digest",
                "package_version",
                "image",
                "source",
                "release_url",
            ):
                if not upstream.get(key):
                    errors.append(f"{slug}/upstream.yaml: missing {key}")
            if upstream.get("version") != docker_source.get("VERSION"):
                errors.append(f"{slug}: upstream version differs from Dockerfile")
            if upstream.get("digest") != docker_source.get("DIGEST"):
                errors.append(f"{slug}: upstream digest differs from Dockerfile")
            if not package_version_matches_upstream(
                package_version,
                str(upstream.get("version", "")),
            ):
                errors.append(f"{slug}: package version differs from upstream")
            if upstream.get("package_version") != package_version:
                errors.append(f"{slug}: package version differs from upstream metadata")

    options = config.get("options")
    schema = config.get("schema")
    if not isinstance(options, dict) or not isinstance(schema, dict):
        errors.append(f"{slug}/config.yaml: options and schema mappings required")
    elif not set(options).issubset(schema):
        unknown = sorted(set(options) - set(schema))
        errors.append(f"{slug}/config.yaml: options absent from schema: {unknown}")


def validate_yaml_files(errors: list[str]) -> None:
    for path in sorted(ROOT.rglob("*.yaml")) + sorted(ROOT.rglob("*.yml")):
        if ".git" in path.parts:
            continue
        load_yaml(path, errors)


def validate_action_pins(errors: list[str]) -> None:
    workflow_dir = ROOT / ".github" / "workflows"
    if not workflow_dir.exists():
        errors.append(".github/workflows: directory missing")
        return
    for path in sorted(workflow_dir.glob("*.y*ml")):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = ACTION_PATTERN.match(line)
            if match and not SHA_PATTERN.fullmatch(match.group(2)):
                errors.append(
                    f"{path.relative_to(ROOT)}:{line_number}: action must use full SHA"
                )


def validate_trivy_exceptions(slug: str, errors: list[str]) -> None:
    path = ROOT / slug / ".trivyignore.yaml"
    data = load_yaml(path, errors)
    if not isinstance(data, dict) or not isinstance(data.get("vulnerabilities"), list):
        errors.append(f"{slug}/.trivyignore.yaml: vulnerabilities list required")
        return

    seen: set[str] = set()
    today = date.today()
    for index, exception in enumerate(data["vulnerabilities"], 1):
        label = f"{slug}/.trivyignore.yaml: exception {index}"
        if not isinstance(exception, dict):
            errors.append(f"{label} must be a mapping")
            continue
        vulnerability_id = exception.get("id")
        if not isinstance(vulnerability_id, str) or not re.fullmatch(
            r"CVE-\d{4}-\d{4,}|GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}",
            vulnerability_id,
        ):
            errors.append(f"{label} must have a CVE or GHSA id")
        elif vulnerability_id in seen:
            errors.append(f"{label} duplicates {vulnerability_id}")
        else:
            seen.add(vulnerability_id)
        # A path scope is required when the finding has one. Operating-system
        # and statically linked binary CVEs have no file path, so Trivy can only
        # ignore them by id; those exceptions omit paths but stay justified and
        # time-boxed by the checks below.
        paths = exception.get("paths")
        if paths is not None and (
            not isinstance(paths, list)
            or not paths
            or not all(isinstance(item, str) and item for item in paths)
        ):
            errors.append(f"{label} paths must be a non-empty list of image paths")
        if not str(exception.get("statement", "")).strip():
            errors.append(f"{label} must explain the temporary exception")

        expires = exception.get("expired_at")
        if isinstance(expires, str):
            try:
                expires = date.fromisoformat(expires)
            except ValueError:
                expires = None
        if not isinstance(expires, date):
            errors.append(f"{label} must have an ISO expiration date")
        elif expires <= today:
            errors.append(f"{label} expired on {expires.isoformat()}")
        elif expires > today + timedelta(days=30):
            errors.append(f"{label} cannot remain active for more than 30 days")


def main() -> int:
    errors: list[str] = []
    validate_repository(errors)
    for slug, image in ADDONS.items():
        validate_addon(slug, image, errors)
        validate_trivy_exceptions(slug, errors)
    validate_yaml_files(errors)
    validate_action_pins(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"Validated repository and {len(ADDONS)} add-ons")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
