# renovate: datasource=docker depName=ghcr.io/n8n-io/n8n versioning=semver
ARG UPSTREAM_VERSION="3.2.0"
ARG UPSTREAM_DIGEST="sha256:9e67c2627d3c30dbb0d51f5da83d4499ac7913f6b4f358a900a58026a832ba12"

# renovate: datasource=docker depName=ghcr.io/n8n-io/runners versioning=semver
ARG RUNNERS_VERSION="3.2.0"
ARG RUNNERS_DIGEST="sha256:121b0ae16e397b31dca8c9f188f44a611d75ed46bcda16bacc42381a4ea1ae90"
FROM ghcr.io/n8n-io/runners:${RUNNERS_VERSION}@${RUNNERS_DIGEST} AS task-runners

FROM ghcr.io/n8n-io/n8n:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant n8n addon" \
    org.opencontainers.image.description="Home Assistant adapter for n8n" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

# jq parses the add-on options. Home Assistant's Supervisor writes
# /data/options.json owned by root with mode 0600, so the wrapper must run as
# root to read it; no Linux capabilities are granted.
USER root

# The Docker Hardened Alpine base omits the package manager. Bootstrap the
# pinned Alpine package manager before installing the small adapter tools.
# renovate: datasource=repology depName=alpine_3_24/apk-tools-static versioning=loose
ARG APK_TOOLS_VERSION="3.0.9-r0"
ARG ALPINE_VERSION="v3.24"
ARG APK_TOOLS_SHA256_X86_64="0a1a0682375f66a83b7b903f6e4638ccfe312547d50d336b5f2be9fc391281be"
ARG APK_TOOLS_SHA256_AARCH64="1f4c822fd14e8eb51ba27e17d5a1649aef33c91611c77eddeb318e8f2cb57fb1"
RUN set -eux; \
    cd /tmp; \
    arch=$(uname -m); \
    case "$arch" in \
        x86_64) expected="$APK_TOOLS_SHA256_X86_64" ;; \
        aarch64) expected="$APK_TOOLS_SHA256_AARCH64" ;; \
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    package="apk-tools-static-${APK_TOOLS_VERSION}.apk"; \
    wget -nv "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/main/${arch}/${package}"; \
    printf '%s  %s\n' "$expected" "$package" | sha256sum -c -; \
    tar -xzf "$package"; \
    ./sbin/apk.static add --no-cache apk-tools; \
    rm -rf /tmp/*

RUN apk add --no-cache jq openssl python3 su-exec

# Internal Python runners need the package, virtual environment, and matching
# interpreter. The upstream n8n image contains none of these files.
COPY --from=task-runners /opt/runners/task-runner-python /usr/local/lib/node_modules/@n8n/task-runner-python
COPY --from=task-runners /usr/local/bin/python3.13 /usr/local/bin/python3.13
COPY --from=task-runners /usr/local/lib/libpython3.13.so* /usr/local/lib/
COPY --from=task-runners /usr/local/lib/python3.13 /usr/local/lib/python3.13

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

# The wrapper prepares persistent storage and environment, then hands off to
# the upstream launcher so its certificate handling and signal behavior remain.
ENTRYPOINT ["tini", "--", "/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD wget -q -O /dev/null --timeout=5 http://127.0.0.1:5678/healthz || exit 1
