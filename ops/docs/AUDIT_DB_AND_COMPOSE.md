# Audit Report: Database and Compose Configuration

Generated on: 2026-02-12

## Inventory of Compose Projects

| App Name | Directory | Postgres Service | Volume Definition | Current Status |
|----------|-----------|------------------|-------------------|----------------|
| LIMS | apps/lims | db | `lims_pgdata` (Named) | Running |
| Radreport (RIMS) | apps/radreport | db | `postgres_data` (Named) | Running |
| Accredivault | apps/accredivault/infra | db | `db_data` (Named) | Running |
| FMU Platform | apps/fmu-platform | db | `fmu_db_data` (Named) | Stopped |
| PGSIMS | apps/pgsims | db | `postgres_data` (Named) | Stopped |
| Consult | apps/consult | db | `postgres_data` (Named) | Stopped |

## Running Postgres Containers

| Container Name | Image | Volume Name (Target) | Project |
|----------------|-------|-------------|---------|
| `lims_db` | postgres:16-alpine | `lims_pgdata` | `lims` |
| `rims_db_prod` | postgres:16-alpine | `radreport_postgres_data` | `radreport` |
| `accredivault_db` | postgres:16 | `infra_db_data` | `infra` |

## Current Risk Findings

1. **Destructive Command Risk**: All production stacks are currently vulnerable to data loss if `docker compose down -v` is executed. This command removes the volumes associated with the containers.
2. **Naming Ambiguity**: Multiple projects use generic volume names like `postgres_data` or `db_data`. While Docker prefixes them with project names, this can lead to human error during manual maintenance.
3. **Lack of PROD/DEV Separation**: There is no clear distinction in the volume naming or project naming between a developer's local test and the actual production data. A developer running a stack might accidentally target a production volume if not careful (though unlikely with default project prefixes, explicit names are safer).
4. **Anonymous Volume Risk**: Not explicitly found in current running containers, but some older or untracked compose files might use anonymous volumes which are even easier to lose.
5. **Backups**: There is no centralized, automated backup system visible in the current `/srv/ops` (which was just created). Some apps have local backup scripts but they are not uniform or offsite-ready.

## What Causes Data Loss Today

- **`docker compose down -v`**: Deletes the database volumes.
- **`docker system prune --volumes`**: Deletes all unused volumes, which can include stopped production databases if not currently in use by a container.
- **Project Name Collision**: If two projects share the same name (e.g. `postgres`), they would share the same volume names if not careful.
