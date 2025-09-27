#!/bin/bash

# ThreadArt Generator - Redis Backup Script
# This script creates automated backups of Redis data

set -euo pipefail

# Configuration
REDIS_CONTAINER="threadart-redis"
BACKUP_DIR="/backup"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate backup filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/redis_backup_$TIMESTAMP.rdb"
COMPRESSED_FILE="$BACKUP_FILE.gz"

echo "Starting Redis backup at $(date)"
echo "Container: $REDIS_CONTAINER"
echo "Backup file: $BACKUP_FILE"

# Force Redis to save current state
echo "Triggering Redis BGSAVE..."
if docker exec "$REDIS_CONTAINER" redis-cli -a "$REDIS_PASSWORD" BGSAVE; then
    echo "BGSAVE initiated successfully"
    
    # Wait for background save to complete
    echo "Waiting for background save to complete..."
    while [ "$(docker exec "$REDIS_CONTAINER" redis-cli -a "$REDIS_PASSWORD" LASTSAVE)" = "$(docker exec "$REDIS_CONTAINER" redis-cli -a "$REDIS_PASSWORD" LASTSAVE)" ]; do
        sleep 2
    done
    
    # Copy the RDB file
    echo "Copying RDB file..."
    if docker exec "$REDIS_CONTAINER" cp /data/dump.rdb "/backup/redis_backup_$TIMESTAMP.rdb"; then
        echo "RDB file copied successfully"
        
        # Compress the backup
        if docker exec "$REDIS_CONTAINER" gzip "/backup/redis_backup_$TIMESTAMP.rdb"; then
            echo "Backup compressed successfully: $COMPRESSED_FILE"
            
            # Verify backup integrity (basic check)
            if docker exec "$REDIS_CONTAINER" test -f "/backup/redis_backup_$TIMESTAMP.rdb.gz"; then
                echo "Backup file created and verified"
                
                # Create a latest backup symlink
                docker exec "$REDIS_CONTAINER" sh -c "cd /backup && ln -sf redis_backup_$TIMESTAMP.rdb.gz redis_latest.rdb.gz"
                
                # Get Redis info for backup metadata
                KEY_COUNT=$(docker exec "$REDIS_CONTAINER" redis-cli -a "$REDIS_PASSWORD" DBSIZE)
                MEMORY_USAGE=$(docker exec "$REDIS_CONTAINER" redis-cli -a "$REDIS_PASSWORD" INFO memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
                
                # Cleanup old backups (keep only last N days)
                echo "Cleaning up backups older than $RETENTION_DAYS days"
                docker exec "$REDIS_CONTAINER" find /backup -name "redis_backup_*.rdb.gz" -type f -mtime "+$RETENTION_DAYS" -delete
                
                # Log backup size and count
                BACKUP_SIZE=$(docker exec "$REDIS_CONTAINER" du -h "/backup/redis_backup_$TIMESTAMP.rdb.gz" | cut -f1)
                BACKUP_COUNT=$(docker exec "$REDIS_CONTAINER" find /backup -name "redis_backup_*.rdb.gz" -type f | wc -l)
                
                echo "Backup completed successfully!"
                echo "Keys backed up: $KEY_COUNT"
                echo "Memory usage: $MEMORY_USAGE"
                echo "Backup size: $BACKUP_SIZE"
                echo "Total backups retained: $BACKUP_COUNT"
                
                # Create backup metadata
                cat > "/tmp/redis_backup_$TIMESTAMP.meta" << EOF
{
    "timestamp": "$TIMESTAMP",
    "backup_file": "redis_backup_$TIMESTAMP.rdb.gz",
    "key_count": $KEY_COUNT,
    "memory_usage": "$MEMORY_USAGE",
    "backup_size": "$BACKUP_SIZE",
    "created_at": "$(date -Iseconds)"
}
EOF
                docker cp "/tmp/redis_backup_$TIMESTAMP.meta" "$REDIS_CONTAINER:/backup/"
                
                # Optional: Send notification (uncomment and configure as needed)
                # curl -X POST -H 'Content-type: application/json' \
                #   --data '{"text":"Redis backup completed: '"$BACKUP_FILE"' ('"$KEY_COUNT"' keys)"}' \
                #   "$SLACK_WEBHOOK_URL"
                
            else
                echo "ERROR: Backup file verification failed!"
                exit 1
            fi
        else
            echo "ERROR: Failed to compress backup"
            exit 1
        fi
    else
        echo "ERROR: Failed to copy RDB file"
        exit 1
    fi
else
    echo "ERROR: Redis BGSAVE failed"
    exit 1
fi

echo "Redis backup process completed at $(date)"