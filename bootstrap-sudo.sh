#!/bin/bash
# =============================================================================
# Al-Shifa VPS Full Restoration Bootstrap
# Run as: sudo bash /home/munaim/srv/bootstrap-sudo.sh
# =============================================================================
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${BLUE}[BOOTSTRAP]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

SRV="/home/munaim/srv"
APPS="$SRV/apps"
OPS="$SRV/ops"

log "=== Al-Shifa VPS Full Restoration Bootstrap ==="
echo ""

# ─────────────────────────────────────────────
# 1. SYSTEM: docker group + PATH
# ─────────────────────────────────────────────
log "1) System setup: docker group and PATH"

# Add munaim to docker group if not already
if ! id -nG munaim | grep -qw docker; then
    usermod -aG docker munaim
    ok "Added munaim to docker group (requires re-login to take effect)"
else
    ok "munaim already in docker group"
fi

# Add ops/bin to PATH for all users
cat > /etc/profile.d/ops-path.sh << 'EOF'
export PATH="$PATH:/home/munaim/srv/ops/bin"
EOF
chmod 644 /etc/profile.d/ops-path.sh
ok "ops/bin added to system PATH via /etc/profile.d/ops-path.sh"

# ─────────────────────────────────────────────
# 2. OPERATIONAL DIRECTORIES
# ─────────────────────────────────────────────
log "2) Ensuring operational directories exist"
mkdir -p "$OPS"/{logs,backups,caddy_backups,truth_audit}
mkdir -p "$SRV/proxy/caddy"/{logs,overrides}
chown -R munaim:munaim "$OPS"/{logs,backups,caddy_backups,truth_audit}
ok "Operational directories ready"

# ─────────────────────────────────────────────
# 3. CADDY: symlink + enable + start
# ─────────────────────────────────────────────
log "3) Caddy configuration and service"

REPO_CF="$SRV/proxy/caddy/Caddyfile"
ETC_CF="/etc/caddy/Caddyfile"

# Backup and symlink
if [ -f "$ETC_CF" ] && [ ! -L "$ETC_CF" ]; then
    TS=$(date +%Y%m%d_%H%M%S)
    mv "$ETC_CF" "${ETC_CF}.bak.${TS}"
    warn "Backed up existing /etc/caddy/Caddyfile to ${ETC_CF}.bak.${TS}"
fi

if [ -L "$ETC_CF" ] && [ "$(readlink -f "$ETC_CF")" = "$REPO_CF" ]; then
    ok "Caddyfile symlink already correct"
else
    [ -L "$ETC_CF" ] && rm "$ETC_CF"
    ln -s "$REPO_CF" "$ETC_CF"
    ok "Caddyfile symlinked: $REPO_CF -> $ETC_CF"
fi

# Ensure /var/log/caddy exists
mkdir -p /var/log/caddy
chown caddy:caddy /var/log/caddy 2>/dev/null || chown root:root /var/log/caddy || true

# Validate before starting
log "Validating Caddy config..."
if caddy validate --config "$REPO_CF" 2>&1 | grep -q "Valid configuration"; then
    ok "Caddy config is valid"
else
    # Show what caddy says
    caddy validate --config "$REPO_CF" 2>&1 || true
    warn "Caddy config validation had issues (see above). Attempting start anyway."
fi

# Enable and start Caddy
systemctl enable caddy
systemctl restart caddy
sleep 2
if systemctl is-active --quiet caddy; then
    ok "Caddy is running"
else
    err "Caddy failed to start. Check: journalctl -u caddy -n 50"
    systemctl status caddy --no-pager -n 20 || true
fi

# ─────────────────────────────────────────────
# 4. INSTALL BACKUP SYSTEMD TIMER
# ─────────────────────────────────────────────
log "4) Installing backup systemd timer"

# Use pre-existing systemd unit files from repo if available
SYSTEMD_DIR="$OPS/systemd"

if [ -f "$SYSTEMD_DIR/ops-backup.service" ]; then
    cp "$SYSTEMD_DIR/ops-backup.service" /etc/systemd/system/ops-backup.service
    ok "Installed ops-backup.service from repo"
else
    cat > /etc/systemd/system/ops-backup.service << EOF
[Unit]
Description=Daily Production Backup
After=docker.service

[Service]
Type=oneshot
ExecStart=$OPS/bin/ops-backup-now
User=munaim
Group=munaim
EOF
    ok "Created ops-backup.service"
fi

if [ -f "$SYSTEMD_DIR/ops-backup.timer" ]; then
    cp "$SYSTEMD_DIR/ops-backup.timer" /etc/systemd/system/ops-backup.timer
    ok "Installed ops-backup.timer from repo"
else
    cat > /etc/systemd/system/ops-backup.timer << EOF
[Unit]
Description=Run Production Backup Daily

[Timer]
OnCalendar=*-*-* 02:15:00 Asia/Karachi
Persistent=true
Unit=ops-backup.service

[Install]
WantedBy=timers.target
EOF
    ok "Created ops-backup.timer"
fi

# Install other systemd units from repo
for svc in ops-agent.service ops-prune.service ops-prune.timer ops-validate.service ops-validate.timer; do
    if [ -f "$SYSTEMD_DIR/$svc" ]; then
        cp "$SYSTEMD_DIR/$svc" /etc/systemd/system/$svc
        ok "Installed $svc"
    fi
done

systemctl daemon-reload
systemctl enable --now ops-backup.timer
ok "Backup timer enabled"

# ─────────────────────────────────────────────
# 5. START ALL APPLICATIONS
# ─────────────────────────────────────────────
log "5) Starting all production applications"

start_app() {
    local name="$1"
    local compose="$2"
    local workdir
    workdir="$(dirname "$compose")"

    log "  Starting $name (compose: $compose)"
    if [ ! -f "$compose" ]; then
        err "  Compose file not found: $compose"
        return 1
    fi

    cd "$workdir"
    docker compose -p "prod_${name}" -f "$(basename "$compose")" up -d --build 2>&1 | tail -5 || {
        err "  Failed to start $name"
        return 1
    }
    ok "  $name started"
    cd "$SRV"
}

# App list: name → compose path
start_app "lims"          "$APPS/lims/docker-compose.prod.yml"
start_app "radreport"     "$APPS/radreport/docker-compose.prod.yml"
start_app "fmu-platform"  "$APPS/fmu-platform/docker-compose.prod.yml"
start_app "pgsims"        "$APPS/pgsims/docker-compose.prod.yml"
start_app "consult"       "$APPS/consult/docker-compose.prod.yml"
start_app "accredivault"  "$APPS/accredivault/infra/docker-compose.prod.yml"
start_app "mediq"         "$APPS/mediq/infra/docker/compose/docker-compose.prod.yml"
start_app "dashboard"     "$APPS/dashboard/docker-compose.yml"

# ─────────────────────────────────────────────
# 6. WAIT FOR CONTAINERS AND VERIFY PORTS
# ─────────────────────────────────────────────
log "6) Waiting for containers to start (60 seconds)..."
sleep 60

log "7) Verifying port bindings"
echo ""
echo "─── Listening ports (127.0.0.1:8xxx / 127.0.0.1:3xxx / 127.0.0.1:18xxx) ───"
ss -ltnp | grep -E ":(8[0-9]{3}|3025|18000)\b" | sort || true
echo ""

echo "─── Docker container status ───"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | sort || true
echo ""

# Quick health probes on expected ports
log "8) Quick localhost health probes"
declare -A PORTS=(
    [lims]=8012
    [rims-backend]=8015
    [rims-frontend]=8081
    [sims-backend]=8010
    [sims-frontend]=8080
    [pgsims-backend]=8014
    [pgsims-frontend]=8082
    [consult]=8011
    [accredivault]=8016
    [mediq-backend]=8025
    [mediq-frontend]=3025
    [dashboard-frontend]=8013
    [dashboard-backend]=18000
)

for svc in "${!PORTS[@]}"; do
    port="${PORTS[$svc]}"
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:${port}/" 2>/dev/null || echo "NOCONN")
    if [[ "$status" == "NOCONN" ]]; then
        warn "  $svc :$port → NOT REACHABLE"
    else
        ok "  $svc :$port → HTTP $status"
    fi
done

# ─────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────
echo ""
log "=== Bootstrap complete! ==="
echo ""
echo "Next steps:"
echo "  1. Log out and back in so munaim picks up the docker group (or run: newgrp docker)"
echo "  2. Check Caddy: journalctl -u caddy -f"
echo "  3. Run truth audit: /home/munaim/srv/truth.sh"
echo "  4. Once DNS propagates (≤5h), HTTPS will auto-provision via Caddy"
echo ""
echo "If any app failed to start, check logs:"
echo "  docker compose -p prod_<appname> logs -f"
echo ""
