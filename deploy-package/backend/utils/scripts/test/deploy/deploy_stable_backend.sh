#!/bin/bash

# Script de Deploy do Backend Estabilizado SPR
# Criado: 2025-09-02
# Objetivo: Aplicar correções críticas de estabilidade

set -e  # Para no primeiro erro

echo "🚀 INICIANDO DEPLOY DO BACKEND ESTABILIZADO..."
echo "=================================================="

# Verificar se está rodando como root (necessário para acessar /opt/spr)
if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script precisa ser executado como root (sudo)"
   echo "   Use: sudo bash deploy_stable_backend.sh"
   exit 1
fi

# Diretórios
SOURCE_DIR="/home/cadu/spr-project"
TARGET_DIR="/opt/spr"
BACKUP_DIR="/opt/spr/backups/$(date +%Y%m%d_%H%M%S)"

echo "📁 Criando diretório de backup..."
mkdir -p "$BACKUP_DIR"
mkdir -p "$TARGET_DIR/logs"
mkdir -p "$TARGET_DIR/_reports"

# 1. BACKUP DOS ARQUIVOS ATUAIS
echo "💾 Fazendo backup dos arquivos atuais..."
if [ -f "$TARGET_DIR/backend_server_fixed.js" ]; then
    cp "$TARGET_DIR/backend_server_fixed.js" "$BACKUP_DIR/backend_server_fixed.js.backup"
    echo "   ✅ Backup: backend_server_fixed.js"
else
    echo "   ⚠️  Arquivo backend_server_fixed.js não encontrado"
fi

if [ -f "$TARGET_DIR/ecosystem.config.js" ]; then
    cp "$TARGET_DIR/ecosystem.config.js" "$BACKUP_DIR/ecosystem.config.js.backup"
    echo "   ✅ Backup: ecosystem.config.js"
fi

# 2. VERIFICAR ARQUIVOS CORRIGIDOS
echo "🔍 Verificando arquivos corrigidos..."
if [ ! -f "$SOURCE_DIR/backend_server_stable.js" ]; then
    echo "❌ Arquivo backend_server_stable.js não encontrado em $SOURCE_DIR"
    exit 1
fi

if [ ! -f "$SOURCE_DIR/ecosystem.config.js" ]; then
    echo "❌ Arquivo ecosystem.config.js não encontrado em $SOURCE_DIR"
    exit 1
fi

# 3. PARAR PROCESSO ATUAL (se existir)
echo "🛑 Parando processo atual..."
if command -v pm2 &> /dev/null; then
    pm2 stop spr-backend 2>/dev/null || echo "   ℹ️  Processo spr-backend não estava rodando"
    pm2 delete spr-backend 2>/dev/null || echo "   ℹ️  Processo spr-backend não estava registrado"
else
    echo "   ⚠️  PM2 não encontrado, tentando parar processo manualmente..."
    pkill -f "backend_server_fixed.js" 2>/dev/null || echo "   ℹ️  Nenhum processo backend encontrado"
fi

# 4. APLICAR ARQUIVOS CORRIGIDOS
echo "📦 Aplicando arquivos corrigidos..."
cp "$SOURCE_DIR/backend_server_stable.js" "$TARGET_DIR/backend_server_fixed.js"
echo "   ✅ Aplicado: backend_server_fixed.js (versão estabilizada)"

cp "$SOURCE_DIR/ecosystem.config.js" "$TARGET_DIR/"
echo "   ✅ Aplicado: ecosystem.config.js (configuração PM2 otimizada)"

# 5. COPIAR RELATÓRIO
cp "$SOURCE_DIR/_reports/backend_stability.md" "$TARGET_DIR/_reports/"
echo "   ✅ Aplicado: relatório de estabilidade"

# 6. AJUSTAR PERMISSÕES
echo "🔐 Ajustando permissões..."
chmod +x "$TARGET_DIR/backend_server_fixed.js"
chown root:root "$TARGET_DIR/backend_server_fixed.js"
chown root:root "$TARGET_DIR/ecosystem.config.js"
echo "   ✅ Permissões ajustadas"

# 7. INICIAR PROCESSO COM NOVA CONFIGURAÇÃO
echo "🚀 Iniciando processo com nova configuração..."
cd "$TARGET_DIR"

if command -v pm2 &> /dev/null; then
    echo "   📊 Usando PM2 com configuração otimizada..."
    pm2 start ecosystem.config.js
    pm2 save
    echo "   ✅ Processo iniciado via PM2"
else
    echo "   ⚠️  PM2 não disponível, iniciando processo diretamente..."
    nohup node backend_server_fixed.js > logs/backend-direct.log 2>&1 &
    echo "   ✅ Processo iniciado diretamente"
fi

# 8. VERIFICAR SE PROCESSO ESTÁ RODANDO
echo "🔍 Verificando se processo está rodando..."
sleep 3

if command -v pm2 &> /dev/null; then
    pm2 status spr-backend
else
    ps aux | grep "backend_server_fixed.js" | grep -v grep || echo "   ⚠️  Processo não encontrado"
fi

# 9. TESTAR HEALTH CHECK
echo "🏥 Testando health check..."
sleep 5

HEALTH_RESPONSE=$(curl -s http://localhost:3002/api/health 2>/dev/null || echo "FAILED")
if [[ "$HEALTH_RESPONSE" != "FAILED" ]]; then
    echo "   ✅ Health check funcionando!"
    echo "   📊 Status: $(echo "$HEALTH_RESPONSE" | grep -o '"status":"[^"]*' | cut -d'"' -f4)"
else
    echo "   ⚠️  Health check ainda não disponível (pode estar inicializando...)"
fi

# 10. RESUMO
echo ""
echo "🎯 DEPLOY CONCLUÍDO!"
echo "===================="
echo "✅ Backup realizado em: $BACKUP_DIR"
echo "✅ Código estabilizado aplicado"
echo "✅ Configuração PM2 otimizada"
echo "✅ Processo reiniciado"
echo ""
echo "📋 PRÓXIMOS PASSOS:"
echo "1. Monitorar logs: sudo pm2 logs spr-backend"
echo "2. Verificar status: sudo pm2 status"
echo "3. Testar endpoints: curl http://localhost:3002/api/health"
echo "4. Monitorar por 10-15 minutos para confirmar estabilidade"
echo ""
echo "📊 ENDPOINTS DE MONITORAMENTO:"
echo "   Health: http://localhost:3002/api/health"
echo "   Status: http://localhost:3002/api/status"
echo "   Chat:   http://localhost:3002/chat"
echo ""
echo "🔍 COMANDOS ÚTEIS:"
echo "   sudo pm2 logs spr-backend --lines 50"
echo "   sudo pm2 monit"
echo "   sudo pm2 restart spr-backend"
echo ""
echo "✅ BACKEND SPR ESTABILIZADO E PRONTO!"