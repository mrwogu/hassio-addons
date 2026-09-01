# Changelog

## 0.9.2-3

- Fix options.json read by dropping to hindsight user only for app start

## 0.9.2-2

- Fix env_vars schema and app_config mapping

## 0.9.2-1

- Package Hindsight [0.9.2](https://github.com/vectorize-io/hindsight/releases/tag/v0.9.2).
- Ship the memory API on port 8888 and the control plane web interface on port 9999.
- Use the embedded database stored in add-on configuration by default; external PostgreSQL 14+ with pgvector optional.
- Add optional API key protection, LLM provider configuration, and custom environment variables.
