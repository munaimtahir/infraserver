# Ports Registry (Source of Truth)

Last updated: 2026-02-12
Host: vps.us-central1-f.c.munaimfinance.internal

## Routing Registry

| App | Domain(s) | Reserved host port(s) | Upstream target(s) | Compose path |
|---|---|---:|---|---|
| launchpad-portal | portal.alshifalab.pk | 8013 | 127.0.0.1:8013 | /home/munaim/srv/apps/launchpad/docker-compose.yml |
| lims | lims.alshifalab.pk, api.lims.alshifalab.pk | 8012 | 127.0.0.1:8012 | /home/munaim/srv/apps/lims/docker-compose.prod.yml |
| fmu-platform (sims) | sims.alshifalab.pk, sims.pmc.edu.pk, api.sims.alshifalab.pk, api.sims.pmc.edu.pk | 8010, 8080 | 127.0.0.1:8010, 127.0.0.1:8080 | /home/munaim/srv/apps/fmu-platform/docker-compose.yml |
| pgsims | pgsims.alshifalab.pk, pgsims.pmc.edu.pk, api.pgsims.alshifalab.pk, api.pgsims.pmc.edu.pk | 8014, 8082 | 127.0.0.1:8014, 127.0.0.1:8082 | /home/munaim/srv/apps/pgsims/docker-compose.yml |
| rims | rims.alshifalab.pk, api.rims.alshifalab.pk | 8015, 8081 | 127.0.0.1:8015, 127.0.0.1:8081 | /home/munaim/srv/apps/radreport/docker-compose.prod.yml |
| consult | consult.alshifalab.pk, api.consult.alshifalab.pk | 8011 | 127.0.0.1:8011 | /home/munaim/srv/apps/consult/docker-compose.yml |
| accredvault-phc | phc.alshifalab.pk, api.phc.alshifalab.pk | 8016 | 127.0.0.1:8016 | /home/munaim/srv/apps/accredivault/infra/docker-compose.prod.yml |
| accredvault-sos | sos.alshifalab.pk, api.sos.alshifalab.pk | 8017, 8083 | 127.0.0.1:8017, 127.0.0.1:8083 | /home/munaim/srv/apps/accredivault/infra/docker-compose.prod.yml |
| vexel | vexel.alshifalab.pk | 9021 (api), 9022 (pdf), 9023 (admin), 9024 (operator) | 127.0.0.1:9021–9024 | /home/munaim/srv/apps/vexel/docker-compose.yml |
| grafana | grafana.alshifalab.pk | 13000 | 127.0.0.1:13000 | /home/munaim/srv/observability/docker-compose.yml |
| dashboard | dashboard.alshifalab.pk | 4000 + 8013 | 127.0.0.1:4000, 127.0.0.1:8013 | /home/munaim/srv/apps/launchpad/docker-compose.yml |

## Policy

- Web-facing container ports must bind to `127.0.0.1`.
- DB/cache ports must not be public. Prefer no host bind, or `127.0.0.1` only when explicitly required.
- Any new app/domain must reserve host ports in this file before deployment.
- Caddy source of truth is `/home/munaim/srv/proxy/caddy/Caddyfile`; `/etc/caddy/Caddyfile` must be synced copy.
