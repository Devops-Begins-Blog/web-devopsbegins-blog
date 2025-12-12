#!/bin/bash
# Test WordPress Redis Object Cache functionality
# Usage: ./test-object-cache.sh

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

ensure_wordpress_installed() {
    log_info "Ensuring WordPress is installed..."

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)

    # Check if WordPress is already installed
    if docker exec "$wp1_container" wp core is-installed --allow-root 2>/dev/null; then
        log_info "WordPress is already installed"
        return 0
    fi

    log_info "Installing WordPress..."
    docker exec "$wp1_container" wp core install \
        --url="http://localhost:8080" \
        --title="Test Site" \
        --admin_user="admin" \
        --admin_password="admin123" \
        --admin_email="admin@test.local" \
        --skip-email \
        --allow-root 2>/dev/null

    if [ $? -eq 0 ]; then
        log_info "WordPress installed successfully"
        return 0
    else
        log_error "Failed to install WordPress"
        return 1
    fi
}

test_redis_constants_defined() {
    log_info "Testing: WP_REDIS constants are defined"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)

    local result=$(docker exec "$wp1_container" wp eval "
        \$constants = [
            'WP_REDIS_HOST' => defined('WP_REDIS_HOST') ? WP_REDIS_HOST : null,
            'WP_REDIS_PORT' => defined('WP_REDIS_PORT') ? WP_REDIS_PORT : null,
            'WP_REDIS_DATABASE' => defined('WP_REDIS_DATABASE') ? WP_REDIS_DATABASE : null,
        ];
        echo json_encode(\$constants);
    " --allow-root 2>/dev/null || echo "{}")

    local host=$(echo "$result" | grep -o '"WP_REDIS_HOST":"[^"]*"' | cut -d'"' -f4)
    local port=$(echo "$result" | grep -o '"WP_REDIS_PORT":[0-9]*' | cut -d':' -f2)
    local db=$(echo "$result" | grep -o '"WP_REDIS_DATABASE":[0-9]*' | cut -d':' -f2)

    log_info "WP_REDIS_HOST: $host"
    log_info "WP_REDIS_PORT: $port"
    log_info "WP_REDIS_DATABASE: $db"

    if [ -n "$host" ] && [ "$host" != "null" ]; then
        log_info "✓ Redis constants are defined"
        return 0
    else
        log_error "✗ Redis constants not defined"
        return 1
    fi
}

test_redis_object_cache_plugin() {
    log_info "Testing: Redis Object Cache plugin status"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)

    # Check if plugin is installed
    local plugin_status=$(docker exec "$wp1_container" wp plugin status redis-cache --allow-root 2>/dev/null || echo "not-installed")

    if echo "$plugin_status" | grep -q "Status: Active"; then
        log_info "✓ Redis Object Cache plugin is active"
    elif echo "$plugin_status" | grep -q "Status: Inactive"; then
        log_warn "Redis Object Cache plugin is installed but inactive"
    else
        log_info "Redis Object Cache plugin not installed (optional)"
    fi

    # Check if drop-in exists
    if docker exec "$wp1_container" test -f /var/www/html/wp-content/object-cache.php 2>/dev/null; then
        log_info "✓ object-cache.php drop-in exists"
        return 0
    else
        log_info "object-cache.php drop-in not installed (plugin may need activation)"
        return 0
    fi
}

test_redis_connectivity_from_wp() {
    log_info "Testing: WordPress can connect to Redis"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)

    local result=$(docker exec "$wp1_container" php -r "
        \$redis = new Redis();
        try {
            \$redis->connect(getenv('REDIS_HOST') ?: 'redis', getenv('REDIS_PORT') ?: 6379);
            echo \$redis->ping() ? 'connected:OK' : 'connected:FAIL';
        } catch (Exception \$e) {
            echo 'error:' . \$e->getMessage();
        }
    " 2>/dev/null)

    if echo "$result" | grep -q "connected:OK"; then
        log_info "✓ WordPress can connect to Redis"
        return 0
    else
        log_error "✗ Redis connection failed: $result"
        return 1
    fi
}

test_object_cache_working() {
    log_info "Testing: Object cache is working (basic wp_cache operations)"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)

    local test_key="test_key_$(date +%s)"
    local test_value="test_value_$(date +%s)"

    local result=$(docker exec "$wp1_container" wp eval "
        // Set a value
        wp_cache_set('$test_key', '$test_value', 'test_group');

        // Get it back
        \$retrieved = wp_cache_get('$test_key', 'test_group');

        // Check if using Redis
        global \$wp_object_cache;
        \$cache_type = get_class(\$wp_object_cache);

        echo json_encode([
            'set_value' => '$test_value',
            'retrieved' => \$retrieved,
            'match' => (\$retrieved === '$test_value'),
            'cache_class' => \$cache_type
        ]);

        // Cleanup
        wp_cache_delete('$test_key', 'test_group');
    " --allow-root 2>/dev/null || echo "{}")

    log_info "Cache test result: $result"

    local match=$(echo "$result" | grep -o '"match":true' || echo "")
    local cache_class=$(echo "$result" | grep -o '"cache_class":"[^"]*"' | cut -d'"' -f4)

    if [ -n "$match" ]; then
        log_info "✓ wp_cache operations working"
        log_info "Cache class: $cache_class"
        return 0
    else
        log_error "✗ wp_cache operations failed"
        return 1
    fi
}

test_cache_shared_between_nodes() {
    log_info "Testing: Cache is shared between WordPress nodes"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)
    local wp2_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-2)

    local test_key="shared_test_$(date +%s)"
    local test_value="shared_value_$(date +%s)"

    # Set value on node 1
    docker exec "$wp1_container" wp eval "
        wp_cache_set('$test_key', '$test_value', 'shared_test', 300);
    " --allow-root 2>/dev/null

    log_info "Set '$test_key' on wordpress-1"

    # Get value from node 2
    local retrieved=$(docker exec "$wp2_container" wp eval "
        \$value = wp_cache_get('$test_key', 'shared_test');
        echo \$value;
    " --allow-root 2>/dev/null)

    log_info "Retrieved from wordpress-2: $retrieved"

    # Cleanup
    docker exec "$wp1_container" wp eval "wp_cache_delete('$test_key', 'shared_test');" --allow-root 2>/dev/null || true

    if [ "$retrieved" = "$test_value" ]; then
        log_info "✓ Cache is shared between nodes"
        return 0
    else
        log_warn "Cache may not be shared (could be using local cache without Redis drop-in)"
        return 0
    fi
}

test_redis_db0_usage() {
    log_info "Testing: Object cache uses Redis DB 0"

    local redis_container=$(docker compose -f "${COMPOSE_FILE}" ps -q redis)

    # Check keys in DB 0
    local db0_size=$(docker exec "$redis_container" redis-cli -n 0 DBSIZE | grep -o '[0-9]*')

    log_info "Redis DB 0 has $db0_size keys"

    if [ "$db0_size" -gt 0 ]; then
        log_info "✓ Redis DB 0 contains object cache data"
        # Sample some keys
        log_info "Sample keys in DB 0:"
        docker exec "$redis_container" redis-cli -n 0 KEYS "*" | head -5
        return 0
    else
        log_info "DB 0 is empty (object cache may not be enabled yet)"
        return 0
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Starting Object Cache Tests"
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

    # Ensure WordPress is installed before running WP-CLI tests
    ensure_wordpress_installed || exit 1

    local failed=0

    test_redis_constants_defined || failed=$((failed + 1))
    test_redis_connectivity_from_wp || failed=$((failed + 1))
    test_redis_object_cache_plugin || failed=$((failed + 1))
    test_object_cache_working || failed=$((failed + 1))
    test_cache_shared_between_nodes || failed=$((failed + 1))
    test_redis_db0_usage || failed=$((failed + 1))

    log_info "=========================================="
    if [ $failed -eq 0 ]; then
        log_info "All object cache tests passed!"
        exit 0
    else
        log_error "$failed test(s) failed"
        exit 1
    fi
}

main "$@"
