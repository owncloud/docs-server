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

PROJECT_NAME="oc-compose-smoke"

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

# ---------------------------------------------------------------------------

log "Validating the merged compose configuration"
compose config >/dev/null
pass "compose config is valid"

log "Booting the stack"
compose up -d

# Wait until every container with a healthcheck reports "healthy".
log "Waiting for containers to become healthy (timeout ${HEALTH_TIMEOUT}s)"
deadline=$(( $(date +%s) + HEALTH_TIMEOUT ))
while true; do
  # IDs of containers that declare a healthcheck but are not yet healthy.
  unhealthy=""
  while read -r cid; do
    [ -n "${cid}" ] || continue
    status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${cid}")
    name=$(docker inspect -f '{{.Name}}' "${cid}")
    if [ "${status}" != "none" ] && [ "${status}" != "healthy" ]; then
      unhealthy="${unhealthy} ${name#/}(${status})"
    fi
  done < <(compose ps -q)

  if [ -z "${unhealthy}" ]; then
    pass "all containers with a healthcheck are healthy"
    break
  fi
  if [ "$(date +%s)" -ge "${deadline}" ]; then
    fail "timed out waiting for containers:${unhealthy}"
    exit 1
  fi
  sleep 5
done

# ownCloud status.php — poll until first-run install completes.
log "Checking ownCloud https://${OWNCLOUD_HOST}/status.php"
deadline=$(( $(date +%s) + INSTALL_TIMEOUT ))
while true; do
  body=$(curl -sk --max-time 10 \
    --resolve "${OWNCLOUD_HOST}:443:127.0.0.1" \
    "https://${OWNCLOUD_HOST}/status.php" || true)
  if printf '%s' "${body}" | grep -q '"installed":true'; then
    pass "status.php reports installed=true"
    printf '      %s\n' "${body}"
    break
  fi
  if [ "$(date +%s)" -ge "${deadline}" ]; then
    fail "status.php did not report installed=true in time; last body: ${body}"
    exit 1
  fi
  sleep 5
done

# Collabora WOPI discovery.
log "Checking Collabora https://${COLLABORA_HOST}/hosting/discovery"
disco=$(curl -sk --max-time 15 \
  --resolve "${COLLABORA_HOST}:443:127.0.0.1" \
  "https://${COLLABORA_HOST}/hosting/discovery" || true)
if printf '%s' "${disco}" | grep -q '<wopi-discovery>'; then
  pass "Collabora returned a WOPI discovery document"
else
  fail "Collabora /hosting/discovery did not return a wopi-discovery document"
  printf '      %s\n' "${disco}"
  exit 1
fi

# Security regression guard: the data tier must NOT be published to the host.
log "Asserting MariaDB/Redis are not published to the host"
if compose config | grep -Eq 'published:\s*"?(3306|6379)"?'; then
  fail "compose config publishes a data-tier port (3306/6379) to the host"
  exit 1
fi
pass "no data-tier host port bindings in the merged config"

for port in 3306 6379; do
  if curl -s --max-time 3 "http://127.0.0.1:${port}" >/dev/null 2>&1; then
    fail "port ${port} answered on 127.0.0.1 — it must not be exposed"
    exit 1
  fi
done
pass "ports 3306 and 6379 are closed on the host"

log "All smoke-test assertions passed"
