# Home Assistant Tududi Add-on

Home Assistant packaging for [Tududi](https://github.com/chrisvel/tududi), a
self-hosted task management and life organization system for tasks, projects,
notes, areas, and habits.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Install Tududi.
3. Set the initial user email and password.
4. Start the add-on and open its web interface on port `3002`.

The SQLite database, uploads, database backups, Tududi export backups, generated
session secret, and CalDAV encryption key persist in the add-on configuration
directory.

## Documentation

See [DOCS.md](DOCS.md) for configuration, persistence, feature flags, and
advanced upstream environment variables.

## License

Tududi is distributed under the MIT License. See
[LICENSE.upstream](LICENSE.upstream).

This add-on is independent packaging and is not officially supported by the
Tududi authors.
