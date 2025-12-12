# Building a WordPress Docker Image from Scratch

In this post, we'll build a WordPress Docker image from a PHP base, understanding each decision and learning how to research things on our own.

## Why Not Use the Official WordPress Image?

Docker Hub has an [official WordPress image](https://hub.docker.com/_/wordpress) that works perfectly. So why build our own?

1. **Learning**: Understand what's inside the "black box"
2. **Control**: Choose exactly which versions and extensions to include
3. **Security**: Know what we're running in production
4. **Optimization**: Configure PHP specifically for our needs

## Choosing the Base Image

### How to Find Available Images?

The first step is choosing a PHP base image. We can search on Docker Hub:

```bash
# View available PHP tags
curl -s "https://registry.hub.docker.com/v2/repositories/library/php/tags?page_size=100" | \
  python3 -c "import sys,json; [print(t['name']) for t in json.load(sys.stdin)['results']]"
```

Or simply visit https://hub.docker.com/_/php/tags

### FPM, CLI, or Apache?

PHP in Docker comes in several variants:

| Variant | Description | When to Use |
|---------|-------------|-------------|
| `php:8.2-cli` | CLI only | Scripts, cron jobs |
| `php:8.2-apache` | PHP + integrated Apache | Simple projects |
| `php:8.2-fpm` | PHP-FPM (FastCGI) | With Nginx (recommended) |

**We choose FPM** because:
- Nginx handles static files better than Apache
- PHP-FPM allows managing PHP processes independently
- It's the most common production configuration

### Alpine or Debian?

```
php:8.2-fpm         → Debian-based (~400MB)
php:8.2-fpm-alpine  → Alpine-based (~50MB)
```

**We choose Alpine** because:
- 8x smaller image
- Fewer packages = smaller attack surface
- Faster deployments

### How to Find the Latest Exact Version?

```bash
# Search for specific PHP 8.2 FPM Alpine versions
curl -s "https://registry.hub.docker.com/v2/repositories/library/php/tags?page_size=100&name=8.2" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  [print(t['name']) for t in d['results'] if 'fpm-alpine' in t['name'] and t['name'][0].isdigit()]"
```

Result (December 2025):
```
8.2.29-fpm-alpine3.23  ← We choose this one
8.2.29-fpm-alpine3.22
8.2.29-fpm-alpine
...
```

**Tip**: Always pin specific versions (`8.2.29-fpm-alpine3.23`) instead of generic tags (`8.2-fpm-alpine`). This ensures reproducible builds.

## PHP Extensions for WordPress

### How to Know Which Extensions WordPress Needs?

The official documentation is at: https://make.wordpress.org/hosting/handbook/server-environment/

**Required extensions:**
- `mysqli` - MySQL connection
- `json` - Already included in PHP 8+

**Recommended extensions:**
- `gd` or `imagick` - Image manipulation
- `zip` - Plugin/theme installation
- `exif` - Image metadata
- `intl` - Internationalization
- `opcache` - Bytecode cache (performance)

### Installing Extensions on Alpine

Official PHP images include helper scripts:

```dockerfile
# Configure compilation options (only if the extension requires it)
docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp

# Compile and install
docker-php-ext-install mysqli gd zip exif intl opcache

# For PECL extensions (not bundled with PHP)
pecl install imagick
docker-php-ext-enable imagick
```

### What Does `docker-php-ext-configure` Do?

Some extensions need to know where system libraries are located. For example, GD needs the image libraries:

```dockerfile
# Without the helper (manual and complicated):
cd /usr/src/php/ext/gd
phpize
./configure --with-freetype=/usr/include/freetype2 --with-jpeg=/usr/include
make && make install

# With the helper (simple):
docker-php-ext-configure gd --with-freetype --with-jpeg
docker-php-ext-install gd
```

### System Dependencies

Before compiling extensions, we need the system libraries:

```dockerfile
RUN apk add --no-cache \
    # Runtime (stays in the final image)
    freetype libjpeg-turbo libpng libwebp libzip icu imagemagick \
    # Build (removed afterwards)
    freetype-dev libjpeg-turbo-dev libpng-dev libwebp-dev \
    libzip-dev icu-dev imagemagick-dev $PHPIZE_DEPS
```

**Important**: The `-dev` packages contain headers for compilation but aren't needed at runtime. We remove them afterwards to reduce image size.

## Downloading WordPress

### How to Find the Latest Version?

```bash
# Official WordPress API
curl -s "https://api.wordpress.org/core/version-check/1.7/" | grep -o '"version":"[^"]*"' | head -1
# Result: "version":"6.9"
```

### Integrity Verification

We always verify the downloaded file's hash:

```bash
# Get the official SHA1
curl -s "https://wordpress.org/wordpress-6.9.tar.gz.sha1"
# Result: 256dda5bb6a43aecd806b7a62528f442c06e6c25
```

In the Dockerfile:
```dockerfile
ARG WORDPRESS_VERSION=6.9
ARG WORDPRESS_SHA1=256dda5bb6a43aecd806b7a62528f442c06e6c25

RUN curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" \
    && echo "${WORDPRESS_SHA1} *wordpress.tar.gz" | sha1sum -c - \
    && tar -xzf wordpress.tar.gz --strip-components=1
```

**Why verify the hash?** It protects against:
- Corrupted downloads
- Man-in-the-middle attacks
- Download server compromise

## PHP Configuration

### OPcache: PHP's Turbo

OPcache stores compiled PHP code in memory. Without OPcache, PHP has to:

1. Read the .php file from disk
2. Parse the code
3. Compile to bytecode
4. Execute

With OPcache, steps 1-3 happen only once.

```ini
; How much memory for cached scripts
opcache.memory_consumption=128

; How often to check if PHP files changed
opcache.revalidate_freq=60
```

**Common question**: Does `revalidate_freq=60` mean comments take 1 minute to appear?

**No.** OPcache only caches **PHP code**, not data. Comments, posts, and everything in the database is queried on every request. `revalidate_freq` only affects when PHP checks if `.php` files changed on disk.

### Configuration for WordPress

```ini
upload_max_filesize=64M   ; Maximum uploaded file size
post_max_size=64M         ; Maximum POST data size
memory_limit=256M         ; Memory per PHP process
max_execution_time=300    ; 5 minutes (for large imports)
max_input_vars=3000       ; For page builders like Elementor
```

## wp-config.php with Environment Variables

Instead of hardcoding credentials:

```php
// ❌ Bad - credentials in code
define('DB_PASSWORD', 'my_secret_password');

// ✅ Good - read from environment variables
define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD'));
```

This follows the [12-factor app](https://12factor.net/config) principle: configuration should come from the environment, not from code.

## Entrypoint: Container Initialization

The `entrypoint.sh` script solves common problems:

### 1. Race Condition with MySQL

In Docker Compose, containers start simultaneously. WordPress might try to connect before MySQL is ready.

```bash
# Wait until MySQL responds
while ! php -r "new mysqli('mysql', 'user', 'pass');" 2>/dev/null; do
    echo "Waiting for MySQL..."
    sleep 1
done
```

### 2. File Permissions

Docker volumes can have incorrect permissions:

```bash
chown -R www-data:www-data /var/www/html/wp-content
find /var/www/html/wp-content -type d -exec chmod 755 {} \;
find /var/www/html/wp-content -type f -exec chmod 644 {} \;
```

## Testing the Image

```bash
# Build
docker build -t devopsbegins/wordpress:latest docker-image/wordpress/

# Verify installed extensions
docker run --rm devopsbegins/wordpress:latest php -m

# Verify PHP configuration
docker run --rm devopsbegins/wordpress:latest php -i | grep upload_max
```

## Resources for Research

- **Docker Hub PHP**: https://hub.docker.com/_/php
- **WordPress Server Requirements**: https://make.wordpress.org/hosting/handbook/server-environment/
- **PHP Extensions**: https://www.php.net/manual/en/extensions.alphabetical.php
- **Alpine Packages**: https://pkgs.alpinelinux.org/packages
- **12-Factor App**: https://12factor.net/

## Next Steps

In the next post, we'll configure Nginx as a reverse proxy and create the `docker-compose.yml` to orchestrate all services.

---

*This post is part of the "DevOps from Scratch" series where we build real infrastructure documenting every step.*
