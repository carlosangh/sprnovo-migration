#!/bin/bash

# SPR - Evolution API Probe Script
# Real probing with authentication and operations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
EVO_URL="${EVO_URL:-https://evo.royalnegociosagricolas.com.br}"
EVO_APIKEY="${EVO_APIKEY:-c451bb1deb223c150b4c41ed3925bfaa91cdacf45d3d01350b2a16520c97b21c}"
INSTANCE_NAME="${INSTANCE_NAME:-ROY_01}"
TIMEOUT=30

# Usage
usage() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  base           Test base connectivity and /manager/status"
    echo "  docs           Test /docs endpoint"
    echo "  manager        Test /manager endpoints"
    echo "  instances      Test /instance/fetchInstances"
    echo "  create         Create new instance"
    echo "  connect        Connect instance and get QR/pairing"
    echo "  sendText       Send text message (requires PHONE and TEXT env vars)"
    echo "  all            Run all tests"
    echo ""
    echo "Options:"
    echo "  -u, --url URL          Evolution API URL (default: $EVO_URL)"
    echo "  -k, --apikey KEY       API Key (default: env EVO_APIKEY)"
    echo "  -i, --instance NAME    Instance name (default: $INSTANCE_NAME)"
    echo "  -t, --timeout SEC      Request timeout (default: ${TIMEOUT}s)"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  EVO_URL        Evolution API base URL"
    echo "  EVO_APIKEY     Evolution API Key"
    echo "  INSTANCE_NAME  Instance name for operations"
    echo "  PHONE          Phone number for sendText (+5566999999999)"
    echo "  TEXT           Message text for sendText"
}

# HTTP request wrapper
http_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    local url="${EVO_URL}${endpoint}"
    local headers=(-H "apikey: ${EVO_APIKEY}" -H "Content-Type: application/json")
    
    if [ -n "$data" ]; then
        curl -s --max-time "$TIMEOUT" -X "$method" "${headers[@]}" -d "$data" "$url"
    else
        curl -s --max-time "$TIMEOUT" -X "$method" "${headers[@]}" "$url"
    fi
}

# Test result helper
test_result() {
    local name="$1"
    local result="$2"
    
    echo -n "  Testing $name... "
    
    if [ "$result" = "0" ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        return 1
    fi
}

# Base connectivity test
test_base() {
    echo -e "${BLUE}BASE CONNECTIVITY TEST${NC}"
    
    # Test base URL
    if curl -s --max-time 10 "$EVO_URL" > /dev/null 2>&1; then
        test_result "Base URL connectivity" 0
    else
        test_result "Base URL connectivity" 1
        return 1
    fi
    
    # Test manager status
    local status_response
    status_response=$(http_request "GET" "/manager/status" 2>/dev/null)
    local status_code=$?
    
    if [ $status_code -eq 0 ] && echo "$status_response" | grep -q "manager\\|status\\|version"; then
        test_result "Manager status endpoint" 0
        echo "    Response: $(echo "$status_response" | jq -r '.manager.version // .version // "OK"' 2>/dev/null || echo "Connected")"
    else
        test_result "Manager status endpoint" 1
    fi
}

# Docs endpoint test
test_docs() {
    echo -e "\n${BLUE}DOCS ENDPOINT TEST${NC}"
    
    if curl -s --max-time 10 "${EVO_URL}/docs" | grep -i "swagger\\|openapi\\|documentation" > /dev/null 2>&1; then
        test_result "Documentation (/docs)" 0
    else
        test_result "Documentation (/docs)" 1
    fi
}

# Manager endpoints test
test_manager() {
    echo -e "\n${BLUE}MANAGER ENDPOINTS TEST${NC}"
    
    # Test manager/status
    local manager_response
    manager_response=$(http_request "GET" "/manager/status" 2>/dev/null)
    if [ $? -eq 0 ]; then
        test_result "GET /manager/status" 0
    else
        test_result "GET /manager/status" 1
    fi
}

# Instance operations
test_instances() {
    echo -e "\n${BLUE}INSTANCE OPERATIONS TEST${NC}"
    
    # Fetch instances
    local instances_response
    instances_response=$(http_request "GET" "/instance/fetchInstances" 2>/dev/null)
    if [ $? -eq 0 ]; then
        test_result "GET /instance/fetchInstances" 0
        local count=$(echo "$instances_response" | jq '. | length' 2>/dev/null || echo "unknown")
        echo "    Found instances: $count"
    else
        test_result "GET /instance/fetchInstances" 1
    fi
}

# Create instance
cmd_create() {
    echo -e "\n${BLUE}CREATE INSTANCE: $INSTANCE_NAME${NC}"
    
    local create_data=$(cat <<EOF
{
  "instanceName": "$INSTANCE_NAME",
  "token": "$INSTANCE_NAME",
  "qrcode": true,
  "alwaysOnline": true,
  "readMessages": true,
  "readStatus": true,
  "webhook": {
    "url": "https://royalnegociosagricolas.com.br/api/webhook/evolution",
    "by_events": true,
    "base64": false
  }
}
EOF
)
    
    local create_response
    create_response=$(http_request "POST" "/instance/create" "$create_data" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Instance created successfully${NC}"
        echo "$create_response" | jq . 2>/dev/null || echo "$create_response"
    else
        echo -e "${RED}✗ Failed to create instance${NC}"
        return 1
    fi
}

# Connect instance
cmd_connect() {
    echo -e "\n${BLUE}CONNECT INSTANCE: $INSTANCE_NAME${NC}"
    
    local connect_response
    connect_response=$(http_request "GET" "/instance/connect/$INSTANCE_NAME" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Connection initiated${NC}"
        
        # Extract QR code or pairing info
        if echo "$connect_response" | grep -q "qrcode\\|base64"; then
            echo "QR Code available in response (base64)"
        fi
        
        if echo "$connect_response" | grep -q "pairingCode"; then
            local pairing_code=$(echo "$connect_response" | jq -r '.pairingCode // empty' 2>/dev/null)
            if [ -n "$pairing_code" ]; then
                echo "Pairing Code: $pairing_code"
            fi
        fi
        
        echo "$connect_response" | jq . 2>/dev/null || echo "$connect_response"
    else
        echo -e "${RED}✗ Failed to connect instance${NC}"
        return 1
    fi
}

# Send text message
cmd_send_text() {
    echo -e "\n${BLUE}SEND TEXT MESSAGE${NC}"
    
    if [ -z "$PHONE" ] || [ -z "$TEXT" ]; then
        echo -e "${RED}✗ PHONE and TEXT environment variables required${NC}"
        echo "Usage: PHONE='+5566999999999' TEXT='Hello SPR' $0 sendText"
        return 1
    fi
    
    local send_data=$(cat <<EOF
{
  "number": "$PHONE",
  "textMessage": {
    "text": "$TEXT"
  }
}
EOF
)
    
    local send_response
    send_response=$(http_request "POST" "/message/sendText/$INSTANCE_NAME" "$send_data" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Message sent successfully${NC}"
        echo "To: $PHONE"
        echo "Text: $TEXT"
        echo "$send_response" | jq . 2>/dev/null || echo "$send_response"
    else
        echo -e "${RED}✗ Failed to send message${NC}"
        return 1
    fi
}

# Run all tests
cmd_all() {
    test_base
    test_docs
    test_manager
    test_instances
    
    echo -e "\n${YELLOW}Operations (require manual execution):${NC}"
    echo "  $0 create    - Create instance $INSTANCE_NAME"
    echo "  $0 connect   - Connect and get QR code"
    echo "  PHONE='+5566...' TEXT='Hello' $0 sendText - Send message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            EVO_URL="$2"
            shift 2
            ;;
        -k|--apikey)
            EVO_APIKEY="$2"
            shift 2
            ;;
        -i|--instance)
            INSTANCE_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        base|docs|manager|instances|create|connect|sendText|all)
            COMMAND="$1"
            shift
            break
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
echo "🔍 SPR Evolution API Probe"
echo "=========================="
echo "URL: $EVO_URL"
echo "Instance: $INSTANCE_NAME"
echo "Timeout: ${TIMEOUT}s"
echo ""

case "${COMMAND:-all}" in
    base)     test_base ;;
    docs)     test_docs ;;
    manager)  test_manager ;;
    instances) test_instances ;;
    create)   cmd_create ;;
    connect)  cmd_connect ;;
    sendText) cmd_send_text ;;
    all)      cmd_all ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac