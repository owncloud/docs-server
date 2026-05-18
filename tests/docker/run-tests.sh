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
        local all_healthy=true
        for c in owncloud_server owncloud_mariadb owncloud_redis; do
            local s
            s=$(docker inspect --format='{{.State.Health.Status}}' "$c" 2>/dev/null || echo "missing")
            [[ "$s" != "healthy" ]] && all_healthy=false
        done
        $all_healthy && { echo "All containers healthy."; return 0; }
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
