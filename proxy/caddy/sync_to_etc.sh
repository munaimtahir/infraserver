#!/usr/bin/env bash
set -euo pipefail
SRC="/home/munaim/srv/proxy/caddy/Caddyfile"
DST="/etc/caddy/Caddyfile"

sudo install -m 0644 "$SRC" "$DST"
sudo caddy validate --config "$DST"
sudo systemctl reload caddy

echo "Synced $SRC -> $DST and reloaded caddy"
