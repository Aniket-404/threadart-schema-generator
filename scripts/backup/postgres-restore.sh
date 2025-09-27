#!/bin/bash

# ThreadArt Generator - PostgreSQL Restore Script
# This script restores PostgreSQL database from backup

set -euo pipefail

# Configuration
POSTGRES_CONTAINER="threadart-postgres"
BACKUP_DIR="/backup"
POSTGRES_DB="${POSTGRES_DB:-threadart_db}"
POSTGRES_USER="${POSTGRES_USER:-threadart_user}"

# Function to display usage
usage() {
    echo "Usage: $0 <backup_file>"
    echo "       $0 latest"
    echo ""
    echo "Examples:"
    echo "  $0 postgres_backup_20240927_120000.sql.gz"
    echo "  $0 latest"
    echo ""
    echo "Available backups:"
    docker exec "$POSTGRES_CONTAINER" find /backup -name "postgres_backup_*.sql.gz" -type f -exec basename {} \; 2>/dev/null | sort || echo "No backups found"
    exit 1
}

# Check if backup file is provided
if [ $# -ne 1 ]; then
    usage
fi

BACKUP_INPUT="$1"

# Determine backup file to restore
if [ "$BACKUP_INPUT" = "latest" ]; then
    BACKUP_FILE="$BACKUP_DIR/postgres_latest.sql.gz"
    if ! docker exec "$POSTGRES_CONTAINER" test -f "$BACKUP_FILE"; then
        echo "ERROR: Latest backup not found at $BACKUP_FILE"
        exit 1
    fi
else
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_INPUT"
    # Add .gz extension if not provided
    if [[ "$BACKUP_FILE" != *.gz ]]; then
        BACKUP_FILE="$BACKUP_FILE.gz"
    fi
    
    if ! docker exec "$POSTGRES_CONTAINER" test -f "$BACKUP_FILE"; then
        echo "ERROR: Backup file not found: $BACKUP_FILE"
        usage
    fi
fi

echo "Starting PostgreSQL restore at $(date)"
echo "Database: $POSTGRES_DB"
echo "User: $POSTGRES_USER"
echo "Backup file: $BACKUP_FILE"

# Confirm restore operation
read -p "This will REPLACE all data in database '$POSTGRES_DB'. Are you sure? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Create a pre-restore backup
echo "Creating pre-restore backup..."
PRE_RESTORE_BACKUP="$BACKUP_DIR/pre_restore_$(date +"%Y%m%d_%H%M%S").sql.gz"
docker exec "$POSTGRES_CONTAINER" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" | docker exec -i "$POSTGRES_CONTAINER" gzip > "$PRE_RESTORE_BACKUP" 2>/dev/null || {
    echo "Warning: Could not create pre-restore backup (database might not exist yet)"
}

# Drop and recreate database
echo "Dropping and recreating database..."
docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS $POSTGRES_DB;"
docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "CREATE DATABASE $POSTGRES_DB;"

# Restore from backup
echo "Restoring database from backup..."
if docker exec "$POSTGRES_CONTAINER" sh -c "gunzip -c $BACKUP_FILE | psql -U $POSTGRES_USER -d $POSTGRES_DB"; then
    echo "Database restore completed successfully"
    
    # Verify restore
    echo "Verifying restore..."
    TABLE_COUNT=$(docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' ')
    
    echo "Restore verification:"
    echo "  Tables restored: $TABLE_COUNT"
    
    # Run database health check if function exists
    docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM check_database_health();" 2>/dev/null || echo "  Health check function not available"
    
    echo "PostgreSQL restore completed successfully at $(date)"
else
    echo "ERROR: Database restore failed"
    
    if [ -f "$PRE_RESTORE_BACKUP" ]; then
        echo "Attempting to restore from pre-restore backup..."
        docker exec "$POSTGRES_CONTAINER" sh -c "gunzip -c $PRE_RESTORE_BACKUP | psql -U $POSTGRES_USER -d $POSTGRES_DB"
    fi
    
    exit 1
fi