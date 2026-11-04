# Alloy Add-on Documentation

Start the Loki add-on first. Alloy has `startup: application`, so Home
Assistant starts it after the services. Lines read while Loki is unreachable
are retried by Alloy for a limited time and then dropped.

## Configuration

### `loki_url`

Full push endpoint of Loki, for example
`http://ad52851a-loki:3100/loki/api/v1/push`. The host part is the Hostname
shown on the Loki add-on page. Only plain `http` or `https` URLs are accepted.

### `traefik_logs`

When enabled, Alloy tails these files from the Traefik Proxy add-on:

- `/share/traefik/logs/access.jsonl` as `log_type="access"`
- `/share/traefik/logs/traefik.log` as `log_type="app"`

Both get `job="traefik"`. Rotated files (`.1`, `.gz`) are not matched.
Traefik rotates with `copytruncate`, and Alloy follows the truncated file.

### `extra_files`

More files under `/share`. Each entry has a `path` (letters, digits, `.`, `_`,
`-`, `/`, and `*` for globs) and a `job` label. These lines are shipped as
plain text with `log_type="file"`.

At least one source must be enabled. The add-on refuses to start otherwise.

## Labels

For the Traefik access log Alloy parses the JSON line and sets:

- the entry timestamp from `StartUTC`
- label `host` from `RequestHost`
- label `status` from `DownstreamStatus`

Everything else stays in the line. Request headers that the Traefik add-on
logs through `access_log_headers` appear as `request_<Header>`, and LogQL's
`json` parser turns `request_X-Media-User` into `request_X_Media_User`.

## Example queries

Requests per user in the last day:

```logql
sum by (request_X_Media_User) (
  count_over_time({job="traefik", log_type="access"} | json
    | request_X_Media_User != "" [1d])
)
```

Server errors by host:

```logql
sum by (host) (count_over_time({job="traefik", log_type="access", status=~"5.."} [1h]))
```

Items opened by one user:

```logql
{job="traefik", log_type="access"} | json
  | request_X_Media_User = "alice@example.com"
  | line_format "{{.request_X_Media_Item}}"
```

## Storage

`config.alloy` is rendered at every start from the options. Read positions are
kept in `data/`, so a restart neither repeats nor skips lines. Deleting `data/`
makes Alloy read all matching files again from the start.

## Debug UI

Alloy serves its UI on port `12345` inside the Supervisor network. The port is
not published on the host and has no authentication.
