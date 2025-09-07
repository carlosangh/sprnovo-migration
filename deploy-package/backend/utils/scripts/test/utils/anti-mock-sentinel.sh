#!/bin/bash

# 🚨 SPR - Anti-Mock Sentinel
# Script que detecta e impede uso de mocks em produção
# Falha o build se encontrar qualquer trace de mock/fake data

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/opt/spr"
LOG_DIR="$PROJECT_ROOT/logs"
SENTINEL_LOG="$LOG_DIR/anti-mock-sentinel.log"
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
MOCK_PATTERNS=(
    "msw"
    "mock"
    "fixture"
    "faker"
    "jest.mock"
    "sinon"
    "test-data"
    "stub"
    "dummy"
    "fake-api"
    "mock-server"
    "USE_MOCK.*=.*true"
    "MOCK_MODE.*=.*1"
    "TEST_MODE.*=.*true"
    "FAKE_DATA"
    "mockImplementation"
    "mockReturnValue"
    "spyOn"
)

CRITICAL_PATHS=(
    "$PROJECT_ROOT/backend_server_fixed.js"
    "$PROJECT_ROOT/simple_fastapi_server.py"
    "$PROJECT_ROOT/whatsapp_server_fixed.js"
    "$PROJECT_ROOT/whatsapp_server_real.js"
    "$PROJECT_ROOT/app"
    "$PROJECT_ROOT/frontend/src"
    "$PROJECT_ROOT/agents"
)

EXCLUDE_PATTERNS=(
    "node_modules"
    ".git"
    "_backup_obsoletos"
    "test"
    "spec"
    "__pycache__"
    ".pytest_cache"
    "coverage"
    "logs"
    "qrcodes"
    ".wwebjs_cache"
    "sessions"
    "backups"
)

# Contadores
TOTAL_FILES_SCANNED=0
MOCK_VIOLATIONS=0
CRITICAL_VIOLATIONS=0
declare -A VIOLATION_FILES

# Função de banner
show_banner() {
    clear
    echo -e "${BOLD}${RED}"
    echo "████████████████████████████████████████████████████████████████"
    echo "██                                                            ██"
    echo "██    🚨 SPR - ANTI-MOCK SENTINEL                            ██"
    echo "██    🔍 Detector de Código Mock em Produção                 ██"
    echo "██                                                            ██"
    echo "██    ⚠️  ZERO TOLERÂNCIA A MOCKS EM PRODUÇÃO               ██"
    echo "██                                                            ██"
    echo "████████████████████████████████████████████████████████████████"
    echo -e "${NC}"
    echo -e "${CYAN}📅 $TIMESTAMP${NC}"
    echo -e "${CYAN}📍 Diretório: $PROJECT_ROOT${NC}"
    echo -e "${CYAN}📝 Log: $SENTINEL_LOG${NC}"
    echo ""
}

# Função de logging
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$SENTINEL_LOG"
}

# Função para verificar se arquivo deve ser excluído
should_exclude() {
    local file_path=$1
    
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$file_path" =~ $pattern ]]; then
            return 0  # Excluir
        fi
    done
    
    return 1  # Não excluir
}

# Função para escanear arquivo em busca de patterns de mock
scan_file_for_mocks() {
    local file_path=$1
    local is_critical=${2:-false}
    
    if should_exclude "$file_path"; then
        return 0
    fi
    
    if [[ ! -f "$file_path" ]]; then
        return 0
    fi
    
    # Verificar se arquivo é legível
    if [[ ! -r "$file_path" ]]; then
        log_message "WARNING" "Cannot read file: $file_path"
        return 0
    fi
    
    ((TOTAL_FILES_SCANNED++))
    
    # Escanear cada pattern
    for pattern in "${MOCK_PATTERNS[@]}"; do
        local matches=$(grep -n -i "$pattern" "$file_path" 2>/dev/null || true)
        
        if [[ -n "$matches" ]]; then
            ((MOCK_VIOLATIONS++))
            
            if [[ "$is_critical" == "true" ]]; then
                ((CRITICAL_VIOLATIONS++))
            fi
            
            VIOLATION_FILES["$file_path"]=1
            
            echo -e "${RED}🚨 VIOLAÇÃO DETECTADA:${NC}"
            echo -e "${YELLOW}   Arquivo: $file_path${NC}"
            echo -e "${YELLOW}   Pattern: $pattern${NC}"
            
            if [[ "$is_critical" == "true" ]]; then
                echo -e "${RED}   🔥 CRÍTICO: Arquivo de produção contém mock!${NC}"
            fi
            
            echo -e "${CYAN}   Linhas encontradas:${NC}"
            echo "$matches" | while IFS= read -r line; do
                echo -e "${CYAN}      $line${NC}"
            done
            echo ""
            
            log_message "VIOLATION" "Mock pattern '$pattern' found in $file_path"
            
            if [[ "$is_critical" == "true" ]]; then
                log_message "CRITICAL" "Critical production file contains mock: $file_path"
            fi
        fi
    done
}

# Função para verificar arquivos críticos de produção
scan_critical_files() {
    echo -e "${BOLD}${YELLOW}🔍 ESCANEANDO ARQUIVOS CRÍTICOS DE PRODUÇÃO${NC}"
    echo "============================================================"
    
    for path in "${CRITICAL_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            echo -e "${CYAN}📁 Escaneando diretório: $path${NC}"
            find "$path" -type f \( -name "*.js" -o -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | while read -r file; do
                scan_file_for_mocks "$file" "true"
            done
        elif [[ -f "$path" ]]; then
            echo -e "${CYAN}📄 Escaneando arquivo: $path${NC}"
            scan_file_for_mocks "$path" "true"
        else
            echo -e "${YELLOW}⚠️  Caminho não encontrado: $path${NC}"
            log_message "WARNING" "Path not found: $path"
        fi
    done
}

# Função para verificar variáveis de ambiente
check_environment_variables() {
    echo -e "${BOLD}${YELLOW}🌍 VERIFICANDO VARIÁVEIS DE AMBIENTE${NC}"
    echo "============================================================"
    
    local env_violations=0
    
    # Verificar arquivo .env
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        echo -e "${CYAN}📄 Verificando arquivo .env${NC}"
        
        local dangerous_envs=(
            "USE_MOCK=true"
            "USE_MOCK=1"
            "MOCK_MODE=true"
            "MOCK_MODE=1"
            "TEST_MODE=true"
            "TEST_MODE=1"
            "NODE_ENV=test"
            "NODE_ENV=development"
            "ENVIRONMENT=test"
            "FAKE_DATA=true"
        )
        
        for env_var in "${dangerous_envs[@]}"; do
            if grep -q "$env_var" "$PROJECT_ROOT/.env" 2>/dev/null; then
                echo -e "${RED}🚨 VARIÁVEL PERIGOSA DETECTADA: $env_var${NC}"
                log_message "CRITICAL" "Dangerous environment variable found: $env_var"
                ((env_violations++))
                ((CRITICAL_VIOLATIONS++))
            fi
        done
    fi
    
    # Verificar variáveis do sistema
    echo -e "${CYAN}🔍 Verificando variáveis do sistema${NC}"
    
    if [[ "$USE_MOCK" == "true" || "$USE_MOCK" == "1" ]]; then
        echo -e "${RED}🚨 USE_MOCK está ativo no sistema!${NC}"
        log_message "CRITICAL" "USE_MOCK is active in system environment"
        ((env_violations++))
        ((CRITICAL_VIOLATIONS++))
    fi
    
    if [[ "$NODE_ENV" == "test" || "$NODE_ENV" == "development" ]]; then
        echo -e "${YELLOW}⚠️  NODE_ENV=$NODE_ENV (deveria ser 'production')${NC}"
        log_message "WARNING" "NODE_ENV is $NODE_ENV, should be production"
    fi
    
    if [[ $env_violations -eq 0 ]]; then
        echo -e "${GREEN}✅ Variáveis de ambiente estão seguras${NC}"
    fi
    
    echo ""
}

# Função para verificar endpoints de API em tempo real
verify_api_endpoints() {
    echo -e "${BOLD}${YELLOW}🌐 VERIFICANDO ENDPOINTS DE API${NC}"
    echo "============================================================"
    
    local endpoints=(
        "http://localhost:3002/api/status"
        "http://localhost:3002/api/metrics"
        "http://localhost:3002/api/commodities/dashboard/summary"
        "http://localhost:3002/api/offer-management?status=ativa"
        "http://localhost:3003/api/whatsapp/qr-code"
    )
    
    for endpoint in "${endpoints[@]}"; do
        echo -e "${CYAN}🔍 Verificando: $endpoint${NC}"
        
        local response=$(curl -s --max-time 10 "$endpoint" 2>/dev/null || echo "ERROR")
        
        if [[ "$response" == "ERROR" ]]; then
            echo -e "${YELLOW}⚠️  Endpoint não acessível (normal se serviços não estiverem rodando)${NC}"
        else
            # Verificar se resposta contém dados mock óbvios
            local mock_indicators=(
                "mock"
                "fake"
                "test-data"
                "dummy"
                "lorem ipsum"
                "example.com"
                "placeholder"
            )
            
            local found_mock=false
            for indicator in "${mock_indicators[@]}"; do
                if echo "$response" | grep -qi "$indicator"; then
                    echo -e "${RED}🚨 DADOS MOCK DETECTADOS NO ENDPOINT!${NC}"
                    echo -e "${RED}   Indicador: $indicator${NC}"
                    log_message "CRITICAL" "Mock data detected in endpoint $endpoint: $indicator"
                    ((CRITICAL_VIOLATIONS++))
                    found_mock=true
                    break
                fi
            done
            
            if [[ "$found_mock" == "false" ]]; then
                echo -e "${GREEN}✅ Endpoint retornando dados aparentemente reais${NC}"
            fi
        fi
    done
    
    echo ""
}

# Função para gerar relatório final
generate_report() {
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${BOLD}${WHITE}📊 RELATÓRIO ANTI-MOCK SENTINEL${NC}"
    echo "============================================================"
    
    echo -e "${CYAN}📅 Início: $TIMESTAMP${NC}"
    echo -e "${CYAN}📅 Fim: $end_time${NC}"
    echo -e "${CYAN}📁 Arquivos escaneados: $TOTAL_FILES_SCANNED${NC}"
    echo -e "${CYAN}🔍 Violações encontradas: $MOCK_VIOLATIONS${NC}"
    echo -e "${RED}🚨 Violações críticas: $CRITICAL_VIOLATIONS${NC}"
    echo ""
    
    # Status geral
    if [[ $CRITICAL_VIOLATIONS -eq 0 ]]; then
        echo -e "${BOLD}${GREEN}🎉 SISTEMA LIVRE DE MOCKS CRÍTICOS${NC}"
        echo -e "${GREEN}✅ Seguro para produção!${NC}"
        log_message "SUCCESS" "System is mock-free and safe for production"
    else
        echo -e "${BOLD}${RED}🚨 SISTEMA CONTÉM MOCKS CRÍTICOS${NC}"
        echo -e "${RED}❌ NÃO SEGURO PARA PRODUÇÃO!${NC}"
        log_message "CRITICAL" "System contains critical mocks - NOT SAFE FOR PRODUCTION"
    fi
    
    # Listar arquivos com violações
    if [[ ${#VIOLATION_FILES[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BOLD}📋 ARQUIVOS COM VIOLAÇÕES:${NC}"
        echo "------------------------------------------------------------"
        for file in "${!VIOLATION_FILES[@]}"; do
            echo -e "${RED}❌ $file${NC}"
        done
    fi
    
    # Salvar relatório
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    local report_file="$LOG_DIR/anti-mock-report-$(date +%Y%m%d_%H%M%S).txt"
    cat > "$report_file" 2>/dev/null << EOF || true
SPR Anti-Mock Sentinel Report
=============================
Data: $TIMESTAMP - $end_time
Diretório: $PROJECT_ROOT

RESUMO:
- Arquivos escaneados: $TOTAL_FILES_SCANNED
- Violações encontradas: $MOCK_VIOLATIONS
- Violações críticas: $CRITICAL_VIOLATIONS

STATUS: $(if [[ $CRITICAL_VIOLATIONS -eq 0 ]]; then echo "SAFE FOR PRODUCTION"; else echo "NOT SAFE FOR PRODUCTION"; fi)

ARQUIVOS COM VIOLAÇÕES:
EOF

    for file in "${!VIOLATION_FILES[@]}"; do
        echo "- $file" >> "$report_file" 2>/dev/null || true
    done
    
    echo -e "${CYAN}📄 Relatório salvo em: $report_file${NC}"
    echo ""
    
    # Exit code baseado em violações críticas
    if [[ $CRITICAL_VIOLATIONS -gt 0 ]]; then
        echo -e "${RED}🛑 FALHANDO BUILD: Mocks críticos detectados${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ BUILD PODE CONTINUAR: Sistema limpo${NC}"
        exit 0
    fi
}

# Função principal
main() {
    # Criar diretório de logs
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    show_banner
    
    log_message "INFO" "Starting Anti-Mock Sentinel scan"
    
    echo -e "${BOLD}${YELLOW}🚨 INICIANDO VARREDURA ANTI-MOCK${NC}"
    echo "============================================================"
    
    # Executar todas as verificações
    scan_critical_files
    check_environment_variables
    verify_api_endpoints
    
    # Gerar relatório e decidir se falha o build
    generate_report
}

# Trap para limpeza
trap 'echo -e "\n${YELLOW}🛑 Sentinel interrompido${NC}"; exit 130' SIGINT SIGTERM

# Executar
main "$@"