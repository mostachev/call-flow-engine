#!/bin/bash
set -e

# ===================================
# CallFlowEngine Deployment Script
# ===================================
# Usage:
#   ./deploy.sh              - Initial deployment
#   ./deploy.sh --update     - Update existing deployment
#   ./deploy.sh --rollback   - Rollback to previous version
#   ./deploy.sh --status     - Check deployment status
# ===================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project settings
PROJECT_NAME="call_flow_engine"
COMPOSE_PROJECT_NAME="callflow"
BACKUP_DIR="./backups"
LOG_FILE="./deploy.log"

# Default ports (can be overridden in .env.ports)
DEFAULT_APP_PORT=4100
DEFAULT_POSTGRES_PORT=5433
DEFAULT_NGINX_PORT=8100

# ===================================
# Helper Functions
# ===================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# ===================================
# Pre-flight Checks
# ===================================

preflight_checks() {
    log "Running pre-flight checks..."
    
    check_command docker
    check_command docker-compose
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    # Check if running as root (warn if yes)
    if [ "$EUID" -eq 0 ]; then
        warn "Running as root is not recommended for production deployments."
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "Pre-flight checks passed ✓"
}

# ===================================
# Port Configuration
# ===================================

configure_ports() {
    local ports_file=".env.ports"
    
    if [ -f "$ports_file" ]; then
        log "Loading existing port configuration..."
        source "$ports_file"
        return
    fi
    
    log "Configuring ports for deployment..."
    echo
    info "To avoid conflicts with other services, please configure custom ports."
    echo
    
    # App port
    read -p "Phoenix application port (default: $DEFAULT_APP_PORT): " APP_PORT
    APP_PORT=${APP_PORT:-$DEFAULT_APP_PORT}
    
    # PostgreSQL port
    read -p "PostgreSQL port (default: $DEFAULT_POSTGRES_PORT): " POSTGRES_PORT
    POSTGRES_PORT=${POSTGRES_PORT:-$DEFAULT_POSTGRES_PORT}
    
    # Nginx port (optional)
    read -p "Nginx HTTP port (default: $DEFAULT_NGINX_PORT, 0 to disable): " NGINX_PORT
    NGINX_PORT=${NGINX_PORT:-$DEFAULT_NGINX_PORT}
    
    # Check if ports are available
    check_port_available() {
        if [ "$1" != "0" ] && lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
            error "Port $1 is already in use!"
            return 1
        fi
        return 0
    }
    
    if ! check_port_available $APP_PORT; then
        error "Please choose a different app port."
        exit 1
    fi
    
    if ! check_port_available $POSTGRES_PORT; then
        error "Please choose a different PostgreSQL port."
        exit 1
    fi
    
    if [ "$NGINX_PORT" != "0" ] && ! check_port_available $NGINX_PORT; then
        error "Please choose a different Nginx port."
        exit 1
    fi
    
    # Save configuration
    cat > "$ports_file" <<EOF
# Port configuration for CallFlowEngine
APP_PORT=$APP_PORT
POSTGRES_PORT=$POSTGRES_PORT
NGINX_PORT=$NGINX_PORT
EOF
    
    log "Port configuration saved to $ports_file"
    info "App will be accessible at: http://localhost:$APP_PORT"
    if [ "$NGINX_PORT" != "0" ]; then
        info "Nginx will be accessible at: http://localhost:$NGINX_PORT"
    fi
}

# ===================================
# Environment Configuration
# ===================================

configure_environment() {
    local env_file=".env"
    
    if [ -f "$env_file" ]; then
        log "Environment file already exists, skipping configuration."
        return
    fi
    
    log "Configuring environment variables..."
    
    # Load port configuration
    source .env.ports
    
    # Start with template
    if [ -f ".env.docker" ]; then
        cp .env.docker "$env_file"
    else
        error ".env.docker template not found!"
        exit 1
    fi
    
    # Update ports in .env
    sed -i.bak "s/4000/$APP_PORT/g" "$env_file"
    rm -f "${env_file}.bak"
    
    # Generate SECRET_KEY_BASE if docker is available
    log "Generating SECRET_KEY_BASE..."
    SECRET_KEY=$(docker run --rm elixir:1.14-alpine sh -c "mix local.hex --force > /dev/null 2>&1 && mix phx.gen.secret" 2>/dev/null || echo "CHANGE_ME_$(openssl rand -hex 32)")
    sed -i.bak "s|SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY|g" "$env_file"
    rm -f "${env_file}.bak"
    
    # Interactive configuration
    echo
    info "Please configure the following settings (press Enter to keep default):"
    echo
    
    # Asterisk ARI
    read -p "Asterisk ARI URL (default: ws://asterisk:8088/ari/events): " ari_url
    if [ ! -z "$ari_url" ]; then
        sed -i.bak "s|ARI_URL=.*|ARI_URL=$ari_url|g" "$env_file"
        rm -f "${env_file}.bak"
    fi
    
    read -p "Asterisk ARI Username (default: asterisk): " ari_user
    if [ ! -z "$ari_user" ]; then
        sed -i.bak "s|ARI_USER=.*|ARI_USER=$ari_user|g" "$env_file"
        rm -f "${env_file}.bak"
    fi
    
    read -sp "Asterisk ARI Password (default: asterisk): " ari_pass
    echo
    if [ ! -z "$ari_pass" ]; then
        sed -i.bak "s|ARI_PASSWORD=.*|ARI_PASSWORD=$ari_pass|g" "$env_file"
        rm -f "${env_file}.bak"
    fi
    
    # Bitrix24
    read -p "Bitrix24 Webhook URL (optional): " bitrix_url
    if [ ! -z "$bitrix_url" ]; then
        sed -i.bak "s|BITRIX_WEBHOOK_URL=.*|BITRIX_WEBHOOK_URL=$bitrix_url|g" "$env_file"
        rm -f "${env_file}.bak"
    fi
    
    log "Environment configuration completed ✓"
}

# ===================================
# Docker Compose Configuration
# ===================================

prepare_docker_compose() {
    log "Preparing docker-compose override..."
    
    source .env.ports
    
    cat > docker-compose.override.yml <<EOF
version: '3.8'

services:
  postgres:
    ports:
      - "${POSTGRES_PORT}:5432"

  app:
    ports:
      - "${APP_PORT}:4000"
EOF

    if [ "$NGINX_PORT" != "0" ]; then
        cat >> docker-compose.override.yml <<EOF

  nginx:
    image: nginx:alpine
    container_name: ${COMPOSE_PROJECT_NAME}_nginx
    ports:
      - "${NGINX_PORT}:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app
    networks:
      - call_flow_network
    restart: unless-stopped
EOF
    fi
    
    log "Docker Compose override created ✓"
}

# ===================================
# Backup Functions
# ===================================

create_backup() {
    log "Creating backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/backup_${timestamp}.tar.gz"
    
    # Backup database
    if docker ps | grep -q "${COMPOSE_PROJECT_NAME}_postgres"; then
        log "Backing up database..."
        docker exec ${COMPOSE_PROJECT_NAME}_postgres pg_dump -U postgres call_flow_engine_dev > "${BACKUP_DIR}/db_${timestamp}.sql" 2>/dev/null || true
    fi
    
    # Backup configuration files
    tar -czf "$backup_file" \
        .env .env.ports docker-compose.override.yml \
        "${BACKUP_DIR}/db_${timestamp}.sql" 2>/dev/null || true
    
    # Keep only last 5 backups
    ls -t ${BACKUP_DIR}/backup_*.tar.gz | tail -n +6 | xargs -r rm
    
    log "Backup created: $backup_file ✓"
    echo "$backup_file" > "${BACKUP_DIR}/.last_backup"
}

restore_backup() {
    local backup_file="${1:-$(cat ${BACKUP_DIR}/.last_backup 2>/dev/null)}"
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        error "No backup file specified or found."
        return 1
    fi
    
    warn "Restoring from backup: $backup_file"
    
    # Stop services
    docker-compose -p $COMPOSE_PROJECT_NAME down
    
    # Restore configuration
    tar -xzf "$backup_file" .env .env.ports docker-compose.override.yml 2>/dev/null || true
    
    # Restart services
    docker-compose -p $COMPOSE_PROJECT_NAME up -d
    
    log "Backup restored ✓"
}

# ===================================
# Deployment Functions
# ===================================

initial_deploy() {
    log "Starting initial deployment of $PROJECT_NAME..."
    
    preflight_checks
    configure_ports
    configure_environment
    prepare_docker_compose
    
    log "Building and starting services..."
    docker-compose -p $COMPOSE_PROJECT_NAME build --no-cache
    docker-compose -p $COMPOSE_PROJECT_NAME up -d
    
    log "Waiting for services to be ready..."
    sleep 10
    
    # Wait for health check
    local max_attempts=30
    local attempt=0
    
    source .env.ports
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "http://localhost:${APP_PORT}/health" > /dev/null 2>&1; then
            log "Service is healthy! ✓"
            break
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    echo
    
    if [ $attempt -eq $max_attempts ]; then
        error "Service did not become healthy in time. Check logs with: docker-compose -p $COMPOSE_PROJECT_NAME logs"
        exit 1
    fi
    
    create_backup
    
    log "═══════════════════════════════════════════════════════"
    log "Deployment completed successfully! 🎉"
    log "═══════════════════════════════════════════════════════"
    info "Application URL: http://localhost:${APP_PORT}"
    info "Health check:    http://localhost:${APP_PORT}/health"
    info "API Stats:       http://localhost:${APP_PORT}/api/stats"
    log "═══════════════════════════════════════════════════════"
    info "Useful commands:"
    echo "  View logs:      docker-compose -p $COMPOSE_PROJECT_NAME logs -f"
    echo "  Stop services:  docker-compose -p $COMPOSE_PROJECT_NAME down"
    echo "  Run tests:      docker-compose -p $COMPOSE_PROJECT_NAME exec app mix test"
    echo "  Update:         ./deploy.sh --update"
    log "═══════════════════════════════════════════════════════"
}

update_deploy() {
    log "Starting update deployment..."
    
    if [ ! -f ".env" ]; then
        error "No existing deployment found. Run './deploy.sh' first."
        exit 1
    fi
    
    preflight_checks
    
    # Create backup before update
    create_backup
    
    log "Pulling latest changes..."
    if [ -d .git ]; then
        git pull origin main || warn "Git pull failed, continuing with local changes"
    fi
    
    log "Checking for changes..."
    local needs_rebuild=false
    local needs_restart=false
    
    # Check if Dockerfile or dependencies changed
    if git diff HEAD@{1} --name-only 2>/dev/null | grep -qE "(Dockerfile|mix.exs|mix.lock)"; then
        needs_rebuild=true
        log "Code changes detected - rebuild required"
    fi
    
    # Check if config changed
    if git diff HEAD@{1} --name-only 2>/dev/null | grep -qE "(config/|docker-compose)"; then
        needs_restart=true
        log "Configuration changes detected - restart required"
    fi
    
    if [ "$needs_rebuild" = true ]; then
        log "Rebuilding application..."
        docker-compose -p $COMPOSE_PROJECT_NAME build --no-cache app
        needs_restart=true
    fi
    
    if [ "$needs_restart" = true ]; then
        log "Restarting services with zero-downtime..."
        
        # Scale up new instance
        docker-compose -p $COMPOSE_PROJECT_NAME up -d --scale app=2 --no-recreate
        sleep 5
        
        # Remove old instance
        docker-compose -p $COMPOSE_PROJECT_NAME up -d --scale app=1 --no-recreate
        
        log "Services restarted ✓"
    else
        log "No rebuild or restart needed - deployment is up to date ✓"
    fi
    
    # Run migrations
    log "Running database migrations..."
    docker-compose -p $COMPOSE_PROJECT_NAME exec -T app mix ecto.migrate || warn "Migration failed or not needed"
    
    # Health check
    source .env.ports
    if curl -sf "http://localhost:${APP_PORT}/health" > /dev/null 2>&1; then
        log "Update completed successfully! ✓"
    else
        error "Health check failed after update!"
        warn "Rolling back to previous version..."
        restore_backup
        exit 1
    fi
    
    log "═══════════════════════════════════════════════════════"
    log "Update completed successfully! 🎉"
    log "═══════════════════════════════════════════════════════"
}

# ===================================
# Status Check
# ===================================

check_status() {
    log "Checking deployment status..."
    echo
    
    # Check if services are running
    if docker-compose -p $COMPOSE_PROJECT_NAME ps | grep -q "Up"; then
        info "Services are running ✓"
        docker-compose -p $COMPOSE_PROJECT_NAME ps
    else
        warn "Services are not running"
        docker-compose -p $COMPOSE_PROJECT_NAME ps
    fi
    
    echo
    
    # Check health
    if [ -f ".env.ports" ]; then
        source .env.ports
        info "Health check: http://localhost:${APP_PORT}/health"
        if curl -sf "http://localhost:${APP_PORT}/health" 2>/dev/null | jq .; then
            log "Service is healthy ✓"
        else
            warn "Service health check failed or jq not installed"
        fi
    fi
    
    echo
    
    # Disk usage
    info "Docker volumes disk usage:"
    docker system df -v | grep -A 10 "VOLUME NAME"
    
    echo
    
    # Recent logs
    info "Recent logs (last 20 lines):"
    docker-compose -p $COMPOSE_PROJECT_NAME logs --tail=20
}

# ===================================
# Rollback
# ===================================

rollback_deploy() {
    warn "Rolling back to previous version..."
    
    local last_backup=$(cat ${BACKUP_DIR}/.last_backup 2>/dev/null)
    
    if [ -z "$last_backup" ]; then
        error "No backup found to rollback to."
        exit 1
    fi
    
    restore_backup "$last_backup"
    
    log "Rollback completed ✓"
}

# ===================================
# Main Script
# ===================================

main() {
    # Create log file
    touch "$LOG_FILE"
    
    case "${1:-}" in
        --update)
            update_deploy
            ;;
        --rollback)
            rollback_deploy
            ;;
        --status)
            check_status
            ;;
        --help|-h)
            echo "CallFlowEngine Deployment Script"
            echo
            echo "Usage:"
            echo "  ./deploy.sh              Initial deployment"
            echo "  ./deploy.sh --update     Update existing deployment"
            echo "  ./deploy.sh --rollback   Rollback to previous version"
            echo "  ./deploy.sh --status     Check deployment status"
            echo "  ./deploy.sh --help       Show this help"
            echo
            ;;
        "")
            initial_deploy
            ;;
        *)
            error "Unknown option: $1"
            echo "Use './deploy.sh --help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
