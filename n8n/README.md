# n8n Home Assistant Add-on

Home Assistant packaging for [n8n](https://n8n.io/), a workflow automation
platform for connecting apps and services.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app
   store.
2. Install **n8n**.
3. Start the add-on and open its web interface on port `5678`.

n8n uses SQLite by default. PostgreSQL and Redis are optional external
services; this add-on does not bundle either service. JavaScript and Python
Code nodes use the bundled task-runner runtime.

## Documentation

See [DOCS.md](DOCS.md) for database, queue mode, configuration, and persistent
data details.

## License

n8n is distributed under the Sustainable Use License, with separate terms for
Enterprise source files. See [LICENSE.upstream](LICENSE.upstream).

This add-on is independent packaging and is not officially supported by n8n.
