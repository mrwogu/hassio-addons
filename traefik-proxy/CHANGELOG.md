# Changelog

## 3.7.16-8

- Add log_max_size, log_keep and log_max_age options for log rotation.
- Fix log rotation: logrotate failed with "Could not lock file" under AppArmor and logs were never rotated. The config is now rendered under /config.

## 3.7.16-7

- Add metrics_enabled option for Prometheus metrics on an internal port.

## 3.7.16-6

- Add read_timeout option for the request read timeout of public entrypoints.
- Run the startup validation with an empty dynamic directory, so it no longer starts ACME orders that are killed after 10s and leave DNS challenge records behind.
- Issue ACME certificates with EC256 keys instead of the Traefik default RSA4096, TLS handshakes are cheaper.
- Set aliasHeadersStrategy to delete and explicit encodedCharacters on all entrypoints, this also removes the startup warnings about them.

## 3.7.16-5

- Add access_log_headers option to keep extra request headers, like forward-auth identity, in the access log.

## 3.7.16-4

- Update Traefik Proxy to [v3.7.16](https://github.com/traefik/traefik/releases/tag/v3.7.16).

## 3.7.16-3

- Update Traefik Proxy to [v3.7.16](https://github.com/traefik/traefik/releases/tag/v3.7.16).

## 3.7.16-2

- Update Traefik Proxy to [v3.7.16](https://github.com/traefik/traefik/releases/tag/v3.7.16).

## 3.7.16-1

- Update Traefik Proxy to [v3.7.16](https://github.com/traefik/traefik/releases/tag/v3.7.16).

## 3.7.15-2

- Update Traefik Proxy to [v3.7.15](https://github.com/traefik/traefik/releases/tag/v3.7.15).

## 3.7.15-1

- Update Traefik Proxy to [v3.7.15](https://github.com/traefik/traefik/releases/tag/v3.7.15).

## 3.7.14-2

- Update Traefik Proxy to [v3.7.14](https://github.com/traefik/traefik/releases/tag/v3.7.14).

## 3.7.14-1

- Update Traefik Proxy to [v3.7.14](https://github.com/traefik/traefik/releases/tag/v3.7.14).

## 3.7.13-3

- Update Traefik Proxy to [v3.7.13](https://github.com/traefik/traefik/releases/tag/v3.7.13).

## 3.7.13-2

- Update Traefik Proxy to [v3.7.13](https://github.com/traefik/traefik/releases/tag/v3.7.13).

## 3.7.13-1

- Update Traefik Proxy to [v3.7.13](https://github.com/traefik/traefik/releases/tag/v3.7.13).

## 3.7.12-3

- Use app_config mapping for supervisor compatibility

## 3.7.12-2

- Update Traefik Proxy to [v3.7.12](https://github.com/traefik/traefik/releases/tag/v3.7.12).

## 3.7.12-1

- Update Traefik Proxy to [v3.7.12](https://github.com/traefik/traefik/releases/tag/v3.7.12).

## 3.7.11-1

- Update Traefik Proxy to [v3.7.11](https://github.com/traefik/traefik/releases/tag/v3.7.11).

## 3.7.10-2

- Fix runtime configuration, confinement, and smoke tests

## 3.7.10-1

- Initial Traefik Proxy Home Assistant app based on Traefik v3.7.10.
- Add file-provider routing, private dashboard defaults, real-IP diagnostics,
  JSON access logs, bounded log rotation, optional Cloudflare DNS-01 ACME,
  fail2ban examples, and NPM migration guidance.
