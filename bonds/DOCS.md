# Bonds Add-on Documentation

## Access

Bonds listens on port `8080`. Ingress is disabled because upstream base path support has not been confirmed. Set `app_url` to the full URL used by browsers, for example `http://homeassistant.local:8080`.

## Configuration

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

All application state uses the add-on configuration directory:

| Data | Path |
| --- | --- |
| SQLite database | `/config/bonds.db` |
| Uploads | `/config/uploads` |
| Search index | `/config/bonds.bleve` |
| Backups | `/config/backups` |
| Generated secrets | `/config/.secrets` |

Generated secrets are created atomically with mode `0600` and reused after restarts. Secret values are never printed by the adapter.

## Backup

Home Assistant add-on backups include the mapped add-on configuration directory. Stop Bonds before manually replacing its database or restoring individual files.

## License and Support

Bonds uses Business Source License 1.1. It is not an open source license before the change date. Commercial use requires a commercial license from the upstream licensor. Offering Bonds as a hosted or managed service is prohibited by the Additional Use Grant. Read [LICENSE.upstream](LICENSE.upstream) for complete terms.

This repository packages upstream software for Home Assistant. It does not imply endorsement or official support by the Bonds authors. Report Bonds application issues to the [upstream project](https://github.com/naiba/bonds). Report add-on packaging issues in this repository.
