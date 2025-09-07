#!/bin/bash

# SPRNOVO Deployment Script
# Complete migration from old SPR to new SPRNOVO environment

set -e

SPRNOVO_DIR="/home/cadu/SPRNOVO"
DOMAIN="automation.royalnegociosagricolas.com.br"

echo "=== SPRNOVO Deployment Script ==="
echo "Starting deployment at: $(date)"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if running in correct directory
check_directory() {
    if [ ! -f "docker-compose.yml" ]; then
        log "ERROR: docker-compose.yml not found. Please run from SPRNOVO directory."
        exit 1
    fi
}

# Stop old containers
stop_old_containers() {
    log "Stopping old SPR containers..."
    
    # Stop any existing evolution containers
    docker stop evolution_api_v182 evolution_api 2>/dev/null || true
    docker rm evolution_api_v182 evolution_api 2>/dev/null || true
    
    # Stop old python server
    pkill -f "python3 -m http.server" || true
    
    log "Old containers stopped"
}

# Migrate database data
migrate_database() {
    log "Migrating database data..."
    
    # Create backup of existing data
    if docker ps -a | grep -q "spr-postgres"; then
        log "Backing up existing database..."
        docker exec spr-postgres pg_dumpall -U spr_user > /tmp/spr_backup_$(date +%Y%m%d).sql
        log "Database backup created"
        
        # Stop old postgres container
        docker stop spr-postgres || true
        docker rm spr-postgres || true
    fi
}

# Start new SPRNOVO environment
start_sprnovo() {
    log "Starting SPRNOVO environment..."
    
    # Pull latest images
    log "Pulling Docker images..."
    docker-compose pull
    
    # Build custom images
    log "Building custom images..."
    docker-compose build --no-cache
    
    # Start services
    log "Starting services..."
    docker-compose up -d
    
    # Wait for services to be healthy
    log "Waiting for services to start..."
    sleep 30
    
    # Check services
    docker-compose ps
}

# Restore database data if exists
restore_database() {
    BACKUP_FILE="/tmp/spr_backup_$(date +%Y%m%d).sql"
    
    if [ -f "$BACKUP_FILE" ]; then
        log "Restoring database data..."
        
        # Wait for postgres to be ready
        docker-compose exec postgres pg_isready -U spr_user -d spr_db || sleep 10
        
        # Restore data
        docker-compose exec -T postgres psql -U spr_user -d spr_db < $BACKUP_FILE
        
        log "Database data restored"
        rm $BACKUP_FILE
    fi
}

# Setup SSL and Nginx
setup_ssl() {
    log "Setting up SSL and Nginx configuration..."
    
    # Check if domain resolves to this server
    DOMAIN_IP=$(dig +short $DOMAIN)
    SERVER_IP=$(curl -s ifconfig.me)
    
    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        log "WARNING: Domain $DOMAIN does not resolve to this server ($SERVER_IP)"
        log "Please update DNS before running SSL setup"
        return 1
    fi
    
    # Run SSL setup script
    sudo ./scripts/setup-nginx-ssl.sh
    
    log "SSL and Nginx configured"
}

# Setup backup cron job
setup_backup() {
    log "Setting up daily backup cron job..."
    
    # Add to crontab if not exists
    (crontab -l 2>/dev/null; echo "0 2 * * * $SPRNOVO_DIR/scripts/backup-daily.sh >> $SPRNOVO_DIR/logs/backup.log 2>&1") | crontab -
    
    # Create log directory
    mkdir -p $SPRNOVO_DIR/logs
    
    log "Backup cron job configured for 2:00 AM daily"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check all services are running
    SERVICES=(postgres redis backend frontend evolution-api n8n)
    
    for service in "${SERVICES[@]}"; do
        if docker-compose ps $service | grep -q "Up"; then
            log "✓ $service is running"
        else
            log "✗ $service is not running"
            return 1
        fi
    done
    
    # Check endpoints
    log "Testing endpoints..."
    
    # Backend health check
    if curl -s http://localhost:8090/health | grep -q "ok"; then
        log "✓ Backend health check passed"
    else
        log "✗ Backend health check failed"
    fi
    
    # n8n check
    if curl -s http://localhost:5678 | grep -q "n8n"; then
        log "✓ n8n is accessible"
    else
        log "✗ n8n is not accessible"
    fi
    
    log "Deployment verification completed"
}

# Print summary
print_summary() {
    echo ""
    echo "=== SPRNOVO Deployment Summary ==="
    echo "Deployment completed at: $(date)"
    echo ""
    echo "Services:"
    echo "- PostgreSQL Database: localhost:5432"
    echo "- Redis Cache: localhost:6379"
    echo "- SPRNOVO Backend: localhost:8090"
    echo "- SPRNOVO Frontend: localhost:8082"
    echo "- Evolution API: localhost:8080"
    echo "- n8n Automation: localhost:5678"
    echo ""
    echo "Domain Configuration:"
    echo "- n8n: https://$DOMAIN"
    echo "- Login: admin / spr_n8n_2025_admin"
    echo ""
    echo "Next Steps:"
    echo "1. Verify domain DNS points to this server"
    echo "2. Run: sudo ./scripts/setup-nginx-ssl.sh"
    echo "3. Configure Rclone for backups: rclone config"
    echo "4. Test backup script: ./scripts/backup-daily.sh"
    echo ""
    echo "Log files:"
    echo "- Docker logs: docker-compose logs -f [service]"
    echo "- Backup logs: $SPRNOVO_DIR/logs/backup.log"
    echo ""
}

# Main execution
main() {
    cd $SPRNOVO_DIR
    
    check_directory
    stop_old_containers
    migrate_database
    start_sprnovo
    restore_database
    setup_backup
    verify_deployment
    print_summary
    
    log "=== SPRNOVO Deployment Completed Successfully ==="
}

# Execute main function
main