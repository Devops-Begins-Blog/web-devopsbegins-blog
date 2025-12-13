# Spec Tasks

## Tasks

- [ ] 1. **Create Helm Chart Base Structure**
  - [ ] 1.1 Create `helm-chart/wordpress/` directory structure
  - [ ] 1.2 Create `Chart.yaml` with metadata and Bitnami dependencies (mysql, redis)
  - [ ] 1.3 Create `values.yaml` with complete configuration schema
  - [ ] 1.4 Create `templates/_helpers.tpl` with helper functions and validation logic
  - [ ] 1.5 Create `templates/NOTES.txt` with post-install instructions
  - [ ] 1.6 Verify chart structure with `helm lint`

- [ ] 2. **Implement Health Check System**
  - [ ] 2.1 Create `health.php` script with MySQL and Redis connectivity checks
  - [ ] 2.2 Add health.php to WordPress Docker image or ConfigMap mount
  - [ ] 2.3 Configure liveness, readiness, and startup probes in deployment template
  - [ ] 2.4 Test health checks respond correctly for healthy/unhealthy states

- [ ] 3. **Implement Core Kubernetes Resources**
  - [ ] 3.1 Create `templates/configmap.yaml` for WordPress environment configuration
  - [ ] 3.2 Create `templates/secret.yaml` for database and Redis credentials
  - [ ] 3.3 Create `templates/pvc.yaml` for wp-content persistence
  - [ ] 3.4 Create `templates/service.yaml` for WordPress service exposure
  - [ ] 3.5 Create `templates/serviceaccount.yaml` (optional, conditional)
  - [ ] 3.6 Verify resources render correctly with `helm template`

- [ ] 4. **Implement WordPress Deployment**
  - [ ] 4.1 Create `templates/deployment.yaml` with WordPress container spec
  - [ ] 4.2 Implement mode-based logic (standalone vs distributed)
  - [ ] 4.3 Configure environment variables from ConfigMap and Secrets
  - [ ] 4.4 Mount wp-content PVC and health check script
  - [ ] 4.5 Add pod security context and resource limits
  - [ ] 4.6 Test standalone deployment with MySQL subchart

- [ ] 5. **Implement Distributed Mode Features**
  - [ ] 5.1 Add Redis configuration to deployment (session handler, object cache)
  - [ ] 5.2 Implement validation for distributed mode requirements
  - [ ] 5.3 Create `templates/hpa.yaml` for horizontal pod autoscaling
  - [ ] 5.4 Test distributed deployment with Redis subchart
  - [ ] 5.5 Verify session persistence across pods

- [ ] 6. **Implement Optional Ingress**
  - [ ] 6.1 Create `templates/ingress.yaml` with conditional rendering
  - [ ] 6.2 Support TLS configuration and custom annotations
  - [ ] 6.3 Test Ingress resource generation with various configurations

- [ ] 7. **Create Example Values and Documentation**
  - [ ] 7.1 Create `values-standalone.yaml` example configuration
  - [ ] 7.2 Create `values-distributed.yaml` example configuration
  - [ ] 7.3 Create `README.md` with installation instructions and prerequisites
  - [ ] 7.4 Document StorageClass requirements for distributed mode
  - [ ] 7.5 Add examples for external MySQL/Redis configuration

- [ ] 8. **Final Validation and Testing**
  - [ ] 8.1 Run `helm lint` on completed chart
  - [ ] 8.2 Test `helm template` output for standalone mode
  - [ ] 8.3 Test `helm template` output for distributed mode
  - [ ] 8.4 Test installation in local Kubernetes (minikube/kind) if available
  - [ ] 8.5 Verify all probes pass after deployment
