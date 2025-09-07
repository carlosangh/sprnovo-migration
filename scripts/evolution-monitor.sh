#!/bin/bash

# Evolution API Monitoring Script
# Security Level: HIGH
# SPR Production Environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/spr/evolution-monitor.log"

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
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

# Check service health
check_service_health() {
    local service=$1
    local expected_status="Up"
    
    cd "$PROJECT_DIR"
    
    local status=$(docker-compose ps "$service" 2>/dev/null | grep "$service" | awk '{print $4}' || echo "Down")
    
    if [[ "$status" == *"Up"* ]]; then
        echo "✓"
        return 0
    else
        echo "✗"
        return 1
    fi
}

# Check API endpoint
check_api_endpoint() {
    local endpoint=$1
    local expected_code=$2
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080$endpoint" 2>/dev/null || echo "000")
    
    if [[ "$response" == "$expected_code" ]]; then
        echo "✓"
        return 0
    else
        echo "✗ ($response)"
        return 1
    fi
}

# Check system resources
check_system_resources() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local memory_usage=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
    local disk_usage=$(df /opt/spr 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")
    
    echo "CPU: ${cpu_usage}% | RAM: ${memory_usage}% | Disk: ${disk_usage}%"
    
    # Check thresholds
    local alerts=0
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        warning "High CPU usage: ${cpu_usage}%"
        ((alerts++))
    fi
    
    if (( $(echo "$memory_usage > 85" | bc -l) )); then
        warning "High memory usage: ${memory_usage}%"
        ((alerts++))
    fi
    
    if [[ $disk_usage -gt 90 ]]; then
        warning "High disk usage: ${disk_usage}%"
        ((alerts++))
    fi
    
    return $alerts
}

# Check container stats
check_container_stats() {
    cd "$PROJECT_DIR"
    
    echo ""
    info "Container Resource Usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" || warning "Failed to get container stats"
}

# Check logs for errors
check_logs_for_errors() {
    cd "$PROJECT_DIR"
    
    local errors=0
    
    # Check Evolution API logs for errors in last 5 minutes
    local api_errors=$(docker-compose logs --since 5m evolution-api 2>/dev/null | grep -i error | wc -l || echo "0")
    if [[ $api_errors -gt 0 ]]; then
        warning "Found $api_errors errors in Evolution API logs (last 5 minutes)"
        ((errors++))
    fi
    
    # Check PostgreSQL logs for errors
    local db_errors=$(docker-compose logs --since 5m postgres-evolution 2>/dev/null | grep -i error | wc -l || echo "0")
    if [[ $db_errors -gt 0 ]]; then
        warning "Found $db_errors errors in PostgreSQL logs (last 5 minutes)"
        ((errors++))
    fi
    
    # Check Redis logs for errors
    local redis_errors=$(docker-compose logs --since 5m redis-evolution 2>/dev/null | grep -i error | wc -l || echo "0")
    if [[ $redis_errors -gt 0 ]]; then
        warning "Found $redis_errors errors in Redis logs (last 5 minutes)"
        ((errors++))
    fi
    
    return $errors
}

# Security checks
check_security() {
    local issues=0
    
    # Check if services are only listening on localhost
    if ! netstat -tlnp | grep ":8080" | grep -q "127.0.0.1"; then
        warning "Evolution API may be publicly exposed"
        ((issues++))
    fi
    
    if ! netstat -tlnp | grep ":5432" | grep -q "127.0.0.1"; then
        warning "PostgreSQL may be publicly exposed"
        ((issues++))
    fi
    
    if ! netstat -tlnp | grep ":6379" | grep -q "127.0.0.1"; then
        warning "Redis may be publicly exposed"
        ((issues++))
    fi
    
    # Check for suspicious connections
    local suspicious_connections=$(netstat -tn | grep :8080 | grep -v 127.0.0.1 | wc -l)
    if [[ $suspicious_connections -gt 0 ]]; then
        warning "Found $suspicious_connections external connections to Evolution API"
        ((issues++))
    fi
    
    return $issues
}

# Main monitoring function
run_monitoring() {
    local total_issues=0
    
    log "=== SPR Evolution API Health Monitor ==="
    
    # Service status
    echo ""
    info "Service Status:"
    printf "%-20s %s\n" "PostgreSQL:" "$(check_service_health postgres-evolution)"
    printf "%-20s %s\n" "Redis:" "$(check_service_health redis-evolution)"
    printf "%-20s %s\n" "Evolution API:" "$(check_service_health evolution-api)"
    printf "%-20s %s\n" "Watchtower:" "$(check_service_health watchtower)"
    
    # API endpoints
    echo ""
    info "API Endpoints:"
    printf "%-20s %s\n" "Health Check:" "$(check_api_endpoint '/health' '200')"
    printf "%-20s %s\n" "Manager:" "$(check_api_endpoint '/manager' '200')"
    
    # System resources
    echo ""
    info "System Resources:"
    check_system_resources || ((total_issues += $?))
    
    # Container stats
    check_container_stats
    
    # Log analysis
    echo ""
    info "Log Analysis (last 5 minutes):"
    check_logs_for_errors || ((total_issues += $?))
    
    # Security checks
    echo ""
    info "Security Status:"
    check_security || ((total_issues += $?))
    
    # Summary
    echo ""
    if [[ $total_issues -eq 0 ]]; then
        log "✓ All systems operational - no issues detected"
    else
        warning "Found $total_issues potential issues - review warnings above"
    fi
    
    echo ""
    log "=== Monitoring Complete ==="
    
    return $total_issues
}

# Watch mode
watch_mode() {
    log "Starting continuous monitoring mode (press Ctrl+C to stop)..."
    
    while true; do
        clear
        run_monitoring
        
        echo ""
        info "Refreshing in 30 seconds..."
        sleep 30
    done
}

# Show help
show_help() {
    echo "SPR Evolution API Monitor"
    echo ""
    echo "Uso: $0 [OPÇÃO]"
    echo ""
    echo "Opções:"
    echo "  --watch, -w       Modo de monitoramento contínuo"
    echo "  --once, -o        Executa uma verificação única (padrão)"
    echo "  --help, -h        Mostra esta ajuda"
    echo ""
}

# Main execution
main() {
    case "${1:-}" in
        --watch|-w)
            watch_mode
            ;;
        --once|-o|"")
            run_monitoring
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Opção inválida: $1. Use --help para ver as opções disponíveis."
            ;;
    esac
}

# Execute main function
main "$@"