# Product Roadmap

## Phase 1: WordPress Infrastructure

**Goal:** Deploy a fully functional WordPress blog with Docker Compose and custom-built images
**Success Criteria:** WordPress accessible at blog.devopsbegins.com with persistent data

### Features

- [x] Create custom WordPress Dockerfile from PHP-Apache base image `M`
- [x] Configure PHP extensions (mysqli, gd, zip, exif, intl, opcache, imagick) `S`
- [ ] Set up MySQL 8.0 container with proper configuration `S`
- [ ] Create docker-compose.yml with all services `M`
- [ ] Configure environment variables for WordPress and MySQL `S`
- [ ] Set up Docker volumes for wp-content and MySQL data `S`

### Dependencies

- Docker and Docker Compose installed on host
- Domain DNS configured (blog.devopsbegins.com)

### Documentation Deliverables

- `docs/phase-1-wordpress-setup.md` - Complete setup guide

---

## Phase 2: Backup System Core

**Goal:** Implement Python backup job with adapter pattern for multiple storage destinations
**Success Criteria:** Successful backup of wp-content to local storage with logs

### Features

- [ ] Design adapter interface for storage backends `S`
- [ ] Implement LocalAdapter for filesystem storage `S`
- [ ] Implement S3Adapter for AWS S3 `M`
- [ ] Implement GCSAdapter for Google Cloud Storage `M`
- [ ] Implement DriveAdapter for Google Drive `M`
- [ ] Create backup job main script `M`
- [ ] Add compression for backup archives (tar.gz) `S`
- [ ] Create Dockerfile for backup container `S`
- [ ] Add backup service to docker-compose.yml `S`

### Dependencies

- Phase 1 completed
- Cloud credentials configured (for S3/GCS/Drive adapters)

### Documentation Deliverables

- `docs/phase-2-backup-system.md` - Backup architecture and usage guide

---

## Phase 3: Backup Management

**Goal:** Implement backup tracking and retention management with MySQL
**Success Criteria:** Automated cleanup of old backups based on configurable retention policy

### Features

- [ ] Design MySQL schema for backup records table `S`
- [ ] Create database migration script `S`
- [ ] Implement backup registration in database `S`
- [ ] Implement retention policy configuration `S`
- [ ] Create cleanup job for expired backups `M`
- [ ] Add backup listing and status commands `S`
- [ ] Implement backup verification (integrity check) `M`

### Dependencies

- Phase 2 completed
- MySQL database accessible from backup container

### Documentation Deliverables

- `docs/phase-3-backup-management.md` - Retention configuration and management guide

---

## Phase 4: Production Hardening

**Goal:** Secure the deployment for production use
**Success Criteria:** Pass basic security checklist, HTTPS configured

### Features

- [x] Configure WordPress security salts generation `S`
- [ ] Set up SSL/TLS termination (reverse proxy or ingress) `M`
- [ ] Configure firewall rules (Docker network isolation) `S`
- [ ] Implement backup encryption at rest `M`
- [ ] Add health checks to all containers `S`
- [ ] Configure logging and monitoring basics `M`
- [ ] Create security hardening checklist `S`

### Dependencies

- Phase 3 completed
- SSL certificates available (Let's Encrypt or other)

### Documentation Deliverables

- `docs/phase-4-security-hardening.md` - Security configuration guide

---

## Phase 5: Kubernetes Migration

**Goal:** Migrate Docker Compose setup to Kubernetes manifests
**Success Criteria:** WordPress running on Kubernetes with backup job as CronJob

### Features

- [ ] Create Kubernetes Deployment for WordPress `M`
- [ ] Create Kubernetes StatefulSet for MySQL `M`
- [ ] Configure Kubernetes Secrets and ConfigMaps `S`
- [ ] Create PersistentVolumeClaims for data `S`
- [ ] Implement backup job as Kubernetes CronJob `M`
- [ ] Set up Ingress for external access (handles SSL/routing) `M`
- [ ] Document migration steps from Docker Compose `L`

### Dependencies

- Phase 4 completed
- Kubernetes cluster available (GKE or local)

### Documentation Deliverables

- `docs/phase-5-kubernetes-migration.md` - Migration guide from Docker Compose to K8s

---

## Effort Scale Reference

| Label | Effort |
|-------|--------|
| XS | 1 day |
| S | 2-3 days |
| M | 1 week |
| L | 2 weeks |
| XL | 3+ weeks |
