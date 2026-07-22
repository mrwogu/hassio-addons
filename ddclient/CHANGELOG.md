# Changelog

## 3.9.1-ls69-1

- Package ddclient via the [LinuxServer.io image](https://github.com/linuxserver/docker-ddclient) `v3.9.1-ls69`.
- Write `/config/ddclient.conf` from the add-on `config` option on every start.
- Persist the configuration and ddclient cache in add-on configuration storage.
- Run the dynamic DNS daemon without ingress, ports, or elevated privileges.
