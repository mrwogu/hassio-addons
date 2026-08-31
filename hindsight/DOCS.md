# Hindsight add-on documentation

Hindsight is an agent memory system. Assistants store conversations through the memory API and Hindsight extracts, consolidates, and retrieves facts over time. The add-on packages the upstream standalone image, which runs the memory API and the control plane web interface in one container.

## Ports

- `8888` - memory API (OpenAI-compatible endpoints, health endpoint).
- `9999` - control plane web interface.

## LLM configuration

Memory extraction requires an LLM. Configure it with these options:

| Option | Example |
| ------ | ------- |
| `llm_provider` | `openai`, `anthropic`, `gemini`, `ollama`, `openrouter` |
| `llm_api_key` | provider API key; not needed for local Ollama |
| `llm_model` | for example `gpt-4o-mini`, `llama3` |
| `llm_base_url` | `http://192.168.1.50:11434/v1` for a local Ollama server |

The base URL override accepts any OpenAI-compatible endpoint, so local gateways such as Ollama, LM Studio, or LiteLLM work without an API key. Leave `llm_model` blank to use the provider default.

## Database

By default the add-on uses the embedded database and stores its data under the add-on configuration directory, which persists across add-on restarts and updates.

To use an external PostgreSQL 14+ server with pgvector:

1. Set `database_host` and adjust `database_port`, `database_name`, `database_user`, and `database_password`.
2. Choose `database_sslmode`; `require` encrypts traffic, `verify-full` also validates the server certificate.
3. The add-on builds the connection URL automatically, URL-encoding credentials.

Special characters in the database user and password are supported and URL-encoded.

## API protection

Without `tenant_api_key` the memory API is open to anything that can reach port `8888`. On a trusted home network this is acceptable; otherwise set `tenant_api_key` and pass the key in the `Authorization: Bearer <key>` header on every API request. The health endpoints stay open. The control plane on port `9999` has no separate authentication; protect it with a reverse proxy if it must stay reachable beyond the local network.

## Custom environment variables

`env_vars` passes additional environment variables to Hindsight, covering options the add-on does not expose directly:

```yaml
env_vars:
  HINDSIGHT_API_MODEL_INIT_TIMEOUT: "3600"
  HINDSIGHT_WAIT_FOR_DEPS: "true"
```

Names must be plain uppercase identifiers. The adapter rejects overrides of managed variables (`HINDSIGHT_API_DATABASE_URL`, `HINDSIGHT_API_LLM_*`, `HINDSIGHT_API_TENANT_*`, `HOME`, and others) and protected variables (`PATH`, `NODE_OPTIONS`, `PYTHONPATH`, and others). Values may not contain control characters. Custom variables apply after all managed variables.

## Data storage

- Embedded database data: `/config/.pg0` inside the add-on configuration storage.
- The API must become healthy before the control plane starts; the upstream startup script waits up to 300 seconds and the health check retries for 90 seconds.

## Architecture

Supported: `aarch64`, `amd64`.

## Troubleshooting

- **API never becomes healthy** - check the add-on logs for LLM verification errors; the configured LLM endpoint must be reachable at startup.
- **Memory extraction fails with an LLM error** - verify `llm_api_key` and `llm_model`, or point `llm_base_url` at a reachable OpenAI-compatible server.
- **External database connection refused** - verify the server runs PostgreSQL 14+ with the pgvector extension available.
- **401 responses from the API** - a `tenant_api_key` is set; send it as the `Authorization: Bearer <key>` header.
