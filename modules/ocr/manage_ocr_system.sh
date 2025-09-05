#!/bin/bash
#
# Script de gerenciamento do Sistema OCR Enhanced Multi-Agent
# Versão 2.0
#

SERVICE_NAME="ocr-enhanced"
SERVICE_PORT=8003
SERVICE_DIR="/opt/spr/backend"
LOG_FILE="/opt/spr/_logs/ocr_management.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Status check function
check_status() {
    log "Verificando status do sistema OCR Enhanced..."
    
    # Check if service is running
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✓ Serviço $SERVICE_NAME está ativo${NC}"
        
        # Check if port is responding
        if curl -s "http://localhost:$SERVICE_PORT/" > /dev/null; then
            echo -e "${GREEN}✓ API respondendo na porta $SERVICE_PORT${NC}"
            
            # Get detailed status
            status=$(curl -s "http://localhost:$SERVICE_PORT/system/status")
            if [ $? -eq 0 ]; then
                echo -e "${BLUE}📊 Status do sistema:${NC}"
                echo "$status" | jq -r '
                    .processing_stats as $stats |
                    "   Total processado: \($stats.total_processed)",
                    "   Sucessos: \($stats.successful)",
                    "   Falhas: \($stats.failed)",
                    "   Tempo médio: \($stats.average_processing_time | tostring | .[:5])s"
                '
                
                # Agent status
                echo -e "${BLUE}👥 Status dos agentes:${NC}"
                echo "$status" | jq -r '
                    .agent_pools | to_entries[] |
                    "   \(.key): \(.value | length) agentes (\(.value | map(select(.is_active)) | length) ativos)"
                '
            fi
        else
            echo -e "${RED}✗ API não está respondendo na porta $SERVICE_PORT${NC}"
        fi
    else
        echo -e "${RED}✗ Serviço $SERVICE_NAME não está ativo${NC}"
        
        # Check if process is running manually
        if pgrep -f "ocr_service_enhanced" > /dev/null; then
            echo -e "${YELLOW}⚠ Processo OCR encontrado rodando manualmente${NC}"
        fi
    fi
    
    # Check Qdrant
    if curl -s "http://localhost:6333/collections" > /dev/null; then
        echo -e "${GREEN}✓ Qdrant está funcionando${NC}"
    else
        echo -e "${RED}✗ Qdrant não está acessível${NC}"
    fi
}

# Start function
start_service() {
    log "Iniciando sistema OCR Enhanced..."
    
    # Check dependencies first
    echo -e "${BLUE}🔍 Verificando dependências...${NC}"
    
    # Check Python packages
    python3 -c "
import sys
packages = ['fastapi', 'uvicorn', 'pytesseract', 'easyocr', 'qdrant_client', 'sentence_transformers']
missing = []
for pkg in packages:
    try:
        __import__(pkg)
    except ImportError:
        missing.append(pkg)

if missing:
    print(f'Pacotes faltando: {missing}')
    sys.exit(1)
else:
    print('✓ Todas as dependências Python estão disponíveis')
"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Dependências faltando. Execute: pip3 install -r requirements.txt${NC}"
        exit 1
    fi
    
    # Start with systemd if available
    if systemctl is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
        echo -e "${BLUE}🚀 Iniciando via systemd...${NC}"
        systemctl start $SERVICE_NAME
        sleep 5
        
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo -e "${GREEN}✓ Serviço iniciado com sucesso${NC}"
        else
            echo -e "${RED}✗ Falha ao iniciar via systemd${NC}"
            echo -e "${YELLOW}📋 Logs do systemd:${NC}"
            systemctl status $SERVICE_NAME --no-pager -l
        fi
    else
        echo -e "${BLUE}🚀 Iniciando manualmente...${NC}"
        cd "$SERVICE_DIR"
        nohup python3 start_enhanced_ocr.py > /opt/spr/_logs/ocr_manual.log 2>&1 &
        sleep 10
        
        if pgrep -f "ocr_service_enhanced" > /dev/null; then
            echo -e "${GREEN}✓ Serviço iniciado manualmente${NC}"
        else
            echo -e "${RED}✗ Falha ao iniciar manualmente${NC}"
        fi
    fi
}

# Stop function
stop_service() {
    log "Parando sistema OCR Enhanced..."
    
    # Stop systemd service
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}⏹ Parando serviço systemd...${NC}"
        systemctl stop $SERVICE_NAME
    fi
    
    # Kill any manual processes
    if pgrep -f "ocr_service_enhanced" > /dev/null; then
        echo -e "${YELLOW}⏹ Parando processos manuais...${NC}"
        pkill -f "ocr_service_enhanced"
        sleep 2
        
        # Force kill if still running
        if pgrep -f "ocr_service_enhanced" > /dev/null; then
            echo -e "${YELLOW}⚠ Forçando parada de processos restantes...${NC}"
            pkill -9 -f "ocr_service_enhanced"
        fi
    fi
    
    echo -e "${GREEN}✓ Sistema parado${NC}"
}

# Restart function
restart_service() {
    log "Reiniciando sistema OCR Enhanced..."
    stop_service
    sleep 3
    start_service
}

# Test function
test_service() {
    log "Executando testes do sistema..."
    
    if ! curl -s "http://localhost:$SERVICE_PORT/" > /dev/null; then
        echo -e "${RED}✗ Serviço não está respondendo${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🧪 Executando testes...${NC}"
    cd "$SERVICE_DIR"
    python3 test_enhanced_ocr.py
}

# Logs function
show_logs() {
    echo -e "${BLUE}📋 Logs do sistema:${NC}"
    
    if [ -f "/opt/spr/_logs/ocr_enhanced.log" ]; then
        echo -e "${YELLOW}=== Logs do serviço ===${NC}"
        tail -50 "/opt/spr/_logs/ocr_enhanced.log"
    fi
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}=== Logs do systemd ===${NC}"
        journalctl -u $SERVICE_NAME --no-pager -l -n 50
    fi
    
    if [ -f "/opt/spr/_logs/ocr_management.log" ]; then
        echo -e "${YELLOW}=== Logs de gerenciamento ===${NC}"
        tail -20 "/opt/spr/_logs/ocr_management.log"
    fi
}

# Install function
install_service() {
    log "Instalando sistema OCR Enhanced..."
    
    echo -e "${BLUE}📦 Instalando dependências...${NC}"
    
    # Install Python packages
    pip3 install fastapi uvicorn sentence-transformers torch easyocr opencv-python qdrant-client spacy transformers
    
    # Make scripts executable
    chmod +x "$SERVICE_DIR/start_enhanced_ocr.py"
    chmod +x "$SERVICE_DIR/test_enhanced_ocr.py"
    chmod +x "$0"
    
    # Enable systemd service
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        systemctl daemon-reload
        systemctl enable $SERVICE_NAME
        echo -e "${GREEN}✓ Serviço systemd configurado${NC}"
    fi
    
    # Create log directories
    mkdir -p /opt/spr/_logs /opt/spr/_uploads /tmp/ocr_preprocessing
    
    echo -e "${GREEN}✓ Instalação concluída${NC}"
}

# Performance monitoring
monitor_performance() {
    echo -e "${BLUE}📊 Monitor de Performance${NC}"
    
    while true; do
        clear
        echo "=== OCR Enhanced Performance Monitor ==="
        date
        echo
        
        # Service status
        if curl -s "http://localhost:$SERVICE_PORT/" > /dev/null; then
            echo -e "${GREEN}● Serviço Online${NC}"
            
            # Get stats
            stats=$(curl -s "http://localhost:$SERVICE_PORT/system/status" | jq -r '
                .processing_stats as $stats |
                "Processados: \($stats.total_processed)",
                "Sucessos: \($stats.successful)",
                "Falhas: \($stats.failed)",
                "Tempo médio: \($stats.average_processing_time | tostring | .[:5])s"
            ')
            echo "$stats"
        else
            echo -e "${RED}● Serviço Offline${NC}"
        fi
        
        echo
        echo "=== Recursos do Sistema ==="
        
        # CPU and Memory usage
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
        mem_usage=$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')
        
        echo "CPU: ${cpu_usage}%"
        echo "Memória: ${mem_usage}"
        
        # OCR process info
        ocr_pids=$(pgrep -f "ocr_service_enhanced")
        if [ ! -z "$ocr_pids" ]; then
            echo
            echo "=== Processos OCR ==="
            ps -p $ocr_pids -o pid,ppid,%cpu,%mem,cmd --no-headers
        fi
        
        echo
        echo "Pressione Ctrl+C para sair..."
        sleep 5
    done
}

# Help function
show_help() {
    echo "Sistema OCR Enhanced Multi-Agent - Gerenciador"
    echo "Versão 2.0"
    echo
    echo "Uso: $0 [COMANDO]"
    echo
    echo "Comandos disponíveis:"
    echo "  status      Mostra status do sistema"
    echo "  start       Inicia o serviço"
    echo "  stop        Para o serviço"
    echo "  restart     Reinicia o serviço"
    echo "  test        Executa testes"
    echo "  logs        Mostra logs do sistema"
    echo "  install     Instala dependências e configura"
    echo "  monitor     Monitor de performance em tempo real"
    echo "  help        Mostra esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 start    # Inicia o sistema"
    echo "  $0 status   # Verifica status"
    echo "  $0 test     # Executa testes"
}

# Main execution
case "$1" in
    status)
        check_status
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    test)
        test_service
        ;;
    logs)
        show_logs
        ;;
    install)
        install_service
        ;;
    monitor)
        monitor_performance
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Comando inválido: $1${NC}"
        echo
        show_help
        exit 1
        ;;
esac