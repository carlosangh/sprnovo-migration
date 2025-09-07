#!/bin/bash
# Health Monitoring Script for SPR System
# Monitors system and application health

set -e

# Configuration
BACKEND_PORT="${BACKEND_PORT:-3002}"
ANALYTICS_PORT="${ANALYTICS_PORT:-8000}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
HEALTH_LOG="/var/log/spr/health-monitor.log"

# Alert thresholds
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-85}"
DISK_THRESHOLD="${DISK_THRESHOLD:-90}"
RESPONSE_TIME_THRESHOLD="${RESPONSE_TIME_THRESHOLD:-5}"

mkdir -p "$(dirname "$HEALTH_LOG")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$HEALTH_LOG"
}

# Function to send notifications
send_alert() {
    local severity="$1"
    local message="$2"
    local subject="SPR System Alert - $severity"
    
    log "ALERT [$severity]: $message"
    
    # Email notification
    if [ -n "$NOTIFICATION_EMAIL" ] && command -v mail > /dev/null; then
        echo "$message" | mail -s "$subject" "$NOTIFICATION_EMAIL"
    fi
    
    # Slack notification
    if [ -n "$SLACK_WEBHOOK" ] && command -v curl > /dev/null; then
        local color="danger"
        [ "$severity" = "WARNING" ] && color="warning"
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$subject\", \"attachments\":[{\"color\":\"$color\",\"text\":\"$message\"}]}" \
            "$SLACK_WEBHOOK" > /dev/null 2>&1 || true
    fi
    
    # System log
    logger -t spr-health "[$severity] $message"
}

# Check system resources
check_system_resources() {
    log "Checking system resources..."
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | cut -d'%' -f1)
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        send_alert "WARNING" "High CPU usage: ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
    fi
    
    # Memory usage
    local memory_info=$(free | grep Mem:)
    local total_mem=$(echo "$memory_info" | awk '{print $2}')
    local used_mem=$(echo "$memory_info" | awk '{print $3}')
    local memory_usage=$(echo "scale=1; $used_mem * 100 / $total_mem" | bc)
    
    if (( $(echo "$memory_usage > $MEMORY_THRESHOLD" | bc -l) )); then
        local mem_mb=$(echo "scale=0; $used_mem / 1024" | bc)
        local total_mb=$(echo "scale=0; $total_mem / 1024" | bc)
        send_alert "WARNING" "High memory usage: ${mem_mb}MB/${total_mb}MB (${memory_usage}%, threshold: ${MEMORY_THRESHOLD}%)"
    fi
    
    # Disk usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        local disk_info=$(df -h / | awk 'NR==2 {print $3 "/" $2}')
        send_alert "CRITICAL" "High disk usage: ${disk_info} (${disk_usage}%, threshold: ${DISK_THRESHOLD}%)"
    fi
    
    log "System resources OK - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}%"
}

# Check application health endpoints
check_application_health() {
    log "Checking application health..."
    
    # Check backend health
    local backend_status="DOWN"
    local backend_response_time=0
    
    if command -v curl > /dev/null; then
        local start_time=$(date +%s.%N)
        if curl -f -s --max-time 10 "http://localhost:$BACKEND_PORT/health" > /dev/null; then
            local end_time=$(date +%s.%N)
            backend_response_time=$(echo "$end_time - $start_time" | bc)
            backend_status="UP"
            
            # Check response time
            if (( $(echo "$backend_response_time > $RESPONSE_TIME_THRESHOLD" | bc -l) )); then
                send_alert "WARNING" "Backend slow response time: ${backend_response_time}s (threshold: ${RESPONSE_TIME_THRESHOLD}s)"
            fi
        else
            send_alert "CRITICAL" "Backend health check failed on port $BACKEND_PORT"
        fi
    fi
    
    # Check analytics engine health
    local analytics_status="DOWN"
    local analytics_response_time=0
    
    if command -v curl > /dev/null; then
        local start_time=$(date +%s.%N)
        if curl -f -s --max-time 10 "http://localhost:$ANALYTICS_PORT/health" > /dev/null 2>&1 || \
           curl -f -s --max-time 10 "http://localhost:$ANALYTICS_PORT/" > /dev/null 2>&1; then
            local end_time=$(date +%s.%N)
            analytics_response_time=$(echo "$end_time - $start_time" | bc)
            analytics_status="UP"
        else
            send_alert "WARNING" "Analytics engine health check failed on port $ANALYTICS_PORT"
        fi
    fi
    
    log "Application health - Backend: $backend_status (${backend_response_time}s), Analytics: $analytics_status (${analytics_response_time}s)"
}

# Check service status
check_services() {
    log "Checking service status..."
    
    local services=("nginx" "postgresql" "redis-server")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log "Service $service is running"
        elif command -v service > /dev/null && service "$service" status > /dev/null 2>&1; then
            log "Service $service is running"
        else
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        send_alert "WARNING" "Services down: ${failed_services[*]}"
    fi
    
    # Check PM2 processes
    if command -v pm2 > /dev/null; then
        local pm2_status=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.pm2_env.status != "online") | .name' || echo "")
        if [ -n "$pm2_status" ]; then
            send_alert "CRITICAL" "PM2 processes not online: $pm2_status"
        else
            local pm2_count=$(pm2 jlist 2>/dev/null | jq length || echo 0)
            log "PM2 processes running: $pm2_count"
        fi
    fi
}

# Check network connectivity
check_connectivity() {
    log "Checking network connectivity..."
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        send_alert "WARNING" "Internet connectivity issues detected"
    fi
    
    # Check DNS resolution
    if ! nslookup google.com > /dev/null 2>&1; then
        send_alert "WARNING" "DNS resolution issues detected"
    fi
    
    log "Network connectivity OK"
}

# Check log files for errors
check_logs_for_errors() {
    log "Checking logs for recent errors..."
    
    local error_patterns=(
        "ERROR"
        "CRITICAL"
        "FATAL"
        "Exception"
        "Traceback"
        "500 Internal Server Error"
        "502 Bad Gateway"
        "503 Service Unavailable"
    )
    
    local log_files=(
        "/var/log/nginx/error.log"
        "/var/log/spr/error.log"
        "/opt/spr/logs/error.log"
        "/home/cadu/spr_deployment/logs/error.log"
    )
    
    local recent_errors=0
    local error_details=""
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            # Check for errors in the last 5 minutes
            local recent_log=$(find "$log_file" -newermt '5 minutes ago' 2>/dev/null || echo "")
            if [ -n "$recent_log" ]; then
                for pattern in "${error_patterns[@]}"; do
                    local error_count=$(tail -n 100 "$log_file" | grep -c "$pattern" 2>/dev/null || echo 0)
                    if [ "$error_count" -gt 0 ]; then
                        recent_errors=$((recent_errors + error_count))
                        error_details="${error_details}\n$(basename "$log_file"): $error_count x $pattern"
                    fi
                done
            fi
        fi
    done
    
    if [ "$recent_errors" -gt 10 ]; then
        send_alert "WARNING" "High error rate in logs (last 5 min): $recent_errors errors$error_details"
    elif [ "$recent_errors" -gt 0 ]; then
        log "Recent errors found in logs: $recent_errors"
    else
        log "No recent errors found in logs"
    fi
}

# Generate health report
generate_health_report() {
    local report_file="/var/log/spr/health-report.json"
    
    local timestamp=$(date -Iseconds)
    local uptime=$(uptime | awk '{print $3, $4}' | sed 's/,//')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    
    cat > "$report_file" << EOF
{
  "timestamp": "$timestamp",
  "system": {
    "uptime": "$uptime",
    "load_average": "$load_avg",
    "cpu_usage": "$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')",
    "memory_usage": "$(free | grep Mem: | awk '{printf "%.1f%%", $3/$2 * 100.0}')",
    "disk_usage": "$(df -h / | awk 'NR==2 {print $5}')"
  },
  "services": {
    "nginx": "$(systemctl is-active nginx 2>/dev/null || echo 'unknown')",
    "pm2_processes": $(pm2 jlist 2>/dev/null | jq length || echo 0)
  },
  "applications": {
    "backend_port": $BACKEND_PORT,
    "analytics_port": $ANALYTICS_PORT,
    "backend_status": "$(curl -f -s --max-time 5 "http://localhost:$BACKEND_PORT/health" > /dev/null && echo 'UP' || echo 'DOWN')",
    "analytics_status": "$(curl -f -s --max-time 5 "http://localhost:$ANALYTICS_PORT/" > /dev/null && echo 'UP' || echo 'DOWN')"
  }
}
EOF
    
    log "Health report generated: $report_file"
}

# Main execution
main() {
    log "=== Starting Health Monitor Check ==="
    
    check_system_resources
    check_services
    check_application_health
    check_connectivity
    check_logs_for_errors
    generate_health_report
    
    log "=== Health Monitor Check Completed ==="
}

# Handle command line arguments
case "${1:-}" in
    "--system")
        check_system_resources
        ;;
    "--services")
        check_services
        ;;
    "--apps")
        check_application_health
        ;;
    "--logs")
        check_logs_for_errors
        ;;
    "--report")
        generate_health_report
        cat /var/log/spr/health-report.json
        ;;
    "--help"|"-h")
        echo "SPR Health Monitor Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --system    Check system resources only"
        echo "  --services  Check service status only"
        echo "  --apps      Check application health only"
        echo "  --logs      Check logs for errors only"
        echo "  --report    Generate and display health report"
        echo "  --help      Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  BACKEND_PORT         - Backend service port (default: 3002)"
        echo "  ANALYTICS_PORT       - Analytics service port (default: 8000)"
        echo "  NOTIFICATION_EMAIL   - Email for alerts"
        echo "  SLACK_WEBHOOK        - Slack webhook URL for alerts"
        echo "  CPU_THRESHOLD        - CPU usage alert threshold (default: 80%)"
        echo "  MEMORY_THRESHOLD     - Memory usage alert threshold (default: 85%)"
        echo "  DISK_THRESHOLD       - Disk usage alert threshold (default: 90%)"
        echo "  RESPONSE_TIME_THRESHOLD - Response time threshold in seconds (default: 5)"
        echo ""
        echo "Examples:"
        echo "  $0              # Run full health check"
        echo "  $0 --system     # Check system resources only"
        echo "  $0 --report     # Generate health report"
        ;;
    *)
        main
        ;;
esac