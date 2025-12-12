# =============================================================================
# WordPress Docker Image - DevOpsBegins Blog
# =============================================================================
#
# Purpose:
#   Custom WordPress image built from PHP base for full control and educational
#   value. This image serves as both the production runtime and demonstration
#   of Docker best practices for the DevOpsBegins Blog platform.
#
# Architecture:
#   - Base: PHP 8.2 with Apache (serves HTTP directly on port 80)
#   - WordPress: Downloaded and verified at build time (not runtime)
#   - PHP Extensions: Only what WordPress requires (security principle)
#   - Configuration: Environment variable driven (12-factor app)
#
# Why custom image instead of official WordPress image?
#   1. Educational: Understand every layer of the stack
#   2. Control: Pin exact versions for reproducibility
#   3. Security: Know exactly what's installed
#   4. Performance: OPcache tuned for WordPress
#   See: .agent-os/product/decisions.md (DEC-002)
#
# Build:
#   docker build -t devopsbegins/wordpress:latest .
#
# Runtime Requirements:
#   - MySQL 8.0 database (see docker-compose.yml)
#   - Environment variables for database connection
#
# =============================================================================

# -----------------------------------------------------------------------------
# Stage: Base Image
# -----------------------------------------------------------------------------
# Using php:8.2.29-apache (Debian Bookworm based)
#   - PHP 8.2.29 (latest 8.2.x as of Dec 2025)
#   - Apache 2.4 integrated (serves HTTP on port 80)
#   - Debian provides better package availability than Alpine for Apache
# -----------------------------------------------------------------------------
FROM php:8.2.29-apache

# -----------------------------------------------------------------------------
# Metadata Labels
# -----------------------------------------------------------------------------
LABEL org.opencontainers.image.title="DevOpsBegins WordPress"
LABEL org.opencontainers.image.description="Custom WordPress image with PHP-Apache for DevOpsBegins Blog"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.vendor="DevOpsBegins"
LABEL org.opencontainers.image.source="https://github.com/Devops-Begins-Blog/web-devopsbegins-blog"

# -----------------------------------------------------------------------------
# Build Arguments and Environment Variables
# -----------------------------------------------------------------------------
# WordPress version pinned for reproducibility
# SHA1 hash for integrity verification (defense against supply chain attacks)
#
# To update WordPress:
#   1. Check latest version: https://wordpress.org/download/
#   2. Get SHA1: curl -s https://wordpress.org/wordpress-X.X.tar.gz.sha1
#   3. Update both ARG values below
#   4. Rebuild image
# -----------------------------------------------------------------------------
ARG WORDPRESS_VERSION=6.9
ARG WORDPRESS_SHA1=256dda5bb6a43aecd806b7a62528f442c06e6c25

ENV WORDPRESS_VERSION=${WORDPRESS_VERSION}

# -----------------------------------------------------------------------------
# System Dependencies
# -----------------------------------------------------------------------------
# Debian uses apt-get instead of apk
# Install runtime and build dependencies for PHP extensions
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # GD image library requirements
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    # ZIP support
    libzip-dev \
    # Internationalization
    libicu-dev \
    # ImageMagick
    libmagickwand-dev \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# PHP Extensions Installation
# -----------------------------------------------------------------------------
# WordPress core requirements: https://make.wordpress.org/hosting/handbook/server-environment/
# -----------------------------------------------------------------------------
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        mysqli \
        gd \
        zip \
        exif \
        intl \
        opcache \
    && pecl install imagick \
    && docker-php-ext-enable imagick

# -----------------------------------------------------------------------------
# Apache Configuration
# -----------------------------------------------------------------------------
# Enable mod_rewrite for WordPress permalinks
# -----------------------------------------------------------------------------
RUN a2enmod rewrite

# -----------------------------------------------------------------------------
# PHP Configuration Files
# -----------------------------------------------------------------------------
COPY files/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY files/php-wordpress.ini /usr/local/etc/php/conf.d/php-wordpress.ini

# -----------------------------------------------------------------------------
# WordPress Installation
# -----------------------------------------------------------------------------
WORKDIR /var/www/html

# Download, verify, and extract WordPress
RUN set -eux; \
    curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"; \
    echo "${WORDPRESS_SHA1} *wordpress.tar.gz" | sha1sum -c -; \
    tar -xzf wordpress.tar.gz --strip-components=1; \
    rm wordpress.tar.gz; \
    chown -R www-data:www-data /var/www/html

# -----------------------------------------------------------------------------
# Custom Configuration Files
# -----------------------------------------------------------------------------
COPY files/wp-config.php /var/www/html/wp-config.php
COPY files/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# -----------------------------------------------------------------------------
# File Permissions
# -----------------------------------------------------------------------------
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

# -----------------------------------------------------------------------------
# Container Configuration
# -----------------------------------------------------------------------------
# EXPOSE 80: Apache serves HTTP directly
# ENTRYPOINT: Custom script for initialization
# CMD: Start Apache in foreground
# -----------------------------------------------------------------------------
EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
