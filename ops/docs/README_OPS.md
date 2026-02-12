# Al-Shifa Ops: Operator Handbook

This directory contains scripts and configuration for managing production and development environments safely.

## Core Rules

1. **Never** run `docker system prune --volumes` or `docker compose down -v` on production stacks.
2. **Always** use the `ops-*` wrapper scripts for managing applications.
3. Production project names are prefixed with `prod_`.
4. Development project names are prefixed with `dev_`.
5. Production volumes are prefixed with `PROD_`.

## Available Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `ops-status` | `ops-status` | Show summary of projects, containers, and volumes. |
| `ops-prod-up` | `ops-prod-up <app>` | Start a production application. |
| `ops-prod-down` | `ops-prod-down <app>` | Stop a production application (keeps data). |
| `ops-dev-up` | `ops-dev-up <app>` | Start a development application. |
| `ops-dev-down` | `ops-dev-down <app>` | Stop a development application. |
| `ops-dev-reset-hard` | `ops-dev-reset-hard <app>` | **Wipe** dev data and rebuild the dev stack. |
| `ops-backup-now` | `ops-backup-now` | Force an immediate backup of all prod databases. |
| `ops-restore-sandbox` | `ops-restore-sandbox <file>` | Restore a backup to a sandbox to verify it. |

## Backup Policy

- **Daily**: Automated backups at midnight. Kept for 14 days.
- **Weekly**: Full globals dump every Sunday. Kept for 8 weeks.
- **Storage**: Backups are stored in `/home/munaim/srv/ops/backups`.

## Disaster Recovery

If you need to restore a production database:
1. Identify the latest backup in `ops/backups`.
2. Run `ops-restore-sandbox <filename>` to verify the data.
3. Once verified, stop the production app: `ops-prod-down <app>`.
4. (Advanced) Manually restore the verified dump into the production container.
