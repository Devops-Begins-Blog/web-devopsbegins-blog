#!/bin/bash
# Run all WordPress HA integration tests
# Usage: ./run-all-tests.sh [standalone|ha|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "\n${BLUE}=========================================="; echo -e "$1"; echo -e "==========================================${NC}\n"; }

TEST_MODE="${1:-all}"

run_standalone_tests() {
    log_header "STANDALONE MODE TESTS"

    if [ ! -f "${PROJECT_ROOT}/docker-compose.standalone.yml" ]; then
        log_warn "docker-compose.standalone.yml not found, skipping standalone tests"
        return 0
    fi

    bash "${SCRIPT_DIR}/test-standalone-mode.sh"
}

run_ha_tests() {
    log_header "HIGH AVAILABILITY MODE TESTS"

    if [ ! -f "${PROJECT_ROOT}/docker-compose.ha.yml" ]; then
        log_error "docker-compose.ha.yml not found"
        return 1
    fi

    # Start HA environment
    log_info "Starting HA environment..."
    docker compose -f "${PROJECT_ROOT}/docker-compose.ha.yml" up -d

    # Wait for services to initialize
    log_info "Waiting for services to initialize (60 seconds)..."
    sleep 60

    local failed=0

    # Run HA mode tests
    log_header "HA Infrastructure Tests"
    bash "${SCRIPT_DIR}/test-ha-mode.sh" || failed=$((failed + 1))

    # Run session persistence tests
    log_header "Session Persistence Tests"
    bash "${SCRIPT_DIR}/test-session-persistence.sh" || failed=$((failed + 1))

    # Run object cache tests
    log_header "Object Cache Tests"
    bash "${SCRIPT_DIR}/test-object-cache.sh" || failed=$((failed + 1))

    # Run file consistency tests
    log_header "File Consistency Tests"
    bash "${SCRIPT_DIR}/test-file-consistency.sh" || failed=$((failed + 1))

    return $failed
}

cleanup_all() {
    log_info "Cleaning up all test environments..."
    docker compose -f "${PROJECT_ROOT}/docker-compose.ha.yml" down -v --remove-orphans 2>/dev/null || true
    docker compose -f "${PROJECT_ROOT}/docker-compose.standalone.yml" down -v --remove-orphans 2>/dev/null || true
}

# Main execution
main() {
    log_header "WORDPRESS HA INTEGRATION TEST SUITE"
    log_info "Test mode: $TEST_MODE"
    log_info "Project root: $PROJECT_ROOT"

    local total_failed=0

    trap cleanup_all EXIT

    case "$TEST_MODE" in
        standalone)
            run_standalone_tests || total_failed=$((total_failed + 1))
            ;;
        ha)
            run_ha_tests || total_failed=$((total_failed + $?))
            ;;
        all)
            run_standalone_tests || total_failed=$((total_failed + 1))
            run_ha_tests || total_failed=$((total_failed + $?))
            ;;
        *)
            log_error "Unknown test mode: $TEST_MODE"
            log_info "Usage: $0 [standalone|ha|all]"
            exit 1
            ;;
    esac

    log_header "TEST SUITE COMPLETE"

    if [ $total_failed -eq 0 ]; then
        log_info "All test suites passed!"
        exit 0
    else
        log_error "$total_failed test suite(s) had failures"
        exit 1
    fi
}

main "$@"
