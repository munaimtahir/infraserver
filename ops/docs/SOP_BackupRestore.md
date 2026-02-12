# SOP: Backup and Restore Operations

## Daily backup
1. Verify agent health: `curl http://127.0.0.1:9753/health`
2. Trigger backup: `/home/munaim/srv/ops/scripts/opsctl.sh backup`
3. Check runs: `/home/munaim/srv/ops/scripts/opsctl.sh runs`
4. Confirm manifest in `/srv/backups/meta/runs/<jobid>/manifest.json`

## Retention
- Daily: 14
- Weekly: 8
- Monthly: 12
- Trigger manually: `/home/munaim/srv/ops/scripts/opsctl.sh prune`

## Validation
- Weekly timer runs `restic check --read-data-subset=1/20`
- Manual: `/home/munaim/srv/ops/scripts/opsctl.sh validate <run_id>`

## Restore safety rails
- Restore modes: `validate-only`, `restore-db`, `restore-files`, `restore-caddy`, `full`, `export-bundle`
- Destructive restore requires typed phrase: `RESTORE <run_id>`
- DB restore on same server requires `allow_same_server=true` and empty database checks.

## Audit and logs
- Audit: `/home/munaim/srv/ops/logs/audit.log`
- Run logs: `/home/munaim/srv/ops/logs/runs/<jobid>.log`

## Cloud upload (optional)
1. Put rclone config at `/home/munaim/srv/ops/config/rclone.conf` (chmod 600)
2. List remotes: `opsctl.sh remotes`
3. Upload latest: `opsctl.sh upload-latest <remote> [path]`
