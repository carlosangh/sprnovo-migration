#!/bin/bash

# Script de Deploy do COMPAT Router
# Autor: SPR Backend Agent
# Data: 2025-09-02

echo "🚀 Iniciando deploy do COMPAT Router..."

# Verificar se o arquivo modificado existe
if [ ! -f "/home/cadu/spr-project/backend_server_compat.js" ]; then
    echo "❌ Arquivo backend_server_compat.js não encontrado!"
    exit 1
fi

# Fazer backup do arquivo original
echo "📦 Fazendo backup do backend original..."
sudo cp /opt/spr/backend_server_fixed.js /opt/spr/backend_server_fixed.js.backup.$(date +%Y%m%d_%H%M%S)

# Copiar arquivo modificado
echo "📁 Copiando backend modificado..."
sudo cp /home/cadu/spr-project/backend_server_compat.js /opt/spr/backend_server_fixed.js

# Verificar sintaxe
echo "🔍 Verificando sintaxe do Node.js..."
cd /opt/spr
if sudo node -c backend_server_fixed.js; then
    echo "✅ Sintaxe Node.js válida"
else
    echo "❌ Erro de sintaxe! Restaurando backup..."
    sudo cp /opt/spr/backend_server_fixed.js.backup.* /opt/spr/backend_server_fixed.js
    exit 1
fi

# Verificar se PM2 está instalado
if ! command -v pm2 &> /dev/null; then
    echo "⚠️  PM2 não encontrado. Instale com: sudo npm install -g pm2"
    echo "📋 Para testar manualmente: cd /opt/spr && node backend_server_fixed.js"
    exit 1
fi

# Reiniciar PM2
echo "🔄 Reiniciando PM2..."
if sudo pm2 restart spr-backend 2>/dev/null; then
    echo "✅ PM2 reiniciado com sucesso"
else
    echo "⚠️  spr-backend não encontrado no PM2. Iniciando..."
    sudo pm2 start /opt/spr/backend_server_fixed.js --name spr-backend
fi

# Aguardar inicialização
echo "⏳ Aguardando inicialização (10s)..."
sleep 10

# Testar endpoints
echo "🧪 Testando endpoints COMPAT..."

echo "📊 Testando /api/proof/real-data..."
if curl -s -f http://localhost:3002/api/proof/real-data > /dev/null; then
    echo "✅ /api/proof/real-data funcionando"
else
    echo "❌ /api/proof/real-data falhou"
fi

echo "❤️  Testando /api/compat/status..."
if curl -s -f http://localhost:3002/api/compat/status > /dev/null; then
    echo "✅ /api/compat/status funcionando"
else
    echo "❌ /api/compat/status falhou"
fi

echo "🛒 Testando /api/offer-management..."
if curl -s -f "http://localhost:3002/api/offer-management?commodity=SOJA" > /dev/null; then
    echo "✅ /api/offer-management funcionando"
else
    echo "❌ /api/offer-management falhou"
fi

echo ""
echo "🎉 Deploy do COMPAT Router concluído!"
echo "📋 Endpoints disponíveis:"
echo "   📊 GET /api/proof/real-data"
echo "   ❤️  GET /api/compat/status"
echo "   📈 GET /api/compat/metrics"
echo "   📱 GET /api/whatsapp/qr-code"
echo "   📋 GET /api/commodities/dashboard/summary"
echo "   🛒 GET /api/offer-management"
echo ""
echo "📝 Relatório completo: /home/cadu/spr-project/_reports/compat_added.md"