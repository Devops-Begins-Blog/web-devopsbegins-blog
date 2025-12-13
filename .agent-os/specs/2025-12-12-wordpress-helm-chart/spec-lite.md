# Spec Summary (Lite)

Implement a cloud-agnostic Helm chart for WordPress with standalone and distributed deployment modes. Standalone mode deploys a single WordPress replica with optional MySQL subchart. Distributed mode enables multiple replicas with Redis for session persistence. Both modes support external database/cache services and include Kubernetes health checks validating MySQL and Redis connectivity. Chart location: `helm-chart/wordpress/`.
