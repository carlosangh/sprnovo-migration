#!/usr/bin/env bash
set -euo pipefail

# Configuração via ambiente
: "${EVO_URL:=https://evo.royalnegociosagricolas.com.br}"
: "${EVO_APIKEY:=CHANGE_ME_APIKEY}"
: "${INSTANCE:=ROY_01}"
: "${PHONE:=+5566XXXXXXXXX}"
: "${TEXT:=Teste SPRNOVO via Evolution API}"

h() {
  cat <<EOF
Uso:
  EVO_URL=$EVO_URL EVO_APIKEY=<apikey> INSTANCE=$INSTANCE PHONE=$PHONE TEXT="$TEXT" $0 [create|connect|send]

Exemplos:
  EVO_APIKEY=abc123 $0 create
  EVO_APIKEY=abc123 INSTANCE=ROY_01 $0 connect
  EVO_APIKEY=abc123 INSTANCE=ROY_01 PHONE=+5566... TEXT="Olá!" $0 send
EOF
}

create() {
  curl -sS -X POST "$EVO_URL/instance/create" \
    -H "apikey: $EVO_APIKEY" -H "Content-Type: application/json" \
    -d "{\"instanceName\":\"$INSTANCE\",\"token\":\"$INSTANCE\",\"qrcode\":true,\"alwaysOnline\":true,\"readMessages\":true,\"readStatus\":true}" | jq .
}

connect() {
  curl -sS "$EVO_URL/instance/connect/$INSTANCE" \
    -H "apikey: $EVO_APIKEY" | jq .
}

send() {
  curl -sS -X POST "$EVO_URL/message/sendText/$INSTANCE" \
    -H "apikey: $EVO_APIKEY" -H "Content-Type: application/json" \
    -d "{\"number\":\"$PHONE\",\"text\":\"$TEXT\"}" | jq .
}

cmd="${1:-help}"
case "$cmd" in
  create) create ;;
  connect) connect ;;
  send) send ;;
  *) h ;;
esac