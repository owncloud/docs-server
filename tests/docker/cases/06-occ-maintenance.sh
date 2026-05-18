#!/usr/bin/env bash
# Test: occ maintenance:mode --on enables maintenance mode, --off disables it.
# Verifies the documented round-trip works.
source "$(dirname "$0")/../harness.sh"

echo "--- 06: occ maintenance:mode ---"

assert_exit_0 occ maintenance:mode --on

STATUS=$(occ maintenance:mode 2>&1)
assert_contains "$STATUS" "enabled" "maintenance:mode --on: mode is enabled"

assert_exit_0 occ maintenance:mode --off

STATUS=$(occ maintenance:mode 2>&1)
assert_contains "$STATUS" "disabled" "maintenance:mode --off: mode is disabled"
