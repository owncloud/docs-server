#!/usr/bin/env bash
# Test: occ status reports installed=true and a version 11.x string.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

echo "--- 02: occ status ---"

OUT=$(occ status --output=json 2>&1)
assert_contains "$OUT" '"installed":true'       "occ status: installed=true"
assert_contains "$OUT" '"versionstring":"11.'   "occ status: versionstring starts with 11."
assert_contains "$OUT" '"edition"'              "occ status: edition key present"
