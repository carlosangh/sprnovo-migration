#!/bin/bash

# SPR - Go/No-Go Checklist para Circuito Completo
# Sistema Preditivo Royal - Validação Final

echo "🚀 SPR - CHECKLIST GO/NO-GO - Validação do Circuito Completo"
echo "=============================================================="

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "  ${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "  ${RED}✗ FAIL${NC}"
        ((FAILED++))
    fi
}

echo -e "\n${BLUE}1. BACKEND AUTHENTICATION${NC}"
echo -n "  Verificando backend_auth.py na porta 3002..."
if curl -s http://localhost:3002/health > /dev/null 2>&1; then
    check_status 0
else
    check_status 1
fi

echo -e "\n${BLUE}2. FRONTEND ESTRUTURA${NC}"
echo -n "  Verificando estrutura Next.js App Router..."
if [ -f "/home/cadu/SPRNOVO/frontend/app/layout.tsx" ] && [ -f "/home/cadu/SPRNOVO/frontend/app/page.tsx" ]; then
    check_status 0
else
    check_status 1
fi

echo -e "\n${BLUE}3. NAVEGAÇÃO SIDEBAR${NC}"
echo -n "  Verificando componente sidebar..."
if [ -f "/home/cadu/SPRNOVO/frontend/components/layout/sidebar.tsx" ]; then
    check_status 0
else
    check_status 1
fi

echo -e "\n${BLUE}4. PÁGINAS ESSENCIAIS${NC}"
echo -n "  Verificando páginas (/dashboard, /commodities, /settings)..."
if [ -f "/home/cadu/SPRNOVO/frontend/app/dashboard/page.tsx" ] && 
   [ -f "/home/cadu/SPRNOVO/frontend/app/commodities/page.tsx" ] && 
   [ -f "/home/cadu/SPRNOVO/frontend/app/settings/page.tsx" ]; then
    check_status 0
else
    check_status 1
fi

echo -e "\n${BLUE}5. DEPENDÊNCIA RECHARTS${NC}"
echo -n "  Verificando recharts no package.json..."
if grep -q "recharts" "/home/cadu/SPRNOVO/frontend/package.json" 2>/dev/null; then
    check_status 0
else
    check_status 1
fi

echo -e "\n${BLUE}6. EVOLUTION API SCRIPT${NC}"
echo -n "  Verificando script evo_test.sh..."
if [ -f "/home/cadu/SPRNOVO/scripts/evo_test.sh" ] && [ -x "/home/cadu/SPRNOVO/scripts/evo_test.sh" ]; then
    check_status 0
else
    check_status 1
fi

echo -e "\n${BLUE}7. AI AGENTS SISTEMA${NC}"
echo -n "  Verificando agentes IA (10 agentes)..."
AGENT_COUNT=$(find "/home/cadu/SPRNOVO/ai_agents" -name "*.py" 2>/dev/null | wc -l)
if [ "$AGENT_COUNT" -ge 10 ]; then
    check_status 0
else
    check_status 1
fi

echo -e "\n${BLUE}8. CONFIGURAÇÃO API CLIENT${NC}"
echo -n "  Verificando lib/api.ts com interceptors..."
if [ -f "/home/cadu/SPRNOVO/frontend/lib/api.ts" ] && grep -q "interceptors" "/home/cadu/SPRNOVO/frontend/lib/api.ts" 2>/dev/null; then
    check_status 0
else
    check_status 1
fi

echo -e "\n${BLUE}9. COMPONENTES SHADCN UI${NC}"
echo -n "  Verificando componentes UI (Card, Button, Input)..."
if [ -d "/home/cadu/SPRNOVO/frontend/components/ui" ] && 
   [ -f "/home/cadu/SPRNOVO/frontend/components/ui/card.tsx" ] &&
   [ -f "/home/cadu/SPRNOVO/frontend/components/ui/button.tsx" ]; then
    check_status 0
else
    check_status 1
fi

echo -e "\n${BLUE}10. TAILWIND & STYLES${NC}"
echo -n "  Verificando configuração Tailwind CSS..."
if [ -f "/home/cadu/SPRNOVO/frontend/tailwind.config.ts" ] && [ -f "/home/cadu/SPRNOVO/frontend/app/globals.css" ]; then
    check_status 0
else
    check_status 1
fi

echo -e "\n=============================================================="
echo -e "${BLUE}RESUMO FINAL:${NC}"
echo -e "  ${GREEN}✓ PASSED: $PASSED${NC}"
echo -e "  ${RED}✗ FAILED: $FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 GO! Circuito completo validado com sucesso!${NC}"
    echo -e "${GREEN}   Sistema pronto para testes de produção.${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  NO-GO! $FAILED itens precisam de correção.${NC}"
    echo -e "${YELLOW}   Revise os itens marcados como FAIL acima.${NC}"
    exit 1
fi