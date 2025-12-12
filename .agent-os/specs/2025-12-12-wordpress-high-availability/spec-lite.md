# Spec Summary (Lite)

Implement horizontally scalable WordPress for Docker Compose using three pillars: NFS shared storage for `/wp-content` consistency across replicas, Redis for centralized PHP sessions (DB 1) and object cache (DB 0), and OPcache optimization. Includes initialization logic that seeds shared volume from `/wp-content-base` when `WORDPRESS_MODE=distributed` and wp-content is empty. Requires WP-CLI installation and Redis Object Cache plugin automation.
