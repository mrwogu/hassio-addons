# Changelog

## 3.93.0-2

- Update docs: Renovate checks upstream once a week.

## 3.93.0-1

- Bring the latest portfolio tracking and wealth management updates from Ghostfolio [3.93.0](https://github.com/ghostfolio/ghostfolio/releases/tag/3.93.0).

## 3.92.0-1

- Package Ghostfolio [3.92.0](https://github.com/ghostfolio/ghostfolio/releases/tag/3.92.0).
- Connect to an external PostgreSQL and Redis provided through add-on options.
- Generate and persist the access token salt and JWT secret key under
  `/config` when none is given.
- Run Ghostfolio as the upstream `node` user with `tini` as PID 1.
- Expose root URL, log level, security token login, security headers, MCP,
  CoinGecko API keys, and OpenID Connect as options.
