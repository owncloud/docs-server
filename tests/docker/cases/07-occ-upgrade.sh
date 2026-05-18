#!/usr/bin/env bash
# Test: occ upgrade --no-interaction exits 0 on a freshly installed, up-to-date instance.
# On a current install the command should report "Update successful" or "already up-to-date".
[[ -n "${WORK_DIR:-}" ]] || { echo "ERROR: Run via tests/docker/run-tests.sh, not directly."; exit 1; }
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

echo "--- 07: occ upgrade ---"

# Capture output and exit code safely under set -e.
OUT=$(occ upgrade --no-interaction 2>&1) && EXIT=0 || EXIT=$?

# Exit 0  = upgrade applied successfully.
# Exit 3  = already up-to-date ("ownCloud is already latest version") — also a success.
# Any other code is a real failure.
if [[ $EXIT -eq 0 || $EXIT -eq 3 ]]; then
    pass "occ upgrade --no-interaction exits $EXIT (upgrade applied or already up-to-date)"
else
    fail "occ upgrade --no-interaction exited $EXIT: $OUT"
fi
