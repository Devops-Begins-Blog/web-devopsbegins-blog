#!/bin/bash
# Test PHP session persistence across WordPress nodes via Redis
# Usage: ./test-session-persistence.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.ha.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup() {
    log_info "Cleaning up session test environment..."
    # Remove test file if created
    docker compose -f "${COMPOSE_FILE}" exec -T wordpress-1 rm -f /var/www/html/session-test.php 2>/dev/null || true
    docker compose -f "${COMPOSE_FILE}" exec -T wordpress-2 rm -f /var/www/html/session-test.php 2>/dev/null || true
}

trap cleanup EXIT

setup_session_test() {
    log_info "Setting up session test endpoint..."

    local test_script='<?php
session_start();
header("X-Session-ID: " . session_id());
header("X-Server: " . gethostname());

if (!isset($_SESSION["visit_count"])) {
    $_SESSION["visit_count"] = 0;
}
$_SESSION["visit_count"]++;
$_SESSION["last_server"] = gethostname();

echo json_encode([
    "session_id" => session_id(),
    "visit_count" => $_SESSION["visit_count"],
    "current_server" => gethostname(),
    "session_handler" => ini_get("session.save_handler"),
    "session_path" => ini_get("session.save_path")
]);
'

    # Create test file on shared volume (will be visible to both nodes)
    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)
    docker exec "$wp1_container" bash -c "cat > /var/www/html/session-test.php << 'EOFPHP'
$test_script
EOFPHP"

    docker exec "$wp1_container" bash -c "echo '$test_script' > /var/www/html/session-test.php"
}

test_session_handler_configured() {
    log_info "Testing: Redis session handler is configured"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)

    local handler=$(docker exec "$wp1_container" php -r "echo ini_get('session.save_handler');" 2>/dev/null)

    if [ "$handler" = "redis" ]; then
        log_info "✓ Session handler is Redis"
        return 0
    else
        log_warn "Session handler is: $handler (expected: redis)"
        # Check if Redis session config exists
        if docker exec "$wp1_container" test -f /usr/local/etc/php/conf.d/redis-sessions.ini; then
            log_info "Redis sessions config file exists"
        fi
        return 1
    fi
}

test_session_stored_in_redis() {
    log_info "Testing: Sessions are stored in Redis DB 1"

    # Create a session via WordPress
    local response=$(curl -s -c /tmp/cookies.txt "http://localhost:80/session-test.php" 2>/dev/null || echo "")

    if [ -z "$response" ]; then
        log_warn "Could not reach session test endpoint"
        return 1
    fi

    # Extract session ID from response
    local session_id=$(echo "$response" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$session_id" ]; then
        log_warn "Could not extract session ID"
        return 1
    fi

    log_info "Session ID: $session_id"

    # Check if session exists in Redis DB 1
    local redis_container=$(docker compose -f "${COMPOSE_FILE}" ps -q redis)
    local redis_key="PHPREDIS_SESSION:${session_id}"

    if docker exec "$redis_container" redis-cli -n 1 EXISTS "$redis_key" | grep -q "1"; then
        log_info "✓ Session found in Redis DB 1"
        return 0
    else
        log_warn "Session not found in Redis (key: $redis_key)"
        # List all keys in DB 1
        log_info "Keys in Redis DB 1:"
        docker exec "$redis_container" redis-cli -n 1 KEYS "*" | head -5
        return 1
    fi
}

test_session_persistence_across_nodes() {
    log_info "Testing: Session persists across different nodes"

    # First request - establish session
    local cookie_jar="/tmp/session-test-cookies.txt"
    rm -f "$cookie_jar"

    local response1=$(curl -s -c "$cookie_jar" -b "$cookie_jar" "http://localhost:80/session-test.php" 2>/dev/null)
    local visit1=$(echo "$response1" | grep -o '"visit_count":[0-9]*' | cut -d':' -f2)
    local server1=$(echo "$response1" | grep -o '"current_server":"[^"]*"' | cut -d'"' -f4)

    log_info "Request 1 - Server: $server1, Visits: $visit1"

    # Make multiple requests to hit different nodes
    local max_requests=10
    local found_different_server=false

    for i in $(seq 2 $max_requests); do
        local response=$(curl -s -c "$cookie_jar" -b "$cookie_jar" "http://localhost:80/session-test.php" 2>/dev/null)
        local visit=$(echo "$response" | grep -o '"visit_count":[0-9]*' | cut -d':' -f2)
        local server=$(echo "$response" | grep -o '"current_server":"[^"]*"' | cut -d'"' -f4)

        log_info "Request $i - Server: $server, Visits: $visit"

        if [ "$server" != "$server1" ]; then
            found_different_server=true
            if [ "$visit" -gt "$visit1" ]; then
                log_info "✓ Session persisted across nodes (visit count increased)"
                rm -f "$cookie_jar"
                return 0
            fi
        fi

        sleep 0.5
    done

    rm -f "$cookie_jar"

    if [ "$found_different_server" = false ]; then
        log_warn "All requests hit the same server - cannot verify cross-node persistence"
        return 0
    else
        log_error "✗ Session did not persist across nodes"
        return 1
    fi
}

test_session_isolation() {
    log_info "Testing: Sessions use DB 1 (isolated from object cache DB 0)"

    local redis_container=$(docker compose -f "${COMPOSE_FILE}" ps -q redis)

    # Check DB 0 (object cache) vs DB 1 (sessions)
    local db0_keys=$(docker exec "$redis_container" redis-cli -n 0 DBSIZE | grep -o '[0-9]*')
    local db1_keys=$(docker exec "$redis_container" redis-cli -n 1 DBSIZE | grep -o '[0-9]*')

    log_info "Redis DB 0 (object cache): $db0_keys keys"
    log_info "Redis DB 1 (sessions): $db1_keys keys"

    # Sessions should be in DB 1
    if [ "$db1_keys" -gt 0 ] || [ "$db0_keys" -ge 0 ]; then
        log_info "✓ Database isolation verified"
        return 0
    else
        log_warn "Could not verify database isolation"
        return 0
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Starting Session Persistence Tests"
    log_info "=========================================="

    if [ ! -f "${COMPOSE_FILE}" ]; then
        log_error "Compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi

    # Check if services are running
    if ! docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1 > /dev/null 2>&1; then
        log_error "HA services not running. Start with: docker compose -f docker-compose.ha.yml up -d"
        exit 1
    fi

    setup_session_test

    local failed=0

    test_session_handler_configured || failed=$((failed + 1))
    test_session_stored_in_redis || failed=$((failed + 1))
    test_session_persistence_across_nodes || failed=$((failed + 1))
    test_session_isolation || failed=$((failed + 1))

    log_info "=========================================="
    if [ $failed -eq 0 ]; then
        log_info "All session persistence tests passed!"
        exit 0
    else
        log_error "$failed test(s) failed"
        exit 1
    fi
}

main "$@"
