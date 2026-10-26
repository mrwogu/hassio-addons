# Postgres Backup Add-on Documentation

## Why

The Postgres 16 add-on declares a cold backup. For every Home Assistant
backup, including the nightly automatic one, Supervisor stops the database,
copies its files, and starts it again. That takes a few minutes, and every
app using the database fails in that window.

This add-on makes a hot backup instead. Supervisor runs its `backup_pre` hook
right before it archives this add-on. The hook runs `pg_dumpall` against the
running server and writes a gzip-compressed SQL dump into the add-on
configuration folder, which goes into the same backup. Postgres is never
stopped.

## Setup

1. Install the add-on.
2. Set `password` to the superuser password from the Postgres 16 add-on
   options. Keep `host`, `port`, and `username` unless you changed them there.
3. Start the add-on. The log shows whether Postgres accepts connections.
4. Keep the add-on running: leave **Start on boot** enabled and enable the
   **Watchdog**. Supervisor runs the hook only inside a running add-on. When
   the add-on is stopped, the backup silently contains only the older dumps.
5. Exclude Postgres 16 from the automatic backup. Go to **Settings > System >
   Backups > Backup settings**, open the selection of apps (add-ons) included
   in the backup, and untick **Postgres 16**. Make sure **Postgres Backup**
   stays ticked. Otherwise the cold backup still stops the database.

Other add-ons from the same repository as Postgres 16, like Redis or
Prometheus, also use a cold backup. Untick them only if you can live without
their data in the backup. This add-on dumps only Postgres.

## Configuration

### `host`, `port`, `username`, `password`

Connection to the Postgres server. The default host `3b88f413-postgres-16` is
the Postgres 16 add-on on the internal Supervisor network. The user must be a
superuser, because `pg_dumpall` reads every database and role. The password
reaches the client tools only through the `PGPASSWORD` environment variable
and is never written to the log.

### `keep`

How many dump files stay in the dumps folder. After each new dump the oldest
files above this number are deleted. All kept dumps go into every backup, so
a higher number makes backups bigger.

### `restore`

Empty by default. See [Restore](#restore).

## Where the dumps are

Inside the add-on the dumps are in `/config/dumps`. On the host this is
`addon_configs/<prefix>_postgres-backup/dumps`, also visible in the
`addon_configs` share of the Samba add-on. Files are named
`pg_dumpall-YYYYmmdd-HHMMSS.sql.gz`, with the time in UTC.

A dump is written to a hidden temporary file first and renamed only after
`pg_dumpall` finished without error. When the dump fails, the hook exits with
an error, Supervisor marks this add-on's part of the backup as failed, and the
reason is in the add-on log.

## Test without waiting for the night

1. Go to **Settings > System > Backups** and create a new backup.
2. Choose a partial backup with only **Postgres Backup** selected.
3. When it is done, the add-on log shows `Wrote pg_dumpall-...sql.gz` and the
   new file is in the dumps folder.

To check the content, unpack the file and look at the SQL, for example
`gunzip -c pg_dumpall-...sql.gz | less`.

## Restore

When the whole Home Assistant system is restored from a backup, Postgres 16
comes back empty, because it is excluded from the backup. The data is in the
dumps of this add-on.

1. Install the Postgres 16 add-on again, or restore it from the backup, and
   start it. Use the same superuser password as before. The dump sets all
   role passwords back to their values at dump time.
2. Restore this add-on from the Home Assistant backup. The dumps come back
   with it.
3. Stop the apps that use the database, like immich, paperless, or authentik.
4. Turn off the watchdog of this add-on for the restore, so a failed restore
   is not started again automatically.
5. Set `restore` to `latest`, or to an exact file name from the dumps folder,
   and start the add-on.
6. Read the add-on log. It shows the dump size, every `psql` error, and how
   many errors there were. A few errors like `role "postgres" already exists`
   are expected, because the bootstrap role exists on every new server.
7. Clear `restore`, save, and restart the add-on. Turn the watchdog on again.
   Start the apps.

The dump was made with `--clean`, so loading it drops and recreates every
database and role in it. Stop the apps using the database first, or restore
into an empty server. A database with active connections cannot be dropped
and ends up with duplicated or mixed data. A large database, like the one
of immich, takes minutes to load.

The add-on waits up to about five minutes for Postgres to accept
connections. When Postgres does not get ready, or `psql` fails, the add-on
stops with an error and the restore can be started again.

After a successful restore the add-on writes a marker file next to the dump,
`<dump name>.restored`. With the marker present the same dump is never loaded
again, so a forgotten `restore` option does not wipe newer data on the next
restart. Delete the marker to load the same file again. While `restore` is
set, the backup hook refuses to make new dumps. Otherwise a new dump would
become `latest` and be loaded on the next restart.

A dump can also be loaded by hand from any machine with the PostgreSQL 16
client:

```sh
gunzip -c pg_dumpall-YYYYmmdd-HHMMSS.sql.gz | psql -h <host> -U postgres -d postgres
```

## Limitations

- `pg_dumpall` makes a logical dump: all roles and all databases as plain
  SQL. Each database is consistent on its own, but the databases are dumped
  one after another, not in one snapshot.
- There is no point-in-time recovery. A restore brings back the state from
  the time of the dump.
- Load the dump into a PostgreSQL 16 server with the same extensions
  available as the original one.
- The client tools are PostgreSQL 16. Change `host` only to servers of the
  same major version.
