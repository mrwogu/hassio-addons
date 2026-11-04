# Home Assistant Alloy Add-on

Home Assistant packaging for [Grafana Alloy](https://github.com/grafana/alloy).
It tails log files under `/share` and pushes them to Loki. It replaces
Promtail, which is end of life.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Install and start the Loki add-on first.
3. Install Alloy and set `loki_url` to
   `http://<hostname>:3100/loki/api/v1/push`, with the hostname from the Loki page.
4. Start Alloy. Traefik logs are collected by default.

## Documentation

See [DOCS.md](DOCS.md) for the log pipeline, labels, extra files, and example
queries.

## License

Alloy is distributed under the Apache License 2.0. See
[LICENSE.upstream](LICENSE.upstream). The image is built from the unmodified
upstream image.

The entrypoint also ships BusyBox (GPL-2.0), jq (MIT), Oniguruma (BSD-2-Clause)
and musl libc (MIT) from Alpine 3.22, unmodified. Their sources are in the
Alpine packages `busybox`, `jq`, `oniguruma` and `musl`.

This add-on is independent packaging and is not officially supported by
Grafana Labs.
