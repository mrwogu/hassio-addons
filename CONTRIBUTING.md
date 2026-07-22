# Contributing

## Changes

1. Create a branch from `main`.
2. Keep upstream application changes out of this repository.
3. Run `make bump ADDON=gluetun MESSAGE="Describe packaging change."`.
4. Run `make check`.
5. Open a pull request.

Replace `gluetun` with `bonds` or `stirling-pdf` when needed. Helper increments packaging revision and prepends changelog entry. Add-on versions use `<upstream-version>-<packaging-revision>`. New upstream versions start at revision `1`; digest and packaging changes increment revision.

## Security

Never commit credentials, VPN keys, tokens, generated secrets, user data, or production configuration. Follow `SECURITY.md` for vulnerability reports.

## Style

- Shell scripts must be POSIX-compatible unless explicitly documented.
- Code comments must be in English and explain why.
- YAML uses two-space indentation.
- Git commits use Conventional Commits with a subject no longer than 70 characters.
