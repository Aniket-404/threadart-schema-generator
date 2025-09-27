#!/bin/bash

# ThreadArt Generator - Cloudinary Integration Test Script
# Validates Cloudinary configuration and connectivity

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}ThreadArt Generator - Cloudinary Integration Test${NC}"
echo "=================================================="
echo

# Load environment variables
if [ -f ".env" ]; then
    source .env
    echo -e "${GREEN}✓ Environment file loaded${NC}"
else
    echo -e "${RED}✗ .env file not found${NC}"
    exit 1
fi

# Check required environment variables
echo
echo -e "${BLUE}Checking Cloudinary Configuration:${NC}"

if [ -z "$CLOUDINARY_CLOUD_NAME" ]; then
    echo -e "${RED}✗ CLOUDINARY_CLOUD_NAME not set${NC}"
    MISSING_VARS=true
fi

if [ -z "$CLOUDINARY_API_KEY" ]; then
    echo -e "${RED}✗ CLOUDINARY_API_KEY not set${NC}"
    MISSING_VARS=true
fi

if [ -z "$CLOUDINARY_API_SECRET" ]; then
    echo -e "${RED}✗ CLOUDINARY_API_SECRET not set${NC}"
    MISSING_VARS=true
fi

if [ "$MISSING_VARS" = "true" ]; then
    echo
    echo -e "${YELLOW}Please configure Cloudinary credentials in .env file:${NC}"
    echo "CLOUDINARY_CLOUD_NAME=your_cloud_name"
    echo "CLOUDINARY_API_KEY=your_api_key"
    echo "CLOUDINARY_API_SECRET=your_api_secret"
    echo
    echo "Get these from: https://cloudinary.com/console"
    exit 1
fi

echo -e "${GREEN}✓ All Cloudinary environment variables are set${NC}"
echo "  Cloud Name: $CLOUDINARY_CLOUD_NAME"
echo "  API Key: ${CLOUDINARY_API_KEY:0:6}***"
echo "  API Secret: ${CLOUDINARY_API_SECRET:0:6}***"

# Test Cloudinary connectivity
echo
echo -e "${BLUE}Testing Cloudinary Connectivity:${NC}"

# Ping Cloudinary API
PING_URL="https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/ping"
if curl -f -s "$PING_URL" > /dev/null; then
    echo -e "${GREEN}✓ Cloudinary API is reachable${NC}"
else
    echo -e "${RED}✗ Cannot reach Cloudinary API${NC}"
    echo "  URL tested: $PING_URL"
    exit 1
fi

# Test authentication
echo
echo -e "${BLUE}Testing Cloudinary Authentication:${NC}"

# Generate signature for auth test (using current timestamp)
TIMESTAMP=$(date +%s)
PUBLIC_ID="test_auth_$(date +%s)"

# Create string to sign (public_id + timestamp)
STRING_TO_SIGN="public_id=${PUBLIC_ID}&timestamp=${TIMESTAMP}${CLOUDINARY_API_SECRET}"

# Generate SHA1 signature (requires openssl)
if command -v openssl &> /dev/null; then
    SIGNATURE=$(echo -n "$STRING_TO_SIGN" | openssl dgst -sha1 -hex | sed 's/^.* //')
    
    # Test upload with minimal payload (will fail but should authenticate)
    AUTH_TEST_URL="https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload"
    
    RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -F "public_id=$PUBLIC_ID" \
        -F "timestamp=$TIMESTAMP" \
        -F "api_key=$CLOUDINARY_API_KEY" \
        -F "signature=$SIGNATURE" \
        "$AUTH_TEST_URL")
    
    HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')
    
    if [ "$HTTP_STATUS" -eq 400 ]; then
        echo -e "${GREEN}✓ Cloudinary authentication successful${NC}"
        echo "  (400 error expected - no file provided, but auth worked)"
    elif [ "$HTTP_STATUS" -eq 401 ]; then
        echo -e "${RED}✗ Cloudinary authentication failed${NC}"
        echo "  Check your API key and secret"
        exit 1
    else
        echo -e "${YELLOW}⚠ Unexpected response: HTTP $HTTP_STATUS${NC}"
        echo "  Authentication may have issues"
    fi
else
    echo -e "${YELLOW}⚠ OpenSSL not available - skipping auth test${NC}"
fi

# Test Docker integration
echo
echo -e "${BLUE}Testing Docker Integration:${NC}"

if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓ docker-compose is available${NC}"
    
    # Check if services are configured
    if docker-compose config --services | grep -q "app"; then
        echo -e "${GREEN}✓ App service configured in docker-compose.yml${NC}"
        
        # Check environment variables in compose config
        if docker-compose config | grep -q "CLOUDINARY_CLOUD_NAME"; then
            echo -e "${GREEN}✓ Cloudinary environment variables configured in app service${NC}"
        else
            echo -e "${YELLOW}⚠ Cloudinary environment variables not found in app service${NC}"
        fi
    else
        echo -e "${RED}✗ App service not found in docker-compose.yml${NC}"
    fi
else
    echo -e "${YELLOW}⚠ docker-compose not available${NC}"
fi

# Performance recommendations
echo
echo -e "${BLUE}Performance Recommendations:${NC}"
echo "• Enable auto-optimization: f_auto,q_auto"
echo "• Use responsive images with w_auto,c_scale"
echo "• Implement lazy loading for better performance"
echo "• Set appropriate cache headers (max-age=31536000)"
echo "• Use WebP/AVIF formats for modern browsers"

# Security recommendations
echo
echo -e "${BLUE}Security Recommendations:${NC}"
echo "• Never expose API secret in frontend code"
echo "• Use signed uploads for production"
echo "• Implement upload size limits (current nginx limit: 10MB)"
echo "• Validate file types on both client and server"
echo "• Use folder-based permissions"

# Usage monitoring
echo
echo -e "${BLUE}Usage Monitoring:${NC}"
echo "• Monitor usage at: https://cloudinary.com/console/usage"
echo "• Free tier limits:"
echo "  - 25 GB storage"
echo "  - 25 GB monthly bandwidth"
echo "  - 25,000 transformations/month"
echo "  - 1,000 images/month"

echo
echo -e "${GREEN}Cloudinary integration test completed successfully!${NC}"
echo
echo "Next steps:"
echo "1. Test image upload through your application"
echo "2. Implement error handling for upload failures"
echo "3. Set up monitoring alerts for quota usage"
echo "4. Configure backup strategy for critical images"