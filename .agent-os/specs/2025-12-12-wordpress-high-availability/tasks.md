# Spec Tasks

## Tasks

- [ ] 1. **Modify Dockerfile for Distributed Mode Support**
  - [ ] 1.1 Add PHP Redis extension installation (`pecl install redis`)
  - [ ] 1.2 Install WP-CLI with checksum verification
  - [ ] 1.3 Create `/opt/wordpress/wp-content-base` directory (outside DocumentRoot)
  - [ ] 1.4 Move default wp-content contents to `/opt/wordpress/wp-content-base` after WordPress extraction
  - [ ] 1.5 Build and verify image builds successfully

- [ ] 2. **Implement Distributed Mode Initialization in entrypoint.sh**
  - [ ] 2.1 Add `wait_for_redis()` function to check Redis availability
  - [ ] 2.2 Add `init_wp_content_distributed()` function to seed wp-content from `/opt/wordpress/wp-content-base`
  - [ ] 2.3 Add `init_redis_object_cache()` function for WP-CLI plugin installation
  - [ ] 2.4 Update main execution flow with conditional logic based on `WORDPRESS_MODE`
  - [ ] 2.5 Test entrypoint with `WORDPRESS_MODE=standalone` (backward compatibility)
  - [ ] 2.6 Test entrypoint with `WORDPRESS_MODE=distributed` (new behavior)

- [ ] 3. **Configure Redis Integration**
  - [ ] 3.1 Create `php-redis.ini` for session handler configuration
  - [ ] 3.2 Update `wp-config.php` with Redis constants (WP_REDIS_HOST, WP_REDIS_PORT, WP_REDIS_DATABASE)
  - [ ] 3.3 Update `opcache.ini` with `validate_timestamps` environment variable support
  - [ ] 3.4 Verify PHP session handler switches to Redis when configured

- [ ] 4. **Create Docker Compose Configuration**
  - [ ] 4.1 Create `docker-compose.yml` with WordPress, MySQL, and Redis services
  - [ ] 4.2 Configure NFS volume with driver_opts for wp_content
  - [ ] 4.3 Add Redis service with AOF persistence
  - [ ] 4.4 Configure environment variables and service dependencies
  - [ ] 4.5 Create `.env.example` with all required environment variables documented

- [ ] 5. **Create Integration Test Scripts**
  - [ ] 5.1 Create `scripts/tests/test-standalone-mode.sh` - Verify backward compatibility
  - [ ] 5.2 Create `scripts/tests/test-distributed-mode.sh` - Verify NFS initialization
  - [ ] 5.3 Create `scripts/tests/test-session-persistence.sh` - Verify Redis sessions across replicas
  - [ ] 5.4 Create `scripts/tests/test-object-cache.sh` - Verify Redis object cache functionality
  - [ ] 5.5 Create `scripts/tests/test-file-consistency.sh` - Verify NFS file sharing across replicas
  - [ ] 5.6 Run all test scripts and verify all scenarios pass

---

## Test Scripts Specification

### 5.1 `test-standalone-mode.sh`
**Purpose:** Verify backward compatibility when `WORDPRESS_MODE` is not set or set to `standalone`

**Scenarios:**
```bash
#!/bin/bash
# Test: Standalone Mode (Backward Compatibility)

echo "=== Test 1: Default mode (no WORDPRESS_MODE) ==="
# 1. Start single WordPress container without WORDPRESS_MODE
# 2. Verify wp-content uses local filesystem (not NFS)
# 3. Verify WordPress loads correctly
# 4. Verify plugins/themes directory exists locally

echo "=== Test 2: Explicit standalone mode ==="
# 1. Start with WORDPRESS_MODE=standalone
# 2. Verify same behavior as default
# 3. Verify no Redis connection attempted if REDIS_HOST not set

echo "=== Test 3: Standalone without Redis ==="
# 1. Start without REDIS_HOST set
# 2. Verify PHP sessions use default file handler
# 3. Verify no errors about Redis connection
```

### 5.2 `test-distributed-mode.sh`
**Purpose:** Verify NFS volume initialization and wp-content seeding

**Scenarios:**
```bash
#!/bin/bash
# Test: Distributed Mode Initialization

echo "=== Test 1: First boot with empty NFS volume ==="
# 1. Start with WORDPRESS_MODE=distributed and empty NFS mount
# 2. Verify wp-content-base contents copied to wp-content
# 3. Verify default themes exist (twentytwentyfour, etc.)
# 4. Verify default plugins directory created
# 5. Verify uploads directory created with correct permissions

echo "=== Test 2: Subsequent boot with populated NFS ==="
# 1. Stop and restart container
# 2. Verify NO overwrite of existing wp-content
# 3. Verify previously uploaded files still present

echo "=== Test 3: Multiple replicas first boot ==="
# 1. Start 2 replicas simultaneously with empty NFS
# 2. Verify race condition handled (only one seeds, others wait)
# 3. Verify both replicas see same wp-content after boot
```

### 5.3 `test-session-persistence.sh`
**Purpose:** Verify PHP sessions persist across WordPress replicas via Redis

**Scenarios:**
```bash
#!/bin/bash
# Test: Session Persistence Across Replicas

echo "=== Test 1: Login persists across replicas ==="
# 1. Start 2 WordPress replicas with Redis
# 2. Login to WordPress admin via replica A (curl with cookies)
# 3. Stop replica A
# 4. Access WordPress admin via replica B with same cookies
# 5. Verify still logged in (no redirect to login page)

echo "=== Test 2: Session stored in Redis DB 1 ==="
# 1. Login to WordPress
# 2. Execute: redis-cli -n 1 KEYS "PHPREDIS_SESSION:*"
# 3. Verify session key exists
# 4. Verify session data contains WordPress user info

echo "=== Test 3: Session expiration ==="
# 1. Login and capture session ID
# 2. Wait for session timeout (or manually expire)
# 3. Verify session removed from Redis
# 4. Verify user redirected to login
```

### 5.4 `test-object-cache.sh`
**Purpose:** Verify Redis Object Cache reduces MySQL queries

**Scenarios:**
```bash
#!/bin/bash
# Test: Redis Object Cache Functionality

echo "=== Test 1: Object cache plugin active ==="
# 1. Start WordPress with Redis
# 2. Execute: wp plugin list | grep redis-cache
# 3. Verify status is 'active'
# 4. Execute: wp redis status
# 5. Verify 'Status: Connected'

echo "=== Test 2: Cache populated in Redis DB 0 ==="
# 1. Load WordPress homepage
# 2. Execute: redis-cli -n 0 KEYS "*"
# 3. Verify keys exist (wp_options, transients, etc.)
# 4. Verify key count > 0

echo "=== Test 3: Cache hit reduces queries ==="
# 1. Enable WordPress query logging or use Query Monitor
# 2. Load homepage first time - count queries (expect ~50-100)
# 3. Load homepage second time - count queries (expect ~5-15)
# 4. Verify reduction of at least 70%

echo "=== Test 4: Cache flush works ==="
# 1. Execute: wp cache flush
# 2. Verify Redis DB 0 keys cleared
# 3. Load page, verify cache repopulated
```

### 5.5 `test-file-consistency.sh`
**Purpose:** Verify files written on one replica are immediately visible on others

**Scenarios:**
```bash
#!/bin/bash
# Test: NFS File Consistency Across Replicas

echo "=== Test 1: Media upload visible across replicas ==="
# 1. Upload image via replica A (wp media import or REST API)
# 2. Get file path from response
# 3. Immediately check file exists on replica B filesystem
# 4. Verify file accessible via HTTP on replica B

echo "=== Test 2: Plugin installation visible across replicas ==="
# 1. Install plugin via replica A: wp plugin install hello-dolly --activate
# 2. Verify plugin files exist on replica B: ls wp-content/plugins/hello-dolly
# 3. Access replica B admin, verify plugin shows as active

echo "=== Test 3: Theme customization visible across replicas ==="
# 1. Modify theme file via replica A
# 2. Verify modification visible on replica B immediately
# 3. Load page on replica B, verify change reflected

echo "=== Test 4: Concurrent writes from multiple replicas ==="
# 1. Upload file from replica A
# 2. Simultaneously upload different file from replica B
# 3. Verify both files exist and are not corrupted
# 4. Verify no NFS locking errors in logs
```
