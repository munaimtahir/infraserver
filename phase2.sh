cd /home/munaim/srv

TS=$(date +%Y%m%d_%H%M%S)
BKDIR="/home/munaim/srv/ops/caddy_backups/$TS"
mkdir -p "$BKDIR"

SRV_CADDY="/home/munaim/srv/proxy/caddy/Caddyfile"
ETC_CADDY="/etc/caddy/Caddyfile"

sudo cp -a "$SRV_CADDY" "$BKDIR/Caddyfile.bak"

echo "== Commenting out portal + ops blocks safely =="

sudo sed -i '/portal\.alshifalab\.pk/,/}/ s/^/# DISABLED_PORTAL_/' "$SRV_CADDY"
sudo sed -i '/ops\.alshifalab\.pk/,/}/ s/^/# DISABLED_OPS_/' "$SRV_CADDY"

echo "== Append canonical dashboard routing =="

cat <<'EOF' | sudo tee -a "$SRV_CADDY" >/dev/null

# ============================================================
# ACTIVE ROUTE (Single App Mode)
# ============================================================

dashboard.alshifalab.pk {
  encode gzip
  reverse_proxy 127.0.0.1:8013
}
EOF

echo "== Sync to /etc =="
sudo cp -a "$SRV_CADDY" "$ETC_CADDY"

echo "== Validate =="
sudo caddy validate --config "$SRV_CADDY"

echo "== Reload =="
sudo systemctl reload caddy

echo "== Test =="
curl -I https://dashboard.alshifalab.pk
curl -I https://portal.alshifalab.pk
curl -I https://ops.alshifalab.pk

echo "DONE"
