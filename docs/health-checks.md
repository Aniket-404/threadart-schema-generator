# ThreadArt Health Check Reference

This document provides a comprehensive reference for all health check endpoints and monitoring procedures in the ThreadArt infrastructure.

## Service Health Endpoints

### Core Application Services

#### Frontend (Next.js)
```bash
# Health Check
GET http://localhost:3000/health

# Expected Response
Status: 200 OK
Content-Type: application/json

{
  "status": "healthy",
  "service": "threadart-frontend",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "uptime": "1h 30m 45s",
  "version": "1.0.0"
}

# Validation Command
curl -f http://localhost:3000/health || echo "Frontend unhealthy"
```

#### Backend API (Fastify)
```bash
# Health Check
GET http://localhost:3000/api/health

# Expected Response
Status: 200 OK
Content-Type: application/json

{
  "status": "healthy",
  "service": "threadart-api",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "database": "connected",
  "redis": "connected",
  "cloudinary": "connected",
  "uptime": "1h 30m 45s",
  "version": "1.0.0"
}

# Validation Command
curl -f http://localhost:3000/api/health || echo "API unhealthy"
```

#### Detailed API Health (Extended)
```bash
# Detailed Health Check
GET http://localhost:3000/api/health/detailed

# Expected Response
{
  "status": "healthy",
  "services": {
    "database": {
      "status": "healthy",
      "responseTime": "15ms",
      "connections": {
        "active": 5,
        "idle": 10,
        "total": 15
      }
    },
    "redis": {
      "status": "healthy",
      "responseTime": "2ms",
      "memory": {
        "used": "128MB",
        "peak": "256MB"
      }
    },
    "cloudinary": {
      "status": "healthy",
      "responseTime": "150ms",
      "lastSync": "2024-01-01T00:00:00.000Z"
    }
  }
}
```

### Database Services

#### PostgreSQL
```bash
# Simple Health Check
docker exec threadart-postgres pg_isready -U threadart_user -d threadart_db

# Expected Output
/var/lib/postgresql/data:5432 - accepting connections

# Detailed Connection Test
docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "SELECT version();"

# Performance Check
docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "
SELECT 
  datname,
  numbackends as active_connections,
  xact_commit as transactions_committed,
  xact_rollback as transactions_rolled_back,
  blks_read + blks_hit as total_buffer_reads,
  temp_files,
  temp_bytes
FROM pg_stat_database 
WHERE datname = 'threadart_db';"
```

#### Redis  
```bash
# Simple Health Check
docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" ping

# Expected Output
PONG

# Detailed Info
docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" info server

# Memory Usage
docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" info memory

# Key Statistics
docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" info keyspace

# Performance Test
docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" --latency -i 1
```

### Monitoring Services

#### Prometheus
```bash
# Health Check
GET http://localhost:9090/-/healthy

# Expected Response
Status: 200 OK
Content: Prometheus is Healthy.

# Readiness Check
GET http://localhost:9090/-/ready

# Targets Status
GET http://localhost:9090/api/v1/targets

# Validation Commands
curl -f http://localhost:9090/-/healthy || echo "Prometheus unhealthy"
curl -f http://localhost:9090/-/ready || echo "Prometheus not ready"
```

#### Grafana
```bash
# Health Check
GET http://localhost:3001/api/health

# Expected Response
Status: 200 OK
Content-Type: application/json

{
  "commit": "abc123",
  "database": "ok", 
  "version": "8.5.0"
}

# Login Status (requires authentication)
GET http://localhost:3001/api/user

# Validation Command
curl -f http://localhost:3001/api/health || echo "Grafana unhealthy"
```

#### Loki
```bash
# Readiness Check
GET http://localhost:3100/ready

# Expected Response
Status: 200 OK
Content: ready

# Metrics Endpoint
GET http://localhost:3100/metrics

# Service Status
GET http://localhost:3100/services

# Validation Command
curl -f http://localhost:3100/ready || echo "Loki not ready"
```

### Reverse Proxy

#### Nginx
```bash
# Nginx Status (if configured)
GET http://localhost/nginx_status

# Expected Response
Active connections: 1 
server accepts handled requests
 123 123 456
Reading: 0 Writing: 1 Waiting: 0

# Application Health through Proxy
GET http://localhost/health

# SSL Certificate Check (production)
openssl s_client -connect your-domain.com:443 -servername your-domain.com < /dev/null 2>/dev/null | openssl x509 -noout -dates

# Validation Commands
curl -f http://localhost/health || echo "Nginx proxy unhealthy"
nginx -t  # Configuration syntax check
```

## Automated Health Check Scripts

### Comprehensive Validation Script
```bash
# Unix/Linux
./scripts/validate-infrastructure.sh

# Windows
scripts\validate-infrastructure.bat

# Expected Output Summary
==========================================
ThreadArt Infrastructure Validation
==========================================
[PASS] Docker daemon is accessible
[PASS] Docker Compose configuration is valid
[PASS] threadart-postgres is running
[PASS] threadart-redis is running
[PASS] threadart-nginx is running
[PASS] PostgreSQL is accepting connections
[PASS] Redis is responding to ping
[PASS] Prometheus is healthy
[PASS] Grafana is operational
[PASS] Infrastructure is ready for deployment
```

### Individual Service Tests

#### Database Connectivity Test
```bash
#!/bin/bash
# Test PostgreSQL connectivity and basic operations

echo "Testing PostgreSQL..."

# Connection test
if docker exec threadart-postgres pg_isready -U threadart_user -d threadart_db; then
    echo "✓ PostgreSQL connection: PASS"
else
    echo "✗ PostgreSQL connection: FAIL"
    exit 1
fi

# Write test
if docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "CREATE TEMP TABLE health_test (id INT);"; then
    echo "✓ PostgreSQL write operations: PASS"
else
    echo "✗ PostgreSQL write operations: FAIL"
    exit 1
fi

# Read test  
if docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "SELECT COUNT(*) FROM information_schema.tables;" > /dev/null; then
    echo "✓ PostgreSQL read operations: PASS"
else
    echo "✗ PostgreSQL read operations: FAIL"
    exit 1
fi
```

#### Redis Functionality Test
```bash
#!/bin/bash
# Test Redis connectivity and operations

echo "Testing Redis..."

# Connection test
if docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" ping | grep -q PONG; then
    echo "✓ Redis connection: PASS"
else
    echo "✗ Redis connection: FAIL"
    exit 1
fi

# Write/Read test
if docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" set health_test "OK" && \
   docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" get health_test | grep -q OK; then
    echo "✓ Redis operations: PASS"
    docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" del health_test > /dev/null
else
    echo "✗ Redis operations: FAIL"
    exit 1
fi
```

## Health Monitoring Integration

### Prometheus Health Checks
Add these checks to your Prometheus configuration (`prometheus.yml`):

```yaml
rule_files:
  - "health_rules.yml"

# health_rules.yml
groups:
  - name: threadart_health
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.instance }} is down"
          
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          
      - alert: PostgreSQLDown
        expr: pg_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL is down"
          
      - alert: RedisDown
        expr: redis_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Redis is down"
```

### Grafana Dashboard Queries

#### Application Health Panel
```sql
-- Service Uptime
up{job="threadart-app"}

-- Response Time
http_request_duration_seconds_bucket{job="threadart-app"}

-- Error Rate  
rate(http_requests_total{job="threadart-app",status=~"5.."}[5m]) / rate(http_requests_total{job="threadart-app"}[5m])
```

#### Database Health Panel
```sql
-- PostgreSQL Connections
pg_stat_database_numbackends{datname="threadart_db"}

-- Query Performance
rate(pg_stat_statements_total_time[5m]) / rate(pg_stat_statements_calls[5m])

-- Redis Memory Usage
redis_memory_used_bytes / redis_memory_max_bytes
```

## Continuous Health Monitoring

### Automated Health Check Cron Job
```bash
# Add to crontab for automated health monitoring
# Check every 5 minutes
*/5 * * * * /path/to/threadart/scripts/validate-infrastructure.sh --quiet >> /var/log/threadart-health.log 2>&1

# Daily comprehensive check
0 6 * * * /path/to/threadart/scripts/validate-infrastructure.sh --detailed >> /var/log/threadart-daily-health.log 2>&1
```

### Health Check API Integration
Example integration with external monitoring service:

```bash
#!/bin/bash
# External health reporting

HEALTH_ENDPOINT="https://monitoring-service.com/api/health"
API_KEY="your-api-key"

# Run health check and capture results
HEALTH_RESULT=$(./scripts/validate-infrastructure.sh --json)

# Report to external service
curl -X POST "$HEALTH_ENDPOINT" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$HEALTH_RESULT"
```

## Health Check Troubleshooting

### Common Health Check Failures

#### Service Not Responding
```bash
# Check if service is running
docker-compose ps [service_name]

# Check service logs
docker-compose logs [service_name]

# Restart service
docker-compose restart [service_name]
```

#### Network Connectivity Issues
```bash
# Test internal network connectivity
docker-compose exec app ping postgres
docker-compose exec app ping redis

# Check Docker network
docker network inspect threadart_default
```

#### Resource Constraints
```bash
# Check resource usage
docker stats --no-stream

# Check disk space
df -h

# Check memory usage
free -h
```

---

**For troubleshooting health check failures, see [troubleshooting.md](troubleshooting.md)**