# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2025-12-12-wordpress-helm-chart/spec.md

## Chart Structure

```
helm-chart/
└── wordpress/
    ├── Chart.yaml              # Chart metadata and dependencies
    ├── Chart.lock              # Locked dependency versions
    ├── values.yaml             # Default configuration values
    ├── values-standalone.yaml  # Example standalone config
    ├── values-distributed.yaml # Example distributed config
    ├── templates/
    │   ├── _helpers.tpl        # Template helper functions
    │   ├── deployment.yaml     # WordPress Deployment
    │   ├── service.yaml        # WordPress Service
    │   ├── ingress.yaml        # Optional Ingress resource
    │   ├── configmap.yaml      # WordPress configuration
    │   ├── secret.yaml         # Sensitive credentials
    │   ├── hpa.yaml            # Horizontal Pod Autoscaler (optional)
    │   ├── pvc.yaml            # PersistentVolumeClaim for wp-content
    │   ├── serviceaccount.yaml # ServiceAccount (optional)
    │   └── NOTES.txt           # Post-install instructions
    └── charts/                 # Subchart dependencies (auto-populated)
```

## Technical Requirements

### Deployment Modes

| Mode | Replicas | Redis | Use Case |
|------|----------|-------|----------|
| standalone | 1 | Disabled | Development, testing |
| distributed | 2+ | Required | Production, HA |

### WordPress Image

- **Image**: Custom image from `docker-image/wordpress/Dockerfile`
- **Registry**: User-configurable (default: local or custom registry)
- **Tag**: Configurable, defaults to chart appVersion
- **Pull Policy**: IfNotPresent (configurable)

### Health Check Endpoints

Custom PHP health check script at `/health.php`:

```php
<?php
// /var/www/html/health.php
header('Content-Type: application/json');

$checks = [
    'wordpress' => false,
    'mysql' => false,
    'redis' => null  // null when not applicable
];

// WordPress check - verify wp-config.php exists and is readable
$checks['wordpress'] = file_exists('/var/www/html/wp-config.php');

// MySQL check
try {
    $mysqli = new mysqli(
        getenv('WORDPRESS_DB_HOST'),
        getenv('WORDPRESS_DB_USER'),
        getenv('WORDPRESS_DB_PASSWORD'),
        getenv('WORDPRESS_DB_NAME')
    );
    $checks['mysql'] = !$mysqli->connect_error;
    $mysqli->close();
} catch (Exception $e) {
    $checks['mysql'] = false;
}

// Redis check (only in distributed mode)
if (getenv('REDIS_HOST')) {
    try {
        $redis = new Redis();
        $checks['redis'] = $redis->connect(
            getenv('REDIS_HOST'),
            (int)getenv('REDIS_PORT') ?: 6379,
            2.0  // 2 second timeout
        );
        $redis->close();
    } catch (Exception $e) {
        $checks['redis'] = false;
    }
}

// Determine overall health
$healthy = $checks['wordpress'] && $checks['mysql'];
if ($checks['redis'] !== null) {
    $healthy = $healthy && $checks['redis'];
}

http_response_code($healthy ? 200 : 503);
echo json_encode([
    'status' => $healthy ? 'healthy' : 'unhealthy',
    'checks' => $checks,
    'timestamp' => date('c')
]);
```

### Kubernetes Probes Configuration

```yaml
livenessProbe:
  httpGet:
    path: /health.php
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health.php
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /health.php
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 30  # Allow up to 150s for initial startup
```

### Dependencies (Subcharts)

```yaml
# Chart.yaml dependencies
dependencies:
  - name: mysql
    version: "~11.1"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: mysql.enabled
  - name: redis
    version: "~20.0"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: redis.enabled
```

### Values Schema

```yaml
# values.yaml structure
mode: standalone  # standalone | distributed

replicaCount: 1  # Overridden to 2+ in distributed mode

image:
  repository: devopsbegins/wordpress
  tag: ""  # Defaults to chart appVersion
  pullPolicy: IfNotPresent

imagePullSecrets: []

wordpress:
  siteUrl: ""  # Auto-detected if empty
  tablePrefix: "wp_"
  debug: false
  extraEnv: []

# MySQL Configuration
mysql:
  enabled: true  # Set to false for external MySQL
  auth:
    database: wordpress
    username: wordpress
    password: ""  # Required if enabled
    rootPassword: ""  # Required if enabled
  primary:
    persistence:
      enabled: true
      size: 8Gi

# External MySQL (when mysql.enabled=false)
externalDatabase:
  host: ""
  port: 3306
  database: wordpress
  user: wordpress
  password: ""
  existingSecret: ""
  existingSecretPasswordKey: password

# Redis Configuration (distributed mode)
redis:
  enabled: false  # Auto-enabled in distributed mode
  architecture: standalone
  auth:
    enabled: false
  master:
    persistence:
      enabled: true
      size: 1Gi

# External Redis (when redis.enabled=false and mode=distributed)
externalRedis:
  host: ""
  port: 6379
  password: ""
  database: 0
  sessionDatabase: 1
  existingSecret: ""
  existingSecretPasswordKey: password

# Service Configuration
service:
  type: ClusterIP
  port: 80

# Ingress Configuration
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: wordpress.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

# Persistence for wp-content
persistence:
  enabled: true
  storageClass: ""  # Use default StorageClass if empty
  accessModes:
    - ReadWriteOnce  # Use ReadWriteMany for distributed mode
  size: 10Gi
  existingClaim: ""

# Resource Limits
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Autoscaling (distributed mode)
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

# Pod Configuration
nodeSelector: {}
tolerations: []
affinity: {}
podAnnotations: {}
podSecurityContext:
  fsGroup: 33  # www-data group
securityContext:
  runAsUser: 33
  runAsGroup: 33
  runAsNonRoot: true

serviceAccount:
  create: false
  name: ""
  annotations: {}
```

### Mode-Specific Behavior

#### Standalone Mode (`mode: standalone`)
- `replicaCount`: Fixed to 1
- `redis.enabled`: Forced to false
- `persistence.accessModes`: ReadWriteOnce
- Sessions: File-based (default PHP)

#### Distributed Mode (`mode: distributed`)
- `replicaCount`: Minimum 2
- `redis.enabled`: Auto-enabled unless `externalRedis.host` set
- `persistence.accessModes`: Must be ReadWriteMany
- Sessions: Redis-backed (DB 1)
- Object Cache: Redis (DB 0)

### ConfigMap Contents

```yaml
# WordPress runtime configuration
data:
  WORDPRESS_DB_HOST: "{{ database host }}"
  WORDPRESS_DB_NAME: "{{ database name }}"
  WORDPRESS_DB_USER: "{{ database user }}"
  WORDPRESS_TABLE_PREFIX: "{{ table prefix }}"
  WORDPRESS_DEBUG: "{{ debug mode }}"
  # Distributed mode only
  REDIS_HOST: "{{ redis host }}"
  REDIS_PORT: "{{ redis port }}"
  WP_REDIS_HOST: "{{ redis host }}"
  WP_REDIS_PORT: "{{ redis port }}"
  WP_REDIS_DATABASE: "0"
  PHP_SESSION_HANDLER: "redis"
  PHP_SESSION_SAVE_PATH: "tcp://{{ redis host }}:{{ redis port }}?database=1"
```

### Secret Contents

```yaml
data:
  WORDPRESS_DB_PASSWORD: "{{ base64 encoded }}"
  # If external Redis with auth
  REDIS_PASSWORD: "{{ base64 encoded }}"
```

## Storage Considerations

### Shared Storage for Distributed Mode

For distributed mode with multiple replicas, `wp-content` must be shared. Options:

1. **NFS StorageClass** (recommended for on-prem)
   - Requires pre-configured NFS server
   - StorageClass with provisioner like `nfs-subdir-external-provisioner`

2. **Cloud Provider Solutions**
   - GKE: Filestore CSI driver
   - EKS: EFS CSI driver
   - AKS: Azure Files

3. **ReadWriteOnce with Single Writer** (not recommended)
   - Only one pod writes, others read
   - Complex application logic required

**Prerequisite Documentation**: Chart README will document that users must:
1. Have a StorageClass supporting ReadWriteMany
2. Or use external object storage for media (future enhancement)

## Security Considerations

- Secrets stored in Kubernetes Secrets (base64 encoded)
- Support for existing secrets (don't create if `existingSecret` provided)
- Non-root container execution (www-data user, UID 33)
- Network policies not included (can be added externally)
- No hardcoded credentials in templates

## Validation Logic

```yaml
# _helpers.tpl validation
{{- if and (eq .Values.mode "distributed") (lt (int .Values.replicaCount) 2) }}
  {{- fail "distributed mode requires replicaCount >= 2" }}
{{- end }}

{{- if and (eq .Values.mode "distributed") (not .Values.redis.enabled) (empty .Values.externalRedis.host) }}
  {{- fail "distributed mode requires redis.enabled=true or externalRedis.host" }}
{{- end }}

{{- if and (eq .Values.mode "distributed") (contains "ReadWriteOnce" .Values.persistence.accessModes) }}
  {{- fail "distributed mode requires ReadWriteMany storage" }}
{{- end }}
```
