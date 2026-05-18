#!/usr/bin/env bash
# Test: occ app:list returns output and includes known core apps.
[[ -n "${WORK_DIR:-}" ]] || { echo "ERROR: Run via tests/docker/run-tests.sh, not directly."; exit 1; }
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

echo "--- 03: occ app:list ---"

OUT=$(occ app:list 2>&1)
assert_contains "$OUT" "files"                "app:list: 'files' app present"
assert_contains "$OUT" "dav"                  "app:list: 'dav' app present"
assert_contains "$OUT" "federatedfilesharing" "app:list: 'federatedfilesharing' app present"
