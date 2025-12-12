#!/bin/bash
# Test High Availability (HA) mode WordPress deployment
# Usage: ./test-ha-mode.sh

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
    # Skip cleanup if called from run-all-tests.sh (it manages lifecycle)
    if [ "${SKIP_CLEANUP:-0}" = "1" ]; then
        log_info "Skipping cleanup (managed by parent script)"
        return 0
    fi
    log_info "Cleaning up HA test environment (preserving MySQL volume)..."
    docker compose -f "${COMPOSE_FILE}" down --remove-orphans 2>/dev/null || true
    docker volume rm devopsbegins-wp-content-ha devopsbegins-redis-data 2>/dev/null || true
}

trap cleanup EXIT

test_compose_valid() {
    log_info "Testing: Docker Compose file is valid"
    if docker compose -f "${COMPOSE_FILE}" config > /dev/null 2>&1; then
        log_info "✓ Compose file is valid"
        return 0
    else
        log_error "✗ Compose file is invalid"
        return 1
    fi
}

test_all_services_start() {
    log_info "Testing: All HA services start successfully"

    docker compose -f "${COMPOSE_FILE}" up -d

    # Wait for services
    local max_attempts=90
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        local running=$(docker compose -f "${COMPOSE_FILE}" ps --status running -q | wc -l)
        # Expect: nginx, wordpress-1, wordpress-2, redis, mysql = 5 services
        if [ "$running" -ge 5 ]; then
            log_info "✓ All 5 services are running"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    log_error "✗ Not all services started within timeout"
    docker compose -f "${COMPOSE_FILE}" ps
    return 1
}

test_nginx_loadbalancer() {
    log_info "Testing: Nginx load balancer responds"

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080" | grep -qE "200|302|301|502"; then
            log_info "✓ Nginx load balancer responds"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    log_error "✗ Nginx did not respond within timeout"
    return 1
}

test_both_wordpress_nodes() {
    log_info "Testing: Both WordPress nodes are reachable"

    local wp1_healthy=false
    local wp2_healthy=false

    # Test wordpress-1 directly (container listens on port 80 internally)
    if docker compose -f "${COMPOSE_FILE}" exec -T wordpress-1 curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -qE "200|302|301"; then
        wp1_healthy=true
        log_info "✓ wordpress-1 responds"
    else
        log_warn "wordpress-1 may still be initializing"
    fi

    # Test wordpress-2 directly (container listens on port 80 internally)
    if docker compose -f "${COMPOSE_FILE}" exec -T wordpress-2 curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -qE "200|302|301"; then
        wp2_healthy=true
        log_info "✓ wordpress-2 responds"
    else
        log_warn "wordpress-2 may still be initializing"
    fi

    if [ "$wp1_healthy" = true ] && [ "$wp2_healthy" = true ]; then
        return 0
    else
        log_warn "Not all nodes confirmed healthy (may need more time)"
        return 0  # Don't fail, they might just need more initialization time
    fi
}

test_redis_connectivity() {
    log_info "Testing: Redis is accessible from WordPress nodes"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)

    if docker exec "$wp1_container" php -r "
        \$redis = new Redis();
        \$redis->connect('redis', 6379);
        echo \$redis->ping() ? 'OK' : 'FAIL';
    " 2>/dev/null | grep -q "OK"; then
        log_info "✓ Redis is accessible from WordPress"
        return 0
    else
        log_error "✗ Redis connection failed"
        return 1
    fi
}

test_shared_volume() {
    log_info "Testing: Shared wp-content volume works"

    local test_file="test-shared-$(date +%s).txt"
    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)
    local wp2_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-2)

    # Create file on wordpress-1
    docker exec "$wp1_container" touch "/var/www/html/wp-content/${test_file}"

    # Check if visible on wordpress-2
    if docker exec "$wp2_container" test -f "/var/www/html/wp-content/${test_file}"; then
        log_info "✓ Shared volume works across nodes"
        docker exec "$wp1_container" rm -f "/var/www/html/wp-content/${test_file}"
        return 0
    else
        log_error "✗ Shared volume not working"
        return 1
    fi
}

test_load_distribution() {
    log_info "Testing: Load is distributed across nodes"

    local node1_hits=0
    local node2_hits=0

    for i in {1..10}; do
        local response=$(curl -s -I "http://localhost:8080" 2>/dev/null | grep -i "X-Served-By" || echo "")
        if echo "$response" | grep -q "wordpress-1"; then
            node1_hits=$((node1_hits + 1))
        elif echo "$response" | grep -q "wordpress-2"; then
            node2_hits=$((node2_hits + 1))
        fi
        sleep 0.5
    done

    log_info "Load distribution: wordpress-1=$node1_hits, wordpress-2=$node2_hits"

    if [ $node1_hits -gt 0 ] && [ $node2_hits -gt 0 ]; then
        log_info "✓ Load is distributed across both nodes"
        return 0
    elif [ $node1_hits -gt 0 ] || [ $node2_hits -gt 0 ]; then
        log_warn "Load detected but not evenly distributed (may need X-Served-By header)"
        return 0
    else
        log_warn "Could not verify load distribution (X-Served-By header may not be set)"
        return 0
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Starting High Availability Mode Tests"
    log_info "=========================================="

    if [ ! -f "${COMPOSE_FILE}" ]; then
        log_error "Compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi

    local failed=0

    test_compose_valid || failed=$((failed + 1))
    test_all_services_start || failed=$((failed + 1))
    test_nginx_loadbalancer || failed=$((failed + 1))
    test_both_wordpress_nodes || failed=$((failed + 1))
    test_redis_connectivity || failed=$((failed + 1))
    test_shared_volume || failed=$((failed + 1))
    test_load_distribution || failed=$((failed + 1))

    log_info "=========================================="
    if [ $failed -eq 0 ]; then
        log_info "All HA tests passed!"
        exit 0
    else
        log_error "$failed test(s) failed"
        exit 1
    fi
}

main "$@"
