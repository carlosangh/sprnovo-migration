#!/bin/bash

echo "🚀 Deploy SPR para servidor DigitalOcean"
echo "========================================="

# Configurações
SERVER_IP="138.197.83.3"
DROPLET_ID="511012728"
LOCAL_PATH="/home/cadu/spr-project"
REMOTE_PATH="/opt/spr"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para executar comandos no servidor
remote_exec() {
    /home/cadu/doctl compute ssh $DROPLET_ID --ssh-command "$1"
}

# Função para copiar arquivos
copy_files() {
    local src=$1
    local dest=$2
    echo -e "${YELLOW}Copiando $src para servidor...${NC}"
    
    # Criar arquivo tar local
    tar czf /tmp/deploy.tar.gz -C "$LOCAL_PATH" "$src" 2>/dev/null
    
    # Copiar para servidor via doctl
    cat /tmp/deploy.tar.gz | remote_exec "cat > /tmp/deploy.tar.gz && cd $REMOTE_PATH && tar xzf /tmp/deploy.tar.gz && rm /tmp/deploy.tar.gz"
    
    rm /tmp/deploy.tar.gz
}

# Menu de opções
echo "Escolha o tipo de deploy:"
echo "1) Deploy completo (frontend + backend)"
echo "2) Deploy apenas frontend"
echo "3) Deploy apenas backend"
echo "4) Deploy arquivo específico"
echo "5) Executar comando no servidor"
echo "6) Ver logs do servidor"
echo "7) Reiniciar serviços"

read -p "Opção: " option

case $option in
    1)
        echo -e "${GREEN}Deploy completo iniciado...${NC}"
        
        # Backend
        if [ -d "$LOCAL_PATH/backend" ]; then
            copy_files "backend" "$REMOTE_PATH"
        fi
        
        # Frontend
        if [ -d "$LOCAL_PATH/frontend" ]; then
            copy_files "frontend" "$REMOTE_PATH"
        fi
        
        # Package.json
        if [ -f "$LOCAL_PATH/package.json" ]; then
            copy_files "package.json" "$REMOTE_PATH"
            echo -e "${YELLOW}Instalando dependências...${NC}"
            remote_exec "cd $REMOTE_PATH && npm install"
        fi
        
        echo -e "${GREEN}Deploy completo finalizado!${NC}"
        ;;
        
    2)
        echo -e "${GREEN}Deploy do frontend...${NC}"
        if [ -d "$LOCAL_PATH/frontend" ]; then
            copy_files "frontend" "$REMOTE_PATH"
            echo -e "${YELLOW}Build do frontend...${NC}"
            remote_exec "cd $REMOTE_PATH/frontend && npm install && npm run build"
        fi
        ;;
        
    3)
        echo -e "${GREEN}Deploy do backend...${NC}"
        if [ -d "$LOCAL_PATH/backend" ]; then
            copy_files "backend" "$REMOTE_PATH"
        fi
        ;;
        
    4)
        read -p "Digite o caminho do arquivo (relativo ao projeto): " filepath
        if [ -f "$LOCAL_PATH/$filepath" ]; then
            copy_files "$filepath" "$REMOTE_PATH"
            echo -e "${GREEN}Arquivo $filepath enviado!${NC}"
        else
            echo -e "${RED}Arquivo não encontrado!${NC}"
        fi
        ;;
        
    5)
        read -p "Digite o comando para executar: " cmd
        remote_exec "$cmd"
        ;;
        
    6)
        echo -e "${YELLOW}Logs do PM2:${NC}"
        remote_exec "pm2 logs --lines 50"
        ;;
        
    7)
        echo -e "${YELLOW}Reiniciando serviços...${NC}"
        remote_exec "pm2 restart all || echo 'PM2 não está rodando'"
        remote_exec "systemctl restart nginx || echo 'Nginx não instalado'"
        echo -e "${GREEN}Serviços reiniciados!${NC}"
        ;;
        
    *)
        echo -e "${RED}Opção inválida!${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ Operação concluída!${NC}"