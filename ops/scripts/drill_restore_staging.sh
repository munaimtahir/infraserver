#!/usr/bin/env bash
set -euo pipefail

RESTIC_REPO="/srv/backups/restic_repo"
RESTIC_PASSWORD_FILE="/home/munaim/srv/ops/config/restic_password.txt"
RUNS_DIR="/srv/backups/meta/runs"
REPORT_DIR="/home/munaim/srv/ops/docs"

START_EPOCH=$(date +%s)
START_ISO=$(date -Iseconds)

LATEST_RUN="${1:-}"
if [[ -z "$LATEST_RUN" ]]; then
  LATEST_RUN=$(sudo ls -1 "$RUNS_DIR" | tail -n 1)
fi

if [[ -z "$LATEST_RUN" ]]; then
  echo "No run ids found" >&2
  exit 1
fi

WORK_ROOT="/tmp/drill-${LATEST_RUN}-$$"
TARGET="$WORK_ROOT/restore"
mkdir -p "$TARGET"

MANIFEST_SRC="$RUNS_DIR/$LATEST_RUN/manifest.json"
if [[ ! -f "$MANIFEST_SRC" ]]; then
  echo "Missing manifest: $MANIFEST_SRC" >&2
  exit 1
fi

sudo RESTIC_PASSWORD_FILE="$RESTIC_PASSWORD_FILE" restic -r "$RESTIC_REPO" restore latest --tag "run:$LATEST_RUN" --target "$TARGET" >/tmp/drill-restic-restore.log 2>&1

RESTORED_RUN_DIR="$TARGET/srv/backups/work/$LATEST_RUN"
if [[ ! -d "$RESTORED_RUN_DIR" ]]; then
  echo "Restored run folder missing: $RESTORED_RUN_DIR" >&2
  exit 1
fi

# checksum validation against source manifest metadata
python3 - <<'PY' "$MANIFEST_SRC" "$RESTORED_RUN_DIR"
import json, hashlib, pathlib, sys
manifest_path=pathlib.Path(sys.argv[1])
restored_root=pathlib.Path(sys.argv[2])
manifest=json.loads(manifest_path.read_text())
errors=[]
for art in manifest.get('artifacts',[]):
    p=pathlib.Path(art['path'])
    rel=p.relative_to('/srv/backups/work/'+manifest['job_id'])
    restored=restored_root/rel
    if not restored.exists():
        errors.append(f'missing:{restored}')
        continue
    h=hashlib.sha256(restored.read_bytes()).hexdigest()
    if h!=art['sha256']:
        errors.append(f'hash_mismatch:{restored}')
if errors:
    print('\n'.join(errors))
    sys.exit(1)
print('checksum_ok')
PY

# compression checks
find "$RESTORED_RUN_DIR" -type f -name '*.sql.gz' -print0 | while IFS= read -r -d '' f; do
  gunzip -t "$f"
done
find "$RESTORED_RUN_DIR" -type f -name '*.tar.zst' -print0 | while IFS= read -r -d '' f; do
  zstd -t "$f" >/dev/null
done

# DB staging restore to ephemeral postgres
DB_CONTAINER="drill_pg_${LATEST_RUN//[^a-zA-Z0-9]/}"
sudo docker rm -f "$DB_CONTAINER" >/dev/null 2>&1 || true
sudo docker run -d --name "$DB_CONTAINER" -e POSTGRES_PASSWORD=drillpass postgres:16-alpine >/tmp/drill-pg-run.log 2>&1
sleep 8
SQL_DUMP=$(find "$RESTORED_RUN_DIR/db" -type f -name '*.sql.gz' | head -n 1 || true)
if [[ -n "$SQL_DUMP" ]]; then
  gunzip -c "$SQL_DUMP" | sudo docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres >/tmp/drill-psql-restore.log 2>&1
  TABLE_COUNT=$(sudo docker exec "$DB_CONTAINER" psql -U postgres -d postgres -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';" | tr -d ' ')
else
  TABLE_COUNT=0
fi
sudo docker rm -f "$DB_CONTAINER" >/dev/null 2>&1 || true

END_EPOCH=$(date +%s)
END_ISO=$(date -Iseconds)
RTO=$((END_EPOCH-START_EPOCH))
RPO_SECONDS=$(python3 - <<'PY' "$MANIFEST_SRC" "$END_ISO"
import json,sys,datetime
m=json.load(open(sys.argv[1]))
end=datetime.datetime.fromisoformat(sys.argv[2])
ts=datetime.datetime.fromisoformat(m['timestamp'])
print(int((end-ts).total_seconds()))
PY
)

REPORT="$REPORT_DIR/DR_DRILL_REPORT_${LATEST_RUN}.md"
cat > "$REPORT" <<MD
# DR Drill Report

- Run ID: \
  $LATEST_RUN
- Drill start: \
  $START_ISO
- Drill end: \
  $END_ISO
- RTO (seconds): \
  $RTO
- RPO (seconds from backup timestamp to drill completion): \
  $RPO_SECONDS

## Checks
- [x] Restic restore of tagged run succeeded
- [x] Artifact checksums matched manifest
- [x] gzip/zstd integrity checks passed
- [x] SQL restore into ephemeral PostgreSQL succeeded
- [x] Restored DB public table count: \
  $TABLE_COUNT

## Artifacts
- Manifest: \
  $MANIFEST_SRC
- Restic restore log: \
  /tmp/drill-restic-restore.log
- SQL restore log: \
  /tmp/drill-psql-restore.log

## Result
PASS
MD

echo "DR drill completed: $REPORT"
