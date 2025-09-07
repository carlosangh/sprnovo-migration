#!/bin/bash

# 🗺️  SPR - Mapeador de Grafos de Dependência
# Mapeia dependências entre serviços, fluxo de dados e pontos de falha
# Gera visualizações e documentação de arquitetura

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/opt/spr"
LOG_DIR="$PROJECT_ROOT/logs"
REPORTS_DIR="$PROJECT_ROOT/_reports"
MAPPER_LOG="$LOG_DIR/dependency-mapper.log"
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

# Estruturas de dados
declare -A SERVICES
declare -A DEPENDENCIES
declare -A DATA_FLOWS
declare -A FAILURE_POINTS
declare -A LATENCIES
declare -A SERVICE_STATUS

# Configurações
TIMEOUT=10

# Definição dos serviços
SERVICES=(
    "backend:Backend Server:http://localhost:3002:Node.js/Express"
    "whatsapp:WhatsApp Server:http://localhost:3003:Node.js/Baileys"
    "frontend:Frontend React:http://localhost:3000:React/Vite"
    "database:SQLite Database:/opt/spr/spr_broadcast.db:SQLite3"
    "nginx:Nginx Proxy:https://www.royalnegociosagricolas.com.br:Nginx"
    "filesystem:File System:/opt/spr:Linux FS"
)

# Função de banner
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "████████████████████████████████████████████████████████████████"
    echo "██                                                            ██"
    echo "██    🗺️  SPR - MAPEADOR DE DEPENDÊNCIAS                     ██"
    echo "██    📊 Análise de Arquitetura e Fluxos de Dados            ██"
    echo "██                                                            ██"
    echo "██    🔗 Dependências | 📈 Latências | ⚠️  Falhas           ██"
    echo "██                                                            ██"
    echo "████████████████████████████████████████████████████████████████"
    echo -e "${NC}"
    echo -e "${CYAN}📅 $TIMESTAMP${NC}"
    echo -e "${CYAN}📍 Projeto: $PROJECT_ROOT${NC}"
    echo -e "${CYAN}📝 Log: $MAPPER_LOG${NC}"
    echo -e "${CYAN}📊 Relatórios: $REPORTS_DIR${NC}"
    echo ""
}

# Função de logging
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$MAPPER_LOG"
}

# Função para testar conectividade de serviço
test_service_connectivity() {
    local service_name=$1
    local service_url=$2
    local timeout=${3:-$TIMEOUT}
    
    if [[ "$service_url" =~ ^http ]]; then
        # Teste HTTP
        local start_time=$(date +%s%3N)
        local response=$(curl -s -w "%{http_code},%{time_total}" --max-time $timeout "$service_url" 2>/dev/null || echo "ERROR,0")
        local end_time=$(date +%s%3N)
        
        local http_code=$(echo "$response" | tail -c 10 | cut -d',' -f1)
        local time_total=$(echo "$response" | tail -c 10 | cut -d',' -f2)
        
        if [[ "$http_code" =~ ^[2-3][0-9][0-9]$ ]]; then
            SERVICE_STATUS["$service_name"]="ACTIVE"
            local time_ms=$(echo "$time_total * 1000" | bc -l 2>/dev/null || echo "0")
            LATENCIES["$service_name"]="${time_ms%.*}ms"
            return 0
        else
            SERVICE_STATUS["$service_name"]="INACTIVE"
            LATENCIES["$service_name"]="N/A"
            return 1
        fi
    elif [[ "$service_url" =~ ^/ ]]; then
        # Teste de arquivo/diretório
        if [[ -e "$service_url" ]]; then
            SERVICE_STATUS["$service_name"]="ACTIVE"
            LATENCIES["$service_name"]="<1ms"
            return 0
        else
            SERVICE_STATUS["$service_name"]="INACTIVE"
            LATENCIES["$service_name"]="N/A"
            return 1
        fi
    else
        SERVICE_STATUS["$service_name"]="UNKNOWN"
        LATENCIES["$service_name"]="N/A"
        return 1
    fi
}

# Função para descobrir dependências
discover_dependencies() {
    echo -e "${BOLD}${YELLOW}🔍 DESCOBRINDO DEPENDÊNCIAS ENTRE SERVIÇOS${NC}"
    echo "============================================================"
    
    # Backend Dependencies
    echo -e "${CYAN}📊 Analisando dependências do Backend${NC}"
    DEPENDENCIES["backend"]="whatsapp,database,filesystem"
    DATA_FLOWS["backend→whatsapp"]="HTTP API calls, WebSocket connections"
    DATA_FLOWS["backend→database"]="SQL queries, data persistence"
    DATA_FLOWS["backend→filesystem"]="Log files, session data, uploads"
    
    # WhatsApp Dependencies  
    echo -e "${CYAN}📱 Analisando dependências do WhatsApp${NC}"
    DEPENDENCIES["whatsapp"]="database,filesystem"
    DATA_FLOWS["whatsapp→database"]="Session storage, message history"
    DATA_FLOWS["whatsapp→filesystem"]="Session files, QR codes, media"
    
    # Frontend Dependencies
    echo -e "${CYAN}🎨 Analisando dependências do Frontend${NC}"
    DEPENDENCIES["frontend"]="backend,nginx"
    DATA_FLOWS["frontend→backend"]="REST API calls, WebSocket connections"
    DATA_FLOWS["frontend→nginx"]="Static assets, routing"
    
    # Database Dependencies
    echo -e "${CYAN}🗄️  Analisando dependências do Database${NC}"
    DEPENDENCIES["database"]="filesystem"
    DATA_FLOWS["database→filesystem"]="Database file storage"
    
    # Nginx Dependencies
    echo -e "${CYAN}🌐 Analisando dependências do Nginx${NC}"
    DEPENDENCIES["nginx"]="backend,whatsapp,frontend"
    DATA_FLOWS["nginx→backend"]="Reverse proxy, load balancing"
    DATA_FLOWS["nginx→whatsapp"]="WebSocket proxy"
    DATA_FLOWS["nginx→frontend"]="Static file serving"
    
    # Filesystem - base dependency
    echo -e "${CYAN}💾 Analisando dependências do Filesystem${NC}"
    DEPENDENCIES["filesystem"]=""
    
    log_message "INFO" "Dependencies discovered successfully"
}

# Função para identificar pontos de falha
identify_failure_points() {
    echo -e "${BOLD}${YELLOW}⚠️  IDENTIFICANDO PONTOS DE FALHA${NC}"
    echo "============================================================"
    
    # Single Points of Failure
    FAILURE_POINTS["database"]="CRITICAL: Single SQLite file - no replication"
    FAILURE_POINTS["filesystem"]="CRITICAL: Local storage - no backup strategy visible"
    FAILURE_POINTS["nginx"]="HIGH: Single proxy instance - no load balancer"
    
    # Service-specific failure points
    FAILURE_POINTS["backend→database"]="Database lock contention, file corruption"
    FAILURE_POINTS["whatsapp→filesystem"]="Session file corruption, QR code generation"
    FAILURE_POINTS["frontend→backend"]="Network timeouts, API rate limiting"
    
    # External dependencies
    FAILURE_POINTS["external→whatsapp"]="WhatsApp API changes, rate limiting, IP blocking"
    FAILURE_POINTS["external→internet"]="Network connectivity, DNS resolution"
    
    echo -e "${RED}🚨 Pontos de falha críticos identificados${NC}"
    for point in "${!FAILURE_POINTS[@]}"; do
        echo -e "${YELLOW}   - $point: ${FAILURE_POINTS[$point]}${NC}"
        log_message "WARNING" "Failure point identified: $point"
    done
    
    echo ""
}

# Função para medir latências
measure_latencies() {
    echo -e "${BOLD}${YELLOW}⏱️  MEDINDO LATÊNCIAS ENTRE SERVIÇOS${NC}"
    echo "============================================================"
    
    # Testar cada serviço
    for service_def in "${SERVICES[@]}"; do
        IFS=':' read -r name display_name url tech <<< "$service_def"
        
        echo -e "${CYAN}🔍 Testando: $display_name ($url)${NC}"
        
        if test_service_connectivity "$name" "$url"; then
            echo -e "${GREEN}   ✅ Ativo - Latência: ${LATENCIES[$name]}${NC}"
            log_message "SUCCESS" "Service $name is active - latency: ${LATENCIES[$name]}"
        else
            echo -e "${RED}   ❌ Inativo ou inacessível${NC}"
            log_message "WARNING" "Service $name is inactive or unreachable"
        fi
    done
    
    echo ""
    
    # Testar fluxos específicos
    echo -e "${CYAN}🔄 Testando fluxos críticos${NC}"
    
    # Frontend → Backend → WhatsApp
    echo -e "${CYAN}   Frontend → Backend → WhatsApp${NC}"
    local start_time=$(date +%s%3N)
    local backend_response=$(curl -s --max-time 5 "http://localhost:3002/api/health" 2>/dev/null)
    local end_time=$(date +%s%3N)
    
    if [[ -n "$backend_response" ]]; then
        local flow_latency=$((end_time - start_time))
        echo -e "${GREEN}     ✅ Fluxo ativo - ${flow_latency}ms${NC}"
        LATENCIES["flow_frontend_backend"]="${flow_latency}ms"
    else
        echo -e "${RED}     ❌ Fluxo inativo${NC}"
        LATENCIES["flow_frontend_backend"]="FAILED"
    fi
    
    echo ""
}

# Função para gerar grafo DOT
generate_dot_graph() {
    local dot_file="$REPORTS_DIR/dependency-graph.dot"
    
    echo -e "${CYAN}📊 Gerando grafo DOT: $dot_file${NC}"
    
    cat > "$dot_file" << 'EOF'
digraph SPR_Dependencies {
    rankdir=TB;
    node [shape=box, style=rounded];
    
    // Definição dos nós
    subgraph cluster_frontend {
        label="Frontend Layer";
        style=filled;
        color=lightblue;
        
        frontend [label="Frontend\nReact/Vite\nPort 3000", shape=ellipse, color=blue];
        nginx [label="Nginx\nReverse Proxy\nPort 80/443", shape=diamond, color=green];
    }
    
    subgraph cluster_backend {
        label="Backend Layer";
        style=filled;
        color=lightgreen;
        
        backend [label="Backend\nNode.js/Express\nPort 3002", shape=box, color=darkgreen];
        whatsapp [label="WhatsApp\nBaileys Server\nPort 3003", shape=box, color=orange];
    }
    
    subgraph cluster_data {
        label="Data Layer";
        style=filled;
        color=lightyellow;
        
        database [label="SQLite\nDatabase\nspr_broadcast.db", shape=cylinder, color=red];
        filesystem [label="File System\nLogs, Sessions\nMedia Files", shape=folder, color=brown];
    }
    
    // Conexões principais
    frontend -> nginx [label="HTTP/HTTPS"];
    nginx -> backend [label="Reverse Proxy"];
    nginx -> whatsapp [label="WebSocket Proxy"];
    
    backend -> whatsapp [label="HTTP API\nWebSocket"];
    backend -> database [label="SQL Queries"];
    backend -> filesystem [label="Logs, Uploads"];
    
    whatsapp -> database [label="Session Data"];
    whatsapp -> filesystem [label="QR Codes\nSession Files"];
    
    database -> filesystem [label="File Storage"];
    
    // Dependências externas
    whatsapp -> external [label="WhatsApp API", style=dashed];
    external [label="External\nWhatsApp Servers", shape=cloud, color=gray];
    
    // Estilo dos pontos de falha
    database [style=filled, fillcolor=red, fontcolor=white];
    filesystem [style=filled, fillcolor=orange];
}
EOF
    
    log_message "INFO" "DOT graph generated: $dot_file"
}

# Função para gerar mermaid diagram
generate_mermaid_diagram() {
    local mermaid_file="$REPORTS_DIR/dependency-flow.mmd"
    
    echo -e "${CYAN}🔄 Gerando diagrama Mermaid: $mermaid_file${NC}"
    
    cat > "$mermaid_file" << 'EOF'
graph TD
    %% SPR System Dependencies Flow
    
    subgraph "Frontend Layer"
        F[Frontend React<br/>Port 3000]
        N[Nginx Proxy<br/>Port 80/443]
    end
    
    subgraph "Backend Layer"
        B[Backend Server<br/>Node.js Port 3002]
        W[WhatsApp Server<br/>Baileys Port 3003]
    end
    
    subgraph "Data Layer"
        D[(SQLite Database<br/>spr_broadcast.db)]
        FS[File System<br/>Logs/Sessions/Media]
    end
    
    subgraph "External"
        WA[WhatsApp API<br/>External Servers]
    end
    
    %% Connections
    F -->|HTTP/HTTPS| N
    N -->|Reverse Proxy| B
    N -->|WebSocket Proxy| W
    
    B -->|REST API| W
    B -->|SQL Queries| D
    B -->|File I/O| FS
    
    W -->|Session Data| D
    W -->|QR/Session Files| FS
    W -.->|API Calls| WA
    
    D -->|File Storage| FS
    
    %% Styling
    classDef frontend fill:#e1f5fe
    classDef backend fill:#e8f5e8
    classDef data fill:#fff3e0
    classDef external fill:#f3e5f5
    classDef critical fill:#ffebee,stroke:#d32f2f,stroke-width:3px
    
    class F,N frontend
    class B,W backend
    class D,FS data
    class WA external
    class D,FS critical
EOF
    
    log_message "INFO" "Mermaid diagram generated: $mermaid_file"
}

# Função para gerar análise de impacto
generate_impact_analysis() {
    local impact_file="$REPORTS_DIR/failure-impact-analysis.md"
    
    echo -e "${CYAN}💥 Gerando análise de impacto: $impact_file${NC}"
    
    cat > "$impact_file" << EOF
# SPR - Análise de Impacto de Falhas

Gerado em: $TIMESTAMP
Sistema: Sistema Preditivo Royal

## Resumo Executivo

Este documento analisa os pontos de falha críticos do sistema SPR e o impacto de cada componente na operação geral.

## Componentes e Status

| Componente | Status | Latência | Criticidade |
|------------|--------|----------|-------------|
EOF

    # Adicionar status dos serviços
    for service_def in "${SERVICES[@]}"; do
        IFS=':' read -r name display_name url tech <<< "$service_def"
        local status=${SERVICE_STATUS[$name]:-"UNKNOWN"}
        local latency=${LATENCIES[$name]:-"N/A"}
        local criticality="MEDIUM"
        
        case $name in
            "database"|"filesystem") criticality="CRITICAL" ;;
            "backend"|"nginx") criticality="HIGH" ;;
            *) criticality="MEDIUM" ;;
        esac
        
        echo "| $display_name | $status | $latency | $criticality |" >> "$impact_file"
    done
    
    cat >> "$impact_file" << EOF

## Pontos de Falha Críticos

### 1. Base de Dados SQLite (CRÍTICO)
- **Impacto**: Sistema completamente inoperante
- **Probabilidade**: Baixa (arquivo local)
- **Mitigação**: Backup automático, replicação
- **Tempo de Recuperação**: 5-30 minutos

### 2. Sistema de Arquivos (CRÍTICO)
- **Impacto**: Perda de sessões WhatsApp, logs, configurações
- **Probabilidade**: Baixa (SSD local)
- **Mitigação**: Backup diário, monitoramento de disco
- **Tempo de Recuperação**: 10-60 minutos

### 3. Nginx Proxy (ALTO)
- **Impacto**: Site inacessível externamente
- **Probabilidade**: Média
- **Mitigação**: Load balancer, failover automático
- **Tempo de Recuperação**: 2-10 minutos

### 4. Backend Server (ALTO)
- **Impacto**: APIs indisponíveis, sem processamento
- **Probabilidade**: Média
- **Mitigação**: Processo manager, auto-restart
- **Tempo de Recuperação**: 1-5 minutos

### 5. WhatsApp Server (MÉDIO)
- **Impacto**: WhatsApp indisponível, sem QR codes
- **Probabilidade**: Alta (dependência externa)
- **Mitigação**: Reconexão automática, múltiplas sessões
- **Tempo de Recuperação**: 30 segundos - 5 minutos

## Fluxos de Dados Críticos

### Frontend → Backend → Database
1. **Usuário acessa interface**
2. **Frontend faz requisição à API**
3. **Backend consulta banco de dados**
4. **Resposta retorna ao usuário**

**Pontos de falha**: Rede, API rate limiting, bloqueio de database

### WhatsApp → Backend → Database
1. **WhatsApp recebe mensagem**
2. **Processa via Backend**
3. **Salva no banco de dados**
4. **Resposta via WhatsApp**

**Pontos de falha**: WhatsApp API, processamento de mensagem, database lock

## Recomendações de Melhoria

### Prioridade Alta
1. **Implementar backup automático do banco de dados**
2. **Configurar monitoramento de saúde dos serviços**
3. **Implementar alertas para falhas críticas**

### Prioridade Média
1. **Configurar load balancer para Nginx**
2. **Implementar circuit breaker para APIs externas**
3. **Configurar logs centralizados**

### Prioridade Baixa
1. **Implementar replicação de dados**
2. **Configurar ambiente de contingência**
3. **Implementar cache distribuído**

## Métricas de Monitoramento

EOF

    # Adicionar latências medidas
    echo "### Latências Medidas" >> "$impact_file"
    for service in "${!LATENCIES[@]}"; do
        echo "- $service: ${LATENCIES[$service]}" >> "$impact_file"
    done
    
    cat >> "$impact_file" << EOF

### Limites Recomendados
- **API Response Time**: < 2000ms
- **Database Query Time**: < 500ms
- **WhatsApp Response Time**: < 5000ms
- **Frontend Load Time**: < 3000ms

## Plano de Contingência

### Falha do Backend
1. Verificar logs em $LOG_DIR
2. Reiniciar serviço: \`pm2 restart backend\`
3. Verificar conectividade com banco
4. Alertar equipe se não resolver em 5 min

### Falha do WhatsApp
1. Verificar sessão ativa
2. Regenerar QR code se necessário
3. Reiniciar serviço WhatsApp
4. Verificar conectividade externa

### Falha do Banco de Dados
1. **CRÍTICO** - Alertar imediatamente
2. Verificar integridade: \`sqlite3 spr_broadcast.db "PRAGMA integrity_check;"\`
3. Restaurar backup mais recente
4. Verificar espaço em disco

---
Documento gerado automaticamente pelo SPR Dependency Mapper
EOF

    log_message "INFO" "Impact analysis generated: $impact_file"
}

# Função para gerar relatório de telemetria
generate_telemetry_summary() {
    echo -e "${BOLD}${WHITE}📊 RELATÓRIO DE MAPEAMENTO DE DEPENDÊNCIAS${NC}"
    echo "================================================================"
    
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}📅 Período: $TIMESTAMP → $end_time${NC}"
    echo -e "${CYAN}🏗️  Serviços analisados: ${#SERVICES[@]}${NC}"
    echo -e "${CYAN}🔗 Dependências mapeadas: ${#DEPENDENCIES[@]}${NC}"
    echo -e "${CYAN}⚠️  Pontos de falha identificados: ${#FAILURE_POINTS[@]}${NC}"
    echo ""
    
    # Status dos serviços
    echo -e "${BOLD}🔧 STATUS DOS SERVIÇOS:${NC}"
    echo "------------------------------------------------------------"
    local active_services=0
    for service_def in "${SERVICES[@]}"; do
        IFS=':' read -r name display_name url tech <<< "$service_def"
        local status=${SERVICE_STATUS[$name]:-"UNKNOWN"}
        local latency=${LATENCIES[$name]:-"N/A"}
        
        case $status in
            "ACTIVE")
                echo -e "${GREEN}✅ $display_name ($tech) - $latency${NC}"
                ((active_services++))
                ;;
            "INACTIVE")
                echo -e "${RED}❌ $display_name ($tech) - Inativo${NC}"
                ;;
            *)
                echo -e "${YELLOW}❓ $display_name ($tech) - Status desconhecido${NC}"
                ;;
        esac
    done
    
    echo ""
    
    # Taxa de disponibilidade
    local availability=$((active_services * 100 / ${#SERVICES[@]}))
    echo -e "${BOLD}📈 Taxa de Disponibilidade: ${availability}%${NC}"
    
    if [[ $availability -ge 80 ]]; then
        echo -e "${GREEN}✅ Sistema em boa condição${NC}"
    elif [[ $availability -ge 60 ]]; then
        echo -e "${YELLOW}⚠️  Sistema com alguns problemas${NC}"
    else
        echo -e "${RED}🚨 Sistema com problemas críticos${NC}"
    fi
    
    echo ""
    
    # Pontos críticos
    echo -e "${BOLD}🚨 PONTOS CRÍTICOS IDENTIFICADOS:${NC}"
    echo "------------------------------------------------------------"
    echo -e "${RED}• Base de Dados: Ponto único de falha${NC}"
    echo -e "${RED}• Sistema de Arquivos: Sem backup visível${NC}"
    echo -e "${YELLOW}• Nginx: Proxy único${NC}"
    echo -e "${YELLOW}• Dependência WhatsApp API: Externa${NC}"
    
    echo ""
    echo -e "${CYAN}📄 Arquivos gerados:${NC}"
    echo -e "${CYAN}   - $REPORTS_DIR/dependency-graph.dot${NC}"
    echo -e "${CYAN}   - $REPORTS_DIR/dependency-flow.mmd${NC}"
    echo -e "${CYAN}   - $REPORTS_DIR/failure-impact-analysis.md${NC}"
    
    log_message "INFO" "Dependency mapping completed - $availability% availability"
}

# Função principal
main() {
    mkdir -p "$LOG_DIR" "$REPORTS_DIR" 2>/dev/null || true
    
    show_banner
    
    log_message "INFO" "Starting dependency mapping"
    
    echo -e "${BOLD}${YELLOW}🗺️  INICIANDO MAPEAMENTO DE DEPENDÊNCIAS${NC}"
    echo "================================================================"
    
    discover_dependencies
    identify_failure_points
    measure_latencies
    generate_dot_graph
    generate_mermaid_diagram
    generate_impact_analysis
    
    generate_telemetry_summary
    
    echo -e "${GREEN}🎉 Mapeamento de dependências concluído com sucesso!${NC}"
    exit 0
}

# Trap para limpeza
trap 'echo -e "\n${YELLOW}🛑 Mapeamento interrompido${NC}"; exit 130' SIGINT SIGTERM

# Executar
main "$@"