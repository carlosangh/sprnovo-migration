#!/bin/bash
# Network Diagnosis Script for SPR Project
# Royal Negócios Agrícolas - WebSocket/Socket.IO Fix

echo "=== DIAGNÓSTICO DE REDE - SPR PROJECT ==="
echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "1. VERIFICAÇÃO DE PORTAS LOCAIS:"
echo "--------------------------------"
echo "Porta 3002 (API Principal):"
if curl -s -I http://127.0.0.1:3002 > /dev/null; then
    echo "  ✅ ONLINE - $(curl -s -I http://127.0.0.1:3002 | head -1)"
else
    echo "  ❌ OFFLINE"
fi

echo ""
echo "Porta 3003 (WhatsApp/WPPConnect):"
if curl -s -I http://127.0.0.1:3003 > /dev/null; then
    echo "  ✅ ONLINE - $(curl -s -I http://127.0.0.1:3003 | head -1)"
else
    echo "  ❌ OFFLINE"
fi

echo ""
echo "2. TESTE SOCKET.IO LOCAL:"
echo "------------------------"
echo "Socket.IO Polling:"
if curl -s -I "http://127.0.0.1:3002/socket.io/?EIO=4&transport=polling" | grep -q "200 OK"; then
    echo "  ✅ Socket.IO disponível localmente"
else
    echo "  ❌ Socket.IO não disponível localmente"
    echo "  Response: $(curl -s -I "http://127.0.0.1:3002/socket.io/?EIO=4&transport=polling" | head -1)"
fi

echo ""
echo "3. TESTE DOMÍNIO REMOTO:"
echo "-----------------------"
echo "HTTPS Principal:"
if curl -s -I https://royalnegociosagricolas.com.br > /dev/null; then
    echo "  ✅ ONLINE - $(curl -s -I https://royalnegociosagricolas.com.br | head -1)"
else
    echo "  ❌ OFFLINE"
fi

echo ""
echo "Socket.IO Remoto (WSS):"
if curl -s -I "https://royalnegociosagricolas.com.br/socket.io/?EIO=4&transport=polling" | grep -q "200 OK"; then
    echo "  ✅ Socket.IO disponível remotamente"
else
    echo "  ❌ Socket.IO não disponível remotamente"
    echo "  Response: $(curl -s -I "https://royalnegociosagricolas.com.br/socket.io/?EIO=4&transport=polling" | head -1)"
fi

echo ""
echo "4. VERIFICAÇÃO DE PROCESSOS:"
echo "---------------------------"
echo "Processos na porta 3002:"
if lsof -i :3002 2>/dev/null; then
    echo "  ✅ Processo encontrado"
else
    echo "  ❌ Nenhum processo na porta 3002"
fi

echo ""
echo "Processos na porta 3003:"
if lsof -i :3003 2>/dev/null; then
    echo "  ✅ Processo encontrado"
else
    echo "  ❌ Nenhum processo na porta 3003"
fi

echo ""
echo "5. TESTE DE API ENDPOINTS:"
echo "-------------------------"
echo "API Health Check:"
response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3002/api/health)
if [ "$response" = "200" ]; then
    echo "  ✅ API Health Check OK ($response)"
elif [ "$response" = "404" ]; then
    echo "  ⚠️  API responde mas endpoint /health não existe ($response)"
else
    echo "  ❌ API Health Check falhou ($response)"
fi

echo ""
echo "6. VERIFICAÇÃO SSL/TLS:"
echo "----------------------"
echo "Certificado SSL:"
if openssl s_client -connect royalnegociosagricolas.com.br:443 </dev/null 2>/dev/null | openssl x509 -noout -dates; then
    echo "  ✅ Certificado SSL válido"
else
    echo "  ❌ Problema com certificado SSL"
fi

echo ""
echo "=== FIM DO DIAGNÓSTICO ==="