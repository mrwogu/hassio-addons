# mrwogu Home Assistant add-ons

Home Assistant add-ons packaged from upstream projects with automated updates, multi-architecture images, and security-focused defaults.

[![Open your Home Assistant instance and show the add repository dialog](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fmrwogu%2Fhassio-addons)

## Add-ons

<table>
  <tr>
    <td align="center" valign="top" width="33%">
      <a href="gluetun/"><img src="gluetun/logo.png" alt="Gluetun" width="220"></a>
      <h3><a href="gluetun/">Gluetun VPN</a></h3>
      <p>VPN client supporting multiple providers, OpenVPN, WireGuard, DNS filtering, and proxy services.</p>
      <p><sub><code>amd64</code> <code>aarch64</code><br><a href="https://github.com/passteque/gluetun">Upstream</a> · MIT</sub></p>
    </td>
    <td align="center" valign="top" width="33%">
      <a href="bonds/"><img src="bonds/logo.png" alt="Bonds" width="220"></a>
      <h3><a href="bonds/">Bonds</a></h3>
      <p>Personal relationship manager built with Go and React.</p>
      <p><sub><code>amd64</code> <code>aarch64</code><br><a href="https://github.com/naiba/bonds">Upstream</a> · Business Source License 1.1</sub></p>
      <p><sub>SQLite by default. PostgreSQL is optional and external.</sub></p>
      <p><sub>Commercial use and managed hosting restrictions apply.</sub></p>
    </td>
    <td align="center" valign="top" width="33%">
      <a href="stirling-pdf/"><img src="stirling-pdf/logo.png" alt="Stirling-PDF" width="220"></a>
      <h3><a href="stirling-pdf/">Stirling-PDF</a></h3>
      <p>Locally hosted web application for splitting, merging, converting, OCR, and otherwise manipulating PDF files.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Port <code>8080</code><br><a href="https://github.com/Stirling-Tools/Stirling-PDF">Upstream</a> · MIT</sub></p>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%">
      <a href="authentik/"><img src="authentik/logo.png" alt="authentik" width="220"></a>
      <h3><a href="authentik/">authentik</a></h3>
      <p>Self-hosted identity provider for single sign-on, SAML, OAuth2, and LDAP.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Port <code>9000</code><br><a href="https://github.com/goauthentik/authentik">Upstream</a> · MIT</sub></p>
      <p><sub>Requires external PostgreSQL.</sub></p>
    </td>
    <td align="center" valign="top" width="33%">
      <a href="n8n/"><img src="n8n/logo.png" alt="n8n" width="220"></a>
      <h3><a href="n8n/">n8n</a></h3>
      <p>Workflow automation platform for connecting apps and services.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Port <code>5678</code><br><a href="https://github.com/n8n-io/n8n">Upstream</a> · Sustainable Use License</sub></p>
      <p><sub>SQLite by default. PostgreSQL and Redis are optional.</sub></p>
    </td>
    <td align="center" valign="top" width="33%">
      <a href="traefik-proxy/"><img src="traefik-proxy/logo.png" alt="Traefik Proxy" width="220"></a>
      <h3><a href="traefik-proxy/">Traefik Proxy</a></h3>
      <p>File-configured reverse proxy with TLS, real-IP logging, and Cloudflare-aware operations.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Ports <code>80</code> and <code>443</code><br><a href="https://github.com/traefik/traefik">Upstream</a> · MIT</sub></p>
      <p><sub>Docker provider disabled. Dashboard is not published.</sub></p>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%">
      <a href="tududi/"><img src="tududi/logo.png" alt="Tududi" width="220"></a>
      <h3><a href="tududi/">Tududi</a></h3>
      <p>Self-hosted task management and life organization system for tasks, projects, notes, and areas.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Port <code>3002</code><br><a href="https://github.com/chrisvel/tududi">Upstream</a> · MIT</sub></p>
    </td>
    <td align="center" valign="top" width="33%">
      <a href="mem0/"><img src="mem0/logo.png" alt="Mem0" width="220"></a>
      <h3><a href="mem0/">Mem0</a></h3>
      <p>Self-hosted AI memory layer with a REST API for assistants and agents.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Port <code>8000</code><br><a href="https://github.com/mem0ai/mem0">Upstream</a> · Apache 2.0</sub></p>
      <p><sub>REST API only. Requires external PostgreSQL with pgvector.</sub></p>
    </td>
  </tr>
</table>

## Installation

1. Open Home Assistant.
2. Go to **Settings > Apps > App store**.
3. Open the repository menu.
4. Add `https://github.com/mrwogu/hassio-addons`.
5. Install the selected add-on.

## Updates

Renovate checks upstream releases and image digests every six hours. Updates
become eligible after three days, receive a pull request, pass adapter tests
and changed add-on builds on `amd64` and `aarch64`, and merge without review.
Successful merges publish immutable GHCR images and per-add-on GitHub Releases.

## Support

Report packaging, startup, or Home Assistant integration problems in this repository. Report application bugs directly to the respective upstream project.

These packages are community-maintained and are not endorsed by Home Assistant or the upstream projects.

Report packaging, workflow, supply-chain, or secret-handling vulnerabilities
through [private vulnerability reporting](https://github.com/mrwogu/hassio-addons/security/advisories/new).
Report application vulnerabilities to the relevant upstream project.

## License

Repository integration code uses the MIT License. Packaged applications retain their upstream licenses, included in each add-on directory.
