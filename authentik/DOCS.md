# authentik Add-on Documentation

## Requirements

authentik does not bundle a database or cache. Before starting the add-on,
provide:

- An external **PostgreSQL** server (version 12 or newer) with an empty
  database and a user that owns it.
- An external **Redis** server.

Both must be reachable from the Home Assistant host. Example PostgreSQL setup:

```sql
CREATE USER authentik WITH PASSWORD 'a-strong-password';
CREATE DATABASE authentik OWNER authentik;
```

## Access

authentik listens on port `9000` (HTTP) and `9443` (HTTPS). Home Assistant
ingress is not used: authentik serves its interface and API from the root path
and issues absolute redirects, so it cannot follow the dynamic sub-path that
ingress proxies under. Reach it directly on port `9000`, or place your own
reverse proxy in front for TLS.

Complete the initial setup at `http://<host>:9000/if/flow/initial-setup/` to
create the first administrator account.

## Configuration

### `postgres_host`, `postgres_port`, `postgres_db`, `postgres_user`, `postgres_password`

Connection details for the external PostgreSQL server.

### `redis_host`, `redis_port`, `redis_db`, `redis_password`

Connection details for the external Redis server. The password is optional; the
database number selects a Redis logical database (0-15).

### `log_level`

Log verbosity: `trace`, `debug`, `info`, `warning`, or `error`.

### `error_reporting`

Send anonymized error reports to the authentik project. Disabled by default.

### `secret_key`

Signing key used for sessions and tokens. Leave it blank and the add-on
generates a strong key on first start and stores it under `/config/secret_key`
with owner-only permissions, reusing it on every restart. Provide your own key
only if you migrate an existing installation; keep it stable, or existing
sessions and tokens are invalidated.

## Managed behavior

The add-on always disables upstream update checks and startup telemetry, since
Home Assistant manages updates and no usage data should leave the host. These
are not configurable.

## Persistent Data

authentik keeps its authoritative state in PostgreSQL and Redis. The file paths
below are redirected into the add-on configuration directory so uploaded and
generated files survive restarts and are captured by Home Assistant backups:

| Data | Container path | Stored at |
| --- | --- | --- |
| Uploaded and generated files | file storage | `/config/data` |
| Discovered TLS certificates | cert discovery dir | `/config/certs` |
| Custom email templates | template dir | `/config/templates` |
| Generated secret key | - | `/config/secret_key` |

Drop externally issued certificates into `/config/certs` and custom email
templates into `/config/templates` to have authentik pick them up.

## Security updates

authentik is repackaged from the immutable upstream image. That image bundles a
full operating system, Go binaries, and a Python environment, so some HIGH
severity CVEs in those layers can only be resolved when the authentik project
publishes a rebuilt image. Renovate checks upstream every six hours and opens an
automatic update once a release is available, so the fastest way to pick up
fixes is to keep the add-on updated. Findings without an upstream fix are
tracked; those with an available fix are recorded as time-boxed exceptions until
the next upstream release clears them.

## License and Support

authentik is provided primarily under the MIT License. Content under the
upstream `website/` directory is CC BY-SA 4.0, and anything under
`authentik/enterprise/` is covered by a separate enterprise license; enterprise
features stay locked unless you activate a license. See
[LICENSE.upstream](LICENSE.upstream).

This repository packages upstream software for Home Assistant and does not imply
endorsement or official support by the authentik authors. Report application
issues to the [upstream project](https://github.com/goauthentik/authentik) and
packaging issues in this repository.
