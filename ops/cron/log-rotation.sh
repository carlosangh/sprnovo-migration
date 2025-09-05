#!/bin/bash
# Log Rotation Script for SPR System
# Manages log files to prevent disk space issues

set -e

# Configuration
LOG_DIRS=(
    "/var/log/nginx"
    "/var/log/spr"
    "/opt/spr/logs"
    "/home/cadu/spr_deployment/logs"
)

RETENTION_DAYS="${RETENTION_DAYS:-30}"
MAX_SIZE="${MAX_SIZE:-100M}"
COMPRESS_LOGS="${COMPRESS_LOGS:-true}"

# Logging
SCRIPT_LOG="/var/log/spr/log-rotation.log"
mkdir -p "$(dirname "$SCRIPT_LOG")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$SCRIPT_LOG"
}

# Function to rotate logs in a directory
rotate_logs_in_dir() {
    local dir="$1"
    
    if [ ! -d "$dir" ]; then
        log "Directory does not exist: $dir"
        return
    fi
    
    log "Processing log directory: $dir"
    
    # Find log files larger than MAX_SIZE
    local large_files=$(find "$dir" -name "*.log" -type f -size +"$MAX_SIZE" 2>/dev/null || true)
    
    if [ -n "$large_files" ]; then
        echo "$large_files" | while read -r logfile; do
            rotate_large_file "$logfile"
        done
    fi
    
    # Compress old log files
    if [ "$COMPRESS_LOGS" = "true" ]; then
        find "$dir" -name "*.log.[0-9]*" -type f ! -name "*.gz" -mtime +1 -exec gzip {} \; 2>/dev/null || true
    fi
    
    # Remove old log files
    local deleted_count=0
    
    # Remove old compressed logs
    deleted_count=$(find "$dir" -name "*.log.*.gz" -type f -mtime +$RETENTION_DAYS -delete -print 2>/dev/null | wc -l)
    if [ "$deleted_count" -gt 0 ]; then
        log "Deleted $deleted_count old compressed log files from $dir"
    fi
    
    # Remove old uncompressed logs
    deleted_count=$(find "$dir" -name "*.log.[0-9]*" -type f -mtime +$RETENTION_DAYS -delete -print 2>/dev/null | wc -l)
    if [ "$deleted_count" -gt 0 ]; then
        log "Deleted $deleted_count old uncompressed log files from $dir"
    fi
    
    # Remove empty log files older than 7 days
    deleted_count=$(find "$dir" -name "*.log" -type f -empty -mtime +7 -delete -print 2>/dev/null | wc -l)
    if [ "$deleted_count" -gt 0 ]; then
        log "Deleted $deleted_count empty log files from $dir"
    fi
}

# Function to rotate a large log file
rotate_large_file() {
    local logfile="$1"
    local dir=$(dirname "$logfile")
    local basename=$(basename "$logfile" .log)
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    log "Rotating large log file: $logfile ($(du -h "$logfile" | cut -f1))"
    
    # Create numbered backup
    local backup_file="$dir/${basename}.log.${timestamp}"
    
    # Move the current log file
    mv "$logfile" "$backup_file"
    
    # Create new empty log file with same permissions
    touch "$logfile"
    chmod --reference="$backup_file" "$logfile" 2>/dev/null || chmod 644 "$logfile"
    
    # Try to preserve ownership
    if [ -O "$backup_file" ]; then
        chown --reference="$backup_file" "$logfile" 2>/dev/null || true
    fi
    
    # Send signal to processes that might be writing to the log
    restart_services_if_needed "$logfile"
    
    log "Log file rotated: $logfile -> $backup_file"
}

# Function to restart services if needed
restart_services_if_needed() {
    local logfile="$1"
    
    # Restart nginx if we rotated nginx logs
    if echo "$logfile" | grep -q nginx; then
        if systemctl is-active --quiet nginx 2>/dev/null; then
            log "Reloading nginx to reopen log files"
            systemctl reload nginx
        elif command -v service > /dev/null && service nginx status > /dev/null 2>&1; then
            log "Reloading nginx to reopen log files"
            service nginx reload
        fi
    fi
    
    # Send SIGUSR1 to PM2 processes to rotate logs
    if echo "$logfile" | grep -q spr; then
        if command -v pm2 > /dev/null && pm2 list > /dev/null 2>&1; then
            log "Sending log rotation signal to PM2 processes"
            pm2 reloadLogs 2>/dev/null || true
        fi
    fi
}

# Function to analyze disk usage
analyze_disk_usage() {
    log "=== Disk Usage Analysis ==="
    
    for dir in "${LOG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            local usage=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local file_count=$(find "$dir" -type f -name "*.log*" 2>/dev/null | wc -l)
            log "Directory $dir: $usage ($file_count log files)"
            
            # Show largest log files in this directory
            local largest=$(find "$dir" -name "*.log*" -type f -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -3)
            if [ -n "$largest" ]; then
                log "  Largest files in $dir:"
                echo "$largest" | while read -r line; do
                    local size=$(echo "$line" | awk '{print $5}')
                    local file=$(echo "$line" | awk '{print $NF}')
                    log "    $(basename "$file"): $size"
                done
            fi
        fi
    done
    
    # Check overall disk usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    log "Root filesystem usage: ${disk_usage}%"
    
    if [ "$disk_usage" -gt 85 ]; then
        log "WARNING: Disk usage is high (${disk_usage}%)"
        # Send alert if mail is available
        if command -v mail > /dev/null && [ -n "${NOTIFICATION_EMAIL:-}" ]; then
            echo "High disk usage detected: ${disk_usage}%" | \
                mail -s "SPR System Disk Usage Alert" "$NOTIFICATION_EMAIL"
        fi
    fi
}

# Function to generate log rotation report
generate_report() {
    local report_file="/var/log/spr/log-rotation-summary.log"
    
    {
        echo "=== Log Rotation Summary - $(date) ==="
        echo ""
        
        for dir in "${LOG_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                echo "Directory: $dir"
                echo "  Total size: $(du -sh "$dir" 2>/dev/null | cut -f1)"
                echo "  Log files: $(find "$dir" -name "*.log*" -type f 2>/dev/null | wc -l)"
                echo "  Compressed: $(find "$dir" -name "*.gz" -type f 2>/dev/null | wc -l)"
                echo ""
            fi
        done
        
        echo "Configuration:"
        echo "  Retention: $RETENTION_DAYS days"
        echo "  Max size: $MAX_SIZE"
        echo "  Compression: $COMPRESS_LOGS"
        echo ""
        
    } > "$report_file"
    
    log "Log rotation report generated: $report_file"
}

# Main execution
main() {
    log "=== Starting Log Rotation Process ==="
    log "Configuration: Retention=${RETENTION_DAYS}d, MaxSize=${MAX_SIZE}, Compress=${COMPRESS_LOGS}"
    
    # Analyze current disk usage
    analyze_disk_usage
    
    # Process each log directory
    for dir in "${LOG_DIRS[@]}"; do
        rotate_logs_in_dir "$dir"
    done
    
    # Generate summary report
    generate_report
    
    log "=== Log Rotation Process Completed ==="
}

# Handle command line arguments
case "${1:-}" in
    "--analyze")
        analyze_disk_usage
        ;;
    "--report")
        generate_report
        cat /var/log/spr/log-rotation-summary.log
        ;;
    "--help"|"-h")
        echo "SPR Log Rotation Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --analyze   Analyze disk usage without rotation"
        echo "  --report    Generate and display rotation report"
        echo "  --help      Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  RETENTION_DAYS - Days to keep logs (default: 30)"
        echo "  MAX_SIZE       - Maximum log file size before rotation (default: 100M)"
        echo "  COMPRESS_LOGS  - Compress old logs (default: true)"
        echo ""
        echo "Examples:"
        echo "  $0              # Run log rotation"
        echo "  $0 --analyze    # Analyze disk usage"
        echo "  $0 --report     # Show rotation report"
        ;;
    *)
        main
        ;;
esac