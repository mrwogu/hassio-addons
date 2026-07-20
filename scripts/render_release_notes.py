#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

import yaml

DIGEST_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")
HEADING_PATTERN = re.compile(r"^## ([^\s]+)\s*$", re.MULTILINE)


@dataclass(frozen=True)
class ReleaseMetadata:
    tag: str
    title: str
    version: str
    image: str
    digest: str
    notes: str


def load_mapping(path: Path) -> dict[str, object]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: mapping required")
    return data


def changelog_section(path: Path, version: str) -> str:
    content = path.read_text(encoding="utf-8")
    matches = list(HEADING_PATTERN.finditer(content))
    for index, match in enumerate(matches):
        if match.group(1) != version:
            continue
        end = matches[index + 1].start() if index + 1 < len(matches) else len(content)
        section = content[match.end() : end].strip()
        if not section:
            raise ValueError(f"{path}: changelog section {version} is empty")
        return section
    raise ValueError(f"{path}: changelog section {version} not found")


def upstream_release_url(upstream: dict[str, object]) -> str:
    version = str(upstream.get("version", "")).strip()
    base = str(upstream.get("release_url", "")).strip()
    if not version or not base:
        raise ValueError("upstream version and release_url are required")
    prefix = str(upstream.get("release_tag_prefix", ""))
    tag = version if not prefix or version.startswith(prefix) else f"{prefix}{version}"
    return f"{base.rstrip('/')}/{tag}"


def render(addon_dir: Path, manifest_digest: str) -> ReleaseMetadata:
    if not DIGEST_PATTERN.fullmatch(manifest_digest):
        raise ValueError("manifest digest must use sha256:<64 lowercase hex>")

    config = load_mapping(addon_dir / "config.yaml")
    upstream = load_mapping(addon_dir / "upstream.yaml")
    slug = str(config.get("slug", "")).strip()
    name = str(config.get("name", "")).strip()
    version = str(config.get("version", "")).strip()
    image = str(config.get("image", "")).strip()
    if not all((slug, name, version, image)):
        raise ValueError(f"{addon_dir}/config.yaml: release metadata is incomplete")

    upstream_version = str(upstream.get("version", "")).strip()
    section = changelog_section(addon_dir / "CHANGELOG.md", version)
    digest_ref = f"{image}@{manifest_digest}"
    notes = (
        f"{section}\n\n"
        "## Artifacts\n\n"
        f"- Multi-architecture image: `{image}:{version}`\n"
        f"- Manifest digest: `{digest_ref}`\n"
        f"- Architectures: `aarch64`, `amd64`\n"
        f"- Upstream: [{upstream_version}]({upstream_release_url(upstream)})\n\n"
        "SBOMs are attached to architecture images as OCI attestations. "
        "Architecture images and the multi-architecture manifest are signed "
        "with keyless Cosign."
    )
    return ReleaseMetadata(
        tag=f"{slug}/{version}",
        title=f"{name} {version}",
        version=version,
        image=image,
        digest=manifest_digest,
        notes=notes,
    )


def write_github_output(path: Path, metadata: ReleaseMetadata) -> None:
    with path.open("a", encoding="utf-8") as output:
        output.write(f"tag={metadata.tag}\n")
        output.write(f"title={metadata.title}\n")
        output.write(f"version={metadata.version}\n")
        output.write(f"image={metadata.image}\n")
        output.write(f"digest={metadata.digest}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("addon", type=Path)
    parser.add_argument("--digest", required=True)
    parser.add_argument("--notes-file", required=True, type=Path)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()

    metadata = render(args.addon.resolve(), args.digest)
    args.notes_file.write_text(f"{metadata.notes}\n", encoding="utf-8")
    if args.github_output:
        write_github_output(args.github_output, metadata)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
