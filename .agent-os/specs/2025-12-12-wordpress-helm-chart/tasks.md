# Spec Tasks

## Tasks

- [x] 1. **Create Helm Chart Base Structure**
  - [x] 1.1 Create `helm-chart/wordpress/` directory structure
  - [x] 1.2 Create `Chart.yaml` with metadata and Bitnami dependencies (mysql, redis)
  - [x] 1.3 Create `values.yaml` with complete configuration schema
  - [x] 1.4 Create `templates/_helpers.tpl` with helper functions and validation logic
  - [x] 1.5 Create `templates/NOTES.txt` with post-install instructions
  - [x] 1.6 Verify chart structure with `helm lint`

- [x] 2. **Implement Health Check System**
  - [x] 2.1 Create `health.php` script with MySQL and Redis connectivity checks
  - [x] 2.2 Add health.php to WordPress Docker image or ConfigMap mount
  - [x] 2.3 Configure liveness, readiness, and startup probes in deployment template
  - [x] 2.4 Test health checks respond correctly for healthy/unhealthy states

- [x] 3. **Implement Core Kubernetes Resources**
  - [x] 3.1 Create `templates/configmap.yaml` for WordPress environment configuration
  - [x] 3.2 Create `templates/secret.yaml` for database and Redis credentials
  - [x] 3.3 Create `templates/pvc.yaml` for wp-content persistence
  - [x] 3.4 Create `templates/service.yaml` for WordPress service exposure
  - [x] 3.5 Create `templates/serviceaccount.yaml` (optional, conditional)
  - [x] 3.6 Verify resources render correctly with `helm template`

- [x] 4. **Implement WordPress Deployment**
  - [x] 4.1 Create `templates/deployment.yaml` with WordPress container spec
  - [x] 4.2 Implement mode-based logic (standalone vs distributed)
  - [x] 4.3 Configure environment variables from ConfigMap and Secrets
  - [x] 4.4 Mount wp-content PVC and health check script
  - [x] 4.5 Add pod security context and resource limits
  - [x] 4.6 Test standalone deployment with MySQL subchart

- [x] 5. **Implement Distributed Mode Features**
  - [x] 5.1 Add Redis configuration to deployment (session handler, object cache)
  - [x] 5.2 Implement validation for distributed mode requirements
  - [x] 5.3 Create `templates/hpa.yaml` for horizontal pod autoscaling
  - [x] 5.4 Test distributed deployment with Redis subchart
  - [x] 5.5 Verify session persistence across pods

- [x] 6. **Implement Optional Ingress**
  - [x] 6.1 Create `templates/ingress.yaml` with conditional rendering
  - [x] 6.2 Support TLS configuration and custom annotations
  - [x] 6.3 Test Ingress resource generation with various configurations

- [x] 7. **Create Example Values and Documentation**
  - [x] 7.1 Create `values-standalone.yaml` example configuration
  - [x] 7.2 Create `values-distributed.yaml` example configuration
  - [x] 7.3 Create `README.md` with installation instructions and prerequisites
  - [x] 7.4 Document StorageClass requirements for distributed mode
  - [x] 7.5 Add examples for external MySQL/Redis configuration

- [x] 8. **Final Validation and Testing**
  - [x] 8.1 Run `helm lint` on completed chart
  - [x] 8.2 Test `helm template` output for standalone mode
  - [x] 8.3 Test `helm template` output for distributed mode
  - [x] 8.4 Test installation in local Kubernetes (minikube/kind) if available
  - [x] 8.5 Verify all probes pass after deployment
