# Mem0 Home Assistant Add-on

Home Assistant packaging for the [Mem0](https://github.com/mem0ai/mem0) self-hosted REST server, a memory layer for AI assistants and agents.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Install Mem0.
3. Provide an OpenAI API key and an external PostgreSQL server with the pgvector extension.
4. Start the add-on and call the REST API on port `8000`.

The add-on exposes the REST API only. The upstream dashboard ships without a
publishable image and is not included. Generated JWT secrets and all
configuration persist in the add-on configuration directory.

## Documentation

See [DOCS.md](DOCS.md) for configuration, database setup, and API usage.

## License

Mem0 is distributed under the Apache License 2.0. Read
[LICENSE.upstream](LICENSE.upstream) before use.

This add-on is independent packaging and is not officially supported by the
Mem0 authors.
