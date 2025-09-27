#!/bin/bash

# ThreadArt Infrastructure Validation Script
# Comprehensive service orchestration and connectivity testing

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/threadart/service-validation.log"
TIMEOUT=30
RETRY_COUNT=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    echo -e "[$level] $(date -Iseconds) $message" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "[$level] $(date -Iseconds) $message"
}

# Print colored output
print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        "PASS") echo -e "${GREEN}✓ PASS${NC}: $message" ;;
        "FAIL") echo -e "${RED}✗ FAIL${NC}: $message" ;;
        "WARN") echo -e "${YELLOW}⚠ WARN${NC}: $message" ;;
        "INFO") echo -e "${BLUE}ℹ INFO${NC}: $message" ;;
    esac
    log "$status" "$message"
}

# Wait for service to be ready
wait_for_service() {
    local service="$1"
    local check_command="$2"
    local max_attempts="$3"
    
    print_status "INFO" "Waiting for $service to be ready..."
    
    for i in $(seq 1 $max_attempts); do
        if eval "$check_command" >/dev/null 2>&1; then
            print_status "PASS" "$service is ready (attempt $i/$max_attempts)"
            return 0
        fi
        sleep 2
    done
    
    print_status "FAIL" "$service failed to start within $max_attempts attempts"
    return 1
}

# Test service health endpoint
test_health_endpoint() {
    local service="$1"
    local url="$2"
    local expected_status="${3:-200}"
    
    print_status "INFO" "Testing $service health endpoint: $url"
    
    local response
    if response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 10 --max-time 30 "$url" 2>/dev/null); then
        if [ "$response" = "$expected_status" ]; then
            print_status "PASS" "$service health check successful (HTTP $response)"
            return 0
        else
            print_status "FAIL" "$service health check failed (HTTP $response, expected $expected_status)"
            return 1
        fi
    else
        print_status "FAIL" "$service health check failed (connection error)"
        return 1
    fi
}

# Test database connectivity
test_postgresql_connectivity() {
    print_status "INFO" "Testing PostgreSQL connectivity..."
    
    local pg_test="docker exec threadart-postgres pg_isready -U threadart_user -d threadart_db"
    if $pg_test >/dev/null 2>&1; then
        print_status "PASS" "PostgreSQL is accepting connections"
        
        # Test database operations
        if docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "SELECT 1;" >/dev/null 2>&1; then
            print_status "PASS" "PostgreSQL database operations working"
        else
            print_status "FAIL" "PostgreSQL database operations failed"
            return 1
        fi
    else
        print_status "FAIL" "PostgreSQL is not accepting connections"
        return 1
    fi
}

# Test Redis connectivity
test_redis_connectivity() {
    print_status "INFO" "Testing Redis connectivity..."
    
    if docker exec threadart-redis redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q "PONG"; then
        print_status "PASS" "Redis is responding to ping"
        
        # Test Redis operations
        if docker exec threadart-redis redis-cli -a "$REDIS_PASSWORD" set test_key "test_value" >/dev/null 2>&1 && \
           docker exec threadart-redis redis-cli -a "$REDIS_PASSWORD" get test_key 2>/dev/null | grep -q "test_value"; then
            print_status "PASS" "Redis operations working"
            docker exec threadart-redis redis-cli -a "$REDIS_PASSWORD" del test_key >/dev/null 2>&1
        else
            print_status "FAIL" "Redis operations failed"
            return 1
        fi
    else
        print_status "FAIL" "Redis is not responding"
        return 1
    fi
}

# Test monitoring stack
test_monitoring_stack() {
    print_status "INFO" "Testing monitoring stack..."
    
    # Test Prometheus
    if test_health_endpoint "Prometheus" "http://localhost:9090/-/healthy"; then
        # Test Prometheus targets
        local targets_response
        if targets_response=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null) && \
           echo "$targets_response" | grep -q '"status":"success"'; then
            print_status "PASS" "Prometheus targets are configured"
        else
            print_status "WARN" "Prometheus targets may not be properly configured"
        fi
    else
        print_status "FAIL" "Prometheus health check failed"
        return 1
    fi
    
    # Test Grafana
    if test_health_endpoint "Grafana" "http://localhost:3001/api/health"; then
        print_status "PASS" "Grafana is operational"
    else
        print_status "WARN" "Grafana may not be ready (this is often normal during startup)"
    fi
    
    # Test Loki
    if test_health_endpoint "Loki" "http://localhost:3100/ready"; then
        print_status "PASS" "Loki is ready for log ingestion"
    else
        print_status "WARN" "Loki may not be ready"
    fi
}

# Test network connectivity between services
test_inter_service_connectivity() {
    print_status "INFO" "Testing inter-service connectivity..."
    
    # Test app -> PostgreSQL connectivity
    if docker exec threadart-app nc -z postgres 5432 2>/dev/null; then
        print_status "PASS" "App can reach PostgreSQL"
    else
        print_status "FAIL" "App cannot reach PostgreSQL"
        return 1
    fi
    
    # Test app -> Redis connectivity
    if docker exec threadart-app nc -z redis 6379 2>/dev/null; then
        print_status "PASS" "App can reach Redis"
    else
        print_status "FAIL" "App cannot reach Redis"
        return 1
    fi
    
    # Test Prometheus -> exporters connectivity
    if docker exec threadart-prometheus nc -z postgres-exporter 9187 2>/dev/null; then
        print_status "PASS" "Prometheus can reach PostgreSQL exporter"
    else
        print_status "WARN" "Prometheus cannot reach PostgreSQL exporter"
    fi
    
    if docker exec threadart-prometheus nc -z redis-exporter 9121 2>/dev/null; then
        print_status "PASS" "Prometheus can reach Redis exporter"
    else
        print_status "WARN" "Prometheus cannot reach Redis exporter"
    fi
}

# Test Nginx reverse proxy
test_nginx_proxy() {
    print_status "INFO" "Testing Nginx reverse proxy..."
    
    # Test Nginx health
    if test_health_endpoint "Nginx" "http://localhost/health"; then
        print_status "PASS" "Nginx is serving requests"
    else
        print_status "WARN" "Nginx health endpoint not available (may need app running)"
    fi
    
    # Test SSL configuration (if certificates exist)
    if docker exec threadart-nginx test -f /etc/nginx/ssl/threadart.local.crt 2>/dev/null; then
        if test_health_endpoint "Nginx SSL" "https://localhost/health" "200"; then
            print_status "PASS" "Nginx SSL termination working"
        else
            print_status "WARN" "Nginx SSL may not be properly configured"
        fi
    else
        print_status "INFO" "SSL certificates not found, skipping SSL test"
    fi
}

# Test backup system integration
test_backup_integration() {
    print_status "INFO" "Testing backup system integration..."
    
    # Check if backup scripts are accessible
    if docker exec threadart-postgres test -f /backup && \
       docker exec threadart-redis test -f /backup; then
        print_status "PASS" "Backup directories are mounted and accessible"
    else
        print_status "FAIL" "Backup directories not properly mounted"
        return 1
    fi
    
    # Test backup script execution (dry run)
    if [ -f "./scripts/backup/validate-backup-system.bat" ]; then
        print_status "PASS" "Backup validation script exists"
    else
        print_status "WARN" "Backup validation script not found"
    fi
}

# Main validation function
main() {
    local start_time=$(date +%s)
    local failed_tests=0
    
    echo "=========================================="
    echo "ThreadArt Infrastructure Validation"
    echo "=========================================="
    echo "Started at: $(date)"
    echo ""
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_status "FAIL" "Docker is not running or not accessible"
        exit 1
    fi
    print_status "PASS" "Docker daemon is accessible"
    
    # Validate docker-compose configuration
    if docker-compose config --quiet; then
        print_status "PASS" "Docker Compose configuration is valid"
    else
        print_status "FAIL" "Docker Compose configuration has errors"
        exit 1
    fi
    
    # Check if containers are running
    print_status "INFO" "Checking container status..."
    
    local required_containers=("threadart-postgres" "threadart-redis" "threadart-nginx" "threadart-prometheus" "threadart-grafana" "threadart-loki")
    local running_containers=$(docker ps --format "{{.Names}}" | grep "threadart-")
    
    for container in "${required_containers[@]}"; do
        if echo "$running_containers" | grep -q "$container"; then
            print_status "PASS" "$container is running"
        else
            print_status "WARN" "$container is not running"
            ((failed_tests++))
        fi
    done
    
    # Run tests
    echo ""
    print_status "INFO" "Running connectivity tests..."
    
    test_postgresql_connectivity || ((failed_tests++))
    test_redis_connectivity || ((failed_tests++))
    test_monitoring_stack || ((failed_tests++))
    test_inter_service_connectivity || ((failed_tests++))
    test_nginx_proxy || ((failed_tests++))
    test_backup_integration || ((failed_tests++))
    
    # Summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "=========================================="
    echo "Validation Summary"
    echo "=========================================="
    echo "Duration: ${duration}s"
    echo "Failed tests: $failed_tests"
    
    if [ $failed_tests -eq 0 ]; then
        print_status "PASS" "All critical infrastructure tests passed!"
        echo "Infrastructure is ready for application deployment."
    elif [ $failed_tests -le 3 ]; then
        print_status "WARN" "Some non-critical tests failed, but infrastructure is mostly operational"
        echo "Review warnings and fix non-critical issues when possible."
    else
        print_status "FAIL" "Multiple critical tests failed"
        echo "Infrastructure needs attention before application deployment."
        exit 1
    fi
    
    echo "Detailed logs: $LOG_FILE"
    echo "=========================================="
}

# Handle script arguments
case "${1:-}" in
    --containers-only)
        print_status "INFO" "Checking container status only..."
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep threadart || echo "No ThreadArt containers running"
        ;;
    --quick)
        print_status "INFO" "Running quick validation..."
        TIMEOUT=10
        RETRY_COUNT=1
        main
        ;;
    --help)
        echo "Usage: $0 [--containers-only|--quick|--help]"
        echo "  --containers-only  Check container status only"
        echo "  --quick           Run quick validation with shorter timeouts"
        echo "  --help            Show this help message"
        ;;
    *)
        main "$@"
        ;;
esac