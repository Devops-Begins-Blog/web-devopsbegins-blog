# Technical Stack

## Application Layer

| Component | Technology | Version | Notes |
|-----------|------------|---------|-------|
| CMS | WordPress | 6.9 | Custom Dockerfile from source |
| Base Image | PHP-Apache | 8.2.29 | Official PHP image (Debian) |
| Web Server | Apache | 2.4 | Integrated with PHP (mod_php) |
| Database | MySQL | 8.0 | Official MySQL image |
| Container Runtime | Docker | Latest stable | |
| Container Orchestration | Docker Compose | v2+ | |
| Future Orchestration | Kubernetes | TBD | |

## WordPress Custom Image

Building WordPress from source (not using Bitnami or pre-packaged images):

| Layer | Technology |
|-------|------------|
| Base | php:8.2.29-apache (Debian Bookworm) |
| WordPress Source | Downloaded from wordpress.org (SHA1 verified) |
| PHP Extensions | mysqli, gd, zip, exif, intl, opcache, imagick |
| Web Server | Apache with mod_rewrite |

## Backup System

| Component | Technology | Version |
|-----------|------------|---------|
| Language | Python | 3.12+ |
| Database Driver | mysql-connector-python | Latest |
| AWS SDK | boto3 | Latest |
| GCP SDK | google-cloud-storage | Latest |
| Google Drive SDK | google-api-python-client | Latest |
| Configuration | python-dotenv | Latest |

## Storage Adapters

| Adapter | Provider | Use Case |
|---------|----------|----------|
| LocalAdapter | Local filesystem | Development and testing |
| S3Adapter | AWS S3 | Production storage option |
| GCSAdapter | Google Cloud Storage | Production storage option |
| DriveAdapter | Google Drive | Alternative cloud storage |

## Infrastructure

| Component | Technology |
|-----------|------------|
| Application Hosting | Self-managed (Docker host) |
| Future Hosting | Google Kubernetes Engine (GKE) |
| Domain | blog.devopsbegins.com |
| Database Hosting | MySQL container (local) / Cloud SQL (production) |
| Asset Storage | wp-content volume |
| Backup Storage | Configurable (Local/S3/GCS/Drive) |

## Development Tools

| Tool | Purpose |
|------|---------|
| Docker Compose | Local development environment |
| Git | Version control |
| Python venv | Backup job dependencies isolation |

## Configuration Management

| Item | Method |
|------|--------|
| WordPress Config | Environment variables via Docker |
| MySQL Config | Environment variables via Docker |
| Backup Config | Environment variables / .env file |
| Retention Policy | Configurable via environment |
| Storage Selection | Adapter pattern with config |

## Security Considerations

| Area | Approach |
|------|----------|
| Database Credentials | Environment variables (not in code) |
| WordPress Salts | Generated unique per deployment |
| Backup Encryption | TBD (future enhancement) |
| Network | Internal Docker network for DB |
| Cloud Credentials | Service accounts / IAM roles |

## Repository Structure

```
web-devopsbegins-blog/
├── .agent-os/
│   └── product/           # Product documentation
├── docs/                  # Technical documentation
├── docker-image/
│   └── wordpress/
│       ├── Dockerfile     # Custom WordPress image
│       └── files/
│           ├── opcache.ini
│           ├── php-wordpress.ini
│           ├── wp-config.php
│           └── entrypoint.sh
├── docker-compose.yml     # Container orchestration
├── backup/
│   ├── src/               # Python backup job
│   │   ├── adapters/      # Storage adapters
│   │   └── ...
│   ├── requirements.txt
│   └── Dockerfile
└── volumes/               # Docker managed volumes
    ├── wp-content/        # WordPress assets
    └── mysql-data/        # MySQL data
```
