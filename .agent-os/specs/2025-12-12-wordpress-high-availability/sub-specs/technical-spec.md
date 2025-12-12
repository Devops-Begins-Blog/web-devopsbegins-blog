# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-12-12-wordpress-high-availability/spec.md

## Technical Requirements

### Pillar 1: NFS Shared Storage

#### Docker Compose Volume Configuration
- Configure NFS volume using `driver: local` with `driver_opts` for NFS endpoint
- Volume mount target: `/var/www/html/wp-content`
- NFS options: `nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2`

#### WordPress Distributed Mode Initialization
- New environment variable: `WORDPRESS_MODE` (values: `standalone` | `distributed`)
- Default behavior (`standalone`): Current behavior, local wp-content
- Distributed behavior:
  1. Check if `WORDPRESS_MODE=distributed`
  2. Check if `/var/www/html/wp-content` is empty (mounted NFS volume)
  3. If empty, copy contents from `/opt/wordpress/wp-content-base` to `/var/www/html/wp-content`
  4. Set proper ownership (www-data:www-data) and permissions

#### Dockerfile Changes for wp-content-base
- Create `/opt/wordpress/wp-content-base` directory (outside DocumentRoot for security)
- After WordPress extraction, move `wp-content/*` to `/opt/wordpress/wp-content-base/`
- Ensure `wp-content-base` contains: `plugins/`, `themes/`, `uploads/`, `index.php`
- Keep `/var/www/html/wp-content` directory empty for volume mount point

### Pillar 2: Redis Integration

#### Redis Service Configuration
- Image: `redis:7-alpine` (lightweight, production-ready)
- Volume: `redis_data:/data` for AOF persistence
- Command: `redis-server --appendonly yes` (durability)
- Network: Same Docker network as WordPress containers
- No port exposure to host (internal communication only)

#### PHP Session Handler Configuration
- New PHP INI file: `php-redis.ini`
- Settings:
  ```ini
  session.save_handler = redis
  session.save_path = "tcp://redis:6379?database=1"
  ```
- Environment variable: `REDIS_HOST` (default: `redis`)
- Conditional loading: Only configure Redis sessions if `REDIS_HOST` is set

#### Redis Object Cache Configuration
- wp-config.php additions:
  ```php
  define('WP_REDIS_HOST', getenv('REDIS_HOST') ?: 'redis');
  define('WP_REDIS_PORT', getenv('REDIS_PORT') ?: 6379);
  define('WP_REDIS_DATABASE', 0);  // DB 0 for object cache
  define('WP_REDIS_TIMEOUT', 1);
  define('WP_REDIS_READ_TIMEOUT', 1);
  ```
- Plugin: Redis Object Cache (installed via WP-CLI)

### Pillar 3: WP-CLI and Plugin Automation

#### Dockerfile WP-CLI Installation
- Download WP-CLI phar from official source
- Verify checksum for security
- Install to `/usr/local/bin/wp`
- Set executable permissions

#### PHP Redis Extension Installation
- Add to Dockerfile: `pecl install redis && docker-php-ext-enable redis`
- Required for both session handling and object cache

#### Automated Plugin Installation
- Add Redis Object Cache plugin installation to entrypoint.sh
- Use `wp plugin install redis-cache --activate` (run as www-data)
- Run `wp redis enable` to drop-in the object-cache.php
- Only execute on first run or when plugin not present
- Conditional: Only if `REDIS_HOST` environment variable is set

### Pillar 4: OPcache Optimization

#### Current Configuration Review
- Current `opcache.revalidate_freq=60` is acceptable for production
- Add `opcache.validate_timestamps=0` for production mode (disable timestamp checking)
- New environment variable: `OPCACHE_VALIDATE_TIMESTAMPS` (default: `0` for production)
- Allows override for development: `OPCACHE_VALIDATE_TIMESTAMPS=1`

#### OPcache INI Updates
```ini
; Production: disable timestamp validation (deploy triggers restart anyway)
opcache.validate_timestamps=${OPCACHE_VALIDATE_TIMESTAMPS:-0}
```

## File Changes Summary

### Modified Files

| File | Changes |
|------|---------|
| `docker-image/wordpress/Dockerfile` | Add WP-CLI installation, PHP Redis extension, wp-content-base setup |
| `docker-image/wordpress/files/entrypoint.sh` | Add distributed mode logic, Redis Object Cache activation |
| `docker-image/wordpress/files/wp-config.php` | Add Redis configuration constants |
| `docker-image/wordpress/files/opcache.ini` | Add validate_timestamps configuration |

### New Files

| File | Purpose |
|------|---------|
| `docker-image/wordpress/files/php-redis.ini` | Redis session handler configuration |
| `docker-compose.yml` | Main orchestration with NFS volume and Redis service |
| `docker-compose.override.yml` | Local development overrides (optional) |

## Environment Variables

### New Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WORDPRESS_MODE` | `standalone` | Set to `distributed` for HA mode with NFS |
| `REDIS_HOST` | (unset) | Redis hostname, enables Redis features when set |
| `REDIS_PORT` | `6379` | Redis port number |
| `NFS_SERVER` | (required for distributed) | NFS server IP/hostname |
| `NFS_PATH` | (required for distributed) | NFS export path |
| `OPCACHE_VALIDATE_TIMESTAMPS` | `0` | Set to `1` for development |

## Docker Compose Structure

```yaml
services:
  wordpress:
    build: ./docker-image/wordpress
    environment:
      - WORDPRESS_MODE=distributed
      - REDIS_HOST=redis
    volumes:
      - wp_content:/var/www/html/wp-content
    deploy:
      replicas: 2  # Horizontal scaling
    depends_on:
      - mysql
      - redis

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

  mysql:
    image: mysql:8.0
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  wp_content:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_SERVER},nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2
      device: ":${NFS_PATH}"
  redis_data:
  mysql_data:
```

## Initialization Sequence

```
Container Start
     │
     ├─► wait_for_mysql()
     │
     ├─► wait_for_redis() [NEW - if REDIS_HOST set]
     │
     ├─► init_wp_content_distributed() [NEW - if WORDPRESS_MODE=distributed]
     │        │
     │        ├─► Check if /var/www/html/wp-content is empty
     │        │
     │        └─► If empty: cp -a /opt/wordpress/wp-content-base/* /var/www/html/wp-content/
     │
     ├─► fix_permissions()
     │
     ├─► init_redis_object_cache() [NEW - if REDIS_HOST set]
     │        │
     │        ├─► Check if redis-cache plugin installed
     │        │
     │        ├─► If not: wp plugin install redis-cache --activate
     │        │
     │        └─► wp redis enable (creates object-cache.php drop-in)
     │
     └─► exec apache2-foreground
```

## Testing Verification

### Session Persistence Test
1. Start 2 WordPress replicas
2. Log into WordPress admin on replica A
3. Force request to replica B (stop replica A or use direct IP)
4. Verify session maintained (still logged in)

### Object Cache Test
1. Install Query Monitor plugin
2. Load a page, note database queries
3. Reload page, verify queries served from cache
4. Check Redis: `redis-cli -n 0 KEYS "*"` shows cached data

### NFS Consistency Test
1. Upload media file through replica A
2. Verify file visible through replica B immediately
3. Install plugin through replica A
4. Verify plugin appears in replica B admin
