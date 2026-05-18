#!/usr/bin/env bash
# Shared test harness — source this file, do not execute directly.
# Provides: pass, fail, assert_eq, assert_contains, assert_exit_0, occ
# Accumulates: PASS, FAIL, ISSUES (arrays/counters across all sourced case files)

PASS=${PASS:-0}
FAIL=${FAIL:-0}
if [[ -z "${ISSUES+set}" ]]; then
    ISSUES=()
fi

pass() {
    PASS=$((PASS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  ✗ $1"
    ISSUES+=("$1")
}

# assert_eq ACTUAL EXPECTED LABEL
assert_eq() {
    local actual="$1" expected="$2" label="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label: expected '$expected', got '$actual'"
    fi
}

# assert_contains HAYSTACK NEEDLE LABEL
assert_contains() {
    local haystack="$1" needle="$2" label="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$label"
    else
        fail "$label: output does not contain '$needle'"
    fi
}

# assert_exit_0 COMMAND [ARGS...]
assert_exit_0() {
    local label="$*" out
    if out=$("$@" 2>&1); then
        pass "$label"
    else
        fail "command exited non-zero: $label"
        echo "    output: $out" >&2
    fi
}

# occ COMMAND [ARGS...] — runs occ inside the owncloud container.
# Matches the documented occ-command-example-prefix-docker exactly.
occ() {
    docker compose exec owncloud occ "$@"
}
