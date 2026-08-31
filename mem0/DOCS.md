# Mem0 Home Assistant Add-on

Self-hosted [Mem0](https://github.com/mem0ai/mem0) REST server. Mem0 gives AI
assistants a persistent, searchable memory layer backed by PostgreSQL with
pgvector.

## Packaging notes

Upstream publishes no multi-architecture server image, so this add-on builds
the server from the upstream source tarball pinned to tag `v2.0.19` and
verified against a SHA-256 checksum in the Dockerfile. The REST API runs on
port `8000`; authentication is always enabled (`AUTH_DISABLED` cannot be
disabled through the add-on configuration). Anonymous telemetry is disabled by
default; enable it with the `telemetry` option.

The upstream web dashboard ships without a publishable image, so the add-on
exposes the REST API only. Manage API keys and configuration through the REST
endpoints described below.

## Requirements

- An OpenAI API key (default LLM and embedder). Anthropic and Gemini keys are
  optional extras.
- An external PostgreSQL server **with the pgvector extension**, for example
  the `pgvector/pgvector` image. The official Home Assistant PostgreSQL add-on
  does not include pgvector and will not work. The add-on does not bundle or
  create a database.

Example database bootstrap (single database):

```sql
CREATE USER mem0 WITH PASSWORD 'change-me';
CREATE DATABASE mem0 OWNER mem0;
\c mem0
CREATE EXTENSION IF NOT EXISTS vector;
```

Set `app_db_name` only to keep the application tables (users, API keys,
request logs) in a separate database; it must exist before start.

## Configuration

| Option | Description |
| --- | --- |
| `openai_api_key` | Required OpenAI key for the default LLM and embedder. |
| `openai_base_url` | Optional custom endpoint for OpenAI-compatible services (LLM and embedder). Blank uses the official API. |
| `anthropic_api_key` | Optional Anthropic key for the bundled Anthropic provider. |
| `google_api_key` | Optional Google key for the bundled Gemini providers. |
| `admin_api_key` | Optional legacy shared key for protected endpoints. Use 16+ random characters. |
| `jwt_secret` | Optional token-signing secret. Leave blank to generate and persist one automatically. |
| `postgres_host`, `postgres_port`, `postgres_db`, `postgres_user`, `postgres_password` | External PostgreSQL connection. Host, database, and user are required. |
| `postgres_collection_name` | pgvector collection name. Default `memories`. |
| `app_db_name` | Optional separate database for application tables. Blank reuses the vector database. |
| `default_llm_model` | Default LLM model. Default `gpt-5-mini`. |
| `default_embedder_model` | Default embedding model. Default `text-embedding-3-small`. |
| `telemetry` | Anonymous onboarding telemetry. Disabled by default. |
| `request_log_retention_days` | Request log retention. Default `30`. |

Generated secrets are written atomically with mode `0600` under
`/config/.secrets` and are never logged.

## Custom provider endpoints

Two independent layers decide where requests go:

1. **`openai_base_url` add-on option** (default value): exported as the
   `OPENAI_BASE_URL` environment variable. The mem0 library falls back to it
   whenever the runtime config has no explicit endpoint. Change it in the
   add-on options and restart.
2. **`POST /configure` runtime override**: stored in the application database
   and reapplied on every start; it always wins over the environment value.

OpenAI-compatible endpoint for the LLM and the embedder:

```sh
curl -s -X POST http://homeassistant.local:8000/configure \
    -H "X-API-Key: m0sk_your_admin_key" \
    -H "Content-Type: application/json" \
    -d '{
        "llm": {"config": {"openai_base_url": "https://gateway.example:8000/v1"}},
        "embedder": {"config": {"openai_base_url": "https://gateway.example:8000/v1"}}
    }'
```

Other supported endpoint fields: `anthropic_base_url` (Anthropic LLM) and
`openrouter_base_url` (OpenRouter LLM). The Gemini provider has no endpoint
override upstream. Verify with `GET /configure`; secret values are always
redacted in responses.

Keep provider keys in the add-on options (they become environment variables)
and pass only endpoint URLs through `/configure`; configuration overrides
are stored in plain JSON in the application database.

## Dashboard note

The upstream dashboard has **no UI for provider endpoints**; it exposes only
providers from the bundled list, models, and API keys. Endpoint URLs are set
exactly through the two mechanisms above (add-on option or `POST /configure`).
The add-on options only provide defaults: a value already stored by
`POST /configure` in the application database overrides them, and changing
add-on options cannot remove such an override (clear it with
`POST /configure` using the official URL, or reset the override row in the
`settings` table).

## Usage

The server listens on port `8000`. Migrations run automatically on start;
the add-on waits for a reachable database, so keep PostgreSQL running.

Set `admin_api_key` in the add-on configuration and pass it as `X-API-Key`
on every request. The upstream per-user key management (`/api-keys`) requires
a registered admin user, which the add-on cannot create without the upstream
dashboard, so use the admin key directly for client integrations.

Add and search memories:

```sh
curl -s -X POST http://homeassistant.local:8000/memories \
    -H "X-API-Key: m0sk_your_admin_key" \
    -H "Content-Type: application/json" \
    -d '{"messages": [{"role": "user", "content": "I prefer dark mode"}], "user_id": "alice"}'

curl -s "http://homeassistant.local:8000/memories?user_id=alice&query=theme" \
    -H "X-API-Key: m0sk_your_admin_key"
```

See the upstream [REST API reference](https://docs.mem0.ai/open-source/features/rest-api)
for all endpoints. `POST /configure` changes LLM and embedder providers at
runtime; only the bundled providers (`openai`, `anthropic`, `gemini`) are
accepted.

## Troubleshooting

- **401 on every endpoint**: no admin is configured. Set `admin_api_key`
  (16+ characters) in the add-on configuration and restart.
- **502 on memory writes**: the provider key is invalid; check the configured
  provider credentials.
- **Add-on restarts on boot**: PostgreSQL is unreachable or lacks the
  `vector` extension. Verify the connection options and extension.
- **Changing options does not apply**: restart the add-on; environment
  variables are read at process start.

## Updates

Renovate opens pull requests for new Mem0 releases tracked from GitHub
releases. The `renovate-sync` workflow recomputes the pinned
`MEM0_SOURCE_SHA256` from the matching upstream tarball, synchronizes the
package metadata, and the pull request auto-merges after the required
checks. The build verifies the checksum again before extracting, so a
mismatched tarball can never enter the image.
