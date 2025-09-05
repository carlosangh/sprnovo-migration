#!/bin/bash

echo "🚀 DEPLOY - SISTEMA DE DIAGNÓSTICO REACT"
echo "========================================"
echo ""

# Verificar se estamos no diretório correto
if [[ ! -f "backend_server_fixed.js" ]]; then
    echo "❌ Execute este script no diretório do projeto"
    exit 1
fi

echo "📋 Preparando arquivos para deploy..."

# Criar lista de arquivos necessários para o diagnóstico
REQUIRED_FILES=(
    "backend_server_fixed.js"
    "react-diagnosis.html"
    "new_endpoints.js"
    "basis_endpoints.js"
    "package.json"
)

echo "✅ Verificando arquivos necessários:"
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "   ✅ $file"
    else
        echo "   ❌ $file (FALTANDO)"
        exit 1
    fi
done

echo ""
echo "📤 COMANDOS PARA DEPLOY NO SERVIDOR:"
echo ""
echo "1. 📁 Copiar arquivos atualizados:"
echo "   scp backend_server_fixed.js root@SEU_SERVIDOR:/root/spr-project/"
echo "   scp react-diagnosis.html root@SEU_SERVIDOR:/root/spr-project/"
echo ""
echo "2. 🔄 Reiniciar servidor no Digital Ocean:"
echo "   ssh root@SEU_SERVIDOR"
echo "   cd /root/spr-project"
echo "   pm2 restart backend_server_fixed.js"
echo ""
echo "3. ✅ Verificar se funcionou:"
echo "   curl https://www.royalnegociosagricolas.com.br/health"
echo "   curl https://www.royalnegociosagricolas.com.br/react-diagnosis"
echo ""
echo "4. 🔍 Testar diagnóstico:"
echo "   https://www.royalnegociosagricolas.com.br/react-diagnosis"
echo ""

# Se houver um script de deploy existente, sugerir integração
if [[ -f "deploy.sh" ]]; then
    echo "💡 INTEGRAÇÃO COM SCRIPT EXISTENTE:"
    echo "   Você pode adicionar estes comandos ao seu deploy.sh:"
    echo ""
    echo "   # Copiar página de diagnóstico"
    echo "   scp react-diagnosis.html root@\$SERVIDOR:/root/spr-project/"
    echo ""
fi

echo "🎯 ENDPOINT FINAL:"
echo "   https://www.royalnegociosagricolas.com.br/react-diagnosis"
echo ""
echo "📋 RESUMO DA FUNCIONALIDADE:"
echo "   - Carrega o site original em iframe"
echo "   - Injeta automaticamente o script de diagnóstico"
echo "   - Monitora React e elemento #root"
echo "   - Captura erros JavaScript"
echo "   - Exibe resultados em tempo real"
echo "   - Permite exportar relatório"
echo ""
echo "✅ Sistema pronto para deploy!"