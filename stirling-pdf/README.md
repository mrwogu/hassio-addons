# Stirling-PDF Home Assistant Add-on

Home Assistant packaging for [Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF), a locally hosted web application for splitting, merging, converting, OCR-ing, and otherwise manipulating PDF files.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Install Stirling-PDF.
3. Review the configuration and adjust the locale and interface names if wanted.
4. Start the add-on and open its web interface on port `8080`.

Settings, custom files, pipelines, stored files, and any additional OCR languages persist in the add-on configuration directory.

## Documentation

See [DOCS.md](DOCS.md) for configuration options, data paths, and OCR notes.

## License

Stirling-PDF is distributed under the MIT License, with a few upstream directories under separate terms that are not part of this image. See [LICENSE.upstream](LICENSE.upstream).

This add-on is independent packaging and is not officially supported by the Stirling-PDF authors.
