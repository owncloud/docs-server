#!/usr/bin/env bash
# Test: occ background:cron sets the background job scheduler to Cron without error.
# This validates the documented 'background:cron' command runs cleanly.
[[ -n "${WORK_DIR:-}" ]] || { echo "ERROR: Run via tests/docker/run-tests.sh, not directly."; exit 1; }
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

echo "--- 05: occ background:cron ---"

assert_exit_0 occ background:cron
