#!/bin/bash
# Common variables and helpers for ops scripts

OPS_ROOT="/home/munaim/srv/ops"
APPS_ROOT="/home/munaim/srv/apps"
BACKUP_DIR="$OPS_ROOT/backups"
LOG_DIR="$OPS_ROOT/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERROR]${NC} $1"; }

# Helper to check if a command is destructive on prod
check_danger() {
    local cmd="$*"
    if [[ "$cmd" == *"down"* && "$cmd" == *"-v"* ]] || [[ "$cmd" == *"--volumes"* ]] || [[ "$cmd" == *"prune"* ]]; then
        if [[ "$cmd" == *"prod_"* ]] || [[ "$cmd" == *"PROD_"* ]]; then
            log_err "DESTRUCTIVE OPERATION DETECTED ON PRODUCTION!"
            log_err "Command: $cmd"
            log_err "Operation aborted for safety."
            exit 1
        fi
    fi
}
