# Changelog

## 2.0.19-4

- Add custom environment variables option

## 2.0.19-3

- Add openai_base_url option for custom endpoints

## 2.0.19-2

- Fix Polish diacritics in option translations

## 2.0.19-1

- Package the Mem0 self-hosted REST server [v2.0.19](https://github.com/mem0ai/mem0/releases/tag/v2.0.19).
- Build from a checksum-verified upstream source tarball because upstream publishes no server image.
- REST API only: the upstream dashboard has no published image and is not included.
- Requires an external PostgreSQL server with the pgvector extension.
- Persist generated JWT secrets in the add-on configuration storage.
- Disable anonymous telemetry by default.
