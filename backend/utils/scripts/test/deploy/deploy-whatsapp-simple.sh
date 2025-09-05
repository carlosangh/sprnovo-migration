#!/bin/bash

echo "🚀 Deploy Simplificado WhatsApp QR Code - Royal Negócios Agrícolas"
echo "================================================================="

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

echo -e "${YELLOW}📦 Preparando arquivos básicos para deploy...${NC}"

# Criar arquivo tar apenas com arquivos essenciais
tar czf /tmp/whatsapp-simple.tar.gz \
    -C "$LOCAL_PATH" \
    whatsapp-qr.html \
    wppconnect/ \
    2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro ao criar pacote!${NC}"
    exit 1
fi

echo -e "${YELLOW}🚀 Enviando para servidor...${NC}"

# Enviar arquivo para servidor
cat /tmp/whatsapp-simple.tar.gz | remote_exec "
    echo '📂 Criando backup da versão atual...' && \
    cd $REMOTE_PATH && \
    mkdir -p backups && \
    tar czf backups/whatsapp-backup-\$(date +%Y%m%d-%H%M%S).tar.gz whatsapp-qr.html wppconnect/ 2>/dev/null || echo 'Sem arquivos anteriores para backup' && \
    
    echo '📦 Extraindo novos arquivos...' && \
    cat > /tmp/whatsapp-simple.tar.gz && \
    tar xzf /tmp/whatsapp-simple.tar.gz && \
    rm /tmp/whatsapp-simple.tar.gz && \
    
    echo '📦 Preparando WPPConnect...' && \
    cd wppconnect && \
    npm install --production --silent 2>/dev/null || echo 'Instalação de dependências falhou' && \
    npm run build 2>/dev/null || echo 'Build WPPConnect falhou' && \
    
    echo '🔄 Iniciando serviço WPPConnect...' && \
    cd $REMOTE_PATH && \
    pkill -f 'wppconnect' || echo 'Nenhum processo WPPConnect ativo' && \
    cd wppconnect && \
    nohup npm start > ../logs/wppconnect.log 2>&1 & && \
    sleep 3 && \
    
    echo '✅ Deploy WhatsApp simplificado concluído!'
"

# Limpar arquivo temporário
rm -f /tmp/whatsapp-simple.tar.gz

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Deploy WhatsApp realizado com sucesso!${NC}"
    echo ""
    echo -e "${GREEN}📋 Arquivos implantados:${NC}"
    echo "• whatsapp-qr.html - Interface para gerar QR Code"
    echo "• wppconnect/ - Servidor WhatsApp completo"
    echo ""
    echo -e "${BLUE}🌐 Para acessar:${NC}"
    echo "1. Acesse: https://www.royalnegociosagricolas.com.br/whatsapp-qr.html"
    echo "2. OU configure proxy reverso no nginx para rota /whatsapp"
    echo ""
    echo -e "${YELLOW}🔧 Para verificar logs:${NC}"
    echo "doctl compute ssh $DROPLET_ID --ssh-command 'tail -f /opt/spr/logs/wppconnect.log'"
    echo ""
    echo -e "${YELLOW}🔧 Para verificar se WPPConnect está rodando:${NC}"
    echo "doctl compute ssh $DROPLET_ID --ssh-command 'curl -s http://localhost:3003/ || echo \"WPPConnect não está respondendo\"'"
else
    echo -e "${RED}❌ Erro durante o deploy!${NC}"
    exit 1
fi