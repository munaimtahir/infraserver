#!/usr/bin/env bash
set -euo pipefail

SRC="/home/munaim/srv/proxy/caddy/Caddyfile"
DST="/etc/caddy/Caddyfile"
BACKUP="/etc/caddy/Caddyfile.bak.$(date +%F_%H%M%S)"

sudo -n caddy validate --config "$SRC" --adapter caddyfile
sudo -n cp "$DST" "$BACKUP"
sudo -n install -m 0644 -o root -g root "$SRC" "$DST"
sudo -n systemctl reload caddy

checks=(
  "https://portal.alshifalab.pk|200"
  "https://lims.alshifalab.pk|200"
  "https://api.lims.alshifalab.pk/healthz|200"
  "https://rims.alshifalab.pk|200"
  "https://api.rims.alshifalab.pk/healthz|200"
  "https://phc.alshifalab.pk|200"
  "https://api.phc.alshifalab.pk/healthz|200"
  "https://grafana.alshifalab.pk|401"
  "https://dashboard.alshifalab.pk|401"
  "https://sims.alshifalab.pk|503"
  "https://api.sims.alshifalab.pk|503"
  "https://pgsims.alshifalab.pk|503"
  "https://api.pgsims.alshifalab.pk|503"
  "https://consult.alshifalab.pk|503"
  "https://api.consult.alshifalab.pk|503"
  "https://sos.alshifalab.pk|503"
)

printf '%-45s %-8s %-8s %-6s\n' "ENDPOINT" "EXPECTED" "ACTUAL" "OK"
for item in "${checks[@]}"; do
  endpoint="${item%%|*}"
  expected="${item##*|}"
  hostport="${endpoint#https://}"
  host="${hostport%%/*}"
  actual=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 8 --resolve "$host:443:127.0.0.1" "$endpoint" || true)
  ok="NO"
  [[ "$actual" == "$expected" ]] && ok="YES"
  printf '%-45s %-8s %-8s %-6s\n' "$endpoint" "$expected" "$actual" "$ok"
done

echo "Backup created: $BACKUP"
