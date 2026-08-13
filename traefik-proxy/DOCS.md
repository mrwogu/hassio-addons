# Traefik Proxy operations

## Home Assistant Apps format

Home Assistant 2026.8 uses the Apps terminology for the same containerized
extension model previously called add-ons. This App uses the current repository
format: `config.yaml`, immutable image reference, `apparmor.txt`, translations,
ports, and writable storage mappings.

Supported architectures are `aarch64` and `amd64`. `init` is disabled.

## First start

1. Stop Nginx Proxy Manager if it uses host ports 80 or 443.
2. Install Traefik Proxy.
3. Start once with an empty `/share/traefik`.
4. Confirm that these directories exist:

   ```text
   /share/traefik/dynamic
   /share/traefik/logs
   ```

5. Add one dynamic YAML file.
6. Watch `traefik.log` for provider errors.
7. Send a request and validate one complete JSON object per line in
   `access.jsonl`.

Traefik file provider watches a validated staging directory. A valid update
reloads without restarting the App. Malformed YAML is rejected by the staging
watcher and reported in `traefik.log`; the last valid active file remains.

## File layout

```text
/share/traefik/
├── dynamic/
│   ├── homeassistant.yml
│   ├── services.yml
│   ├── middlewares.yml
│   └── tls.yml
└── logs/
    ├── access.jsonl
    └── traefik.log
```

Copy templates from `docs/examples/` into `dynamic/`, then replace every
placeholder with a real internal URL:

```text
docs/examples/homeassistant.yml
docs/examples/services.yml
docs/examples/middlewares.yml
docs/examples/tls.yml
```

`/config/traefik` is reserved for internal state and ACME:

```text
/config/traefik/logrotate.status
/config/traefik/acme.json
```

`/config` is persistent Home Assistant App storage. Protected token files may
also live elsewhere under `/config`, and the App does not assume
`/app_configs/<id>` exists. Logs and user-editable dynamic files stay under
`/share/traefik` deliberately so host fail2ban can consume them; this is the
adapter's only mutable-storage exception.

## Real client IP and Cloudflare Tunnel

Default `trusted_proxy_ips` is empty. This is intentional. Never set
`forwardedHeaders.insecure=true`, `0.0.0.0/0`, or an entire RFC1918 space just
to make a log look correct.

Set `trusted_proxy_ips` only to the source CIDR that actually connects to this
App:

```yaml
trusted_proxy_ips:
  - 172.30.33.12/32
```

The example is documentation only. Discover the real source address in a
controlled test and replace it. For a local cloudflared App, that address is
the cloudflared origin-side address, not the public Cloudflare Edge address.

Traefik then handles forwarded headers only from those trusted source IPs.
The access log keeps:

- `ClientAddr` and `ClientHost`
- `request_Cf-Connecting-Ip`
- `request_X-Forwarded-For`
- `request_X-Real-Ip`

Header logging is explicitly allowlisted. All other headers remain dropped.
Traefik may normalize or replace `X-Forwarded-For` while processing an
untrusted request. Verify its final value only after the origin-side proxy
source has been added to `trusted_proxy_ips`.

### Diagnostic procedure

1. Add a temporary protected `whoami` backend with a dynamic router.
2. Request it locally and through the Tunnel.
3. Compare `ClientHost` in `access.jsonl` with the `whoami` request headers.
4. Confirm the `X-Forwarded-For` value contains expected client and proxy hops.
5. Confirm `request_Cf-Connecting-Ip` contains the public client IP when the request
   came through Cloudflare.
6. Confirm `ClientHost` is not a Cloudflare Edge address.
7. If `ClientHost` is cloudflared instead of the visitor, verify the origin
   source CIDR and cloudflared forwarding behavior. Do not enable insecure
   forwarded headers.
8. Remove the diagnostic route after testing.

Traffic paths differ:

- Local LAN request to Home Assistant: source is the local client unless
  another local proxy is in front.
- Cloudflared to this App: socket peer is cloudflared; forwarded headers carry
  visitor context only when cloudflared provides them and the peer is trusted.
- Cloudflare Edge to Tunnel: Edge addresses are transport intermediaries, not
  visitor addresses. Never ban them as visitors.

A local HA firewall cannot block a visitor by public IP after that visitor has
entered through Cloudflare Tunnel. Apply visitor controls at Cloudflare WAF,
Cloudflare Rate Limiting, a Cloudflare API action, or a Cloudflare-aware
CrowdSec bouncer.

## Fail2ban

Fail2ban is not installed in this App. The App has no host firewall access and
does not request `NET_ADMIN`.

Copy examples from:

```text
docs/fail2ban/filter.d/traefik-auth.conf
docs/fail2ban/filter.d/traefik-404.conf
docs/fail2ban/filter.d/traefik-scan.conf
docs/fail2ban/jail.local.example
```

They target real Traefik JSON fields and `<HOST>` from `ClientHost`. Use them
on a separate Linux host that can read the log and owns its own firewall.

Before enabling:

1. Confirm `ClientHost` is the real visitor IP.
2. Add local trusted ranges to `ignoreip`.
3. Add every current Cloudflare IP range to `ignoreip` when filtering requests
   that can arrive through Cloudflare.
4. Test with `fail2ban-regex`.
5. Start with `enabled = false`, low ban duration, and monitoring.

Never ban Cloudflare Edge ranges. For Tunnel traffic, prefer Cloudflare WAF,
Rate Limiting, a least-privilege Cloudflare API action used by fail2ban, or
CrowdSec with a Cloudflare bouncer.

## Cloudflare DNS-01 ACME

Enable `acme` only when needed:

```yaml
acme:
  enabled: true
  email: admin@example.invalid
  cloudflare_api_token_file: /config/cloudflare/traefik-dns-token
```

Use a Cloudflare API token limited to DNS edit for required zone only. Protect
the file with mode `0600`. The adapter copies its value atomically to an
internal runtime file, passes its path to Traefik through
`CF_DNS_API_TOKEN_FILE`, and never logs its value. Paths are limited to
`/config` and `/share/traefik`.

ACME storage:

```text
/config/traefik/acme.json
```

The file is created with mode `0600`. Back it up with the App configuration
backup before upgrades or hardware replacement. Restore it only while the App
is stopped, preserve mode `0600`, and never publish it. If lost, Let's Encrypt
rate limits still apply, so avoid repeated destructive restores.

Dynamic routers must reference the resolver:

```yaml
http:
  routers:
    homeassistant:
      rule: "Host(`ha.example.invalid`)"
      entryPoints:
        - websecure
      service: homeassistant
      tls:
        certResolver: letsencrypt

  services:
    homeassistant:
      loadBalancer:
        servers:
          - url: "http://<HOME_ASSISTANT_ORIGIN>:8123"
```

## Migration from Nginx Proxy Manager

No automatic NPM database import is implemented. Do not delete NPM or its
hidden `/data`.

1. Create a fresh Home Assistant backup.
2. Export the NPM Proxy Hosts list, domains, certificates, access lists, and
   custom locations.
3. Record every backend URL, WebSocket requirement, headers, auth rule, and
   certificate.
4. Create equivalent files under `/share/traefik/dynamic/`.
5. Start Traefik on an alternate test host or isolated test system. Do not
   change production NPM ports yet.
6. Test HTTP, HTTPS, redirects, WebSocket, auth, TLS, and access logs.
7. Stop NPM.
8. Start Traefik on host ports 80 and 443.
9. Change the Cloudflare Tunnel origin manually to the Traefik HTTP or HTTPS
   origin. This App does not edit cloudflared.
10. Update Home Assistant `trusted_proxies` with only the actual proxy source
    addresses. Do not trust all private networks.
11. Test from LAN.
12. Test through Cloudflare from the Internet.
13. Keep NPM stopped but intact until migration is accepted.

### Rollback

1. Stop Traefik.
2. Start NPM.
3. Restore the previous cloudflared origin manually.
4. Confirm NPM `/data` and certificates remain intact.
5. Restore the previous Home Assistant proxy trust settings if they changed.

## Integration testing

The end-to-end test builds the pinned image, runs Docker on both `amd64` and
`aarch64` emulation targets, checks HTTP/HTTPS/WebSocket routing, access-log
redaction, dynamic reloads, invalid-file retention, restart persistence, and
log rotation:

```sh
make integration-traefik
```

The same test runs manually from the protected `Traefik integration` workflow.
The workflow also loads `apparmor.txt`, so it verifies the profile and
`net_bind_service` permission against the built image. Set `ACME_TEST=true` for
the optional resolver and `0600` storage checks.

## Health and troubleshooting

Healthcheck uses Traefik `healthcheck` against the private `health` entrypoint
with `ping=true`. No host port is published for it.

Check:

```text
tail -f /share/traefik/logs/traefik.log
tail -f /share/traefik/logs/access.jsonl
jq -c . /share/traefik/logs/access.jsonl
```

Typical messages:

- `Invalid options`: schema or runtime validation rejected a value.
- `configuration received from provider file`: dynamic file loaded.
- `Error while building configuration`: new dynamic file was rejected; old
  valid state remains active.
- `entryPoint ... already in use`: NPM or another proxy still owns 80/443.

## Security boundary

No privileged mode, host networking, Docker API, Docker provider, `NET_ADMIN`,
host firewall access, or public dashboard port is used. AppArmor limits file
access to required runtime paths. Secrets belong in masked options or protected
files, never in README files, fixtures, logs, URLs, or commits.
