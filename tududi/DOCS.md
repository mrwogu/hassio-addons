# Tududi Add-on Documentation

## Access

Tududi listens on port `3002`. Open the add-on web interface directly on that
port. The add-on does not publish additional ports.

## First start

Set a valid `user_email` and a `user_password` containing at least six
characters before the first start. The adapter passes these credentials only
while the database contains no users. After successful bootstrap, password
changes made inside Tududi persist across restarts. Clear both options after
the first successful start to remove bootstrap credentials from add-on
configuration.

The adapter generates a cryptographically random session secret on first start
when `session_secret` is blank. It stores the secret at
`/config/session_secret` with mode `0600`. Changing the secret invalidates
existing sessions. It also generates a separate persistent CalDAV encryption
key for remote-calendar credentials.

## Configuration

### `user_email`

Initial administrator email. It must use a valid email format and is passed to
upstream only while the database contains no users.

### `user_password`

Initial administrator password containing at least six characters. Store it
securely. The value is never written to the adapter log and is ignored after
the database contains a user.

### `session_secret`

Optional session signing secret containing at least 32 characters. Leave blank
to generate and persist one under `/config`.

### `allowed_origins`

Comma-separated CORS origins. The default allows direct local access on port
`3002`. Set this to the public origin when using a reverse proxy.

### `trust_proxy`

Trust the first reverse-proxy hop when enabled. Keep disabled for direct
access. Enable only when the add-on is behind a trusted proxy.

### `cookie_secure`

Session cookie mode: `auto`, `true`, or `false`. Use `auto` for normal
deployments. Set `true` when HTTPS is guaranteed end to end.

### `file_upload_limit_mb`

Maximum upload size per file. Valid range is `1` to `1024` MB.

### Feature flags

- `disable_scheduler` disables background scheduled jobs.
- `disable_telegram` disables Telegram integration by default.
- `swagger_enabled` controls the authenticated Swagger API page.
- `enable_backups` enables Tududi's backup feature under `/config/backups`.
- `enable_caldav` enables CalDAV synchronization with a generated encryption
  key stored under `/config`.
- `enable_mcp` enables the Tududi MCP endpoint.

Telegram, OIDC, email, CalDAV credentials, AI providers, and other advanced
upstream settings can be passed through `env_vars`. Names must be uppercase
environment identifiers. Managed adapter variables and control characters are
rejected.

## Persistent data

| Data | Container path | Stored at |
| --- | --- | --- |
| SQLite database and database backups | `/config/db` | add-on config `/config/db` |
| User avatars and task attachments | `/config/uploads` | add-on config `/config/uploads` |
| Tududi export backups | `/app/backend/backups` | add-on config `/config/backups` |
| Session signing secret | `/config/session_secret` | add-on config `/config/session_secret` |
| CalDAV encryption key | `/config/caldav_encryption_key` | add-on config `/config/caldav_encryption_key` |

Home Assistant backups include these paths. Logs are not persisted; use the
Home Assistant add-on log viewer.

## Managed behavior

The adapter forces production mode, binds Tududi to port `3002`, routes all
mutable data under `/config`, and preserves the upstream migration and signal
handling flow.

## License and support

Tududi is provided under the MIT License. This repository packages upstream
software for Home Assistant and does not imply endorsement or official support
by the upstream project. Report application issues to
[Tududi](https://github.com/chrisvel/tududi) and packaging issues in this
repository.
