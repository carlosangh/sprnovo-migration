#!/bin/bash

echo "🔍 Deploy do config.js com sistema de debug"
echo "============================================="

# Configurações
LOCAL_CONFIG="/home/cadu/spr-project/frontend/build/config.js"
BACKUP_CONFIG="/home/cadu/spr-project/frontend/build/config.js.backup"

echo "📁 Arquivo local: $LOCAL_CONFIG"
echo "🕒 Timestamp: $(date)"

# Faz backup do config original se não existir
if [ ! -f "$BACKUP_CONFIG" ]; then
    echo "💾 Criando backup do config original..."
    cp "$LOCAL_CONFIG" "$BACKUP_CONFIG"
    echo "✅ Backup criado em: $BACKUP_CONFIG"
fi

echo ""
echo "📋 Conteúdo atual do config.js (primeiras 10 linhas):"
head -n 10 "$LOCAL_CONFIG"

echo ""
echo "🔍 Verificando se o sistema de debug está presente..."
if grep -q "SPR-DEBUG" "$LOCAL_CONFIG"; then
    echo "✅ Sistema de debug encontrado no arquivo"
else
    echo "❌ Sistema de debug NÃO encontrado no arquivo"
fi

echo ""
echo "📊 Estatísticas do arquivo:"
echo "   Tamanho: $(wc -c < "$LOCAL_CONFIG") bytes"
echo "   Linhas: $(wc -l < "$LOCAL_CONFIG") linhas"
echo "   Debug logs: $(grep -c "debugLog" "$LOCAL_CONFIG") ocorrências"

echo ""
echo "🌐 PRÓXIMOS PASSOS PARA TESTAR:"
echo "1. Acesse: https://www.royalnegociosagricolas.com.br"
echo "2. Abra as DevTools (F12)"
echo "3. Vá para a aba Console"
echo "4. Procure por logs que começam com '[SPR-DEBUG]'"
echo "5. Observe se aparece um painel de debug verde no canto superior direito"
echo "6. Verifique se há erros JavaScript sendo capturados"

echo ""
echo "🔧 Se o arquivo não foi atualizado no servidor, você pode:"
echo "   - Copiar manualmente o conteúdo do arquivo"
echo "   - Usar FTP/SFTP para fazer upload"
echo "   - Usar o painel de controle da hospedagem"

echo ""
echo "📝 Para reverter as mudanças:"
echo "   cp $BACKUP_CONFIG $LOCAL_CONFIG"

echo ""
echo "✅ Script de debug deploy concluído!"