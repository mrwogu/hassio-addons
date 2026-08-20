# CLAUDE.md

<!-- PromptScript 2026-08-20T13:47:14.393Z | source: .promptscript/project.prs | target: claude - do not edit -->

## Project

You are a maintainer of a public Home Assistant add-on repository. Build
small, secure adapters around immutable upstream images. Preserve upstream
behavior, licenses, persistent data, and user secrets. Follow the repository
release automation instead of publishing artifacts manually.

## Tech Stack

python, shell, yaml, dockerfile

## Context

The repository packages Home Assistant add-ons. Integration code is MIT
licensed. Packaged applications retain their upstream licenses. Bonds uses
BUSL-1.1 and has commercial-use and managed hosting restrictions. n8n uses
the Sustainable Use License and has separate terms for Enterprise source
files.

Each add-on is a thin wrapper. Runtime adapters translate Home Assistant
options into upstream environment variables or files, validate untrusted
input, persist state under `/config`, and finish with `exec` so signals reach
the upstream process.

`addons.yaml` is the single registry for add-on slugs, images, Dockerfiles,
and adapter test scripts. Repository validation, Make targets, workflows, and
Renovate patterns must consume this registry instead of maintaining separate
add-on lists.

- Project: hassio-addons
- Architectures: aarch64, amd64
- Registry: ghcr.io/mrwogu
- Manifest: addons.yaml

## Code Style

- Pin every upstream image by both an explicit version and sha256 digest
- Use package versions in the exact form <upstream-version>-<positive-revision>
- Keep Dockerfile, upstream.yaml, config.yaml, and CHANGELOG.md synchronized
- Support aarch64 and amd64 in that order
- Keep init false and provide a writable addon_config mapping
- Store all mutable application data and generated secrets under /config
- Create generated secrets atomically with mode 0600 and never log their values
- Preserve upstream licenses and attribution in every add-on
- Use addons.yaml as the registry for add-on-specific automation
- Grant no capabilities by default
- Gluetun may use only NET_ADMIN and /dev/net/tun with its bounded AppArmor profile
- Reject control characters, unsafe custom environment names, and overrides of managed variables
- Pin every external GitHub Action to a full 40-character commit SHA
- Verify downloaded bootstrap artifacts with a pinned checksum
- Run make check after repository changes
- Run yamllint and actionlint after YAML or workflow changes
- Run ShellCheck after shell changes
- Build every changed add-on for aarch64 and amd64 before merge
- Run architecture integration workflows manually when credentials or privileged runtime are required

## Commands

```
/validate  - Run all repository validators relevant to the current changes
/new-addon - Apply the complete new add-on checklist from these instructions
/release   - Verify version, changelog, and automated release readiness
```

# Repository workflow

## Existing add-on

1. Start from `main` and inspect the add-on's `config.yaml`, `Dockerfile`,
   `upstream.yaml`, entrypoint, tests, documentation, translations, changelog,
   license, and manifest entry before editing.

2. Keep changes in the Home Assistant adapter layer. Do not change upstream
   application code.

3. For packaging-only changes, run:

```sh
     make bump ADDON=<slug> MESSAGE="<one-line description>"
```

The helper increments packaging revision and updates config, metadata, and
changelog atomically.

4. For upstream tag or digest changes, update Dockerfile source arguments and
   run:

```sh
     python3 scripts/sync_addon_version.py <slug>
```

## Validation

```sh
  make check
  yamllint .
  actionlint .github/workflows/*.yml
  find $(python3 scripts/addon_manifest.py directories) scripts -type f \
    \( -name '*.sh' -o -name 'addon-entrypoint' \) -print0 |
    xargs -0 shellcheck
  promptscript check
  promptscript validate --strict
  promptscript compile
  promptscript diff
```

CI runs the official Home Assistant add-on linter, changed add-on native
architecture builds, and publish validation. Use protected manual workflows
for real WireGuard or privileged integration tests.

## New add-on

Required files:

- `config.yaml`
- `Dockerfile`
- `README.md`
- `DOCS.md`
- `CHANGELOG.md`
- `LICENSE.upstream`
- `icon.png`
- `logo.png`
- `upstream.yaml`
- `translations/en.yaml`
- `translations/pl.yaml`
- `rootfs/usr/local/bin/addon-entrypoint`
- `tests/run.sh`

Add the slug, image, Dockerfile, and adapter test script to `addons.yaml`.
Do not duplicate the slug in Makefiles or workflow loops.

## Autonomous release process

Renovate checks upstream image tags and digests every six hours. Custom Docker
manager updates version and digest. Renovate PRs auto-merge after required
checks, including major updates by design because this repository distributes
upstream applications rather than developing them.

`renovate-sync` synchronizes package metadata on trusted Renovate branches.
It uses `pull_request_target` and write permissions only for the Renovate bot.

Maintainer adapter changes use `make bump` and a normal pull request.
Publish runs on `main`, finds add-ons without immutable `<slug>/<version>`
tags, validates all metadata, builds native architectures, signs images,
publishes SBOM attestations, creates multi-architecture manifests, and
creates matching GitHub Releases.

## Security reporting

Use GitHub private vulnerability reporting for wrapper code, adapter scripts,
workflow automation, image supply chain, secret handling, and published
artifacts. Route vulnerabilities in packaged upstream applications to the
upstream project.

## Don'ts

- Don't copy, fork, or patch upstream application source in an add-on
- Don't use an unpinned image, a latest base tag, or a mutable GitHub Action reference
- Don't expose credentials, VPN keys, generated secrets, tokens, personal data, or production configuration in code, tests, or logs
- Don't add full_access, host_network, a device, or a capability without a documented runtime requirement and validator coverage
- Don't reuse or overwrite a released package version or Git tag
- Don't execute downloaded bootstrap code without verifying its expected checksum
- Don't edit AGENTS.md or generated .factory content directly; edit .promptscript sources and run promptscript compile
- Don't treat upstream application vulnerabilities as wrapper vulnerabilities without verifying the boundary
