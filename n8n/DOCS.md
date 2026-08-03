# n8n Add-on Documentation

## Storage and database

n8n stores its user folder under `/config/n8n`. This includes the SQLite
database when `database` is `sqlite`, encryption state, logs, and other
instance data. Home Assistant backups include this directory.

SQLite is the default and needs no external service. For PostgreSQL, set
`database` to `postgresdb` and provide an external PostgreSQL server:

- `postgres_host`, `postgres_port`, `postgres_db`, `postgres_user`,
  `postgres_password`
- optional `postgres_schema` and `postgres_ssl`

The database is not created by the add-on. Create an empty database and a
dedicated user before startup. PostgreSQL is recommended for larger or
production installations.

## Queue mode

The default `execution_mode` is `regular`. To use queue mode, set it to
`queue`, use external PostgreSQL, and provide an external Redis server through
`redis_host`, `redis_port`, `redis_db`, `redis_username`, `redis_password`, and
`redis_tls`.

Queue mode is intended for a deployment with separate n8n workers. This
single add-on runs the main n8n process only; it does not start Redis or worker
containers.

## URLs and timezone

Set `timezone` to an IANA timezone such as `Europe/Warsaw`. This controls
schedule-based workflows. Set `editor_base_url` and `webhook_url` when n8n is
reachable through a reverse proxy or public hostname. Use HTTPS at the proxy
and keep the add-on's direct port private when exposing webhooks publicly.

## Security

The add-on generates a random n8n encryption key on first start when
`encryption_key` is blank. It stores the key at `/config/encryption_key` with
mode `0600`; keep it stable because changing it can make saved credentials
unusable.

The add-on forces these settings:

- `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true`
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=true`
- `N8N_DIAGNOSTICS_ENABLED=false`
- `N8N_VERSION_NOTIFICATIONS_ENABLED=false`

Advanced `env_vars` entries must use uppercase environment names. Managed,
adapter, loader, and dynamic-library variables cannot be overridden. Values
containing control characters are rejected.

## License and support

n8n uses the Sustainable Use License. It permits personal, non-commercial, and
internal business use, subject to its restrictions. Enterprise files use
separate licensing. Read [LICENSE.upstream](LICENSE.upstream) before
redistribution or commercial use.

Report application issues to the [n8n project](https://github.com/n8n-io/n8n)
and packaging issues in this repository.
