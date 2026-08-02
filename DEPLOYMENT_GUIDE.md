# Nayo Deployment Guide

Step-by-step guide for deploying the Nayo loyalty platform in
development, staging, and production environments.

---

## Table of Contents

1. [Deployment Options](#deployment-options)
2. [Prerequisites](#prerequisites)
3. [Docker Compose Deployment](#docker-compose-deployment)
4. [Kubernetes Deployment](#kubernetes-deployment)
5. [Environment Variables](#environment-variables)
6. [SSL/TLS Configuration](#ssltls-configuration)
7. [Database Setup](#database-setup)
8. [First-Time Setup](#first-time-setup)
9. [Odoo Integration Deployment](#odoo-integration-deployment)
10. [Monitoring and Logging](#monitoring-and-logging)
11. [Backup and Recovery](#backup-and-recovery)
12. [Scaling](#scaling)
13. [CI/CD Pipeline](#cicd-pipeline)
14. [Production Checklist](#production-checklist)

---

## Deployment Options

| Option | Best For | Complexity |
|---|---|---|
| **Docker Compose** | Development, small production, single-server | Low |
| **Kubernetes** | Production, multi-tenant, high-traffic | High |
| **Bare Metal** | Maximum control, air-gapped environments | High |

---

## Prerequisites

### Server Requirements

| Component | Minimum | Recommended (Production) |
|---|---|---|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Disk | 20 GB | 50+ GB SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

### Software Requirements

- Docker 24+ and Docker Compose v2
- For Kubernetes: kubectl, Helm 3, cluster access
- Domain name with DNS configured
- SSL certificate (Let's Encrypt or commercial)

### Network Ports

| Port | Service | External Access |
|---|---|---|
| 80 | HTTP (redirect to HTTPS) | Yes |
| 443 | HTTPS | Yes |
| 5432 | PostgreSQL | No (internal only) |
| 9200 | Elasticsearch | No (internal only) |

---

## Docker Compose Deployment

### Step 1: Prepare the Server

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt install docker-compose-plugin -y

# Verify
docker --version
docker compose version
```

### Step 2: Clone and Configure

```bash
git clone https://github.com/iamtutumo/OpenLoyalty.git nayo
cd nayo

# Create production environment file
cp docker/.env docker/.env.production
```

### Step 3: Configure Environment Variables

Edit `docker/.env.production`:

```env
# Database
POSTGRES_DB=nayo
POSTGRES_USER=nayo
POSTGRES_PASSWORD=<strong-random-password>

# Application
APP_DB_HOST=db
APP_DB_PORT=5432
APP_DB_USER=nayo
APP_DB_PASSWORD=<same-as-above>
APP_DB_NAME=nayo

# Elasticsearch
ELK_HOST=elk

# Application URLs
ADMIN_URL=https://admin.yourdomain.com/
CUSTOMER_URL=https://customer.yourdomain.com/
MERCHANT_URL=https://merchant.yourdomain.com/

# Mail (SMTP)
MAILER_HOST=smtp.yourdomain.com
MAILER_PORT=587
MAILER_USER=noreply@yourdomain.com
MAILER_PASSWORD=<smtp-password>
MAILER_FROM=noreply@yourdomain.com
```

### Step 4: Build and Start

```bash
# Using the Makefile
make setup

# Or directly with Docker Compose
cd docker
docker compose -f docker-compose.yml --env-file .env.production up -d

# Wait for services to start, then initialize
docker compose exec -T php phing setup
docker compose exec -T php phing generate-jwt-keys
docker compose exec -T php bin/console cache:clear
```

### Step 5: Verify Deployment

```bash
# Check container status
docker compose ps

# Check API health
curl http://localhost/api/healthcheck

# Check admin panel
curl -I http://localhost:8182
```

---

## Kubernetes Deployment

### Step 1: Review Kubernetes Manifests

The `kubernetes/` directory contains:
- `deployment.yml` — Pod and service definitions
- `config.yml` — ConfigMaps and Secrets
- `storage.yml` — Persistent volume claims
- `claims.yml` — Resource claims

### Step 2: Configure Secrets

```bash
# Create namespace
kubectl create namespace nayo

# Create secrets
kubectl create secret generic nayo-db-credentials \
  --from-literal=username=nayo \
  --from-literal=password=<strong-password> \
  -n nayo

kubectl create secret generic nayo-jwt-keys \
  --from-file=private.pem=./jwt/private.pem \
  --from-file=public.pem=./jwt/public.pem \
  -n nayo
```

### Step 3: Deploy

```bash
# Apply storage first
kubectl apply -f kubernetes/storage.yml -n nayo

# Apply config
kubectl apply -f kubernetes/config.yml -n nayo

# Apply deployments
kubectl apply -f kubernetes/deployment.yml -n nayo

# Verify
kubectl get pods -n nayo
kubectl get services -n nayo
```

### Step 4: Configure Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nayo-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
spec:
  tls:
    - hosts:
        - api.nayo.yourdomain.com
        - admin.nayo.yourdomain.com
      secretName: nayo-tls
  rules:
    - host: api.nayo.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nayo-nginx
                port:
                  number: 80
    - host: admin.nayo.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nayo-nginx
                port:
                  number: 8182
```

---

## Environment Variables

### Required Variables

| Variable | Description | Example |
|---|---|---|
| `POSTGRES_DB` | Database name | `nayo` |
| `POSTGRES_USER` | Database user | `nayo` |
| `POSTGRES_PASSWORD` | Database password | (strong random) |
| `APP_DB_HOST` | Database host | `db` (Docker) or RDS endpoint |
| `ADMIN_URL` | Admin panel URL | `https://admin.nayo.com/` |
| `CUSTOMER_URL` | Customer panel URL | `https://customer.nayo.com/` |
| `MERCHANT_URL` | Merchant panel URL | `https://merchant.nayo.com/` |

### Optional Variables

| Variable | Description | Default |
|---|---|---|
| `MAILER_HOST` | SMTP server | `mail` |
| `MAILER_PORT` | SMTP port | `1025` |
| `MAILER_USER` | SMTP username | (empty) |
| `MAILER_PASSWORD` | SMTP password | (empty) |
| `JWT_TOKEN_TTL` | JWT token lifetime (seconds) | `86400` |
| `PAGINATION_PER_PAGE` | Default page size | `10` |
| `MASTER_API_KEY` | Master API key | (empty) |

---

## SSL/TLS Configuration

### Option 1: Nginx with Let's Encrypt

Create `docker/nginx/ssl.conf`:

```nginx
server {
    listen 80;
    server_name api.nayo.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.nayo.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/nayo.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nayo.yourdomain.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://nayo_backend:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Option 2: Let's Encrypt with Certbot

```bash
# Install certbot
sudo apt install certbot -y

# Get certificate (stop nginx first)
sudo certbot certonly --standalone -d nayo.yourdomain.com

# Renew automatically
sudo certbot renew --dry-run
```

---

## Database Setup

### New Installation

```bash
# Via Docker
docker compose exec -T php phing setup

# Via Makefile
make setup
```

### Migration from Existing System

```bash
# 1. Export from source
pg_dump -U old_user old_db > backup.sql

# 2. Import to Nayo
docker compose exec -T db psql -U nayo -d nayo < backup.sql

# 3. Run migrations
docker compose exec -T php bin/console doctrine:migrations:migrate -n

# 4. Rebuild search indexes
docker compose exec -T php bin/console oloy:user:projections:index:create --drop-old
```

### External Database (AWS RDS, etc.)

Update `docker/.env.production`:

```env
APP_DB_HOST=your-rds-endpoint.amazonaws.com
APP_DB_PORT=5432
APP_DB_USER=nayo
APP_DB_PASSWORD=<password>
APP_DB_NAME=nayo
```

Remove the `db` service from `docker-compose.yml` and restart.

---

## First-Time Setup

```bash
# 1. Start services
make run

# 2. Initialize database
make install

# 3. Generate JWT keys
make jwt-keys

# 4. Add hosts entry (development)
make update-hosts

# 5. Access admin panel
# URL: http://nayo.localhost:8182
# Login: admin / open

# 6. Change default password immediately!
# Navigate to: Admin > Profile > Change Password

# 7. Configure settings
# Navigate to: Settings
# Set: Currency (UGX), Timezone (Africa/Nairobi), Language (en)

# 8. Create earning rules
# Navigate to: Earning Rules > Create New

# 9. Create rewards (optional)
# Navigate to: Rewards > Create New

# 10. Create tiers (optional)
# Navigate to: Tiers > Create New
```

---

## Odoo Integration Deployment

### Deploying Nayo as Odoo's Loyalty Backend

```
                    Internet
                       |
                 Load Balancer
                  /           \
         +-----------+    +-----------+
         |  Odoo     |    |   Nayo    |
         |  Server   |    |   Server  |
         +-----------+    +-----------+
              |                  |
              +------ Internal Network ------+
              |                              |
         +----v----+                  +------v-----+
         |  Odoo   |                  |  Nayo      |
         |  DB     |                  |  DB        |
         +---------+                  +------------+
```

### Network Configuration

1. Place both servers on the same private network (VPC)
2. Allow Odoo server to reach Nayo API on port 80/443
3. Block external access to Nayo database (port 5432)

### Firewall Rules (UFW)

```bash
# On Nayo server
sudo ufw allow from <odoo-server-ip> to any port 443
sudo ufw allow from <odoo-server-ip> to any port 80
sudo ufw deny 5432   # Block external DB access
sudo ufw enable
```

### Odoo Configuration

In Odoo, set system parameters:

| Key | Value |
|---|---|
| `nayo.api_url` | `http://nayo-server-ip` or `https://nayo.yourdomain.com` |
| `nayo.api_key` | Nayo admin API token |
| `nayo.enabled` | `true` |

Test connection from Odoo shell:

```python
import requests
url = env['ir.config_parameter'].sudo().get_param('nayo.api_url')
resp = requests.get(f"{url}/api/healthcheck", timeout=5)
print(f"Nayo status: {resp.status_code}")
```

---

## Monitoring and Logging

### Health Checks

```bash
# API health
curl http://nayo.localhost/api/healthcheck

# Database health
docker compose exec db pg_isready -U nayo

# Elasticsearch health
curl http://elk:9200/_cluster/health?pretty
```

### Log Aggregation

#### Docker Logs

```bash
# All services
docker compose logs -f --tail=100

# Specific service
docker compose logs -f php
docker compose logs -f nginx
docker compose logs -f db
```

#### File-Based Logging

```bash
# Symfony application logs
docker compose exec php cat var/logs/prod.log
docker compose exec php tail -f var/logs/prod.log
```

### Metrics with Prometheus

Add to `docker-compose.yml`:

```yaml
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

---

## Backup and Recovery

### Automated Database Backups

```bash
# Create backup script
cat > /opt/nayo/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/nayo/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Dump database
docker compose exec -T db pg_dump -U nayo nayo | gzip > $BACKUP_DIR/nayo_${TIMESTAMP}.sql.gz

# Keep only last 30 backups
ls -t $BACKUP_DIR/*.sql.gz | tail -n +31 | xargs rm -f

echo "Backup completed: nayo_${TIMESTAMP}.sql.gz"
EOF

chmod +x /opt/nayo/backup.sh

# Schedule daily backup at 2 AM
echo "0 2 * * * /opt/nayo/backup.sh >> /var/log/nayo-backup.log 2>&1" | crontab -
```

### Restore from Backup

```bash
# Via Makefile
make restore BACKUP_FILE=backups/nayo_20260802_020000.sql.gz

# Or manually
gunzip -c backups/nayo_20260802_020000.sql.gz | \
  docker compose exec -T db psql -U nayo -d nayo

# Rebuild indexes after restore
docker compose exec -T php bin/console oloy:user:projections:index:create --drop-old
```

---

## Scaling

### Horizontal Scaling (Multiple PHP Instances)

```yaml
# docker-compose.prod.yml
services:
  php:
    image: nayo-php:latest
    deploy:
      replicas: 3
    depends_on:
      - db
      - elk

  nginx:
    image: nginx:alpine
    depends_on:
      - php
    # Nginx will load-balance across PHP replicas
```

### Vertical Scaling

| Load | PHP Workers | DB RAM | ES Heap |
|---|---|---|---|
| < 1,000 members | 2 | 1 GB | 512 MB |
| 1,000 - 10,000 | 4 | 2 GB | 1 GB |
| 10,000 - 50,000 | 8 | 4 GB | 2 GB |
| 50,000+ | 16+ | 8+ GB | 4+ GB |

### Database Read Replicas

For read-heavy workloads:

```yaml
  db:
    image: postgres:15
    # Primary (read-write)

  db-replica:
    image: postgres:15
    # Read-only replica for analytics queries
```

---

## CI/CD Pipeline

### GitHub Actions

```yaml
name: Deploy Nayo

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker images
        run: |
          docker build -t nayo-php:${{ github.sha }} -f docker/dev/php/fpm-dockerfile .
          docker tag nayo-php:${{ github.sha }} ghcr.io/iamtutumo/nayo-php:${{ github.sha }}

      - name: Push to registry
        run: |
          echo "${{ secrets.GHCR_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
          docker push ghcr.io/iamtutumo/nayo-php:${{ github.sha }}

      - name: Deploy to server
        run: |
          ssh ${{ secrets.DEPLOY_USER }}@${{ secrets.DEPLOY_HOST }} << 'EOF'
            cd /opt/nayo
            docker compose pull
            docker compose up -d
            docker compose exec -T php bin/console cache:clear
          EOF
```

### GitLab CI

The existing `.gitlab-ci.yml` can be extended with deployment stages:

```yaml
deploy:production:
  stage: deploy
  only:
    - main
  script:
    - docker compose -f docker/docker-compose.prod.yml pull
    - docker compose -f docker/docker-compose.prod.yml up -d
    - docker compose exec -T php bin/console cache:clear
  environment:
    name: production
    url: https://nayo.yourdomain.com
```

---

## Production Checklist

Before going live, verify all items:

### Security

- [ ] Default admin password changed
- [ ] JWT keys generated (not using defaults)
- [ ] Database password is strong (32+ characters)
- [ ] HTTPS enabled on all endpoints
- [ ] External database access blocked
- [ ] MailHog disabled / replaced with real SMTP
- [ ] Debug mode disabled (`APP_ENV=prod`)
- [ ] `.env` files excluded from version control
- [ ] API keys rotated and stored securely
- [ ] CORS configured to allow only trusted origins

### Performance

- [ ] Database indexes verified (run `QUICK_FIX.sql`)
- [ ] Elasticsearch health: green
- [ ] PHP opcache enabled
- [ ] Static assets served via CDN (optional)
- [ ] Database connection pooling configured
- [ ] Resource limits set on Docker containers

### Reliability

- [ ] Automated backups configured and tested
- [ ] Health checks responding correctly
- [ ] Log rotation configured
- [ ] Monitoring alerts set up
- [ ] Disaster recovery plan documented
- [ ] SSL certificate auto-renewal configured

### Odoo Integration

- [ ] Nayo API accessible from Odoo server
- [ ] API credentials stored as Odoo system parameters
- [ ] Initial bulk sync completed
- [ ] Automated sync actions configured
- [ ] Webhook endpoint tested
- [ ] POS integration tested (if applicable)
- [ ] eCommerce integration tested (if applicable)

### Functionality

- [ ] Member registration works
- [ ] Transaction recording works
- [ ] Points earning rules active and tested
- [ ] Reward redemption works
- [ ] Tier calculation correct
- [ ] Email notifications sending
- [ ] Admin panel accessible
- [ ] Customer panel accessible
- [ ] Merchant panel accessible
- [ ] API documentation accessible at `/doc`
