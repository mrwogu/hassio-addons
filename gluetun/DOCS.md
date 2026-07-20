# Gluetun VPN configuration

## Before starting

Gluetun provider-specific requirements still apply. Check
[upstream setup documentation](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)
for supported tunnel types, credentials, and forwarding support.

Set `vpn_service_provider` to Gluetun provider identifier. Use `custom` for a
custom OpenVPN, WireGuard, or AmneziaWG configuration.

## Tunnel options

### OpenVPN

Select `vpn_type: openvpn`.

- `username`, `password`: provider credentials
- `endpoint_ip`, `endpoint_port`: optional fixed endpoint
- `protocol`: `udp` or `tcp`
- `custom_config`: path to custom OpenVPN file, usually
  `/gluetun/custom.conf`

Username and password use `OPENVPN_USER_SECRETFILE` and
`OPENVPN_PASSWORD_SECRETFILE`.

### WireGuard

Select `vpn_type: wireguard`.

- `private_key`, `preshared_key`, `public_key`: tunnel keys
- `addresses`: comma-separated interface addresses
- `endpoint_ip`, `endpoint_port`: fixed endpoint
- `allowed_ips`: comma-separated routed networks
- `mtu`: tunnel MTU, or `0` to keep upstream default

Private key, preshared key, and addresses use corresponding Gluetun
secret-file variables.

### AmneziaWG

Select `vpn_type: amneziawg`. AmneziaWG currently requires provider `custom`.
Core key, address, endpoint, route, and MTU fields match WireGuard. Obfuscation
fields `jc`, `jmin`, `jmax`, `s1` through `s4`, and `h1` through `h4` map to
their upstream `AMNEZIAWG_*` variables. Zero or empty values retain upstream
defaults.

Private key, preshared key, and addresses use corresponding Gluetun
secret-file variables.

## Server filters

`server` accepts lists for:

- `regions`
- `countries`
- `cities`
- `hostnames`
- `names`
- `categories`

Empty lists do not set matching upstream variables.

## Port forwarding

`port_forwarding.enabled` requests provider-side port forwarding. Provider
must support this feature. Optional fields:

- `provider`: forwarding implementation override
- `listening_ports`: comma-separated ports opened through firewall
- `ports_count`: requested port count

## Firewall and LAN access

`firewall.outbound_subnets` maps to `FIREWALL_OUTBOUND_SUBNETS`. Add local
networks requiring direct access, for example `192.168.1.0/24`. Keep list as
small as possible because each subnet bypasses VPN route.

`firewall.vpn_input_ports` maps to `FIREWALL_VPN_INPUT_PORTS`.

Firewall kill switch remains enabled and cannot be disabled through managed
options.

## DNS

- `enabled`: enable Gluetun DNS server
- `resolver_type`: `dot`, `doh`, or `plain`
- `upstream_resolvers`: resolver names for encrypted DNS
- `plain_addresses`: host and port values for plain DNS
- `block_malicious`, `block_ads`: threat list controls
- `caching`: DNS response cache
- `ipv6`: allow IPv6 upstream DNS

For `plain`, set `plain_addresses`. For encrypted modes, set
`upstream_resolvers`.

## Proxies

Published host ports can be changed or disabled in Home Assistant network
settings. Container-side listener ports stay fixed:

| Service | Default port | Protocol |
| --- | ---: | --- |
| HTTP proxy | 8888 | TCP |
| Shadowsocks | 8388 | TCP and UDP |
| SOCKS5 | 1080 | TCP and UDP |

Each proxy group has `enabled`. HTTP proxy supports username, password,
stealth mode, and request logging. Shadowsocks supports password, cipher, and
logging. SOCKS5 supports username and password.

HTTP proxy and Shadowsocks credentials use Gluetun secret-file variables.
Gluetun v3.41.1 has no SOCKS5 secret-file variables, so SOCKS5 credentials
must be passed in process environment. Adapter still never logs their values.

## Advanced environment variables

`env_vars` contains `name` and `value` entries:

```yaml
env_vars:
  - name: HEALTH_TARGET_ADDRESSES
    value: example.com:443
```

Names must match `[A-Z][A-Z0-9_]*`. Adapter rejects:

- every variable managed by structured options
- adapter control and loader variables
- malformed names
- values containing control characters

Adapter logs accepted names only, never values. Advanced values may expose
secrets through process environment, so prefer structured secret options.

## Health and watchdog

Image retains native Gluetun healthcheck
`/gluetun-entrypoint healthcheck` for container diagnostics. Home Assistant
watchdog is not enabled because Gluetun does not expose a dedicated,
unauthenticated HTTP health endpoint. Control server remains internal because
its default role has administrative access.

## Updating and restoring

Stop addon before manually editing files in addon configuration storage.
Include addon configuration in Home Assistant backup. Before major Gluetun
updates, keep a current backup. Restore backup and install previous addon
version to roll back both adapter and persistent configuration.
