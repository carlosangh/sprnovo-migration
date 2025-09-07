#!/bin/bash

# ==========================================
# SETUP ENVIRONMENT EVOLUTION API
# Configuração automática do ambiente
# ==========================================

set -e  # Parar em caso de erro

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

# Configurações padrão
DEFAULT_EVO_URL="http://localhost:8080"
DEFAULT_EVO_APIKEY="your-api-key-here"
DEFAULT_WEBHOOK_TOKEN="your-webhook-token"

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

# ==========================================
# FUNÇÕES PRINCIPAIS
# ==========================================

# Verificar se arquivo .env existe
check_env_file() {
    if [ -f ".env" ]; then
        log_info "Arquivo .env encontrado"
        return 0
    else
        log_warning "Arquivo .env não encontrado"
        return 1
    fi
}

# Criar arquivo .env
create_env_file() {
    log_step "Criando arquivo .env"
    
    cat > .env << EOF
# ==========================================
# CONFIGURAÇÃO SPR BACKEND
# ==========================================

# Servidor
PORT=3002
NODE_ENV=development

# ==========================================
# EVOLUTION API - WHATSAPP
# ==========================================

# URL da Evolution API (padrão local)
EVO_URL=$DEFAULT_EVO_URL
EVOLUTION_API_URL=$DEFAULT_EVO_URL

# API Key da Evolution API
EVO_APIKEY=$DEFAULT_EVO_APIKEY
EVOLUTION_API_KEY=$DEFAULT_EVO_APIKEY

# Token do Webhook
EVO_WEBHOOK_TOKEN=$DEFAULT_WEBHOOK_TOKEN
EVOLUTION_WEBHOOK_TOKEN=$DEFAULT_WEBHOOK_TOKEN

# ==========================================
# SERVIÇOS SPR
# ==========================================

# URL do serviço Market Trap Radar
SPR_MTR_SERVICE_URL=http://localhost:3001/mtr/detect

# URLs de serviços externos
WPPCONNECT_BASE_URL=http://localhost:3003

# ==========================================
# CONFIGURAÇÕES DE DESENVOLVIMENTO
# ==========================================

# Debug
DEBUG=spr:*

# Timeout para requisições (ms)
REQUEST_TIMEOUT=10000

# Configurações de CORS
CORS_ORIGIN=http://localhost:3000,https://www.royalnegociosagricolas.com.br

EOF

    log_success "Arquivo .env criado com configurações padrão"
    log_warning "IMPORTANTE: Edite o arquivo .env com suas configurações reais"
}

# Atualizar configurações no .env
update_env_config() {
    local key=$1
    local value=$2
    local file=".env"
    
    if grep -q "^${key}=" "$file"; then
        # Atualizar linha existente
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
        log_info "Configuração $key atualizada"
    else
        # Adicionar nova linha
        echo "${key}=${value}" >> "$file"
        log_info "Configuração $key adicionada"
    fi
}

# Configurar Evolution API interativamente
configure_evolution_api() {
    log_step "Configuração interativa da Evolution API"
    
    echo -e "${YELLOW}Configurações atuais:${NC}"
    if [ -f ".env" ]; then
        echo "EVO_URL: $(grep '^EVO_URL=' .env | cut -d'=' -f2 2>/dev/null || echo 'não definido')"
        echo "EVO_APIKEY: $(grep '^EVO_APIKEY=' .env | cut -d'=' -f2 | sed 's/./*/g' 2>/dev/null || echo 'não definido')"
    fi
    echo
    
    read -p "URL da Evolution API [$DEFAULT_EVO_URL]: " evo_url
    evo_url=${evo_url:-$DEFAULT_EVO_URL}
    
    read -p "API Key da Evolution API: " evo_apikey
    evo_apikey=${evo_apikey:-$DEFAULT_EVO_APIKEY}
    
    read -p "Token do Webhook (opcional): " webhook_token
    webhook_token=${webhook_token:-$DEFAULT_WEBHOOK_TOKEN}
    
    # Atualizar configurações
    update_env_config "EVO_URL" "$evo_url"
    update_env_config "EVOLUTION_API_URL" "$evo_url"
    update_env_config "EVO_APIKEY" "$evo_apikey"
    update_env_config "EVOLUTION_API_KEY" "$evo_apikey"
    update_env_config "EVO_WEBHOOK_TOKEN" "$webhook_token"
    update_env_config "EVOLUTION_WEBHOOK_TOKEN" "$webhook_token"
    
    log_success "Configurações da Evolution API atualizadas"
}

# Testar configurações
test_configuration() {
    log_step "Testando configurações"
    
    if [ ! -f ".env" ]; then
        log_error "Arquivo .env não encontrado"
        return 1
    fi
    
    # Source das variáveis
    set -a  # Exportar todas as variáveis
    source .env
    set +a
    
    # Testar URL da Evolution API
    if [ -n "${EVO_URL:-}" ]; then
        if curl -s --max-time 5 "$EVO_URL" > /dev/null 2>&1; then
            log_success "Evolution API acessível em $EVO_URL"
        else
            log_warning "Evolution API não acessível em $EVO_URL"
        fi
    else
        log_error "EVO_URL não configurada"
    fi
    
    # Testar API Key
    if [ -n "${EVO_APIKEY:-}" ] && [ "$EVO_APIKEY" != "$DEFAULT_EVO_APIKEY" ]; then
        log_success "API Key configurada"
    else
        log_warning "API Key não configurada ou usando valor padrão"
    fi
    
    # Testar backend local
    if curl -s --max-time 5 "http://localhost:3002/health" > /dev/null 2>&1; then
        log_success "Backend SPR está rodando"
    else
        log_warning "Backend SPR não está rodando"
        log_info "Execute: node spr-backend-complete.js"
    fi
}

# Mostrar resumo das configurações
show_config_summary() {
    log_step "Resumo das Configurações"
    
    if [ -f ".env" ]; then
        echo -e "${CYAN}Configurações encontradas em .env:${NC}"
        echo
        
        # Mostrar configurações principais (mascarar senhas)
        echo "🌐 EVO_URL: $(grep '^EVO_URL=' .env | cut -d'=' -f2 2>/dev/null || echo 'não definido')"
        
        local apikey=$(grep '^EVO_APIKEY=' .env | cut -d'=' -f2 2>/dev/null)
        if [ -n "$apikey" ] && [ "$apikey" != "$DEFAULT_EVO_APIKEY" ]; then
            echo "🔑 EVO_APIKEY: ${apikey:0:8}***"
        else
            echo "🔑 EVO_APIKEY: não configurado"
        fi
        
        local webhook=$(grep '^EVO_WEBHOOK_TOKEN=' .env | cut -d'=' -f2 2>/dev/null)
        if [ -n "$webhook" ] && [ "$webhook" != "$DEFAULT_WEBHOOK_TOKEN" ]; then
            echo "🎣 WEBHOOK_TOKEN: ${webhook:0:8}***"
        else
            echo "🎣 WEBHOOK_TOKEN: não configurado"
        fi
        
        echo "🚀 PORT: $(grep '^PORT=' .env | cut -d'=' -f2 2>/dev/null || echo '3002')"
        echo
    else
        log_warning "Arquivo .env não encontrado"
    fi
}

# Criar scripts de exemplo
create_example_scripts() {
    log_step "Criando scripts de exemplo"
    
    # Script de início rápido
    cat > scripts/start_dev.sh << 'EOF'
#!/bin/bash
# Início rápido do ambiente de desenvolvimento

echo "🚀 Iniciando ambiente SPR..."
echo

# Carregar variáveis de ambiente
if [ -f ".env" ]; then
    source .env
    echo "✅ Variáveis de ambiente carregadas"
else
    echo "❌ Arquivo .env não encontrado"
    exit 1
fi

# Iniciar backend
echo "🔧 Iniciando backend SPR..."
node spr-backend-complete.js &
BACKEND_PID=$!

echo "Backend PID: $BACKEND_PID"
echo "Backend URL: http://localhost:${PORT:-3002}"
echo
echo "Para parar: kill $BACKEND_PID"
echo "Para monitorar: ./scripts/monitor_dashboard.sh"
echo "Para testar: ./scripts/evo_test.sh test"
EOF

    chmod +x scripts/start_dev.sh
    
    # Script de configuração rápida
    cat > scripts/quick_config.sh << 'EOF'
#!/bin/bash
# Configuração rápida com valores comuns

echo "🔧 Configuração rápida Evolution API"
echo

# Solicitar apenas informações essenciais
read -p "URL da Evolution API [http://localhost:8080]: " evo_url
evo_url=${evo_url:-http://localhost:8080}

read -p "API Key: " evo_apikey

if [ -n "$evo_apikey" ]; then
    sed -i "s|^EVO_URL=.*|EVO_URL=${evo_url}|" .env
    sed -i "s|^EVO_APIKEY=.*|EVO_APIKEY=${evo_apikey}|" .env
    sed -i "s|^EVOLUTION_API_URL=.*|EVOLUTION_API_URL=${evo_url}|" .env
    sed -i "s|^EVOLUTION_API_KEY=.*|EVOLUTION_API_KEY=${evo_apikey}|" .env
    
    echo "✅ Configuração salva em .env"
    echo "🧪 Para testar: ./scripts/evo_test.sh test"
else
    echo "❌ API Key é obrigatória"
fi
EOF

    chmod +x scripts/quick_config.sh
    
    log_success "Scripts de exemplo criados em scripts/"
}

# ==========================================
# MENU PRINCIPAL
# ==========================================

show_help() {
    echo -e "${CYAN}Setup Evolution API Environment${NC}"
    echo "Configuração automática do ambiente para Evolution API"
    echo
    echo -e "${YELLOW}Uso:${NC}"
    echo "  $0 <comando>"
    echo
    echo -e "${YELLOW}Comandos:${NC}"
    echo "  init     - Configuração inicial completa"
    echo "  config   - Configurar Evolution API interativamente"  
    echo "  test     - Testar configurações atuais"
    echo "  show     - Mostrar resumo das configurações"
    echo "  reset    - Recriar arquivo .env"
    echo "  help     - Mostrar esta ajuda"
    echo
    echo -e "${YELLOW}Exemplos:${NC}"
    echo "  $0 init    # Primeira vez"
    echo "  $0 config  # Alterar configurações"
    echo "  $0 test    # Verificar se tudo está funcionando"
}

main() {
    local command=${1:-help}
    
    case $command in
        "init")
            log_step "Inicialização completa do ambiente"
            if ! check_env_file; then
                create_env_file
            fi
            configure_evolution_api
            create_example_scripts
            test_configuration
            show_config_summary
            log_success "Ambiente configurado com sucesso!"
            ;;
        "config")
            if ! check_env_file; then
                create_env_file
            fi
            configure_evolution_api
            test_configuration
            ;;
        "test")
            test_configuration
            ;;
        "show")
            show_config_summary
            ;;
        "reset")
            log_warning "Recriando arquivo .env (backup em .env.backup)"
            if [ -f ".env" ]; then
                cp .env .env.backup
            fi
            create_env_file
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