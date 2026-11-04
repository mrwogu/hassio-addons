# Loki Add-on Documentation

## Access

Loki listens on port `3100` inside the Supervisor network. The port is not
published on the host. Other add-ons reach it as `http://<hostname>:3100`,
where the hostname is shown on the add-on page (for example `ad52851a-loki`).
There is no authentication, so publish the port only on a trusted network.

## Configuration

### `retention_days`

How long logs are kept, from 1 to 3650 days. The compactor deletes expired
data about every ten minutes, after a two hour safety delay. Lowering the value
frees disk after the next compaction, not immediately.

### `log_level`

Verbosity of the Loki application log: `debug`, `info`, `warn`, or `error`.

## Storage

Everything lives in the add-on configuration directory:

- `loki.yaml` is rendered at every start from the options. Do not edit it.
- `data/` holds chunks, the index, the write-ahead log, and compactor state.

Loki is a single process with filesystem storage and a single replica. That is
enough for one home server. It is not a clustered setup.

Loki throttles writes when the disk it writes to is more than 90 percent full.
Keep free space on the Home Assistant data partition.

## Grafana

Add a data source of type Loki with the URL `http://<hostname>:3100`. If you
provision Grafana from files:

```yaml
apiVersion: 1
datasources:
  - name: Loki
    uid: loki
    type: loki
    access: proxy
    url: http://ad52851a-loki:3100
    editable: false
```

## Ready check

The container health check calls `/ready`. After a start Loki reports not ready
for up to a minute while the ingester joins its ring. That is normal.

## Backup

Logs are regenerable data. Exclude this add-on from backups if size matters.
