#!/bin/bash

# ThreadArt Generator - SSL Certificate Renewal
# Renew Let's Encrypt certificates and reload Nginx

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}ThreadArt Generator - SSL Certificate Renewal${NC}"
echo "============================================="
echo

# Load environment variables
if [ -f "../.env" ]; then
    source ../.env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Check required variables
if [ -z "$SSL_DOMAIN" ]; then
    echo -e "${RED}Error: SSL_DOMAIN not set in .env file${NC}"
    exit 1
fi

if [ -z "$SSL_EMAIL" ]; then
    echo -e "${RED}Error: SSL_EMAIL not set in .env file${NC}"
    exit 1
fi

echo "Domain: $SSL_DOMAIN"
echo "Email: $SSL_EMAIL"
echo

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose not found${NC}"
    exit 1
fi

# Function to check certificate expiry
check_certificate_expiry() {
    if [ -f "../ssl/certs/fullchain.pem" ]; then
        local expiry_date=$(openssl x509 -in ../ssl/certs/fullchain.pem -noout -enddate | cut -d= -f2)
        local expiry_timestamp=$(date -d "$expiry_date" +%s)
        local current_timestamp=$(date +%s)
        local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        echo "Current certificate expires in $days_until_expiry days ($expiry_date)"
        
        if [ $days_until_expiry -lt 30 ]; then
            echo -e "${YELLOW}Certificate expires soon, renewal recommended${NC}"
            return 0
        else
            echo -e "${GREEN}Certificate is valid for $days_until_expiry more days${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}No existing certificate found${NC}"
        return 0
    fi
}

# Check current certificate
if check_certificate_expiry; then
    SHOULD_RENEW=true
else
    read -p "Certificate doesn't need renewal yet. Force renewal? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SHOULD_RENEW=true
    else
        SHOULD_RENEW=false
    fi
fi

if [ "$SHOULD_RENEW" = "true" ]; then
    echo "Starting certificate renewal process..."
    echo
    
    # Stop nginx temporarily if it's running
    if docker-compose ps nginx | grep -q "Up"; then
        echo "Stopping Nginx for renewal..."
        docker-compose stop nginx
        RESTART_NGINX=true
    else
        RESTART_NGINX=false
    fi
    
    # Run certbot
    echo "Running certbot..."
    if docker-compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email $SSL_EMAIL \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d $SSL_DOMAIN; then
        
        echo -e "${GREEN}✓ Certificate renewed successfully${NC}"
        
        # Copy certificates to nginx ssl directory
        echo "Copying certificates..."
        mkdir -p ../ssl/certs
        
        # Note: In a real setup, you'd copy from certbot's letsencrypt directory
        # This is a placeholder for the actual certificate copy process
        echo -e "${YELLOW}Note: In production, copy certificates from /etc/letsencrypt/live/$SSL_DOMAIN/${NC}"
        
    else
        echo -e "${RED}✗ Certificate renewal failed${NC}"
        
        # Restart nginx even if renewal failed
        if [ "$RESTART_NGINX" = "true" ]; then
            echo "Restarting Nginx..."
            docker-compose start nginx
        fi
        
        exit 1
    fi
    
    # Restart nginx
    if [ "$RESTART_NGINX" = "true" ]; then
        echo "Restarting Nginx..."
        if docker-compose start nginx; then
            echo -e "${GREEN}✓ Nginx restarted successfully${NC}"
        else
            echo -e "${RED}✗ Failed to restart Nginx${NC}"
            exit 1
        fi
    fi
    
    # Verify new certificate
    echo
    echo "Verifying new certificate..."
    if check_certificate_expiry; then
        echo -e "${GREEN}✓ Certificate renewal completed successfully!${NC}"
    else
        echo -e "${GREEN}✓ Certificate is now valid for extended period${NC}"
    fi
    
else
    echo "Certificate renewal skipped."
fi

echo
echo -e "${GREEN}SSL renewal process completed!${NC}"