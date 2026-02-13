#!/usr/bin/env bash
set -euo pipefail

sudo caddy validate --config /home/munaim/srv/proxy/caddy/Caddyfile && \
sudo install -m 0644 /home/munaim/srv/proxy/caddy/Caddyfile /etc/caddy/Caddyfile && \
sudo systemctl reload caddy
