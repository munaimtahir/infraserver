# Incident Report: 20260213_093626
**Status**: MITIGATED / MONITORING

## Executive Summary
Following the setup of the Ops Dashboard, several connectivity and login issues were reported across multiple domains. The primary root cause was a synchronization failure between the project-managed Caddyfile and the system's effective Caddyfile, combined with missing Django security configurations for HTTPS.

## Evidence & Root Causes

### 1. Proxy Routing Mismatch
- **Evidence**: `sha256sum` between `/home/munaim/srv/proxy/caddy/Caddyfile` and `/etc/caddy/Caddyfile` differed. The effective file was missing the `ops.alshifalab.pk` site block.
- **Symptom**: `ops.alshifalab.pk` was unreachable or returned default 404.

### 2. Login Failures (CSRF/Cookies)
- **Evidence**: `ops_dashboard_backend` settings lacked `CSRF_TRUSTED_ORIGINS` and secure cookie flags.
- **Symptom**: 403 Forbidden or 401 Unauthorized during login on HTTPS.

### 3. Upstream Health
- **Evidence**: Most upstreams (8012, 8013, 8015, 8016, 18000, 18001) were active in Docker, but `ops.alshifalab.pk` was not being routed to them.

## Fixes Applied

### Phase B1: Caddyfile Synchronization
- **Action**: Performed strict copy of source-of-truth Caddyfile to `/etc/caddy/Caddyfile`.
- **Command**: `sudo cp /home/munaim/srv/proxy/caddy/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy`
- **Result**: Routing restored for `ops.alshifalab.pk`.

### Phase B5: Backend Security Hardening
- **Ops Dashboard**: 
    - Updated `settings.py` to allow `CSRF_TRUSTED_ORIGINS` and `CORS_ALLOWED_ORIGINS` to be derived from `ALLOWED_HOSTS` or environment.
    - Added `SESSION_COOKIE_SECURE=True`, `CSRF_COOKIE_SECURE=True`, and `CSRF_TRUSTED_ORIGINS=https://ops.alshifalab.pk` to `.env.ops-dashboard`.
- **RIMS (RadReport)**:
    - Added `SESSION_COOKIE_SECURE=1` and `CSRF_COOKIE_SECURE=1` to `.env`.

## Verification Matrix

| Domain | Request Port | Host Header | Status Before | Status After |
| :--- | :--- | :--- | :--- | :--- |
| portal.alshifalab.pk | 80/443 | portal.alshifalab.pk | 308 | 308 |
| lims.alshifalab.pk | 80/443 | lims.alshifalab.pk | 308 | 308 |
| rims.alshifalab.pk | 80/443 | rims.alshifalab.pk | 308 | 308 |
| ops.alshifalab.pk | 80/443 | ops.alshifalab.pk | ERR/404 | 308 |

## Recommendation / Next Steps
1. **Automate Sync**: Implement a pre-commit hook or a CI step to ensure `/etc/caddy/Caddyfile` is always in sync with the repository.
2. **Monitor Logs**: Keep an eye on `sudo journalctl -u caddy -f` for certificate issuance lock errors observed during snapshot.
3. **External Test**: Verify that JWT cookies are correctly saved in browser (Secure flag should be present).
