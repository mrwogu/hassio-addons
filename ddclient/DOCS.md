# ddclient Add-on Documentation

## Overview

ddclient updates dynamic DNS entries for accounts on many providers (Cloudflare,
DuckDNS, Namecheap, deSEC, DynDNS, and dozens more). This add-on wraps the
[LinuxServer.io ddclient image](https://github.com/linuxserver/docker-ddclient)
and turns the add-on `config` option into `/config/ddclient.conf` before the
daemon starts.

ddclient makes only outbound connections, so the add-on exposes no ports and no
web interface.

## Configuration

### `config`

The complete contents of `ddclient.conf`. The add-on writes it to
`/config/ddclient.conf` with owner-only permissions (`0600`) on every start and
never prints it to the log. See the
[upstream ddclient.conf reference](https://github.com/ddclient/ddclient/blob/main/ddclient.conf.in)
for all directives.

Set `daemon=` to the refresh interval in seconds. Provide at least one host to
update.

#### Cloudflare example

```
daemon=300
ssl=yes
use=web
protocol=cloudflare
zone=example.com
ttl=1
login=token
password=CLOUDFLARE_API_TOKEN
example.com,www.example.com
```

#### DuckDNS example

```
daemon=300
ssl=yes
use=web
protocol=duckdns
password=DUCKDNS_TOKEN
your-subdomain
```

## Persistent Data

| Data | Path |
| --- | --- |
| ddclient configuration | `/config/ddclient.conf` |
| ddclient cache | managed by the upstream image under `/config` |

The configuration is regenerated from the add-on options on every start, so edit
the `config` option (not the file) to make changes. Home Assistant add-on
backups include the mapped add-on configuration directory.

## Security

The configuration holds provider API tokens and passwords. Keep the add-on
private, and never paste its `config` value or `/config/ddclient.conf` into
logs, issues, or attachments. The adapter validates the option and rejects
control characters that could corrupt the file.

## Security updates

ddclient is repackaged from the immutable LinuxServer.io image. Renovate checks
the upstream image tag and digest every six hours and opens an automatic update
when a new build is available, so keeping the add-on updated is the fastest way
to pick up fixes. Findings with an available fix are recorded as time-boxed
exceptions until the next upstream image clears them.

## License and Support

ddclient is distributed under the GNU General Public License v2.0 (or later).
See [LICENSE.upstream](LICENSE.upstream).

This repository packages upstream software for Home Assistant and does not imply
endorsement or official support by the ddclient or LinuxServer.io authors. Report
application issues to the [upstream project](https://github.com/ddclient/ddclient)
and packaging issues in this repository.
