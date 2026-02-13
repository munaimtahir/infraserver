# Full Stack Validation Summary

Validation timestamp: 2026-02-13 16:13:49 (+05:00)
Output directory: `/home/munaim/srv/ops/post_mitigation_validation/20260213_161349`

## Status Matrix

| App (Domain) | Routing | Static | API | Auth | DB | CORS |
|---|---|---|---|---|---|---|
| portal.alshifalab.pk | OK | OK | FAIL | FAIL | FAIL | FAIL |
| lims.alshifalab.pk | OK | OK | FAIL | FAIL | OK | OK |
| rims.alshifalab.pk | OK | OK | OK | FAIL | OK | OK |
| ops.alshifalab.pk | OK | OK | FAIL | FAIL | OK | FAIL |

## Evidence and Root Cause

### portal.alshifalab.pk
- Routing OK: `HEAD /` returned 200 (`portal.alshifalab.pk_head_headers.txt`).
- Static OK: JS asset returned 200 with `application/javascript` (`portal.alshifalab.pk_static_js_headers.txt`).
- API FAIL: `/api/health/` and `/api/` both returned 404 (`portal.alshifalab.pk_api_health_headers.txt`, `portal.alshifalab.pk_api_root_headers.txt`).
- Auth FAIL: `/api/login/` returned 404; no `Set-Cookie` (`portal.alshifalab.pk_auth_headers.txt`).
- DB FAIL: no validated backend container mapped to `portal` API target (`proxy/caddy/Caddyfile` routes `/api/*` to `127.0.0.1:4000`, not one of checked backend containers).
- CORS FAIL: no `Access-Control-Allow-Origin` on `/api/` response (`portal.alshifalab.pk_cors_headers.txt`).

### lims.alshifalab.pk
- Routing OK: `HEAD /` returned 200 (`lims.alshifalab.pk_head_headers.txt`).
- Static OK: JS asset returned 200 with `application/javascript` (`lims.alshifalab.pk_static_js_headers.txt`).
- API FAIL (for requested probe paths): `/api/health/` and `/api/` returned 404 (`lims.alshifalab.pk_api_health_headers.txt`, `lims.alshifalab.pk_api_root_headers.txt`).
- Root cause: API is versioned; `/api/v1/health/` returned 200 (`lims_v1_health_headers.txt`).
- Auth FAIL (for requested path): `/api/login/` returned 404, no `Set-Cookie` (`lims.alshifalab.pk_auth_headers.txt`).
- Root cause: auth endpoint is versioned (`/api/v1/auth/login/`), which returned 400 with invalid creds and no cookies (`lims_v1_auth_login_headers.txt`, `lims_v1_auth_login_body.txt`).
- DB OK: `ENV OK` in container exec; migrations readable; no DB errors in last 200 logs (`lims_backend_prod_db_exec_check.txt`, `lims_backend_prod_showmigrations.txt`, `db_check_lims_backend_prod.txt`).
- CORS OK: ACAO present and non-wildcard for origin `https://lims.alshifalab.pk` (`lims.alshifalab.pk_cors_headers.txt`, `lims_v1_cors_headers.txt`).

### rims.alshifalab.pk
- Routing OK: `HEAD /` returned 200 (`rims.alshifalab.pk_head_headers.txt`).
- Static OK: JS asset returned 200 with `application/javascript` (`rims.alshifalab.pk_static_js_headers.txt`).
- API OK: `/api/health/` returned 200; `/api/` returned 401 (authenticated API reachable) (`rims.alshifalab.pk_api_health_headers.txt`, `rims.alshifalab.pk_api_root_headers.txt`).
- Auth FAIL (for requested path): `/api/login/` returned 404 (`rims.alshifalab.pk_auth_headers.txt`).
- Root cause: token endpoint is `/api/auth/token/`; invalid creds returned 401 (expected auth behavior) and no `Set-Cookie` (`rims_auth_token_headers.txt`, `rims_auth_token_body.txt`).
- DB OK: `ENV OK`; no obvious DB errors in logs; health endpoint functional (`rims_backend_prod_db_exec_check.txt`, `db_check_rims_backend_prod.txt`, `rims.alshifalab.pk_api_health_headers.txt`).
- Note: Django mgmt commands in container failed with `ModuleNotFoundError: No module named 'django'` (`rims_backend_prod_collectstatic_dry_run.txt`, `rims_backend_prod_showmigrations.txt`) indicating image/runtime management mismatch, but live API health stayed up.
- CORS OK: ACAO present and non-wildcard for origin `https://rims.alshifalab.pk` (`rims.alshifalab.pk_cors_headers.txt`, `rims_health_cors_headers.txt`).

### ops.alshifalab.pk
- Routing OK: `HEAD /` returned 200 (`ops.alshifalab.pk_head_headers.txt`).
- Static OK: JS asset returned 200 with `application/javascript` (`ops.alshifalab.pk_static_js_headers.txt`).
- API FAIL: `/api/health/` and `/api/` returned 404 (`ops.alshifalab.pk_api_health_headers.txt`, `ops.alshifalab.pk_api_root_headers.txt`).
- Auth FAIL: `/api/login/` returned 404; no `Set-Cookie` (`ops.alshifalab.pk_auth_headers.txt`).
- DB OK: `ENV OK`; migrations listed as applied (`ops_dashboard_backend_db_exec_check.txt`, `ops_dashboard_backend_showmigrations.txt`).
- DB warning: runtime log shows worker timeout/restart event (`db_check_ops_dashboard_backend.txt`).
- CORS FAIL: missing `Access-Control-Allow-Origin` on `/api/` probe (`ops.alshifalab.pk_cors_headers.txt`).

## Cookie Flags Validation
- Requested `/api/login/` on all four domains returned 404 and **no `Set-Cookie` header**, so `Secure`/`SameSite` flags could not be validated on that path.
- On known auth endpoints (LIMS `/api/v1/auth/login/`, RIMS `/api/auth/token/`), responses were token-style JSON and still did not set cookies (`lims_v1_auth_login_headers.txt`, `rims_auth_token_headers.txt`).

## Django `collectstatic --dry-run` Check
- Command executed in all detected Django backend containers.
- In `ops_dashboard_backend`, `lims_backend_prod`, `accredivault_backend`, `accredivault_backend_prod`: command prompted for interactive confirmation and exited with EOF in non-interactive execution (`*_collectstatic_dry_run.txt`).
- In `rims_backend_prod`: command failed with `ModuleNotFoundError: No module named 'django'` (`rims_backend_prod_collectstatic_dry_run.txt`).

