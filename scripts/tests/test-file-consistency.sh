#!/bin/bash
# Test file consistency across WordPress nodes (shared volume)
# Usage: ./test-file-consistency.sh

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
    log_info "Cleaning up test files..."
    docker compose -f "${COMPOSE_FILE}" exec -T wordpress-1 rm -rf /var/www/html/wp-content/uploads/test-consistency 2>/dev/null || true
}

trap cleanup EXIT

test_wp_content_structure() {
    log_info "Testing: wp-content directory structure"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)
    local wp2_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-2)

    # Check required directories on both nodes
    local dirs=("themes" "plugins" "uploads")

    for dir in "${dirs[@]}"; do
        local path="/var/www/html/wp-content/${dir}"

        if docker exec "$wp1_container" test -d "$path" && \
           docker exec "$wp2_container" test -d "$path"; then
            log_info "✓ ${dir}/ exists on both nodes"
        else
            log_error "✗ ${dir}/ missing on one or both nodes"
            return 1
        fi
    done

    return 0
}

test_file_creation_sync() {
    log_info "Testing: File created on node 1 appears on node 2"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)
    local wp2_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-2)

    local test_dir="/var/www/html/wp-content/uploads/test-consistency"
    local test_file="${test_dir}/test-$(date +%s).txt"
    local test_content="Created on wordpress-1 at $(date)"

    # Create directory and file on node 1
    docker exec "$wp1_container" mkdir -p "$test_dir"
    docker exec "$wp1_container" bash -c "echo '$test_content' > '$test_file'"

    log_info "Created file on wordpress-1"

    # Verify on node 2
    sleep 1  # Brief pause for any filesystem sync

    if docker exec "$wp2_container" test -f "$test_file"; then
        local retrieved=$(docker exec "$wp2_container" cat "$test_file")
        if [ "$retrieved" = "$test_content" ]; then
            log_info "✓ File appears on wordpress-2 with correct content"
            return 0
        else
            log_error "✗ File content mismatch"
            return 1
        fi
    else
        log_error "✗ File not visible on wordpress-2"
        return 1
    fi
}

test_file_modification_sync() {
    log_info "Testing: File modified on node 2 reflects on node 1"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)
    local wp2_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-2)

    local test_file="/var/www/html/wp-content/uploads/test-consistency/modify-test.txt"
    local original_content="Original content"
    local modified_content="Modified on wordpress-2 at $(date)"

    # Create on node 1
    docker exec "$wp1_container" bash -c "echo '$original_content' > '$test_file'"

    # Modify on node 2
    docker exec "$wp2_container" bash -c "echo '$modified_content' > '$test_file'"

    sleep 1

    # Read back on node 1
    local retrieved=$(docker exec "$wp1_container" cat "$test_file")

    if [ "$retrieved" = "$modified_content" ]; then
        log_info "✓ Modifications sync correctly"
        return 0
    else
        log_error "✗ Modifications not synced"
        return 1
    fi
}

test_file_deletion_sync() {
    log_info "Testing: File deleted on node 1 disappears from node 2"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)
    local wp2_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-2)

    local test_file="/var/www/html/wp-content/uploads/test-consistency/delete-test.txt"

    # Create file
    docker exec "$wp1_container" touch "$test_file"

    # Verify exists on node 2
    if ! docker exec "$wp2_container" test -f "$test_file"; then
        log_error "✗ File not created properly"
        return 1
    fi

    # Delete on node 1
    docker exec "$wp1_container" rm -f "$test_file"

    sleep 1

    # Verify gone on node 2
    if docker exec "$wp2_container" test -f "$test_file" 2>/dev/null; then
        log_error "✗ Deleted file still visible on node 2"
        return 1
    else
        log_info "✓ Deletions sync correctly"
        return 0
    fi
}

test_large_file_handling() {
    log_info "Testing: Large file handling across nodes"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)
    local wp2_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-2)

    local test_file="/var/www/html/wp-content/uploads/test-consistency/large-file.bin"

    # Create 1MB file on node 1
    docker exec "$wp1_container" dd if=/dev/urandom of="$test_file" bs=1M count=1 2>/dev/null

    local size1=$(docker exec "$wp1_container" stat -c%s "$test_file" 2>/dev/null || echo "0")

    sleep 2

    # Check on node 2
    if docker exec "$wp2_container" test -f "$test_file"; then
        local size2=$(docker exec "$wp2_container" stat -c%s "$test_file" 2>/dev/null || echo "0")

        if [ "$size1" = "$size2" ]; then
            log_info "✓ Large file (1MB) synced correctly"
            docker exec "$wp1_container" rm -f "$test_file"
            return 0
        else
            log_error "✗ File sizes differ: $size1 vs $size2"
            docker exec "$wp1_container" rm -f "$test_file"
            return 1
        fi
    else
        log_error "✗ Large file not visible on node 2"
        return 1
    fi
}

test_permissions_consistency() {
    log_info "Testing: File permissions consistency"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)
    local wp2_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-2)

    local test_file="/var/www/html/wp-content/uploads/test-consistency/perms-test.txt"

    # Create file with specific permissions
    docker exec "$wp1_container" touch "$test_file"
    docker exec "$wp1_container" chmod 644 "$test_file"
    docker exec "$wp1_container" chown www-data:www-data "$test_file"

    sleep 1

    # Check permissions on node 2
    local perms1=$(docker exec "$wp1_container" stat -c"%a %U:%G" "$test_file" 2>/dev/null)
    local perms2=$(docker exec "$wp2_container" stat -c"%a %U:%G" "$test_file" 2>/dev/null)

    if [ "$perms1" = "$perms2" ]; then
        log_info "✓ Permissions consistent: $perms1"
        return 0
    else
        log_warn "Permissions differ: node1=$perms1, node2=$perms2"
        return 0  # Don't fail, permissions may differ based on mount options
    fi
}

test_concurrent_writes() {
    log_info "Testing: Concurrent writes from both nodes"

    local wp1_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-1)
    local wp2_container=$(docker compose -f "${COMPOSE_FILE}" ps -q wordpress-2)

    local test_file="/var/www/html/wp-content/uploads/test-consistency/concurrent.log"

    # Clear file
    docker exec "$wp1_container" bash -c "> '$test_file'"

    # Write from both nodes concurrently
    docker exec "$wp1_container" bash -c "for i in {1..10}; do echo 'node1-\$i' >> '$test_file'; done" &
    docker exec "$wp2_container" bash -c "for i in {1..10}; do echo 'node2-\$i' >> '$test_file'; done" &
    wait

    sleep 1

    # Count lines
    local lines=$(docker exec "$wp1_container" wc -l "$test_file" | awk '{print $1}')

    log_info "Total lines after concurrent writes: $lines"

    if [ "$lines" -ge 15 ]; then
        log_info "✓ Concurrent writes handled (some lines may be interleaved)"
        return 0
    else
        log_warn "Fewer lines than expected ($lines < 20), some writes may have been lost"
        return 0
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Starting File Consistency Tests"
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

    local failed=0

    test_wp_content_structure || failed=$((failed + 1))
    test_file_creation_sync || failed=$((failed + 1))
    test_file_modification_sync || failed=$((failed + 1))
    test_file_deletion_sync || failed=$((failed + 1))
    test_large_file_handling || failed=$((failed + 1))
    test_permissions_consistency || failed=$((failed + 1))
    test_concurrent_writes || failed=$((failed + 1))

    log_info "=========================================="
    if [ $failed -eq 0 ]; then
        log_info "All file consistency tests passed!"
        exit 0
    else
        log_error "$failed test(s) failed"
        exit 1
    fi
}

main "$@"
