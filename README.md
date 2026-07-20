# mrwogu Home Assistant add-ons

Home Assistant add-ons packaged from upstream projects with automated updates, multi-architecture images, and security-focused defaults.

[![Open your Home Assistant instance and show the add repository dialog](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fmrwogu%2Fhassio-addons)

## Add-ons

### Gluetun

VPN client supporting multiple providers, OpenVPN, WireGuard, DNS filtering, and proxy services.

- Architectures: `amd64`, `aarch64`
- Upstream: [passteque/gluetun](https://github.com/passteque/gluetun)
- License: MIT

### Bonds

Personal relationship manager built with Go and React.

- Architectures: `amd64`, `aarch64`
- Upstream: [naiba/bonds](https://github.com/naiba/bonds)
- License: Business Source License 1.1
- Commercial use and managed hosting restrictions apply. Read the add-on documentation before installation.

## Installation

1. Open Home Assistant.
2. Go to **Settings > Apps > App store**.
3. Open the repository menu.
4. Add `https://github.com/mrwogu/hassio-addons`.
5. Install the selected add-on.

## Updates

Renovate checks upstream releases and image digests every six hours. Updates become eligible after three days, receive a pull request, pass required checks on `amd64` and `aarch64`, and merge without review. Successful merges publish immutable GHCR images and per-add-on GitHub Releases.

## Support

Report packaging, startup, or Home Assistant integration problems in this repository. Report application bugs directly to the respective upstream project.

These packages are community-maintained and are not endorsed by Home Assistant or the upstream projects.

## License

Repository integration code uses the MIT License. Packaged applications retain their upstream licenses, included in each add-on directory.
