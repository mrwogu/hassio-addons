# Changelog

## 2026.8.0-2

- Use app_config mapping for supervisor compatibility

## 2026.8.0-1

- Refresh authentik's identity, SSO, and directory integration with [2026.8.0](https://github.com/goauthentik/authentik/releases/tag/version/2026.8.0).

## 2026.8.0-rc7-2

- Remove obsolete Redis configuration; authentik now uses PostgreSQL only

## 2026.8.0-rc7-1

- Refresh authentik's identity, SSO, and directory integration with [2026.8.0-rc7](https://github.com/goauthentik/authentik/releases/tag/version/2026.8.0-rc7).

## 2026.5.5-2

- Run as root to read options.json and add advanced env_vars option

## 2026.5.5-1

- Package authentik [2026.5.5](https://github.com/goauthentik/authentik/releases/tag/version/2026.5.5).
- Run the server and worker in a single container with the upstream allinone
  launcher.
- Connect to an external PostgreSQL and Redis provided through add-on options.
- Generate and persist a stable secret key under `/config` when none is given.
- Persist uploaded media, discovered certificates, and custom email templates
  under add-on configuration storage.
- Force upstream update checks and startup telemetry off.
