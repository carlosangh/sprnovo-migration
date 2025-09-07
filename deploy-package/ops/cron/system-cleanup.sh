#!/bin/bash
# System Cleanup Script for SPR System
# Performs weekly maintenance and cleanup tasks

set -e

# Configuration
TEMP_DIRS=(
    "/tmp"
    "/var/tmp"
    "/opt/spr/tmp"
    "/home/cadu/spr_deployment/tmp"
)

CACHE_DIRS=(
    "/var/cache/nginx"
    "/opt/spr/cache"
    "/home/cadu/.npm"
    "/home/cadu/.cache"
)

LOG_FILE="/var/log/spr/system-cleanup.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Clean temporary files
cleanup_temp_files() {
    log "Cleaning temporary files..."
    
    local total_freed=0
    
    for temp_dir in "${TEMP_DIRS[@]}"; do
        if [ -d "$temp_dir" ]; then
            log "Processing temp directory: $temp_dir"
            
            # Calculate current size
            local before_size=$(du -sb "$temp_dir" 2>/dev/null | cut -f1 || echo 0)
            
            # Remove files older than 7 days
            find "$temp_dir" -type f -atime +7 -delete 2>/dev/null || true
            
            # Remove empty directories
            find "$temp_dir" -type d -empty -delete 2>/dev/null || true
            
            # Calculate freed space
            local after_size=$(du -sb "$temp_dir" 2>/dev/null | cut -f1 || echo 0)
            local freed=$((before_size - after_size))
            total_freed=$((total_freed + freed))
            
            if [ $freed -gt 0 ]; then
                local freed_mb=$((freed / 1024 / 1024))
                log "  Freed ${freed_mb}MB from $temp_dir"
            fi
        fi
    done
    
    local total_freed_mb=$((total_freed / 1024 / 1024))
    log "Total temporary files cleaned: ${total_freed_mb}MB"
}

# Clean cache directories
cleanup_cache() {
    log "Cleaning cache directories..."
    
    for cache_dir in "${CACHE_DIRS[@]}"; do
        if [ -d "$cache_dir" ]; then
            log "Processing cache directory: $cache_dir"
            
            case "$cache_dir" in
                *nginx*)
                    # Clean nginx cache but preserve structure
                    find "$cache_dir" -type f -mtime +30 -delete 2>/dev/null || true
                    ;;
                *npm*)
                    # Clean old npm cache
                    if [ -w "$cache_dir" ]; then
                        npm cache clean --force 2>/dev/null || true
                    fi
                    ;;
                *)
                    # Generic cache cleanup
                    find "$cache_dir" -type f -mtime +14 -delete 2>/dev/null || true
                    ;;
            esac
        fi
    done
}

# Clean old package files
cleanup_packages() {
    log "Cleaning old package files..."
    
    # Clean apt cache (if running on Debian/Ubuntu)
    if command -v apt-get > /dev/null; then
        log "Cleaning apt cache..."
        apt-get clean 2>/dev/null || true
        apt-get autoclean 2>/dev/null || true
        
        # Remove orphaned packages
        local orphaned=$(apt list --installed 2>/dev/null | grep -c "automatically installed" || echo 0)
        if [ "$orphaned" -gt 0 ]; then
            log "Found $orphaned potentially orphaned packages"
            apt-get autoremove -y 2>/dev/null || true
        fi
    fi
    
    # Clean yum cache (if running on Red Hat/CentOS)
    if command -v yum > /dev/null; then
        log "Cleaning yum cache..."
        yum clean all 2>/dev/null || true
    fi
}

# Clean old kernels (keep last 2)
cleanup_old_kernels() {
    log "Checking for old kernels..."
    
    if command -v dpkg > /dev/null; then
        # Ubuntu/Debian
        local current_kernel=$(uname -r)
        local installed_kernels=$(dpkg -l | grep linux-image | grep -v "$current_kernel" | wc -l)
        
        if [ "$installed_kernels" -gt 2 ]; then
            log "Found $installed_kernels old kernels (keeping current + 1 backup)"
            # This is commented out for safety - uncomment if you want automatic kernel cleanup
            # apt-get autoremove --purge -y
        else
            log "Kernel cleanup not needed ($installed_kernels old kernels found)"
        fi
    fi
}

# Clean old logs (complement to log rotation)
cleanup_old_logs() {
    log "Cleaning very old log files..."
    
    local log_dirs=(
        "/var/log"
        "/opt/spr/logs"
        "/home/cadu/spr_deployment/logs"
    )
    
    for log_dir in "${log_dirs[@]}"; do
        if [ -d "$log_dir" ]; then
            # Remove very old compressed logs (older than 90 days)
            local old_logs=$(find "$log_dir" -name "*.gz" -type f -mtime +90 2>/dev/null | wc -l)
            if [ "$old_logs" -gt 0 ]; then
                log "Removing $old_logs very old compressed logs from $log_dir"
                find "$log_dir" -name "*.gz" -type f -mtime +90 -delete 2>/dev/null || true
            fi
            
            # Remove empty log directories
            find "$log_dir" -type d -empty -delete 2>/dev/null || true
        fi
    done
}

# Clean Docker resources (if Docker is installed)
cleanup_docker() {
    if command -v docker > /dev/null; then
        log "Cleaning Docker resources..."
        
        # Remove unused containers, networks, images
        docker system prune -f 2>/dev/null || true
        
        # Remove dangling images
        local dangling=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
        if [ "$dangling" -gt 0 ]; then
            log "Removing $dangling dangling Docker images"
            docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
        fi
        
        # Clean build cache
        docker builder prune -f 2>/dev/null || true
    fi
}

# Optimize databases
optimize_databases() {
    log "Optimizing databases..."
    
    # PostgreSQL maintenance
    if command -v psql > /dev/null && [ -n "${DATABASE_URL:-}" ]; then
        if echo "$DATABASE_URL" | grep -q "postgres"; then
            log "Running PostgreSQL maintenance..."
            psql "$DATABASE_URL" -c "VACUUM ANALYZE;" 2>/dev/null || log "PostgreSQL maintenance failed"
        fi
    fi
    
    # SQLite maintenance (if using SQLite)
    local sqlite_dbs=$(find /opt/spr -name "*.db" -o -name "*.sqlite*" 2>/dev/null || true)
    if [ -n "$sqlite_dbs" ]; then
        echo "$sqlite_dbs" | while read -r db_file; do
            if [ -f "$db_file" ] && [ -w "$db_file" ]; then
                log "Optimizing SQLite database: $db_file"
                sqlite3 "$db_file" "VACUUM;" 2>/dev/null || true
            fi
        done
    fi
}

# Generate cleanup report
generate_cleanup_report() {
    local report_file="/var/log/spr/cleanup-report.log"
    
    {
        echo "=== System Cleanup Report - $(date) ==="
        echo ""
        
        # Disk usage after cleanup
        echo "Current disk usage:"
        df -h | grep -E "^/dev"
        echo ""
        
        # Memory usage
        echo "Memory usage:"
        free -h
        echo ""
        
        # Process summary
        echo "Top processes by memory:"
        ps aux --sort=-%mem | head -10
        echo ""
        
        # Log summary
        echo "Log file counts:"
        find /var/log -name "*.log*" -type f 2>/dev/null | wc -l
        echo "Compressed logs:"
        find /var/log -name "*.gz" -type f 2>/dev/null | wc -l
        echo ""
        
        # Service status
        echo "Key service status:"
        systemctl is-active nginx 2>/dev/null || echo "nginx: unknown"
        systemctl is-active postgresql 2>/dev/null || echo "postgresql: unknown"
        if command -v pm2 > /dev/null; then
            echo "PM2 processes: $(pm2 jlist 2>/dev/null | jq length || echo 0)"
        fi
        echo ""
        
    } > "$report_file"
    
    log "Cleanup report generated: $report_file"
}

# Main execution
main() {
    log "=== Starting System Cleanup Process ==="
    
    # Record initial disk usage
    local initial_usage=$(df -h / | awk 'NR==2 {print $3}')
    log "Initial disk usage: $initial_usage"
    
    cleanup_temp_files
    cleanup_cache
    cleanup_packages
    cleanup_old_kernels
    cleanup_old_logs
    cleanup_docker
    optimize_databases
    
    # Record final disk usage
    local final_usage=$(df -h / | awk 'NR==2 {print $3}')
    log "Final disk usage: $final_usage"
    
    generate_cleanup_report
    
    log "=== System Cleanup Process Completed ==="
}

# Handle command line arguments
case "${1:-}" in
    "--temp")
        cleanup_temp_files
        ;;
    "--cache")
        cleanup_cache
        ;;
    "--packages")
        cleanup_packages
        ;;
    "--logs")
        cleanup_old_logs
        ;;
    "--docker")
        cleanup_docker
        ;;
    "--database")
        optimize_databases
        ;;
    "--report")
        generate_cleanup_report
        cat /var/log/spr/cleanup-report.log
        ;;
    "--help"|"-h")
        echo "SPR System Cleanup Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --temp      Clean temporary files only"
        echo "  --cache     Clean cache directories only"
        echo "  --packages  Clean package cache only"
        echo "  --logs      Clean old log files only"
        echo "  --docker    Clean Docker resources only"
        echo "  --database  Optimize databases only"
        echo "  --report    Generate and display cleanup report"
        echo "  --help      Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0          # Run full cleanup"
        echo "  $0 --temp   # Clean temporary files only"
        echo "  $0 --report # Show cleanup report"
        ;;
    *)
        main
        ;;
esac