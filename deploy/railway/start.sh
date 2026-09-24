#!/usr/bin/env bash
# Railway container entrypoint. Runs three processes and exits when any of
# them does, so Railway's restart policy brings the whole container back:
#   1. Caddy on Railway's $PORT: basic auth in front of the app.
#   2. The Docker self-host entrypoint (preflight, migrations, vite preview)
#      on an internal port.
#   3. A 5-minute tick that fires the worker's scheduled handler, standing in
#      for the "*/5 * * * *" cron in wrangler.jsonc (rank checks, stale-audit
#      reconcile), which Docker self-hosting otherwise never runs.
set -euo pipefail

: "${OPENSEO_USERNAME:?Set the OPENSEO_USERNAME variable on the Railway service}"
: "${OPENSEO_PASSWORD:?Set the OPENSEO_PASSWORD variable on the Railway service}"

export APP_PORT=3001
export PORT="${PORT:-8080}"
OPENSEO_PASSWORD_HASH="$(caddy hash-password --plaintext "$OPENSEO_PASSWORD")"
export OPENSEO_PASSWORD_HASH

caddy run --config deploy/railway/Caddyfile --adapter caddyfile &

PORT="$APP_PORT" sh docker-entrypoint.sh &

(
  while sleep 300; do
    curl -fsS -o /dev/null "http://127.0.0.1:${APP_PORT}/cdn-cgi/handler/scheduled?cron=*/5+*+*+*+*" \
      || echo "[scheduler] tick failed"
  done
) &

wait -n
