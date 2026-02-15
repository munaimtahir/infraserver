#!/bin/bash
set -euo pipefail

# Repository Cleanup Script
# Purpose: Remove irrelevant files and organize directory structure
# Date: 2026-02-15

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/srv_backup_before_cleanup_$TIMESTAMP.tar.gz"

echo "========================================="
echo "Repository Cleanup Script"
echo "========================================="
echo ""

# Step 1: Create backup archive
echo "Step 1: Creating backup archive..."
echo "Backup file: $BACKUP_FILE"

cd "$SCRIPT_DIR"

# Create backup of files to be removed
tar -czf "$BACKUP_FILE" \
    --ignore-failed-read \
    deployment_report.md \
    config_updated.txt \
    CONFIGURATION_REVIEW.md \
    phase2.sh \
    caddy.sh \
    _triage_backups/ \
    .mypy_cache/ \
    ops/docs/DR_DRILL_REPORT_20260212105419-eac8a035.md \
    ops/docs/FINAL_REPORT.md \
    ops/incident/ \
    ops/post_mitigation_validation/ \
    ops/fixpack_api_routing/ \
    2>/dev/null || true

if [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✅ Backup created: $BACKUP_FILE ($BACKUP_SIZE)"
else
    echo "⚠️  Warning: Backup file not created (files may not exist)"
fi

echo ""

# Step 2: Remove event-specific reports
echo "Step 2: Removing event-specific reports..."
rm -f deployment_report.md && echo "  ✅ Removed: deployment_report.md" || echo "  ⏭️  Not found: deployment_report.md"
rm -f config_updated.txt && echo "  ✅ Removed: config_updated.txt" || echo "  ⏭️  Not found: config_updated.txt"
rm -f CONFIGURATION_REVIEW.md && echo "  ✅ Removed: CONFIGURATION_REVIEW.md" || echo "  ⏭️  Not found: CONFIGURATION_REVIEW.md"
rm -f ops/docs/DR_DRILL_REPORT_20260212105419-eac8a035.md && echo "  ✅ Removed: ops/docs/DR_DRILL_REPORT_*.md" || echo "  ⏭️  Not found: ops/docs/DR_DRILL_REPORT_*.md"
rm -f ops/docs/FINAL_REPORT.md && echo "  ✅ Removed: ops/docs/FINAL_REPORT.md" || echo "  ⏭️  Not found: ops/docs/FINAL_REPORT.md"

echo ""

# Step 3: Remove temporary backups
echo "Step 3: Removing temporary backup directories..."
if [ -d "_triage_backups" ]; then
    rm -rf _triage_backups/
    echo "  ✅ Removed: _triage_backups/"
else
    echo "  ⏭️  Not found: _triage_backups/"
fi

echo ""

# Step 4: Remove incident-specific directories
echo "Step 4: Removing incident-specific directories..."
if [ -d "ops/incident" ]; then
    rm -rf ops/incident/
    echo "  ✅ Removed: ops/incident/"
else
    echo "  ⏭️  Not found: ops/incident/"
fi

if [ -d "ops/post_mitigation_validation" ]; then
    rm -rf ops/post_mitigation_validation/
    echo "  ✅ Removed: ops/post_mitigation_validation/"
else
    echo "  ⏭️  Not found: ops/post_mitigation_validation/"
fi

if [ -d "ops/fixpack_api_routing" ]; then
    rm -rf ops/fixpack_api_routing/
    echo "  ✅ Removed: ops/fixpack_api_routing/"
else
    echo "  ⏭️  Not found: ops/fixpack_api_routing/"
fi

echo ""

# Step 5: Remove temporary scripts
echo "Step 5: Removing temporary scripts..."
rm -f phase2.sh && echo "  ✅ Removed: phase2.sh" || echo "  ⏭️  Not found: phase2.sh"
rm -f caddy.sh && echo "  ✅ Removed: caddy.sh" || echo "  ⏭️  Not found: caddy.sh"

echo ""

# Step 6: Remove cache directories
echo "Step 6: Removing cache directories..."
if [ -d ".mypy_cache" ]; then
    rm -rf .mypy_cache/
    echo "  ✅ Removed: .mypy_cache/"
else
    echo "  ⏭️  Not found: .mypy_cache/"
fi

echo ""

# Step 7: Update .gitignore
echo "Step 7: Updating .gitignore..."
if ! grep -q "^_triage_backups/$" .gitignore 2>/dev/null; then
    echo "_triage_backups/" >> .gitignore
    echo "  ✅ Added _triage_backups/ to .gitignore"
fi

if ! grep -q "^.mypy_cache/$" .gitignore 2>/dev/null; then
    echo ".mypy_cache/" >> .gitignore
    echo "  ✅ Added .mypy_cache/ to .gitignore"
fi

if ! grep -q "^ops/incident/$" .gitignore 2>/dev/null; then
    echo "ops/incident/" >> .gitignore
    echo "  ✅ Added ops/incident/ to .gitignore"
fi

if ! grep -q "^ops/post_mitigation_validation/$" .gitignore 2>/dev/null; then
    echo "ops/post_mitigation_validation/" >> .gitignore
    echo "  ✅ Added ops/post_mitigation_validation/ to .gitignore"
fi

if ! grep -q "^ops/fixpack_" .gitignore 2>/dev/null; then
    echo "ops/fixpack_*/" >> .gitignore
    echo "  ✅ Added ops/fixpack_*/ to .gitignore"
fi

echo ""

# Step 8: Show cleanup summary
echo "========================================="
echo "Cleanup Summary"
echo "========================================="
echo ""
echo "✅ Cleanup completed successfully!"
echo ""
echo "Backup archive: $BACKUP_FILE"
echo "Backup size: $(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1 || echo 'N/A')"
echo ""
echo "Files and directories removed:"
echo "  - Event-specific reports (5 files)"
echo "  - Temporary backup directories (1 directory)"
echo "  - Incident-specific directories (3 directories)"
echo "  - Temporary scripts (2 files)"
echo "  - Cache directories (1 directory)"
echo ""
echo "Next steps:"
echo "  1. Review the changes: git status"
echo "  2. Verify system status: ./truth.sh"
echo "  3. Commit changes: git add -A && git commit -m 'chore: cleanup repository'"
echo ""
echo "========================================="
