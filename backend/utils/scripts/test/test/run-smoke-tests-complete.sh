#!/bin/bash

#####################################################################
# SPR LICENSE SYSTEM - COMPLETE SMOKE TEST RUNNER
# 
# Executa todos os testes smoke do sistema de licenças
# Valida funcionamento completo sem mock com fonte única real
#
# Uso: ./run-smoke-tests-complete.sh [--production] [--no-e2e]
#####################################################################

set -e

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
TESTS_DIR="$PROJECT_DIR/tests"
REPORTS_DIR="/opt/spr/_reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MASTER_REPORT="$REPORTS_DIR/smoke_tests_master_${TIMESTAMP}.json"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Flags
PRODUCTION_MODE=false
RUN_E2E=true
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --production)
            PRODUCTION_MODE=true
            shift
            ;;
        --no-e2e)
            RUN_E2E=false
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--production] [--no-e2e] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --production  Run in production mode with strict validations"
            echo "  --no-e2e      Skip E2E tests (useful for headless environments)"
            echo "  --verbose     Enable verbose output"
            echo "  -h, --help    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

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
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# Função para verificar dependências
check_dependencies() {
    log "STEP" "🔍 Verificando dependências..."
    
    local missing_deps=()
    
    # Verificar Node.js
    if ! command -v node >&2 /dev/null; then
        missing_deps+=("Node.js")
    fi
    
    # Verificar npm
    if ! command -v npm >&2 /dev/null; then
        missing_deps+=("npm")
    fi
    
    # Verificar se servidor está rodando
    if ! curl -f -s "$BACKEND_URL/api/health" > /dev/null; then
        log "WARNING" "⚠️ Backend servidor não está respondendo em $BACKEND_URL"
        log "INFO" "Certifique-se de que o servidor está rodando: node backend_server_fixed.js"
    fi
    
    # Verificar se diretório de testes existe
    if [[ ! -d "$TESTS_DIR" ]]; then
        log "ERROR" "❌ Diretório de testes não encontrado: $TESTS_DIR"
        return 1
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "❌ Dependências faltando: ${missing_deps[*]}"
        return 1
    fi
    
    log "SUCCESS" "✅ Todas as dependências verificadas"
    return 0
}

# Função para configurar ambiente
setup_environment() {
    log "STEP" "🔧 Configurando ambiente de testes..."
    
    # Criar diretórios necessários
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$REPORTS_DIR/screenshots"
    
    # Configurar variáveis de ambiente baseado no modo
    if [[ "$PRODUCTION_MODE" == true ]]; then
        export NODE_ENV="production"
        export LICENSE_MODE="production"
        export LICENSE_MOCK="0"
        export NO_MOCK="1"
        log "INFO" "🏭 Modo de produção ativado"
    else
        export NODE_ENV="development"
        export LICENSE_MODE="development"
        log "INFO" "🧪 Modo de desenvolvimento ativado"
    fi
    
    # Configurar URLs
    export BACKEND_URL="${BACKEND_URL:-http://localhost:3002}"
    export FRONTEND_URL="${FRONTEND_URL:-http://localhost:3000}"
    
    log "INFO" "Backend URL: $BACKEND_URL"
    log "INFO" "Frontend URL: $FRONTEND_URL"
    
    # Instalar dependências de teste se necessário
    if [[ ! -d "$PROJECT_DIR/node_modules" ]] || [[ ! -f "$PROJECT_DIR/node_modules/.bin/playwright" ]]; then
        log "INFO" "📦 Instalando dependências de teste..."
        cd "$PROJECT_DIR"
        npm install --no-save axios ws playwright
        npx playwright install chromium --with-deps
    fi
    
    log "SUCCESS" "✅ Ambiente configurado"
}

# Função para executar teste individual
run_test() {
    local test_name=$1
    local test_script=$2
    local test_type=$3
    local start_time=$(date +%s)
    
    log "STEP" "🧪 Executando: $test_name"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "   Script: $test_script"
        echo "   Tipo: $test_type"
    fi
    
    local output_file="$REPORTS_DIR/${test_name,,}_output.log"
    local exit_code=0
    
    # Executar o teste e capturar output
    if node "$test_script" > "$output_file" 2>&1; then
        exit_code=0
        log "SUCCESS" "✅ $test_name: PASSOU"
    else
        exit_code=$?
        log "ERROR" "❌ $test_name: FALHOU (exit code: $exit_code)"
        
        if [[ "$VERBOSE" == true ]]; then
            echo "   Últimas linhas do log:"
            tail -n 10 "$output_file" | sed 's/^/     /'
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Adicionar resultado ao array global
    TEST_RESULTS+=("{\"name\":\"$test_name\",\"type\":\"$test_type\",\"exit_code\":$exit_code,\"duration\":$duration,\"output_file\":\"$output_file\"}")
    
    return $exit_code
}

# Função para executar todos os testes
run_all_tests() {
    log "STEP" "🚀 Iniciando bateria completa de testes smoke"
    
    # Array para armazenar resultados
    TEST_RESULTS=()
    local failed_tests=0
    local total_tests=0
    
    # 1. Testes Backend Críticos
    log "INFO" "📡 TESTES BACKEND CRÍTICOS"
    if run_test "Backend_License_Tests" "$TESTS_DIR/smoke-license-comprehensive.js" "backend"; then
        :
    else
        ((failed_tests++))
    fi
    ((total_tests++))
    
    # 2. Validação Anti-Mock
    log "INFO" "🚫 VALIDAÇÃO ANTI-MOCK"
    if run_test "Anti_Mock_Validation" "$TESTS_DIR/anti-mock-validation.js" "security"; then
        :
    else
        ((failed_tests++))
    fi
    ((total_tests++))
    
    # 3. Testes E2E (se habilitado)
    if [[ "$RUN_E2E" == true ]]; then
        log "INFO" "🌐 TESTES E2E FRONTEND"
        
        # Verificar se Playwright está disponível
        if command -v npx >&2 /dev/null && npx playwright --version >&2 /dev/null; then
            if run_test "E2E_License_Tests" "$TESTS_DIR/e2e-license-tests.js" "e2e"; then
                :
            else
                ((failed_tests++))
            fi
            ((total_tests++))
        else
            log "WARNING" "⚠️ Playwright não disponível, pulando testes E2E"
        fi
    else
        log "INFO" "⏭️ Testes E2E desabilitados via --no-e2e"
    fi
    
    # 4. Validação Adicional de Integração
    log "INFO" "🔗 TESTES DE INTEGRAÇÃO"
    # Criar teste de integração simples inline
    create_integration_test
    if run_test "Integration_Validation" "$REPORTS_DIR/integration_test.js" "integration"; then
        :
    else
        ((failed_tests++))
    fi
    ((total_tests++))
    
    log "INFO" "📊 Testes executados: $total_tests"
    log "INFO" "❌ Testes falharam: $failed_tests"
    log "INFO" "✅ Testes passaram: $((total_tests - failed_tests))"
    
    return $failed_tests
}

# Função para criar teste de integração simples
create_integration_test() {
    cat > "$REPORTS_DIR/integration_test.js" << 'EOF'
const axios = require('axios');

async function testIntegration() {
    const backend = process.env.BACKEND_URL || 'http://localhost:3002';
    
    console.log('🔗 Testing API integration...');
    
    try {
        // Teste 1: Health check
        const health = await axios.get(`${backend}/api/health`);
        if (health.status !== 200) throw new Error('Health check failed');
        console.log('✅ Health check: PASS');
        
        // Teste 2: License status
        const license = await axios.get(`${backend}/api/license/status`);
        if (license.status !== 200) throw new Error('License status check failed');
        console.log('✅ License status: PASS');
        
        // Teste 3: Sistema responde corretamente
        const status = await axios.get(`${backend}/api/status`);
        if (status.status !== 200) throw new Error('System status check failed');
        console.log('✅ System status: PASS');
        
        console.log('✅ All integration tests passed');
        process.exit(0);
        
    } catch (error) {
        console.error('❌ Integration test failed:', error.message);
        process.exit(1);
    }
}

testIntegration();
EOF
}

# Função para gerar relatório master
generate_master_report() {
    log "STEP" "📋 Gerando relatório master..."
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    local passed_tests=0
    local failed_tests=0
    
    # Contar resultados
    for result in "${TEST_RESULTS[@]}"; do
        local exit_code=$(echo "$result" | sed 's/.*"exit_code":\([0-9]*\).*/\1/')
        if [[ "$exit_code" == "0" ]]; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
    done
    
    local success_rate=0
    if [[ ${#TEST_RESULTS[@]} -gt 0 ]]; then
        success_rate=$(echo "scale=2; $passed_tests * 100 / ${#TEST_RESULTS[@]}" | bc -l)
    fi
    
    # Gerar JSON do relatório
    cat > "$MASTER_REPORT" << EOF
{
    "summary": {
        "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
        "environment": "$NODE_ENV",
        "production_mode": $PRODUCTION_MODE,
        "backend_url": "$BACKEND_URL",
        "frontend_url": "$FRONTEND_URL",
        "total_duration": "${total_duration}s",
        "statistics": {
            "total_tests": ${#TEST_RESULTS[@]},
            "passed": $passed_tests,
            "failed": $failed_tests,
            "success_rate": "${success_rate}%"
        }
    },
    "test_results": [
        $(IFS=','; echo "${TEST_RESULTS[*]}")
    ],
    "system_info": {
        "node_version": "$(node --version)",
        "os": "$(uname -s)",
        "hostname": "$(hostname)",
        "pwd": "$(pwd)"
    }
}
EOF
    
    log "SUCCESS" "📄 Relatório master salvo em: $MASTER_REPORT"
    
    # Exibir sumário final
    echo ""
    echo "========================================================"
    echo "📊 RELATÓRIO FINAL - SPR LICENSE SMOKE TESTS"
    echo "========================================================"
    echo "Horário: $(date)"
    echo "Ambiente: $NODE_ENV"
    echo "Modo Produção: $PRODUCTION_MODE"
    echo "Backend: $BACKEND_URL"
    if [[ "$RUN_E2E" == true ]]; then
        echo "Frontend: $FRONTEND_URL"
    fi
    echo ""
    echo "📈 ESTATÍSTICAS:"
    echo "Total de Testes: ${#TEST_RESULTS[@]}"
    echo "✅ Passaram: $passed_tests"
    echo "❌ Falharam: $failed_tests"
    echo "📊 Taxa de Sucesso: ${success_rate}%"
    echo "⏱️ Duração Total: ${total_duration}s"
    echo ""
    
    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}🎉 TODOS OS TESTES PASSARAM! Sistema validado com sucesso.${NC}"
        echo -e "${GREEN}✅ Sistema de licenças funcionando corretamente sem mock.${NC}"
    else
        echo -e "${RED}⚠️ $failed_tests TESTE(S) FALHARAM!${NC}"
        echo -e "${RED}❌ Verifique os logs individuais para detalhes.${NC}"
    fi
    
    echo ""
    echo "📁 ARQUIVOS GERADOS:"
    echo "   📄 Relatório Master: $MASTER_REPORT"
    echo "   📂 Logs Individuais: $REPORTS_DIR/"
    if [[ "$RUN_E2E" == true ]]; then
        echo "   📸 Screenshots E2E: $REPORTS_DIR/screenshots/"
    fi
    echo ""
    
    return $failed_tests
}

# Função principal
main() {
    local start_banner="
    ███████╗██████╗ ██████╗     ██╗     ██╗ ██████╗███████╗███╗   ██╗███████╗███████╗
    ██╔════╝██╔══██╗██╔══██╗    ██║     ██║██╔════╝██╔════╝████╗  ██║██╔════╝██╔════╝
    ███████╗██████╔╝██████╔╝    ██║     ██║██║     █████╗  ██╔██╗ ██║███████╗█████╗  
    ╚════██║██╔═══╝ ██╔══██╗    ██║     ██║██║     ██╔══╝  ██║╚██╗██║╚════██║██╔══╝  
    ███████║██║     ██║  ██║    ███████╗██║╚██████╗███████╗██║ ╚████║███████║███████╗
    ╚══════╝╚═╝     ╚═╝  ╚═╝    ╚══════╝╚═╝ ╚═════╝╚══════╝╚═╝  ╚═══╝╚══════╝╚══════╝
    
    🚀 COMPREHENSIVE SMOKE TESTS - NO MOCK - REAL SYSTEM ONLY 🚀
    "
    
    echo -e "${CYAN}$start_banner${NC}"
    
    START_TIME=$(date +%s)
    
    # Executar verificações e testes
    if ! check_dependencies; then
        log "ERROR" "❌ Falha na verificação de dependências"
        exit 1
    fi
    
    setup_environment
    
    if run_all_tests; then
        local test_exit_code=0
    else
        local test_exit_code=$?
    fi
    
    if generate_master_report; then
        local report_exit_code=$?
    else
        local report_exit_code=1
    fi
    
    # Exit code final baseado nos resultados
    if [[ $test_exit_code -eq 0 ]] && [[ $report_exit_code -eq 0 ]]; then
        log "SUCCESS" "🎉 Smoke tests concluídos com sucesso!"
        exit 0
    else
        log "ERROR" "❌ Smoke tests falharam! Verifique os logs para detalhes."
        exit 1
    fi
}

# Verificar se bc está disponível (para cálculos)
if ! command -v bc >&2 /dev/null; then
    echo "Instalando bc para cálculos..."
    if command -v apt-get >&2 /dev/null; then
        sudo apt-get update && sudo apt-get install -y bc
    elif command -v yum >&2 /dev/null; then
        sudo yum install -y bc
    fi
fi

# Executar função principal
main "$@"