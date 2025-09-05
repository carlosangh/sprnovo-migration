#!/bin/bash

# SPR FRONTEND - SCRIPT DE LIMPEZA DE MOCKS
# Remove completamente todos os resquícios de licença mock

FRONTEND_DIR="/opt/spr/frontend/src"
BACKUP_DIR="/opt/spr/frontend-backup-$(date +%Y%m%d-%H%M%S)"

echo "🧹 SPR Frontend - Limpeza de Mocks de Licença"
echo "=============================================="

# 1. BACKUP DE SEGURANÇA
echo "📦 Criando backup de segurança..."
mkdir -p "$BACKUP_DIR"
cp -r "$FRONTEND_DIR" "$BACKUP_DIR/"
echo "✅ Backup criado em: $BACKUP_DIR"

# 2. BUSCAR REFERÊNCIAS MOCK
echo ""
echo "🔍 Buscando referências mock..."

echo "📋 Arquivos com 'Mock Client':"
find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs grep -l "Mock Client" 2>/dev/null || echo "Nenhum encontrado"

echo ""
echo "📋 Arquivos com 'default-session':"
find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs grep -l "default-session" 2>/dev/null || echo "Nenhum encontrado"

echo ""
echo "📋 Arquivos com shouldBypassLicensing = true:"
find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs grep -l "shouldBypassLicensing.*true" 2>/dev/null || echo "Nenhum encontrado"

echo ""
echo "📋 Arquivos com useLicenseStore:"
find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs grep -l "useLicenseStore" 2>/dev/null || echo "Nenhum encontrado"

echo ""
echo "📋 Arquivos com mockLicense:"
find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs grep -l "mockLicense" 2>/dev/null || echo "Nenhum encontrado"

# 3. VERIFICAR SE STORE EXISTE
STORE_FILE="$FRONTEND_DIR/store/useLicenseStore.ts"
if [ -f "$STORE_FILE" ]; then
    echo ""
    echo "⚠️  ENCONTRADO: $STORE_FILE"
    echo "   Este arquivo deve ser removido!"
else
    echo ""
    echo "✅ Store de licença mock não encontrado"
fi

# 4. BUSCAR localStorage/sessionStorage DE LICENÇA
echo ""
echo "📋 Arquivos com localStorage de licença:"
find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs grep -l "localStorage.*licen" 2>/dev/null || echo "Nenhum encontrado"

echo ""
echo "📋 Arquivos com 'spr-license-store':"
find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs grep -l "spr-license-store" 2>/dev/null || echo "Nenhum encontrado"

# 5. VERIFICAR CONFIGURAÇÃO
CONFIG_FILE="$FRONTEND_DIR/config/index.ts"
if [ -f "$CONFIG_FILE" ]; then
    echo ""
    echo "🔧 Verificando configuração:"
    
    if grep -q "shouldBypassLicensing.*true" "$CONFIG_FILE"; then
        echo "❌ PROBLEMA: shouldBypassLicensing está true em $CONFIG_FILE"
    else
        echo "✅ shouldBypassLicensing parece correto"
    fi
    
    if grep -q "bypassLicensing.*true" "$CONFIG_FILE"; then
        echo "❌ PROBLEMA: bypassLicensing está true em $CONFIG_FILE"
    else
        echo "✅ bypassLicensing parece correto"
    fi
else
    echo "⚠️  Arquivo de configuração não encontrado: $CONFIG_FILE"
fi

# 6. SCRIPT DE LIMPEZA AUTOMÁTICA
echo ""
echo "🔧 Executar limpeza automática? (y/n)"
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    echo "🧹 Executando limpeza automática..."
    
    # Remover store de licença se existir
    if [ -f "$STORE_FILE" ]; then
        echo "🗑️  Removendo $STORE_FILE"
        rm -f "$STORE_FILE"
    fi
    
    # Substituir referências em arquivos
    echo "🔄 Substituindo referências mock..."
    
    # Substituir Mock Client por nome real (se necessário)
    find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs sed -i 's/Mock Client/Cliente/g' 2>/dev/null || true
    
    # Substituir default-session por session real (se necessário)
    find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs sed -i 's/default-session/session/g' 2>/dev/null || true
    
    # Corrigir shouldBypassLicensing para false
    find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs sed -i 's/shouldBypassLicensing.*=.*true/shouldBypassLicensing = false/g' 2>/dev/null || true
    
    echo "✅ Limpeza automática concluída"
else
    echo "⏭️  Limpeza automática ignorada"
fi

# 7. VERIFICAÇÃO FINAL
echo ""
echo "🔎 Verificação final..."

MOCK_REFS=$(find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs grep -l "Mock Client\|default-session\|mockLicense" 2>/dev/null | wc -l)
STORE_REFS=$(find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs grep -l "useLicenseStore" 2>/dev/null | wc -l)
BYPASS_REFS=$(find "$FRONTEND_DIR" -name "*.ts" -o -name "*.tsx" | xargs grep -l "shouldBypassLicensing.*true" 2>/dev/null | wc -l)

echo "📊 Resumo:"
echo "   - Referências mock: $MOCK_REFS"
echo "   - Referências store: $STORE_REFS" 
echo "   - Bypass true: $BYPASS_REFS"

if [ "$MOCK_REFS" -eq 0 ] && [ "$STORE_REFS" -eq 0 ] && [ "$BYPASS_REFS" -eq 0 ]; then
    echo ""
    echo "🎉 SUCESSO: Nenhuma referência mock encontrada!"
    echo "✅ Frontend limpo e pronto para fonte única real"
else
    echo ""
    echo "⚠️  ATENÇÃO: Ainda existem referências mock"
    echo "   Por favor, revise manualmente os arquivos listados acima"
fi

# 8. PRÓXIMOS PASSOS
echo ""
echo "📋 PRÓXIMOS PASSOS:"
echo "1. Copiar novos arquivos gerados:"
echo "   cp /home/cadu/spr-project/useLicense.ts $FRONTEND_DIR/hooks/"
echo "   cp /home/cadu/spr-project/LicenseStatus.tsx $FRONTEND_DIR/components/License/"
echo "   cp /home/cadu/spr-project/LicenseActivation.tsx $FRONTEND_DIR/components/License/"
echo "   cp /home/cadu/spr-project/FeatureGuard.tsx $FRONTEND_DIR/components/License/"
echo ""
echo "2. Atualizar configuração:"
echo "   cp $FRONTEND_DIR/config/index.ts $FRONTEND_DIR/config/index.ts.backup"
echo "   cp /home/cadu/spr-project/config-updated.ts $FRONTEND_DIR/config/index.ts"
echo ""
echo "3. Atualizar App.tsx:"
echo "   cp $FRONTEND_DIR/App.tsx $FRONTEND_DIR/App.tsx.backup"
echo "   cp /home/cadu/spr-project/App-updated.tsx $FRONTEND_DIR/App.tsx"
echo ""
echo "4. Instalar dependências (se necessário):"
echo "   cd /opt/spr/frontend && npm install react-query react-hot-toast"
echo ""
echo "5. Testar aplicação:"
echo "   npm start"

echo ""
echo "💾 Backup disponível em: $BACKUP_DIR"
echo "📖 Documentação completa em: /home/cadu/spr-project/CHANGES-SUMMARY.md"
echo ""
echo "🎯 CRÍTICO: Garantir que backend está rodando em localhost:3002"
echo "   com endpoints /api/license/status e /api/license/activate"