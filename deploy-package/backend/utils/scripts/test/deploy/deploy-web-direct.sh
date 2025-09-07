#!/bin/bash

echo "🌐 Deploy Direto via Web - Royal Negócios Agrícolas"
echo "=================================================="

# Configurações
SITE_URL="https://www.royalnegociosagricolas.com.br"
LOCAL_PATH="/home/cadu/spr-project"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔍 Testando conectividade com o site...${NC}"

# Testar conectividade básica
curl -s --head "$SITE_URL" | head -1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Site acessível!${NC}"
else
    echo -e "${RED}❌ Site não acessível!${NC}"
    exit 1
fi

echo -e "${YELLOW}🔍 Verificando se existe alguma página de teste...${NC}"

# Testar se existe uma página de upload ou API
curl -s "$SITE_URL/test" | head -5
curl -s "$SITE_URL/api/health" | head -5 2>/dev/null || echo "API health não encontrada"

echo -e "${YELLOW}📋 Análise do site atual:${NC}"

# Verificar estrutura atual do site
curl -s "$SITE_URL" | grep -E "(title|h1|h2)" | head -5

echo -e "${BLUE}📋 Próximos passos recomendados:${NC}"
echo "1. Contactar administrador do servidor para:"
echo "   - Verificar configuração do nginx/apache"
echo "   - Confirmar diretório web root"
echo "   - Verificar permissões de arquivos"
echo ""
echo "2. Alternativas para deploy:"
echo "   - FTP/SFTP para upload direto"
echo "   - Git deploy hooks"
echo "   - Panel de controle do servidor"
echo ""
echo "3. Para teste local:"
echo "   - Abrir arquivo HTML local no navegador"
echo "   - Usar servidor HTTP local para testar"

echo -e "${YELLOW}🧪 Teste local disponível:${NC}"
echo "1. cd $LOCAL_PATH"
echo "2. python3 -m http.server 8080"  
echo "3. Abrir: http://localhost:8080/whatsapp-qr.html"