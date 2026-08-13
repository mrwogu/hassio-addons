# Traefik Proxy

Home Assistant App for Traefik Proxy v3.7.10. It exposes only HTTP and HTTPS:

- `80/tcp` - `web`
- `443/tcp` - `websecure`

Dashboard and API have no host port. Docker provider and Docker API access are
not used.

## Important migration warning

Do not run this App and Nginx Proxy Manager on host ports 80 or 443 at the
same time. Stop NPM before assigning those ports to Traefik. This App does not
edit, import, stop, delete, or back up NPM. Existing NPM `/data` remains
untouched.

Use [DOCS.md](DOCS.md) for full configuration, Cloudflare Tunnel diagnostics,
fail2ban guidance, backup, migration, and rollback.

## Storage

User-editable files live in:

```text
/share/traefik/dynamic/
```

Logs live in:

```text
/share/traefik/logs/access.jsonl
/share/traefik/logs/traefik.log
```

Internal state and ACME storage live under `/config/traefik`. The App creates
missing directories and keeps `acme.json` at mode `0600`.

The `/config` mapping is the persistent Home Assistant App storage. The App
does not modify any existing Nginx Proxy Manager data there.

## Minimal dynamic configuration

Create `/share/traefik/dynamic/homeassistant.yml`:

```yaml
http:
  routers:
    homeassistant:
      rule: "Host(`ha.example.invalid`)"
      entryPoints:
        - websecure
      service: homeassistant
      middlewares:
        - secure-headers
      tls: {}

  services:
    homeassistant:
      loadBalancer:
        servers:
          - url: "http://<HOME_ASSISTANT_ORIGIN>:8123"

  middlewares:
    secure-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        frameDeny: true
        referrerPolicy: no-referrer
```

Use real internal backend URLs in user files. Never commit production addresses,
credentials, tokens, or private keys.

Home Assistant uses WebSocket connections for parts of its frontend. Traefik
supports WebSocket upgrade on normal HTTP routers. No special middleware is
needed. Keep `Connection` and `Upgrade` headers unmodified.

## HTTP to HTTPS redirect

The static configuration redirects every request entering `web` to
`websecure`. A router that must remain HTTP-only must be deliberately placed on
`web` and must account for that redirect before changing the static file.

## Basic auth and forward auth

Generate a bcrypt password hash outside the App, then create a protected
dynamic file. Example:

```yaml
http:
  middlewares:
    dashboard-auth:
      basicAuth:
        users:
          - "operator:$2y$05$REPLACE_WITH_BCRYPT_HASH"

    sso:
      forwardAuth:
        address: "http://<AUTH_SERVICE_ORIGIN>:9000/verify"
        trustForwardHeader: false
        authResponseHeaders:
          - X-Forwarded-User
          - X-Forwarded-Email

  routers:
    protected-service:
      rule: "Host(`service.example.invalid`)"
      entryPoints:
        - websecure
      service: service
      middlewares:
        - dashboard-auth
      tls: {}

  services:
    service:
      loadBalancer:
        servers:
          - url: "http://<SERVICE_ORIGIN>:8080"
```

Do not place plaintext passwords in dynamic files. Basic auth hashes and
forward-auth configuration must remain protected by the Home Assistant backup
policy.

## TLS

Static TLS certificates can be loaded from `/share/traefik/dynamic/tls.yml`:

```yaml
tls:
  certificates:
    - certFile: /share/traefik/certs/example.crt
      keyFile: /share/traefik/certs/example.key
```

Keep private keys outside Git and use mode `0600`.

## Access logs

Default access log is JSON Lines at:

```text
/share/traefik/logs/access.jsonl
```

Each request is flushed immediately with `bufferingSize=0`. The configured
fields include `ClientAddr`, `ClientHost`, `RequestHost`, `RequestMethod`,
`RequestPath`, `DownstreamStatus`, `OriginStatus`, `UserAgent`, `Referer`,
`RequestCount`, `Duration`, and `RetryAttempts`.

All other request headers are dropped. `Cookie`, `Authorization`, `X-Api-Key`,
access tokens, and passwords are not configured for logging. Query parameters
are dropped by default, including query-string credentials. Do not put secrets
in URL paths or referrer URLs.

Set `access_log_format` to `common` only when a simple CLF-compatible filter is
more useful than structured analysis. JSON remains recommended.

Application log:

```text
/share/traefik/logs/traefik.log
```

Rotation: 50 MiB per file, 14 rotations, gzip, `copytruncate`. The active file
stays in place so `tail` and external log readers keep working.

## Dashboard and API

`api.insecure` is false. No dashboard or API port is published. `/api` and
`/dashboard` are not public routes unless the user explicitly creates a
dynamic router to `api@internal` and attaches authentication.

Do not expose `api@internal` without authentication:

```yaml
http:
  routers:
    dashboard:
      rule: "Host(`proxy-admin.example.invalid`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))"
      entryPoints:
        - websecure
      service: api@internal
      middlewares:
        - dashboard-auth
      tls: {}
```

## License

Traefik Proxy is MIT licensed. See [LICENSE.upstream](LICENSE.upstream).
This Home Assistant adapter is maintained separately and is not affiliated with
Traefik Labs or Home Assistant.
