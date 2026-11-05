# FlareSolverr Add-on Documentation

## Access

FlareSolverr listens on port `8191` and publishes it on the host. Other
services point at `http://<home-assistant-host>:8191`. For example in Prowlarr
add an indexer proxy of type FlareSolverr with that URL.

There is no authentication. Do not expose the port to the internet.
FlareSolverr drives a real browser for every request, so keep it on a trusted
network.

## Configuration

### `log_level`

`info` or `debug`.

### `log_html`

Writes the full HTML of visited pages to the log. Very verbose. Turn it on only
when you debug a failing solve.

### `disable_media`

Blocks images, CSS and fonts in the browser. Saves bandwidth and CPU, but a few
challenges may stop working.

### `env_vars`

Extra upstream environment variables, for example `PROXY_URL` for a default
proxy. Names must be uppercase environment identifiers. Managed adapter
variables, `PATH`, `LD_*`, `PYTHON*` and control characters are rejected. The
add-on log shows only the names of these variables, never the values.

Do not put proxy credentials here. When `PROXY_URL` is set with
`PROXY_USERNAME` or `PROXY_PASSWORD`, FlareSolverr 3.5.2 copies them into every
`/v1` request that has no proxy of its own, and then writes the whole request
to its own log at `info` level. The password ends up in the log in clear text.
Use a proxy without credentials, or send the proxy with each request from the
client.

## Storage

FlareSolverr keeps sessions in memory, so there is nothing to back up. The
add-on configuration directory is mapped but not used.

## Resources

Each request starts a Chromium instance. Plan for at least 512 MB of free RAM
per parallel request.
