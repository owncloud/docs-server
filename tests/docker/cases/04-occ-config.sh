#!/usr/bin/env bash
# Test: occ config:app:set writes a value; occ config:app:get reads it back.
# Uses a throw-away key in the 'testapp' namespace.
[[ -n "${WORK_DIR:-}" ]] || { echo "ERROR: Run via tests/docker/run-tests.sh, not directly."; exit 1; }
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

echo "--- 04: occ config round-trip ---"

KEY="test_suite_marker"
VALUE="hello_from_test"
APP="testapp"

# Write
assert_exit_0 occ config:app:set "$APP" "$KEY" --value="$VALUE"

# Read back
GOT=$(occ config:app:get "$APP" "$KEY" 2>&1)
assert_eq "$GOT" "$VALUE" "config:app:get returns written value"

# Clean up
occ config:app:delete "$APP" "$KEY" >/dev/null 2>&1 || true
