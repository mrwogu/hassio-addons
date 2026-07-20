# Bonds Home Assistant Add-on

Home Assistant packaging for [Bonds](https://github.com/naiba/bonds), a personal relationship manager built with Go and React.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Install Bonds.
3. Review the configuration and set `app_url` to the URL used to access Bonds.
4. Start the add-on and open its web interface on port `8080`.

Data, uploads, search indexes, backups, and generated secrets persist in the add-on configuration directory.

## Documentation

See [DOCS.md](DOCS.md) for configuration, data paths, and backup details.

## License

Bonds is distributed under the Business Source License 1.1. Commercial use and managed hosting are restricted. Read [LICENSE.upstream](LICENSE.upstream) before use.

This add-on is independent packaging and is not officially supported by the Bonds authors.
