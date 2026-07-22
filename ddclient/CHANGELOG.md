# Changelog

## 3.11.2-3

- Pass daemon interval explicitly so ddclient loops in the foreground

## 3.11.2-2

- Keep ddclient running as a foreground daemon (fix restart loop)

## 3.11.2-1

- Package ddclient `3.11.2` from the Alpine community repository on a current,
  digest-pinned Alpine base (the LinuxServer.io image is abandoned on Alpine 3.12).
- Write `/config/ddclient.conf` from the add-on `config` option on every start.
- Run ddclient in the foreground and persist its cache under `/config`.
- Run the dynamic DNS daemon without ingress, ports, or elevated privileges.
