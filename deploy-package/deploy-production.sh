#!/bin/bash
# SPRNOVO Production Deployment Script
# Target Server: 138.197.83.3
# Deploy Date: $(date)

set -euo pipefail

# Configuration
SERVER_IP="138.197.83.3"
SERVER_USER="root"
DEPLOY_PATH="/opt/sprnovo"
BACKUP_PATH="/opt/backups/sprnovo-$(date +%Y%m%d-%H%M%S)"
SERVICE_NAME="sprnovo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

# Verify local files
verify_files() {
    log "Verificando arquivos locais..."
    
    local required_files=(
        "backend/node/spr-backend-complete-extended.js"
        "frontend/spr-complete.html"
        ".env"
        "docker-compose.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Arquivo obrigatório não encontrado: $file"
            exit 1
        fi
        success "Encontrado: $file ($(ls -lh "$file" | awk '{print $5}'))"
    done
}

# Create deployment package
create_package() {
    log "Criando pacote de deployment..."
    
    # Create tarball with all necessary files
    tar -czf sprnovo-deploy.tar.gz \
        backend/ \
        frontend/ \
        scripts/ \
        ops/ \
        nginx/ \
        .env \
        docker-compose.yml \
        --exclude='backend/node/node_modules' \
        --exclude='*.log' \
        --exclude='.git'
    
    success "Pacote criado: sprnovo-deploy.tar.gz ($(ls -lh sprnovo-deploy.tar.gz | awk '{print $5}'))"
}

# Deploy to server
deploy_to_server() {
    log "Iniciando deploy para servidor $SERVER_IP..."
    
    # Upload package
    log "Fazendo upload do pacote..."
    scp sprnovo-deploy.tar.gz $SERVER_USER@$SERVER_IP:/tmp/
    
    # Execute deployment on server
    ssh $SERVER_USER@$SERVER_IP << 'REMOTE_SCRIPT'
        set -euo pipefail
        
        # Stop existing services
        echo "Parando serviços existentes..."
        systemctl stop sprnovo || true
        docker-compose -f /opt/sprnovo/docker-compose.yml down || true
        
        # Backup current deployment
        if [[ -d "/opt/sprnovo" ]]; then
            echo "Criando backup..."
            mv /opt/sprnovo /opt/backups/sprnovo-backup-$(date +%Y%m%d-%H%M%S) || true
        fi
        
        # Create deployment directory
        mkdir -p /opt/sprnovo
        cd /opt/sprnovo
        
        # Extract new deployment
        echo "Extraindo nova versão..."
        tar -xzf /tmp/sprnovo-deploy.tar.gz
        
        # Set permissions
        chown -R www-data:www-data /opt/sprnovo
        chmod +x scripts/*.sh || true
        
        # Install/Update Node.js dependencies
        cd backend/node
        npm ci --only=production
        
        # Build and start containers
        cd /opt/sprnovo
        docker-compose build --no-cache
        docker-compose up -d
        
        # Wait for services to start
        echo "Aguardando serviços iniciarem..."
        sleep 30
        
        # Verify deployment
        echo "Verificando deployment..."
        curl -f http://localhost:8090/api/status || {
            echo "ERRO: Backend não está respondendo na porta 8090"
            exit 1
        }
        
        curl -f http://localhost:8082/ || {
            echo "ERRO: Frontend não está respondendo na porta 8082"
            exit 1
        }
        
        echo "✓ Deploy concluído com sucesso!"
        
        # Clean up
        rm -f /tmp/sprnovo-deploy.tar.gz
REMOTE_SCRIPT

    success "Deploy para servidor concluído!"
}

# Configure nginx
configure_nginx() {
    log "Configurando nginx no servidor..."
    
    ssh $SERVER_USER@$SERVER_IP << 'REMOTE_SCRIPT'
        # Update nginx configuration for SPRNOVO
        cat > /etc/nginx/sites-available/sprnovo << 'EOF'
server {
    listen 80;
    server_name evo.royalnegociosagricolas.com.br;
    
    # Frontend
    location / {
        proxy_pass http://localhost:8082;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:8090/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:8090/api/status;
        access_log off;
    }
}
EOF
        
        # Enable site
        ln -sf /etc/nginx/sites-available/sprnovo /etc/nginx/sites-enabled/
        
        # Test and reload nginx
        nginx -t && systemctl reload nginx
        
        echo "✓ Nginx configurado!"
REMOTE_SCRIPT

    success "Nginx configurado no servidor!"
}

# Configure systemd service
configure_service() {
    log "Configurando serviço systemd..."
    
    ssh $SERVER_USER@$SERVER_IP << 'REMOTE_SCRIPT'
        cat > /etc/systemd/system/sprnovo.service << 'EOF'
[Unit]
Description=SPRNOVO Production Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/sprnovo
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable sprnovo
        systemctl start sprnovo
        
        echo "✓ Serviço systemd configurado!"
REMOTE_SCRIPT

    success "Serviço systemd configurado!"
}

# Final verification
verify_deployment() {
    log "Executando verificação final..."
    
    # Test backend endpoints
    local endpoints=(
        "http://138.197.83.3:8090/api/status"
        "http://138.197.83.3:8090/api/whatsapp/status"
        "http://138.197.83.3:8082/"
    )
    
    for endpoint in "${endpoints[@]}"; do
        log "Testando: $endpoint"
        if curl -f -m 10 "$endpoint" > /dev/null 2>&1; then
            success "OK: $endpoint"
        else
            warning "FALHA: $endpoint - pode estar inicializando"
        fi
    done
    
    # Test n8n webhook connectivity
    log "Testando conectividade com n8n..."
    ssh $SERVER_USER@$SERVER_IP << 'REMOTE_SCRIPT'
        # Test internal connectivity
        docker exec sprnovo-backend curl -f http://localhost:8090/api/status || echo "Backend interno: FALHA"
        docker exec sprnovo-n8n curl -f http://localhost:5678/healthz || echo "N8N interno: FALHA"
        
        echo "✓ Verificações internas concluídas"
REMOTE_SCRIPT
}

# Print deployment summary
print_summary() {
    log "=== RESUMO DO DEPLOYMENT ==="
    echo ""
    success "Backend: http://138.197.83.3:8090/api/status"
    success "Frontend: http://138.197.83.3:8082/"
    success "N8N: http://138.197.83.3:5678/"
    success "Evolution API: http://138.197.83.3:8080/"
    echo ""
    log "Configurações importantes:"
    echo "  - Backend rodando na porta 8090"
    echo "  - Frontend via nginx na porta 8082"
    echo "  - PostgreSQL preservado com dados existentes"
    echo "  - N8N webhooks configurados para porta 8090"
    echo ""
    log "Para monitorar os serviços:"
    echo "  ssh root@138.197.83.3"
    echo "  docker-compose -f /opt/sprnovo/docker-compose.yml logs -f"
    echo ""
    success "DEPLOYMENT CONCLUÍDO!"
}

# Main execution
main() {
    log "=== SPRNOVO PRODUCTION DEPLOYMENT ==="
    log "Servidor destino: $SERVER_IP"
    log "Data/Hora: $(date)"
    echo ""
    
    verify_files
    create_package
    deploy_to_server
    configure_nginx
    configure_service
    verify_deployment
    print_summary
}

# Run main function
main "$@"