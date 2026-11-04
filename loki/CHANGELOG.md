# Changelog

## 3.7.9-2

- Document bundled helper licenses

## 3.7.9-1

- Package Loki [3.7.9](https://github.com/grafana/loki/releases/tag/v3.7.9).
- Run Loki as a single binary with filesystem storage under the add-on
  configuration directory.
- Translate the `retention_days` and `log_level` options into the Loki
  configuration and enable the compactor so old logs are deleted.
- Keep the HTTP API unpublished by default; other add-ons reach it by hostname.
