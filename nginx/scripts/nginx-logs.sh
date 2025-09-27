#!/bin/bash

# ThreadArt Generator - Nginx Log Management
# View, filter, and manage Nginx logs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
LINES=50
FOLLOW=false
LOG_TYPE="both"

show_help() {
    echo -e "${GREEN}ThreadArt Generator - Nginx Log Viewer${NC}"
    echo "====================================="
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -t, --type TYPE     Log type: access, error, or both (default: both)"
    echo "  -n, --lines LINES   Number of lines to show (default: 50)"
    echo "  -f, --follow        Follow log output (like tail -f)"
    echo "  -s, --stats         Show log statistics"
    echo "  -e, --errors        Show only error logs from last hour"
    echo "  -4, --4xx           Show 4xx HTTP errors from access log"
    echo "  -5, --5xx           Show 5xx HTTP errors from access log"
    echo "  --clear             Clear log files (requires confirmation)"
    echo "  -h, --help          Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -f                    # Follow both access and error logs"
    echo "  $0 -t access -n 100     # Show last 100 access log entries"
    echo "  $0 --4xx                # Show recent 4xx errors"
    echo "  $0 --stats              # Show log statistics"
}

show_stats() {
    echo -e "${GREEN}Nginx Log Statistics${NC}"
    echo "==================="
    echo
    
    # Access log stats
    echo -e "${BLUE}Access Log Statistics:${NC}"
    if docker-compose exec nginx test -f /var/log/nginx/access.log; then
        echo "Total requests today:"
        docker-compose exec nginx grep "$(date '+%d/%b/%Y')" /var/log/nginx/access.log | wc -l
        
        echo
        echo "Top 10 IP addresses:"
        docker-compose exec nginx awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head -10
        
        echo
        echo "Top 10 requested URLs:"
        docker-compose exec nginx awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head -10
        
        echo
        echo "HTTP Status Code distribution:"
        docker-compose exec nginx awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -nr
        
        echo
        echo "Response times (95th percentile):"
        docker-compose exec nginx awk '{print $NF}' /var/log/nginx/access.log | grep -E '^[0-9]' | sort -n | tail -n +$(echo "$(wc -l < /var/log/nginx/access.log) * 0.95" | bc | cut -d. -f1) | head -1
    else
        echo "Access log not found"
    fi
    
    echo
    echo -e "${BLUE}Error Log Statistics:${NC}"
    if docker-compose exec nginx test -f /var/log/nginx/error.log; then
        echo "Total errors today:"
        docker-compose exec nginx grep "$(date '+%Y/%m/%d')" /var/log/nginx/error.log | wc -l
        
        echo
        echo "Error levels:"
        docker-compose exec nginx grep "$(date '+%Y/%m/%d')" /var/log/nginx/error.log | awk '{print $4}' | sed 's/\[//g' | sort | uniq -c | sort -nr
    else
        echo "Error log not found"
    fi
}

show_4xx_errors() {
    echo -e "${YELLOW}4xx Client Errors (Last Hour)${NC}"
    echo "============================="
    docker-compose exec nginx grep "$(date '+%d/%b/%Y:%H' -d '1 hour ago')\|$(date '+%d/%b/%Y:%H')" /var/log/nginx/access.log | grep ' 4[0-9][0-9] ' | tail -n $LINES
}

show_5xx_errors() {
    echo -e "${RED}5xx Server Errors (Last Hour)${NC}"
    echo "============================="
    docker-compose exec nginx grep "$(date '+%d/%b/%Y:%H' -d '1 hour ago')\|$(date '+%d/%b/%Y:%H')" /var/log/nginx/access.log | grep ' 5[0-9][0-9] ' | tail -n $LINES
}

show_recent_errors() {
    echo -e "${RED}Error Log (Last Hour)${NC}"
    echo "===================="
    docker-compose exec nginx grep "$(date '+%Y/%m/%d %H' -d '1 hour ago')\|$(date '+%Y/%m/%d %H')" /var/log/nginx/error.log | tail -n $LINES
}

clear_logs() {
    echo -e "${YELLOW}Warning: This will clear all Nginx log files${NC}"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Clearing log files..."
        docker-compose exec nginx truncate -s 0 /var/log/nginx/access.log
        docker-compose exec nginx truncate -s 0 /var/log/nginx/error.log
        echo -e "${GREEN}✓ Log files cleared${NC}"
    else
        echo "Operation cancelled"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            LOG_TYPE="$2"
            shift 2
            ;;
        -n|--lines)
            LINES="$2"
            shift 2
            ;;
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -s|--stats)
            show_stats
            exit 0
            ;;
        -e|--errors)
            show_recent_errors
            exit 0
            ;;
        -4|--4xx)
            show_4xx_errors
            exit 0
            ;;
        -5|--5xx)
            show_5xx_errors
            exit 0
            ;;
        --clear)
            clear_logs
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose not found${NC}"
    exit 1
fi

# Check if nginx container is running
if ! docker-compose ps nginx | grep -q "Up"; then
    echo -e "${RED}Error: Nginx container is not running${NC}"
    exit 1
fi

echo -e "${GREEN}Nginx Logs${NC}"
echo "=========="
echo

# Show logs based on type
if [ "$FOLLOW" = "true" ]; then
    case $LOG_TYPE in
        "access")
            echo -e "${BLUE}Following access log...${NC}"
            docker-compose logs -f --tail=$LINES nginx | grep -E "(access|GET|POST|PUT|DELETE)"
            ;;
        "error")
            echo -e "${RED}Following error log...${NC}"
            docker-compose logs -f --tail=$LINES nginx | grep -E "(error|ERROR|warning|WARNING)"
            ;;
        "both"|*)
            echo -e "${BLUE}Following all logs...${NC}"
            docker-compose logs -f --tail=$LINES nginx
            ;;
    esac
else
    case $LOG_TYPE in
        "access")
            echo -e "${BLUE}Access Log (Last $LINES lines):${NC}"
            docker-compose exec nginx tail -n $LINES /var/log/nginx/access.log
            ;;
        "error")
            echo -e "${RED}Error Log (Last $LINES lines):${NC}"
            docker-compose exec nginx tail -n $LINES /var/log/nginx/error.log
            ;;
        "both"|*)
            echo -e "${BLUE}Access Log (Last $LINES lines):${NC}"
            docker-compose exec nginx tail -n $LINES /var/log/nginx/access.log
            echo
            echo -e "${RED}Error Log (Last $LINES lines):${NC}"
            docker-compose exec nginx tail -n $LINES /var/log/nginx/error.log
            ;;
    esac
fi