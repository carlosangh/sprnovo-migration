#!/bin/bash

echo "🚀 Deploy WhatsApp QR Code - Royal Negócios Agrícolas"
echo "==================================================="

# Configurações
SERVER_IP="138.197.83.3"
DROPLET_ID="505486676"
LOCAL_PATH="/home/cadu/spr-project"
REMOTE_PATH="/opt/spr"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para executar comandos no servidor
remote_exec() {
    echo -e "${BLUE}[SERVIDOR]${NC} $1"
    /home/cadu/doctl compute ssh $DROPLET_ID --ssh-command "$1"
}

echo -e "${YELLOW}📦 Preparando arquivos para deploy...${NC}"

# Build do projeto
echo -e "${YELLOW}🔨 Fazendo build do projeto...${NC}"
npm run build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro no build do projeto!${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 Criando pacote de deploy...${NC}"

# Criar arquivo tar com os arquivos necessários
tar czf /tmp/whatsapp-deploy.tar.gz \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='wppconnect/node_modules' \
    --exclude='wppconnect/userDataDir' \
    --exclude='logs' \
    --exclude='_logs' \
    -C "$LOCAL_PATH" \
    whatsapp-qr.html \
    src/routes/whatsapp.ts \
    src/server.ts \
    wppconnect/src/config.ts \
    wppconnect/package.json \
    package.json \
    tsconfig.json \
    dist/ \
    wppconnect/dist/ 2>/dev/null

echo -e "${YELLOW}🚀 Enviando para servidor...${NC}"

# Enviar arquivo para servidor
cat /tmp/whatsapp-deploy.tar.gz | remote_exec "
    echo '📂 Criando backup da versão atual...'
    cd $REMOTE_PATH && \
    mkdir -p backups && \
    tar czf backups/backup-\$(date +%Y%m%d-%H%M%S).tar.gz --exclude='backups' --exclude='node_modules' . 2>/dev/null || echo 'Backup falhou, mas continuando...' && \
    
    echo '📦 Extraindo novos arquivos...' && \
    cat > /tmp/whatsapp-deploy.tar.gz && \
    tar xzf /tmp/whatsapp-deploy.tar.gz && \
    rm /tmp/whatsapp-deploy.tar.gz && \
    
    echo '📦 Instalando dependências se necessário...' && \
    npm ci --production --silent 2>/dev/null || npm install --production --silent && \
    
    echo '🔄 Reiniciando serviços...' && \
    sudo systemctl restart spr-backend || pm2 restart spr-backend || echo 'Serviço backend não reiniciado automaticamente' && \
    sudo systemctl restart spr-whatsapp || pm2 restart spr-whatsapp || echo 'Serviço WhatsApp não reiniciado automaticamente' && \
    
    echo '✅ Deploy WhatsApp concluído!'
"

# Limpar arquivo temporário
rm -f /tmp/whatsapp-deploy.tar.gz

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Deploy WhatsApp realizado com sucesso!${NC}"
    echo -e "${GREEN}🌐 Acesse: https://www.royalnegociosagricolas.com.br/whatsapp-qr${NC}"
    echo ""
    echo -e "${BLUE}📋 Próximos passos:${NC}"
    echo "1. Acesse o link acima no navegador"
    echo "2. Clique em 'Gerar QR Code WhatsApp'"  
    echo "3. Escaneie o código com seu WhatsApp"
    echo "4. Monitore o status da conexão"
    echo ""
    echo -e "${YELLOW}🔧 Para monitorar logs:${NC}"
    echo "doctl compute ssh $DROPLET_ID --ssh-command 'tail -f /opt/spr/logs/*.log'"
else
    echo -e "${RED}❌ Erro durante o deploy!${NC}"
    exit 1
fi