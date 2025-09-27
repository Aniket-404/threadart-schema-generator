#!/bin/bash

# ThreadArt Generator - Nginx Configuration Reload
# Gracefully reload Nginx without dropping connections

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}ThreadArt Generator - Nginx Reload${NC}"
echo "===================================="
echo

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose not found${NC}"
    exit 1
fi

# Test configuration first
echo "Testing Nginx configuration..."
if docker-compose exec nginx nginx -t; then
    echo -e "${GREEN}✓ Configuration test passed${NC}"
else
    echo -e "${RED}✗ Configuration test failed${NC}"
    echo "Please fix configuration errors before reloading."
    exit 1
fi

echo

# Graceful reload
echo "Performing graceful reload..."
if docker-compose exec nginx nginx -s reload; then
    echo -e "${GREEN}✓ Nginx reloaded successfully${NC}"
    echo
    
    # Show status
    echo "Current Nginx status:"
    docker-compose ps nginx
else
    echo -e "${RED}✗ Nginx reload failed${NC}"
    echo
    
    # Show recent logs for troubleshooting
    echo "Recent error logs:"
    docker-compose logs --tail=20 nginx
    exit 1
fi

echo
echo -e "${GREEN}Reload completed successfully!${NC}"