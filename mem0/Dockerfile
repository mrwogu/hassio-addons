# renovate: datasource=github-releases depName=mem0ai/mem0 versioning=semver extractVersion=^v(?<version>\d+\.\d+\.\d+)$
ARG UPSTREAM_VERSION="2.0.19"
# python:3.12-slim multi-architecture index digest. Upstream publishes no
# server image, so this add-on builds the Mem0 REST server from the upstream
# source tarball verified against MEM0_SOURCE_SHA256.
ARG UPSTREAM_DIGEST="sha256:09f7da3bc104798d0afb40bc08d23ab2da20a76130cec1f2ef170848f5d85217"
FROM python:3.12-slim@${UPSTREAM_DIGEST}

ARG UPSTREAM_VERSION="2.0.19"
ARG MEM0_SOURCE_SHA256="46bdc2d658a7f89727cdf2bcbccc10d248c55a2c366463378cd64ff1a92c5879"

LABEL \
    org.opencontainers.image.title="Home Assistant Mem0 addon" \
    org.opencontainers.image.description="Home Assistant adapter for the Mem0 self-hosted REST server" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="Apache-2.0"

ENV \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Download the pinned upstream tag, verify its checksum before extraction,
# and unpack only the server/ tree. No upstream code runs during the build.
RUN python3 - "${UPSTREAM_VERSION}" "${MEM0_SOURCE_SHA256}" <<'PY'
import hashlib
import io
import sys
import tarfile
import urllib.request

version, expected = sys.argv[1], sys.argv[2]
url = f"https://github.com/mem0ai/mem0/archive/refs/tags/v{version}.tar.gz"
with urllib.request.urlopen(url, timeout=120) as response:
    data = response.read()
digest = hashlib.sha256(data).hexdigest()
if digest != expected:
    raise SystemExit(f"mem0 source checksum mismatch: {digest} != {expected}")

with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
    for member in archive.getmembers():
        parts = member.name.split("/")
        if len(parts) < 3 or parts[1] != "server" or not member.isfile():
            continue
        member.name = "/".join(parts[2:])
        archive.extract(member, "/app", filter="data")
PY

RUN pip install --no-cache-dir "mem0ai==${UPSTREAM_VERSION}" && \
    pip install --no-cache-dir -r /app/requirements.txt && \
    pip install --no-cache-dir "psycopg[binary]>=3.2.8"
# The binary extra bundles libpq: python:3.12-slim ships no libpq and the
# upstream requirements pin psycopg without an implementation extra.

# jq backs the entrypoint option validation, mirroring the other add-ons.
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq && \
    rm -rf /var/lib/apt/lists/*

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint
COPY rootfs/usr/local/bin/addon-healthcheck /usr/local/bin/addon-healthcheck

RUN chmod 0755 /usr/local/bin/addon-entrypoint /usr/local/bin/addon-healthcheck

ENTRYPOINT ["/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
    CMD ["/usr/local/bin/addon-healthcheck"]
