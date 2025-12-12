<?php
/**
 * =============================================================================
 * WordPress Configuration - DevOpsBegins Blog
 * =============================================================================
 *
 * This wp-config.php is designed for containerized environments following
 * the 12-factor app methodology. All sensitive values are read from
 * environment variables, never hardcoded.
 *
 * Environment Variables Required:
 *   WORDPRESS_DB_HOST      - MySQL hostname (e.g., "mysql" in Docker network)
 *   WORDPRESS_DB_NAME      - Database name
 *   WORDPRESS_DB_USER      - Database username
 *   WORDPRESS_DB_PASSWORD  - Database password
 *
 * Optional Environment Variables:
 *   WORDPRESS_TABLE_PREFIX - Table prefix (default: wp_)
 *   WORDPRESS_DEBUG        - Enable debug mode (default: false)
 *   WORDPRESS_DEBUG_LOG    - Log debug to file (default: false)
 *
 * @package DevOpsBegins
 */

// =============================================================================
// Database Configuration
// =============================================================================
// Read from environment variables with fallback error handling

$required_env_vars = [
    'WORDPRESS_DB_HOST',
    'WORDPRESS_DB_NAME',
    'WORDPRESS_DB_USER',
    'WORDPRESS_DB_PASSWORD',
];

foreach ($required_env_vars as $var) {
    if (empty(getenv($var))) {
        error_log("WordPress Error: Required environment variable {$var} is not set");
    }
}

/** MySQL hostname */
define('DB_HOST', getenv('WORDPRESS_DB_HOST') ?: 'localhost');

/** Database name */
define('DB_NAME', getenv('WORDPRESS_DB_NAME') ?: 'wordpress');

/** Database username */
define('DB_USER', getenv('WORDPRESS_DB_USER') ?: 'wordpress');

/** Database password */
define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') ?: '');

/** Database charset (utf8mb4 supports emojis and special characters) */
define('DB_CHARSET', 'utf8mb4');

/** Database collation (leave blank for MySQL default) */
define('DB_COLLATE', '');

// =============================================================================
// Authentication Keys and Salts
// =============================================================================
// These are used to secure cookies and passwords.
// Generate new keys at: https://api.wordpress.org/secret-key/1.1/salt/
//
// For production, consider setting these via environment variables or
// generating them at container startup in entrypoint.sh

define('AUTH_KEY',         getenv('WORDPRESS_AUTH_KEY')         ?: 'put-your-unique-phrase-here');
define('SECURE_AUTH_KEY',  getenv('WORDPRESS_SECURE_AUTH_KEY')  ?: 'put-your-unique-phrase-here');
define('LOGGED_IN_KEY',    getenv('WORDPRESS_LOGGED_IN_KEY')    ?: 'put-your-unique-phrase-here');
define('NONCE_KEY',        getenv('WORDPRESS_NONCE_KEY')        ?: 'put-your-unique-phrase-here');
define('AUTH_SALT',        getenv('WORDPRESS_AUTH_SALT')        ?: 'put-your-unique-phrase-here');
define('SECURE_AUTH_SALT', getenv('WORDPRESS_SECURE_AUTH_SALT') ?: 'put-your-unique-phrase-here');
define('LOGGED_IN_SALT',   getenv('WORDPRESS_LOGGED_IN_SALT')   ?: 'put-your-unique-phrase-here');
define('NONCE_SALT',       getenv('WORDPRESS_NONCE_SALT')       ?: 'put-your-unique-phrase-here');

// =============================================================================
// Table Prefix
// =============================================================================
// Change this if you want to run multiple WordPress installations in one database
// Only use letters, numbers, and underscores

$table_prefix = getenv('WORDPRESS_TABLE_PREFIX') ?: 'wp_';

// =============================================================================
// Debug Configuration
// =============================================================================
// IMPORTANT: Set WORDPRESS_DEBUG=false in production!

$debug_mode = filter_var(getenv('WORDPRESS_DEBUG') ?: 'false', FILTER_VALIDATE_BOOLEAN);
$debug_log  = filter_var(getenv('WORDPRESS_DEBUG_LOG') ?: 'false', FILTER_VALIDATE_BOOLEAN);

define('WP_DEBUG', $debug_mode);
define('WP_DEBUG_LOG', $debug_log);
define('WP_DEBUG_DISPLAY', $debug_mode && !$debug_log);

// =============================================================================
// Security Hardening
// =============================================================================

/** Disable file editing from admin panel (security best practice) */
define('DISALLOW_FILE_EDIT', true);

/** Limit post revisions to save database space */
define('WP_POST_REVISIONS', 10);

/** Empty trash after 7 days */
define('EMPTY_TRASH_DAYS', 7);

// =============================================================================
// Redis Object Cache Configuration
// =============================================================================
// Used by Redis Object Cache plugin for persistent caching
// Object cache uses Redis DB 0 (sessions use DB 1, configured in PHP INI)

if (getenv('REDIS_HOST')) {
    define('WP_REDIS_HOST', getenv('REDIS_HOST'));
    define('WP_REDIS_PORT', getenv('REDIS_PORT') ?: 6379);
    define('WP_REDIS_DATABASE', 0);  // DB 0 for object cache
    define('WP_REDIS_TIMEOUT', 1);
    define('WP_REDIS_READ_TIMEOUT', 1);
}

// =============================================================================
// Performance Optimizations
// =============================================================================

/** Increase memory limit for PHP scripts */
define('WP_MEMORY_LIMIT', '256M');

/** Admin area may need more memory */
define('WP_MAX_MEMORY_LIMIT', '512M');

/** Disable WordPress cron, use system cron instead for reliability */
// define('DISABLE_WP_CRON', true);

// =============================================================================
// Reverse Proxy / Load Balancer Support
// =============================================================================
// Required when running behind Nginx or other reverse proxies

if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}

if (isset($_SERVER['HTTP_X_FORWARDED_HOST'])) {
    $_SERVER['HTTP_HOST'] = $_SERVER['HTTP_X_FORWARDED_HOST'];
}

// =============================================================================
// WordPress Core Settings
// =============================================================================

/** Absolute path to the WordPress directory */
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

/** Sets up WordPress vars and included files */
require_once ABSPATH . 'wp-settings.php';
