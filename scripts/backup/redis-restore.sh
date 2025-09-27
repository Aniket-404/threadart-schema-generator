#!/bin/bash

# ThreadArt Generator - Redis Restore Script
# This script restores Redis data from backup

set -euo pipefail

# Configuration
REDIS_CONTAINER="threadart-redis"
BACKUP_DIR="/backup"

# Function to display usage
usage() {
    echo "Usage: $0 <backup_file>"
    echo "       $0 latest"
    echo ""
    echo "Examples:"
    echo "  $0 redis_backup_20240927_120000.rdb.gz"
    echo "  $0 latest"
    echo ""
    echo "Available backups:"
    docker exec "$REDIS_CONTAINER" find /backup -name "redis_backup_*.rdb.gz" -type f -exec basename {} \; 2>/dev/null | sort || echo "No backups found"
    exit 1
}

# Check if backup file is provided
if [ $# -ne 1 ]; then
    usage
fi

BACKUP_INPUT="$1"

# Determine backup file to restore
if [ "$BACKUP_INPUT" = "latest" ]; then
    BACKUP_FILE="$BACKUP_DIR/redis_latest.rdb.gz"
    if ! docker exec "$REDIS_CONTAINER" test -f "$BACKUP_FILE"; then
        echo "ERROR: Latest backup not found at $BACKUP_FILE"
        exit 1
    fi
else
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_INPUT"
    # Add .gz extension if not provided
    if [[ "$BACKUP_FILE" != *.gz ]]; then
        BACKUP_FILE="$BACKUP_FILE.gz"
    fi
    
    if ! docker exec "$REDIS_CONTAINER" test -f "$BACKUP_FILE"; then
        echo "ERROR: Backup file not found: $BACKUP_FILE"
        usage
    fi
fi

echo "Starting Redis restore at $(date)"
echo "Container: $REDIS_CONTAINER"
echo "Backup file: $BACKUP_FILE"

# Show current Redis info before restore
CURRENT_KEYS=$(docker exec "$REDIS_CONTAINER" redis-cli -a "$REDIS_PASSWORD" DBSIZE 2>/dev/null || echo "0")
echo "Current Redis keys: $CURRENT_KEYS"

# Confirm restore operation
read -p "This will REPLACE all data in Redis. Are you sure? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Create a pre-restore backup if there's data
if [ "$CURRENT_KEYS" -gt 0 ]; then
    echo "Creating pre-restore backup..."
    PRE_RESTORE_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    docker exec "$REDIS_CONTAINER" redis-cli -a "$REDIS_PASSWORD" BGSAVE
    sleep 3  # Wait for save to complete
    docker exec "$REDIS_CONTAINER" cp /data/dump.rdb "/backup/pre_restore_$PRE_RESTORE_TIMESTAMP.rdb"
    docker exec "$REDIS_CONTAINER" gzip "/backup/pre_restore_$PRE_RESTORE_TIMESTAMP.rdb"
    echo "Pre-restore backup saved as: pre_restore_$PRE_RESTORE_TIMESTAMP.rdb.gz"
fi

# Stop Redis to safely replace RDB file
echo "Stopping Redis for restore..."
docker stop "$REDIS_CONTAINER"

# Wait a moment for container to fully stop
sleep 2

# Replace the RDB file
echo "Restoring RDB file..."
TEMP_RDB="/tmp/restore_dump.rdb"

# Extract backup to temporary location
docker start "$REDIS_CONTAINER"
sleep 5  # Wait for Redis to start

if docker exec "$REDIS_CONTAINER" sh -c "gunzip -c $BACKUP_FILE > $TEMP_RDB"; then
    echo "Backup extracted successfully"
    
    # Stop Redis again to replace file safely
    docker stop "$REDIS_CONTAINER"
    sleep 2
    
    # Replace the dump.rdb file
    docker start "$REDIS_CONTAINER"
    sleep 2
    docker exec "$REDIS_CONTAINER" redis-cli -a "$REDIS_PASSWORD" SHUTDOWN NOSAVE 2>/dev/null || true
    sleep 2
    
    # Copy the extracted backup over the current dump.rdb
    docker exec "$REDIS_CONTAINER" sh -c "cp $TEMP_RDB /data/dump.rdb"
    
    # Start Redis with the restored data
    docker start "$REDIS_CONTAINER" 2>/dev/null || true
    sleep 5
    
    # Verify restore
    echo "Verifying restore..."
    RESTORED_KEYS=$(docker exec "$REDIS_CONTAINER" redis-cli -a "$REDIS_PASSWORD" DBSIZE)
    
    if [ "$RESTORED_KEYS" -gt 0 ]; then
        echo "Restore verification:"
        echo "  Keys restored: $RESTORED_KEYS"
        
        # Display Redis info
        MEMORY_USAGE=$(docker exec "$REDIS_CONTAINER" redis-cli -a "$REDIS_PASSWORD" INFO memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
        echo "  Memory usage: $MEMORY_USAGE"
        
        # Show backup metadata if available
        BACKUP_META="${BACKUP_FILE%.gz}.meta"
        if docker exec "$REDIS_CONTAINER" test -f "$BACKUP_META"; then
            echo "  Backup metadata:"
            docker exec "$REDIS_CONTAINER" cat "$BACKUP_META" | grep -E "(key_count|created_at|backup_size)" || true
        fi
        
        echo "Redis restore completed successfully at $(date)"
    else
        echo "WARNING: No keys found after restore. This might indicate an empty backup or restore failure."
    fi
    
    # Cleanup temporary file
    docker exec "$REDIS_CONTAINER" rm -f "$TEMP_RDB" 2>/dev/null || true
    
else
    echo "ERROR: Failed to extract backup file"
    docker start "$REDIS_CONTAINER" 2>/dev/null || true
    exit 1
fi