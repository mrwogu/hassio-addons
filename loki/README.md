# Home Assistant Loki Add-on

Home Assistant packaging for [Loki](https://github.com/grafana/loki), the log
aggregation backend from Grafana. It stores logs on disk, deletes them after a
retention period, and answers LogQL queries from Grafana.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Install Loki and start it.
3. In Grafana add a Loki data source with the URL `http://<hostname>:3100`.
   The hostname is shown on the Loki add-on page, for example `ad52851a-loki`.
4. Install the Alloy add-on to ship logs into Loki.

The API has no authentication and no host port by default. Keep it that way.

## Documentation

See [DOCS.md](DOCS.md) for retention and storage.

## License

Loki is distributed under the GNU Affero General Public License v3.0. See
[LICENSE.upstream](LICENSE.upstream). The image is built from the unmodified
upstream image; the corresponding source is available in the
[upstream repository](https://github.com/grafana/loki).

The entrypoint also ships BusyBox (GPL-2.0), jq (MIT), Oniguruma (BSD-2-Clause)
and musl libc (MIT) from Alpine 3.22, unmodified. Package, license and
homepage data is in `/opt/addon/NOTICE` inside the image. Their source is
referenced by the APKBUILD recipes for the `busybox`, `jq`, `oniguruma` and
`musl` packages in the [aports tree](https://wiki.alpinelinux.org/wiki/Aports_tree).

This add-on is independent packaging and is not officially supported by
Grafana Labs.
