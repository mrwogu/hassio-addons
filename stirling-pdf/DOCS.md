# Stirling-PDF Add-on Documentation

## Access

Stirling-PDF listens on port `8080`. Home Assistant ingress is not used:
Stirling-PDF pins its base href and API base to a fixed server context path, so
it cannot follow the dynamic path prefix that ingress proxies under. Reach it
directly on port `8080`, or place your own reverse proxy in front.

## Configuration

### `default_locale`

Interface language and locale, for example `en-US` or `pl-PL`.

### `app_name`

Name shown in the interface title and navigation bar.

### `home_description`

Optional subtitle on the home page. Leave blank to use the upstream default.

### `enable_security`

Enables the Stirling-PDF login system and user accounts. Enable it when the
port is reachable beyond a trusted network. When enabled, Stirling-PDF stores
its own accounts in the persisted configuration directory.

### `metrics_enabled`

Exposes the Prometheus metrics endpoint. Disabled by default.

## Managed behavior

The adapter always disables upstream update prompts and usage analytics, since
Home Assistant manages updates and no usage data should leave the host. These
are not configurable.

## Persistent Data

Upstream application paths are redirected into the add-on configuration
directory so they survive restarts and are captured by Home Assistant backups:

| Data | Container path | Stored at |
| --- | --- | --- |
| Settings, database, config | `/configs` | `/config/configs` |
| Custom files and templates | `/customFiles` | `/config/customFiles` |
| Saved pipelines | `/pipeline` | `/config/pipeline` |
| Stored and processed files | `/storage` | `/config/storage` |
| Extra OCR languages | `/usr/share/tessdata` | `/config/tessdata` |

Logs are not persisted; use the Home Assistant add-on log viewer.

## OCR languages

The image bundles the English Tesseract language. To OCR other languages, drop
the matching `*.traineddata` file into `/config/tessdata`. Stirling-PDF copies
these into its system Tesseract directory on the next start.

## License and Support

Stirling-PDF is provided under the MIT License. Some upstream repository
directories (`app/proprietary`, `app/saas`, and similar) carry separate terms;
they are not redistributed in this image. See [LICENSE.upstream](LICENSE.upstream).

This repository packages upstream software for Home Assistant and does not imply
endorsement or official support by the Stirling-PDF authors. Report application
issues to the [upstream project](https://github.com/Stirling-Tools/Stirling-PDF)
and packaging issues in this repository.
