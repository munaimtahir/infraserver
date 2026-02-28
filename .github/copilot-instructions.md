# Copilot Instructions — Al-Shifa Lab Infrastructure

This repo is the **infrastructure master** for the Al-Shifa Lab VPS. All apps run on a single Ubuntu 24.04 server at `/home/munaim/srv/`, managed via Docker Compose behind a Caddy reverse proxy. Apps are Git submodules.

---

## Architecture

```
/home/munaim/srv/
├── apps/           # Git submodules — one per application
├── proxy/caddy/    # Master Caddyfile (source of truth for routing)
├── ops/bin/        # Operational wrapper scripts (use these, not raw docker commands)
├── ops/docs/       # SOPs, runbooks, DR checklists
├── envlogic/       # .env backup/restore scripts
├── observability/  # Prometheus + Grafana stack
├── truth.sh        # Read-only system audit + health check script
└── setup_vps.sh    # Bootstrap script for a blank VPS
```

**Traffic flow:** DNS → Caddy (ports 80/443, systemd service) → `127.0.0.1:<port>` → Docker container

**Caddy config** lives at `proxy/caddy/Caddyfile` and must be kept in sync with `/etc/caddy/Caddyfile`. Caddy handles automatic HTTPS. The Caddyfile uses shared snippets `(std_headers)`, `(std_proxy)`, `(std_log)`, and `(maintenance_503)` defined at the top; reuse these in new site blocks. The file ends with `import overrides/*` for local-only overrides that are not committed.

**`PORTS_REGISTRY.md` is the source of truth for port allocation.** Always register a new app's port there before deploying.

---

## Application Stack

Each app under `apps/` is a submodule with its own `docker-compose.prod.yml` (or `docker-compose.yml`). Typical stack per app: Django REST Framework + React/Next.js + PostgreSQL + Redis (+ Celery for async).

| App | Domains | Backend port | Frontend port |
|-----|---------|-------------|---------------|
| lims | lims.alshifalab.pk, api.lims.alshifalab.pk | 8012 | — |
| rims (radreport) | rims.alshifalab.pk, api.rims.alshifalab.pk | 8015 | 8081 |
| sims (fmu-platform) | sims.alshifalab.pk | 8010 | 8080 |
| pgsims | pgsims.alshifalab.pk | 8014 | 8082 |
| consult | consult.alshifalab.pk | 8011 | — |
| accredvault (phc/sos) | phc.alshifalab.pk, sos.alshifalab.pk | 8016 | 8017/8083 |
| mediq | mediq.alshifalab.pk | 8025 | 3025 |
| vexel (monorepo) | vexel.alshifalab.pk | 3000 (API), 5000 (PDF) | 3001 |
| ops dashboard | ops.alshifalab.pk, dashboard.alshifalab.pk | 18000 | 8013 |

**vexel-health** (`apps/vexel-health/`) is an npm workspace monorepo with its own governance — see `apps/vexel-health/AGENTS.md` before touching it.

---

## Key Conventions

**Never use raw `docker compose` on production.** Always use the `ops/bin/` wrappers:
- `ops-prod-up <app>` / `ops-prod-down <app>` — start/stop (keeps volumes)
- `ops-dev-up <app>` / `ops-dev-down <app>` / `ops-dev-reset-hard <app>`
- `ops-status` — overview of all containers and volumes
- `ops-backup-now` — immediate backup of all prod DBs
- `ops-restore-sandbox <file>` — verify a backup in isolation before prod restore

**Never run `docker compose down -v` or `docker system prune --volumes` on production.** Production project names are prefixed `prod_`; volumes are prefixed `PROD_`.

**`.env` files are not in Git.** They are backed up separately via `envlogic/backup_env.sh` → `secrets_backup_*.tar.gz`. Restore with `envlogic/restore_env.sh <archive>`. Each app has a `.env.example` as a template.

**Caddyfile sync:** After editing `proxy/caddy/Caddyfile`, sync it:
```bash
sudo cp /home/munaim/srv/proxy/caddy/Caddyfile /etc/caddy/Caddyfile
sudo systemctl reload caddy
```
Or use `truth.sh` to detect drift between the two files.

**Container ports bind to `127.0.0.1` only.** DB/cache ports must not be publicly bound.

---

## Commands

### System health & audit
```bash
./truth.sh                         # Full read-only audit: docker, caddy, domains, probes
ops-status                         # Quick container/volume summary
```

### Application lifecycle
```bash
ops-prod-up lims                   # Start production app
ops-prod-down lims                 # Stop production app (data preserved)
ops-dev-reset-hard lims            # Wipe dev data and rebuild
```

### Caddy
```bash
sudo systemctl status caddy
sudo journalctl -u caddy -f
sudo caddy validate --config /etc/caddy/Caddyfile
```

### Logs
```bash
docker compose -f apps/lims/docker-compose.prod.yml logs -f
journalctl -u caddy -f
# Operational logs: ops/logs/, ops/truth_audit/
```

### Backup
```bash
ops-backup-now                                  # Manual backup of all prod DBs
ops-restore-sandbox /path/to/backup.sql.gz      # Restore into sandbox for verification
# Direct prod restore (careful!):
zcat backup.sql.gz | docker exec -i <container> psql -U <user> <db>
```

### VPS bootstrap (new server only)
```bash
git clone --recurse-submodules <repo-url> /home/munaim/srv
cd /home/munaim/srv
sudo ./setup_vps.sh
./envlogic/restore_env.sh secrets_backup_*.tar.gz
ops-prod-up lims   # repeat for each app
./truth.sh         # verify
```

---

## Health Endpoint Standard

All apps should expose `/health`, `/ready`, and `/live`. Expected `/health` response:
```json
{ "status": "ok|degraded|down", "version": "...", "timestamp": "ISO-8601", "deps": { "db": "ok|down", "cache": "ok|down" } }
```
Caddy exposes a lightweight `/healthz` for API subdomains inline in the Caddyfile (returns `{"status":"ok","service":"..."}`).

---

## vexel-health Monorepo (apps/vexel-health)

This is an npm workspace monorepo governed by `apps/vexel-health/AGENTS.md` and `apps/vexel-health/governance/`. Key rules:

- OpenAPI (`packages/contracts/openapi.yaml`) is the API contract source of truth. Run `npm run contracts:generate` after any API change.
- Never hand-edit `apps/api/dist/*` or `packages/contracts/dist/*`.
- All workflow state transitions go through commands/state machines — no raw CRUD mutations to workflow state.
- Every domain table is tenant-scoped; every query must filter by tenant.
- `core/*` = reusable platform capabilities; `modules/*` = product modules. No cross-module internal imports.

```bash
# From apps/vexel-health/
npm run dev                              # Start local stack
docker compose up --build                # Rebuild and run all services
npm run lint                             # Lint all workspaces
npm run test --workspace=api             # API unit tests
npm run test:e2e --workspace=api         # API e2e tests
npm run test:cov --workspace=api         # With coverage
npm run contracts:generate               # Regenerate types from OpenAPI
npm run start:dev --workspace=api        # API watch mode
npm run dev --workspace=web              # Web dev server
```
