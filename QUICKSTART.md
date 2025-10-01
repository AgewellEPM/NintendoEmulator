# ⚡ Quick Start Guide - Nintendo Emulator

**Get up and running in 10 minutes**

---

## 🎯 Prerequisites (2 minutes)

Install the following:

```bash
# 1. Node.js 18+
node --version  # Should be >= 18.0.0

# 2. Docker (optional, for production deployment)
docker --version

# 3. Swift (for building the app)
swift --version
```

---

## 🚀 Local Development (5 minutes)

### Step 1: Clone & Setup

```bash
# Clone repository
git clone https://github.com/yourusername/nintendo-emulator.git
cd nintendo-emulator
```

### Step 2: Backend Setup

```bash
# Navigate to backend
cd backend

# Install dependencies
npm install

# Configure environment
cp .env.example .env
nano .env  # Add your OAuth credentials

# Start services
npm run start:all
```

**Services will run on:**
- OAuth Proxy: http://localhost:3000
- Auth Service: http://localhost:3001

### Step 3: App Setup

```bash
# In a new terminal, navigate to project root
cd ..

# Set environment variables
./scripts/setup-env.sh

# Build the app
swift build -c release

# Run the app
.build/release/NintendoEmulator
```

---

## 🐳 Docker Deployment (3 minutes)

### Option 1: Quick Deploy

```bash
cd backend
./deploy.sh deploy
```

### Option 2: Manual Docker

```bash
cd backend

# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

**Services will run on:**
- Nginx: http://localhost (HTTP) / https://localhost (HTTPS)
- OAuth Proxy: http://localhost:3000
- Auth Service: http://localhost:3001

---

## ✅ Verify Installation

```bash
# Run health checks
cd backend
npm run health

# Run tests
npm test
```

**Expected output:**
```
✅ HEALTHY OAuth Proxy (123ms)
✅ HEALTHY Auth Service (89ms)
✅ All critical services are healthy
```

---

## 🎮 Test the App

### 1. Register a User

```bash
curl -X POST http://localhost:3001/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "TestPassword123!",
    "username": "testuser"
  }'
```

### 2. Sign In

```bash
curl -X POST http://localhost:3001/auth/signin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "TestPassword123!"
  }'
```

### 3. Load a ROM

- Open the Nintendo Emulator app
- Click "Add ROM"
- Select a valid N64 ROM file (.z64, .n64, .v64)
- Game should load and be playable!

---

## 📝 Configuration

### OAuth Credentials

Get your credentials from:

1. **Twitch**: https://dev.twitch.tv/console/apps
2. **YouTube**: https://console.developers.google.com/
3. **Discord**: https://discord.com/developers/applications
4. **Twitter**: https://developer.twitter.com/en/portal/dashboard
5. **Instagram**: https://developers.facebook.com/apps/
6. **TikTok**: https://developers.tiktok.com/apps/

Add them to `backend/.env`:

```env
TWITCH_CLIENT_ID=your_id_here
TWITCH_CLIENT_SECRET=your_secret_here
# ... repeat for all platforms
```

---

## 🔧 Troubleshooting

### Backend won't start

```bash
# Check if ports are in use
lsof -i :3000
lsof -i :3001

# Kill processes if needed
kill -9 <PID>

# Restart services
cd backend
npm run start:all
```

### Docker issues

```bash
# Reset Docker
docker compose down
docker compose build --no-cache
docker compose up -d

# Check logs
docker compose logs -f
```

### App won't build

```bash
# Clean build
swift package clean
swift build -c release

# Check Swift version
swift --version  # Should be 5.0+
```

---

## 📚 Next Steps

- **Security**: Review [SECURITY_ASSESSMENT_REPORT.md](./SECURITY_ASSESSMENT_REPORT.md)
- **Deployment**: See [backend/PRODUCTION_DEPLOYMENT.md](./backend/PRODUCTION_DEPLOYMENT.md)
- **Backend API**: Check [backend/README.md](./backend/README.md)
- **Development**: Read [DEPLOYMENT_READY.md](./DEPLOYMENT_READY.md)

---

## 🆘 Need Help?

- **Health Checks**: `npm run health`
- **View Logs**: `docker compose logs -f`
- **Test Endpoints**: `npm test`
- **Documentation**: All docs in project root

---

**🎮 Happy gaming! 🔒 Stay secure!**