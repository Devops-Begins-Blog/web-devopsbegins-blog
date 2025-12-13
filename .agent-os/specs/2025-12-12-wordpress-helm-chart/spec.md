# Spec Requirements Document

> Spec: WordPress Helm Chart
> Created: 2025-12-12

## Overview

Implement a Helm chart for WordPress supporting two deployment modes (standalone and distributed/HA) on Kubernetes, with optional MySQL and Redis dependencies, robust health checks, and cloud-agnostic configuration. This chart will document the migration path from Docker Compose to Kubernetes as educational content for DevOpsBegins.

## User Stories

### Standalone Deployment for Development

As a developer, I want to deploy WordPress in standalone mode with a single command, so that I can quickly set up a development environment in Kubernetes.

The developer runs `helm install` with default or minimal values. The chart deploys a single WordPress pod with MySQL included (subchart) or connection to external MySQL. The result is a functional WordPress accessible via Service/Ingress without requiring Redis or high availability.

### Distributed Deployment for Production

As a platform engineer, I want to deploy WordPress in distributed/HA mode, so that the application can handle production traffic with session persistence and horizontal scaling.

The engineer configures `mode: distributed` in values.yaml. The chart deploys multiple WordPress replicas with Redis for sessions and object cache (subchart or external). Sessions persist across pods and traffic is automatically distributed via the Kubernetes Service.

### Connection to External Services

As a cloud architect, I want to connect WordPress to external MySQL and Redis services, so that I can use managed database services like Cloud SQL or Memorystore.

The architect disables MySQL/Redis subcharts and configures external hosts in values.yaml. WordPress connects to external services using provided credentials. Health checks validate connectivity before marking the pod as ready.

## Spec Scope

1. **Helm Chart Base** - Chart structure with templates for Deployment, Service, ConfigMap, Secrets, and configurable values
2. **Standalone Mode** - Single-replica deployment with MySQL as optional dependency (Bitnami subchart or external)
3. **Distributed Mode** - Multi-replica deployment with Redis for sessions, MySQL as dependency, and optional HPA configuration
4. **Health Checks** - Liveness and readiness probes validating WordPress, MySQL connection, and Redis (when applicable)
5. **Optional Ingress** - Configurable Ingress resource with TLS support and customizable annotations

## Out of Scope

- Nginx as internal load balancer (Kubernetes Service handles load balancing)
- Cloud provider-specific configuration (GKE, EKS, AKS)
- Automatic TLS certificates (cert-manager) - manual secret configuration only
- Automated volume backups (future phase)
- Prometheus monitoring and metrics (future phase)
- NFS StorageClass creation (documented as prerequisite)

## Expected Deliverable

1. Functional Helm chart in `helm-chart/wordpress/` enabling WordPress deployment in standalone mode with `helm install wordpress ./helm-chart/wordpress`
2. Functional distributed mode with `helm install wordpress ./helm-chart/wordpress --set mode=distributed --set replicaCount=2`
3. Health checks validating MySQL and Redis connectivity, visible with `kubectl describe pod` showing passing probes
