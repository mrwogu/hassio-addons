#!/bin/sh
# Fake upstream startup script used by adapter tests.
if [ -n "${HINDSIGHT_FAKE_MARKER:-}" ]; then
    printf 'started\n' >"$HINDSIGHT_FAKE_MARKER"
fi
exit 0
