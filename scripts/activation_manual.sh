#!/bin/bash

# SPR - Manual Activation Guide
# Plano de Ativação Completo (15 min)

echo "🚀 SPR - PLANO DE ATIVAÇÃO MANUAL"
echo "================================="

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${BLUE}1. SEGREDOS DE PRODUÇÃO GERADOS ✅${NC}"
echo "   • EVO_APIKEY: c451bb1deb223c150b4c41ed3925bfaa91cdacf45d3d01350b2a16520c97b21c"
echo "   • EVO_WEBHOOK_TOKEN: f542b07048e0b7401bf1de47e84b2822f27391aa414cc72c"
echo "   • Arquivos criados: /secrets/evolution.env, /backend/.env"

echo -e "\n${BLUE}2. DOCKER EVOLUTION API${NC}"
echo -e "${YELLOW}   ⚠️ Requer sudo - Execute manualmente:${NC}"
echo "   sudo service docker start"
echo "   docker-compose up -d mongodb redis"
echo "   sleep 10"
echo "   docker-compose up -d evolution-api"
echo "   docker-compose ps"

echo -e "\n${BLUE}3. DNS & TLS (Requer Admin)${NC}"
echo -e "${YELLOW}   ⚠️ Configure nos servidores:${NC}"
echo "   • Confirmar A/AAAA: royalnegociosagricolas.com.br"
echo "   • Confirmar A/AAAA: evo.royalnegociosagricolas.com.br"
echo "   • sudo certbot --nginx -d evo.royalnegociosagricolas.com.br"
echo "   • sudo nginx -t && sudo systemctl reload nginx"

echo -e "\n${BLUE}4. BACKEND COM NOVOS .ENV${NC}"
echo -e "${GREEN}   Executável agora:${NC}"
echo "   pkill -f backend_auth.py"
echo "   source venv/bin/activate"
echo "   python modules/auth/backend_auth.py &"

echo -e "\n${BLUE}5. PROVA REAL (quando Evolution API estiver up)${NC}"
echo "   export EVO_APIKEY=c451bb1deb223c150b4c41ed3925bfaa91cdacf45d3d01350b2a16520c97b21c"
echo "   ./scripts/evo_test.sh create"
echo "   ./scripts/evo_test.sh connect"
echo "   ./scripts/evo_test.sh send \"+5566999999999\" \"Teste SPRNOVO\""

echo -e "\n${BLUE}6. FRONTEND${NC}"
echo "   cd frontend"
echo "   npm install"
echo "   npm run dev"

echo -e "\n${BLUE}7. WEBHOOK TESTE${NC}"
echo "   curl -X POST \"https://royalnegociosagricolas.com.br/api/webhook/evolution?token=f542b07048e0b7401bf1de47e84b2822f27391aa414cc72c\" \\"
echo "        -H \"Content-Type: application/json\" \\"
echo "        -d '{\"event\":\"QRCODE_UPDATED\",\"instance\":\"ROY_01\",\"qrcode\":\"test\"}'"

echo -e "\n${BLUE}8. CRITÉRIOS DE ACEITE${NC}"
echo "   • QR exibido em /whatsapp ✓"
echo "   • Mensagem enviada com sucesso ✓"
echo "   • /commodities carregando gráficos ✓"
echo "   • /settings mostrando configurações ✓"
echo "   • mini_smoke.sh retornando OK ✓"

echo -e "\n${GREEN}🔧 COMANDOS DE MONITORAMENTO:${NC}"
echo "   ./scripts/mini_smoke.sh"
echo "   ./scripts/go_no_go_checklist.sh"
echo "   docker logs -f evolution_api"
echo "   tail -f /var/log/nginx/access.log"

echo -e "\n${GREEN}🚀 SISTEMA PREPARADO PARA ATIVAÇÃO!${NC}"