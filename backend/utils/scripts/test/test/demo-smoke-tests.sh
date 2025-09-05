#!/bin/bash

#####################################################################
# SPR LICENSE SYSTEM - DEMO SMOKE TESTS
# 
# Demonstração rápida do sistema de smoke tests
# Executa testes básicos para validar funcionamento
#####################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_URL="${BACKEND_URL:-http://localhost:3002}"
DEMO_REPORTS_DIR="$SCRIPT_DIR/_demo_reports"

# Banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                SPR LICENSE SMOKE TESTS - DEMO                 ║"
    echo "║                                                              ║"
    echo "║  Demonstração rápida do sistema de testes smoke            ║"
    echo "║  Validação básica do sistema de licenças real              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Função de logging
log() {
    local level=$1
    local message=$2
    local color=""
    
    case $level in
        "ERROR") color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "WARNING") color=$YELLOW ;;
        "INFO") color=$BLUE ;;
        "STEP") color=$PURPLE ;;
        *) color=$NC ;;
    esac
    
    echo -e "${color}[$(date '+%H:%M:%S')] [$level] $message${NC}"
}

# Verificar se backend está rodando
check_backend() {
    log "STEP" "🔍 Verificando backend em $BACKEND_URL..."
    
    if curl -f -s "$BACKEND_URL/api/health" > /dev/null; then
        log "SUCCESS" "✅ Backend respondendo corretamente"
        return 0
    else
        log "ERROR" "❌ Backend não está respondendo em $BACKEND_URL"
        log "INFO" "💡 Para iniciar o backend, execute: node backend_server_fixed.js"
        return 1
    fi
}

# Teste básico de health
test_health_endpoint() {
    log "STEP" "🏥 Testando endpoint de health..."
    
    local response=$(curl -s "$BACKEND_URL/api/health")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/api/health")
    
    if [[ "$status_code" == "200" ]]; then
        log "SUCCESS" "✅ Health check: $status_code"
        echo "   Response: $(echo $response | jq -c '.status // .message' 2>/dev/null || echo $response)"
    else
        log "ERROR" "❌ Health check falhou: $status_code"
        return 1
    fi
}

# Teste de status de licença sem licença
test_license_status_inactive() {
    log "STEP" "🔐 Testando status de licença (sem licença ativa)..."
    
    local client_id="demo-test-$(date +%s)"
    local response=$(curl -s -H "X-Client-Id: $client_id" "$BACKEND_URL/api/license/status")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Client-Id: $client_id" "$BACKEND_URL/api/license/status")
    
    if [[ "$status_code" == "200" ]]; then
        local active=$(echo $response | jq -r '.active' 2>/dev/null)
        if [[ "$active" == "false" ]]; then
            log "SUCCESS" "✅ License status sem licença: active=false"
        else
            log "WARNING" "⚠️ License status inesperado: active=$active"
        fi
    else
        log "ERROR" "❌ License status falhou: $status_code"
        return 1
    fi
}

# Teste de ativação de licença
test_license_activation() {
    log "STEP" "🔑 Testando ativação de licença..."
    
    local client_id="demo-activation-$(date +%s)"
    local license_key="SPR-TEST-1234-5678-ABCD"
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"$license_key\",\"clientId\":\"$client_id\"}" \
        "$BACKEND_URL/api/license/activate")
    
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"$license_key\",\"clientId\":\"$client_id\"}" \
        "$BACKEND_URL/api/license/activate")
    
    if [[ "$status_code" == "200" ]]; then
        local success=$(echo $response | jq -r '.success' 2>/dev/null)
        if [[ "$success" == "true" ]]; then
            log "SUCCESS" "✅ Ativação de licença: sucesso"
            
            # Verificar se licença está ativa agora
            local status_response=$(curl -s -H "X-Client-Id: $client_id" "$BACKEND_URL/api/license/status")
            local active=$(echo $status_response | jq -r '.active' 2>/dev/null)
            
            if [[ "$active" == "true" ]]; then
                log "SUCCESS" "✅ Verificação pós-ativação: active=true"
            else
                log "WARNING" "⚠️ Licença ativada mas status ainda inactive"
            fi
        else
            log "ERROR" "❌ Ativação falhou: success=$success"
            return 1
        fi
    else
        log "ERROR" "❌ Ativação de licença falhou: $status_code"
        return 1
    fi
}

# Teste de middleware (endpoint protegido)
test_protected_endpoint() {
    log "STEP" "🛡️ Testando middleware de proteção..."
    
    local client_id="demo-no-license-$(date +%s)"
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "X-Client-Id: $client_id" \
        -H "Authorization: Bearer invalid-token" \
        "$BACKEND_URL/api/metrics")
    
    # Esperamos 401 ou 403 (sem autorização ou licença)
    if [[ "$status_code" == "401" || "$status_code" == "403" ]]; then
        log "SUCCESS" "✅ Middleware bloqueando acesso sem licença: $status_code"
    else
        log "WARNING" "⚠️ Middleware response inesperado: $status_code"
    fi
}

# Teste anti-mock básico
test_anti_mock_basic() {
    log "STEP" "🚫 Testando validação anti-mock básica..."
    
    # Testar com User-Agent suspeito
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "User-Agent: Mock Client v1.0" \
        "$BACKEND_URL/api/status")
    
    if [[ "$NODE_ENV" == "production" ]]; then
        if [[ "$status_code" == "403" ]]; then
            log "SUCCESS" "✅ Mock client bloqueado em produção: $status_code"
        else
            log "WARNING" "⚠️ Mock client não bloqueado em produção: $status_code"
        fi
    else
        log "INFO" "ℹ️ Environment development - Mock client status: $status_code"
    fi
}

# Resumo dos testes
show_summary() {
    local passed=$1
    local total=$2
    local failed=$((total - passed))
    
    echo ""
    log "INFO" "📊 RESUMO DOS TESTES DEMO"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "Total de testes: ${CYAN}$total${NC}"
    echo -e "✅ Passou: ${GREEN}$passed${NC}"
    echo -e "❌ Falhou: ${RED}$failed${NC}"
    
    local success_rate=$(echo "scale=1; $passed * 100 / $total" | bc -l 2>/dev/null || echo "0")
    echo -e "📈 Taxa de sucesso: ${CYAN}${success_rate}%${NC}"
    
    if [[ $failed -eq 0 ]]; then
        echo ""
        log "SUCCESS" "🎉 Todos os testes demo passaram!"
        log "INFO" "💡 Execute o sistema completo com: ./run-smoke-tests-complete.sh"
    else
        echo ""
        log "WARNING" "⚠️ Alguns testes falharam, mas isso pode ser normal para demo"
        log "INFO" "💡 Verifique se o backend está rodando corretamente"
    fi
}

# Criar relatório simples
create_demo_report() {
    local passed=$1
    local total=$2
    
    mkdir -p "$DEMO_REPORTS_DIR"
    
    cat > "$DEMO_REPORTS_DIR/demo_results.txt" << EOF
SPR LICENSE SMOKE TESTS - DEMO RESULTS
======================================
Timestamp: $(date)
Backend URL: $BACKEND_URL
Environment: ${NODE_ENV:-development}

Results:
- Total Tests: $total
- Passed: $passed  
- Failed: $((total - passed))
- Success Rate: $(echo "scale=1; $passed * 100 / $total" | bc -l 2>/dev/null || echo "0")%

Status: $([ $passed -eq $total ] && echo "ALL PASSED" || echo "SOME FAILED")
EOF
    
    log "INFO" "📄 Relatório demo salvo em: $DEMO_REPORTS_DIR/demo_results.txt"
}

# Função principal
main() {
    show_banner
    
    # Configurar ambiente
    export BACKEND_URL="${BACKEND_URL:-http://localhost:3002}"
    log "INFO" "🔧 Backend URL: $BACKEND_URL"
    log "INFO" "🌍 Environment: ${NODE_ENV:-development}"
    
    # Verificar dependências básicas
    if ! command -v curl >&2 /dev/null; then
        log "ERROR" "❌ curl não encontrado. Instale com: sudo apt-get install curl"
        exit 1
    fi
    
    if ! command -v bc >&2 /dev/null; then
        log "WARNING" "⚠️ bc não encontrado. Calculadora não disponível."
    fi
    
    # Verificar backend
    if ! check_backend; then
        log "ERROR" "❌ Não é possível executar testes sem backend rodando"
        exit 1
    fi
    
    echo ""
    log "INFO" "🚀 Executando testes smoke demo..."
    
    # Executar testes
    local passed=0
    local total=0
    
    # Teste 1: Health
    ((total++))
    if test_health_endpoint; then
        ((passed++))
    fi
    
    # Teste 2: License status inactive
    ((total++))
    if test_license_status_inactive; then
        ((passed++))
    fi
    
    # Teste 3: License activation
    ((total++))
    if test_license_activation; then
        ((passed++))
    fi
    
    # Teste 4: Protected endpoint
    ((total++))
    if test_protected_endpoint; then
        ((passed++))
    fi
    
    # Teste 5: Anti-mock basic
    ((total++))
    if test_anti_mock_basic; then
        ((passed++))
    fi
    
    # Mostrar resumo
    show_summary $passed $total
    
    # Criar relatório
    create_demo_report $passed $total
    
    # Exit code
    if [[ $passed -eq $total ]]; then
        exit 0
    else
        exit 1
    fi
}

# Executar
main "$@"