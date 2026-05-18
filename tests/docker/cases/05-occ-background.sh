#!/usr/bin/env bash
# Test: occ background:cron sets the background job scheduler to Cron without error.
# This validates the documented 'background:cron' command runs cleanly.
source "$(dirname "$0")/../harness.sh"

echo "--- 05: occ background:cron ---"

assert_exit_0 occ background:cron
