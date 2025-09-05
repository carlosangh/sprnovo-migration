#!/bin/bash
# Database Backup Script for SPR System
# Performs automated backups of the SPR database

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/opt/spr/backups/database}"
DATABASE_URL="${DATABASE_URL:-}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
S3_BUCKET="${S3_BUCKET:-}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"

# Timestamp for backup files
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="spr_database_${TIMESTAMP}.sql"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

# Logging
LOG_FILE="/var/log/spr/backup-database.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR: $1"
    send_notification "FAILED" "$1"
    exit 1
}

send_notification() {
    local status="$1"
    local message="$2"
    
    if [ -n "$NOTIFICATION_EMAIL" ] && command -v mail > /dev/null; then
        echo "Database backup $status at $(date): $message" | \
            mail -s "SPR Database Backup $status" "$NOTIFICATION_EMAIL"
    fi
    
    # Log to system log
    logger -t spr-backup "Database backup $status: $message"
}

# Create backup directory
create_backup_directory() {
    mkdir -p "$BACKUP_DIR"
    if [ ! -w "$BACKUP_DIR" ]; then
        error_exit "Backup directory $BACKUP_DIR is not writable"
    fi
}

# Perform database backup
backup_database() {
    log "Starting database backup..."
    
    # Extract database info from URL
    if [ -z "$DATABASE_URL" ]; then
        error_exit "DATABASE_URL not configured"
    fi
    
    local db_type=$(echo "$DATABASE_URL" | cut -d: -f1)
    
    case "$db_type" in
        "postgresql"|"postgres")
            backup_postgresql
            ;;
        "mysql")
            backup_mysql
            ;;
        "sqlite")
            backup_sqlite
            ;;
        *)
            error_exit "Unsupported database type: $db_type"
            ;;
    esac
    
    log "Database backup completed: $BACKUP_FILE"
}

backup_postgresql() {
    log "Performing PostgreSQL backup..."
    
    # Use pg_dump with connection string
    pg_dump "$DATABASE_URL" > "$BACKUP_DIR/$BACKUP_FILE" || \
        error_exit "PostgreSQL backup failed"
}

backup_mysql() {
    log "Performing MySQL backup..."
    
    # Parse MySQL URL: mysql://user:password@host:port/database
    local mysql_params=$(echo "$DATABASE_URL" | sed 's|mysql://||' | sed 's|/| |g')
    local credentials=$(echo "$mysql_params" | cut -d' ' -f1)
    local database=$(echo "$mysql_params" | cut -d' ' -f2)
    local user=$(echo "$credentials" | cut -d'@' -f1 | cut -d':' -f1)
    local password=$(echo "$credentials" | cut -d'@' -f1 | cut -d':' -f2)
    local host=$(echo "$credentials" | cut -d'@' -f2 | cut -d':' -f1)
    local port=$(echo "$credentials" | cut -d'@' -f2 | cut -d':' -f2)
    
    mysqldump -h"$host" -P"${port:-3306}" -u"$user" -p"$password" \
        --single-transaction --routines --triggers "$database" > \
        "$BACKUP_DIR/$BACKUP_FILE" || error_exit "MySQL backup failed"
}

backup_sqlite() {
    log "Performing SQLite backup..."
    
    # Extract database file path from URL
    local db_file=$(echo "$DATABASE_URL" | sed 's|sqlite://||')
    
    if [ ! -f "$db_file" ]; then
        error_exit "SQLite database file not found: $db_file"
    fi
    
    # Create a backup copy
    sqlite3 "$db_file" ".backup $BACKUP_DIR/$BACKUP_FILE" || \
        error_exit "SQLite backup failed"
}

# Compress backup file
compress_backup() {
    log "Compressing backup file..."
    
    cd "$BACKUP_DIR"
    gzip "$BACKUP_FILE" || error_exit "Backup compression failed"
    
    local file_size=$(du -h "$COMPRESSED_FILE" | cut -f1)
    log "Compressed backup size: $file_size"
}

# Upload to S3 if configured
upload_to_s3() {
    if [ -z "$S3_BUCKET" ]; then
        log "S3 upload not configured, skipping..."
        return
    fi
    
    if ! command -v aws > /dev/null; then
        log "AWS CLI not found, skipping S3 upload"
        return
    fi
    
    log "Uploading backup to S3..."
    
    aws s3 cp "$BACKUP_DIR/$COMPRESSED_FILE" \
        "s3://$S3_BUCKET/database-backups/$COMPRESSED_FILE" || \
        error_exit "S3 upload failed"
    
    log "Backup uploaded to S3 successfully"
}

# Clean up old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    # Local cleanup
    find "$BACKUP_DIR" -name "spr_database_*.sql.gz" -type f \
        -mtime +$RETENTION_DAYS -delete
    
    local remaining=$(find "$BACKUP_DIR" -name "spr_database_*.sql.gz" -type f | wc -l)
    log "Local backups remaining: $remaining"
    
    # S3 cleanup if configured
    if [ -n "$S3_BUCKET" ] && command -v aws > /dev/null; then
        # List and delete old S3 objects (requires jq for date parsing)
        if command -v jq > /dev/null; then
            local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
            
            aws s3api list-objects-v2 --bucket "$S3_BUCKET" \
                --prefix "database-backups/spr_database_" \
                --query "Contents[?LastModified<'$cutoff_date'].Key" \
                --output text | xargs -r -I {} aws s3 rm "s3://$S3_BUCKET/{}"
        fi
    fi
}

# Verify backup integrity
verify_backup() {
    log "Verifying backup integrity..."
    
    if [ ! -f "$BACKUP_DIR/$COMPRESSED_FILE" ]; then
        error_exit "Backup file not found"
    fi
    
    # Test gzip integrity
    gzip -t "$BACKUP_DIR/$COMPRESSED_FILE" || \
        error_exit "Backup file is corrupted"
    
    # Check file size (should be > 0)
    local file_size=$(stat -c%s "$BACKUP_DIR/$COMPRESSED_FILE")
    if [ "$file_size" -eq 0 ]; then
        error_exit "Backup file is empty"
    fi
    
    log "Backup verification successful"
}

# Main execution
main() {
    log "=== Starting SPR Database Backup Process ==="
    
    create_backup_directory
    backup_database
    compress_backup
    verify_backup
    upload_to_s3
    cleanup_old_backups
    
    local final_size=$(du -h "$BACKUP_DIR/$COMPRESSED_FILE" | cut -f1)
    send_notification "SUCCESS" "Backup completed successfully. Size: $final_size"
    
    log "=== Database Backup Process Completed Successfully ==="
}

# Handle command line arguments
case "${1:-}" in
    "--verify")
        # Verify the most recent backup
        LATEST_BACKUP=$(find "$BACKUP_DIR" -name "spr_database_*.sql.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
        if [ -n "$LATEST_BACKUP" ]; then
            COMPRESSED_FILE=$(basename "$LATEST_BACKUP")
            verify_backup
            log "Latest backup verified: $COMPRESSED_FILE"
        else
            error_exit "No backup files found to verify"
        fi
        ;;
    "--help"|"-h")
        echo "SPR Database Backup Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --verify    Verify the most recent backup"
        echo "  --help      Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  DATABASE_URL       - Database connection string"
        echo "  BACKUP_DIR         - Backup directory (default: /opt/spr/backups/database)"
        echo "  RETENTION_DAYS     - Days to keep backups (default: 30)"
        echo "  S3_BUCKET          - S3 bucket for remote backup storage"
        echo "  NOTIFICATION_EMAIL - Email for backup notifications"
        echo ""
        echo "Examples:"
        echo "  $0                 # Run backup"
        echo "  $0 --verify        # Verify latest backup"
        ;;
    *)
        main
        ;;
esac