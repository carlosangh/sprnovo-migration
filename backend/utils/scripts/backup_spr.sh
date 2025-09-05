#!/usr/bin/env bash
set -euo pipefail
BASE="/opt/spr"; SEC="$BASE/.secrets/spaces.env"; LOG="$BASE/_logs/backup_spr.log"
TS=$(date +%Y%m%d_%H%M%S); OUT="$BASE/_backups/backup_spr_$TS.tar.gz"
echo "[$(date)] SPR backup -> $OUT" | tee -a "$LOG"
tar --exclude="node_modules" -C "$BASE" -czf "$OUT" backend_server_fixed.js new_endpoints.js basis_endpoints.js package.json ecosystem.config.cjs dist _logs .secrets >/dev/null 2>&1 || true
# retenção local 14
ls -1t "$BASE/_backups"/backup_spr_*.tar.gz | tail -n +15 | xargs -r rm -f
# offsite se credenciais
if [ -f "$SEC" ]; then
  set -a; . "$SEC"; set +a
  if [ -n "${SPACES_KEY:-}" ] && [ -n "${SPACES_SECRET:-}" ] && [ -n "${SPACES_BUCKET:-}" ]; then
    endpoint="${SPACES_ENDPOINT:-https://nyc3.digitaloceanspaces.com}"
    AWS_ACCESS_KEY_ID="$SPACES_KEY" AWS_SECRET_ACCESS_KEY="$SPACES_SECRET" \
    aws s3 cp "$OUT" "s3://$SPACES_BUCKET/spr/$TS.tar.gz" --endpoint-url "$endpoint" --no-progress \
      && echo "[$(date)] SPR offsite OK" | tee -a "$LOG" || echo "[offsite] FAIL" | tee -a "$LOG"
  else
    echo "[offsite] SKIP: creds faltando" | tee -a "$LOG"
  fi
else
  echo "[offsite] SKIP: spaces.env ausente" | tee -a "$LOG"
fi
# restore-test
TST="/tmp/spr_restore_$TS"; mkdir -p "$TST"; tar -tzf "$OUT" >/dev/null && tar -xzf "$OUT" -C "$TST" dist >/dev/null 2>&1 \
  && echo "[restore-test] OK em $TST" | tee -a "$LOG" || echo "[restore-test] FAIL" | tee -a "$LOG"
