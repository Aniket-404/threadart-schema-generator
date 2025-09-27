# ThreadArt Quick Start Guide

This is a condensed setup guide for getting ThreadArt infrastructure running quickly. For detailed documentation, see [infrastructure-setup.md](infrastructure-setup.md).

## Prerequisites
- Docker & Docker Compose installed
- 4GB RAM, 20GB disk space minimum
- Ports 80, 3000, 3001, 5432, 6379, 9090 available

## Quick Setup (5 minutes)

### 1. Configure Environment
```bash
# Copy environment template
cp .env.example .env.production

# Edit with your settings (required fields marked)
nano .env.production
```

**Required Environment Variables:**
```bash
POSTGRES_PASSWORD=your_secure_password    # Required
REDIS_PASSWORD=your_redis_password        # Required
JWT_SECRET=your_jwt_secret               # Required
CLOUDINARY_CLOUD_NAME=your_cloud         # Required
CLOUDINARY_API_KEY=your_api_key          # Required  
CLOUDINARY_API_SECRET=your_secret        # Required
```

### 2. Start Infrastructure
```bash
# Start all services
docker-compose up -d

# Check status (should show 6-8 services running)
docker-compose ps
```

### 3. Verify Setup
```bash
# Run validation script
./scripts/validate-infrastructure.sh     # Linux/Mac
scripts\validate-infrastructure.bat     # Windows
```

### 4. Access Services
- **Application**: http://localhost:3000
- **API Health**: http://localhost:3000/api/health  
- **Grafana**: http://localhost:3001 (admin/your_grafana_password)
- **Prometheus**: http://localhost:9090

## Quick Health Check
```bash
# All should return success/healthy status
curl http://localhost:3000/health
curl http://localhost:9090/-/healthy
curl http://localhost:3001/api/health
```

## Common Issues & Fixes

### Services won't start:
```bash
# Check Docker daemon
docker info

# Check configuration
docker-compose config
```

### Port conflicts:
```bash
# Find conflicting process
netstat -tulpn | grep :3000

# Kill conflicting process or change ports in docker-compose.yml
```

### Database connection fails:
```bash
# Check PostgreSQL is running
docker exec threadart-postgres pg_isready
```

## Next Steps
1. **Development**: Your infrastructure is ready for frontend/backend development
2. **Monitoring**: Configure Grafana dashboards for your metrics
3. **Backups**: Automatic backups are configured and running
4. **Production**: Follow [infrastructure-setup.md](infrastructure-setup.md) for production deployment

## Stop Services
```bash
docker-compose down
```

Need help? See the full [Infrastructure Setup Guide](infrastructure-setup.md) or [Troubleshooting Guide](troubleshooting.md).