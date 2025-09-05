#!/bin/bash

# 🔍 SPR - Validador de Endpoints Críticos
# Valida que endpoints retornam dados reais com provenance comprovada
# Verifica integridade dos dados e detecção de mocks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/opt/spr"
LOG_DIR="$PROJECT_ROOT/logs"
VALIDATOR_LOG="$LOG_DIR/endpoint-validator.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Configurações
TIMEOUT=15
PRODUCTION_DOMAIN="www.royalnegociosagricolas.com.br"

# Contadores
TOTAL_ENDPOINTS=0
VALID_ENDPOINTS=0
INVALID_ENDPOINTS=0
MOCK_DETECTED=0
declare -A ENDPOINT_RESULTS
declare -A ENDPOINT_TIMING
declare -A ENDPOINT_ERRORS

# Endpoints críticos para validação
declare -A CRITICAL_ENDPOINTS
CRITICAL_ENDPOINTS=(
    ["/api/status"]="Status do sistema com dados reais"
    ["/api/metrics"]="Métricas agregadas de produção"
    ["/api/commodities/dashboard/summary"]="Dashboard baseado em dados_mercado"
    ["/api/offer-management?status=ativa"]="Ofertas ativas reais"
    ["/api/whatsapp/qr-code"]="QR Code WhatsApp real"
    ["/api/health"]="Health check com dados reais"
    ["/api/data-provenance"]="Prova de origem dos dados"
    ["/api/database/stats"]="Estatísticas do banco de dados"
)

# Indicadores de dados reais vs mock
REAL_DATA_INDICATORS=(
    "timestamp"
    "created_at"
    "updated_at"
    "id"
    "count"
    "total"
    "real_time"
    "production"
    "live"
)

MOCK_DATA_INDICATORS=(
    "mock"
    "fake"
    "test"
    "dummy"
    "placeholder"
    "lorem"
    "example"
    "sample"
    "fixture"
    "seed"
)

# Função de banner
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "████████████████████████████████████████████████████████████████"
    echo "██                                                            ██"
    echo "██    🔍 SPR - VALIDADOR DE ENDPOINTS CRÍTICOS               ██"
    echo "██    🌐 Verificação de Dados Reais em Produção              ██"
    echo "██                                                            ██"
    echo "██    ✅ Dados Reais | ❌ Mocks Detectados                   ██"
    echo "██                                                            ██"
    echo "████████████████████████████████████████████████████████████████"
    echo -e "${NC}"
    echo -e "${CYAN}📅 $TIMESTAMP${NC}"
    echo -e "${CYAN}📍 Validando endpoints de: $PROJECT_ROOT${NC}"
    echo -e "${CYAN}📝 Log: $VALIDATOR_LOG${NC}"
    echo ""
}

# Função de logging
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$VALIDATOR_LOG"
}

# Função para detectar se servidor está rodando
detect_running_services() {
    echo -e "${BOLD}${YELLOW}🔍 DETECTANDO SERVIÇOS ATIVOS${NC}"
    echo "============================================================"
    
    local backend_running=false
    local whatsapp_running=false
    local frontend_running=false
    
    # Verificar portas
    if netstat -tuln 2>/dev/null | grep -q ":3002"; then
        echo -e "${GREEN}✅ Backend detectado na porta 3002${NC}"
        backend_running=true
    fi
    
    if netstat -tuln 2>/dev/null | grep -q ":3003"; then
        echo -e "${GREEN}✅ WhatsApp Server detectado na porta 3003${NC}"
        whatsapp_running=true
    fi
    
    if netstat -tuln 2>/dev/null | grep -q ":3000"; then
        echo -e "${GREEN}✅ Frontend detectado na porta 3000${NC}"
        frontend_running=true
    fi
    
    # Verificar processos
    if pgrep -f "backend_server" > /dev/null; then
        echo -e "${GREEN}✅ Processo backend_server ativo${NC}"
    fi
    
    if pgrep -f "whatsapp_server" > /dev/null; then
        echo -e "${GREEN}✅ Processo whatsapp_server ativo${NC}"
    fi
    
    if pgrep -f "npm.*start\|yarn.*start" > /dev/null; then
        echo -e "${GREEN}✅ Processo frontend ativo${NC}"
    fi
    
    echo ""
}

# Função para validar resposta de endpoint
validate_endpoint_response() {
    local endpoint=$1
    local response_body=$2
    local http_code=$3
    local description=$4
    
    local real_score=0
    local mock_score=0
    local total_checks=0
    
    echo -e "${CYAN}🔍 Analisando resposta de: $endpoint${NC}"
    echo -e "${CYAN}   Descrição: $description${NC}"
    echo -e "${CYAN}   HTTP Code: $http_code${NC}"
    
    # Verificar se resposta está vazia
    if [[ -z "$response_body" || "$response_body" == "null" ]]; then
        echo -e "${YELLOW}   ⚠️  Resposta vazia ou null${NC}"
        ENDPOINT_ERRORS["$endpoint"]="Empty response"
        return 1
    fi
    
    # Buscar indicadores de dados reais
    for indicator in "${REAL_DATA_INDICATORS[@]}"; do
        ((total_checks++))
        if echo "$response_body" | grep -qi "$indicator"; then
            ((real_score++))
            echo -e "${GREEN}   ✅ Indicador real encontrado: $indicator${NC}"
            log_message "INFO" "Real data indicator found in $endpoint: $indicator"
        fi
    done
    
    # Buscar indicadores de dados mock
    for indicator in "${MOCK_DATA_INDICATORS[@]}"; do
        if echo "$response_body" | grep -qi "$indicator"; then
            ((mock_score++))
            echo -e "${RED}   🚨 Indicador mock encontrado: $indicator${NC}"
            log_message "WARNING" "Mock data indicator found in $endpoint: $indicator"
        fi
    done
    
    # Validações específicas por endpoint
    case "$endpoint" in
        *"/api/status")
            if echo "$response_body" | grep -q "connected\|active\|running\|online"; then
                ((real_score++))
                echo -e "${GREEN}   ✅ Status parece real (connected/active)${NC}"
            fi
            ;;
        *"/api/metrics")
            if echo "$response_body" | grep -Eq "[0-9]{10,}"; then # Timestamps unix
                ((real_score++))
                echo -e "${GREEN}   ✅ Timestamps unix detectados${NC}"
            fi
            if echo "$response_body" | grep -Eq '"count":\s*[1-9][0-9]*'; then
                ((real_score++))
                echo -e "${GREEN}   ✅ Contadores com valores reais${NC}"
            fi
            ;;
        *"/api/commodities"*)
            if echo "$response_body" | grep -qi "soja\|milho\|trigo\|café"; then
                ((real_score++))
                echo -e "${GREEN}   ✅ Commodities reais detectadas${NC}"
            fi
            if echo "$response_body" | grep -Eq '"price":\s*[0-9]+\.[0-9]+'; then
                ((real_score++))
                echo -e "${GREEN}   ✅ Preços com formato real${NC}"
            fi
            ;;
        *"/api/offer-management"*)
            if echo "$response_body" | grep -q "ativa\|pendente\|aprovada"; then
                ((real_score++))
                echo -e "${GREEN}   ✅ Status de ofertas reais${NC}"
            fi
            ;;
        *"/api/whatsapp/qr-code"*)
            if [[ ${#response_body} -gt 100 ]]; then
                ((real_score++))
                echo -e "${GREEN}   ✅ QR Code parece conter dados reais${NC}"
            fi
            ;;
    esac
    
    # Calcular score final
    local real_percentage=0
    if [[ $total_checks -gt 0 ]]; then
        real_percentage=$((real_score * 100 / total_checks))
    fi
    
    echo -e "${CYAN}   📊 Score de dados reais: $real_score/$total_checks ($real_percentage%)${NC}"
    echo -e "${CYAN}   📊 Indicadores mock: $mock_score${NC}"
    
    # Determinar se endpoint é válido
    if [[ $mock_score -gt 0 ]]; then
        echo -e "${RED}   ❌ MOCK DETECTADO - Endpoint inválido${NC}"
        ENDPOINT_RESULTS["$endpoint"]="MOCK_DETECTED"
        ((MOCK_DETECTED++))
        return 1
    elif [[ $real_percentage -ge 30 ]]; then
        echo -e "${GREEN}   ✅ DADOS REAIS - Endpoint válido${NC}"
        ENDPOINT_RESULTS["$endpoint"]="VALID"
        return 0
    else
        echo -e "${YELLOW}   ⚠️  DADOS INSUFICIENTES - Endpoint suspeito${NC}"
        ENDPOINT_RESULTS["$endpoint"]="INSUFFICIENT_DATA"
        ENDPOINT_ERRORS["$endpoint"]="Insufficient real data indicators"
        return 1
    fi
}

# Função para testar endpoint individual
test_endpoint() {
    local base_url=$1
    local endpoint=$2
    local description=$3
    
    ((TOTAL_ENDPOINTS++))
    
    local full_url="$base_url$endpoint"
    echo -e "${BOLD}${PURPLE}🌐 TESTANDO: $endpoint${NC}"
    echo "------------------------------------------------------------"
    
    log_message "INFO" "Testing endpoint: $full_url"
    
    local start_time=$(date +%s%3N)
    local temp_file=$(mktemp)
    local response_file=$(mktemp)
    
    # Fazer requisição
    local response=$(curl -s -w '%{http_code},%{time_total},%{size_download}' \
        --max-time $TIMEOUT \
        --connect-timeout 10 \
        -H "Accept: application/json" \
        -H "User-Agent: SPR-Endpoint-Validator/1.0" \
        "$full_url" -o "$response_file" 2>"$temp_file")
    
    local curl_exit_code=$?
    local end_time=$(date +%s%3N)
    
    if [[ $curl_exit_code -eq 0 ]]; then
        local http_code=$(echo "$response" | cut -d',' -f1)
        local time_total=$(echo "$response" | cut -d',' -f2)
        local size_download=$(echo "$response" | cut -d',' -f3)
        local response_body=$(cat "$response_file")
        
        # Converter tempo para ms
        local time_ms=$(echo "$time_total * 1000" | bc -l 2>/dev/null || echo "0")
        time_ms=${time_ms%.*}
        
        ENDPOINT_TIMING["$endpoint"]="${time_ms}ms"
        
        echo -e "${CYAN}📊 Resposta recebida: HTTP $http_code (${time_ms}ms, ${size_download} bytes)${NC}"
        
        if [[ "$http_code" =~ ^(200|201|202)$ ]]; then
            # Validar conteúdo da resposta
            if validate_endpoint_response "$endpoint" "$response_body" "$http_code" "$description"; then
                ((VALID_ENDPOINTS++))
                log_message "SUCCESS" "Endpoint $endpoint validation passed"
            else
                ((INVALID_ENDPOINTS++))
                log_message "WARNING" "Endpoint $endpoint validation failed"
            fi
        else
            echo -e "${RED}❌ HTTP $http_code - Status inválido${NC}"
            ENDPOINT_RESULTS["$endpoint"]="HTTP_ERROR"
            ENDPOINT_ERRORS["$endpoint"]="HTTP $http_code"
            ((INVALID_ENDPOINTS++))
            log_message "ERROR" "Endpoint $endpoint returned HTTP $http_code"
        fi
        
    else
        local error_msg=$(cat "$temp_file")
        echo -e "${RED}❌ Erro de conexão: $error_msg${NC}"
        ENDPOINT_RESULTS["$endpoint"]="CONNECTION_ERROR"
        ENDPOINT_ERRORS["$endpoint"]="Connection failed: $error_msg"
        ((INVALID_ENDPOINTS++))
        log_message "ERROR" "Endpoint $endpoint connection failed: $error_msg"
    fi
    
    # Limpeza
    rm -f "$temp_file" "$response_file"
    echo ""
}

# Função para testar todos os endpoints críticos
test_all_endpoints() {
    echo -e "${BOLD}${YELLOW}🌐 TESTANDO ENDPOINTS CRÍTICOS${NC}"
    echo "============================================================"
    
    local base_urls=(
        "http://localhost:3002"
        "http://localhost:3003"
        "https://$PRODUCTION_DOMAIN"
    )
    
    for base_url in "${base_urls[@]}"; do
        echo -e "${BOLD}${CYAN}🔗 Testando base URL: $base_url${NC}"
        echo "------------------------------------------------------------"
        
        for endpoint in "${!CRITICAL_ENDPOINTS[@]}"; do
            test_endpoint "$base_url" "$endpoint" "${CRITICAL_ENDPOINTS[$endpoint]}"
        done
        
        echo ""
    done
}

# Função para testar WebSocket
test_websocket() {
    echo -e "${BOLD}${YELLOW}🔌 TESTANDO WEBSOCKET CONNECTION${NC}"
    echo "============================================================"
    
    local ws_url="wss://$PRODUCTION_DOMAIN/socket.io"
    echo -e "${CYAN}🔍 Testando WebSocket: $ws_url${NC}"
    
    # Usar curl para testar handshake HTTP primeiro
    local handshake_response=$(curl -s --max-time 10 \
        -H "Connection: Upgrade" \
        -H "Upgrade: websocket" \
        -H "Sec-WebSocket-Version: 13" \
        -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
        -I "https://$PRODUCTION_DOMAIN/socket.io/?transport=websocket" 2>/dev/null)
    
    if echo "$handshake_response" | grep -q "101\|200"; then
        echo -e "${GREEN}✅ WebSocket handshake bem-sucedido${NC}"
        log_message "SUCCESS" "WebSocket handshake successful"
    else
        echo -e "${RED}❌ WebSocket handshake falhou${NC}"
        echo -e "${YELLOW}   Resposta: $handshake_response${NC}"
        log_message "ERROR" "WebSocket handshake failed"
    fi
    
    echo ""
}

# Função para verificar banco de dados
check_database_connection() {
    echo -e "${BOLD}${YELLOW}🗄️  VERIFICANDO CONEXÃO COM BANCO DE DADOS${NC}"
    echo "============================================================"
    
    # Verificar se arquivo SQLite existe
    local db_file="$PROJECT_ROOT/spr_broadcast.db"
    if [[ -f "$db_file" ]]; then
        local db_size=$(du -h "$db_file" | cut -f1)
        echo -e "${GREEN}✅ Banco de dados encontrado: $db_file ($db_size)${NC}"
        
        # Verificar se banco não está vazio
        local table_count=$(sqlite3 "$db_file" "SELECT count(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
        echo -e "${CYAN}📊 Número de tabelas: $table_count${NC}"
        
        if [[ $table_count -gt 0 ]]; then
            echo -e "${GREEN}✅ Banco de dados parece ter dados reais${NC}"
            log_message "SUCCESS" "Database appears to contain real data"
        else
            echo -e "${YELLOW}⚠️  Banco de dados pode estar vazio${NC}"
            log_message "WARNING" "Database may be empty"
        fi
        
    else
        echo -e "${RED}❌ Banco de dados não encontrado: $db_file${NC}"
        log_message "ERROR" "Database file not found: $db_file"
    fi
    
    echo ""
}

# Função para gerar relatório final
generate_report() {
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${BOLD}${WHITE}📊 RELATÓRIO DE VALIDAÇÃO DE ENDPOINTS${NC}"
    echo "============================================================"
    
    echo -e "${CYAN}📅 Início: $TIMESTAMP${NC}"
    echo -e "${CYAN}📅 Fim: $end_time${NC}"
    echo -e "${CYAN}🌐 Endpoints testados: $TOTAL_ENDPOINTS${NC}"
    echo -e "${GREEN}✅ Endpoints válidos: $VALID_ENDPOINTS${NC}"
    echo -e "${RED}❌ Endpoints inválidos: $INVALID_ENDPOINTS${NC}"
    echo -e "${RED}🚨 Mocks detectados: $MOCK_DETECTED${NC}"
    echo ""
    
    # Taxa de validade
    local validity_rate=0
    if [[ $TOTAL_ENDPOINTS -gt 0 ]]; then
        validity_rate=$((VALID_ENDPOINTS * 100 / TOTAL_ENDPOINTS))
    fi
    
    echo -e "${BOLD}🎯 Taxa de Validade: ${validity_rate}%${NC}"
    
    if [[ $MOCK_DETECTED -eq 0 && $validity_rate -ge 80 ]]; then
        echo -e "${BOLD}${GREEN}🎉 SISTEMA VALIDADO: Endpoints retornando dados reais!${NC}"
        log_message "SUCCESS" "System validated - endpoints returning real data"
    elif [[ $MOCK_DETECTED -gt 0 ]]; then
        echo -e "${BOLD}${RED}🚨 MOCKS DETECTADOS: Sistema não validado para produção!${NC}"
        log_message "CRITICAL" "Mocks detected - system not validated for production"
    else
        echo -e "${BOLD}${YELLOW}⚠️  VALIDAÇÃO PARCIAL: Alguns endpoints podem ter problemas${NC}"
        log_message "WARNING" "Partial validation - some endpoints may have issues"
    fi
    
    # Detalhes por endpoint
    echo ""
    echo -e "${BOLD}📋 DETALHES POR ENDPOINT:${NC}"
    echo "------------------------------------------------------------"
    
    for endpoint in "${!ENDPOINT_RESULTS[@]}"; do
        local result=${ENDPOINT_RESULTS[$endpoint]}
        local timing=${ENDPOINT_TIMING[$endpoint]:-"N/A"}
        local error=${ENDPOINT_ERRORS[$endpoint]:-""}
        
        case $result in
            "VALID")
                echo -e "${GREEN}✅ $endpoint - $timing${NC}"
                ;;
            "MOCK_DETECTED")
                echo -e "${RED}🚨 $endpoint - MOCK DETECTADO${NC}"
                ;;
            "HTTP_ERROR")
                echo -e "${RED}❌ $endpoint - $error${NC}"
                ;;
            "CONNECTION_ERROR")
                echo -e "${RED}🔌 $endpoint - Erro de conexão${NC}"
                ;;
            "INSUFFICIENT_DATA")
                echo -e "${YELLOW}⚠️  $endpoint - Dados insuficientes${NC}"
                ;;
            *)
                echo -e "${YELLOW}❓ $endpoint - Status desconhecido${NC}"
                ;;
        esac
    done
    
    # Salvar relatório
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    local report_file="$LOG_DIR/endpoint-validation-$(date +%Y%m%d_%H%M%S).txt"
    cat > "$report_file" 2>/dev/null << EOF || true
SPR Endpoint Validation Report
==============================
Data: $TIMESTAMP - $end_time

RESUMO:
- Endpoints testados: $TOTAL_ENDPOINTS
- Endpoints válidos: $VALID_ENDPOINTS
- Endpoints inválidos: $INVALID_ENDPOINTS
- Mocks detectados: $MOCK_DETECTED
- Taxa de validade: ${validity_rate}%

STATUS: $(if [[ $MOCK_DETECTED -eq 0 && $validity_rate -ge 80 ]]; then echo "VALIDATED"; else echo "NOT VALIDATED"; fi)

DETALHES POR ENDPOINT:
EOF

    for endpoint in "${!ENDPOINT_RESULTS[@]}"; do
        echo "$endpoint: ${ENDPOINT_RESULTS[$endpoint]}" >> "$report_file" 2>/dev/null || true
    done
    
    echo -e "${CYAN}📄 Relatório salvo em: $report_file${NC}"
    echo ""
    
    # Exit code baseado na validação
    if [[ $MOCK_DETECTED -eq 0 && $validity_rate -ge 80 ]]; then
        echo -e "${GREEN}✅ VALIDAÇÃO APROVADA: Sistema seguro para produção${NC}"
        exit 0
    else
        echo -e "${RED}❌ VALIDAÇÃO REPROVADA: Sistema não seguro para produção${NC}"
        exit 1
    fi
}

# Função principal
main() {
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    show_banner
    
    log_message "INFO" "Starting endpoint validation"
    
    echo -e "${BOLD}${YELLOW}🔍 INICIANDO VALIDAÇÃO DE ENDPOINTS CRÍTICOS${NC}"
    echo "============================================================"
    
    detect_running_services
    test_all_endpoints
    test_websocket
    check_database_connection
    
    generate_report
}

# Trap para limpeza
trap 'echo -e "\n${YELLOW}🛑 Validação interrompida${NC}"; exit 130' SIGINT SIGTERM

# Executar
main "$@"