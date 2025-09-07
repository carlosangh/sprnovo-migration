#!/bin/bash

# SPR - Evolution API Admin Script
# Docker Compose wrapper for Evolution API management

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
COMPOSE_FILE="docker-compose.yml"
PROJECT_NAME="sprnovo"

# Change to project directory
cd "$(dirname "$0")/.."

# Usage
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  up [service]      Start services (default: all)"
    echo "  down              Stop and remove all services"
    echo "  ps                Show running containers status"
    echo "  logs [service]    Show logs (default: evolution-api)"
    echo ""
    echo "Examples:"
    echo "  $0 up             Start all services (pg, redis, evolution-api)"
    echo "  $0 up pg          Start only PostgreSQL"
    echo "  $0 down           Stop all services"
    echo "  $0 ps             Show container status"
    echo "  $0 logs           Show Evolution API logs"
    echo "  $0 logs pg        Show PostgreSQL logs"
}

# Execute docker-compose command
docker_compose() {
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" "$@"
}

# Start services
cmd_up() {
    local service="$1"
    
    echo -e "${BLUE}Starting Evolution API services...${NC}"
    
    if [ -n "$service" ]; then
        echo "Service: $service"
        docker_compose up -d "$service"
    else
        echo "Services: pg, redis, evolution-api"
        docker_compose up -d
    fi
    
    echo -e "${GREEN}✓ Services started${NC}"
    
    # Wait a bit and show status
    sleep 3
    cmd_ps
    
    # Show quick health check
    echo -e "\n${BLUE}Quick Health Check:${NC}"
    echo "PostgreSQL: $(docker_compose ps pg | grep -q "Up" && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Stopped${NC}")"
    echo "Redis: $(docker_compose ps redis | grep -q "Up" && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Stopped${NC}")"
    echo "Evolution API: $(docker_compose ps evolution-api | grep -q "Up" && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Stopped${NC}")"
    
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "• Wait 30-60 seconds for Evolution API to fully initialize"
    echo "• Check logs: $0 logs"
    echo "• Test API: curl http://localhost:8080/manager/status"
    echo "• Use probe: ./scripts/evo_probe.sh base"
}

# Stop services
cmd_down() {
    echo -e "${BLUE}Stopping Evolution API services...${NC}"
    
    docker_compose down
    
    echo -e "${GREEN}✓ All services stopped and removed${NC}"
    
    # Show volume status
    echo -e "\n${BLUE}Data volumes (preserved):${NC}"
    docker volume ls | grep -E "(pgdata|redis_data|evolution_instances)" || echo "No volumes found"
}

# Show container status
cmd_ps() {
    echo -e "${BLUE}Evolution API Services Status:${NC}"
    echo ""
    
    # Custom status format
    docker_compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    
    # Health check summary
    local pg_status=$(docker_compose ps -q pg | xargs -r docker inspect --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    local redis_status=$(docker_compose ps -q redis | xargs -r docker inspect --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
    local evo_status=$(docker_compose ps -q evolution-api | xargs -r docker inspect --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    
    echo -e "${BLUE}Health Status:${NC}"
    echo "PostgreSQL: $pg_status"
    echo "Redis: $redis_status"
    echo "Evolution API: $evo_status"
    
    # Port information
    echo -e "\n${BLUE}Access URLs:${NC}"
    echo "Evolution API: http://localhost:8080"
    echo "PostgreSQL: localhost:5432 (user: spr_user, db: evolution)"
    echo "Redis: localhost:6379"
}

# Show logs
cmd_logs() {
    local service="${1:-evolution-api}"
    local lines="${2:-50}"
    
    echo -e "${BLUE}Showing logs for: $service (last $lines lines)${NC}"
    echo "Press Ctrl+C to exit"
    echo ""
    
    if [ "$service" = "all" ]; then
        docker_compose logs -f --tail="$lines"
    else
        docker_compose logs -f --tail="$lines" "$service"
    fi
}

# Validate docker-compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}✗ Error: $COMPOSE_FILE not found${NC}"
    echo "Make sure you're in the project root directory"
    exit 1
fi

# Parse command
case "${1:-}" in
    up)
        cmd_up "$2"
        ;;
    down)
        cmd_down
        ;;
    ps|status)
        cmd_ps
        ;;
    logs)
        cmd_logs "$2" "$3"
        ;;
    -h|--help|help)
        usage
        ;;
    "")
        echo -e "${YELLOW}No command specified${NC}"
        usage
        exit 1
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        usage
        exit 1
        ;;
esac