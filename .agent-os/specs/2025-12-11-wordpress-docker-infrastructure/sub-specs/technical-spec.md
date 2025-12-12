# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-12-11-wordpress-docker-infrastructure/spec.md

## Project Structure

```
web-devopsbegins-blog/
├── docker-compose.yml
├── docker-image/
│   └── wordpress/
│       ├── Dockerfile
│       └── files/
│           ├── opcache.ini
│           ├── php-wordpress.ini
│           ├── wp-config.php
│           └── entrypoint.sh
├── docs/
│   └── phase-1-wordpress-setup.md
└── .agent-os/
```

## Technical Requirements

### WordPress Container (PHP-Apache)

- **Base Image:** `php:8.2.29-apache` (Debian Bookworm)
- **WordPress Version:** Pinned 6.9 with SHA1 verification
- **PHP Extensions Required:**
  - `mysqli` - MySQL database connectivity
  - `gd` - Image manipulation (with freetype, jpeg, webp)
  - `zip` - Plugin/theme installation
  - `exif` - Image metadata
  - `intl` - Internationalization
  - `opcache` - PHP bytecode caching
  - `imagick` - Advanced image processing
- **Apache Configuration:**
  - `mod_rewrite` enabled for WordPress permalinks
  - Serves both static files and PHP directly
- **Configuration:**
  - Custom `wp-config.php` reading from environment variables
  - Entrypoint script for initialization tasks
  - OPcache tuned for WordPress (revalidate_freq=60)
  - PHP limits optimized for WordPress (64M uploads, 256M memory)
- **Exposed:** Port 80 (HTTP)

### MySQL Container

- **Image:** `mysql:8.0`
- **Configuration:**
  - Character set: `utf8mb4`
  - Collation: `utf8mb4_unicode_ci`
  - Authentication plugin: `mysql_native_password` (WordPress compatibility)
- **Environment Variables (in docker-compose.yml):**
  - `MYSQL_ROOT_PASSWORD`
  - `MYSQL_DATABASE`
  - `MYSQL_USER`
  - `MYSQL_PASSWORD`
- **Exposed:** Port 3306 (internal network only)

## Docker Compose Configuration

### Services

| Service | Build Context | Ports | Depends On |
|---------|---------------|-------|------------|
| wordpress | `./docker-image/wordpress` | 80:80 | mysql |
| mysql | mysql:8.0 (image) | (internal 3306) | - |

### Networks

- **backend:** Internal network for service communication
  - MySQL not exposed to host
  - Only WordPress exposed on port 80

### Volumes (Docker managed, not in repo)

Volumes are defined in docker-compose.yml as named Docker volumes, managed by Docker runtime:

| Volume Name | Mount Point | Purpose |
|-------------|-------------|---------|
| `wp-content` | `/var/www/html/wp-content` | Themes, plugins, uploads |
| `mysql-data` | `/var/lib/mysql` | Database persistence |

### Environment Variables (embedded in docker-compose.yml)

**WordPress Service:**
```yaml
environment:
  WORDPRESS_DB_HOST: mysql
  WORDPRESS_DB_NAME: wordpress
  WORDPRESS_DB_USER: wordpress
  WORDPRESS_DB_PASSWORD: <secure_password>
  WORDPRESS_TABLE_PREFIX: wp_
  WORDPRESS_DEBUG: "false"
```

**MySQL Service:**
```yaml
environment:
  MYSQL_ROOT_PASSWORD: <root_password>
  MYSQL_DATABASE: wordpress
  MYSQL_USER: wordpress
  MYSQL_PASSWORD: <secure_password>
```

## WordPress Configuration (wp-config.php)

Custom `wp-config.php` that reads from environment variables:

- Database connection from `WORDPRESS_DB_*` env vars
- Security salts generated at build time or first run
- Debug mode configurable via environment
- File permissions for container environment
- Reverse proxy support (X-Forwarded-Proto for HTTPS detection)
- Security hardening (DISALLOW_FILE_EDIT, limited revisions)

## Performance Considerations

- **OPcache:** Enabled with WordPress-optimized settings (128MB memory, 60s revalidate)
- **Apache:** Serves all content (static + PHP) in single process
- **MySQL:** InnoDB buffer pool sized for container memory limits
- **PHP Limits:** 64MB uploads, 256MB memory, 300s execution time
