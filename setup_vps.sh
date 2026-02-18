#!/bin/bash
# Al-Shifa Infrastructure Master Setup Script
# Use this to bootstrap a blank Ubuntu-based VPS.
# Run as: sudo ./setup_vps.sh

set -euo pipefail

echo "=== Al-Shifa VPS Setup Start ==="

# 1. Update System and Install Base Utilities
echo "--- Updating system and installing base utilities ---"
apt-get update && apt-get upgrade -y
apt-get install -y \
    curl \
    git \
    jq \
    iproute2 \
    python3-pip \
    build-essential \
    unzip \
    wget \
    ca-certificates \
    gnupg

# 2. Check for SSH Keys (Crucial for submodules)
echo "--- Checking SSH setup for GitHub ---"
if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "WARNING: No SSH keys found. Submodule initialization might fail."
    echo "Please ensure you have an SSH key added to GitHub if you are using SSH URLs."
fi

# 3. Install Docker
if ! command -v docker &> /dev/null; then
    echo "--- Installing Docker ---"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker ${USER:-$(logname)}
    # Ensure docker compose plugin is installed
    apt-get install -y docker-compose-plugin
else
    echo "--- Docker already installed ---"
fi

# 4. Install Node.js (LTS) and pnpm
if ! command -v node &> /dev/null; then
    echo "--- Installing Node.js LTS ---"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

if ! command -v pnpm &> /dev/null; then
    echo "--- Installing pnpm ---"
    npm install -g pnpm
fi

# 5. Install Caddy
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

# 6. Initialize Submodules
echo "--- Initializing Submodules ---"
# Note: This requires SSH keys to be set up on GitHub if URLs are SSH-based
git submodule update --init --recursive || echo "ERROR: Submodule update failed. Check your SSH access to GitHub."

# 5. Create Directory Structure
echo "--- Creating Operational Directories ---"
mkdir -p /home/munaim/srv/ops/{logs,backups,caddy_backups}
mkdir -p /home/munaim/srv/proxy/caddy/{logs,overrides}

# 6. Apply Caddy Configuration
echo "--- Syncing Caddy Configuration ---"
REPO_CADDYFILE="/home/munaim/srv/proxy/caddy/Caddyfile"
SYSTEM_CADDYFILE="/etc/caddy/Caddyfile"

if [ -f "$REPO_CADDYFILE" ]; then
    echo "--- checking Caddy configuration ---"
    
    # Check if /etc/caddy/Caddyfile is already a symlink to our repo file
    if [ -L "$SYSTEM_CADDYFILE" ] && [ "$(readlink -f "$SYSTEM_CADDYFILE")" = "$REPO_CADDYFILE" ]; then
        echo "--- Caddyfile is already correctly linked. Skipping. ---"
    else
        echo "--- Linking Caddyfile ---"
        # Back up existing file/link if it exists
        if [ -e "$SYSTEM_CADDYFILE" ] || [ -L "$SYSTEM_CADDYFILE" ]; then
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            mv "$SYSTEM_CADDYFILE" "${SYSTEM_CADDYFILE}.bak.${TIMESTAMP}"
            echo "Backed up existing Caddyfile to ${SYSTEM_CADDYFILE}.bak.${TIMESTAMP}"
        fi
        
        ln -s "$REPO_CADDYFILE" "$SYSTEM_CADDYFILE"
        echo "Linked $REPO_CADDYFILE -> $SYSTEM_CADDYFILE"
        
        # Reload caddy to apply changes
        systemctl reload caddy || systemctl restart caddy
    fi
else
    echo "WARNING: Repository Caddyfile not found at $REPO_CADDYFILE"
fi

echo "=== Setup Complete! ==="
echo "Remaining Steps:"
echo "1. Log out and back in to apply docker group membership."
echo "2. Populate .env files for each app in apps/*/ (see .env.example files)."
echo "3. Start apps using: ./ops/bin/ops-prod-up <app_name>"
