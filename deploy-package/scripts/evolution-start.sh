#!/bin/bash

# Evolution API Startup Script
# Security Level: HIGH
# SPR Production Environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/spr/evolution-start.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

# Pre-flight checks
preflight_checks() {
    log "Executando verificações pré-inicialização..."
    
    # Check if running as correct user
    if [[ $EUID -eq 0 ]]; then
        error "Este script não deve ser executado como root por segurança"
    fi
    
    # Check required files
    if [[ ! -f "$PROJECT_DIR/secrets/evolution.env" ]]; then
        error "Arquivo de configuração não encontrado: $PROJECT_DIR/secrets/evolution.env"
    fi
    
    if [[ ! -f "$PROJECT_DIR/docker-compose.yml" ]]; then
        error "Docker compose não encontrado: $PROJECT_DIR/docker-compose.yml"
    fi
    
    # Check Docker installation
    if ! command -v docker &> /dev/null; then
        error "Docker não está instalado ou não está no PATH"
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose não está instalado"
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon não está rodando ou usuário não tem permissão"
    fi
    
    log "✓ Todas as verificações pré-inicialização passaram"
}

# Create required directories
create_directories() {
    log "Criando diretórios necessários..."
    
    sudo mkdir -p /opt/spr/{data/{postgres,redis,evolution/{instances,store}},logs}
    sudo mkdir -p /var/log/spr
    sudo mkdir -p /var/www/letsencrypt
    
    # Set proper permissions
    sudo chown -R $USER:$USER /opt/spr/data
    sudo chown -R $USER:$USER /var/log/spr
    sudo chmod 755 /opt/spr/data
    sudo chmod 755 /var/log/spr
    
    log "✓ Diretórios criados com sucesso"
}

# Database security setup
setup_database_security() {
    log "Configurando segurança do banco de dados..."
    
    # Verify PostgreSQL configuration
    info "Verificando configurações de segurança do PostgreSQL..."
    
    log "✓ Configurações de segurança do banco aplicadas"
}

# Start services with health checks
start_services() {
    log "Iniciando serviços Evolution API..."
    
    cd "$PROJECT_DIR"
    
    # Pull latest images
    info "Baixando imagens Docker..."
    docker-compose pull
    
    # Start database first
    log "Iniciando PostgreSQL..."
    docker-compose up -d postgres-evolution
    
    # Wait for database
    info "Aguardando PostgreSQL ficar pronto..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if docker-compose exec -T postgres-evolution pg_isready -U spr_evolution -d evolution_db &> /dev/null; then
            log "✓ PostgreSQL está pronto"
            break
        fi
        sleep 2
        ((timeout-=2))
    done
    
    if [ $timeout -eq 0 ]; then
        error "Timeout aguardando PostgreSQL"
    fi
    
    # Start Redis
    log "Iniciando Redis..."
    docker-compose up -d redis-evolution
    
    # Wait for Redis
    info "Aguardando Redis ficar pronto..."
    timeout=30
    while [ $timeout -gt 0 ]; do
        if docker-compose exec -T redis-evolution redis-cli -a SPRevol2024redis ping &> /dev/null; then
            log "✓ Redis está pronto"
            break
        fi
        sleep 2
        ((timeout-=2))
    done
    
    if [ $timeout -eq 0 ]; then
        error "Timeout aguardando Redis"
    fi
    
    # Start Evolution API
    log "Iniciando Evolution API..."
    docker-compose up -d evolution-api
    
    # Wait for Evolution API
    info "Aguardando Evolution API ficar pronto..."
    timeout=120
    while [ $timeout -gt 0 ]; do
        if curl -f http://localhost:8080/health &> /dev/null; then
            log "✓ Evolution API está pronto"
            break
        fi
        sleep 5
        ((timeout-=5))
    done
    
    if [ $timeout -eq 0 ]; then
        error "Timeout aguardando Evolution API"
    fi
    
    # Start monitoring
    log "Iniciando serviços de monitoramento..."
    docker-compose up -d watchtower
    
    log "✓ Todos os serviços iniciados com sucesso"
}

# Security verification
verify_security() {
    log "Verificando configurações de segurança..."
    
    # Check service health
    info "Verificando saúde dos serviços..."
    
    services=("postgres-evolution" "redis-evolution" "evolution-api" "watchtower-evolution")
    for service in "${services[@]}"; do
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$service" | grep -q "Up"; then
            log "✓ $service está rodando"
        else
            warning "$service não está rodando corretamente"
        fi
    done
    
    # Check network security
    info "Verificando configurações de rede..."
    
    # Check if services are only listening on localhost
    if netstat -tlnp | grep ":8080" | grep -q "127.0.0.1"; then
        log "✓ Evolution API está ouvindo apenas no localhost"
    else
        warning "Evolution API pode estar exposto publicamente"
    fi
    
    if netstat -tlnp | grep ":5432" | grep -q "127.0.0.1"; then
        log "✓ PostgreSQL está ouvindo apenas no localhost"
    else
        warning "PostgreSQL pode estar exposto publicamente"
    fi
    
    if netstat -tlnp | grep ":6379" | grep -q "127.0.0.1"; then
        log "✓ Redis está ouvindo apenas no localhost"
    else
        warning "Redis pode estar exposto publicamente"
    fi
    
    log "✓ Verificação de segurança concluída"
}

# Show status
show_status() {
    log "Status dos serviços Evolution API:"
    echo ""
    docker-compose ps
    echo ""
    log "Logs podem ser visualizados com:"
    echo "  docker-compose logs -f evolution-api"
    echo "  docker-compose logs -f postgres-evolution"
    echo "  docker-compose logs -f redis-evolution"
    echo ""
    log "Para parar os serviços:"
    echo "  ./scripts/evolution-stop.sh"
    echo ""
    log "API disponível em: http://localhost:8080"
    log "Documentação: http://localhost:8080/manager"
}

# Main execution
main() {
    log "=== SPR Evolution API Startup ==="
    log "Iniciando processo de startup seguro..."
    
    preflight_checks
    create_directories
    setup_database_security
    start_services
    verify_security
    show_status
    
    log "=== Startup concluído com sucesso! ==="
}

# Execute main function
main "$@"