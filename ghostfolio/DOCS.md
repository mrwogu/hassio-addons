# Ghostfolio Add-on Documentation

## Requirements

Ghostfolio does not bundle a database or a cache. Before starting the add-on,
provide:

- An external **PostgreSQL** server with an empty database and a user that
  owns it.
- An external **Redis** server, used for caching and background job queues.

Both must be reachable from the Home Assistant host. Example PostgreSQL setup:

```sql
CREATE USER ghostfolio WITH PASSWORD 'a-strong-password';
CREATE DATABASE ghostfolio OWNER ghostfolio;
```

On every start the upstream launcher applies pending database migrations and
seeds the base data before the server starts. The first start can take a
while.

## Access

Ghostfolio listens on port `3333`. Home Assistant ingress is not used:
Ghostfolio serves its web app and API from the root path, so it cannot follow
the dynamic sub-path that ingress proxies under. Reach it directly on port
`3333`, or place your own reverse proxy in front for TLS.

Open the interface and click **Get Started** to create the first user. The
first user becomes the administrator. Ghostfolio signs in with a security
token, so store the token shown after sign up in a safe place.

## Configuration

### `postgres_host`, `postgres_port`, `postgres_db`, `postgres_user`, `postgres_password`

Connection details for the external PostgreSQL server. The host must be a
hostname, an IPv4 address, or an IPv6 address without brackets. The add-on
percent-encodes the user, password, and database name, so special characters
in the password are fine.

### `postgres_sslmode`

TLS mode for the database connection: `disable`, `prefer`, or `require`.

### `redis_host`, `redis_port`, `redis_db`, `redis_password`, `redis_tls`

Connection details for the external Redis server. `redis_db` selects the
database index (`0` to `15`), so several applications can share one Redis.
Leave `redis_password` blank when Redis has no password.

### `access_token_salt`, `jwt_secret_key`

Salt for security tokens and signing key for sessions. Leave them blank and
the add-on generates strong values on first start and stores them under
`/config/access_token_salt` and `/config/jwt_secret_key` with owner-only
permissions, reusing them on every restart. Provide your own values only if
you migrate an existing installation; keep them stable, or existing security
tokens and sessions stop working.

### `root_url`

Public URL of Ghostfolio, for example `https://ghostfolio.example.com`. It is
used for generated links and the OIDC callback. Leave it blank to keep the
upstream default. A trailing slash is removed.

### `log_level`

Lowest level written to the log: `error`, `warn`, `log`, `debug`, or
`verbose`. More severe levels are always included.

### `enable_auth_token`

Allow sign in with a security token. Keep it enabled unless another sign in
method, such as OIDC, is set up.

### `enable_security_headers`

Send HTTP security headers like `Content-Security-Policy` and
`X-Frame-Options`. Experimental upstream feature, disabled by default.
`Strict-Transport-Security` is never set; configure it in your reverse proxy.

### `enable_mcp`

Enable the Model Context Protocol server at `/mcp`. Experimental upstream
feature, disabled by default.

### `api_key_coingecko_demo`, `api_key_coingecko_pro`

Optional CoinGecko API keys for cryptocurrency market data.

### `oidc_enabled`, `oidc_issuer`, `oidc_client_id`, `oidc_client_secret`

Sign in with an OpenID Connect provider, for example authentik. Experimental
upstream feature. When enabled, all three settings are required. Register
`<root_url>/api/auth/oidc/callback` as the redirect URI at the provider and
set `root_url` to the public address. Extra OIDC settings such as
`OIDC_SCOPE` can be passed through `env_vars`.

### `env_vars`

Advanced upstream variables for Ghostfolio settings the structured options do
not expose. Each entry has a `name` and a `value`:

```yaml
env_vars:
  - name: REQUEST_TIMEOUT
    value: "5000"
  - name: TRUST_PROXY
    value: "1"
```

Names must match `[A-Z][A-Z0-9_]*`. The add-on rejects:

- variables already managed by the options above (database, Redis, secrets,
  listener, root URL, log levels, feature flags, API keys, and OIDC)
- adapter and runtime variables (such as `PATH`, `NODE_OPTIONS`, or
  `LD_PRELOAD`)
- malformed names
- values containing control characters

## Managed behavior

The add-on always binds Ghostfolio to `0.0.0.0:3333` so the published port
and the health check stay valid. Options are parsed as root, because the
Supervisor keeps them root-only, and the application then runs as the
upstream `node` user. No Linux capabilities are granted.

## Persistent Data

Ghostfolio keeps its authoritative state in PostgreSQL. Back up the database
separately; Home Assistant backups only capture the add-on configuration
directory.

| Data | Stored at |
| --- | --- |
| Portfolios, accounts, activities, users | external PostgreSQL |
| Cache and job queues | external Redis |
| Generated access token salt | `/config/access_token_salt` |
| Generated JWT secret key | `/config/jwt_secret_key` |

## Security updates

Ghostfolio is repackaged from the immutable upstream image. Some CVEs in its
operating system or Node.js layers can only be resolved when the Ghostfolio
project publishes a rebuilt image. Renovate checks upstream once a week
and opens an automatic update once a release is available, so the fastest way
to pick up fixes is to keep the add-on updated.

## License and Support

Ghostfolio is provided under the GNU Affero General Public License v3.0. See
[LICENSE.upstream](LICENSE.upstream). This add-on runs the unmodified upstream
image; the corresponding source is available in the
[upstream repository](https://github.com/ghostfolio/ghostfolio).

This repository packages upstream software for Home Assistant and does not
imply endorsement or official support by the Ghostfolio authors. Report
application issues to the [upstream project](https://github.com/ghostfolio/ghostfolio)
and packaging issues in this repository.
