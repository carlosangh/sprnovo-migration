#!/bin/bash
# Main Deployment Script for SPR System
# Orchestrates frontend build, backend deployment, and service management

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-/opt/spr}"
ENVIRONMENT="${1:-production}"
SKIP_TESTS="${SKIP_TESTS:-false}"
SKIP_BACKUP="${SKIP_BACKUP:-false}"
ROLLBACK="${ROLLBACK:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[INFO]${NC} [$timestamp] $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} [$timestamp] $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} [$timestamp] $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} [$timestamp] $message" ;;
    esac
}

# Error handler
error_handler() {
    local line_number="$1"
    log "ERROR" "Deployment failed at line $line_number"
    log "ERROR" "Rolling back changes..."
    rollback_deployment
    exit 1
}

trap 'error_handler ${LINENO}' ERR

# Load environment configuration
load_environment() {
    local env_file="$SCRIPT_DIR/../.env.$ENVIRONMENT"
    if [ -f "$env_file" ]; then
        log "INFO" "Loading environment variables from $env_file"
        export $(cat "$env_file" | grep -v '^#' | xargs)
    else
        log "WARN" "Environment file $env_file not found, using defaults"
    fi
}

# Pre-deployment checks
pre_deployment_checks() {
    log "INFO" "Running pre-deployment checks..."
    
    # Check if we're running as the correct user
    if [ "$USER" = "root" ]; then
        log "WARN" "Running deployment as root. Consider using a dedicated deploy user."
    fi
    
    # Check available disk space
    local available_space=$(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | sed 's/[^0-9]*//g')
    if [ "$available_space" -lt 1000 ]; then  # Less than 1GB
        log "ERROR" "Insufficient disk space. Available: ${available_space}MB"
        exit 1
    fi
    
    # Check if services are running
    if command -v systemctl > /dev/null; then
        if ! systemctl is-active --quiet nginx; then
            log "WARN" "Nginx is not running. Will attempt to start after deployment."
        fi
    fi
    
    # Validate environment configuration
    if [ -z "$DATABASE_URL" ] && [ "$ENVIRONMENT" = "production" ]; then
        log "ERROR" "DATABASE_URL not configured for production environment"
        exit 1
    fi
}

# Backup current deployment
backup_deployment() {
    if [ "$SKIP_BACKUP" = "true" ]; then
        log "INFO" "Skipping backup as requested"
        return
    fi
    
    local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"
    log "INFO" "Creating deployment backup at $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # Backup frontend build
    if [ -d "$PROJECT_ROOT/frontend/build" ]; then
        cp -r "$PROJECT_ROOT/frontend/build" "$backup_dir/frontend_build"
    fi
    
    # Backup backend (if applicable)
    if [ -d "$PROJECT_ROOT/backend" ]; then
        cp -r "$PROJECT_ROOT/backend" "$backup_dir/backend"
    fi
    
    # Backup current PM2 processes
    pm2 jlist > "$backup_dir/pm2_processes.json" 2>/dev/null || true
    
    # Keep only last 10 backups
    cd "$PROJECT_ROOT/backups"
    ls -t | tail -n +11 | xargs -r rm -rf
    
    echo "$backup_dir" > "$PROJECT_ROOT/.last_backup"
    log "SUCCESS" "Backup created successfully"
}

# Build frontend
build_frontend() {
    log "INFO" "Building frontend..."
    
    if [ -x "$SCRIPT_DIR/build_frontend.sh" ]; then
        FRONTEND_DIR="$PROJECT_ROOT/frontend" "$SCRIPT_DIR/build_frontend.sh"
    else
        log "ERROR" "Frontend build script not found or not executable"
        exit 1
    fi
    
    log "SUCCESS" "Frontend build completed"
}

# Deploy backend
deploy_backend() {
    log "INFO" "Deploying backend..."
    
    # Use PM2 deployment script
    if [ -x "$SCRIPT_DIR/../pm2/pm2-deploy.sh" ]; then
        cd "$SCRIPT_DIR/../pm2"
        ./pm2-deploy.sh "$ENVIRONMENT"
    else
        log "ERROR" "PM2 deployment script not found"
        exit 1
    fi
    
    log "SUCCESS" "Backend deployment completed"
}

# Run tests
run_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log "INFO" "Skipping tests as requested"
        return
    fi
    
    log "INFO" "Running tests..."
    
    # Frontend tests
    if [ -f "$PROJECT_ROOT/frontend/package.json" ]; then
        cd "$PROJECT_ROOT/frontend"
        if npm run test --if-present -- --watchAll=false --ci; then
            log "SUCCESS" "Frontend tests passed"
        else
            log "ERROR" "Frontend tests failed"
            exit 1
        fi
    fi
    
    # Backend tests (if applicable)
    if [ -f "$PROJECT_ROOT/backend/requirements-test.txt" ]; then
        cd "$PROJECT_ROOT/backend"
        if python -m pytest --tb=short; then
            log "SUCCESS" "Backend tests passed"
        else
            log "ERROR" "Backend tests failed"
            exit 1
        fi
    fi
}

# Health checks
health_checks() {
    log "INFO" "Performing health checks..."
    
    # Check if backend is responding
    local backend_port="${BACKEND_PORT:-3002}"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "http://localhost:$backend_port/health" > /dev/null; then
            log "SUCCESS" "Backend health check passed"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log "ERROR" "Backend health check failed after $max_attempts attempts"
            exit 1
        fi
        
        log "INFO" "Health check attempt $attempt/$max_attempts failed, retrying in 2s..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    # Check if frontend is accessible
    if command -v curl > /dev/null && systemctl is-active --quiet nginx; then
        if curl -f -s "http://localhost/" > /dev/null; then
            log "SUCCESS" "Frontend accessibility check passed"
        else
            log "WARN" "Frontend accessibility check failed"
        fi
    fi
}

# Rollback deployment
rollback_deployment() {
    log "INFO" "Initiating rollback..."
    
    if [ -f "$PROJECT_ROOT/.last_backup" ]; then
        local backup_dir=$(cat "$PROJECT_ROOT/.last_backup")
        if [ -d "$backup_dir" ]; then
            log "INFO" "Restoring from backup: $backup_dir"
            
            # Restore frontend
            if [ -d "$backup_dir/frontend_build" ]; then
                rm -rf "$PROJECT_ROOT/frontend/build"
                cp -r "$backup_dir/frontend_build" "$PROJECT_ROOT/frontend/build"
            fi
            
            # Restore PM2 processes
            if [ -f "$backup_dir/pm2_processes.json" ]; then
                pm2 delete all || true
                pm2 resurrect "$backup_dir/pm2_processes.json" || true
            fi
            
            log "SUCCESS" "Rollback completed"
        else
            log "ERROR" "Backup directory not found: $backup_dir"
        fi
    else
        log "ERROR" "No backup information found for rollback"
    fi
}

# Main deployment function
main() {
    log "INFO" "Starting SPR deployment process"
    log "INFO" "Environment: $ENVIRONMENT"
    log "INFO" "Skip tests: $SKIP_TESTS"
    log "INFO" "Skip backup: $SKIP_BACKUP"
    
    if [ "$ROLLBACK" = "true" ]; then
        rollback_deployment
        exit 0
    fi
    
    load_environment
    pre_deployment_checks
    backup_deployment
    run_tests
    build_frontend
    deploy_backend
    health_checks
    
    log "SUCCESS" "Deployment completed successfully!"
    log "INFO" "Application should be available at configured URLs"
}

# Handle command line arguments
case "${1:-}" in
    "rollback")
        ROLLBACK="true"
        main
        ;;
    "production"|"staging"|"development")
        main
        ;;
    "--help"|"-h")
        echo "SPR Deployment Script"
        echo "Usage: $0 [environment] [options]"
        echo ""
        echo "Environments:"
        echo "  production  - Deploy to production (default)"
        echo "  staging     - Deploy to staging"
        echo "  development - Deploy to development"
        echo "  rollback    - Rollback to previous deployment"
        echo ""
        echo "Environment Variables:"
        echo "  SKIP_TESTS=true    - Skip running tests"
        echo "  SKIP_BACKUP=true   - Skip creating backup"
        echo "  PROJECT_ROOT       - Override project root directory"
        echo ""
        echo "Examples:"
        echo "  $0 production"
        echo "  SKIP_TESTS=true $0 staging"
        echo "  $0 rollback"
        ;;
    *)
        main
        ;;
esac