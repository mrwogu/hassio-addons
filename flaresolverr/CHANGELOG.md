# Changelog

## 3.5.2-2

- Start as root to read options, drop to flaresolverr before exec

## 3.5.2-1

- Package FlareSolverr [v3.5.2](https://github.com/FlareSolverr/FlareSolverr/releases/tag/v3.5.2).
- Translate the `log_level`, `log_html` and `disable_media` options into
  FlareSolverr environment variables.
- Accept extra upstream variables such as `PROXY_URL` through `env_vars`.
