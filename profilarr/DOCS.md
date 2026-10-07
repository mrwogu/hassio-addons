# Profilarr Add-on Documentation

## Access

Profilarr listens on port `6868`. Open the add-on web interface directly on
that port. The add-on does not publish additional ports.

## First start

With the default `auth: on`, Profilarr shows a setup screen until the first
local account exists. Create the administrator account right after the first
start, before exposing the port to other networks. Users, sessions, and the
optional local network bypass are managed in **Settings > Security**.

## Configuration

### `auth`

- `on` uses local Profilarr accounts. This is the default.
- `oidc` signs in through an OpenID Connect provider such as authentik. It
  requires `origin`, `oidc_discovery_url`, `oidc_client_id`, and
  `oidc_client_secret`.
- `off` disables all authentication, including API key checks. Use it only
  behind a trusted proxy that authenticates every request. The adapter logs a
  warning on each start in this mode.

### `origin`

Public URL when Profilarr runs behind a reverse proxy, for example
`https://profilarr.example.com`. Profilarr uses it for OIDC redirects and
cookie security. The OIDC redirect URL is `{origin}/auth/oidc/callback`.

### `api_key`

Optional plaintext secret for `X-Api-Key` authentication. It must contain at
least 32 characters without whitespace. While set, it overrides the API key
stored in the database. Clearing it reactivates the stored key.

### `oidc_discovery_url`, `oidc_client_id`, `oidc_client_secret`

OpenID Connect client settings used when `auth` is `oidc`.

### `env_vars`

Extra upstream environment variables, for example `PARSER_HOST`,
`PARSER_PORT`, or `PROFILARR_BULLETIN_URL`. Names must be uppercase
environment identifiers. Managed adapter variables, `PUID`, `PGID`, `UMASK`,
`*_FILE` secret indirection, `DENO_*`, and control characters are rejected.

## Parser service

Custom format and quality profile testing needs the separate
`profilarr-parser` service. Linking, syncing, and other features work without
it. This add-on does not bundle the parser. If you run it elsewhere, set
`PARSER_HOST` and `PARSER_PORT` through `env_vars`.

## Persistent data

| Data | Stored at |
| --- | --- |
| SQLite database and settings | add-on config `/config/data/profilarr.db` |
| Linked configuration databases | add-on config `/config/data/databases` |
| Backups | add-on config `/config/backups` |
| Logs | add-on config `/config/logs` |

Home Assistant backups include these paths. The upstream entrypoint creates the
directories and owns them as UID and GID `1000`.

## Managed behavior

The adapter binds Profilarr to port `6868`, keeps all data under `/config`, and
hands off to the unmodified upstream entrypoint. `tini` stays PID 1 and forwards
signals. Home Assistant sets `TZ` from the system time zone.

## License and support

Profilarr is provided under the GNU Affero General Public License v3.0. This
repository packages the unmodified upstream image for Home Assistant. The
corresponding source is available in the
[upstream repository](https://github.com/Dictionarry-Hub/profilarr). This
packaging does not imply endorsement or official support by the upstream
project. Report application issues to
[Profilarr](https://github.com/Dictionarry-Hub/profilarr) and packaging issues
in this repository.
