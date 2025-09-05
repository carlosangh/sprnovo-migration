#!/bin/bash

echo "🚀 Iniciando deploy das correções SPR..."

# 1. Fazer backup do backend atual no servidor
echo "📦 Criando backup do backend atual..."
/home/cadu/doctl compute ssh 511012728 --ssh-command "cd /opt/spr && cp backend_server_fixed.js backend_server_fixed.js.backup_$(date +%Y%m%d_%H%M%S)"

# 2. Criar arquivo temporário com o backend corrigido
echo "📋 Preparando backend corrigido..."
cp /home/cadu/spr-project/backend_server_fixed.js /tmp/backend_corrected.js

# 3. Transferir via echo para não ter problemas de SSH key
echo "📤 Enviando backend corrigido..."
/home/cadu/doctl compute ssh 511012728 --ssh-command "cat > /opt/spr/backend_server_fixed.js.new" < /tmp/backend_corrected.js

# 4. Substituir arquivo no servidor
echo "🔄 Atualizando backend no servidor..."
/home/cadu/doctl compute ssh 511012728 --ssh-command "cd /opt/spr && mv backend_server_fixed.js.new backend_server_fixed.js"

# 5. Atualizar config.js do frontend se necessário
if [ -f "/home/cadu/spr-project/frontend/build/config.js" ]; then
    echo "📤 Enviando config.js do frontend..."
    /home/cadu/doctl compute ssh 511012728 --ssh-command "cat > /opt/spr/frontend/build/config.js" < /home/cadu/spr-project/frontend/build/config.js
fi

# 6. Reiniciar backend via PM2
echo "🔄 Reiniciando backend via PM2..."
/home/cadu/doctl compute ssh 511012728 --ssh-command "pm2 start spr-backend"

# 7. Verificar status
echo "✅ Verificando status dos serviços..."
/home/cadu/doctl compute ssh 511012728 --ssh-command "pm2 list && echo '=== Health Check ===' && curl -s http://localhost:3002/health | head -5"

echo "🎉 Deploy concluído!"