#!/bin/bash
# Script to restore .env files from a backup tarball.
# Usage: ./envlogic/restore_env.sh <backup_file.tar.gz>
# Run from the root directory (/home/munaim/srv)

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file '$BACKUP_FILE' not found!"
    exit 1
fi

echo "=== Environment Restore Start ==="
echo "Restoring from: $BACKUP_FILE"

# 1. Preview
echo "The following files will be restored:"
tar -tzf "$BACKUP_FILE"

read -p "Are you sure you want to proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 1
fi

# 2. Extract
echo "Extracting files..."
tar -xzvf "$BACKUP_FILE"

# 3. Verification
echo "Verifying restored files..."
RESTORED_FILES=$(tar -tzf "$BACKUP_FILE")
for f in $RESTORED_FILES; do
    if [ -f "$f" ]; then
        echo "[OK] $f"
    else
        echo "[MISSING] $f"
    fi
done

echo "=== Restore Complete ==="
echo "Note: You may need to restart your Docker containers to apply the new environment variables."
