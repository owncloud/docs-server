#!/usr/bin/env bash
#
# Smoke test for the shipped ownCloud + Collabora CODE docker-compose example.
#
# It boots the REAL example file
# (modules/admin_manual/examples/installation/docker/docker-compose.yml) with a
# local override + test env (self-signed TLS, pinned images, *.localhost hosts),
# waits for the containers to become healthy, and asserts that:
#   1. ownCloud answers on https://owncloud.localhost/status.php with installed=true
#   2. Collabora answers on https://collabora.localhost/hosting/discovery (WOPI XML)
#   3. MariaDB (3306) and Redis (6379) are NOT reachable on the host (security
#      regression guard — the hardened compose must not publish them)
#
# The stack is always torn down (docker compose down -v) on exit.
#
# Usage: tests/docker-compose/smoke-test.sh
# Requires: docker (with the compose plugin) and curl.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EXAMPLE_DIR="${REPO_ROOT}/modules/admin_manual/examples/installation/docker"

BASE_COMPOSE="${EXAMPLE_DIR}/docker-compose.yml"
OVERRIDE_COMPOSE="${SCRIPT_DIR}/docker-compose.override.yml"
ENV_FILE="${SCRIPT_DIR}/test.env"

# Must match the top-level "name:" in the shipped compose file. Compose derives
# the network names from the project name ("<project>_frontend"), and the
# ownCloud service's traefik.docker.network label refers to "owncloud_frontend"
# by that exact name — a different project name would break proxy routing here
# while leaving the shipped example working, i.e. testing a different stack.
# Consequence: this harness reuses the example's container/network names, so it
# cannot run next to a real deployment of the same example on one host.
PROJECT_NAME="owncloud"

# How long to wait for every container to report healthy.
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-300}"
# How long to wait for the ownCloud first-run install to finish (status.php).
INSTALL_TIMEOUT="${INSTALL_TIMEOUT:-300}"

OWNCLOUD_HOST="owncloud.localhost"
COLLABORA_HOST="collabora.localhost"

compose() {
  docker compose \
    --project-name "${PROJECT_NAME}" \
    --env-file "${ENV_FILE}" \
    -f "${BASE_COMPOSE}" \
    -f "${OVERRIDE_COMPOSE}" \
    "$@"
}

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
pass() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m  ✗\033[0m %s\n' "$*" >&2; }

cleanup() {
  local rc=$?
  if [ "${rc}" -ne 0 ]; then
    log "FAILURE (exit ${rc}) — dumping container status and logs"
    compose ps || true
    compose logs --no-color --tail 100 || true
  fi
  log "Tearing down the stack"
  compose down --volumes --remove-orphans || true
  exit "${rc}"
}
trap cleanup EXIT

# Poll until "$1" (a shell snippet) succeeds, or "$2" seconds elapse.
#   poll_until <condition> <timeout> <description> [on_timeout]
# Shared by the health / status.php / WOPI-discovery waits below so the
# deadline+sleep scaffolding exists once.
#
# <condition> and <on_timeout> are `eval`ed, so callers pass them SINGLE-quoted
# on purpose: they must be re-evaluated on each iteration / at timeout. Double
# quoting would expand them once at call time and freeze the then-empty values
# into the diagnostics. Hence the `shellcheck disable=SC2016` markers at the
# call sites.
poll_until() {
  local condition="$1" timeout="$2" description="$3" on_timeout="${4:-}"
  local deadline=$(( $(date +%s) + timeout ))
  while true; do
    if eval "${condition}"; then
      return 0
    fi
    if [ "$(date +%s)" -ge "${deadline}" ]; then
      fail "timed out after ${timeout}s waiting for ${description}"
      [ -n "${on_timeout}" ] && eval "${on_timeout}"
      return 1
    fi
    sleep 5
  done
}

# ---------------------------------------------------------------------------

log "Validating the merged compose configuration"
compose config >/dev/null
pass "compose config is valid"

# Clear any stale state from a previous run that died without its EXIT trap
# firing (CI OOM/timeout, SIGKILL). A leftover MariaDB volume still holds the
# old root password, so the healthcheck below would fail for reasons that have
# nothing to do with the compose example under test.
log "Removing any leftovers from a previous run"
compose down --volumes --remove-orphans

log "Booting the stack"
compose up -d

# Reports the containers that declare a healthcheck but are not yet healthy.
# One `docker inspect` call per container, emitting "<name> <status>" pairs.
unhealthy_containers() {
  local cids
  cids=$(compose ps -q)
  [ -n "${cids}" ] || return 0
  # shellcheck disable=SC2086
  docker inspect \
    -f '{{if .State.Health}}{{printf "%s(%s)" .Name .State.Health.Status}}{{end}}' \
    ${cids} | sed 's|^/||' | grep -v '(healthy)$' || true
}

log "Waiting for containers to become healthy (timeout ${HEALTH_TIMEOUT}s)"
# shellcheck disable=SC2016  # deferred expansion is intended — see poll_until
poll_until '[ -z "$(unhealthy_containers)" ]' "${HEALTH_TIMEOUT}" \
  "containers to report healthy" \
  'printf "      still not healthy: %s\n" "$(unhealthy_containers | tr "\n" " ")"' \
  || exit 1
pass "all containers with a healthcheck are healthy"

# Fetches an HTTPS URL through the proxy and asserts the body contains a marker.
# `last_body` is kept for the timeout diagnostics.
#   https_body_contains <host> <path> <marker> [max_time]
last_body=""
https_body_contains() {
  local host="$1" path="$2" marker="$3" max_time="${4:-10}"
  last_body=$(curl -sk --max-time "${max_time}" \
    --resolve "${host}:443:127.0.0.1" "https://${host}${path}" || true)
  # Pure-bash substring match: do NOT pipe into `grep -q`. Under `set -o
  # pipefail`, grep -q closes the pipe on the first match, the writer then dies
  # with SIGPIPE, and the pipeline reports failure even though the match succeeded.
  [[ "${last_body}" == *"${marker}"* ]]
}

# ownCloud status.php — poll until first-run install completes.
log "Checking ownCloud https://${OWNCLOUD_HOST}/status.php"
# shellcheck disable=SC2016  # deferred expansion is intended — see poll_until
poll_until "https_body_contains '${OWNCLOUD_HOST}' /status.php '\"installed\":true'" \
  "${INSTALL_TIMEOUT}" "status.php to report installed=true" \
  'printf "      last body: %s\n" "${last_body}"' \
  || exit 1
pass "status.php reports installed=true"
printf '      %s\n' "${last_body}"

# Collabora WOPI discovery. CODE has no healthcheck (so the health-wait above
# does not cover it) and, while it is still starting, the proxy returns 404/502
# for this path. Poll until the discovery document is served or we time out.
log "Checking Collabora https://${COLLABORA_HOST}/hosting/discovery"
# shellcheck disable=SC2016  # deferred expansion is intended — see poll_until
poll_until "https_body_contains '${COLLABORA_HOST}' /hosting/discovery '<wopi-discovery>' 15" \
  "${INSTALL_TIMEOUT}" "Collabora to serve a WOPI discovery document" \
  'printf "      last body: %s\n" "${last_body}"' \
  || exit 1
pass "Collabora returned a WOPI discovery document"

# Security regression guard: the data tier must NOT be published to the host.
# Capture the config first, then match — piping `compose config` straight into
# `grep -Eq` is unsafe under `set -o pipefail`: a match makes grep close the
# pipe, compose dies with SIGPIPE, and the non-zero pipeline status inverts the
# result, silently hiding a real port exposure.
log "Asserting MariaDB/Redis are not published to the host"
merged_config=$(compose config)
if [[ "${merged_config}" =~ published:[[:space:]]*\"?(3306|6379)\"? ]]; then
  fail "compose config publishes a data-tier port (3306/6379) to the host"
  exit 1
fi
pass "no data-tier host port bindings in the merged config"

# Probe with a raw TCP connect, NOT curl: MariaDB and Redis do not speak HTTP,
# so `curl http://127.0.0.1:<port>` never exits 0 even when the port is wide open
# (it returns 52 "empty reply" for an open port vs 7 "refused" for a closed one).
# A curl-based guard therefore always passes and could never catch the very
# regression it exists to catch. /dev/tcp succeeds on connect alone.
for port in 3306 6379; do
  if (exec 3<>"/dev/tcp/127.0.0.1/${port}") 2>/dev/null; then
    fail "port ${port} accepted a TCP connection on 127.0.0.1 — it must not be exposed"
    exit 1
  fi
done
pass "ports 3306 and 6379 refuse connections on the host"

log "All smoke-test assertions passed"
