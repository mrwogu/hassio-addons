# Contributing

## Changes

1. Create a branch from `main`.
2. Keep upstream application changes out of this repository.
3. Run `make bump ADDON=gluetun MESSAGE="Describe packaging change."`.
4. Run `make check`.
5. Open a pull request.

Replace `gluetun` with `bonds`, `n8n`, `stirling-pdf`, `authentik`, `traefik-proxy`, `tududi`, or `hindsight` when needed. Helper increments packaging revision and prepends changelog entry. Add-on versions use `<upstream-version>-<packaging-revision>`. New upstream versions start at revision `1`; digest and packaging changes increment revision.

`addons.yaml` is the single registry for add-on slugs, images, Dockerfiles, and
adapter test scripts. New add-ons must update it before validation can pass.

Each `upstream.yaml` contains an add-on-specific `changelog_template`. Keep its wording specific to the add-on and preserve both `{upstream_version}` and `{upstream_link}` placeholders.

## Validation

Required checks:

```sh
make check
yamllint .
actionlint .github/workflows/*.yml
promptscript check
promptscript validate --strict
promptscript diff
```

Changed add-ons must also pass native `amd64` and `aarch64` build validation.

## Security

Never commit credentials, VPN keys, tokens, generated secrets, user data, or production configuration. Follow `SECURITY.md` for vulnerability reports.

## Style

- Shell scripts must be POSIX-compatible unless explicitly documented.
- Code comments must be in English and explain why.
- YAML uses two-space indentation.
- Git commits use Conventional Commits with a subject no longer than 70 characters.
