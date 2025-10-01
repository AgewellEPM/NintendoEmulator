# 🚀 Nintendo Emulator - Production Deployment Guide

**Last Updated:** September 30, 2025
**Deployment Status:** ✅ Ready for Production

---

## 📋 Overview

This guide covers deploying the Nintendo Emulator backend infrastructure to production using Docker containers with nginx reverse proxy and SSL/TLS encryption.

### Architecture

```
                                    ┌─────────────────┐
                                    │   Client App    │
                                    │  (macOS Swift)  │
                                    └────────┬────────┘
                                             │
                                             │ HTTPS
                                             ▼
                                    ┌─────────────────┐
                                    │  Nginx (Port    │
                                    │  80/443)        │
                                    │  - SSL/TLS      │
                                    │  - Rate Limit   │
                                    │  - Load Balance │
                                    └────────┬────────┘
                                             │
                        ┌────────────────────┴────────────────────┐
                        │                                         │
                        ▼                                         ▼
               ┌─────────────────┐                      ┌─────────────────┐
               │  OAuth Proxy    │                      │  Auth Service   │
               │  (Port 3000)    │                      │  (Port 3001)    │
               │  - 6 Platforms  │                      │  - Argon2id     │
               │  - Token Mgmt   │                      │  - JWT Tokens   │
               └─────────────────┘                      └─────────────────┘
```

---

## 🛠️ Prerequisites

### System Requirements

- **OS:** Linux (Ubuntu 20.04+ recommended) or macOS
- **RAM:** 2GB minimum, 4GB recommended
- **Disk:** 10GB available
- **Network:** Public IP or domain name

### Software Requirements

1. **Docker** (20.10+)
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   ```

2. **Docker Compose** (v2.0+)
   ```bash
   sudo apt-get install docker-compose-plugin
   ```

3. **Git**
   ```bash
   sudo apt-get install git
   ```

---

## 📦 Installation

### Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/nintendo-emulator.git
cd nintendo-emulator/backend
```

### Step 2: Configure Environment Variables

```bash
# Copy example environment file
cp .env.example .env

# Edit with your OAuth credentials
nano .env
```

**Required Variables:**

```env
# OAuth Proxy Configuration
OAUTH_PORT=3000
TWITCH_CLIENT_ID=your_twitch_client_id
TWITCH_CLIENT_SECRET=your_twitch_client_secret
YOUTUBE_CLIENT_ID=your_youtube_client_id
YOUTUBE_CLIENT_SECRET=your_youtube_client_secret
DISCORD_CLIENT_ID=your_discord_client_id
DISCORD_CLIENT_SECRET=your_discord_client_secret
TWITTER_CLIENT_ID=your_twitter_client_id
TWITTER_CLIENT_SECRET=your_twitter_client_secret
INSTAGRAM_CLIENT_ID=your_instagram_client_id
INSTAGRAM_CLIENT_SECRET=your_instagram_client_secret
TIKTOK_CLIENT_KEY=your_tiktok_client_key
TIKTOK_CLIENT_SECRET=your_tiktok_client_secret

# Auth Service Configuration
AUTH_PORT=3001
JWT_SECRET=your_secure_random_jwt_secret_here

# CORS Configuration
ALLOWED_ORIGIN=https://nintendoemulator.app
```

**Generate JWT Secret:**
```bash
openssl rand -base64 32
```

### Step 3: SSL Certificate Setup

#### Option A: Let's Encrypt (Production)

```bash
# Install certbot
sudo apt-get install certbot

# Get certificate
sudo certbot certonly --standalone -d api.nintendoemulator.app

# Copy certificates
sudo mkdir -p ssl
sudo cp /etc/letsencrypt/live/api.nintendoemulator.app/fullchain.pem ssl/
sudo cp /etc/letsencrypt/live/api.nintendoemulator.app/privkey.pem ssl/
sudo chmod 644 ssl/*
```

#### Option B: Self-Signed (Development)

```bash
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/privkey.pem \
  -out ssl/fullchain.pem \
  -subj "/C=US/ST=State/L=City/O=Org/CN=api.nintendoemulator.app"
```

### Step 4: Deploy

```bash
# Run deployment script
./deploy.sh deploy
```

This will:
1. ✅ Check prerequisites
2. ✅ Build Docker images
3. ✅ Start all services
4. ✅ Run health checks
5. ✅ Display service status

---

## 🎯 Deployment Options

### Quick Deploy (Automated)

```bash
./deploy.sh deploy
```

### Manual Deploy

```bash
# Build images
docker compose build

# Start services
docker compose up -d

# Check status
docker compose ps
```

### Deploy to Cloud Providers

#### AWS EC2

1. Launch Ubuntu 20.04 instance (t2.small or larger)
2. Configure security groups (ports 80, 443)
3. SSH into instance
4. Follow installation steps above

#### DigitalOcean

1. Create Droplet (Ubuntu 20.04, 2GB RAM)
2. Add domain DNS A record → Droplet IP
3. SSH into droplet
4. Follow installation steps above

#### Google Cloud

```bash
# Create VM
gcloud compute instances create nintendo-backend \
  --image-family=ubuntu-2004-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=e2-small \
  --zone=us-central1-a

# SSH
gcloud compute ssh nintendo-backend
```

---

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `OAUTH_PORT` | OAuth proxy port | No | 3000 |
| `AUTH_PORT` | Auth service port | No | 3001 |
| `JWT_SECRET` | JWT signing key | Yes | - |
| `ALLOWED_ORIGIN` | CORS origin | Yes | - |
| `TWITCH_CLIENT_ID` | Twitch OAuth client ID | Yes | - |
| `TWITCH_CLIENT_SECRET` | Twitch OAuth secret | Yes | - |

### Nginx Configuration

Edit `nginx.conf` to customize:

- **Rate Limiting:**
  ```nginx
  limit_req_zone $binary_remote_addr zone=oauth_limit:10m rate=10r/s;
  ```

- **SSL Settings:**
  ```nginx
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:...';
  ```

- **Upstream Servers:**
  ```nginx
  upstream oauth_proxy {
      server oauth-proxy:3000;
      keepalive 32;
  }
  ```

---

## 📊 Monitoring

### Service Health Checks

```bash
# OAuth proxy
curl http://localhost:3000/health
# Response: {"status":"ok","service":"oauth-proxy"}

# Auth service
curl http://localhost:3001/health
# Response: {"status":"ok","service":"auth-service","users":0}

# Nginx
curl http://localhost/health
# Response: OK
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f oauth-proxy
docker compose logs -f auth-service
docker compose logs -f nginx
```

### Container Status

```bash
# List containers
docker compose ps

# Resource usage
docker stats

# Inspect container
docker inspect nintendo-oauth-proxy
```

---

## 🔐 Security

### SSL/TLS

- **Protocols:** TLS 1.2, TLS 1.3
- **Ciphers:** Mozilla Intermediate profile
- **HSTS:** Enabled (6 months)
- **Certificate Pinning:** Enabled in client app

### Rate Limiting

- **OAuth endpoints:** 10 req/s with burst of 20
- **Auth endpoints:** 5 req/s with burst of 10
- **General:** 30 req/s

### Security Headers

```nginx
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=15768000
```

### Container Security

- Non-root user (UID 1001)
- Read-only filesystem where possible
- Security updates via Alpine base image
- No unnecessary capabilities

---

## 🚦 Operations

### Start Services

```bash
./deploy.sh deploy
# or
docker compose up -d
```

### Stop Services

```bash
./deploy.sh stop
# or
docker compose down
```

### Restart Services

```bash
./deploy.sh restart
# or
docker compose restart
```

### Update Deployment

```bash
# Pull latest code
git pull origin main

# Rebuild and restart
docker compose up -d --build
```

### Rollback

```bash
# Stop current deployment
docker compose down

# Checkout previous version
git checkout <previous-commit>

# Redeploy
./deploy.sh deploy
```

---

## 🧪 Testing

### OAuth Flow Testing

```bash
# Test Twitch token exchange
curl -X POST http://localhost:3000/oauth/twitch/exchange \
  -H "Content-Type: application/json" \
  -d '{
    "code": "test_authorization_code",
    "redirect_uri": "http://localhost/callback"
  }'
```

### Authentication Testing

```bash
# Register user
curl -X POST http://localhost:3001/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePassword123!",
    "username": "testuser"
  }'

# Sign in
curl -X POST http://localhost:3001/auth/signin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePassword123!"
  }'
```

### Load Testing

```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Test 1000 requests with 10 concurrent
ab -n 1000 -c 10 http://localhost:3000/health
```

---

## 📈 Scaling

### Horizontal Scaling

```yaml
# docker-compose.yml
services:
  oauth-proxy:
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### Load Balancer

```nginx
# nginx.conf
upstream oauth_proxy {
    least_conn;  # or ip_hash for sticky sessions
    server oauth-proxy-1:3000;
    server oauth-proxy-2:3000;
    server oauth-proxy-3:3000;
}
```

### Database Integration

Replace in-memory storage:

```javascript
// auth-service.js
const { Pool } = require('pg');
const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  database: 'nintendo_emulator',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD
});
```

---

## 🐛 Troubleshooting

### Service Won't Start

```bash
# Check logs
docker compose logs oauth-proxy

# Common issues:
# 1. Port already in use
sudo lsof -i :3000
# 2. Missing environment variables
cat .env | grep CLIENT_SECRET
# 3. Permissions
sudo chown -R $USER:$USER .
```

### SSL Certificate Issues

```bash
# Verify certificate
openssl x509 -in ssl/fullchain.pem -text -noout

# Check expiry
openssl x509 -enddate -noout -in ssl/fullchain.pem

# Renew Let's Encrypt
sudo certbot renew
```

### High Memory Usage

```bash
# Check memory
docker stats

# Limit container memory
docker compose up -d --build \
  --scale oauth-proxy=1 \
  -m 512m
```

### Database Connection Fails

```bash
# Test connection
docker exec -it nintendo-auth-service \
  node -e "console.log(process.env.DB_HOST)"

# Check network
docker network inspect nintendo-network
```

---

## 🔄 Maintenance

### Certificate Renewal

```bash
# Renew Let's Encrypt (runs automatically)
sudo certbot renew

# Copy new certs
sudo cp /etc/letsencrypt/live/api.nintendoemulator.app/*.pem ssl/

# Reload nginx
docker compose restart nginx
```

### Log Rotation

```bash
# Configure in docker-compose.yml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### Backup

```bash
# Backup environment
tar -czf backup-$(date +%Y%m%d).tar.gz \
  .env ssl/ docker-compose.yml

# Backup database (if using)
docker exec nintendo-db \
  pg_dump -U postgres nintendo_emulator > backup.sql
```

---

## 📞 Support

### Health Check Endpoints

- OAuth Proxy: `http://localhost:3000/health`
- Auth Service: `http://localhost:3001/health`
- Nginx: `http://localhost/health`

### Logs Location

- **OAuth Proxy:** `docker compose logs oauth-proxy`
- **Auth Service:** `docker compose logs auth-service`
- **Nginx:** `./logs/nginx/access.log` and `./logs/nginx/error.log`

### Emergency Contacts

- **Security Issues:** security@nintendoemulator.app
- **Downtime:** ops@nintendoemulator.app

---

## ✅ Production Checklist

### Pre-Deployment

- [ ] All environment variables set in `.env`
- [ ] SSL certificates obtained (Let's Encrypt)
- [ ] Domain DNS configured
- [ ] Firewall rules set (ports 80, 443)
- [ ] JWT secret generated (32+ characters)
- [ ] OAuth credentials from all 6 platforms
- [ ] Backup plan created

### Post-Deployment

- [ ] Health checks passing for all services
- [ ] SSL certificate valid (check in browser)
- [ ] OAuth flow tested with real credentials
- [ ] User registration/login tested
- [ ] Rate limiting verified
- [ ] Logs reviewed for errors
- [ ] Monitoring alerts configured
- [ ] Documentation updated

### Week 1

- [ ] Daily log review
- [ ] Monitor error rates
- [ ] Check certificate expiry (90 days for Let's Encrypt)
- [ ] Review resource usage
- [ ] Test backup restoration

---

## 🎯 Performance Benchmarks

### Expected Performance

| Metric | Target | Measurement |
|--------|--------|-------------|
| OAuth token exchange | < 500ms | `ab -n 100 -c 10` |
| User registration | < 200ms | Argon2id hashing |
| User login | < 200ms | Database query + JWT |
| Health check | < 10ms | Simple status response |
| Concurrent users | 1000+ | With 2GB RAM |

### Monitoring Metrics

```bash
# Response time
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:3000/health

# Throughput
ab -n 10000 -c 100 http://localhost:3000/health | grep "Requests per second"
```

---

## 🚀 Next Steps

1. **Deploy to staging** environment first
2. **Run load tests** with expected production traffic
3. **Set up monitoring** (Prometheus, Grafana, Datadog)
4. **Configure backups** (automated daily)
5. **Plan scaling strategy** based on user growth
6. **Set up CI/CD** for automated deployments
7. **Create runbook** for common operations

---

**Deployment Ready! 🎮🔒**

Built with security, scalability, and reliability in mind.