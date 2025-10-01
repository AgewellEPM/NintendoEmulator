# 🎮 Nintendo Emulator Backend

**Secure OAuth proxy and authentication services for Nintendo Emulator**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen.svg)](https://nodejs.org/)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [API Documentation](#api-documentation)
- [Deployment](#deployment)
- [Security](#security)
- [Development](#development)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This backend provides secure OAuth token exchange and user authentication services for the Nintendo Emulator app. It ensures that sensitive OAuth client secrets and password hashing remain server-side, following security best practices.

### Why This Backend?

- **Security**: Keeps OAuth secrets out of client app
- **Compliance**: Follows OWASP authentication guidelines
- **Privacy**: Uses Argon2id for password hashing (OWASP recommended)
- **Performance**: Rate limiting and optimized token exchange
- **Scalability**: Containerized with Docker, ready for cloud deployment

---

## ✨ Features

### OAuth Proxy Service (Port 3000)

- ✅ **6 Platform Support**: Twitch, YouTube, Discord, Twitter, Instagram, TikTok
- ✅ **Secure Token Exchange**: Client secrets never exposed to client
- ✅ **Token Refresh**: Automatic token renewal
- ✅ **Rate Limiting**: Protection against abuse
- ✅ **CORS Support**: Configurable origin whitelist

### Authentication Service (Port 3001)

- ✅ **Argon2id Hashing**: Industry-standard password security
- ✅ **JWT Tokens**: Access tokens (1 hour) + refresh tokens (7 days)
- ✅ **User Management**: Registration, login, password reset
- ✅ **Email Verification**: Optional email confirmation flow
- ✅ **Device Tracking**: Multi-device support

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Client App (Swift)                       │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Nginx Reverse Proxy                        │
│  • SSL/TLS Termination                                       │
│  • Rate Limiting                                             │
│  • Load Balancing                                            │
└───────────────┬──────────────────────┬──────────────────────┘
                │                      │
    ┌───────────▼────────┐  ┌──────────▼───────────┐
    │  OAuth Proxy       │  │  Auth Service        │
    │  (Port 3000)       │  │  (Port 3001)         │
    │                    │  │                      │
    │  • Token Exchange  │  │  • User Registration │
    │  • Token Refresh   │  │  • User Login        │
    │  • 6 Platforms     │  │  • Argon2id Hashing  │
    └────────────────────┘  │  • JWT Generation    │
                            └──────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ ([Download](https://nodejs.org/))
- npm 9+
- Docker & Docker Compose (for containerized deployment)

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Configure Environment

```bash
# Copy example file
cp .env.example .env

# Edit with your credentials
nano .env
```

**Required environment variables:**

```env
# OAuth Credentials
TWITCH_CLIENT_ID=your_twitch_client_id
TWITCH_CLIENT_SECRET=your_twitch_client_secret
# ... (repeat for all 6 platforms)

# JWT Configuration
JWT_SECRET=$(openssl rand -base64 32)

# CORS
ALLOWED_ORIGIN=https://yourdomain.com
```

### 3. Run Services

#### Option A: Local Development

```bash
# Terminal 1: OAuth Proxy
npm start

# Terminal 2: Auth Service
npm run start:auth

# Or run both together
npm run start:all
```

#### Option B: Docker (Recommended)

```bash
./deploy.sh deploy
```

### 4. Verify

```bash
# Check OAuth proxy
curl http://localhost:3000/health
# Response: {"status":"ok","service":"oauth-proxy"}

# Check auth service
curl http://localhost:3001/health
# Response: {"status":"ok","service":"auth-service","users":0}
```

---

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| **OAuth Proxy** |
| `OAUTH_PORT` | OAuth service port | No | 3000 |
| `TWITCH_CLIENT_ID` | Twitch OAuth client ID | Yes | - |
| `TWITCH_CLIENT_SECRET` | Twitch OAuth secret | Yes | - |
| `YOUTUBE_CLIENT_ID` | YouTube OAuth client ID | Yes | - |
| `YOUTUBE_CLIENT_SECRET` | YouTube OAuth secret | Yes | - |
| `DISCORD_CLIENT_ID` | Discord OAuth client ID | Yes | - |
| `DISCORD_CLIENT_SECRET` | Discord OAuth secret | Yes | - |
| `TWITTER_CLIENT_ID` | Twitter OAuth client ID | Yes | - |
| `TWITTER_CLIENT_SECRET` | Twitter OAuth secret | Yes | - |
| `INSTAGRAM_CLIENT_ID` | Instagram OAuth client ID | Yes | - |
| `INSTAGRAM_CLIENT_SECRET` | Instagram OAuth secret | Yes | - |
| `TIKTOK_CLIENT_KEY` | TikTok OAuth client key | Yes | - |
| `TIKTOK_CLIENT_SECRET` | TikTok OAuth secret | Yes | - |
| **Auth Service** |
| `AUTH_PORT` | Auth service port | No | 3001 |
| `JWT_SECRET` | JWT signing secret | Yes | - |
| `ALLOWED_ORIGIN` | CORS allowed origin | Yes | - |

### Getting OAuth Credentials

1. **Twitch**: https://dev.twitch.tv/console/apps
2. **YouTube**: https://console.developers.google.com/
3. **Discord**: https://discord.com/developers/applications
4. **Twitter**: https://developer.twitter.com/en/portal/dashboard
5. **Instagram**: https://developers.facebook.com/apps/
6. **TikTok**: https://developers.tiktok.com/apps/

---

## 📚 API Documentation

### OAuth Proxy Endpoints

#### Exchange Authorization Code

```http
POST /oauth/{platform}/exchange
Content-Type: application/json

{
  "code": "authorization_code_from_oauth_flow",
  "redirect_uri": "your_redirect_uri"
}
```

**Supported platforms:** `twitch`, `youtube`, `discord`, `twitter`, `instagram`, `tiktok`

**Response:**
```json
{
  "access_token": "ya29.a0AfH6...",
  "refresh_token": "1//0gDd5...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

#### Refresh Token

```http
POST /oauth/{platform}/refresh
Content-Type: application/json

{
  "refresh_token": "your_refresh_token"
}
```

### Authentication Endpoints

#### Register User

```http
POST /auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePassword123!",
  "username": "username",
  "deviceID": "optional_device_id"
}
```

**Response:**
```json
{
  "userID": "user_1234567890_abc123",
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
  "createdAt": "2025-09-30T12:00:00.000Z"
}
```

#### Sign In

```http
POST /auth/signin
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePassword123!",
  "deviceID": "optional_device_id"
}
```

#### Get Current User

```http
GET /auth/me
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "id": "user_1234567890_abc123",
  "email": "user@example.com",
  "username": "username",
  "isEmailVerified": false,
  "createdAt": "2025-09-30T12:00:00.000Z",
  "subscription": "free"
}
```

#### Refresh Access Token

```http
POST /auth/refresh
Content-Type: application/json

{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

---

## 🐳 Deployment

### Docker Compose (Recommended)

```bash
# Deploy all services
./deploy.sh deploy

# View logs
./deploy.sh logs

# Check status
./deploy.sh status

# Stop services
./deploy.sh stop

# Restart services
./deploy.sh restart
```

### Manual Docker

```bash
# Build image
docker build -t nintendo-backend .

# Run OAuth proxy
docker run -d \
  --name oauth-proxy \
  -p 3000:3000 \
  --env-file .env \
  nintendo-backend node oauth-proxy.js

# Run auth service
docker run -d \
  --name auth-service \
  -p 3001:3001 \
  --env-file .env \
  nintendo-backend node auth-service.js
```

### Cloud Deployment

See [PRODUCTION_DEPLOYMENT.md](./PRODUCTION_DEPLOYMENT.md) for detailed guides on:

- AWS EC2
- DigitalOcean Droplets
- Google Cloud Platform
- Azure
- Heroku

---

## 🔐 Security

### Password Security

- **Algorithm**: Argon2id (OWASP recommended)
- **Memory Cost**: 64 MB
- **Time Cost**: 3 iterations
- **Parallelism**: 4 threads

### Token Security

- **Access Tokens**: Short-lived (1 hour)
- **Refresh Tokens**: Long-lived (7 days)
- **Algorithm**: HS256 (HMAC-SHA256)
- **Secret**: 32-byte random key

### Network Security

- **TLS/HTTPS**: All traffic encrypted
- **Certificate Pinning**: Client validates server cert
- **HSTS**: HTTP Strict Transport Security enabled
- **Rate Limiting**: 5-30 req/s depending on endpoint

### Container Security

- **Non-root user**: Runs as UID 1001
- **Minimal base**: Alpine Linux
- **Health checks**: Automatic restart on failure
- **Resource limits**: CPU and memory constraints

---

## 💻 Development

### Local Development

```bash
# Install dependencies
npm install

# Run with auto-reload
npm run dev          # OAuth proxy only
npm run dev:auth     # Auth service only
npm run dev:all      # Both services
```

### Testing

```bash
# Run health checks
npm run health

# Run deployment tests
npm test

# Manual testing
curl -X POST http://localhost:3001/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!",
    "username": "testuser"
  }'
```

### Logging

```bash
# OAuth proxy logs
docker compose logs -f oauth-proxy

# Auth service logs
docker compose logs -f auth-service

# All logs
docker compose logs -f
```

---

## 🔧 Troubleshooting

### Port Already in Use

```bash
# Find process using port
lsof -i :3000

# Kill process
kill -9 <PID>
```

### Environment Variables Not Loading

```bash
# Verify .env file
cat .env | grep CLIENT_SECRET

# Check Docker container
docker exec oauth-proxy env | grep TWITCH
```

### Service Won't Start

```bash
# Check logs
docker compose logs oauth-proxy

# Restart service
docker compose restart oauth-proxy

# Rebuild from scratch
docker compose down
docker compose build --no-cache
docker compose up -d
```

### SSL Certificate Issues

```bash
# Verify certificate
openssl x509 -in ssl/fullchain.pem -text -noout

# Check expiry
openssl x509 -enddate -noout -in ssl/fullchain.pem

# Regenerate self-signed cert
./deploy.sh deploy
```

---

## 📊 Performance

### Benchmarks

| Operation | Target | Typical |
|-----------|--------|---------|
| OAuth token exchange | < 500ms | 200-300ms |
| User registration | < 200ms | 100-150ms |
| User login | < 200ms | 80-120ms |
| Health check | < 10ms | 2-5ms |

### Load Testing

```bash
# Install Apache Bench
brew install ab

# Test OAuth proxy
ab -n 1000 -c 10 http://localhost:3000/health

# Test auth service
ab -n 1000 -c 10 http://localhost:3001/health
```

---

## 📝 License

MIT License - see [LICENSE](../LICENSE) for details

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📞 Support

- **Documentation**: See [PRODUCTION_DEPLOYMENT.md](./PRODUCTION_DEPLOYMENT.md)
- **Issues**: https://github.com/yourusername/nintendo-emulator/issues
- **Security**: security@nintendoemulator.app

---

**Built with ❤️ and 🔒 security in mind**