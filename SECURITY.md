# Security policy

## Reporting

Do not open public issues for vulnerabilities.

Use GitHub private vulnerability reporting for `mrwogu/hassio-addons`:

https://github.com/mrwogu/hassio-addons/security/advisories/new

Report only vulnerabilities caused by this repository's:

- Dockerfiles and image selection;
- add-on entrypoints and adapter scripts;
- Home Assistant metadata and option schemas;
- GitHub Actions and release automation;
- secret handling, persistence, and confinement;
- supply chain or published artifacts.

Include affected add-on version, Home Assistant version, architecture, impact,
and reproduction steps.

Report vulnerabilities in Gluetun, Bonds, n8n, Stirling-PDF, authentik, Traefik Proxy, or Tududi directly to their upstream maintainers when the issue is not caused by this packaging.

## Supported versions

Only latest published add-on version receives security updates. Previous versioned images remain available for rollback but are unsupported.

## Secrets

Remove VPN credentials, tokens, private keys, cookies, and personal data from logs and attachments before submission.

## Response

The latest published add-on version receives security fixes. Maintainers
triage reports privately, confirm whether the issue belongs to this wrapper or
upstream, and publish a corrective package release when the wrapper is affected.
