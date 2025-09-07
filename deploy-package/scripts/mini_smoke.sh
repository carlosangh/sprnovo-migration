#!/bin/bash

# SPR - Mini Smoke Test
# Monitoramento rápido de saúde do sistema

echo "💊 SPR - MINI SMOKE TEST - Health Check Rápido"
echo "==============================================="

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ISSUES=0

quick_check() {
    local url=$1
    local name=$2
    local timeout=${3:-3}
    
    echo -n "  $name... "
    
    if curl -s --connect-timeout $timeout --max-time $timeout "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        ((ISSUES++))
    fi
}

file_check() {
    local file=$1
    local name=$2
    
    echo -n "  $name... "
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        ((ISSUES++))
    fi
}

# Timestamp
echo -e "${BLUE}Timestamp: $(date '+%Y-%m-%d %H:%M:%S')${NC}"

# Quick health checks
echo -e "\n${BLUE}SERVIÇOS ESSENCIAIS:${NC}"
quick_check "http://localhost:3002/health" "Backend Auth" 2
quick_check "http://localhost:8080" "Evolution API Local" 2

echo -e "\n${BLUE}ARQUIVOS CRÍTICOS:${NC}"
file_check "/home/cadu/SPRNOVO/modules/auth/backend_auth.py" "Backend Auth Script"
file_check "/home/cadu/SPRNOVO/scripts/evo_test.sh" "Evolution Test Script" 
file_check "/home/cadu/SPRNOVO/frontend/package.json" "Frontend Config"

echo -e "\n${BLUE}ESTRUTURA FRONTEND:${NC}"
file_check "/home/cadu/SPRNOVO/frontend/app/layout.tsx" "App Layout"
file_check "/home/cadu/SPRNOVO/frontend/components/layout/sidebar.tsx" "Sidebar"
file_check "/home/cadu/SPRNOVO/frontend/app/commodities/page.tsx" "Commodities Page"

# Verificar processos ativos
echo -e "\n${BLUE}PROCESSOS ATIVOS:${NC}"
echo -n "  Backend Python... "
if pgrep -f "backend_auth.py" > /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    ((ISSUES++))
fi

# Resultado final
echo -e "\n==============================================="
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}🟢 SISTEMA SAUDÁVEL - Todos os componentes OK${NC}"
    exit 0
else
    echo -e "${YELLOW}🟡 $ISSUES PROBLEMAS DETECTADOS${NC}"
    echo -e "${YELLOW}   Execute checklist completo para diagnóstico.${NC}"
    exit 1
fi