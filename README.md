# mrwogu Home Assistant add-ons

Home Assistant add-ons packaged from upstream projects with automated updates, multi-architecture images, and security-focused defaults.

[![Open your Home Assistant instance and show the add repository dialog](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fmrwogu%2Fhassio-addons)

## Add-ons

<table>
  <tr>
    <td align="center" valign="top" width="33%">
      <a href="gluetun/"><img src="https://img.shields.io/badge/Gluetun_VPN-0E7490?style=for-the-badge" alt="Gluetun VPN"></a>
      <p>VPN client supporting multiple providers, OpenVPN, WireGuard, DNS filtering, and proxy services.</p>
      <p><sub><code>amd64</code> <code>aarch64</code><br><a href="https://github.com/passteque/gluetun">Upstream</a> · MIT</sub></p>
    </td>
    <td align="center" valign="top" width="33%">
      <a href="bonds/"><img src="https://img.shields.io/badge/Bonds-7C3AED?style=for-the-badge" alt="Bonds"></a>
      <p>Personal relationship manager built with Go and React.</p>
      <p><sub><code>amd64</code> <code>aarch64</code><br><a href="https://github.com/naiba/bonds">Upstream</a> · Business Source License 1.1</sub></p>
      <p><sub>SQLite by default. PostgreSQL is optional and external.</sub></p>
      <p><sub>Commercial use and managed hosting restrictions apply.</sub></p>
    </td>
    <td align="center" valign="top" width="33%">
      <a href="stirling-pdf/"><img src="https://img.shields.io/badge/Stirling_PDF-B91C1C?style=for-the-badge" alt="Stirling-PDF"></a>
      <p>Locally hosted web application for splitting, merging, converting, OCR, and otherwise manipulating PDF files.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Port <code>8080</code><br><a href="https://github.com/Stirling-Tools/Stirling-PDF">Upstream</a> · MIT</sub></p>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%">
      <a href="authentik/"><img src="https://img.shields.io/badge/authentik-FD4B2A?style=for-the-badge" alt="authentik"></a>
      <p>Self-hosted identity provider for single sign-on, SAML, OAuth2, and LDAP.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Port <code>9000</code><br><a href="https://github.com/goauthentik/authentik">Upstream</a> · MIT</sub></p>
      <p><sub>Requires external PostgreSQL.</sub></p>
    </td>
    <td align="center" valign="top" width="33%">
      <a href="n8n/"><img src="https://img.shields.io/badge/n8n-EA4B71?style=for-the-badge" alt="n8n"></a>
      <p>Workflow automation platform for connecting apps and services.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Port <code>5678</code><br><a href="https://github.com/n8n-io/n8n">Upstream</a> · Sustainable Use License</sub></p>
      <p><sub>SQLite by default. PostgreSQL and Redis are optional.</sub></p>
    </td>
    <td align="center" valign="top" width="33%">
      <a href="traefik-proxy/"><img src="https://img.shields.io/badge/Traefik_Proxy-24A1C1?style=for-the-badge" alt="Traefik Proxy"></a>
      <p>File-configured reverse proxy with TLS, real-IP logging, and Cloudflare-aware operations.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Ports <code>80</code> and <code>443</code><br><a href="https://github.com/traefik/traefik">Upstream</a> · MIT</sub></p>
      <p><sub>Docker provider disabled. Dashboard is not published.</sub></p>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%">
      <a href="tududi/"><img src="https://img.shields.io/badge/Tududi-059669?style=for-the-badge" alt="Tududi"></a>
      <p>Self-hosted task management and life organization system for tasks, projects, notes, and areas.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Port <code>3002</code><br><a href="https://github.com/chrisvel/tududi">Upstream</a> · MIT</sub></p>
    </td>
    <td align="center" valign="top" width="33%">
      <a href="hindsight/"><img src="https://img.shields.io/badge/Hindsight-4F46E5?style=for-the-badge" alt="Hindsight"></a>
      <p>Agent memory system with an OpenAI-compatible REST API and a web control plane.</p>
      <p><sub><code>amd64</code> <code>aarch64</code> · Ports <code>8888</code> and <code>9999</code><br><a href="https://github.com/vectorize-io/hindsight">Upstream</a> · MIT</sub></p>
      <p><sub>Embedded database by default. External PostgreSQL with pgvector optional.</sub></p>
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
