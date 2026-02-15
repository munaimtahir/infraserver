#!/bin/bash
# Al-Shifa Infrastructure Master Setup Script
# Use this to bootstrap a blank Ubuntu-based VPS.
# Run as: sudo ./setup_vps.sh

set -euo pipefail

echo "=== Al-Shifa VPS Setup Start ==="

# 1. Update System
echo "--- Updating system ---"
apt-get update && apt-get upgrade -y
apt-get install -y curl git jq ss-others python3-pip

# 2. Install Docker
if ! command -v docker &> /dev/null; then
    echo "--- Installing Docker ---"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $USER
else
    echo "--- Docker already installed ---"
fi

# 3. Install Caddy
if ! command -v caddy &> /dev/null; then
    echo "--- Installing Caddy ---"
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1G 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1G 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install caddy -y
else
    echo "--- Caddy already installed ---"
fi

# 4. Initialize Submodules
echo "--- Initializing Submodules ---"
git submodule update --init --recursive

# 5. Create Directory Structure
echo "--- Creating Operational Directories ---"
mkdir -p /home/munaim/srv/ops/{logs,backups,caddy_backups}
mkdir -p /home/munaim/srv/proxy/caddy/{logs,overrides}

# 6. Apply Caddy Configuration
echo "--- Syncing Caddy Configuration ---"
# Note: This assumes the user has already cloned the repo into /home/munaim/srv
# Configure Caddy to use the repository's Caddyfile
if [ -f "/home/munaim/srv/proxy/caddy/Caddyfile" ]; then
    echo "--- Reloading Caddy Configuration ---"
    # Link the repository Caddyfile to /etc/caddy/Caddyfile if not already linked
    if [ ! -L "/etc/caddy/Caddyfile" ] && [ -f "/etc/caddy/Caddyfile" ]; then
        mv /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak
        ln -s /home/munaim/srv/proxy/caddy/Caddyfile /etc/caddy/Caddyfile
    elif [ ! -f "/etc/caddy/Caddyfile" ]; then
        ln -s /home/munaim/srv/proxy/caddy/Caddyfile /etc/caddy/Caddyfile
    fi
    systemctl reload caddy || systemctl restart caddy
fi

echo "=== Setup Complete! ==="
echo "Remaining Steps:"
echo "1. Log out and back in to apply docker group membership."
echo "2. Populate .env files for each app in apps/*/ (see .env.example files)."
echo "3. Start apps using: ./ops/bin/ops-prod-up <app_name>"
