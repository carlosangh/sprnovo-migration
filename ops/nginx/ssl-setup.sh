#!/bin/bash

# SSL Setup Script for Evolution API
# Domain: evo.royalnegociosagricolas.com.br
# Security Level: HIGH

set -e

DOMAIN="evo.royalnegociosagricolas.com.br"
EMAIL="admin@royalnegociosagricolas.com.br"
WEBROOT="/var/www/letsencrypt"

echo "=== SSL Setup for Evolution API ==="
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo ""

# Create webroot directory
echo "Creating webroot directory..."
sudo mkdir -p $WEBROOT
sudo chown -R www-data:www-data $WEBROOT

# Create initial nginx config without SSL
echo "Creating initial nginx config..."
sudo cp /home/cadu/SPRNOVO/ops/nginx/sites-available/evo.royalnegociosagricolas.com.br /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/evo.royalnegociosagricolas.com.br /etc/nginx/sites-enabled/

# Test nginx config
echo "Testing nginx configuration..."
sudo nginx -t

# Reload nginx
echo "Reloading nginx..."
sudo systemctl reload nginx

# Obtain SSL certificate
echo "Obtaining SSL certificate with certbot..."
sudo certbot certonly --webroot \
  --webroot-path=$WEBROOT \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email \
  --domains $DOMAIN \
  --non-interactive

# Generate strong DH parameters
echo "Generating DH parameters (this may take a while)..."
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

# Set up automatic renewal
echo "Setting up automatic renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Create renewal hook script
sudo tee /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh > /dev/null << 'EOFHOOK'
#!/bin/bash
systemctl reload nginx
EOFHOOK

sudo chmod +x /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh

# Test automatic renewal
echo "Testing automatic renewal..."
sudo certbot renew --dry-run

# Final nginx reload with SSL
echo "Final nginx configuration reload..."
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "=== SSL Setup Complete! ==="
echo "Certificate location: /etc/letsencrypt/live/$DOMAIN/"
echo "Auto-renewal: Enabled via systemd timer"
echo "Nginx config: /etc/nginx/sites-available/evo.royalnegociosagricolas.com.br"
echo ""
echo "Next steps:"
echo "1. Start Evolution API on port 8080"
echo "2. Test API access: https://$DOMAIN/health"
echo "3. Monitor logs: tail -f /var/log/nginx/evolution-api.access.log"
