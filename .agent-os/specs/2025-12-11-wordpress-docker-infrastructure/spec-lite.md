# Spec Summary (Lite)

Deploy production-ready WordPress using Docker Compose with custom-built PHP 8.2 + Apache image and MySQL 8.0. Apache serves both static files and PHP processing in a single container for simplicity. All Docker assets (Dockerfiles, scripts, configs) are organized in `docker-image/` directory. Environment variables are configured directly in docker-compose.yml without external .env files.
