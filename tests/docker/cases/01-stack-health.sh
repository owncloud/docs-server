#!/usr/bin/env bash
# Test: all three containers reach healthy state within 120 seconds.
# run-tests.sh calls wait_healthy before sourcing cases, so if we reach
# this file the stack is already healthy — this case validates that the
# wait_healthy function in run-tests.sh didn't time out and skip cases.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

echo "--- 01: stack health ---"

# mariadb and redis have Docker healthchecks
for container in owncloud_mariadb owncloud_redis; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "missing")
    assert_eq "$STATUS" "healthy" "container $container is healthy"
done

# owncloud_server has no Docker healthcheck — verify it is running and HTTP-reachable
SERVER_STATE=$(docker inspect --format='{{.State.Status}}' "owncloud_server" 2>/dev/null || echo "missing")
assert_eq "$SERVER_STATE" "running" "container owncloud_server is running"

HTTP_CODE=$(curl -so /dev/null -w "%{http_code}" --max-time 5 http://localhost:8080/status.php 2>/dev/null || echo "000")
assert_eq "$HTTP_CODE" "200" "owncloud /status.php returns HTTP 200"
