# ddclient Home Assistant Add-on

Home Assistant packaging for [ddclient](https://github.com/ddclient/ddclient), a
Perl dynamic DNS client that keeps DNS records for many providers pointed at
your current IP address. The add-on wraps the maintained
[LinuxServer.io image](https://github.com/linuxserver/docker-ddclient).

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Install ddclient.
3. Put your full `ddclient.conf` in the `config` option (provider, credentials,
   and hosts to update).
4. Start the add-on. ddclient runs as a daemon and updates records on the
   interval set by `daemon=` in the configuration.

The configuration and the ddclient cache persist in the add-on configuration
directory. ddclient makes only outbound connections and needs no ports.

## Documentation

See [DOCS.md](DOCS.md) for configuration examples, persistent data, and provider
notes.

## License

ddclient is distributed under the GNU General Public License v2.0 (or later).
Read [LICENSE.upstream](LICENSE.upstream). This add-on is independent packaging
and is not officially supported by the ddclient or LinuxServer.io authors.
