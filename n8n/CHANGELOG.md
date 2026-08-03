# Changelog

## 2.32.7-2

- Add Python task runner and explicit n8n defaults.

## 2.32.7-1

- Package n8n [2.32.7](https://github.com/n8n-io/n8n/releases/tag/n8n%402.32.7).
- Use SQLite by default, with optional external PostgreSQL.
- Support external Redis for n8n queue mode; no database or cache is bundled.
- Persist the n8n user folder and encryption key under `/config`.
- Disable n8n update notifications and telemetry by default.
