# Changelog

## 3.41.1-6

- Allow AppArmor writes to /etc/openvpn for OpenVPN config generation

## 3.41.1-5

- Allow AppArmor writes to /etc/passwd and /etc/group for gluetun user creation

## 3.41.1-4

- Drop forced endpoint_port default so it stays unset for named providers

## 3.41.1-3

- Make VPN endpoint_port optional so named providers pick the endpoint

## 3.41.1-2

- Grant read on addon-entrypoint in AppArmor so /bin/sh can load the script

## 3.41.1-1

- Initial Home Assistant addon based on Gluetun v3.41.1.
- Add OpenVPN, WireGuard, and AmneziaWG configuration.
- Add server filters, firewall, DNS, port forwarding, and proxy options.
- Add atomic runtime secret files and validated advanced environment values.
- Add bounded AppArmor profile and native health monitoring.
