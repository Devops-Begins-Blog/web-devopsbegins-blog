#!/bin/bash
# Test standalone mode WordPress deployment
# Usage: ./test-standalone-mode.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.standalone.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup() {
    log_info "Cleaning up standalone test environment..."
    docker compose -f "${COMPOSE_FILE}" down -v --remove-orphans 2>/dev/null || true
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

test_services_start() {
    log_info "Testing: Services start successfully"

    docker compose -f "${COMPOSE_FILE}" up -d

    # Wait for services to be healthy
    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker compose -f "${COMPOSE_FILE}" ps | grep -q "healthy"; then
            log_info "✓ Services started and healthy"
            return 0
        fi

        # Check if wordpress is at least running
        if docker compose -f "${COMPOSE_FILE}" ps wordpress 2>/dev/null | grep -q "Up"; then
            log_info "✓ WordPress service is running"
            break
        fi

        attempt=$((attempt + 1))
        sleep 2
    done

    if [ $attempt -eq $max_attempts ]; then
        log_error "✗ Services failed to start within timeout"
        docker compose -f "${COMPOSE_FILE}" logs
        return 1
    fi

    return 0
}

test_wordpress_responds() {
    log_info "Testing: WordPress responds to HTTP requests"

    local max_attempts=30
    local attempt=0
    local port="${WP_PORT:-8080}"

    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}" | grep -qE "200|302|301"; then
            log_info "✓ WordPress responds to HTTP requests"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    log_error "✗ WordPress did not respond within timeout"
    return 1
}

test_wp_content_seeded() {
    log_info "Testing: wp-content is properly seeded"

    local container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress)

    if [ -z "$container" ]; then
        log_error "✗ WordPress container not found"
        return 1
    fi

    # Check for default directories
    if docker exec "$container" test -d /var/www/html/wp-content/themes && \
       docker exec "$container" test -d /var/www/html/wp-content/plugins && \
       docker exec "$container" test -d /var/www/html/wp-content/uploads; then
        log_info "✓ wp-content directories exist"
        return 0
    else
        log_error "✗ wp-content directories missing"
        return 1
    fi
}

test_wpcli_available() {
    log_info "Testing: WP-CLI is available"

    local container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress)

    if docker exec "$container" wp --info --allow-root > /dev/null 2>&1; then
        log_info "✓ WP-CLI is available"
        return 0
    else
        log_error "✗ WP-CLI is not available"
        return 1
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Starting Standalone Mode Tests"
    log_info "=========================================="

    if [ ! -f "${COMPOSE_FILE}" ]; then
        log_error "Compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi

    local failed=0

    test_compose_valid || failed=$((failed + 1))
    test_services_start || failed=$((failed + 1))
    test_wordpress_responds || failed=$((failed + 1))
    test_wp_content_seeded || failed=$((failed + 1))
    test_wpcli_available || failed=$((failed + 1))

    log_info "=========================================="
    if [ $failed -eq 0 ]; then
        log_info "All standalone tests passed!"
        exit 0
    else
        log_error "$failed test(s) failed"
        exit 1
    fi
}

main "$@"
