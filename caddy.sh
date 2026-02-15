set -euo pipefail

SRV_DIR="/home/munaim/srv/proxy/caddy"
SRV_CADDY="$SRV_DIR/Caddyfile"
OVR_DIR="$SRV_DIR/overrides"
OVR_FILE="$OVR_DIR/single_app_dashboard.caddy"
TS="$(date +%Y%m%d_%H%M%S)"
BKDIR="/home/munaim/srv/ops/caddy_backups/$TS"
mkdir -p "$BKDIR" "$OVR_DIR"

echo "== Backup Caddyfile =="
sudo cp -a "$SRV_CADDY" "$BKDIR/Caddyfile.bak"

echo "== Write override: only dashboard route; portal/ops return 404 =="
sudo tee "$OVR_FILE" >/dev/null <<'EOF'
# Single-app override (safe)
# Keep only dashboard.alshifalab.pk -> 127.0.0.1:8013
# And explicitly neutralize portal/ops.

dashboard.alshifalab.pk {
  encode gzip
  reverse_proxy 127.0.0.1:8013
}

portal.alshifalab.pk {
  respond "Not configured" 404
}

ops.alshifalab.pk {
  respond "Not configured" 404
}
EOF

echo "== Ensure Caddyfile imports overrides directory (idempotent) =="
if ! grep -qE '^[[:space:]]*import[[:space:]]+overrides/\*' "$SRV_CADDY"; then
  echo "" | sudo tee -a "$SRV_CADDY" >/dev/null
  echo "# Load local overrides (do not edit large blocks directly)" | sudo tee -a "$SRV_CADDY" >/dev/null
  echo "import overrides/*" | sudo tee -a "$SRV_CADDY" >/dev/null
fi

echo "== Sync to /etc and validate =="
sudo cp -a "$SRV_CADDY" /etc/caddy/Caddyfile
sudo caddy validate --config "$SRV_CADDY"

echo "== Reload Caddy =="
sudo systemctl reload caddy
sudo systemctl status caddy --no-pager -n 25

echo "== Probe =="
for d in dashboard.alshifalab.pk portal.alshifalab.pk ops.alshifalab.pk; do
  echo "---- $d"
  curl -k -sS -I --max-time 10 "https://$d/" | sed 's/\r$//' | head -n 12
done

echo "DONE. Backup: $BKDIR"
echo "Override file: $OVR_FILE"
