# WordPress Helm Chart

A Helm chart for deploying WordPress on Kubernetes with standalone and distributed (HA) deployment modes.

## Features

- **Two deployment modes**: Standalone (single replica) and Distributed (multi-replica with Redis)
- **Flexible dependencies**: Use Bitnami subcharts or external MySQL/Redis services
- **Health checks**: Liveness, readiness, and startup probes validating WordPress, MySQL, and Redis connectivity
- **Optional Ingress**: Configurable Ingress resource with TLS support
- **Horizontal Pod Autoscaling**: Automatic scaling based on CPU/memory utilization (distributed mode)

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+
- PV provisioner support in the underlying infrastructure
- **For distributed mode**: StorageClass with ReadWriteMany (RWX) support

### Storage Requirements

| Mode | Access Mode | StorageClass Examples |
|------|-------------|----------------------|
| Standalone | ReadWriteOnce | Default, standard, gp2, pd-standard |
| Distributed | ReadWriteMany | nfs-client, filestore-sc, efs-sc, azurefile |

#### Setting Up NFS StorageClass

If your cluster doesn't have RWX storage, you can set up NFS:

```bash
# Using nfs-subdir-external-provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=<NFS_SERVER_IP> \
  --set nfs.path=<NFS_SHARE_PATH> \
  --set storageClass.name=nfs-client
```

## Installation

### Quick Start (Standalone Mode)

```bash
# Add dependencies
cd helm-chart/wordpress
helm dependency update

# Install with default values (standalone mode)
helm install wordpress . \
  --set mysql.auth.password=your-password \
  --set mysql.auth.rootPassword=your-root-password
```

### Standalone Mode with Custom Values

```bash
helm install wordpress . -f values-standalone.yaml \
  --set mysql.auth.password=your-password \
  --set mysql.auth.rootPassword=your-root-password
```

### Distributed Mode (HA)

```bash
helm install wordpress . -f values-distributed.yaml \
  --set mysql.auth.password=your-password \
  --set mysql.auth.rootPassword=your-root-password \
  --set persistence.storageClass=nfs-client
```

### External MySQL and Redis

```bash
helm install wordpress . -f values-external-services.yaml \
  --set externalDatabase.host=mysql.example.com \
  --set externalDatabase.password=your-db-password \
  --set externalRedis.host=redis.example.com
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mode` | Deployment mode: `standalone` or `distributed` | `standalone` |
| `replicaCount` | Number of WordPress replicas | `1` |
| `image.repository` | WordPress image repository | `devopsbegins/wordpress` |
| `image.tag` | WordPress image tag | Chart appVersion |

### Database Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mysql.enabled` | Deploy MySQL subchart | `true` |
| `mysql.auth.password` | MySQL user password | `""` (required) |
| `mysql.auth.rootPassword` | MySQL root password | `""` (required) |
| `externalDatabase.host` | External MySQL host | `""` |
| `externalDatabase.password` | External MySQL password | `""` |

### Redis Configuration (Distributed Mode)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `redis.enabled` | Deploy Redis subchart | `false` |
| `externalRedis.host` | External Redis host | `""` |
| `externalRedis.database` | Redis DB for object cache | `0` |
| `externalRedis.sessionDatabase` | Redis DB for sessions | `1` |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistence | `true` |
| `persistence.storageClass` | StorageClass name | `""` (default) |
| `persistence.size` | PVC size | `10Gi` |
| `persistence.accessModes` | PVC access modes | `[ReadWriteOnce]` |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.hosts[].host` | Hostname | `wordpress.local` |
| `ingress.tls` | TLS configuration | `[]` |

### Health Checks

| Parameter | Description | Default |
|-----------|-------------|---------|
| `healthCheck.liveness.enabled` | Enable liveness probe | `true` |
| `healthCheck.readiness.enabled` | Enable readiness probe | `true` |
| `healthCheck.startup.enabled` | Enable startup probe | `true` |

## Deployment Modes

### Standalone Mode

- Single WordPress replica
- MySQL subchart (or external)
- File-based PHP sessions
- `ReadWriteOnce` storage
- Ideal for development/testing

```yaml
mode: standalone
replicaCount: 1
redis:
  enabled: false
```

### Distributed Mode

- Multiple WordPress replicas (minimum 2)
- Redis for session persistence and object cache
- `ReadWriteMany` storage required
- Automatic rolling updates
- Optional HPA for auto-scaling

```yaml
mode: distributed
replicaCount: 2
redis:
  enabled: true
autoscaling:
  enabled: true
```

## Health Check Endpoint

The chart deploys a custom health check endpoint at `/health.php` that validates:

- WordPress installation (wp-config.php exists)
- MySQL connectivity
- Redis connectivity (distributed mode only)

Example response:

```json
{
  "status": "healthy",
  "checks": {
    "wordpress": true,
    "mysql": true,
    "redis": true
  },
  "mode": "distributed",
  "timestamp": "2025-12-12T10:00:00+00:00"
}
```

## Upgrading

```bash
# Update dependencies
helm dependency update

# Upgrade release
helm upgrade wordpress . -f your-values.yaml
```

## Uninstalling

```bash
helm uninstall wordpress

# Optionally delete PVCs
kubectl delete pvc -l app.kubernetes.io/instance=wordpress
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l app.kubernetes.io/instance=wordpress
kubectl describe pod <pod-name>
```

### View Logs

```bash
kubectl logs -l app.kubernetes.io/instance=wordpress -f
```

### Test Health Endpoint

```bash
kubectl exec deploy/wordpress -- curl -s localhost/health.php | jq
```

### Validate Configuration

```bash
# Dry-run installation
helm install wordpress . --dry-run --debug

# Template rendering
helm template wordpress .
```

## Architecture

### Standalone Mode

```
┌─────────────────┐     ┌─────────────────┐
│   WordPress     │────▶│     MySQL       │
│   (1 replica)   │     │   (subchart)    │
└─────────────────┘     └─────────────────┘
        │
        ▼
┌─────────────────┐
│  PVC (RWO)      │
│  wp-content     │
└─────────────────┘
```

### Distributed Mode

```
                    ┌─────────────────┐
               ┌───▶│  WordPress #1   │───┐
┌──────────┐   │    └─────────────────┘   │    ┌─────────────────┐
│ Service  │───┤                          ├───▶│     MySQL       │
└──────────┘   │    ┌─────────────────┐   │    └─────────────────┘
               └───▶│  WordPress #2   │───┤
                    └─────────────────┘   │    ┌─────────────────┐
                            │             └───▶│     Redis       │
                            ▼                  └─────────────────┘
                    ┌─────────────────┐
                    │  PVC (RWX)      │
                    │  wp-content     │
                    └─────────────────┘
```

## License

This chart is part of the DevOpsBegins project and is released under the MIT License.
