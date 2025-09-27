# ThreadArt Backup & Restore Documentation

## Overview
Comprehensive backup and restore procedures for ThreadArt infrastructure including PostgreSQL database and Redis cache.

## Backup Strategy
- **Daily automated backups** at 2:00 AM via cron scheduler
- **Retention Policy**: 7 days daily, 4 weeks weekly, 6 months monthly
- **Compression**: All backups are gzip compressed to save space
- **Integrity**: Every backup is verified after creation
- **Monitoring**: Automated alerts for backup failures and disk space

## Quick Commands

### Manual Backup
```bash
# PostgreSQL backup
./scripts/backup/postgres-backup.sh

# Redis backup  
./scripts/backup/redis-backup.sh

# Both services (with monitoring)
./scripts/backup/backup-scheduler.sh
```

### Manual Restore
```bash
# PostgreSQL restore (latest backup)
./scripts/backup/postgres-restore.sh latest

# PostgreSQL restore (specific backup)
./scripts/backup/postgres-restore.sh postgres_backup_20250927_120000.sql.gz

# Redis restore (latest backup)
./scripts/backup/redis-restore.sh latest

# Redis restore (specific backup)
./scripts/backup/redis-restore.sh redis_backup_20250927_120000.rdb.gz
```

## Backup Locations
- **Inside containers**: `/backup/`
- **Host system**: `./scripts/backup/` (mounted volume)
- **Directory structure**:
  ```
  /backup/
  ├── postgres_backup_YYYYMMDD_HHMMSS.sql.gz
  ├── postgres_latest.sql.gz -> (symlink to latest)
  ├── redis_backup_YYYYMMDD_HHMMSS.rdb.gz
  └── redis_latest.rdb.gz -> (symlink to latest)
  ```

## Automated Scheduling

### Method 1: Docker Compose (Recommended)
Add the backup scheduler service to your docker-compose.yml:
```yaml
# Include the backup service from docker-compose-backup.yml
```

### Method 2: Host Cron
```bash
# Add to crontab (crontab -e)
0 2 * * * /path/to/threadart/scripts/backup/backup-scheduler.sh

# Weekly cleanup (optional)
0 3 * * 0 /path/to/threadart/scripts/backup/cleanup-old-backups.sh
```

## Environment Variables

### Required
- `POSTGRES_PASSWORD` - PostgreSQL database password
- `REDIS_PASSWORD` - Redis authentication password

### Optional
- `BACKUP_RETENTION_DAYS=7` - Days to keep daily backups
- `BACKUP_ALERT_EMAIL` - Email for backup alerts
- `DISCORD_WEBHOOK_URL` - Discord webhook for notifications

## Monitoring & Alerting

### Log Files
- **Backup logs**: `/var/log/threadart/backup-scheduler.log`
- **Individual logs**: Included in scheduler log

### Alert Triggers
- Backup script failures (with retries)
- Disk space > 85% usage
- Docker daemon unavailable
- Database containers not running

### Test Alerts
```bash
# Test notification system
./scripts/backup/backup-scheduler.sh --test-alerts

# Dry run (check without executing)
./scripts/backup/backup-scheduler.sh --dry-run
```

## Recovery Procedures

### Complete System Recovery
1. **Start infrastructure**: `docker-compose up -d postgres redis`
2. **Restore PostgreSQL**: `./scripts/backup/postgres-restore.sh latest`
3. **Restore Redis**: `./scripts/backup/redis-restore.sh latest`
4. **Verify services**: Check application connectivity
5. **Start remaining services**: `docker-compose up -d`

### Partial Recovery
- **Database only**: Restore PostgreSQL, restart app services
- **Cache only**: Restore Redis (or let it rebuild from application)

### Point-in-Time Recovery
1. List available backups: `ls /backup/postgres_backup_*.sql.gz`
2. Select specific backup: `./scripts/backup/postgres-restore.sh postgres_backup_YYYYMMDD_HHMMSS.sql.gz`

## Best Practices

### Regular Testing
```bash
# Monthly restore test (to test environment)
docker-compose -f docker-compose.test.yml up -d postgres-test redis-test
./scripts/backup/postgres-restore.sh latest  # to test containers
./scripts/backup/redis-restore.sh latest     # to test containers
# Verify data integrity
docker-compose -f docker-compose.test.yml down
```

### Security
- Store backups on separate storage (NAS, cloud)
- Encrypt sensitive backups for off-site storage
- Restrict backup directory permissions (600/700)
- Regular security audits of backup procedures

### Performance
- Schedule backups during low-traffic periods (2-4 AM)
- Monitor backup duration and optimize if needed
- Use backup compression to save storage space
- Consider incremental backups for very large datasets

## Troubleshooting

### Common Issues

**Backup fails with "permission denied"**
```bash
# Fix backup directory permissions
chmod -R 755 ./scripts/backup/
chown -R 999:999 /backup/  # PostgreSQL container user
```

**Docker socket permission errors**
```bash
# Add user to docker group or run with sudo
sudo usermod -aG docker $USER
```

**Backup takes too long**
```bash
# Check database size and optimize if needed
docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "SELECT pg_size_pretty(pg_database_size('threadart_db'));"

# Consider maintenance during backups
docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "VACUUM ANALYZE;"
```

**Restore fails with encoding errors**
```bash
# Ensure database encoding matches backup
docker exec threadart-postgres psql -U threadart_user -c "SELECT datname, encoding FROM pg_database WHERE datname='threadart_db';"
```

### Emergency Contacts
- **System Admin**: admin@threadart.local
- **Discord Channel**: #infrastructure-alerts
- **Documentation**: https://docs.threadart.local/backup-restore

---

**Last Updated**: September 2025  
**Version**: 1.0  
**Maintainer**: ThreadArt DevOps Team