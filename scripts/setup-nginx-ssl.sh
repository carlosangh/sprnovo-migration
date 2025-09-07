#!/bin/bash

# SPRNOVO Nginx + SSL Setup Script
# Execute como root: sudo ./setup-nginx-ssl.sh

set -e

DOMAIN="automation.royalnegociosagricolas.com.br"
EMAIL="admin@royalnegociosagricolas.com.br"
SPRNOVO_DIR="/home/cadu/SPRNOVO"

echo "=== SPRNOVO Nginx + SSL Setup ==="
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Este script deve ser executado como root (use sudo)" 
   exit 1
fi

# Install certbot if not installed
echo "Instalando/Atualizando Certbot..."
apt update
apt install -y certbot python3-certbot-nginx

# Copy nginx configuration
echo "Copiando configuração do Nginx..."
cp $SPRNOVO_DIR/nginx/automation.royalnegociosagricolas.com.br /etc/nginx/sites-available/

# Create temporary HTTP-only version for certbot
cat > /etc/nginx/sites-available/automation.royalnegociosagricolas.com.br.temp << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}
EOF

# Enable temporary site
echo "Habilitando configuração temporária..."
ln -sf /etc/nginx/sites-available/automation.royalnegociosagricolas.com.br.temp /etc/nginx/sites-enabled/automation.royalnegociosagricolas.com.br
rm -f /etc/nginx/sites-enabled/default

# Test nginx config
nginx -t

# Reload nginx
systemctl reload nginx

# Obtain SSL certificate
echo "Obtendo certificado SSL para $DOMAIN..."
certbot --nginx --non-interactive --agree-tos --email $EMAIL -d $DOMAIN

# Replace with full SSL configuration
echo "Aplicando configuração SSL completa..."
rm /etc/nginx/sites-enabled/automation.royalnegociosagricolas.com.br
ln -sf /etc/nginx/sites-available/automation.royalnegociosagricolas.com.br /etc/nginx/sites-enabled/automation.royalnegociosagricolas.com.br

# Test nginx config again
nginx -t

# Reload nginx with SSL config
systemctl reload nginx

# Setup auto-renewal
echo "Configurando renovação automática..."
crontab -l | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | crontab -

echo ""
echo "=== Setup Concluído! ==="
echo "Domain: https://$DOMAIN"
echo "Certificado SSL instalado e configurado"
echo "Auto-renovação configurada"
echo ""