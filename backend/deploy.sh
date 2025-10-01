#!/bin/bash

# Nintendo Emulator Backend Deployment Script
# Deploys OAuth proxy, auth service, and nginx reverse proxy

set -e

echo "🚀 Nintendo Emulator Backend Deployment"
echo "========================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# Functions
error() {
    echo -e "${RED}❌ Error: $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo "ℹ️  $1"
}

# Pre-flight checks
preflight_checks() {
    info "Running pre-flight checks..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi
    success "Docker is installed"

    # Check if Docker Compose is available
    if ! docker compose version &> /dev/null; then
        error "Docker Compose is not available. Please install Docker Compose v2."
    fi
    success "Docker Compose is available"

    # Check if .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        error ".env file not found. Please create it from .env.example"
    fi
    success ".env file exists"

    # Check if required environment variables are set
    source "$ENV_FILE"

    required_vars=(
        "TWITCH_CLIENT_ID"
        "TWITCH_CLIENT_SECRET"
        "YOUTUBE_CLIENT_ID"
        "YOUTUBE_CLIENT_SECRET"
        "DISCORD_CLIENT_ID"
        "DISCORD_CLIENT_SECRET"
        "TWITTER_CLIENT_ID"
        "TWITTER_CLIENT_SECRET"
        "INSTAGRAM_CLIENT_ID"
        "INSTAGRAM_CLIENT_SECRET"
        "TIKTOK_CLIENT_KEY"
        "TIKTOK_CLIENT_SECRET"
        "JWT_SECRET"
    )

    missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        warning "Missing environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        error "Please set all required environment variables in .env"
    fi
    success "All required environment variables are set"

    echo ""
}

# SSL certificate setup
setup_ssl() {
    info "Setting up SSL certificates..."

    mkdir -p "${SCRIPT_DIR}/ssl"

    if [ -f "${SCRIPT_DIR}/ssl/fullchain.pem" ] && [ -f "${SCRIPT_DIR}/ssl/privkey.pem" ]; then
        success "SSL certificates found"
    else
        warning "SSL certificates not found"
        info "For production, use Let's Encrypt:"
        echo "  1. Install certbot: brew install certbot"
        echo "  2. Get certificate: sudo certbot certonly --standalone -d api.nintendoemulator.app"
        echo "  3. Copy certificates:"
        echo "     sudo cp /etc/letsencrypt/live/api.nintendoemulator.app/fullchain.pem ./ssl/"
        echo "     sudo cp /etc/letsencrypt/live/api.nintendoemulator.app/privkey.pem ./ssl/"
        echo ""
        info "For development, generating self-signed certificate..."

        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "${SCRIPT_DIR}/ssl/privkey.pem" \
            -out "${SCRIPT_DIR}/ssl/fullchain.pem" \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=api.nintendoemulator.app" \
            2>/dev/null

        success "Self-signed certificate generated (development only)"
    fi

    echo ""
}

# Build Docker images
build_images() {
    info "Building Docker images..."

    cd "$SCRIPT_DIR"
    docker compose build --no-cache

    success "Docker images built successfully"
    echo ""
}

# Start services
start_services() {
    info "Starting services..."

    cd "$SCRIPT_DIR"
    docker compose up -d

    success "Services started"
    echo ""
}

# Wait for services to be healthy
wait_for_services() {
    info "Waiting for services to be healthy..."

    # Wait for OAuth proxy
    for i in {1..30}; do
        if curl -f http://localhost:3000/health &> /dev/null; then
            success "OAuth proxy is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            error "OAuth proxy failed to start"
        fi
        sleep 2
    done

    # Wait for auth service
    for i in {1..30}; do
        if curl -f http://localhost:3001/health &> /dev/null; then
            success "Auth service is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            error "Auth service failed to start"
        fi
        sleep 2
    done

    # Wait for nginx
    for i in {1..30}; do
        if curl -f http://localhost/health &> /dev/null; then
            success "Nginx is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            error "Nginx failed to start"
        fi
        sleep 2
    done

    echo ""
}

# Display service status
show_status() {
    info "Service status:"
    echo ""

    docker compose ps

    echo ""
    success "Deployment complete!"
    echo ""
    echo "📊 Service endpoints:"
    echo "  - OAuth proxy:   http://localhost:3000"
    echo "  - Auth service:  http://localhost:3001"
    echo "  - Nginx (HTTP):  http://localhost"
    echo "  - Nginx (HTTPS): https://localhost"
    echo ""
    echo "📝 Next steps:"
    echo "  1. Test OAuth flow: curl http://localhost:3000/health"
    echo "  2. Test auth:       curl http://localhost:3001/health"
    echo "  3. View logs:       docker compose logs -f"
    echo "  4. Stop services:   docker compose down"
    echo ""
}

# Rollback function
rollback() {
    warning "Rolling back deployment..."
    docker compose down
    success "Rollback complete"
    exit 1
}

# Main deployment flow
main() {
    # Parse command line arguments
    case "${1:-deploy}" in
        deploy)
            preflight_checks
            setup_ssl
            build_images
            start_services || rollback
            wait_for_services || rollback
            show_status
            ;;
        stop)
            info "Stopping services..."
            docker compose down
            success "Services stopped"
            ;;
        restart)
            info "Restarting services..."
            docker compose restart
            wait_for_services
            success "Services restarted"
            ;;
        logs)
            docker compose logs -f
            ;;
        status)
            docker compose ps
            ;;
        *)
            echo "Usage: $0 {deploy|stop|restart|logs|status}"
            echo ""
            echo "Commands:"
            echo "  deploy  - Deploy all services (default)"
            echo "  stop    - Stop all services"
            echo "  restart - Restart all services"
            echo "  logs    - View service logs"
            echo "  status  - Show service status"
            exit 1
            ;;
    esac
}

# Trap errors
trap rollback ERR

# Run main function
main "$@"