# Hindsight

Home Assistant add-on packaging [Hindsight](https://github.com/vectorize-io/hindsight), an agent memory system with an OpenAI-compatible REST API and a web control plane.

## Features

- Memory API on port `8888` with OpenAI-compatible endpoints for assistants and agents.
- Web control plane on port `9999` for browsing memories, fact trajectories, and missions.
- Embedded database by default, persisted in add-on configuration storage.
- Optional external PostgreSQL 14+ with pgvector for shared or production deployments.
- Optional API key protection for the memory API.
- OpenAI-compatible LLM endpoint override for local models such as Ollama.

## Installation

1. Add this repository to Home Assistant.
2. Install **Hindsight** from the add-on store.
3. Configure the LLM provider (for example `openai` with an API key, or `ollama` with a base URL).
4. Start the add-on and open the web UI.

## Configuration

| Option | Default | Description |
| ------ | ------- | ----------- |
| `llm_provider` | `openai` | LLM backend used for memory extraction. |
| `llm_api_key` | - | API key for the selected provider. |
| `llm_model` | - | Model name; blank uses the provider default. |
| `llm_base_url` | - | OpenAI-compatible endpoint override. |
| `database_host` | - | External PostgreSQL host; blank uses the embedded database. |
| `database_port` | `5432` | External PostgreSQL port. |
| `database_name` | `hindsight` | External database name. |
| `database_user` | `hindsight` | External database user. |
| `database_password` | - | External database password. |
| `database_sslmode` | `prefer` | External database TLS mode. |
| `tenant_api_key` | - | Optional API key required on every memory API request. |
| `worker_id` | `hindsight-hassio` | Stable worker identifier. |
| `env_vars` | `[]` | Additional environment variables as name/value pairs. |

See [DOCS.md](DOCS.md) for the full documentation.

## License

This wrapper is MIT licensed. Hindsight is MIT licensed; see [LICENSE.upstream](LICENSE.upstream).
