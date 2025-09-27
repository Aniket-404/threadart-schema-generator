# ThreadArt Infrastructure Setup Guide

## Table of Contents
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Environment Configuration](#environment-configuration)
- [Service Management](#service-management)
- [Health Check Endpoints](#health-check-endpoints)
- [Monitoring and Logging](#monitoring-and-logging)
- [Backup and Restore](#backup-and-restore)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

## Prerequisites

### System Requirements
- **Docker**: Version 20.10+ with Docker Compose v2
- **Operating System**: Linux (Ubuntu 20.04+), macOS (10.15+), or Windows 10/11 with WSL2
- **Hardware**: Minimum 4GB RAM, 20GB disk space, 2 CPU cores
- **Network**: Ports 80, 443, 3000, 3001, 3100, 5432, 6379, 9090 available

### Required Tools
- Git for version control
- Text editor for configuration files
- curl or wget for health checks
- Optional: pgAdmin for PostgreSQL management

## Initial Setup

### 1. Clone and Configure Project
```bash
git clone <repository-url> threadart
cd threadart

# Copy environment template
cp .env.example .env.production
```

### 2. Environment Configuration
Edit `.env.production` with your specific settings:

```bash
# Database Configuration
POSTGRES_DB=threadart_db
POSTGRES_USER=threadart_user
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# Redis Configuration  
REDIS_PASSWORD=your_redis_password_here
REDIS_HOST=redis
REDIS_PORT=6379

# Application Configuration
NODE_ENV=production
JWT_SECRET=your_jwt_secret_here
API_BASE_URL=http://localhost:3000

# Cloudinary Configuration
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# Monitoring Configuration
PROMETHEUS_RETENTION_TIME=15d
GRAFANA_ADMIN_PASSWORD=your_grafana_password

# SSL Configuration (for production)
SSL_CERT_PATH=/etc/ssl/certs/threadart.crt
SSL_KEY_PATH=/etc/ssl/private/threadart.key

# Backup Configuration
BACKUP_RETENTION_DAYS=30
BACKUP_SCHEDULE="0 2 * * *"  # Daily at 2 AM
```

### 3. SSL Certificate Setup (Production)
For production deployments, place SSL certificates:
```bash
# Create SSL directory
sudo mkdir -p /etc/ssl/certs /etc/ssl/private

# Copy your certificates
sudo cp your-cert.crt /etc/ssl/certs/threadart.crt
sudo cp your-key.key /etc/ssl/private/threadart.key

# Set proper permissions
sudo chmod 644 /etc/ssl/certs/threadart.crt
sudo chmod 600 /etc/ssl/private/threadart.key
```

## Service Management

### Starting Services
```bash
# Start all services
docker-compose up -d

# Start specific services
docker-compose up -d postgres redis

# View startup logs
docker-compose logs -f
```

### Stopping Services
```bash
# Stop all services
docker-compose down

# Stop and remove volumes (CAUTION: Data loss)
docker-compose down -v
```

### Updating Services
```bash
# Pull latest images
docker-compose pull

# Recreate containers with new images
docker-compose up -d --force-recreate
```

### Service Status
```bash
# Check all container status
docker-compose ps

# View resource usage
docker stats

# Check specific service logs
docker-compose logs -f [service_name]
```

## Health Check Endpoints

### Application Services
| Service | Health Endpoint | Expected Response |
|---------|----------------|-------------------|
| **Frontend** | `http://localhost:3000/health` | `200 OK` |
| **Backend API** | `http://localhost:3000/api/health` | `200 OK` |
| **PostgreSQL** | `docker exec threadart-postgres pg_isready` | `accepting connections` |
| **Redis** | `docker exec threadart-redis redis-cli ping` | `PONG` |

### Monitoring Stack
| Service | Endpoint | Purpose |
|---------|----------|---------|
| **Prometheus** | `http://localhost:9090/-/healthy` | Metrics collection status |
| **Grafana** | `http://localhost:3001/api/health` | Dashboard availability |
| **Loki** | `http://localhost:3100/ready` | Log ingestion readiness |

### Nginx Reverse Proxy
| Endpoint | Purpose |
|----------|---------|
| `http://localhost/health` | Overall application health |
| `http://localhost/api/health` | API health through proxy |

### Health Check Scripts
Run comprehensive validation:
```bash
# Unix/Linux systems
./scripts/validate-infrastructure.sh

# Windows systems  
scripts\validate-infrastructure.bat
```

## Monitoring and Logging

### Accessing Dashboards
- **Grafana**: http://localhost:3001
  - Username: `admin`
  - Password: Set in `GRAFANA_ADMIN_PASSWORD`
  
- **Prometheus**: http://localhost:9090
  - Direct access to metrics and targets

### Key Metrics to Monitor
1. **Application Performance**
   - Response times and error rates
   - Active user sessions
   - API endpoint performance

2. **Infrastructure Health**
   - CPU and memory usage
   - Disk space and I/O
   - Network connectivity

3. **Database Performance**
   - Connection pool usage
   - Query execution times
   - Database size and growth

4. **Cache Performance**
   - Redis hit/miss ratios
   - Memory usage patterns
   - Key expiration rates

### Log Management
```bash
# View all service logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f [service_name]

# View logs with timestamps
docker-compose logs -f -t

# Limit log output
docker-compose logs --tail=100 -f
```

## Backup and Restore

### Automated Backups
Backups run automatically based on `BACKUP_SCHEDULE`:
```bash
# Check backup status
./scripts/backup/validate-backup-system.sh

# Manual backup execution
./scripts/backup/postgres-backup.sh
./scripts/backup/redis-backup.sh
```

### Backup Locations
- PostgreSQL: `./backups/postgres/`
- Redis: `./backups/redis/`
- Application data: `./backups/app/`

### Restore Procedures
```bash
# Restore PostgreSQL from backup
./scripts/backup/postgres-restore.sh backup_filename.sql.gz

# Restore Redis from backup  
./scripts/backup/redis-restore.sh backup_filename.rdb.gz

# Restore with verification
./scripts/backup/postgres-restore.sh backup_file.sql.gz --verify
```

### Backup Verification
```bash
# Test backup integrity
./scripts/backup/validate-backup-system.sh --test-restore

# Check backup retention policy
find ./backups -name "*.gz" -mtime +30 -ls
```

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check Docker daemon
sudo systemctl status docker

# Verify configuration
docker-compose config

# Check port conflicts
netstat -tulpn | grep :<port>

# Review service logs
docker-compose logs [service_name]
```

#### Database Connection Issues
```bash
# Test PostgreSQL connectivity
docker exec threadart-postgres pg_isready -U threadart_user

# Check database logs
docker-compose logs postgres

# Verify environment variables
docker-compose exec postgres env | grep POSTGRES
```

#### Performance Issues
```bash
# Check resource usage
docker stats

# Monitor disk space
df -h

# Check memory usage
free -h

# Review slow queries (PostgreSQL)
docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
```

#### Network Connectivity
```bash
# Test inter-service connectivity
docker-compose exec app ping postgres
docker-compose exec app ping redis

# Check Docker networks
docker network ls
docker network inspect threadart_default
```

### Diagnostic Commands
```bash
# Complete system status
./scripts/validate-infrastructure.sh

# Service dependency check
docker-compose ps
docker-compose top

# Configuration verification
docker-compose config --services
docker-compose config --volumes
```

### Log Analysis
```bash
# Search for errors in logs
docker-compose logs | grep -i error

# Monitor real-time errors
docker-compose logs -f | grep -i error

# Check application startup
docker-compose logs app | head -50
```

## Security Best Practices

### Environment Security
- Store sensitive credentials in `.env.production` only
- Never commit `.env` files to version control
- Use strong, unique passwords for all services
- Regularly rotate API keys and passwords

### Network Security
- Configure firewall rules for production deployment
- Use SSL/TLS certificates for all external connections
- Implement IP allowlisting for database access
- Monitor access logs for suspicious activity

### Container Security
- Keep Docker images updated with latest security patches
- Run containers with non-root users when possible
- Limit container capabilities and resources
- Scan images for vulnerabilities regularly

### Database Security
- Use dedicated database users with minimal privileges
- Enable PostgreSQL SSL connections in production
- Regular security updates and patches
- Implement connection pooling and rate limiting

### Monitoring Security
- Secure Grafana with strong authentication
- Use HTTPS for monitoring dashboard access
- Implement alerting for security events
- Regular security audit logs

### Backup Security
- Encrypt backup files at rest
- Secure backup storage locations
- Implement backup access controls
- Test backup restoration procedures regularly

## Production Deployment Checklist

### Pre-Deployment
- [ ] Environment variables configured and secured
- [ ] SSL certificates installed and verified
- [ ] Firewall rules configured
- [ ] DNS records configured
- [ ] Backup systems tested
- [ ] Monitoring dashboards configured

### Deployment Steps
1. [ ] Pull latest application code
2. [ ] Update environment configuration
3. [ ] Run infrastructure validation
4. [ ] Start services with docker-compose
5. [ ] Verify all health checks pass
6. [ ] Configure monitoring alerts
7. [ ] Test backup and restore procedures
8. [ ] Document deployment details

### Post-Deployment
- [ ] Monitor application performance
- [ ] Verify backup schedules active
- [ ] Test all critical functionality
- [ ] Update documentation
- [ ] Train team on operations procedures

---

For additional support or questions, refer to the project documentation or contact the development team.