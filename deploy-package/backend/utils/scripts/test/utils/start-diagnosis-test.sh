#!/bin/bash

echo "🔍 SISTEMA DE DIAGNÓSTICO REACT - TESTE LOCAL"
echo "=============================================="
echo ""

# Verificar se Node.js está disponível
if ! command -v node &> /dev/null; then
    echo "❌ Node.js não encontrado. Instale o Node.js primeiro."
    exit 1
fi

# Verificar se os arquivos necessários existem
echo "📋 Verificando arquivos necessários..."

if [[ ! -f "backend_server_fixed.js" ]]; then
    echo "❌ backend_server_fixed.js não encontrado"
    exit 1
fi

if [[ ! -f "react-diagnosis.html" ]]; then
    echo "❌ react-diagnosis.html não encontrado"
    exit 1
fi

if [[ ! -f "test-diagnosis.html" ]]; then
    echo "❌ test-diagnosis.html não encontrado"
    exit 1
fi

echo "✅ Todos os arquivos encontrados"
echo ""

# Verificar se a porta 3002 está ocupada
if lsof -Pi :3002 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Porta 3002 já está em uso"
    echo "   Parando processo existente..."
    pkill -f "node backend_server_fixed.js" 2>/dev/null || true
    sleep 2
fi

echo "🚀 Iniciando backend servidor..."
echo "   Porta: 3002"
echo "   Endpoints disponíveis:"
echo "   - http://localhost:3002/health"
echo "   - http://localhost:3002/react-diagnosis"
echo "   - http://localhost:3002/test-diagnosis.html (arquivo local)"
echo ""

# Iniciar servidor em background
node backend_server_fixed.js &
SERVER_PID=$!

# Aguardar servidor inicializar
echo "⏳ Aguardando servidor inicializar..."
sleep 3

# Verificar se o servidor está funcionando
if curl -s http://localhost:3002/health > /dev/null; then
    echo "✅ Servidor funcionando!"
    echo ""
    echo "🌐 TESTES DISPONÍVEIS:"
    echo "   1. Página de teste: http://localhost:3002/test-diagnosis.html"
    echo "   2. Diagnóstico React: http://localhost:3002/react-diagnosis"
    echo "   3. Health check: http://localhost:3002/health"
    echo ""
    echo "📱 Para testar em produção:"
    echo "   https://www.royalnegociosagricolas.com.br/react-diagnosis"
    echo ""
    echo "🛑 Para parar o servidor: Ctrl+C ou kill $SERVER_PID"
    echo ""
    echo "⏳ Servidor rodando (PID: $SERVER_PID)..."
    
    # Manter o script ativo
    wait $SERVER_PID
    
else
    echo "❌ Falha ao iniciar servidor"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi