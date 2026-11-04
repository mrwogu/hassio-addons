# Changelog

## 1.21.3-3

- Ship helper package notice in the image

## 1.21.3-2

- Fix storage docs, drop host label, strict option patterns

## 1.21.3-1

- Package Alloy [v1.21.3](https://github.com/grafana/alloy/releases/tag/v1.21.3).
- Render an Alloy pipeline from the add-on options that tails the Traefik
  access and application logs from `/share/traefik/logs` and pushes them to
  Loki.
- Parse Traefik access log timestamps and keep `host` and `status` as labels;
  every other field stays in the log line for `| json` queries.
- Allow extra log files under `/share` through the `extra_files` option.
- Keep read positions under the add-on configuration directory so restarts do
  not duplicate or lose lines.
