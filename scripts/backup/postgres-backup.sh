#!/bin/bash

# ThreadArt Generator - PostgreSQL Backup Script
# This script creates automated backups of the PostgreSQL database

set -euo pipefail

# Configuration
POSTGRES_CONTAINER="threadart-postgres"
BACKUP_DIR="/backup"
POSTGRES_DB="${POSTGRES_DB:-threadart_db}"
POSTGRES_USER="${POSTGRES_USER:-threadart_user}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate backup filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/postgres_backup_$TIMESTAMP.sql"
COMPRESSED_FILE="$BACKUP_FILE.gz"

echo "Starting PostgreSQL backup at $(date)"
echo "Database: $POSTGRES_DB"
echo "User: $POSTGRES_USER"
echo "Backup file: $BACKUP_FILE"

# Create database backup
if docker exec "$POSTGRES_CONTAINER" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "/backup/postgres_backup_$TIMESTAMP.sql"; then
    echo "Database dump completed successfully"
    
    # Compress the backup
    if docker exec "$POSTGRES_CONTAINER" gzip "/backup/postgres_backup_$TIMESTAMP.sql"; then
        echo "Backup compressed successfully: $COMPRESSED_FILE"
        
        # Verify backup integrity
        if docker exec "$POSTGRES_CONTAINER" sh -c "gunzip -t /backup/postgres_backup_$TIMESTAMP.sql.gz"; then
            echo "Backup integrity verified"
            
            # Create a latest backup symlink
            docker exec "$POSTGRES_CONTAINER" sh -c "cd /backup && ln -sf postgres_backup_$TIMESTAMP.sql.gz postgres_latest.sql.gz"
            
            # Cleanup old backups (keep only last N days)
            echo "Cleaning up backups older than $RETENTION_DAYS days"
            docker exec "$POSTGRES_CONTAINER" find /backup -name "postgres_backup_*.sql.gz" -type f -mtime "+$RETENTION_DAYS" -delete
            
            # Log backup size and count
            BACKUP_SIZE=$(docker exec "$POSTGRES_CONTAINER" du -h "/backup/postgres_backup_$TIMESTAMP.sql.gz" | cut -f1)
            BACKUP_COUNT=$(docker exec "$POSTGRES_CONTAINER" find /backup -name "postgres_backup_*.sql.gz" -type f | wc -l)
            
            echo "Backup completed successfully!"
            echo "Size: $BACKUP_SIZE"
            echo "Total backups retained: $BACKUP_COUNT"
            
            # Optional: Send notification (uncomment and configure as needed)
            # curl -X POST -H 'Content-type: application/json' \
            #   --data '{"text":"PostgreSQL backup completed: '"$BACKUP_FILE"'"}' \
            #   "$SLACK_WEBHOOK_URL"
            
        else
            echo "ERROR: Backup integrity check failed!"
            exit 1
        fi
    else
        echo "ERROR: Failed to compress backup"
        exit 1
    fi
else
    echo "ERROR: Database dump failed"
    exit 1
fi

echo "PostgreSQL backup process completed at $(date)"