#!/bin/bash
# SSL Certificate Setup Script for SPR System
# Supports both Let's Encrypt and self-signed certificates

set -e

DOMAIN="${1}"
EMAIL="${2:-admin@${DOMAIN}}"
ENVIRONMENT="${3:-production}"
FORCE_RENEW="${FORCE_RENEW:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[SSL-SETUP]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Function to install certbot if not present
install_certbot() {
    log "Installing certbot..."
    
    if command -v apt-get > /dev/null; then
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
    elif command -v yum > /dev/null; then
        yum install -y certbot python3-certbot-nginx
    else
        error "Package manager not supported. Please install certbot manually."
    fi
}

# Function to create self-signed certificate
create_self_signed_cert() {
    local domain="$1"
    local cert_dir="/etc/nginx/ssl"
    
    log "Creating self-signed certificate for $domain..."
    
    mkdir -p "$cert_dir"
    
    # Generate private key
    openssl genrsa -out "$cert_dir/${domain}.key" 2048
    
    # Generate certificate
    openssl req -new -x509 -key "$cert_dir/${domain}.key" \
        -out "$cert_dir/${domain}.crt" \
        -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=${domain}/emailAddress=${EMAIL}"
    
    # Set proper permissions
    chmod 600 "$cert_dir/${domain}.key"
    chmod 644 "$cert_dir/${domain}.crt"
    
    log "Self-signed certificate created successfully"
    log "Certificate: $cert_dir/${domain}.crt"
    log "Private Key: $cert_dir/${domain}.key"
}

# Function to obtain Let's Encrypt certificate
obtain_letsencrypt_cert() {
    local domain="$1"
    local email="$2"
    
    log "Obtaining Let's Encrypt certificate for $domain..."
    
    # Check if certbot is installed
    if ! command -v certbot > /dev/null; then
        install_certbot
    fi
    
    # Stop nginx temporarily
    systemctl stop nginx || service nginx stop
    
    # Obtain certificate
    certbot certonly \
        --standalone \
        --email "$email" \
        --agree-tos \
        --no-eff-email \
        --domains "$domain" \
        ${FORCE_RENEW:+--force-renewal}
    
    # Start nginx
    systemctl start nginx || service nginx start
    
    log "Let's Encrypt certificate obtained successfully"
}

# Function to renew Let's Encrypt certificates
renew_letsencrypt_cert() {
    log "Renewing Let's Encrypt certificates..."
    
    certbot renew --nginx --quiet
    
    # Reload nginx to use new certificates
    systemctl reload nginx || service nginx reload
    
    log "Certificate renewal completed"
}

# Function to setup automatic renewal
setup_auto_renewal() {
    log "Setting up automatic certificate renewal..."
    
    # Create renewal script
    cat > /etc/cron.d/certbot-renew << EOF
# Automatically renew Let's Encrypt certificates
0 2 * * * root certbot renew --quiet --nginx && systemctl reload nginx
EOF
    
    # Or add to crontab if cron.d is not available
    if [ ! -d /etc/cron.d ]; then
        (crontab -l 2>/dev/null; echo "0 2 * * * certbot renew --quiet --nginx && systemctl reload nginx") | crontab -
    fi
    
    log "Automatic renewal configured (daily at 2 AM)"
}

# Function to generate DH parameters
generate_dhparam() {
    local dhparam_file="/etc/letsencrypt/ssl-dhparams.pem"
    
    if [ ! -f "$dhparam_file" ]; then
        log "Generating DH parameters (this may take a while)..."
        openssl dhparam -out "$dhparam_file" 2048
        log "DH parameters generated"
    else
        log "DH parameters already exist"
    fi
}

# Function to create SSL configuration snippet
create_ssl_config() {
    local ssl_conf="/etc/letsencrypt/options-ssl-nginx.conf"
    
    if [ ! -f "$ssl_conf" ]; then
        log "Creating SSL configuration..."
        
        mkdir -p "$(dirname "$ssl_conf")"
        
        cat > "$ssl_conf" << 'EOF'
# SSL configuration for nginx
ssl_session_cache shared:le_nginx_SSL:10m;
ssl_session_timeout 1440m;
ssl_session_tickets off;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;

ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
EOF
        
        log "SSL configuration created"
    fi
}

# Function to test SSL configuration
test_ssl_config() {
    local domain="$1"
    
    log "Testing SSL configuration..."
    
    # Test nginx configuration
    nginx -t
    
    # Test SSL certificate (if domain is accessible)
    if command -v curl > /dev/null; then
        if curl -k -s "https://$domain/health" > /dev/null; then
            log "SSL certificate is working correctly"
        else
            warn "SSL certificate test failed - this may be normal if the domain is not yet accessible"
        fi
    fi
}

# Main function
main() {
    if [ -z "$DOMAIN" ]; then
        echo "Usage: $0 <domain> [email] [environment]"
        echo ""
        echo "Examples:"
        echo "  $0 example.com admin@example.com production"
        echo "  $0 staging.example.com admin@example.com staging"
        echo ""
        echo "Environment variables:"
        echo "  FORCE_RENEW=true  - Force renewal of existing certificates"
        exit 1
    fi
    
    log "Setting up SSL for domain: $DOMAIN"
    log "Email: $EMAIL"
    log "Environment: $ENVIRONMENT"
    
    # Create SSL configuration files
    create_ssl_config
    generate_dhparam
    
    if [ "$ENVIRONMENT" = "production" ]; then
        # Production: Use Let's Encrypt
        obtain_letsencrypt_cert "$DOMAIN" "$EMAIL"
        setup_auto_renewal
    else
        # Staging/Development: Use self-signed certificate
        create_self_signed_cert "$DOMAIN"
    fi
    
    # Test the configuration
    test_ssl_config "$DOMAIN"
    
    log "SSL setup completed successfully for $DOMAIN"
    
    if [ "$ENVIRONMENT" = "production" ]; then
        log "Certificate will be automatically renewed"
    else
        warn "Using self-signed certificate - not suitable for production"
    fi
}

# Handle command line arguments
case "${1:-}" in
    "renew")
        renew_letsencrypt_cert
        exit 0
        ;;
    "--help"|"-h")
        echo "SSL Certificate Setup Script"
        echo ""
        echo "Usage: $0 <domain> [email] [environment]"
        echo "       $0 renew"
        echo ""
        echo "Commands:"
        echo "  <domain>   - Set up SSL for specified domain"
        echo "  renew      - Renew existing Let's Encrypt certificates"
        echo ""
        echo "Examples:"
        echo "  $0 example.com"
        echo "  $0 example.com admin@example.com production"
        echo "  $0 staging.example.com admin@example.com staging"
        echo "  $0 renew"
        exit 0
        ;;
    *)
        main
        ;;
esac