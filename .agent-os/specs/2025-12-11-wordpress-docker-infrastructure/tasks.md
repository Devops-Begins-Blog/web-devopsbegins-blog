# Spec Tasks

## Tasks

- [x] 1. Create WordPress Docker image
  - [x] 1.1 Create `docker-image/wordpress/Dockerfile` with PHP 8.2.29-Apache (Debian Trixie)
  - [x] 1.2 Install PHP extensions (mysqli, gd, zip, exif, intl, opcache, imagick)
  - [x] 1.3 Download and install pinned WordPress 6.9 (SHA1 verified)
  - [x] 1.4 Create `docker-image/wordpress/files/wp-config.php` with environment variable support
  - [x] 1.5 Create `docker-image/wordpress/files/entrypoint.sh` for initialization
  - [x] 1.6 Test WordPress image builds successfully

- [ ] 2. Create Docker Compose configuration
  - [ ] 2.1 Create `docker-compose.yml` with WordPress and MySQL services
  - [ ] 2.2 Configure internal network for service communication
  - [ ] 2.3 Define named volumes for wp-content and mysql-data
  - [ ] 2.4 Set environment variables for WordPress and MySQL
  - [ ] 2.5 Configure service dependencies and health checks

- [ ] 3. Integration testing
  - [ ] 3.1 Run `docker compose up -d` and verify all containers start
  - [ ] 3.2 Access WordPress installation wizard via browser
  - [ ] 3.3 Complete WordPress setup and create test post
  - [ ] 3.4 Verify data persists after `docker compose down && docker compose up -d`

- [ ] 4. Documentation
  - [ ] 4.1 Create `docs/phase-1-wordpress-setup.md` with architecture overview
  - [ ] 4.2 Document architecture decision (Apache vs Nginx)
  - [ ] 4.3 Add setup instructions and troubleshooting guide
