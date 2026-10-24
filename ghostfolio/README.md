# Ghostfolio Home Assistant Add-on

Home Assistant packaging for [Ghostfolio](https://ghostfol.io/), open source
wealth management software for tracking stocks, ETFs, and cryptocurrencies
across multiple platforms.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Prepare an external PostgreSQL database and a Redis server (see
   [DOCS.md](DOCS.md)).
3. Install Ghostfolio.
4. Enter the PostgreSQL and Redis connection details in the configuration.
5. Start the add-on, open the interface on port `3333`, and click
   **Get Started** to create the first user. The first user becomes the
   administrator.

Ghostfolio keeps its state in external PostgreSQL and uses Redis for cache
and job queues. The generated access token salt and JWT secret key persist in
the add-on configuration directory.

## Documentation

See [DOCS.md](DOCS.md) for requirements, configuration options, and data paths.

## License

Ghostfolio is distributed under the GNU Affero General Public License v3.0. See
[LICENSE.upstream](LICENSE.upstream). The image is built from the unmodified
upstream image; the corresponding source is available in the
[upstream repository](https://github.com/ghostfolio/ghostfolio).

This add-on is independent packaging and is not officially supported by the
Ghostfolio authors.
