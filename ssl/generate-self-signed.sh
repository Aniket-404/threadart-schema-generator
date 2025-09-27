#!/bin/bash

# ThreadArt Generator - Self-Signed Certificate Generator
# Creates development SSL certificates for local testing

set -e

# Configuration
CERT_DIR="$(dirname "$0")/certs"
DOMAIN="${SSL_DOMAIN:-threadart.local}"
DAYS=365
KEY_SIZE=2048

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}ThreadArt Generator SSL Certificate Generator${NC}"
echo "=========================================="
echo

# Create certificate directory
mkdir -p "$CERT_DIR"

# Check if certificates already exist
if [ -f "$CERT_DIR/fullchain.pem" ] && [ -f "$CERT_DIR/privkey.pem" ]; then
    echo -e "${YELLOW}Warning: Certificates already exist in $CERT_DIR${NC}"
    read -p "Do you want to regenerate them? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing certificates."
        exit 0
    fi
fi

echo "Generating self-signed SSL certificate..."
echo "Domain: $DOMAIN"
echo "Valid for: $DAYS days"
echo "Key size: $KEY_SIZE bits"
echo

# Generate private key
echo "Generating private key..."
openssl genrsa -out "$CERT_DIR/privkey.pem" $KEY_SIZE

# Generate certificate signing request
echo "Creating certificate signing request..."
openssl req -new \
    -key "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/cert.csr" \
    -subj "/C=US/ST=California/L=San Francisco/O=ThreadArt Generator/OU=Development/CN=$DOMAIN" \
    -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = ThreadArt Generator
OU = Development
CN = $DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
DNS.3 = *.${DOMAIN}
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
)

# Generate self-signed certificate
echo "Generating self-signed certificate..."
openssl x509 -req \
    -in "$CERT_DIR/cert.csr" \
    -signkey "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/fullchain.pem" \
    -days $DAYS \
    -extensions v3_req \
    -extfile <(cat <<EOF
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
DNS.3 = *.${DOMAIN}
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
)

# Create chain file (same as fullchain for self-signed)
cp "$CERT_DIR/fullchain.pem" "$CERT_DIR/chain.pem"

# Set proper permissions
chmod 600 "$CERT_DIR/privkey.pem"
chmod 644 "$CERT_DIR/fullchain.pem" "$CERT_DIR/chain.pem"

# Clean up CSR
rm -f "$CERT_DIR/cert.csr"

echo -e "${GREEN}✓ SSL certificates generated successfully!${NC}"
echo
echo "Certificate details:"
echo "=================="
openssl x509 -in "$CERT_DIR/fullchain.pem" -text -noout | grep -E "(Subject:|DNS:|IP Address:|Not Before:|Not After :)"
echo
echo -e "${YELLOW}Note: Self-signed certificates will show security warnings in browsers.${NC}"
echo "For development, you can:"
echo "1. Click 'Advanced' and 'Proceed to $DOMAIN (unsafe)' in your browser"
echo "2. Add the certificate to your browser's trusted certificate store"
echo "3. Use '--ignore-certificate-errors' flag with Chrome for testing"
echo
echo "Certificate files created:"
echo "- $CERT_DIR/fullchain.pem (Certificate)"
echo "- $CERT_DIR/privkey.pem (Private Key)"
echo "- $CERT_DIR/chain.pem (Certificate Chain)"
echo
echo -e "${GREEN}Ready to start Nginx with SSL support!${NC}"