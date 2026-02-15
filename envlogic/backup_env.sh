#!/bin/bash
# Script to bundle all production .env files into a secure archive.
# Run from the root directory (/home/munaim/srv)

set -euo pipefail

ROOT_DIR="/home/munaim/srv"
BACKUP_NAME="secrets_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

echo "=== Environment Backup Start ==="

# 1. Finding files
echo "Searching for .env files in apps/..."
FILES=$(find apps/ -name ".env*" -not -name "*.example" -not -path "*/node_modules/*")

if [ -z "$FILES" ]; then
    echo "ERROR: No .env files found to backup!"
    exit 1
fi

# 2. Creating archive
echo "Creating archive: $BACKUP_NAME"
echo "$FILES" | tar -czvf "$BACKUP_NAME" -T -

# 3. Verification
echo "--- Verification ---"
echo "Backup size: $(du -sh "$BACKUP_NAME" | cut -f1)"
echo "File count in archive: $(tar -tzf "$BACKUP_NAME" | wc -l)"
echo "Files included:"
tar -tzf "$BACKUP_NAME"

echo "=== Backup Complete ==="
echo "IMPORTANT: Transfer $BACKUP_NAME to a secure offline location immediately."
