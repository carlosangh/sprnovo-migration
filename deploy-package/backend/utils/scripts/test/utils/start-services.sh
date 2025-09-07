#!/bin/bash
  echo "Iniciando serviços Royal..."
  if ! lsof -i :8000 > /dev/null 2>&1; then
      cd /opt/spr/backend
      python3 main.py > /opt/spr/logs/api.log 2>&1 &
      echo "API iniciada!"
  else
      echo "API já rodando!"
  fi
  if ! lsof -i :3003 > /dev/null 2>&1; then
      cd /opt/spr/wppconnect
      npm run dev > /opt/spr/logs/whatsapp.log 2>&1 &
      echo "WhatsApp iniciado!"
  else
      echo "WhatsApp já rodando!"
  fi
  echo "Serviços iniciados!"
