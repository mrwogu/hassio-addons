# Home Assistant Profilarr Add-on

Home Assistant packaging for [Profilarr](https://github.com/Dictionarry-Hub/profilarr),
a configuration management platform that builds, tests, and syncs quality
profiles, custom formats, and media settings across Radarr and Sonarr.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Install Profilarr.
3. Start the add-on and open its web interface on port `6868`.
4. Create the administrator account in the setup screen.

The SQLite database, linked configuration databases, backups, and logs persist
in the add-on configuration directory.

## Documentation

See [DOCS.md](DOCS.md) for authentication, reverse proxy, OIDC, the optional
parser service, and advanced upstream environment variables.

## License

Profilarr is distributed under the GNU Affero General Public License v3.0. See
[LICENSE.upstream](LICENSE.upstream). The image is built from the unmodified
upstream image; the corresponding source is available in the
[upstream repository](https://github.com/Dictionarry-Hub/profilarr).

This add-on is independent packaging and is not officially supported by the
Profilarr authors.
