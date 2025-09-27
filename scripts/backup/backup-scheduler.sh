#!/bin/bash

# ThreadArt Generator - Backup Scheduler
# Automated backup coordination and monitoring

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/threadart"
LOG_FILE="$LOG_DIR/backup-scheduler.log"
BACKUP_DIR="/backup"
ALERT_EMAIL="${BACKUP_ALERT_EMAIL:-admin@threadart.local}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL:-}"

# Create log directory
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Logging function
log_message() {
    local level="$1"
    shift
    echo "[$(date -Iseconds)] [$level] $*" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(date -Iseconds)] [$level] $*"
}

# Send alerts
send_alert() {
    local title="$1"
    local message="$2"
    local status="${3:-ERROR}"
    
    log_message "ALERT" "$title: $message"
    
    # Discord webhook notification
    if [ -n "$DISCORD_WEBHOOK" ]; then
        curl -H "Content-Type: application/json" \
             -X POST \
             -d "{\"embeds\":[{\"title\":\"ThreadArt Backup Alert\",\"description\":\"**$title**\\n$message\",\"color\":$([ "$status" = "SUCCESS" ] && echo "65280" || echo "16711680")}]}" \
             "$DISCORD_WEBHOOK" 2>/dev/null || true
    fi
    
    # System logger
    logger -t "threadart-backup" "$title: $message"
}

# Check system resources
check_resources() {
    local backup_dir="$1"
    
    # Check disk space
    if [ -d "$backup_dir" ]; then
        local disk_usage=$(df "$backup_dir" | tail -1 | awk '{print $5}' | sed 's/%//')
        log_message "INFO" "Disk usage for $backup_dir: $disk_usage%"
        
        if [ "$disk_usage" -gt 85 ]; then
            send_alert "Low Disk Space" "Backup directory $backup_dir is $disk_usage% full" "WARNING"
        fi
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        send_alert "Docker Unavailable" "Docker daemon is not running or accessible" "ERROR"
        return 1
    fi
    
    # Check containers are running
    local postgres_running=$(docker ps --filter "name=threadart-postgres" --format "{{.Names}}" | wc -l)
    local redis_running=$(docker ps --filter "name=threadart-redis" --format "{{.Names}}" | wc -l)
    
    if [ "$postgres_running" -eq 0 ]; then
        send_alert "PostgreSQL Container Down" "threadart-postgres container is not running" "ERROR"
        return 1
    fi
    
    if [ "$redis_running" -eq 0 ]; then
        send_alert "Redis Container Down" "threadart-redis container is not running" "ERROR"
        return 1
    fi
    
    log_message "INFO" "Resource checks passed"
    return 0
}

# Execute backup with monitoring
execute_backup() {
    local service="$1"
    local script="$2"
    local max_retries="${3:-2}"
    
    log_message "INFO" "Starting $service backup..."
    
    local attempt=1
    while [ $attempt -le $max_retries ]; do
        if [ $attempt -gt 1 ]; then
            log_message "INFO" "$service backup retry attempt $attempt/$max_retries"
            sleep 30  # Wait before retry
        fi
        
        # Execute backup script with timeout
        if timeout 1800 bash "$SCRIPT_DIR/$script" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "SUCCESS" "$service backup completed successfully"
            return 0
        else
            local exit_code=$?
            log_message "ERROR" "$service backup failed with exit code $exit_code (attempt $attempt/$max_retries)"
            attempt=$((attempt + 1))
        fi
    done
    
    send_alert "$service Backup Failed" "All $max_retries attempts failed. Check logs for details." "ERROR"
    return 1
}

# Generate backup report
generate_report() {
    local postgres_success="$1"
    local redis_success="$2"
    
    log_message "INFO" "Generating backup report..."
    
    # Count existing backups
    local postgres_backups=$(docker exec threadart-postgres find /backup -name "postgres_backup_*.sql.gz" -type f 2>/dev/null | wc -l || echo "0")
    local redis_backups=$(docker exec threadart-redis find /backup -name "redis_backup_*.rdb.gz" -type f 2>/dev/null | wc -l || echo "0")
    
    # Calculate total backup sizes
    local postgres_size=$(docker exec threadart-postgres du -sh /backup/postgres_* 2>/dev/null | tail -1 | cut -f1 || echo "0B")
    local redis_size=$(docker exec threadart-redis du -sh /backup/redis_* 2>/dev/null | tail -1 | cut -f1 || echo "0B")
    
    # Create summary
    local summary="Backup Summary - $(date)\\n"
    summary+="PostgreSQL: $([ $postgres_success -eq 1 ] && echo "✅ SUCCESS" || echo "❌ FAILED") ($postgres_backups files, ~$postgres_size)\\n"
    summary+="Redis: $([ $redis_success -eq 1 ] && echo "✅ SUCCESS" || echo "❌ FAILED") ($redis_backups files, ~$redis_size)"
    
    log_message "INFO" "Backup report generated"
    
    # Send summary notification
    if [ $postgres_success -eq 1 ] && [ $redis_success -eq 1 ]; then
        send_alert "Backup Summary" "$summary" "SUCCESS"
    else
        send_alert "Backup Summary" "$summary" "WARNING"
    fi
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    log_message "INFO" "=== ThreadArt Backup Scheduler Started ==="
    
    # Pre-flight checks
    if ! check_resources "$BACKUP_DIR"; then
        log_message "ERROR" "Pre-flight checks failed, aborting backup"
        exit 1
    fi
    
    # Initialize success flags
    local postgres_success=0
    local redis_success=0
    
    # Execute backups
    if execute_backup "PostgreSQL" "postgres-backup.sh" 2; then
        postgres_success=1
    fi
    
    if execute_backup "Redis" "redis-backup.sh" 2; then
        redis_success=1
    fi
    
    # Post-backup checks
    check_resources "$BACKUP_DIR" || true
    
    # Generate report
    generate_report $postgres_success $redis_success
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_message "INFO" "=== ThreadArt Backup Scheduler Completed in ${duration}s ==="
    
    # Exit with error if any backup failed
    if [ $postgres_success -eq 0 ] || [ $redis_success -eq 0 ]; then
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --dry-run)
        log_message "INFO" "Running in dry-run mode"
        check_resources "$BACKUP_DIR"
        echo "Dry run completed successfully"
        ;;
    --test-alerts)
        send_alert "Test Alert" "This is a test alert from the backup scheduler" "SUCCESS"
        echo "Test alert sent"
        ;;
    *)
        main "$@"
        ;;
esac