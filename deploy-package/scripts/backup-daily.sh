#!/bin/bash

# SPRNOVO Daily Backup Script
# Backs up PostgreSQL database and n8n_data volume to DigitalOcean Spaces

set -e

# Configuration
BACKUP_DIR="/home/cadu/SPRNOVO/backups"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER_PREFIX="spr"
RCLONE_REMOTE="digitalocean:spr-backups-2025"

# Database backup configuration
DB_CONTAINER="spr-postgres-new"
DB_NAME="spr_db"
DB_USER="spr_user"
DB_PASSWORD="spr_password_2025"

# n8n volume configuration
N8N_VOLUME="sprnovo_n8n_data"

# Create backup directory
mkdir -p $BACKUP_DIR

echo "=== SPRNOVO Daily Backup Started: $(date) ==="

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if containers are running
check_container() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^$1$"; then
        log "ERROR: Container $1 is not running"
        exit 1
    fi
}

# Backup PostgreSQL database
backup_database() {
    log "Starting database backup..."
    
    check_container $DB_CONTAINER
    
    BACKUP_FILE="$BACKUP_DIR/spr_database_$DATE.sql.gz"
    
    docker exec $DB_CONTAINER pg_dump \
        -h localhost \
        -U $DB_USER \
        -d $DB_NAME \
        --clean \
        --create \
        --verbose \
        | gzip > $BACKUP_FILE
    
    if [ $? -eq 0 ]; then
        log "Database backup completed: $(basename $BACKUP_FILE)"
        log "Size: $(du -h $BACKUP_FILE | cut -f1)"
    else
        log "ERROR: Database backup failed"
        exit 1
    fi
}

# Backup n8n data volume
backup_n8n_volume() {
    log "Starting n8n volume backup..."
    
    VOLUME_BACKUP_FILE="$BACKUP_DIR/n8n_data_$DATE.tar.gz"
    
    # Create temporary container to access volume
    docker run --rm \
        -v $N8N_VOLUME:/n8n-data:ro \
        -v $BACKUP_DIR:/backup \
        alpine:latest \
        tar -czf /backup/$(basename $VOLUME_BACKUP_FILE) -C /n8n-data .
    
    if [ $? -eq 0 ]; then
        log "n8n volume backup completed: $(basename $VOLUME_BACKUP_FILE)"
        log "Size: $(du -h $VOLUME_BACKUP_FILE | cut -f1)"
    else
        log "ERROR: n8n volume backup failed"
        exit 1
    fi
}

# Upload to DigitalOcean Spaces via Rclone
upload_to_spaces() {
    log "Uploading backups to DigitalOcean Spaces..."
    
    # Check if rclone is configured
    if ! rclone listremotes | grep -q "digitalocean:"; then
        log "ERROR: Rclone not configured for DigitalOcean Spaces"
        log "Run: rclone config"
        exit 1
    fi
    
    # Create remote directory structure
    REMOTE_PATH="$RCLONE_REMOTE/$(date +%Y)/$(date +%m)/$(date +%d)"
    
    # Upload database backup
    log "Uploading database backup..."
    rclone copy $BACKUP_DIR/spr_database_$DATE.sql.gz $REMOTE_PATH/ --progress
    
    # Upload n8n volume backup
    log "Uploading n8n volume backup..."
    rclone copy $BACKUP_DIR/n8n_data_$DATE.tar.gz $REMOTE_PATH/ --progress
    
    if [ $? -eq 0 ]; then
        log "Upload completed successfully"
    else
        log "ERROR: Upload to DigitalOcean Spaces failed"
        exit 1
    fi
}

# Cleanup old local backups (keep last 7 days)
cleanup_local() {
    log "Cleaning up local backups older than 7 days..."
    find $BACKUP_DIR -name "spr_database_*.sql.gz" -mtime +7 -delete
    find $BACKUP_DIR -name "n8n_data_*.tar.gz" -mtime +7 -delete
    log "Local cleanup completed"
}

# Cleanup old remote backups (keep last 30 days)
cleanup_remote() {
    log "Cleaning up remote backups older than 30 days..."
    
    # This would require more complex logic to parse dates from remote files
    # For now, we'll implement a simple version
    CUTOFF_DATE=$(date -d '30 days ago' +%Y%m%d)
    
    rclone lsf $RCLONE_REMOTE --recursive | \
    while read file; do
        # Extract date from filename (YYYYMMDD format)
        if [[ $file =~ ([0-9]{8}) ]]; then
            file_date=${BASH_REMATCH[1]}
            if [ $file_date -lt $CUTOFF_DATE ]; then
                log "Removing old backup: $file"
                rclone delete "$RCLONE_REMOTE/$file"
            fi
        fi
    done
    
    log "Remote cleanup completed"
}

# Create backup summary
create_summary() {
    SUMMARY_FILE="$BACKUP_DIR/backup_summary_$DATE.txt"
    
    cat > $SUMMARY_FILE << EOF
SPRNOVO Backup Summary
Date: $(date)
===================

Database Backup: spr_database_$DATE.sql.gz
n8n Volume Backup: n8n_data_$DATE.tar.gz

Database Size: $(docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));")
n8n Volume Size: $(docker volume inspect $N8N_VOLUME --format '{{ .Mountpoint }}' | xargs du -sh 2>/dev/null | cut -f1 || echo "Unknown")

Backup Location: $REMOTE_PATH
Status: SUCCESS
EOF

    log "Backup summary created: $(basename $SUMMARY_FILE)"
    
    # Upload summary
    rclone copy $SUMMARY_FILE $REMOTE_PATH/ --progress
}

# Main execution
main() {
    backup_database
    backup_n8n_volume
    upload_to_spaces
    create_summary
    cleanup_local
    cleanup_remote
    
    log "=== SPRNOVO Daily Backup Completed Successfully: $(date) ==="
}

# Execute main function
main

# Send completion notification (optional)
if command -v mail &> /dev/null; then
    echo "SPRNOVO backup completed successfully on $(hostname) at $(date)" | \
    mail -s "SPRNOVO Backup Success - $(date +%Y-%m-%d)" admin@royalnegociosagricolas.com.br
fi