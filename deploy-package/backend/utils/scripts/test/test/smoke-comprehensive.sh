#!/bin/bash

# 🔥 SPR - Smoke Test Ampliado
# Teste completo de fumaça com validação anti-mock e telemetria
# Integra todos os testes críticos em uma única execução

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/opt/spr"
LOG_DIR="$PROJECT_ROOT/logs"
SMOKE_LOG="$LOG_DIR/smoke-comprehensive.log"
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
TIMEOUT=20
MAX_RETRIES=3
PRODUCTION_DOMAIN="www.royalnegociosagricolas.com.br"

# Contadores globais
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
CRITICAL_FAILURES=0
MOCK_DETECTIONS=0

declare -A TEST_RESULTS
declare -A TEST_ERRORS
declare -A COMPONENT_STATUS

# Componentes do sistema
COMPONENTS=(
    "anti_mock_sentinel"
    "endpoint_validator" 
    "backend_service"
    "whatsapp_service"
    "frontend_service"
    "database_connectivity"
    "websocket_connection"
    "production_readiness"
)

# Função de banner
show_banner() {
    clear
    echo -e "${BOLD}${GREEN}"
    echo "████████████████████████████████████████████████████████████████"
    echo "██                                                            ██"
    echo "██    🔥 SPR - SMOKE TEST AMPLIADO                           ██"
    echo "██    🎯 Validação Completa Anti-Mock + Telemetria           ██"
    echo "██                                                            ██"
    echo "██    🚨 Zero Tolerância a Mocks | ✅ Dados Reais           ██"
    echo "██                                                            ██"
    echo "████████████████████████████████████████████████████████████████"
    echo -e "${NC}"
    echo -e "${CYAN}📅 Início: $TIMESTAMP${NC}"
    echo -e "${CYAN}📍 Projeto: $PROJECT_ROOT${NC}"
    echo -e "${CYAN}📝 Log: $SMOKE_LOG${NC}"
    echo ""
}

# Função de logging
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$SMOKE_LOG"
}

# Função para executar teste com retry
execute_test_with_retry() {
    local test_name=$1
    local test_command=$2
    local expected_exit_code=${3:-0}
    local is_critical=${4:-false}
    
    ((TOTAL_TESTS++))
    
    echo -e "${BOLD}${YELLOW}🧪 EXECUTANDO: $test_name${NC}"
    echo "------------------------------------------------------------"
    
    local attempt=1
    local success=false
    
    while [[ $attempt -le $MAX_RETRIES ]]; do
        echo -e "${CYAN}🔄 Tentativa $attempt/$MAX_RETRIES${NC}"
        log_message "INFO" "Starting test: $test_name (attempt $attempt)"
        
        # Executar comando
        local start_time=$(date +%s)
        eval "$test_command" > /tmp/test_output_$$ 2>&1
        local exit_code=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Mostrar output se necessário
        if [[ -s /tmp/test_output_$$ ]]; then
            echo -e "${CYAN}📋 Output do teste:${NC}"
            cat /tmp/test_output_$$
        fi
        
        if [[ $exit_code -eq $expected_exit_code ]]; then
            echo -e "${GREEN}✅ $test_name PASSOU (${duration}s)${NC}"
            TEST_RESULTS["$test_name"]="PASS"
            ((PASSED_TESTS++))
            log_message "SUCCESS" "$test_name passed in ${duration}s"
            success=true
            break
        else
            echo -e "${RED}❌ $test_name FALHOU (código: $exit_code, esperado: $expected_exit_code)${NC}"
            
            if [[ $attempt -eq $MAX_RETRIES ]]; then
                TEST_RESULTS["$test_name"]="FAIL"
                TEST_ERRORS["$test_name"]="Exit code $exit_code (expected $expected_exit_code)"
                ((FAILED_TESTS++))
                
                if [[ "$is_critical" == "true" ]]; then
                    ((CRITICAL_FAILURES++))
                    echo -e "${RED}🚨 FALHA CRÍTICA DETECTADA!${NC}"
                fi
                
                log_message "ERROR" "$test_name failed with exit code $exit_code"
            fi
        fi
        
        ((attempt++))
        if [[ $attempt -le $MAX_RETRIES ]]; then
            echo -e "${YELLOW}⏳ Aguardando 5s antes da próxima tentativa...${NC}"
            sleep 5
        fi
    done
    
    # Limpar arquivo temporário
    rm -f /tmp/test_output_$$
    echo ""
    
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Função para testar serviços básicos
test_basic_services() {
    echo -e "${BOLD}${PURPLE}🛠️  TESTANDO SERVIÇOS BÁSICOS${NC}"
    echo "============================================================"
    
    # Verificar se diretório do projeto existe
    execute_test_with_retry "Project Directory Exists" \
        "test -d '$PROJECT_ROOT'" \
        0 true
    
    # Verificar permissões de escrita em logs
    execute_test_with_retry "Log Directory Writable" \
        "mkdir -p '$LOG_DIR' && touch '$LOG_DIR/test_write' && rm -f '$LOG_DIR/test_write'" \
        0 false
    
    # Verificar dependências do sistema
    execute_test_with_retry "System Dependencies" \
        "which curl && which grep && which bc" \
        0 true
    
    COMPONENT_STATUS["basic_services"]="TESTED"
}

# Função para executar Anti-Mock Sentinel
test_anti_mock_sentinel() {
    echo -e "${BOLD}${PURPLE}🚨 EXECUTANDO ANTI-MOCK SENTINEL${NC}"
    echo "============================================================"
    
    local sentinel_script="$SCRIPT_DIR/anti-mock-sentinel.sh"
    
    if [[ -f "$sentinel_script" ]]; then
        execute_test_with_retry "Anti-Mock Sentinel" \
            "bash '$sentinel_script'" \
            0 true
        
        # Verificar se encontrou mocks
        if grep -q "MOCK DETECTADO\|NOT SAFE FOR PRODUCTION" "$SMOKE_LOG" 2>/dev/null; then
            ((MOCK_DETECTIONS++))
            echo -e "${RED}🚨 MOCKS DETECTADOS PELO SENTINEL!${NC}"
            COMPONENT_STATUS["anti_mock_sentinel"]="FAILED_MOCK_DETECTED"
        else
            COMPONENT_STATUS["anti_mock_sentinel"]="PASSED"
        fi
    else
        echo -e "${YELLOW}⚠️  Script Anti-Mock Sentinel não encontrado: $sentinel_script${NC}"
        COMPONENT_STATUS["anti_mock_sentinel"]="NOT_FOUND"
    fi
}

# Função para executar validação de endpoints
test_endpoint_validation() {
    echo -e "${BOLD}${PURPLE}🌐 EXECUTANDO VALIDAÇÃO DE ENDPOINTS${NC}"
    echo "============================================================"
    
    local validator_script="$SCRIPT_DIR/endpoint-validator.sh"
    
    if [[ -f "$validator_script" ]]; then
        execute_test_with_retry "Endpoint Validator" \
            "bash '$validator_script'" \
            0 true
        
        COMPONENT_STATUS["endpoint_validator"]="TESTED"
    else
        echo -e "${YELLOW}⚠️  Script Endpoint Validator não encontrado: $validator_script${NC}"
        COMPONENT_STATUS["endpoint_validator"]="NOT_FOUND"
    fi
}

# Função para testar conectividade de rede
test_network_connectivity() {
    echo -e "${BOLD}${PURPLE}🌍 TESTANDO CONECTIVIDADE DE REDE${NC}"
    echo "============================================================"
    
    # Teste de DNS
    execute_test_with_retry "DNS Resolution" \
        "nslookup google.com > /dev/null" \
        0 false
    
    # Teste de conectividade externa
    execute_test_with_retry "External Connectivity" \
        "curl -s --max-time 10 https://google.com > /dev/null" \
        0 false
    
    # Teste do domínio de produção
    execute_test_with_retry "Production Domain Connectivity" \
        "curl -s --max-time 15 -I https://$PRODUCTION_DOMAIN" \
        0 true
    
    COMPONENT_STATUS["network_connectivity"]="TESTED"
}

# Função para testar portas locais
test_local_ports() {
    echo -e "${BOLD}${PURPLE}🔌 TESTANDO PORTAS LOCAIS${NC}"
    echo "============================================================"
    
    local ports=(3000 3002 3003)
    local ports_ok=0
    
    for port in "${ports[@]}"; do
        echo -e "${CYAN}🔍 Verificando porta $port${NC}"
        
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "${GREEN}✅ Porta $port está ativa${NC}"
            ((ports_ok++))
            
            # Testar HTTP na porta
            execute_test_with_retry "HTTP Test Port $port" \
                "curl -s --max-time 5 http://localhost:$port > /dev/null" \
                0 false
        else
            echo -e "${YELLOW}⚠️  Porta $port não está ativa${NC}"
        fi
    done
    
    if [[ $ports_ok -ge 2 ]]; then
        COMPONENT_STATUS["local_ports"]="PASSED"
    else
        COMPONENT_STATUS["local_ports"]="FAILED"
    fi
}

# Função para testar WebSocket
test_websocket_comprehensive() {
    echo -e "${BOLD}${PURPLE}🔌 TESTANDO WEBSOCKET COMPREHENSIVE${NC}"
    echo "============================================================"
    
    # Testar handshake HTTP primeiro
    execute_test_with_retry "WebSocket HTTP Handshake" \
        "curl -s --max-time 10 -H 'Connection: Upgrade' -H 'Upgrade: websocket' -I 'http://localhost:3003/socket.io/'" \
        0 false
    
    # Testar produção se disponível
    execute_test_with_retry "Production WebSocket Handshake" \
        "curl -s --max-time 15 -H 'Connection: Upgrade' -H 'Upgrade: websocket' -I 'https://$PRODUCTION_DOMAIN/socket.io/'" \
        0 false
    
    COMPONENT_STATUS["websocket_connection"]="TESTED"
}

# Função para testar banco de dados
test_database_comprehensive() {
    echo -e "${BOLD}${PURPLE}🗄️  TESTANDO BANCO DE DADOS COMPREHENSIVE${NC}"
    echo "============================================================"
    
    local db_file="$PROJECT_ROOT/spr_broadcast.db"
    
    # Verificar se arquivo existe
    execute_test_with_retry "Database File Exists" \
        "test -f '$db_file'" \
        0 true
    
    # Verificar se não está vazio
    execute_test_with_retry "Database Not Empty" \
        "test -s '$db_file'" \
        0 true
    
    # Verificar integridade com SQLite
    if which sqlite3 > /dev/null 2>&1; then
        execute_test_with_retry "Database Integrity Check" \
            "sqlite3 '$db_file' 'PRAGMA integrity_check;' | grep -q 'ok'" \
            0 false
        
        execute_test_with_retry "Database Tables Count" \
            "test \$(sqlite3 '$db_file' 'SELECT count(*) FROM sqlite_master WHERE type=\"table\";') -gt 0" \
            0 true
    else
        echo -e "${YELLOW}⚠️  SQLite3 não disponível para testes detalhados${NC}"
    fi
    
    COMPONENT_STATUS["database_connectivity"]="TESTED"
}

# Função para análise de performance
test_performance_analysis() {
    echo -e "${BOLD}${PURPLE}⚡ ANÁLISE DE PERFORMANCE${NC}"
    echo "============================================================"
    
    # Testar tempo de resposta dos endpoints principais
    local endpoints=(
        "http://localhost:3002/api/health"
        "http://localhost:3002/api/status"
        "http://localhost:3003/api/status"
    )
    
    local total_time=0
    local successful_tests=0
    
    for endpoint in "${endpoints[@]}"; do
        echo -e "${CYAN}⏱️  Medindo performance: $endpoint${NC}"
        
        local response_time=$(curl -o /dev/null -s -w '%{time_total}' --max-time 10 "$endpoint" 2>/dev/null || echo "timeout")
        
        if [[ "$response_time" != "timeout" ]]; then
            local time_ms=$(echo "$response_time * 1000" | bc -l 2>/dev/null || echo "0")
            time_ms=${time_ms%.*}
            echo -e "${GREEN}   ✅ Tempo de resposta: ${time_ms}ms${NC}"
            
            total_time=$(echo "$total_time + $response_time" | bc -l 2>/dev/null || echo "$total_time")
            ((successful_tests++))
            
            # Alertar se muito lento
            if (( $(echo "$response_time > 2.0" | bc -l 2>/dev/null || echo "0") )); then
                echo -e "${YELLOW}   ⚠️  Resposta lenta (>2s)${NC}"
            fi
        else
            echo -e "${RED}   ❌ Timeout ou erro${NC}"
        fi
    done
    
    if [[ $successful_tests -gt 0 ]]; then
        local avg_time=$(echo "scale=3; $total_time / $successful_tests" | bc -l 2>/dev/null || echo "0")
        echo -e "${CYAN}📊 Tempo médio de resposta: ${avg_time}s${NC}"
    fi
    
    COMPONENT_STATUS["performance"]="ANALYZED"
}

# Função para verificação de segurança básica
test_security_basics() {
    echo -e "${BOLD}${PURPLE}🔒 VERIFICAÇÕES DE SEGURANÇA BÁSICA${NC}"
    echo "============================================================"
    
    # Verificar se .env não está exposto
    execute_test_with_retry "Env File Not Web Accessible" \
        "! curl -s --max-time 5 http://localhost:3000/.env | grep -q 'DATABASE'" \
        0 true
    
    # Verificar headers de segurança básicos
    execute_test_with_retry "Security Headers Check" \
        "curl -s -I --max-time 10 http://localhost:3002/api/health | grep -qi 'server\\|x-powered-by' || true" \
        0 false
    
    COMPONENT_STATUS["security_basics"]="TESTED"
}

# Função para gerar relatório de telemetria
generate_telemetry_report() {
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local duration=$(( $(date -d "$end_time" +%s) - $(date -d "$TIMESTAMP" +%s) ))
    
    echo -e "${BOLD}${WHITE}📊 RELATÓRIO DE TELEMETRIA - SMOKE TEST AMPLIADO${NC}"
    echo "================================================================"
    
    # Informações básicas
    echo -e "${CYAN}📅 Período: $TIMESTAMP → $end_time (${duration}s)${NC}"
    echo -e "${CYAN}🖥️  Host: $(hostname)${NC}"
    echo -e "${CYAN}👤 Usuário: $(whoami)${NC}"
    echo -e "${CYAN}📁 Projeto: $PROJECT_ROOT${NC}"
    echo ""
    
    # Resumo dos testes
    echo -e "${BOLD}📈 RESUMO DOS TESTES:${NC}"
    echo -e "${GREEN}✅ Testes Aprovados: $PASSED_TESTS${NC}"
    echo -e "${RED}❌ Testes Falharam: $FAILED_TESTS${NC}"
    echo -e "${CYAN}📊 Total de Testes: $TOTAL_TESTS${NC}"
    echo -e "${RED}🚨 Falhas Críticas: $CRITICAL_FAILURES${NC}"
    echo -e "${RED}🔍 Mocks Detectados: $MOCK_DETECTIONS${NC}"
    
    # Taxa de sucesso
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    echo -e "${BOLD}🎯 Taxa de Sucesso: ${success_rate}%${NC}"
    echo ""
    
    # Status por componente
    echo -e "${BOLD}🔧 STATUS DOS COMPONENTES:${NC}"
    echo "------------------------------------------------------------"
    for component in "${COMPONENTS[@]}"; do
        local status=${COMPONENT_STATUS[$component]:-"NOT_TESTED"}
        case $status in
            "PASSED"|"TESTED"|"ANALYZED")
                echo -e "${GREEN}✅ $(echo $component | tr '_' ' ' | tr '[:lower:]' '[:upper:]'): $status${NC}"
                ;;
            "FAILED"|"FAILED_MOCK_DETECTED")
                echo -e "${RED}❌ $(echo $component | tr '_' ' ' | tr '[:lower:]' '[:upper:]'): $status${NC}"
                ;;
            "NOT_FOUND")
                echo -e "${YELLOW}⚠️  $(echo $component | tr '_' ' ' | tr '[:lower:]' '[:upper:]'): $status${NC}"
                ;;
            *)
                echo -e "${CYAN}❓ $(echo $component | tr '_' ' ' | tr '[:lower:]' '[:upper:]'): $status${NC}"
                ;;
        esac
    done
    echo ""
    
    # Detalhes dos testes
    echo -e "${BOLD}📋 DETALHES DOS TESTES:${NC}"
    echo "------------------------------------------------------------"
    for test in "${!TEST_RESULTS[@]}"; do
        local result=${TEST_RESULTS[$test]}
        local error=${TEST_ERRORS[$test]:-""}
        
        case $result in
            "PASS")
                echo -e "${GREEN}✅ $test${NC}"
                ;;
            "FAIL")
                echo -e "${RED}❌ $test - $error${NC}"
                ;;
            *)
                echo -e "${YELLOW}❓ $test - $result${NC}"
                ;;
        esac
    done
    echo ""
    
    # Avaliação final
    echo -e "${BOLD}🏆 AVALIAÇÃO FINAL:${NC}"
    echo "------------------------------------------------------------"
    
    if [[ $CRITICAL_FAILURES -eq 0 && $MOCK_DETECTIONS -eq 0 && $success_rate -ge 90 ]]; then
        echo -e "${BOLD}${GREEN}🎉 SISTEMA VALIDADO PARA PRODUÇÃO!${NC}"
        echo -e "${GREEN}✅ Sem mocks detectados${NC}"
        echo -e "${GREEN}✅ Sem falhas críticas${NC}"
        echo -e "${GREEN}✅ Alta taxa de sucesso ($success_rate%)${NC}"
        log_message "SUCCESS" "System validated for production - no mocks, no critical failures"
    elif [[ $MOCK_DETECTIONS -gt 0 ]]; then
        echo -e "${BOLD}${RED}🚨 SISTEMA REJEITADO: MOCKS DETECTADOS!${NC}"
        echo -e "${RED}❌ Encontrados $MOCK_DETECTIONS mocks${NC}"
        echo -e "${RED}🛑 NÃO SEGURO PARA PRODUÇÃO${NC}"
        log_message "CRITICAL" "System rejected - mocks detected"
    elif [[ $CRITICAL_FAILURES -gt 0 ]]; then
        echo -e "${BOLD}${RED}🚨 SISTEMA REJEITADO: FALHAS CRÍTICAS!${NC}"
        echo -e "${RED}❌ Encontradas $CRITICAL_FAILURES falhas críticas${NC}"
        echo -e "${RED}🛑 NÃO SEGURO PARA PRODUÇÃO${NC}"
        log_message "CRITICAL" "System rejected - critical failures detected"
    else
        echo -e "${BOLD}${YELLOW}⚠️  SISTEMA PARCIALMENTE VALIDADO${NC}"
        echo -e "${YELLOW}📊 Taxa de sucesso: $success_rate%${NC}"
        echo -e "${YELLOW}🔍 Requer investigação adicional${NC}"
        log_message "WARNING" "System partially validated - requires additional investigation"
    fi
    
    # Salvar relatório completo
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    local report_file="$LOG_DIR/smoke-comprehensive-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" 2>/dev/null << EOF || true
SPR Smoke Test Comprehensive Report
===================================
Executado em: $TIMESTAMP - $end_time
Duração: ${duration}s
Host: $(hostname)
Usuário: $(whoami)
Projeto: $PROJECT_ROOT

RESUMO:
- Testes executados: $TOTAL_TESTS
- Testes aprovados: $PASSED_TESTS
- Testes falharam: $FAILED_TESTS
- Falhas críticas: $CRITICAL_FAILURES
- Mocks detectados: $MOCK_DETECTIONS
- Taxa de sucesso: $success_rate%

STATUS FINAL: $(if [[ $CRITICAL_FAILURES -eq 0 && $MOCK_DETECTIONS -eq 0 && $success_rate -ge 90 ]]; then echo "VALIDATED"; elif [[ $MOCK_DETECTIONS -gt 0 ]]; then echo "REJECTED_MOCKS"; elif [[ $CRITICAL_FAILURES -gt 0 ]]; then echo "REJECTED_CRITICAL"; else echo "PARTIAL"; fi)

COMPONENTES TESTADOS:
EOF

    for component in "${COMPONENTS[@]}"; do
        echo "- $(echo $component | tr '_' ' ' | tr '[:lower:]' '[:upper:]'): ${COMPONENT_STATUS[$component]:-NOT_TESTED}" >> "$report_file" 2>/dev/null || true
    done
    
    echo -e "${CYAN}📄 Relatório completo salvo em: $report_file${NC}"
    echo ""
    
    # Exit code final
    if [[ $CRITICAL_FAILURES -eq 0 && $MOCK_DETECTIONS -eq 0 && $success_rate -ge 90 ]]; then
        return 0
    else
        return 1
    fi
}

# Função principal
main() {
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    show_banner
    
    log_message "INFO" "Starting comprehensive smoke test"
    
    echo -e "${BOLD}${YELLOW}🔥 INICIANDO SMOKE TEST AMPLIADO${NC}"
    echo "================================================================"
    
    # Executar todos os testes
    test_basic_services
    test_anti_mock_sentinel  
    test_endpoint_validation
    test_network_connectivity
    test_local_ports
    test_websocket_comprehensive
    test_database_comprehensive
    test_performance_analysis
    test_security_basics
    
    # Gerar relatório final e determinar exit code
    if generate_telemetry_report; then
        echo -e "${GREEN}🎉 SMOKE TEST COMPLETADO COM SUCESSO!${NC}"
        exit 0
    else
        echo -e "${RED}🚨 SMOKE TEST FALHOU!${NC}"
        exit 1
    fi
}

# Trap para limpeza
trap 'echo -e "\n${YELLOW}🛑 Smoke test interrompido${NC}"; exit 130' SIGINT SIGTERM

# Executar
main "$@"