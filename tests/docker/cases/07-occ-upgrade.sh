#!/usr/bin/env bash
# Test: occ upgrade --no-interaction exits 0 on a freshly installed, up-to-date instance.
# On a current install the command should report "Update successful" or "already up-to-date".
source "$(dirname "$0")/../harness.sh"

echo "--- 07: occ upgrade ---"

OUT=$(occ upgrade --no-interaction 2>&1)
EXIT=$?

if [[ $EXIT -eq 0 ]]; then
    pass "occ upgrade --no-interaction exits 0"
else
    fail "occ upgrade --no-interaction exited $EXIT: $OUT"
fi
