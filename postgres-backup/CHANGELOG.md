# Changelog

## 3.24.3-1

- Dump the Postgres 16 add-on with `pg_dumpall` from the Supervisor
  `backup_pre` hook, so Home Assistant backups get a consistent SQL dump
  without stopping the database.
- Keep the newest dumps under the add-on configuration directory and load one
  back with the `restore` option.
- Built on Alpine Linux [3.24.3](https://gitlab.alpinelinux.org/alpine/aports/-/tags/v3.24.3)
  with its PostgreSQL 16 client tools.
