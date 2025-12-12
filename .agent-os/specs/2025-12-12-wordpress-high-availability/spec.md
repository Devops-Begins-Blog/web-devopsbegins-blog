# Spec Requirements Document

> Spec: WordPress High Availability
> Created: 2025-12-12

## Overview

Implement a horizontally scalable WordPress architecture for Docker Compose that ensures consistency and performance across multiple replicas through three pillars: shared file persistence (NFS), centralized session/cache management (Redis), and PHP optimization (OPcache). This enables running multiple WordPress containers behind a load balancer without state inconsistencies.

## User Stories

### Scaling WordPress Without Session Loss

As a DevOps engineer, I want to scale WordPress horizontally with multiple replicas, so that I can handle increased traffic without users losing their sessions or seeing inconsistent content.

When traffic increases, I need to spin up additional WordPress containers. Currently, each container has its own isolated filesystem and session storage, causing users to lose their shopping cart or login state when requests hit different replicas. With this implementation, all replicas will share the same `/wp-content` directory via NFS and use Redis for centralized session storage, ensuring a seamless user experience regardless of which replica serves the request.

### Reducing MySQL Load with Object Caching

As a site administrator, I want WordPress to cache database queries in Redis, so that MySQL doesn't become a bottleneck under high traffic.

WordPress makes repetitive database queries for options, transients, and post data. By implementing Redis Object Cache, these queries are served from memory instead of hitting MySQL repeatedly. This can reduce MySQL load by 80-95%, improving response times and allowing the database to handle more concurrent connections.

### Maintaining Plugin/Theme Consistency Across Replicas

As a content manager, I want plugins and themes installed on one replica to be immediately available on all replicas, so that I don't have to manually sync files or deal with inconsistent states.

When I install a plugin through the WordPress admin on one replica, the files should be written to shared NFS storage and immediately accessible by all other replicas. The initialization logic ensures that default WordPress content is properly seeded to the shared volume on first deployment.

## Spec Scope

1. **NFS Volume Configuration** - Configure Docker Compose with NFS driver for shared `/wp-content` volume across all WordPress replicas
2. **WordPress Initialization Logic** - Implement `entrypoint.sh` logic to detect `WORDPRESS_MODE=distributed` and seed `/wp-content` from `/wp-content-base` if empty
3. **Redis Deployment** - Add Redis service to Docker Compose with persistent volume for centralized cache and session storage
4. **PHP Session Configuration** - Configure PHP to use Redis (DB 1) as session handler via `session.save_path`
5. **Redis Object Cache Setup** - Install WP-CLI in Docker image, configure `wp-config.php` for Redis Object Cache (DB 0), and automate plugin installation
6. **OPcache Optimization** - Verify and configure OPcache settings (`opcache.enable=1`, `opcache.validate_timestamps=0`) in PHP configuration

## Out of Scope

- Kubernetes/GKE implementation (planned for Phase 5)
- CDN integration (can be implemented separately with Nginx cache-control headers and Cloudflare/Cloud CDN)
- MySQL replication or clustering (single MySQL instance)
- WordPress multisite configuration
- Automated WordPress core updates
- Backup system (covered separately in Phase 2)
- NFS server provisioning (assumes external NFS endpoint is provided)
- Load balancer configuration (assumes external load balancer like Nginx or Traefik)

## Expected Deliverable

1. Docker Compose configuration with WordPress replicas sharing NFS volume, Redis service with persistence, and proper networking between services
2. Modified WordPress Dockerfile with WP-CLI installed, `/wp-content-base` directory containing default content, and updated `entrypoint.sh` with distributed mode initialization logic
3. WordPress containers successfully sharing sessions and object cache through Redis, verifiable by logging into WordPress on one replica and maintaining session when served by another replica
