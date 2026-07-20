# Gluetun VPN

Home Assistant addon for [Gluetun](https://github.com/passteque/gluetun).
Thin adapter translates Home Assistant options to Gluetun environment
variables and keeps Gluetun data in addon configuration storage.

## Features

- OpenVPN, WireGuard, and AmneziaWG
- Provider and server selection
- Firewall kill switch and LAN subnet access
- DNS filtering and caching
- VPN provider port forwarding
- HTTP, SOCKS5, and Shadowsocks proxy servers
- Advanced, validated Gluetun environment variables

## Security

Addon requests only `NET_ADMIN` and `/dev/net/tun` for VPN and firewall
operation. It does not request host networking, privileged mode, full host
access, Home Assistant API access, or an unconfined AppArmor profile.

Managed credentials are written atomically to runtime files with mode `0600`
and passed through Gluetun secret-file variables where Gluetun supports them.
Secret values are never logged by adapter. Gluetun does not offer secret-file
variables for SOCKS5 credentials, so those two values are passed directly in
process environment.

## Installation

Add `https://github.com/mrwogu/hassio-addons` as Home Assistant addon
repository, install Gluetun VPN, configure provider credentials, then start
addon. See [DOCS.md](DOCS.md) for option details.

## Data and backups

Home Assistant `addon_config` storage is mounted at `/config`. Image links
Gluetun storage path `/gluetun` to that directory, so downloaded server data,
custom VPN files, and control-server authentication survive restarts and are
included in addon backups.

## Support

Report packaging, Home Assistant integration, or adapter problems in
[this repository](https://github.com/mrwogu/hassio-addons/issues).
Report Gluetun application and provider problems to
[upstream Gluetun](https://github.com/passteque/gluetun).

This community addon is not affiliated with or supported by Gluetun authors.

## License

Gluetun is licensed under MIT. Exact upstream license is included as
[LICENSE.upstream](LICENSE.upstream).
