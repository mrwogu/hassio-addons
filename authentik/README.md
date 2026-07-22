# authentik Home Assistant Add-on

Home Assistant packaging for [authentik](https://goauthentik.io/), a self-hosted
identity provider for single sign-on, SAML, OAuth2, LDAP, and more.

## Installation

1. Add `https://github.com/mrwogu/hassio-addons` to the Home Assistant app store.
2. Prepare an external PostgreSQL database and a Redis server (see
   [DOCS.md](DOCS.md)).
3. Install authentik.
4. Enter the database and Redis connection details in the configuration.
5. Start the add-on and open the interface on port `9000`, then complete the
   initial setup at `/if/flow/initial-setup/`.

authentik keeps its state in the external PostgreSQL and Redis. Uploaded files,
certificates, custom templates, and the generated secret key persist in the
add-on configuration directory.

## Documentation

See [DOCS.md](DOCS.md) for requirements, configuration options, and data paths.

## License

authentik is distributed primarily under the MIT License, with some upstream
directories under separate terms (CC BY-SA 4.0 and an enterprise license) that
are not activated by this add-on. See [LICENSE.upstream](LICENSE.upstream).

This add-on is independent packaging and is not officially supported by the
authentik authors.
