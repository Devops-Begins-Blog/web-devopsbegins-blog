#!/bin/sh
# =============================================================================
# WordPress Container Entrypoint - DevOpsBegins Blog
# =============================================================================
#
# This script runs before Apache starts to handle initialization tasks:
#   1. Wait for MySQL to be ready (avoid race conditions)
#   2. Set correct file permissions
#   3. Generate security keys if not provided
#
# Usage: This script is called automatically by Docker as the ENTRYPOINT
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
WORDPRESS_ROOT="/var/www/html"
WP_CONTENT="${WORDPRESS_ROOT}/wp-content"
MAX_MYSQL_WAIT=30  # seconds to wait for MySQL

# -----------------------------------------------------------------------------
# Logging Helper
# -----------------------------------------------------------------------------
log() {
    echo "[entrypoint] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[entrypoint] $(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >&2
}

# -----------------------------------------------------------------------------
# Wait for MySQL
# -----------------------------------------------------------------------------
# WordPress will fail to connect if MySQL isn't ready yet
# This is common in Docker Compose where services start simultaneously
# -----------------------------------------------------------------------------
wait_for_mysql() {
    if [ -z "${WORDPRESS_DB_HOST}" ]; then
        log "WORDPRESS_DB_HOST not set, skipping MySQL wait"
        return 0
    fi

    log "Waiting for MySQL at ${WORDPRESS_DB_HOST}..."

    counter=0
    # Extract host and port (default port 3306)
    DB_HOST=$(echo "${WORDPRESS_DB_HOST}" | cut -d: -f1)
    DB_PORT=$(echo "${WORDPRESS_DB_HOST}" | cut -d: -f2 -s)
    DB_PORT=${DB_PORT:-3306}

    while [ $counter -lt $MAX_MYSQL_WAIT ]; do
        # Try to connect using PHP's mysqli (available in our image)
        if php -r "new mysqli('${DB_HOST}', '${WORDPRESS_DB_USER}', '${WORDPRESS_DB_PASSWORD}', '', ${DB_PORT});" 2>/dev/null; then
            log "MySQL is ready!"
            return 0
        fi

        counter=$((counter + 1))
        log "MySQL not ready yet... (${counter}/${MAX_MYSQL_WAIT})"
        sleep 1
    done

    log_error "MySQL did not become ready in ${MAX_MYSQL_WAIT} seconds"
    # Don't exit - let WordPress handle the connection error
    return 0
}

# -----------------------------------------------------------------------------
# Fix File Permissions
# -----------------------------------------------------------------------------
# Ensure wp-content is writable for uploads, plugins, and themes
# This is especially important when using Docker volumes
# -----------------------------------------------------------------------------
fix_permissions() {
    log "Setting file permissions..."

    # Ensure wp-content exists and is owned by www-data
    if [ -d "${WP_CONTENT}" ]; then
        chown -R www-data:www-data "${WP_CONTENT}"
        # Directories need execute permission for traversal
        find "${WP_CONTENT}" -type d -exec chmod 755 {} \;
        # Files should be readable but not executable
        find "${WP_CONTENT}" -type f -exec chmod 644 {} \;
        log "Permissions set for wp-content"
    else
        log "Creating wp-content directory..."
        mkdir -p "${WP_CONTENT}"
        chown www-data:www-data "${WP_CONTENT}"
        chmod 755 "${WP_CONTENT}"
    fi

    # Create standard WordPress directories if they don't exist
    for dir in uploads plugins themes; do
        if [ ! -d "${WP_CONTENT}/${dir}" ]; then
            mkdir -p "${WP_CONTENT}/${dir}"
            chown www-data:www-data "${WP_CONTENT}/${dir}"
            chmod 755 "${WP_CONTENT}/${dir}"
            log "Created ${dir} directory"
        fi
    done
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
log "Starting WordPress container initialization..."

# Run initialization tasks
wait_for_mysql
fix_permissions

log "Initialization complete, starting Apache..."

# Execute the CMD passed to the container (apache2-foreground)
exec "$@"
