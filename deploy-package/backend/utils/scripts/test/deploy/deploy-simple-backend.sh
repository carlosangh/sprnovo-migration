#!/bin/bash

# Script de Deploy para simple_backend.js
# =====================================

echo "🚀 Deploy do Simple Backend para SPR"
echo "======================================"

SERVER_IP="138.197.83.3"
DROPLET_ID="511012728"
BACKEND_FILE="simple_backend.js"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para executar comandos remotos
execute_remote() {
    local cmd="$1"
    echo -e "${YELLOW}Executando: $cmd${NC}"
    
    # Tentar diferentes métodos de conexão
    if ssh -o ConnectTimeout=5 root@$SERVER_IP "$cmd" 2>/dev/null; then
        return 0
    elif doctl compute ssh $DROPLET_ID --ssh-command "$cmd" 2>/dev/null; then
        return 0  
    else
        echo -e "${RED}❌ Falha na execução do comando${NC}"
        return 1
    fi
}

# Função para copiar arquivo
copy_file() {
    local file="$1"
    local dest="$2"
    
    echo -e "${YELLOW}Copiando $file para $dest${NC}"
    
    # Tentar SCP
    if scp "$file" root@$SERVER_IP:"$dest" 2>/dev/null; then
        echo -e "${GREEN}✅ Arquivo copiado com sucesso${NC}"
        return 0
    else
        echo -e "${RED}❌ Falha na cópia do arquivo${NC}"
        return 1
    fi
}

# Verificar se o arquivo existe
if [[ ! -f "$BACKEND_FILE" ]]; then
    echo -e "${RED}❌ Arquivo $BACKEND_FILE não encontrado!${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Iniciando deploy do backend...${NC}"

# 1. Verificar status do servidor
echo -e "${YELLOW}1. Verificando status do servidor...${NC}"
if execute_remote "whoami && pwd"; then
    echo -e "${GREEN}✅ Conexão com servidor estabelecida${NC}"
else
    echo -e "${RED}❌ Não foi possível conectar ao servidor${NC}"
    echo -e "${YELLOW}💡 Instruções manuais:${NC}"
    echo "1. Acesse o servidor via console do DigitalOcean"
    echo "2. Copie o conteúdo do arquivo simple_backend.js"
    echo "3. Execute os comandos abaixo no servidor:"
    echo ""
    echo "# Parar processos antigos"
    echo "pm2 stop all"
    echo "pm2 delete all"
    echo ""
    echo "# Criar arquivo do backend"
    echo "cat > /opt/spr/simple_backend.js << 'EOF'"
    cat "$BACKEND_FILE"
    echo "EOF"
    echo ""
    echo "# Instalar dependências"
    echo "cd /opt/spr"
    echo "npm install express cors"
    echo ""
    echo "# Iniciar servidor"
    echo "pm2 start simple_backend.js --name 'royal-backend'"
    echo "pm2 save"
    echo ""
    exit 1
fi

# 2. Parar processos antigos
echo -e "${YELLOW}2. Parando processos backend antigos...${NC}"
execute_remote "pm2 stop all 2>/dev/null; pm2 delete all 2>/dev/null; pkill -f 'backend_server'"

# 3. Copiar arquivo
echo -e "${YELLOW}3. Copiando simple_backend.js...${NC}"
if ! copy_file "$BACKEND_FILE" "/opt/spr/simple_backend.js"; then
    echo -e "${RED}❌ Falha na cópia. Tentando método alternativo...${NC}"
    
    # Método alternativo usando tar
    tar czf /tmp/backend_deploy.tar.gz "$BACKEND_FILE"
    if scp /tmp/backend_deploy.tar.gz root@$SERVER_IP:/tmp/backend_deploy.tar.gz 2>/dev/null; then
        execute_remote "cd /opt/spr && tar xzf /tmp/backend_deploy.tar.gz && rm /tmp/backend_deploy.tar.gz"
        echo -e "${GREEN}✅ Arquivo copiado via tar${NC}"
    else
        echo -e "${RED}❌ Todas as tentativas de cópia falharam${NC}"
        exit 1
    fi
    rm /tmp/backend_deploy.tar.gz
fi

# 4. Verificar dependências
echo -e "${YELLOW}4. Verificando e instalando dependências...${NC}"
execute_remote "cd /opt/spr && npm install express cors --save"

# 5. Iniciar servidor
echo -e "${YELLOW}5. Iniciando servidor com PM2...${NC}"
execute_remote "cd /opt/spr && pm2 start simple_backend.js --name 'royal-backend'"
execute_remote "pm2 save"

# 6. Verificar status
echo -e "${YELLOW}6. Verificando status do servidor...${NC}"
execute_remote "pm2 status"
execute_remote "netstat -tlnp | grep :3001"

# 7. Testar APIs
echo -e "${YELLOW}7. Testando APIs...${NC}"
sleep 3
execute_remote "curl -s http://localhost:3001/api/status | jq . || curl -s http://localhost:3001/api/status"

echo -e "${GREEN}🎉 Deploy concluído!${NC}"
echo -e "${YELLOW}📡 Testando conexão externa...${NC}"

# Testar API externamente
if curl -s -m 5 "http://$SERVER_IP:3001/api/status" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ APIs acessíveis externamente${NC}"
else
    echo -e "${RED}❌ APIs não acessíveis externamente${NC}"
    echo -e "${YELLOW}💡 Verificar configuração do firewall/nginx${NC}"
fi

echo -e "${YELLOW}🌐 Site: https://www.royalnegociosagricolas.com.br${NC}"
echo -e "${YELLOW}📊 API Status: http://$SERVER_IP:3001/api/status${NC}"