#!/bin/bash

# ThreadArt Generator - Nginx Configuration Test
# Test configuration syntax without affecting running service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}ThreadArt Generator - Nginx Configuration Test${NC}"
echo "============================================="
echo

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose not found${NC}"
    exit 1
fi

# Check if Nginx container is running
if ! docker-compose ps nginx | grep -q "Up"; then
    echo -e "${YELLOW}Warning: Nginx container is not running${NC}"
    echo "Testing configuration with temporary container..."
    
    # Test with temporary container
    if docker run --rm -v "$(pwd)/nginx:/etc/nginx:ro" nginx:alpine nginx -t; then
        echo -e "${GREEN}✓ Configuration syntax is valid${NC}"
    else
        echo -e "${RED}✗ Configuration syntax errors found${NC}"
        exit 1
    fi
else
    echo "Testing configuration in running container..."
    
    # Test in running container
    if docker-compose exec nginx nginx -t; then
        echo -e "${GREEN}✓ Configuration syntax is valid${NC}"
        
        # Additional checks
        echo
        echo "Additional validation:"
        
        # Check SSL certificate files (if they exist)
        if docker-compose exec nginx test -f /etc/nginx/ssl/fullchain.pem; then
            echo -e "${GREEN}✓ SSL certificate found${NC}"
            
            # Check certificate validity
            if docker-compose exec nginx openssl x509 -in /etc/nginx/ssl/fullchain.pem -noout -checkend 86400 &>/dev/null; then
                echo -e "${GREEN}✓ SSL certificate is valid${NC}"
            else
                echo -e "${YELLOW}⚠ SSL certificate expires within 24 hours${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ SSL certificate not found${NC}"
        fi
        
        # Check if upstream servers are accessible
        echo
        echo "Checking upstream servers:"
        
        # App server
        if docker-compose exec nginx nc -z app 3000 2>/dev/null; then
            echo -e "${GREEN}✓ App server (app:3000) is accessible${NC}"
        else
            echo -e "${RED}✗ App server (app:3000) is not accessible${NC}"
        fi
        
        # Grafana
        if docker-compose exec nginx nc -z grafana 3000 2>/dev/null; then
            echo -e "${GREEN}✓ Grafana (grafana:3000) is accessible${NC}"
        else
            echo -e "${RED}✗ Grafana (grafana:3000) is not accessible${NC}"
        fi
        
        # Prometheus
        if docker-compose exec nginx nc -z prometheus 9090 2>/dev/null; then
            echo -e "${GREEN}✓ Prometheus (prometheus:9090) is accessible${NC}"
        else
            echo -e "${RED}✗ Prometheus (prometheus:9090) is not accessible${NC}"
        fi
        
    else
        echo -e "${RED}✗ Configuration syntax errors found${NC}"
        exit 1
    fi
fi

echo
echo -e "${GREEN}Configuration test completed!${NC}"