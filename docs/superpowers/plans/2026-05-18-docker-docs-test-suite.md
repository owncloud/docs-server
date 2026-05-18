# Docker Documentation Test Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a portable bash test suite that spins up the documented ownCloud 11 Docker stack, runs documented `occ` commands against a live container, and writes `ISSUES.md` listing every failure — suitable for both local use and GitHub Actions CI.

**Architecture:** A thin bash harness (`harness.sh`) is sourced by numbered test case files in `tests/docker/cases/`. The entry point (`run-tests.sh`) copies the repo's existing `docker-compose.yml` to a temp dir, brings the stack up, sources each case file in order, tears down, then writes `ISSUES.md`. A GitHub Actions workflow calls `run-tests.sh` and uploads `ISSUES.md` as an artifact on failure.

**Tech Stack:** bash, Docker Compose v2, `docker compose exec`, GitHub Actions (`ubuntu-latest`)

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `tests/docker/harness.sh` | Create | `pass`/`fail`/`assert_*`/`occ` helpers; `PASS`, `FAIL`, `ISSUES` accumulators |
| `tests/docker/env.test` | Create | `.env` values pinned to `owncloud/server:11.0.0-prealpha` |
| `tests/docker/run-tests.sh` | Create | Entry point: stack lifecycle, source cases, write `ISSUES.md` |
| `tests/docker/cases/01-stack-health.sh` | Create | All three containers reach `healthy` within 120s |
| `tests/docker/cases/02-occ-status.sh` | Create | `occ status` returns `installed:true` and version `11.x` |
| `tests/docker/cases/03-occ-app-list.sh` | Create | `occ app:list` returns output containing known core apps |
| `tests/docker/cases/04-occ-config.sh` | Create | `occ config:app:set` / `config:app:get` round-trip |
| `tests/docker/cases/05-occ-background.sh` | Create | `occ background:cron` exits 0 |
| `tests/docker/cases/06-occ-maintenance.sh` | Create | `occ maintenance:mode --on` / `--off` round-trip |
| `tests/docker/cases/07-occ-upgrade.sh` | Create | `occ upgrade --no-interaction` exits 0 on a current install |
| `tests/docker/cases/08-occ-user.sh` | Create | `occ user:list` output contains `admin` |
| `.github/workflows/docker-docs-test.yml` | Create | CI: triggers on push/PR, runs suite, uploads `ISSUES.md` artifact |

---

### Task 1: Harness

**Files:**
- Create: `tests/docker/harness.sh`

- [ ] **Step 1: Create the harness file**

```bash
#!/usr/bin/env bash
# Shared test harness — source this file, do not execute directly.
# Provides: pass, fail, assert_eq, assert_contains, assert_exit_0, occ
# Accumulates: PASS, FAIL, ISSUES (arrays/counters across all sourced case files)

PASS=${PASS:-0}
FAIL=${FAIL:-0}
ISSUES=${ISSUES:-()}   # re-declaration is harmless when already set by run-tests.sh

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
    local label="$*"
    if "$@" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "command exited non-zero: $label"
    fi
}

# occ COMMAND [ARGS...] — runs occ inside the owncloud container.
# Matches the documented occ-command-example-prefix-docker exactly.
occ() {
    docker compose exec owncloud occ "$@"
}
```

- [ ] **Step 2: Make it non-executable (it is sourced, never run directly)**

```bash
chmod -x tests/docker/harness.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/docker/harness.sh
git commit -s -m "test: add docker test harness (pass/fail/assert/occ helpers)"
```

---

### Task 2: env.test

**Files:**
- Create: `tests/docker/env.test`

- [ ] **Step 1: Create the env file**

```bash
# Test environment — copied as .env alongside docker-compose.yml by run-tests.sh
OWNCLOUD_IMAGE=11.0.0-prealpha
OWNCLOUD_DOMAIN=localhost
OWNCLOUD_TRUSTED_DOMAINS=localhost
OWNCLOUD_OVERWRITE_CLI_URL=http://localhost
HTTP_PORT=8080
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin
MARIADB_IMAGE=10.11
REDIS_IMAGE=7
```

- [ ] **Step 2: Commit**

```bash
git add tests/docker/env.test
git commit -s -m "test: add env.test pinned to owncloud/server:11.0.0-prealpha"
```

---

### Task 3: Test case 01 — stack health

**Files:**
- Create: `tests/docker/cases/01-stack-health.sh`

- [ ] **Step 1: Create the test case**

```bash
#!/usr/bin/env bash
# Test: all three containers reach healthy state within 120 seconds.
# run-tests.sh calls wait_healthy before sourcing cases, so if we reach
# this file the stack is already healthy — this case validates that the
# wait_healthy function in run-tests.sh didn't time out and skip cases.
source "$(dirname "$0")/../harness.sh"

echo "--- 01: stack health ---"

for container in owncloud_server owncloud_mariadb owncloud_redis; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "missing")
    assert_eq "$STATUS" "healthy" "container $container is healthy"
done
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/docker/cases/01-stack-health.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/docker/cases/01-stack-health.sh
git commit -s -m "test: add case 01 — stack health check"
```

---

### Task 4: Test case 02 — occ status

**Files:**
- Create: `tests/docker/cases/02-occ-status.sh`

- [ ] **Step 1: Create the test case**

```bash
#!/usr/bin/env bash
# Test: occ status reports installed=true and a version 11.x string.
source "$(dirname "$0")/../harness.sh"

echo "--- 02: occ status ---"

OUT=$(occ status --output=json 2>&1)
assert_contains "$OUT" '"installed":true'       "occ status: installed=true"
assert_contains "$OUT" '"versionstring":"11.'   "occ status: versionstring starts with 11."
assert_contains "$OUT" '"edition"'              "occ status: edition key present"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/docker/cases/02-occ-status.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/docker/cases/02-occ-status.sh
git commit -s -m "test: add case 02 — occ status"
```

---

### Task 5: Test case 03 — occ app:list

**Files:**
- Create: `tests/docker/cases/03-occ-app-list.sh`

- [ ] **Step 1: Create the test case**

```bash
#!/usr/bin/env bash
# Test: occ app:list returns output and includes known core apps.
source "$(dirname "$0")/../harness.sh"

echo "--- 03: occ app:list ---"

OUT=$(occ app:list 2>&1)
assert_contains "$OUT" "files"          "app:list: 'files' app present"
assert_contains "$OUT" "dav"            "app:list: 'dav' app present"
assert_contains "$OUT" "federatedfilesharing" "app:list: 'federatedfilesharing' app present"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/docker/cases/03-occ-app-list.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/docker/cases/03-occ-app-list.sh
git commit -s -m "test: add case 03 — occ app:list"
```

---

### Task 6: Test case 04 — occ config round-trip

**Files:**
- Create: `tests/docker/cases/04-occ-config.sh`

- [ ] **Step 1: Create the test case**

```bash
#!/usr/bin/env bash
# Test: occ config:app:set writes a value; occ config:app:get reads it back.
# Uses a throw-away key in the 'testapp' namespace.
source "$(dirname "$0")/../harness.sh"

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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/docker/cases/04-occ-config.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/docker/cases/04-occ-config.sh
git commit -s -m "test: add case 04 — occ config:app:set/get round-trip"
```

---

### Task 7: Test case 05 — occ background:cron

**Files:**
- Create: `tests/docker/cases/05-occ-background.sh`

- [ ] **Step 1: Create the test case**

```bash
#!/usr/bin/env bash
# Test: occ background:cron sets the background job scheduler to Cron without error.
# This validates the documented 'background:cron' command runs cleanly.
source "$(dirname "$0")/../harness.sh"

echo "--- 05: occ background:cron ---"

assert_exit_0 occ background:cron
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/docker/cases/05-occ-background.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/docker/cases/05-occ-background.sh
git commit -s -m "test: add case 05 — occ background:cron"
```

---

### Task 8: Test case 06 — occ maintenance:mode

**Files:**
- Create: `tests/docker/cases/06-occ-maintenance.sh`

- [ ] **Step 1: Create the test case**

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/docker/cases/06-occ-maintenance.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/docker/cases/06-occ-maintenance.sh
git commit -s -m "test: add case 06 — occ maintenance:mode round-trip"
```

---

### Task 9: Test case 07 — occ upgrade

**Files:**
- Create: `tests/docker/cases/07-occ-upgrade.sh`

- [ ] **Step 1: Create the test case**

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/docker/cases/07-occ-upgrade.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/docker/cases/07-occ-upgrade.sh
git commit -s -m "test: add case 07 — occ upgrade on fresh install"
```

---

### Task 10: Test case 08 — occ user:list

**Files:**
- Create: `tests/docker/cases/08-occ-user.sh`

- [ ] **Step 1: Create the test case**

```bash
#!/usr/bin/env bash
# Test: occ user:list output contains the admin user configured in env.test.
source "$(dirname "$0")/../harness.sh"

echo "--- 08: occ user:list ---"

OUT=$(occ user:list 2>&1)
# ADMIN_USERNAME is set in .env (env.test) as 'admin'
assert_contains "$OUT" "admin" "user:list: admin user present"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/docker/cases/08-occ-user.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/docker/cases/08-occ-user.sh
git commit -s -m "test: add case 08 — occ user:list"
```

---

### Task 11: Entry point — run-tests.sh

**Files:**
- Create: `tests/docker/run-tests.sh`

- [ ] **Step 1: Create the entry point**

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_SRC="$REPO_ROOT/modules/admin_manual/examples/installation/docker/docker-compose.yml"
ENV_SRC="$REPO_ROOT/tests/docker/env.test"
CASES_DIR="$REPO_ROOT/tests/docker/cases"
ISSUES_OUT="$REPO_ROOT/ISSUES.md"

# --- Harness accumulators (shared across all sourced case files) ---
PASS=0
FAIL=0
ISSUES=()

# --- Temp working directory for docker compose ---
WORK_DIR=$(mktemp -d)
trap 'echo ""; echo "Tearing down stack..."; cd "$WORK_DIR" && docker compose down -v --remove-orphans 2>/dev/null || true; rm -rf "$WORK_DIR"' EXIT

cp "$COMPOSE_SRC" "$WORK_DIR/docker-compose.yml"
cp "$ENV_SRC"     "$WORK_DIR/.env"
cd "$WORK_DIR"

# --- Bring stack up ---
echo "Starting stack with image: $(grep OWNCLOUD_IMAGE "$WORK_DIR/.env" | cut -d= -f2)"
docker compose up -d

# --- Wait for all services to be healthy ---
wait_healthy() {
    local timeout=$1
    local elapsed=0
    echo "Waiting for healthy containers (timeout ${timeout}s)..."
    while [[ $elapsed -lt $timeout ]]; do
        local unhealthy
        unhealthy=$(docker compose ps --format json 2>/dev/null \
            | python3 -c "
import sys, json
data = sys.stdin.read().strip()
rows = [json.loads(l) for l in data.splitlines() if l.strip()]
print(' '.join(r.get('Name','') for r in rows if r.get('Health','') not in ('healthy','')))
" 2>/dev/null || echo "parse_error")
        if [[ -z "$unhealthy" || "$unhealthy" == "parse_error" ]]; then
            # Fallback: check via docker inspect
            local all_healthy=true
            for c in owncloud_server owncloud_mariadb owncloud_redis; do
                local s
                s=$(docker inspect --format='{{.State.Health.Status}}' "$c" 2>/dev/null || echo "missing")
                [[ "$s" != "healthy" ]] && all_healthy=false
            done
            $all_healthy && { echo "All containers healthy."; return 0; }
        else
            [[ -z "$unhealthy" ]] && { echo "All containers healthy."; return 0; }
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo "  still waiting... (${elapsed}s)"
    done
    echo "ERROR: containers did not reach healthy within ${timeout}s"
    FAIL=$((FAIL + 1))
    ISSUES+=("Containers did not reach healthy within ${timeout}s — stack may not be functional")
    return 1
}

wait_healthy 120 || true  # allow cases to run even after timeout to gather more data

# --- Run cases ---
echo ""
echo "Running test cases..."
echo ""
for case_file in "$CASES_DIR"/[0-9]*.sh; do
    # shellcheck source=/dev/null
    source "$case_file"
    echo ""
done

# --- Summary ---
TOTAL=$((PASS + FAIL))
echo "========================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

# --- Write ISSUES.md ---
if [[ $FAIL -gt 0 ]]; then
    DATE=$(date +%Y-%m-%d)
    IMAGE=$(grep OWNCLOUD_IMAGE "$WORK_DIR/.env" | cut -d= -f2)
    {
        echo "# Docker Documentation Issues — $DATE"
        echo ""
        echo "Found $FAIL failure(s) against \`owncloud/server:$IMAGE\`"
        echo ""
        for issue in "${ISSUES[@]}"; do
            echo "- [ ] $issue"
        done
    } > "$ISSUES_OUT"
    echo ""
    echo "Issues written to: $ISSUES_OUT"
    exit 1
else
    echo ""
    echo "All tests passed. No issues found."
    exit 0
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/docker/run-tests.sh
```

- [ ] **Step 3: Smoke-check the script parses without errors**

```bash
bash -n tests/docker/run-tests.sh
```

Expected: no output (clean parse).

- [ ] **Step 4: Commit**

```bash
git add tests/docker/run-tests.sh
git commit -s -m "test: add run-tests.sh entry point with stack lifecycle and ISSUES.md output"
```

---

### Task 12: GitHub Actions workflow

**Files:**
- Create: `.github/workflows/docker-docs-test.yml`

- [ ] **Step 1: Create the workflow**

```yaml
name: Docker Docs Test Suite

on:
  push:
    branches:
      - feat/docker-only
  pull_request:
    branches:
      - master

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Docker documentation test suite
        run: bash tests/docker/run-tests.sh

      - name: Upload ISSUES.md on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: issues-report
          path: ISSUES.md
          if-no-files-found: ignore
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/docker-docs-test.yml
git commit -s -m "ci: add GitHub Actions workflow for docker docs test suite"
```

---

### Task 13: Local smoke run

This task validates the complete suite runs end-to-end locally.

- [ ] **Step 1: Pull the pre-alpha image (may take a few minutes)**

```bash
docker pull owncloud/server:11.0.0-prealpha
```

Expected: image pulled or "Image is up to date".

- [ ] **Step 2: Run the full test suite**

```bash
bash tests/docker/run-tests.sh
```

Expected: output showing each test case running, a results summary, exit 0 if all pass. If failures occur, `ISSUES.md` is written to the repo root.

- [ ] **Step 3: Review ISSUES.md (if it exists)**

```bash
cat ISSUES.md 2>/dev/null || echo "No issues found — all tests passed."
```

- [ ] **Step 4: Commit ISSUES.md if produced (do not commit if absent)**

If `ISSUES.md` was produced:
```bash
git add ISSUES.md
git commit -s -m "test: add initial ISSUES.md from first run against 11.0.0-prealpha"
```

---

## Self-Review

**Spec coverage:**

| Spec requirement | Covered by |
|---|---|
| Portable bash runner | `run-tests.sh` + `harness.sh` |
| Works locally and in CI | Task 13 (local), Task 12 (CI) |
| Uses `owncloud/server:11.0.0-prealpha` | `env.test` |
| Uses repo's `docker-compose.yml` | `run-tests.sh` copies it from `modules/admin_manual/examples/installation/docker/` |
| Stack health check | Case 01, `wait_healthy` in `run-tests.sh` |
| occ command smoke tests | Cases 02–08 |
| `occ()` matches documented prefix | `harness.sh` `occ()` function |
| Issues output as `ISSUES.md` | `run-tests.sh` end section |
| GitHub Actions CI | Task 12 |
| Artifact upload on failure | `.github/workflows/docker-docs-test.yml` |

**Placeholder scan:** None found. All code blocks are complete.

**Type/name consistency:** `PASS`, `FAIL`, `ISSUES` defined in `run-tests.sh` before any case is sourced; `harness.sh` initialises with `:-` defaults so it is safe to source standalone for unit-testing the harness itself. `occ()` name is consistent across all case files. `wait_healthy` is defined before it is called.
