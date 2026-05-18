#!/usr/bin/env bash
# Test: occ user:list output contains the admin user configured in env.test.
[[ -n "${WORK_DIR:-}" ]] || { echo "ERROR: Run via tests/docker/run-tests.sh, not directly."; exit 1; }
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

echo "--- 08: occ user:list ---"

OUT=$(occ user:list 2>&1)
# ADMIN_USERNAME is set in .env (env.test) as 'admin'
assert_contains "$OUT" "- admin" "user:list: admin user present (plain text format)"
