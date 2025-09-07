#!/bin/bash

echo "🚀 Deploy do Status Test - Royal Negócios Agrícolas"
echo "=================================================="

# Configurações
SERVER_IP="138.197.83.3"
SERVER_USER="root"
REMOTE_PATH="/var/www/spr-project"
LOCAL_BACKEND="backend_server_fixed.js"
LOCAL_HTML="status-test.html"

echo "📤 Enviando arquivos para o servidor..."

# Fazer backup do backend atual
echo "💾 Fazendo backup do backend atual..."
ssh $SERVER_USER@$SERVER_IP "cd $REMOTE_PATH && cp backend_server_fixed.js backend_server_fixed.js.backup.$(date +%Y%m%d_%H%M%S)"

# Enviar backend modificado
echo "📡 Enviando backend modificado..."
scp $LOCAL_BACKEND $SERVER_USER@$SERVER_IP:$REMOTE_PATH/

# Enviar página de status
echo "🌐 Enviando página de status..."
scp $LOCAL_HTML $SERVER_USER@$SERVER_IP:$REMOTE_PATH/

# Reiniciar o serviço
echo "🔄 Reiniciando serviço no servidor..."
ssh $SERVER_USER@$SERVER_IP "cd $REMOTE_PATH && pm2 restart backend_server_fixed || pm2 start backend_server_fixed.js --name spr-backend"

# Verificar status
echo "🔍 Verificando status do serviço..."
ssh $SERVER_USER@$SERVER_IP "pm2 status"

echo ""
echo "✅ Deploy concluído!"
echo "🌐 Teste o sistema em: https://www.royalnegociosagricolas.com.br"
echo "📊 Página de status: https://www.royalnegociosagricolas.com.br/status-test"
echo ""
echo "📋 APIs disponíveis:"
echo "   - /health"
echo "   - /api/whatsapp/status" 
echo "   - /api/system-info"
echo "   - /status-test"
echo ""
echo "🔧 Para verificar logs: ssh $SERVER_USER@$SERVER_IP 'pm2 logs spr-backend'"