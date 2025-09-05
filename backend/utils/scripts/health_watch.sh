#!/usr/bin/env bash
set -euo pipefail
BASE=/opt/spr; LOG=$BASE/_logs; STATE=$BASE/_state; SECR=$BASE/.secrets; PM2=$(command -v pm2 || echo /usr/bin/pm2)
mkdir -p "$LOG" "$STATE" "$SECR"
ts(){ date +'%F %T'; }
read_env(){ [ -f "$SECR/alerts.env" ] && set -a && . "$SECR/alerts.env" && set +a || true; }
send_tg(){ [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ] && curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d parse_mode=HTML --data-urlencode text="$1" >/dev/null || true; }
ENDPTS=(
  "/api/news/latest" "/api/reports/wasde/latest" "/api/us/crop-progress" "/api/cftc/cot" "/api/us/drought/latest" "/api/eia/ethanol/latest" "/api/intel/status"
)
BASEURL="http://127.0.0.1"
OK=0; FAIL=0; REPORT="[$(ts)] SPR health check"
for u in "${ENDPTS[@]}"; do read -r code time <<<"$(curl -s -o /dev/null -w "%{http_code} %{time_total}" "$BASEURL$u" || echo "000 0")"; if [ "$code" = "200" ]; then OK=$((OK+1)); REPORT+=$'\\n'"✓ $u [$code em ${time}s]"; else FAIL=$((FAIL+1)); REPORT+=$'\\n'"✗ $u [$code]"; fi; done
echo "$REPORT" | tee -a "$LOG/health_watch.log" >/dev/null
CNT_FILE="$STATE/health_fail.count"; CNT=0; [ -f "$CNT_FILE" ] && CNT=$(cat "$CNT_FILE" 2>/dev/null || echo 0)
if [ "$FAIL" -gt 0 ]; then CNT=$((CNT+1)); else CNT=0; fi; echo "$CNT" > "$CNT_FILE"
# Diagnóstico Nginx vs backend
if [ "$FAIL" -gt 0 ]; then CODE3002=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:3002/api/intel/status" || echo 000); if [ "$CODE3002" = "200" ]; then read_env; send_tg "<b>SPR</b>: proxy Nginx falhando (80), backend :3002 OK. $FAIL falha(s)."; fi; fi
# Auto-heal após 3 ciclos ruins
if [ "$CNT" -ge 3 ]; then echo "[$(ts)] Autoheal: pm2 reload spr-backend (cnt=$CNT)" | tee -a "$LOG/health_watch.log"; $PM2 reload spr-backend --update-env || $PM2 start "$BASE/ecosystem.config.cjs" --only spr-backend || true; read_env; send_tg "<b>SPR</b>: autoheal acionado, reiniciei <code>spr-backend</code> (falhas consecutivas: $CNT)."; echo 0 > "$CNT_FILE"; fi
