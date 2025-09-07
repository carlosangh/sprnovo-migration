#!/bin/bash

# ==========================================
# SCRIPT DE TESTE EVOLUTION API
# Configuração completa de testes para WhatsApp
# ==========================================

set -e  # Parar em caso de erro
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
NC='\033[0m' # No Color

# URLs e configurações
BACKEND_URL="http://localhost:3002"
EVO_URL="${EVO_URL:-http://localhost:8080}"
DEFAULT_INSTANCE="spr_test_instance"
DEFAULT_TEST_NUMBER="+5511999887766"

# ==========================================
# FUNÇÕES AUXILIARES
# ==========================================

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${MAGENTA}[STEP]${NC} $1"
}

# Verificar se um comando existe
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Comando '$1' não encontrado. Instale: $2"
        exit 1
    fi
}

# Aguardar serviço ficar disponível
wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=${3:-30}
    local attempt=1
    
    log_info "Aguardando $name ficar disponível..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            log_success "$name está disponível"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "$name não ficou disponível após $max_attempts tentativas"
    return 1
}

# Fazer requisição HTTP com tratamento de erro
http_request() {
    local method=$1
    local url=$2
    local data=${3:-""}
    local expected_status=${4:-200}
    
    local response
    local status
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
            -X "$method" \
            -H "Content-Type: application/json" \
            -H "apikey: ${EVO_APIKEY:-}" \
            -d "$data" \
            "$url")
    else
        response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
            -X "$method" \
            -H "apikey: ${EVO_APIKEY:-}" \
            "$url")
    fi
    
    status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$status" != "$expected_status" ]; then
        log_error "HTTP $status: $body"
        return 1
    fi
    
    echo "$body"
    return 0
}

# ==========================================
# COMANDOS DE TESTE
# ==========================================

# Verificar pré-requisitos
check_prerequisites() {
    log_step "Verificando pré-requisitos"
    
    check_command "curl" "curl"
    # check_command "jq" "jq (para parsing JSON)" # Opcional - usaremos alternativas
    
    # Verificar se backend está rodando
    if ! wait_for_service "$BACKEND_URL/health" "Backend SPR" 10; then
        log_error "Backend SPR não está disponível em $BACKEND_URL"
        log_info "Execute: node spr-backend-complete.js"
        exit 1
    fi
    
    # Verificar Evolution API
    if [ -n "${EVO_URL:-}" ]; then
        if ! wait_for_service "$EVO_URL" "Evolution API" 10; then
            log_warning "Evolution API não está disponível em $EVO_URL"
            log_warning "Alguns testes serão limitados"
        fi
    else
        log_warning "EVO_URL não configurada"
    fi
    
    log_success "Pré-requisitos verificados"
}

# Testar health checks
test_health_checks() {
    log_step "Testando health checks"
    
    # Backend health
    log_info "Testando backend health..."
    if response=$(http_request GET "$BACKEND_URL/health"); then
        status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "$response" | grep -o '"ok":[^,}]*' | cut -d':' -f2 || echo "unknown")
        log_success "Backend health: $status"
    else
        log_error "Falha no health check do backend"
        return 1
    fi
    
    # WhatsApp health
    log_info "Testando WhatsApp health..."
    if response=$(http_request GET "$BACKEND_URL/api/whatsapp/health"); then
        service=$(echo "$response" | grep -o '"service":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        ok=$(echo "$response" | grep -o '"ok":[^,}]*' | cut -d':' -f2 | tr -d ' ' || echo "false")
        log_success "WhatsApp health: service=$service, ok=$ok"
    else
        log_error "Falha no health check do WhatsApp"
        return 1
    fi
    
    log_success "Health checks completados"
}

# Criar instância WhatsApp
create_instance() {
    local instance_name=${1:-$DEFAULT_INSTANCE}
    
    log_step "Criando instância WhatsApp: $instance_name"
    
    local data="{\"instanceName\": \"$instance_name\", \"qrcode\": true}"
    
    if response=$(http_request POST "$BACKEND_URL/api/whatsapp/instance" "$data"); then
        log_success "Instância '$instance_name' criada com sucesso"
        echo "$response"
        
        # Salvar nome da instância para outros comandos
        echo "$instance_name" > /tmp/evo_test_instance
        
        return 0
    else
        log_error "Falha ao criar instância '$instance_name'"
        return 1
    fi
}

# Obter QR Code
get_qr_code() {
    local instance_name=${1:-}
    
    if [ -z "$instance_name" ] && [ -f /tmp/evo_test_instance ]; then
        instance_name=$(cat /tmp/evo_test_instance)
    fi
    
    if [ -z "$instance_name" ]; then
        instance_name=$DEFAULT_INSTANCE
    fi
    
    log_step "Obtendo QR Code para instância: $instance_name"
    
    if response=$(http_request GET "$BACKEND_URL/api/whatsapp/qr/$instance_name"); then
        log_success "QR Code obtido para '$instance_name'"
        
        # Tentar extrair QR code base64 se disponível
        qr_code=$(echo "$response" | grep -o '"base64":"[^"]*"' | cut -d'"' -f4 || echo "N/A")
        if [ "$qr_code" != "N/A" ] && [ "$qr_code" != "null" ]; then
            log_info "QR Code base64 disponível (${#qr_code} caracteres)"
            
            # Salvar QR code em arquivo se desejado
            if command -v qrencode &> /dev/null; then
                echo "$qr_code" | base64 -d > "/tmp/qr_${instance_name}.png" 2>/dev/null || true
                log_info "QR Code salvo em: /tmp/qr_${instance_name}.png"
            fi
        fi
        
        echo "$response"
        return 0
    else
        log_error "Falha ao obter QR Code para '$instance_name'"
        return 1
    fi
}

# Conectar instância
connect_instance() {
    local instance_name=${1:-}
    
    if [ -z "$instance_name" ] && [ -f /tmp/evo_test_instance ]; then
        instance_name=$(cat /tmp/evo_test_instance)
    fi
    
    if [ -z "$instance_name" ]; then
        instance_name=$DEFAULT_INSTANCE
    fi
    
    log_step "Conectando instância: $instance_name"
    log_warning "Para conectar, escaneie o QR Code com WhatsApp Web"
    log_info "Execute: $0 qr $instance_name para obter o QR Code"
    
    # Tentar obter QR automaticamente
    get_qr_code "$instance_name"
}

# Enviar mensagem de teste
send_test_message() {
    local instance_name=${1:-}
    local number=${2:-$DEFAULT_TEST_NUMBER}
    local message=${3:-"🤖 Teste Evolution API - $(date)"}
    
    if [ -z "$instance_name" ] && [ -f /tmp/evo_test_instance ]; then
        instance_name=$(cat /tmp/evo_test_instance)
    fi
    
    if [ -z "$instance_name" ]; then
        instance_name=$DEFAULT_INSTANCE
    fi
    
    log_step "Enviando mensagem de teste"
    log_info "Instância: $instance_name"
    log_info "Número: $number"
    log_info "Mensagem: $message"
    
    local data="{\"instanceName\": \"$instance_name\", \"number\": \"$number\", \"message\": \"$message\"}"
    
    if response=$(http_request POST "$BACKEND_URL/api/whatsapp/send" "$data"); then
        log_success "Mensagem enviada com sucesso"
        echo "$response"
        return 0
    else
        log_error "Falha ao enviar mensagem"
        return 1
    fi
}

# Monitorar instâncias
monitor_instances() {
    log_step "Iniciando monitoramento de instâncias"
    log_info "Pressione Ctrl+C para parar"
    
    while true; do
        clear
        echo -e "${CYAN}=== MONITORAMENTO EVOLUTION API ===${NC}"
        echo "$(date)"
        echo
        
        # Status geral
        echo -e "${YELLOW}Backend Status:${NC}"
        response=$(http_request GET "$BACKEND_URL/health" 2>/dev/null) && echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "ERROR"
        echo
        
        # WhatsApp status
        echo -e "${YELLOW}WhatsApp Status:${NC}"
        if response=$(http_request GET "$BACKEND_URL/api/whatsapp/health" 2>/dev/null); then
            service=$(echo "$response" | grep -o '"service":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
            ok=$(echo "$response" | grep -o '"ok":[^,}]*' | cut -d':' -f2 | tr -d ' ' || echo "false")
            echo "$service: $ok"
        else
            echo "ERROR"
        fi
        echo
        
        # Instâncias (se Evolution API disponível)
        if [ -n "${EVO_URL:-}" ] && curl -s "$EVO_URL" > /dev/null 2>&1; then
            echo -e "${YELLOW}Evolution API Instances:${NC}"
            if [ -n "${EVO_APIKEY:-}" ]; then
                instances=$(curl -s -H "apikey: $EVO_APIKEY" "$EVO_URL/instance/fetchInstances" 2>/dev/null)
                if [ -n "$instances" ] && [ "$instances" != "[]" ]; then
                    echo "$instances" | grep -o '"instanceName":"[^"]*"' | cut -d'"' -f4 | head -5
                else
                    echo "Nenhuma instância encontrada"
                fi
            else
                echo "APIKEY não configurada"
            fi
        else
            echo -e "${YELLOW}Evolution API:${NC} Não disponível"
        fi
        
        sleep 5
    done
}

# Executar suite completa de testes
run_full_test_suite() {
    log_step "Executando suite completa de testes"
    
    local instance_name="test_$(date +%s)"
    local test_results=()
    
    # Teste 1: Pré-requisitos
    if check_prerequisites; then
        test_results+=("✅ Pré-requisitos: PASS")
    else
        test_results+=("❌ Pré-requisitos: FAIL")
    fi
    
    # Teste 2: Health checks
    if test_health_checks; then
        test_results+=("✅ Health checks: PASS")
    else
        test_results+=("❌ Health checks: FAIL")
    fi
    
    # Teste 3: Criação de instância
    if create_instance "$instance_name"; then
        test_results+=("✅ Criação de instância: PASS")
        
        # Teste 4: QR Code
        if get_qr_code "$instance_name"; then
            test_results+=("✅ QR Code: PASS")
        else
            test_results+=("❌ QR Code: FAIL")
        fi
    else
        test_results+=("❌ Criação de instância: FAIL")
        test_results+=("⏭️  QR Code: SKIP")
    fi
    
    # Relatório final
    log_step "Relatório de Testes"
    for result in "${test_results[@]}"; do
        echo "$result"
    done
    
    # Limpar arquivos temporários
    rm -f /tmp/evo_test_instance
    
    log_success "Suite de testes completa"
}

# ==========================================
# MENU DE AJUDA
# ==========================================

show_help() {
    echo -e "${CYAN}Evolution API Test Script${NC}"
    echo "Script completo para testar integração WhatsApp Evolution API"
    echo
    echo -e "${YELLOW}Uso:${NC}"
    echo "  $0 <comando> [argumentos]"
    echo
    echo -e "${YELLOW}Comandos:${NC}"
    echo "  check          - Verificar pré-requisitos"
    echo "  health         - Testar health checks"
    echo "  create [name]  - Criar instância WhatsApp"
    echo "  qr [name]      - Obter QR Code para conectar"
    echo "  connect [name] - Conectar instância (mostra QR)"
    echo "  send [name] [number] [message] - Enviar mensagem teste"
    echo "  monitor        - Monitorar instâncias em tempo real"
    echo "  test           - Executar suite completa de testes"
    echo "  help           - Mostrar esta ajuda"
    echo
    echo -e "${YELLOW}Exemplos:${NC}"
    echo "  $0 create minha_instancia"
    echo "  $0 qr minha_instancia"
    echo "  $0 send minha_instancia +5511999887766 'Olá teste'"
    echo "  $0 monitor"
    echo "  $0 test"
    echo
    echo -e "${YELLOW}Variáveis de Ambiente:${NC}"
    echo "  EVO_URL        - URL da Evolution API (padrão: http://localhost:8080)"
    echo "  EVO_APIKEY     - API Key da Evolution API"
    echo "  BACKEND_URL    - URL do backend SPR (padrão: http://localhost:3002)"
    echo
    echo -e "${YELLOW}Pré-requisitos:${NC}"
    echo "  - curl (para requisições HTTP)"
    echo "  - jq (para parsing JSON) - opcional"
    echo "  - Backend SPR rodando"
    echo "  - Evolution API configurada (opcional)"
}

# ==========================================
# MAIN
# ==========================================

main() {
    local command=${1:-help}
    
    case $command in
        "check")
            check_prerequisites
            ;;
        "health")
            check_prerequisites
            test_health_checks
            ;;
        "create")
            check_prerequisites
            create_instance "$2"
            ;;
        "qr")
            check_prerequisites
            get_qr_code "$2"
            ;;
        "connect")
            check_prerequisites
            connect_instance "$2"
            ;;
        "send")
            check_prerequisites
            send_test_message "$2" "$3" "$4"
            ;;
        "monitor")
            check_prerequisites
            monitor_instances
            ;;
        "test")
            run_full_test_suite
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "Comando '$command' não reconhecido"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Executar comando principal
main "$@"