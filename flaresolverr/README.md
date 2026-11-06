# Home Assistant FlareSolverr Add-on

Home Assistant packaging for
[FlareSolverr](https://github.com/FlareSolverr/FlareSolverr), a proxy server
that solves Cloudflare and DDoS-GUARD challenges with a real browser. Prowlarr
and similar tools use it to reach protected indexers.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Install FlareSolverr and start it.
3. In Prowlarr add an indexer proxy of type FlareSolverr with the URL
   `http://<home-assistant-host>:8191`.

The API has no authentication. Keep the port on a trusted network.

## Documentation

See [DOCS.md](DOCS.md) for options and resource notes.

## License

FlareSolverr is distributed under the MIT License. See
[LICENSE.upstream](LICENSE.upstream). The image is built from the unmodified
upstream image; the source is available in the
[upstream repository](https://github.com/FlareSolverr/FlareSolverr). The
entrypoint also installs `jq` from Debian.

This add-on is independent packaging and is not officially supported by the
FlareSolverr authors.
