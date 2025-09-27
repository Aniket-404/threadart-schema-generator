# ThreadArt Troubleshooting Guide

## Common Infrastructure Issues

### Docker and Container Issues

#### Docker Daemon Not Running
**Symptoms:** `Cannot connect to the Docker daemon` error

**Linux/macOS Fix:**
```bash
# Start Docker daemon
sudo systemctl start docker

# Enable auto-start on boot
sudo systemctl enable docker
```

**Windows Fix:**
```bash
# Start Docker Desktop
# Check Windows Services for Docker Desktop Service
```

#### Port Already in Use
**Symptoms:** `Port 3000 is already allocated` or similar

**Diagnosis:**
```bash
# Find what's using the port
netstat -tulpn | grep :3000     # Linux/macOS
netstat -ano | findstr :3000    # Windows
```

**Fix:**
```bash
# Kill the conflicting process
sudo kill -9 <PID>              # Linux/macOS
taskkill /PID <PID> /F          # Windows

# OR change ports in docker-compose.yml
```

#### Out of Disk Space
**Symptoms:** `No space left on device`

**Diagnosis:**
```bash
# Check disk usage
df -h                           # Linux/macOS
dir c:\ /s                      # Windows

# Check Docker disk usage
docker system df
```

**Fix:**
```bash
# Clean up Docker resources
docker system prune -a
docker volume prune

# Remove old images
docker image prune -a
```

### Database Issues

#### PostgreSQL Won't Start
**Symptoms:** Database connection refused or timeout

**Diagnosis:**
```bash
# Check PostgreSQL container status
docker-compose logs postgres

# Check if container is running
docker-compose ps postgres
```

**Common Fixes:**
```bash
# Restart PostgreSQL container
docker-compose restart postgres

# Check data directory permissions
ls -la ./data/postgres/

# Reset database (CAUTION: Data loss)
docker-compose down
docker volume rm threadart_postgres_data
docker-compose up -d postgres
```

#### PostgreSQL Connection Errors
**Symptoms:** `FATAL: password authentication failed`

**Fix:**
```bash
# Verify environment variables
docker-compose exec postgres env | grep POSTGRES

# Check .env.production file
cat .env.production | grep POSTGRES

# Recreate with correct credentials
docker-compose down
docker volume rm threadart_postgres_data
# Fix .env.production
docker-compose up -d postgres
```

#### Database Performance Issues
**Symptoms:** Slow queries, connection timeouts

**Diagnosis:**
```bash
# Check database connections
docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "SELECT * FROM pg_stat_activity;"

# Check slow queries
docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
```

### Redis Issues

#### Redis Won't Start
**Symptoms:** `Could not connect to Redis`

**Diagnosis:**
```bash
# Check Redis logs
docker-compose logs redis

# Test Redis connection
docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" ping
```

**Fix:**
```bash
# Restart Redis
docker-compose restart redis

# Check Redis configuration
docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" CONFIG GET "*"
```

#### Redis Memory Issues
**Symptoms:** Out of memory errors

**Diagnosis:**
```bash
# Check Redis memory usage
docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" INFO memory
```

**Fix:**
```bash
# Clear Redis cache (CAUTION: Cache loss)
docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" FLUSHALL

# Increase memory limit in docker-compose.yml
```

### Application Issues

#### Application Won't Start
**Symptoms:** Container exits immediately or crashes

**Diagnosis:**
```bash
# Check application logs
docker-compose logs app

# Check environment variables
docker-compose exec app env
```

**Common Fixes:**
```bash
# Rebuild application container
docker-compose build app
docker-compose up -d app

# Check Node.js version compatibility
docker-compose exec app node --version

# Verify package.json dependencies
docker-compose exec app npm list
```

#### API Endpoints Not Responding
**Symptoms:** 404 or 500 errors on API calls

**Diagnosis:**
```bash
# Check API health endpoint
curl http://localhost:3000/api/health

# Check application logs for errors
docker-compose logs -f app

# Test database connectivity from app
docker-compose exec app node -e "console.log('DB test')"
```

### Networking Issues

#### Services Can't Communicate
**Symptoms:** Connection refused between containers

**Diagnosis:**
```bash
# Check Docker network
docker network ls
docker network inspect threadart_default

# Test connectivity between containers
docker-compose exec app ping postgres
docker-compose exec app ping redis
```

**Fix:**
```bash
# Recreate network
docker-compose down
docker-compose up -d

# Check service names in docker-compose.yml
# Use service names (not localhost) for internal communication
```

#### Nginx Proxy Issues
**Symptoms:** 502 Bad Gateway or SSL errors

**Diagnosis:**
```bash
# Check Nginx logs
docker-compose logs nginx

# Test backend connectivity from Nginx
docker-compose exec nginx curl app:3000/health
```

**Fix:**
```bash
# Reload Nginx configuration
docker-compose exec nginx nginx -s reload

# Check Nginx configuration syntax
docker-compose exec nginx nginx -t

# Restart Nginx
docker-compose restart nginx
```

### Monitoring Issues

#### Prometheus Not Collecting Metrics
**Symptoms:** Empty dashboards, no data in Prometheus

**Diagnosis:**
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Prometheus logs
docker-compose logs prometheus
```

**Fix:**
```bash
# Verify prometheus.yml configuration
docker-compose exec prometheus cat /etc/prometheus/prometheus.yml

# Restart Prometheus
docker-compose restart prometheus
```

#### Grafana Login Issues
**Symptoms:** Cannot access Grafana dashboard

**Fix:**
```bash
# Reset Grafana admin password
docker-compose exec grafana grafana-cli admin reset-admin-password newpassword

# Check Grafana logs
docker-compose logs grafana
```

### Backup Issues

#### Backup Scripts Fail
**Symptoms:** Backup files not created or corrupted

**Diagnosis:**
```bash
# Test backup script manually
./scripts/backup/postgres-backup.sh

# Check backup directory permissions
ls -la ./backups/

# Verify database connectivity
docker exec threadart-postgres pg_dump --version
```

**Fix:**
```bash
# Fix backup directory permissions
sudo chown -R $(whoami):$(whoami) ./backups/

# Test database access
docker exec threadart-postgres pg_isready -U threadart_user
```

#### Restore Fails
**Symptoms:** Cannot restore from backup

**Diagnosis:**
```bash
# Verify backup file integrity
gunzip -t backup_file.sql.gz

# Check PostgreSQL version compatibility
docker exec threadart-postgres psql --version
```

## Performance Troubleshooting

### High Memory Usage
**Diagnosis:**
```bash
# Check container memory usage
docker stats

# Check system memory
free -h                         # Linux
wmic OS get TotalVisibleMemorySize,FreePhysicalMemory    # Windows
```

**Fix:**
```bash
# Limit container memory in docker-compose.yml
services:
  postgres:
    mem_limit: 1g
    
# Optimize PostgreSQL settings
# Edit postgresql.conf for shared_buffers, work_mem
```

### High CPU Usage
**Diagnosis:**
```bash
# Check container CPU usage
docker stats

# Check system load
top                             # Linux/macOS
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10    # Windows PowerShell
```

### Slow Application Response
**Diagnosis:**
```bash
# Check database query performance
docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 5;"

# Check Redis performance
docker exec threadart-redis redis-cli -a "${REDIS_PASSWORD}" --latency
```

## Recovery Procedures

### Complete System Recovery
**When everything is broken:**

1. **Stop all services:**
```bash
docker-compose down
```

2. **Clean up Docker resources:**
```bash
docker system prune -a
docker volume prune
```

3. **Restore from backup (if available):**
```bash
# Restore database
./scripts/backup/postgres-restore.sh latest_backup.sql.gz
./scripts/backup/redis-restore.sh latest_backup.rdb.gz
```

4. **Restart with fresh configuration:**
```bash
docker-compose up -d
```

### Data Recovery from Corrupted Volume
```bash
# Stop services
docker-compose down

# Create temporary container to access data
docker run --rm -v threadart_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_recovery.tar.gz /data

# Remove corrupted volume
docker volume rm threadart_postgres_data

# Restore from backup or manual recovery
```

## Getting Help

### Collecting Debug Information
When seeking help, collect this information:

```bash
# System information
uname -a                        # Linux/macOS
systeminfo                      # Windows

# Docker information
docker version
docker-compose version
docker info

# Container status
docker-compose ps
docker-compose logs --tail=50

# Resource usage
docker stats --no-stream
df -h                           # Disk usage
```

### Log Collection
```bash
# Collect all logs
mkdir debug_logs
docker-compose logs > debug_logs/all_services.log
docker-compose logs postgres > debug_logs/postgres.log
docker-compose logs redis > debug_logs/redis.log
docker-compose logs app > debug_logs/app.log
```

Save these logs when reporting issues to the development team.

---

**Need immediate help?** Run the validation script to get an overview of system health:
```bash
./scripts/validate-infrastructure.sh        # Linux/macOS
scripts\validate-infrastructure.bat        # Windows
```