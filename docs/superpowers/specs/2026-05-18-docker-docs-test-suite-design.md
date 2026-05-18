# Docker Documentation Test Suite — Design Spec

**Date:** 2026-05-18
**Branch:** feat/docker-only
**Target image:** `owncloud/server:11.0.0-prealpha`

---

## Goal

Spin up the exact `docker-compose.yml` shipped in the docs, run the `occ` commands described in the documentation against a live container, and produce an `ISSUES.md` listing every failure — ready to file as GitHub issues.

---

## Scope

- **In:** container health, `occ` command smoke tests, issues report, CI integration
- **Out:** web UI testing, HTTP endpoint checks, enterprise app commands, upgrade path testing

---

## File Layout

```
tests/docker/
  run-tests.sh          # entry point
  harness.sh            # shared assertion helpers
  env.test              # .env for test run (image pinned to 11.0.0-prealpha)
  cases/
    01-stack-health.sh  # all containers reach healthy within timeout
    02-occ-status.sh    # occ status: installed=true, version=11.x
    03-occ-app-list.sh  # app:list: non-empty, core apps present
    04-occ-config.sh    # config:app:get / config:app:set round-trip
    05-occ-background.sh# background:cron sets mode without error
    06-occ-maintenance.sh# maintenance:mode --on / --off round-trip
    07-occ-upgrade.sh   # upgrade --no-interaction exits 0 (already current)
    08-occ-user.sh      # user:list returns admin user

.github/workflows/docker-docs-test.yml  # CI workflow
```

---

## Harness (`harness.sh`)

Sourced by every test case file. Provides:

```bash
PASS=0; FAIL=0; ISSUES=()

pass()            # increment PASS, print ✓
fail()            # increment FAIL, print ✗, append to ISSUES array
assert_eq()       # compare two strings, pass or fail with label
assert_contains() # substring check, pass or fail with label
assert_exit_0()   # run command, pass if exit 0

occ()             # docker compose exec owncloud occ "$@"
                  # matches the documented occ-command-example-prefix-docker exactly
```

Each test case sources `harness.sh`, runs assertions, and returns. The `ISSUES` array and counters are accumulated across all case files by `run-tests.sh` sourcing each case file directly (not subshells), so the `PASS`, `FAIL`, and `ISSUES` variables remain in scope throughout the entire run.

---

## Test Case Format

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/../harness.sh"

echo "--- occ status ---"
OUT=$(occ status --output=json)
assert_contains "$OUT" '"installed":true'   "occ status: installed=true"
assert_contains "$OUT" '"versionstring":"11.' "occ status: version is 11.x"
```

---

## Stack Lifecycle (`run-tests.sh`)

1. Copy `docker-compose.yml` (from `modules/admin_manual/examples/installation/docker/`) and `env.test` (as `.env`) into a temp directory.
2. `docker compose up -d`
3. `wait_healthy 120` — poll every 5s; fail-fast if not all healthy within 120s.
4. Source each `cases/*.sh` in order.
5. `docker compose down -v` — always via `trap EXIT`, even on failure.
6. Write `ISSUES.md` if any failures were recorded.

---

## `env.test`

```bash
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

---

## Issues Output (`ISSUES.md`)

Generated at the end of a run if any assertions failed:

```markdown
# Docker Documentation Issues — 2026-05-18

Found N failures against owncloud/server:11.0.0-prealpha

- [ ] `occ status` versionstring is not 11.x — got "10.15.0"
- [ ] `occ background:cron` exited non-zero: <error output>
- [ ] Container owncloud_server did not reach healthy within 120s
```

Each line maps directly to a GitHub issue to file against the docs repo.

---

## CI Workflow (`.github/workflows/docker-docs-test.yml`)

- **Triggers:** push to `feat/docker-only`, pull_request targeting `master`
- **Runner:** `ubuntu-latest` (Docker pre-installed)
- **Steps:**
  1. Checkout repo
  2. `bash tests/docker/run-tests.sh`
  3. On failure: upload `ISSUES.md` as a workflow artifact

No matrix builds, no caching. Single job, minimal surface area.

---

## Non-Goals / Future Work

- Enterprise app commands (LDAP, ransomware, etc.) — need licensed apps
- Web UI / WebDAV HTTP assertions — would require curl checks, deferred to a later test tier
- Upgrade path testing — needs a pre-existing data volume
