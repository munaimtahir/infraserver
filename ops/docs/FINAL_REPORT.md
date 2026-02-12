# FINAL REPORT: Secure Production Docker Ops Implementation

## Overview
The "Al-Shifa Launchpad" environment has been secured with a dedicated operational framework (`ops`). Production data is now strictly separated from development environments using naming conventions, explicit project names, and wrapper scripts.

## What Changed?
1.  **Operational Root**: Created `/home/munaim/srv/ops` as the central hub for system management, backups, and logs.
2.  **Production Standardization**:
    *   All production projects are now named with a `prod_` prefix (e.g., `prod_lims`, `prod_radreport`, `prod_accredivault`).
    *   All production volumes use a `PROD_` prefix and are explicitly named in compose files to prevent auto-naming collision (e.g., `PROD_lims_pgdata`).
    *   Major apps (`lims`, `radreport`, `accredivault`) have been migrated to use `docker-compose.prod.yml`.
3.  **Development Safety**:
    *   Development stacks now use separate volumes with a `DEV_` prefix.
    *   A hard-reset command (`ops-dev-reset-hard`) is provided that only targets `dev_` projects.
4.  **Automated Backups**:
    *   Nightly backups are configured via a systemd timer.
    *   Backups are stored in `/home/munaim/srv/ops/backups` with a 14-day daily and 8-week weekly retention policy.
    *   A restore-to-sandbox workflow is implemented for testing backups without touching production.

## New Operational Commands
Use these scripts instead of raw `docker compose` commands for safety:

| Command | Usage | Description |
| :--- | :--- | :--- |
| `ops-status` | `ops-status` | Status overview of running projects/volumes. |
| `ops-prod-up` | `ops-prod-up <app>` | Start a production app safely. |
| `ops-prod-down` | `ops-prod-down <app>` | Stop a production app (Volumes are kept). |
| `ops-dev-up` | `ops-dev-up <app>` | Start a development version of an app. |
| `ops-dev-reset-hard` | `ops-dev-reset-hard <app>` | **Wipe** dev data and rebuild. Blocks prod. |
| `ops-backup-now` | `ops-backup-now` | Trigger a manual backup of all prod DBs. |
| `ops-restore-sandbox`| `ops-restore-sandbox <file>`| Restore a backup into a temporary container. |

## Disaster Recovery Quick Steps
1.  **Identify Backup**: Find the latest `.sql.gz` in `/home/munaim/srv/ops/backups/daily/`.
2.  **Restore Sandbox**: Run `ops-restore-sandbox /home/munaim/srv/ops/backups/daily/<filename>`.
3.  **Verify Data**: Use the connection details printed by the script to check the restored DB.
4.  **Production Restore**: If a production restore is needed, stop the prod container and use `zcat <backup> | docker exec -i <container> psql -U <user> <db>`.

## Important Guardrails
*   **Destructive Actions Blocked**: `ops-dev-reset-hard` will refuse to run if it detects a production project name.
*   **Volume Immutability**: Production volumes are now "untouchable" by standard dev cleanup workflows.
*   **Manual Warning**: **NEVER** run `docker system prune --volumes` or `docker compose down -v` on production without extreme caution. Use the `ops-*` wrappers instead.

## Next Steps
- **Offsite Backups**: To enable offsite backups, install `rclone`, configure a remote named `offsite`, and set `OFFSITE_ENABLED=1` in `/home/munaim/srv/ops/backup.env`.
- **Git Commit**: Ensure the new `ops/` directory and `.prod.yml` / `.dev.yml` files are committed to your repository.

---
*Implementation completed on 2026-02-12.*
