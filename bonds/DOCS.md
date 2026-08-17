# Bonds Add-on Documentation

## Storage and database

Bonds uses SQLite by default. To use PostgreSQL, set `database` to `postgres`
and provide an external PostgreSQL server:

- `postgres_host`, `postgres_port`, `postgres_db`, `postgres_user`,
  `postgres_password`
- `postgres_sslmode` to select the TLS mode

The add-on does not create or bundle PostgreSQL. Create an empty database and
a dedicated user before startup. The PostgreSQL server must be reachable from
the Home Assistant host.

Upstream backup and restore shell out to the bundled `pg_dump` and `psql`
version 18 clients, so the PostgreSQL server major version must be 18 or
lower.

The adapter does not migrate database contents. Perform any SQLite to
PostgreSQL migration separately before switching. An existing
`/config/bonds.db` is left untouched and unused in PostgreSQL mode; the
adapter logs a warning when it finds one.

## Access

Bonds listens on port `8080`. Ingress is disabled because upstream base path support has not been confirmed. Set `app_url` to the full URL used by browsers, for example `http://homeassistant.local:8080`.

## Configuration

### `database`

Select `sqlite` for the local database or `postgres` for an external
PostgreSQL database.

### `postgres_host`, `postgres_port`, `postgres_db`, `postgres_user`, `postgres_password`

Connection details for the external PostgreSQL server. These values are used
only when `database` is `postgres`. `postgres_host`, `postgres_db`, and
`postgres_user` are required in that mode.

An empty `postgres_password` is omitted from the connection string, which
keeps `PGPASSFILE`, `trust`, and `peer` authentication usable.

Example setup:

```sql
CREATE USER bonds WITH PASSWORD 'a-strong-password';
CREATE DATABASE bonds OWNER bonds;
```

### `postgres_sslmode`

TLS mode for the PostgreSQL connection. Default: `require`.

| Value | Behavior |
| --- | --- |
| `disable` | No TLS. Credentials and contact data cross the network in clear text. |
| `require` | Encrypted, but the server certificate is not verified, so an active attacker on the network path can impersonate the database. |
| `verify-full` | Encrypted, and the certificate and hostname are verified against the certificate authorities bundled in the image. |

Prefer `verify-full`. It requires a server certificate issued by a publicly
trusted certificate authority, because the add-on exposes no option for a
private authority bundle.

### `app_url`

Public URL used by Bonds when generating links.

### `jwt_secret`

Optional JWT signing secret. Leave blank to generate a persistent secret in `/config/.secrets`. Changing this value can invalidate existing sessions.

### `settings_encryption_key`

Optional application settings encryption key. Leave blank to generate a persistent key in `/config/.secrets`. Changing this value can make encrypted settings unreadable.

### `storage_max_size_mb`

Maximum uploaded file size in megabytes. Must be a positive integer.

### `backup_cron`

Optional cron schedule for application backups. Default: `0 3 * * *`.

### `backup_retention_days`

Number of days to retain backups. Must be a positive integer.

### `debug`

Enables detailed upstream diagnostics when `true`. Keep disabled for normal use.

## Persistent Data

SQLite mode stores application state in the add-on configuration directory:

| Data | Path |
| --- | --- |
| SQLite database | `/config/bonds.db` |
| Uploads | `/config/uploads` |
| Search index | `/config/bonds.bleve` |
| Backups | `/config/backups` |
| Generated secrets | `/config/.secrets` |

In PostgreSQL mode, the database is external. Uploads, search index, backups,
and generated secrets remain under `/config`; Home Assistant add-on backups
cover only that directory and never reach the PostgreSQL server directly.

Generated secrets are created atomically with mode `0600` and reused after restarts. Secret values are never printed by the adapter.

## Backup

Home Assistant add-on backups include the mapped add-on configuration directory. Stop Bonds before manually replacing its database or restoring individual files.

Upstream scheduled backups run inside the add-on and write archives to
`/config/backups`, so a Home Assistant add-on backup carries them along. In
SQLite mode the archive holds a consistent database copy. In PostgreSQL mode it
holds a `pg_dump` output of the external database, and restore replays it with
`psql`.

## License and Support

Bonds uses Business Source License 1.1. It is not an open source license before the change date. Commercial use requires a commercial license from the upstream licensor. Offering Bonds as a hosted or managed service is prohibited by the Additional Use Grant. Read [LICENSE.upstream](LICENSE.upstream) for complete terms.

This repository packages upstream software for Home Assistant. It does not imply endorsement or official support by the Bonds authors. Report Bonds application issues to the [upstream project](https://github.com/naiba/bonds). Report add-on packaging issues in this repository.
