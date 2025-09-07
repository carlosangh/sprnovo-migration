#!/bin/bash
  echo "Parando serviços Royal..."
  pkill -f "python3 main.py"
  pkill -f "npm run dev"
  killall node 2>/dev/null
  echo "Serviços parados!"
