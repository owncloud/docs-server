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
