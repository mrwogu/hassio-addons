# Home Assistant Postgres Backup Add-on

Hot backup of the Postgres 16 add-on for Home Assistant backups.

The Postgres 16 add-on uses a cold backup, so every Home Assistant backup
stops the database for a few minutes and everything using it fails in that
window. This add-on runs `pg_dumpall` from the Supervisor `backup_pre` hook
instead. The database keeps running and a consistent, gzip-compressed SQL
dump lands in the Home Assistant backup together with this add-on.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Install Postgres Backup.
3. Set `password` to the superuser password of the Postgres 16 add-on.
4. Start the add-on and enable the watchdog.
5. Exclude the Postgres 16 add-on from the automatic backup.

## Documentation

See [DOCS.md](DOCS.md) for setup, where the dumps are stored, testing, and
restore.

## License

The PostgreSQL client tools are distributed under the PostgreSQL License. See
[LICENSE.upstream](LICENSE.upstream). The image is built from the official
Alpine Linux image and the unmodified Alpine `postgresql16-client` package.

This add-on is independent packaging and is not officially supported by the
PostgreSQL Global Development Group or the Postgres 16 add-on authors.
