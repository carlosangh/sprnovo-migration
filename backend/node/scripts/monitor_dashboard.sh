#!/bin/bash

# ==========================================
# DASHBOARD DE MONITORAMENTO SPR
# Monitoramento em tempo real dos serviços
# ==========================================

set -u  # Tratar variáveis não definidas como erro

# ==========================================
# CONFIGURAÇÃO
# ==========================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# URLs e configurações
BACKEND_URL="${BACKEND_URL:-http://localhost:3002}"
EVO_URL="${EVO_URL:-http://localhost:8080}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-3}"

# ==========================================
# FUNÇÕES AUXILIARES
# ==========================================

# Fazer requisição HTTP silenciosa
silent_request() {
    local url=$1
    curl -s -w "HTTP_STATUS:%{http_code}" --max-time 5 "$url" 2>/dev/null
}

# Obter status de um serviço
get_service_status() {
    local url=$1
    local response=$(silent_request "$url")
    local status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2 2>/dev/null)
    local body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$status" = "200" ]; then
        echo "🟢 ONLINE"
    elif [ -n "$status" ]; then
        echo "🟡 HTTP $status"
    else
        echo "🔴 OFFLINE"
    fi
}

# Obter uptime do backend
get_backend_uptime() {
    local response=$(silent_request "$BACKEND_URL/health")
    local body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    local uptime=$(echo "$body" | grep -o '"uptime":[0-9.]*' | cut -d: -f2 2>/dev/null)
    
    if [ -n "$uptime" ]; then
        local hours=$(echo "$uptime / 3600" | bc 2>/dev/null || echo "0")
        local minutes=$(echo "($uptime % 3600) / 60" | bc 2>/dev/null || echo "0")
        echo "${hours}h ${minutes}m"
    else
        echo "N/A"
    fi
}

# Obter contagem de instâncias Evolution
get_evolution_instances() {
    if [ -z "${EVO_APIKEY:-}" ]; then
        echo "N/A (sem APIKEY)"
        return
    fi
    
    local instances=$(curl -s -H "apikey: $EVO_APIKEY" "$EVO_URL/instance/fetchInstances" 2>/dev/null)
    if [ -n "$instances" ] && [ "$instances" != "[]" ]; then
        local count=$(echo "$instances" | grep -o '"instanceName"' | wc -l 2>/dev/null || echo "0")
        echo "$count instâncias"
    else
        echo "0 instâncias"
    fi
}

# Obter métricas do sistema
get_system_metrics() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f%%", ($3/$2) * 100.0}' 2>/dev/null || echo "N/A")
    local disk_usage=$(df / | tail -1 | awk '{print $5}' 2>/dev/null || echo "N/A")
    
    echo "CPU: $cpu_usage% | RAM: $mem_usage | Disco: $disk_usage"
}

# Testar endpoints principais
test_endpoints() {
    local endpoints=(
        "$BACKEND_URL/health"
        "$BACKEND_URL/api/status"
        "$BACKEND_URL/api/offers"
        "$BACKEND_URL/api/whatsapp/health"
    )
    
    echo -e "${WHITE}ENDPOINTS:${NC}"
    for endpoint in "${endpoints[@]}"; do
        local status=$(get_service_status "$endpoint")
        local path=$(echo "$endpoint" | sed "s|$BACKEND_URL||")
        printf "  %-25s %s\n" "$path" "$status"
    done
}

# Mostrar logs recentes
show_recent_activity() {
    echo -e "${WHITE}ATIVIDADE RECENTE:${NC}"
    
    # Se existir arquivo de log do backend
    if [ -f "/tmp/spr_backend.log" ]; then
        tail -5 "/tmp/spr_backend.log" 2>/dev/null | while read line; do
            echo "  📝 $line"
        done
    else
        echo "  📝 Logs não disponíveis"
    fi
}

# ==========================================
# DASHBOARD PRINCIPAL
# ==========================================

show_dashboard() {
    clear
    
    # Header
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║               🚀 SPR MONITORING DASHBOARD                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}Atualizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo
    
    # Status dos serviços principais
    echo -e "${WHITE}SERVIÇOS PRINCIPAIS:${NC}"
    printf "  %-20s %s\n" "Backend SPR:" "$(get_service_status "$BACKEND_URL/health")"
    printf "  %-20s %s\n" "Evolution API:" "$(get_service_status "$EVO_URL")"
    printf "  %-20s %s\n" "WhatsApp Service:" "$(get_service_status "$BACKEND_URL/api/whatsapp/health")"
    echo
    
    # Métricas
    echo -e "${WHITE}MÉTRICAS:${NC}"
    printf "  %-20s %s\n" "Backend Uptime:" "$(get_backend_uptime)"
    printf "  %-20s %s\n" "Instâncias WA:" "$(get_evolution_instances)"
    printf "  %-20s %s\n" "Sistema:" "$(get_system_metrics)"
    echo
    
    # Endpoints
    test_endpoints
    echo
    
    # Atividade recente
    show_recent_activity
    echo
    
    # Instruções
    echo -e "${YELLOW}Comandos disponíveis:${NC}"
    echo "  • ./scripts/evo_test.sh test    - Executar testes completos"
    echo "  • ./scripts/evo_test.sh create  - Criar nova instância WhatsApp"
    echo "  • ./scripts/evo_test.sh monitor - Monitor avançado"
    echo "  • Ctrl+C                       - Sair"
    echo
    echo -e "${CYAN}Próxima atualização em ${REFRESH_INTERVAL}s...${NC}"
}

# ==========================================
# LOOP PRINCIPAL
# ==========================================

main() {
    trap 'echo -e "\n${CYAN}Dashboard encerrado.${NC}"; exit 0' INT
    
    echo -e "${GREEN}Iniciando Dashboard SPR...${NC}"
    sleep 1
    
    while true; do
        show_dashboard
        sleep "$REFRESH_INTERVAL"
    done
}

# Verificar se bc está disponível para cálculos
if ! command -v bc &> /dev/null; then
    echo "Instalando bc para cálculos..."
fi

# Executar dashboard
main "$@"