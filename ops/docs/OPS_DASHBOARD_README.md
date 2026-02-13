# OPS Dashboard (OpsWeb) Runbook

## Overview
The dashboard frontend is served by Docker Compose (`127.0.0.1:8013`) and the backend API runs as `opsweb` via systemd (`127.0.0.1:4000`).

Security model:
- No Docker socket is mounted into dashboard services.
- Backend can execute only approved ops scripts via `sudo -n`.
- Caddy Basic Auth protects both UI and API.

## Start / Stop
### Frontend (static UI)
```bash
cd /home/munaim/srv/dashboard
docker compose up -d dashboard
docker compose stop dashboard
```

### Backend (OpsWeb API)
```bash
sudo systemctl restart dashboard-api.service
sudo systemctl status dashboard-api.service --no-pager
```

## Credentials
- Htpasswd/hash record: `/home/munaim/srv/ops/opsweb.htpasswd`
- One-time plaintext record: `/home/munaim/srv/ops/docs/OPS_DASHBOARD_CREDENTIALS.txt`

## Rotate Dashboard Password
1. Generate a new password:
```bash
openssl rand -base64 30
```
2. Generate bcrypt hash:
```bash
caddy hash-password --plaintext '<NEW_PASSWORD>'
```
3. Update credentials files:
- `/home/munaim/srv/ops/opsweb.htpasswd`
- `/home/munaim/srv/ops/docs/OPS_DASHBOARD_CREDENTIALS.txt`
4. Update Caddy `dashboard.alshifalab.pk` block in `/etc/caddy/Caddyfile`:
- Replace `opsadmin <bcrypt-hash>` in both `basic_auth` blocks.
5. Reload Caddy:
```bash
sudo systemctl reload caddy
```

## Current Caddy Snippet
```caddyfile
dashboard.alshifalab.pk {
	encode gzip zstd
	import access_json
	import sec_headers

	basic_auth {
		opsadmin <bcrypt-hash>
	}

	handle /api/* {
		basic_auth {
			opsadmin <bcrypt-hash>
		}
		reverse_proxy 127.0.0.1:4000 {
			import proxy_headers
			header_up X-Remote-User {http.auth.user.id}
		}
	}

	handle {
		reverse_proxy 127.0.0.1:8013 {
			transport http {
				read_timeout 30s
				write_timeout 30s
			}
			import proxy_headers
		}
	}
}
```

## Audit Logs
- JSONL audit: `/home/munaim/srv/ops/logs/opsweb_audit.log`
- SQLite audit DB: `/home/munaim/srv/ops/logs/opsweb_audit.sqlite`
- Backup log: `/home/munaim/srv/ops/logs/backup.log`

## Troubleshooting
1. API 500 on actions:
```bash
sudo journalctl -u dashboard-api.service -n 200 --no-pager
sudo tail -n 200 /home/munaim/srv/ops/logs/opsweb_audit.log
```
2. Caddy auth/routing issue:
```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```
3. Check status script directly:
```bash
sudo -u opsweb sudo -n /home/munaim/srv/ops/bin/ops-status --json | jq
```
