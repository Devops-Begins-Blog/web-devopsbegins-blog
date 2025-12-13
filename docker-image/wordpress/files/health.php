<?php
/**
 * WordPress Health Check Endpoint
 *
 * Validates connectivity to WordPress, MySQL, and Redis (when applicable).
 * Returns JSON response with individual check statuses.
 *
 * This file is part of the WordPress Docker image and is copied to /var/www/html/
 * during the Docker build process.
 *
 * @package DevOpsBegins
 */

header('Content-Type: application/json');
header('Cache-Control: no-cache, no-store, must-revalidate');

$checks = [
    'wordpress' => false,
    'mysql' => false,
    'redis' => null  // null when not applicable (standalone mode)
];

$errors = [];

// WordPress check - verify wp-config.php exists and is readable
if (file_exists('/var/www/html/wp-config.php')) {
    $checks['wordpress'] = is_readable('/var/www/html/wp-config.php');
}
if (!$checks['wordpress']) {
    $errors[] = 'WordPress configuration not found or not readable';
}

// MySQL check - verify database connectivity
$dbHost = getenv('WORDPRESS_DB_HOST') ?: 'localhost';
$dbUser = getenv('WORDPRESS_DB_USER') ?: 'wordpress';
$dbPass = getenv('WORDPRESS_DB_PASSWORD') ?: '';
$dbName = getenv('WORDPRESS_DB_NAME') ?: 'wordpress';

// Parse host:port format
$hostParts = explode(':', $dbHost);
$mysqlHost = $hostParts[0];
$mysqlPort = isset($hostParts[1]) ? (int)$hostParts[1] : 3306;

try {
    $mysqli = new mysqli($mysqlHost, $dbUser, $dbPass, $dbName, $mysqlPort);
    if ($mysqli->connect_error) {
        $checks['mysql'] = false;
        $errors[] = 'MySQL connection failed: ' . $mysqli->connect_error;
    } else {
        // Verify we can query
        $result = $mysqli->query('SELECT 1');
        $checks['mysql'] = ($result !== false);
        if (!$checks['mysql']) {
            $errors[] = 'MySQL query failed';
        }
        $mysqli->close();
    }
} catch (Exception $e) {
    $checks['mysql'] = false;
    $errors[] = 'MySQL exception: ' . $e->getMessage();
}

// Redis check (only in distributed mode)
$redisHost = getenv('REDIS_HOST');
if (!empty($redisHost)) {
    $redisPort = (int)(getenv('REDIS_PORT') ?: 6379);

    if (class_exists('Redis')) {
        try {
            $redis = new Redis();
            $connected = @$redis->connect($redisHost, $redisPort, 2.0);  // 2 second timeout

            if ($connected) {
                // Check if auth is required
                $redisPass = getenv('REDIS_PASSWORD');
                if (!empty($redisPass)) {
                    $authResult = @$redis->auth($redisPass);
                    if (!$authResult) {
                        $checks['redis'] = false;
                        $errors[] = 'Redis authentication failed';
                    } else {
                        $checks['redis'] = ($redis->ping() === true || $redis->ping() === '+PONG');
                    }
                } else {
                    $checks['redis'] = ($redis->ping() === true || $redis->ping() === '+PONG');
                }
            } else {
                $checks['redis'] = false;
                $errors[] = 'Redis connection failed';
            }

            $redis->close();
        } catch (Exception $e) {
            $checks['redis'] = false;
            $errors[] = 'Redis exception: ' . $e->getMessage();
        }
    } else {
        $checks['redis'] = false;
        $errors[] = 'Redis PHP extension not installed';
    }
}

// Determine overall health
$healthy = $checks['wordpress'] && $checks['mysql'];
if ($checks['redis'] !== null) {
    $healthy = $healthy && $checks['redis'];
}

// Set HTTP status code
http_response_code($healthy ? 200 : 503);

// Return JSON response
echo json_encode([
    'status' => $healthy ? 'healthy' : 'unhealthy',
    'checks' => $checks,
    'errors' => $healthy ? [] : $errors,
    'mode' => getenv('WORDPRESS_MODE') ?: 'standalone',
    'timestamp' => date('c')
], JSON_PRETTY_PRINT);
