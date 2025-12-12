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
WP_CONTENT_BASE="/opt/wordpress/wp-content-base"
MAX_MYSQL_WAIT=30  # seconds to wait for MySQL
MAX_REDIS_WAIT=30  # seconds to wait for Redis

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
# Wait for Redis
# -----------------------------------------------------------------------------
# Redis is required for session handling and object cache in distributed mode
# Only wait if REDIS_HOST is configured
# -----------------------------------------------------------------------------
wait_for_redis() {
    if [ -z "${REDIS_HOST}" ]; then
        log "REDIS_HOST not set, skipping Redis wait"
        return 0
    fi

    REDIS_PORT="${REDIS_PORT:-6379}"
    log "Waiting for Redis at ${REDIS_HOST}:${REDIS_PORT}..."

    counter=0
    while [ $counter -lt $MAX_REDIS_WAIT ]; do
        # Try to connect using PHP's Redis extension
        if php -r "try { \$r = new Redis(); \$r->connect('${REDIS_HOST}', ${REDIS_PORT}, 1); \$r->ping(); exit(0); } catch (Exception \$e) { exit(1); }" 2>/dev/null; then
            log "Redis is ready!"
            return 0
        fi

        counter=$((counter + 1))
        log "Redis not ready yet... (${counter}/${MAX_REDIS_WAIT})"
        sleep 1
    done

    log_error "Redis did not become ready in ${MAX_REDIS_WAIT} seconds"
    # Don't exit - continue without Redis
    return 0
}

# -----------------------------------------------------------------------------
# Configure Redis Session Handler
# -----------------------------------------------------------------------------
# Generates PHP INI file for Redis sessions at runtime
# Only creates the file if REDIS_HOST is set AND file doesn't exist
# This allows mounting a custom config externally
# Sessions use Redis DB 1 (DB 0 is for object cache)
# -----------------------------------------------------------------------------
configure_redis_sessions() {
    PHP_INI_PATH="/usr/local/etc/php/conf.d/redis-sessions.ini"

    # Check if custom config was mounted externally
    if [ -f "${PHP_INI_PATH}" ]; then
        log "Redis sessions config already exists, preserving custom configuration"
        return 0
    fi

    if [ -z "${REDIS_HOST}" ]; then
        log "REDIS_HOST not set, using default file-based sessions"
        return 0
    fi

    REDIS_PORT="${REDIS_PORT:-6379}"

    log "Configuring Redis session handler (${REDIS_HOST}:${REDIS_PORT})..."

    cat > "${PHP_INI_PATH}" << EOF
; =============================================================================
; Redis Session Handler - Generated at runtime by entrypoint.sh
; =============================================================================
; Sessions stored in Redis DB 1 (DB 0 reserved for object cache)
; =============================================================================

session.save_handler = redis
session.save_path = "tcp://${REDIS_HOST}:${REDIS_PORT}?database=1"
session.gc_maxlifetime = 1440
session.cookie_httponly = 1
session.use_strict_mode = 1
EOF

    log "Redis session handler configured"
}

# -----------------------------------------------------------------------------
# Initialize wp-content from base
# -----------------------------------------------------------------------------
# Seeds wp-content directory from wp-content-base if empty
# This supports both standalone (local volume) and distributed (NFS) modes
# Preserves existing data - only copies if wp-content is empty
# -----------------------------------------------------------------------------
init_wp_content() {
    log "Checking wp-content initialization..."

    # Check if wp-content directory exists
    if [ ! -d "${WP_CONTENT}" ]; then
        log "Creating wp-content directory..."
        mkdir -p "${WP_CONTENT}"
    fi

    # Check if wp-content is empty (no files except . and ..)
    if [ -z "$(ls -A ${WP_CONTENT} 2>/dev/null)" ]; then
        log "wp-content is empty, seeding from base..."

        if [ -d "${WP_CONTENT_BASE}" ] && [ -n "$(ls -A ${WP_CONTENT_BASE} 2>/dev/null)" ]; then
            cp -a "${WP_CONTENT_BASE}/." "${WP_CONTENT}/"
            log "wp-content seeded successfully from base"
        else
            log_error "wp-content-base is empty or missing, creating minimal structure"
            mkdir -p "${WP_CONTENT}/plugins"
            mkdir -p "${WP_CONTENT}/themes"
            mkdir -p "${WP_CONTENT}/uploads"
        fi
    else
        log "wp-content already has data, preserving existing content"
    fi
}

# -----------------------------------------------------------------------------
# Initialize Redis Object Cache
# -----------------------------------------------------------------------------
# Installs and activates Redis Object Cache plugin using WP-CLI
# Only runs if REDIS_HOST is set and WordPress is installed
# -----------------------------------------------------------------------------
init_redis_object_cache() {
    if [ -z "${REDIS_HOST}" ]; then
        log "REDIS_HOST not set, skipping Redis Object Cache setup"
        return 0
    fi

    # Check if WordPress is installed (wp-config.php exists and DB is accessible)
    if ! su -s /bin/sh www-data -c "wp core is-installed --path=${WORDPRESS_ROOT}" 2>/dev/null; then
        log "WordPress not yet installed, skipping Redis Object Cache setup"
        return 0
    fi

    log "Checking Redis Object Cache plugin..."

    # Check if redis-cache plugin is installed
    if su -s /bin/sh www-data -c "wp plugin is-installed redis-cache --path=${WORDPRESS_ROOT}" 2>/dev/null; then
        # Plugin installed, check if active
        if ! su -s /bin/sh www-data -c "wp plugin is-active redis-cache --path=${WORDPRESS_ROOT}" 2>/dev/null; then
            log "Activating Redis Object Cache plugin..."
            su -s /bin/sh www-data -c "wp plugin activate redis-cache --path=${WORDPRESS_ROOT}" 2>/dev/null || true
        fi
    else
        log "Installing Redis Object Cache plugin..."
        su -s /bin/sh www-data -c "wp plugin install redis-cache --activate --path=${WORDPRESS_ROOT}" 2>/dev/null || true
    fi

    # Enable Redis object cache drop-in
    if [ ! -f "${WP_CONTENT}/object-cache.php" ]; then
        log "Enabling Redis object cache drop-in..."
        su -s /bin/sh www-data -c "wp redis enable --path=${WORDPRESS_ROOT}" 2>/dev/null || true
    fi

    log "Redis Object Cache setup complete"
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

# Run initialization tasks in order:
# 1. Configure Redis sessions (must run before Apache starts)
configure_redis_sessions

# 2. Wait for dependencies
wait_for_mysql
wait_for_redis

# 3. Initialize wp-content (seed from base if empty)
init_wp_content

# 4. Fix permissions (must run after wp-content init)
fix_permissions

# 5. Setup Redis Object Cache (requires WordPress installed)
init_redis_object_cache

log "Initialization complete, starting Apache..."

# Execute the CMD passed to the container (apache2-foreground)
exec "$@"
