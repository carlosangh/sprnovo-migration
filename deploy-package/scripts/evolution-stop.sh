#!/bin/bash

# Evolution API Shutdown Script
# Security Level: HIGH
# SPR Production Environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/spr/evolution-stop.log"

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

# Graceful shutdown function
graceful_shutdown() {
    log "Iniciando parada graceful dos serviços..."
    
    cd "$PROJECT_DIR"
    
    # Stop services in reverse order
    info "Parando Evolution API..."
    docker-compose stop evolution-api || warning "Falha ao parar Evolution API"
    
    info "Parando Watchtower..."
    docker-compose stop watchtower || warning "Falha ao parar Watchtower"
    
    info "Parando Redis..."
    docker-compose stop redis-evolution || warning "Falha ao parar Redis"
    
    info "Parando PostgreSQL..."
    docker-compose stop postgres-evolution || warning "Falha ao parar PostgreSQL"
    
    log "✓ Parada graceful concluída"
}

# Force shutdown function
force_shutdown() {
    log "Executando parada forçada dos serviços..."
    
    cd "$PROJECT_DIR"
    
    info "Forçando parada de todos os containers..."
    docker-compose down --timeout 30
    
    log "✓ Parada forçada concluída"
}

# Clean shutdown with data preservation
clean_shutdown() {
    log "Executando limpeza segura (preservando dados)..."
    
    cd "$PROJECT_DIR"
    
    # Stop and remove containers but keep volumes
    docker-compose down --remove-orphans
    
    # Clean up unused networks
    docker network prune -f
    
    log "✓ Limpeza segura concluída"
}

# Show help
show_help() {
    echo "SPR Evolution API Stop Script"
    echo ""
    echo "Uso: $0 [OPÇÃO]"
    echo ""
    echo "Opções:"
    echo "  --graceful, -g    Parada graceful (padrão)"
    echo "  --force, -f       Parada forçada"
    echo "  --clean, -c       Limpeza segura (remove containers, preserva dados)"
    echo "  --help, -h        Mostra esta ajuda"
    echo ""
}

# Check running status
check_status() {
    cd "$PROJECT_DIR"
    
    if docker-compose ps | grep -q "Up"; then
        return 0  # Services are running
    else
        return 1  # No services running
    fi
}

# Main execution
main() {
    log "=== SPR Evolution API Shutdown ==="
    
    cd "$PROJECT_DIR"
    
    # Check if services are running
    if ! check_status; then
        log "Nenhum serviço Evolution API está rodando"
        exit 0
    fi
    
    # Parse command line arguments
    case "${1:-}" in
        --graceful|-g|"")
            graceful_shutdown
            ;;
        --force|-f)
            force_shutdown
            ;;
        --clean|-c)
            clean_shutdown
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Opção inválida: $1. Use --help para ver as opções disponíveis."
            ;;
    esac
    
    # Verify shutdown
    info "Verificando se todos os serviços pararam..."
    sleep 5
    
    if ! check_status; then
        log "✓ Todos os serviços Evolution API foram parados com sucesso"
    else
        warning "Alguns serviços ainda podem estar rodando:"
        docker-compose ps
    fi
    
    log "=== Shutdown concluído ==="
}

# Execute main function
main "$@"