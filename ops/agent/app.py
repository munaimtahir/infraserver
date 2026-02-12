import gzip
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import tempfile
import threading
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.responses import JSONResponse, PlainTextResponse
from prometheus_client import CONTENT_TYPE_LATEST, CollectorRegistry, Gauge, generate_latest
from pydantic import BaseModel, Field

APP = FastAPI(title="ops-agent", version="1.0.0")

OPS_ROOT = Path("/home/munaim/srv/ops")
CONFIG_DIR = OPS_ROOT / "config"
LOG_DIR = OPS_ROOT / "logs"
RUN_LOG_DIR = LOG_DIR / "runs"
AUDIT_LOG = LOG_DIR / "audit.log"
APPS_FILE = CONFIG_DIR / "apps.yml"
TOKEN_FILE = CONFIG_DIR / "ops_token.txt"
RESTIC_PASSWORD_FILE = CONFIG_DIR / "restic_password.txt"
AGE_KEY_FILE = CONFIG_DIR / "age.key"
RCLONE_CONF = CONFIG_DIR / "rclone.conf"

BACKUP_REPO = Path("/srv/backups/restic_repo")
BACKUP_WORK = Path("/srv/backups/work")
BACKUP_META = Path("/srv/backups/meta")
RUNS_META = BACKUP_META / "runs"
DB_META = BACKUP_META / "backups.sqlite"

ALLOWLIST_ACTIONS = {
    "backup",
    "validate",
    "prune",
    "restore",
    "export_bundle",
    "upload_latest",
    "upload_snapshot",
    "rclone_test",
}

RETENTION = {"daily": 14, "weekly": 8, "monthly": 12}

for p in [LOG_DIR, RUN_LOG_DIR, BACKUP_REPO, BACKUP_WORK, BACKUP_META, RUNS_META]:
    p.mkdir(parents=True, exist_ok=True)

registry = CollectorRegistry()
metric_backup_success = Gauge("ops_backup_last_success", "last backup success", ["app"], registry=registry)
metric_backup_epoch = Gauge("ops_backup_last_epoch", "last backup timestamp", ["app"], registry=registry)
metric_job_running = Gauge("ops_jobs_running", "jobs currently running", registry=registry)

JOBS: Dict[str, Dict[str, Any]] = {}
JOBS_LOCK = threading.Lock()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def shell(cmd: List[str], env: Optional[Dict[str, str]] = None, check: bool = True, log_path: Optional[Path] = None) -> subprocess.CompletedProcess:
    effective_env = os.environ.copy()
    if env:
        effective_env.update(env)
    proc = subprocess.run(cmd, capture_output=True, text=True, env=effective_env)
    if log_path:
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(f"$ {' '.join(cmd)}\n")
            if proc.stdout:
                fh.write(proc.stdout + "\n")
            if proc.stderr:
                fh.write(proc.stderr + "\n")
    if check and proc.returncode != 0:
        raise RuntimeError(f"command failed ({proc.returncode}): {' '.join(cmd)}\n{proc.stderr}")
    return proc


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_apps() -> Dict[str, Dict[str, Any]]:
    data = yaml.safe_load(APPS_FILE.read_text(encoding="utf-8")) or {}
    return data.get("apps", {})


def ensure_restic_init() -> None:
    if (BACKUP_REPO / "config").exists():
        return
    shell([
        "restic",
        "-r",
        str(BACKUP_REPO),
        "init",
    ], env={"RESTIC_PASSWORD_FILE": str(RESTIC_PASSWORD_FILE)})


def init_db() -> None:
    con = sqlite3.connect(DB_META)
    cur = con.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS runs (
            job_id TEXT PRIMARY KEY,
            action TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            payload_json TEXT NOT NULL
        )
        """
    )
    con.commit()
    con.close()


def persist_run(job_id: str, action: str, status: str, payload: Dict[str, Any]) -> None:
    con = sqlite3.connect(DB_META)
    cur = con.cursor()
    cur.execute(
        """
        INSERT INTO runs(job_id, action, status, created_at, updated_at, payload_json)
        VALUES(?, ?, ?, ?, ?, ?)
        ON CONFLICT(job_id) DO UPDATE SET
          action=excluded.action,
          status=excluded.status,
          updated_at=excluded.updated_at,
          payload_json=excluded.payload_json
        """,
        (job_id, action, status, payload.get("created_at", now_iso()), now_iso(), json.dumps(payload)),
    )
    con.commit()
    con.close()


def audit(action: str, status: str, actor: str, details: Dict[str, Any]) -> None:
    record = {
        "time": now_iso(),
        "action": action,
        "status": status,
        "actor": actor,
        "details": details,
    }
    with AUDIT_LOG.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, ensure_ascii=True) + "\n")


def get_public_age_recipient() -> str:
    out = shell(["age-keygen", "-y", str(AGE_KEY_FILE)])
    return out.stdout.strip()


def start_job(action: str, payload: Dict[str, Any], actor: str, fn) -> Dict[str, Any]:
    if action not in ALLOWLIST_ACTIONS:
        raise HTTPException(status_code=400, detail="Action not allowed")
    job_id = datetime.now().strftime("%Y%m%d%H%M%S") + "-" + uuid.uuid4().hex[:8]
    log_path = RUN_LOG_DIR / f"{job_id}.log"
    data = {
        "job_id": job_id,
        "action": action,
        "status": "queued",
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "payload": payload,
        "log": str(log_path),
    }
    with JOBS_LOCK:
        JOBS[job_id] = data
    persist_run(job_id, action, "queued", data)
    audit(action, "queued", actor, {"job_id": job_id, "payload": payload})

    def runner():
        metric_job_running.inc()
        try:
            with JOBS_LOCK:
                JOBS[job_id]["status"] = "running"
                JOBS[job_id]["updated_at"] = now_iso()
            persist_run(job_id, action, "running", JOBS[job_id])
            result = fn(job_id, payload, log_path)
            with JOBS_LOCK:
                JOBS[job_id]["status"] = "success"
                JOBS[job_id]["result"] = result
                JOBS[job_id]["updated_at"] = now_iso()
            persist_run(job_id, action, "success", JOBS[job_id])
            audit(action, "success", actor, {"job_id": job_id})
        except Exception as exc:  # noqa: BLE001
            with JOBS_LOCK:
                JOBS[job_id]["status"] = "failed"
                JOBS[job_id]["error"] = str(exc)
                JOBS[job_id]["updated_at"] = now_iso()
            persist_run(job_id, action, "failed", JOBS[job_id])
            with log_path.open("a", encoding="utf-8") as fh:
                fh.write(f"ERROR: {exc}\n")
            audit(action, "failed", actor, {"job_id": job_id, "error": str(exc)})
        finally:
            metric_job_running.dec()

    threading.Thread(target=runner, daemon=True).start()
    return data


def token_guard(x_ops_token: Optional[str] = Header(default=None, alias="X-OPS-TOKEN")) -> str:
    expected = read_text(TOKEN_FILE)
    if not x_ops_token or x_ops_token != expected:
        raise HTTPException(status_code=403, detail="Invalid ops token")
    return "ops-dashboard"


def extract_snapshot_id_for_run(job_id: str, log_path: Path) -> Optional[str]:
    out = shell(
        ["restic", "-r", str(BACKUP_REPO), "snapshots", "--json", "--tag", f"run:{job_id}"],
        env={"RESTIC_PASSWORD_FILE": str(RESTIC_PASSWORD_FILE)},
        log_path=log_path,
    )
    snaps = json.loads(out.stdout or "[]")
    if not snaps:
        return None
    return snaps[-1].get("id")


def resolve_apps(selected: Optional[List[str]]) -> Dict[str, Dict[str, Any]]:
    apps = load_apps()
    if not selected:
        return apps
    missing = [a for a in selected if a not in apps]
    if missing:
        raise HTTPException(status_code=404, detail=f"Unknown apps: {','.join(missing)}")
    return {a: apps[a] for a in selected}


def list_app_paths(app_cfg: Dict[str, Any]) -> List[Path]:
    paths: List[Path] = []
    compose_dir = Path(app_cfg["compose_dir"])
    if compose_dir.exists():
        for name in ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"]:
            p = compose_dir / name
            if p.exists():
                paths.append(p)
    for key in ["media_paths", "static_paths", "extra_paths"]:
        for raw in app_cfg.get(key, []) or []:
            p = Path(raw)
            if p.exists():
                paths.append(p)
    return sorted(set(paths))


def backup_job(job_id: str, payload: Dict[str, Any], log_path: Path) -> Dict[str, Any]:
    ensure_restic_init()
    apps = resolve_apps(payload.get("apps"))
    scopes = payload.get("scopes") or ["db", "files", "env", "caddy"]
    host = os.uname().nodename

    run_root = BACKUP_WORK / job_id
    db_dir = run_root / "db"
    files_dir = run_root / "files"
    env_dir = run_root / "env"
    caddy_dir = run_root / "caddy"
    for p in [db_dir, files_dir, env_dir, caddy_dir]:
        p.mkdir(parents=True, exist_ok=True)

    manifest = {
        "job_id": job_id,
        "type": "backup",
        "timestamp": now_iso(),
        "apps": list(apps.keys()),
        "scopes": scopes,
        "host": host,
        "artifacts": [],
        "validation": {"ok": True, "checks": []},
        "restic": {},
    }

    recipient = get_public_age_recipient()

    for app_key, cfg in apps.items():
        if "db" in scopes and cfg.get("db_container"):
            db_file = db_dir / f"{app_key}.sql.gz"
            dump_cmd = (
                f"docker exec {cfg['db_container']} pg_dump -U {cfg.get('db_user','postgres')} {cfg.get('db_name', app_key)} | gzip -c > {db_file}"
            )
            shell(["bash", "-lc", dump_cmd], log_path=log_path)
            shell(["gunzip", "-t", str(db_file)], log_path=log_path)
            manifest["artifacts"].append({
                "type": "db",
                "app": app_key,
                "path": str(db_file),
                "size": db_file.stat().st_size,
                "sha256": sha256_file(db_file),
            })

        if "files" in scopes:
            app_paths = list_app_paths(cfg)
            if app_paths:
                bundle = files_dir / f"{app_key}_files.tar.zst"
                shell(["tar", "--zstd", "-cf", str(bundle)] + [str(p) for p in app_paths], log_path=log_path)
                shell(["zstd", "-t", str(bundle)], log_path=log_path)
                shell(["tar", "-tf", str(bundle)], log_path=log_path)
                manifest["artifacts"].append({
                    "type": "files",
                    "app": app_key,
                    "path": str(bundle),
                    "size": bundle.stat().st_size,
                    "sha256": sha256_file(bundle),
                })

        if "env" in scopes:
            env_files = [Path(p) for p in (cfg.get("env_files") or []) if Path(p).exists()]
            if env_files:
                with tempfile.TemporaryDirectory(prefix=f"env-{app_key}-") as tmp:
                    tmp_dir = Path(tmp)
                    for env_file in env_files:
                        rel_name = env_file.name
                        shutil.copy2(env_file, tmp_dir / rel_name)
                    tar_path = env_dir / f"{app_key}_env.tar.zst"
                    enc_path = env_dir / f"{app_key}_env.tar.zst.age"
                    shell(["tar", "--zstd", "-cf", str(tar_path), "-C", str(tmp_dir), "."], log_path=log_path)
                    shell(["age", "-r", recipient, "-o", str(enc_path), str(tar_path)], log_path=log_path)
                    tar_path.unlink(missing_ok=True)
                    manifest["artifacts"].append({
                        "type": "env_encrypted",
                        "app": app_key,
                        "path": str(enc_path),
                        "size": enc_path.stat().st_size,
                        "sha256": sha256_file(enc_path),
                    })

    if "caddy" in scopes:
        caddy_targets = [Path("/home/munaim/srv/proxy/caddy/Caddyfile"), Path("/etc/caddy/Caddyfile")]
        existing = [str(p) for p in caddy_targets if p.exists()]
        if existing:
            bundle = caddy_dir / "caddy_config.tar.zst"
            shell(["tar", "--zstd", "-cf", str(bundle)] + existing, log_path=log_path)
            shell(["zstd", "-t", str(bundle)], log_path=log_path)
            manifest["artifacts"].append({
                "type": "caddy",
                "path": str(bundle),
                "size": bundle.stat().st_size,
                "sha256": sha256_file(bundle),
            })

    scope_tag = "scope:full" if set(scopes) == {"db", "files", "env", "caddy"} else "scope:partial"
    cmd = ["restic", "-r", str(BACKUP_REPO), "backup", str(run_root), "--tag", f"run:{job_id}", "--tag", scope_tag, "--tag", f"server:{host}"]
    for app_key in apps.keys():
        cmd += ["--tag", f"app:{app_key}"]
    shell(cmd, env={"RESTIC_PASSWORD_FILE": str(RESTIC_PASSWORD_FILE)}, log_path=log_path)
    snapshot = extract_snapshot_id_for_run(job_id, log_path)
    manifest["restic"]["snapshot_id"] = snapshot

    run_meta_dir = RUNS_META / job_id
    run_meta_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = run_meta_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    with (run_meta_dir / "checksums.sha256").open("w", encoding="utf-8") as fh:
        for item in manifest["artifacts"]:
            fh.write(f"{item['sha256']}  {item['path']}\n")

    for app_key in apps.keys():
        metric_backup_success.labels(app=app_key).set(1)
        metric_backup_epoch.labels(app=app_key).set(time.time())

    return {"manifest": str(manifest_path), "snapshot_id": snapshot, "work_dir": str(run_root)}


def validate_job(job_id: str, payload: Dict[str, Any], log_path: Path) -> Dict[str, Any]:
    run_id = payload.get("run_id")
    if run_id:
        manifest_path = RUNS_META / run_id / "manifest.json"
        if not manifest_path.exists():
            raise HTTPException(status_code=404, detail="run manifest not found")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        checks = []
        for artifact in manifest.get("artifacts", []):
            p = Path(artifact["path"])
            ok = p.exists() and sha256_file(p) == artifact["sha256"]
            checks.append({"path": artifact["path"], "ok": ok})
            if p.suffix == ".gz":
                shell(["gunzip", "-t", str(p)], log_path=log_path)
            if p.suffixes[-2:] == [".tar", ".zst"] or str(p).endswith(".tar.zst"):
                shell(["zstd", "-t", str(p)], log_path=log_path)
        out = shell(["restic", "-r", str(BACKUP_REPO), "check", "--read-data-subset=1/20"], env={"RESTIC_PASSWORD_FILE": str(RESTIC_PASSWORD_FILE)}, log_path=log_path)
        return {"run_id": run_id, "checks": checks, "restic": out.stdout[-1000:]}

    out = shell(["restic", "-r", str(BACKUP_REPO), "check", "--read-data-subset=1/20"], env={"RESTIC_PASSWORD_FILE": str(RESTIC_PASSWORD_FILE)}, log_path=log_path)
    return {"restic": out.stdout[-1000:]}


def prune_job(job_id: str, payload: Dict[str, Any], log_path: Path) -> Dict[str, Any]:
    out = shell(
        [
            "restic",
            "-r",
            str(BACKUP_REPO),
            "forget",
            "--keep-daily",
            str(RETENTION["daily"]),
            "--keep-weekly",
            str(RETENTION["weekly"]),
            "--keep-monthly",
            str(RETENTION["monthly"]),
            "--prune",
        ],
        env={"RESTIC_PASSWORD_FILE": str(RESTIC_PASSWORD_FILE)},
        log_path=log_path,
    )
    return {"output": out.stdout[-2000:]}


def ensure_restore_source(run_id: str, log_path: Path) -> Path:
    src = BACKUP_WORK / run_id
    if src.exists():
        return src
    temp_target = Path(tempfile.mkdtemp(prefix=f"restore-{run_id}-", dir="/tmp"))
    shell(
        ["restic", "-r", str(BACKUP_REPO), "restore", "latest", "--tag", f"run:{run_id}", "--target", str(temp_target)],
        env={"RESTIC_PASSWORD_FILE": str(RESTIC_PASSWORD_FILE)},
        log_path=log_path,
    )
    restored = temp_target / "srv" / "backups" / "work" / run_id
    if not restored.exists():
        raise RuntimeError("restored run directory not found")
    return restored


def restore_db(run_dir: Path, apps: Dict[str, Dict[str, Any]], log_path: Path, force_same_server: bool) -> None:
    for app_key, cfg in apps.items():
        dump_file = run_dir / "db" / f"{app_key}.sql.gz"
        if not dump_file.exists():
            continue
        if not force_same_server:
            raise RuntimeError("same-server DB restore blocked; set allow_same_server=true")
        count_cmd = f"docker exec {cfg['db_container']} psql -U {cfg.get('db_user', 'postgres')} -d {cfg.get('db_name', app_key)} -tAc \"SELECT count(*) FROM information_schema.tables WHERE table_schema='public';\""
        out = shell(["bash", "-lc", count_cmd], log_path=log_path)
        try:
            tables = int((out.stdout or "0").strip() or "0")
        except ValueError:
            tables = 999999
        if tables > 0:
            raise RuntimeError(f"db not empty for {app_key}; refusing restore")
        restore_cmd = f"gunzip -c {dump_file} | docker exec -i {cfg['db_container']} psql -U {cfg.get('db_user','postgres')} -d {cfg.get('db_name', app_key)}"
        shell(["bash", "-lc", restore_cmd], log_path=log_path)


def restore_files(run_dir: Path, log_path: Path) -> None:
    for archive in (run_dir / "files").glob("*_files.tar.zst"):
        shell(["tar", "--zstd", "-xf", str(archive), "-P"], log_path=log_path)


def restore_caddy(run_dir: Path, log_path: Path) -> None:
    caddy_archive = run_dir / "caddy" / "caddy_config.tar.zst"
    if caddy_archive.exists():
        shell(["tar", "--zstd", "-xf", str(caddy_archive), "-P"], log_path=log_path)


def write_restore_guide(path: Path, run_id: str) -> None:
    content = f"""# RESTORE GUIDE\n\nRun ID: {run_id}\n\n1. Install restic, docker, age, zstd.\n2. Place encrypted env files and age key on destination.\n3. For DB restore use `opsctl.sh restore` with typed confirmation.\n4. Extract file archives with absolute paths only on intended host.\n5. Restore Caddyfile and reload Caddy after validation.\n"""
    path.write_text(content, encoding="utf-8")


def export_bundle_job(job_id: str, payload: Dict[str, Any], log_path: Path) -> Dict[str, Any]:
    run_id = payload.get("run_id")
    if not run_id:
        raise RuntimeError("run_id is required")
    run_dir = ensure_restore_source(run_id, log_path)
    bundle_dir = Path(tempfile.mkdtemp(prefix=f"bundle-{run_id}-", dir="/tmp"))
    dest_dir = bundle_dir / f"restore_bundle_{run_id}"
    shutil.copytree(run_dir, dest_dir, dirs_exist_ok=True)
    write_restore_guide(dest_dir / "RESTORE_GUIDE.md", run_id)
    out_file = BACKUP_META / f"restore_bundle_{run_id}.tar.zst"
    shell(["tar", "--zstd", "-cf", str(out_file), "-C", str(bundle_dir), dest_dir.name], log_path=log_path)
    return {"bundle": str(out_file)}


def restore_job(job_id: str, payload: Dict[str, Any], log_path: Path) -> Dict[str, Any]:
    run_id = payload.get("run_id")
    mode = payload.get("mode", "validate-only")
    typed = payload.get("typed_confirmation", "")
    allow_same_server = bool(payload.get("allow_same_server", False))
    if mode not in ["validate-only", "restore-db", "restore-files", "restore-caddy", "full", "export-bundle"]:
        raise RuntimeError("unsupported mode")
    if mode in ["restore-db", "restore-files", "restore-caddy", "full"]:
        expected = f"RESTORE {run_id}"
        if typed != expected:
            raise RuntimeError(f"typed confirmation mismatch; expected '{expected}'")

    if mode == "export-bundle":
        return export_bundle_job(job_id, payload, log_path)

    run_dir = ensure_restore_source(run_id, log_path)
    apps = resolve_apps(payload.get("apps"))

    if mode == "validate-only":
        return validate_job(job_id, {"run_id": run_id}, log_path)
    if mode in ["restore-db", "full"]:
        restore_db(run_dir, apps, log_path, allow_same_server)
    if mode in ["restore-files", "full"]:
        restore_files(run_dir, log_path)
    if mode in ["restore-caddy", "full"]:
        restore_caddy(run_dir, log_path)
    return {"restored_mode": mode, "run_id": run_id}


def list_rclone_remotes() -> List[str]:
    if not RCLONE_CONF.exists():
        return []
    out = shell(["rclone", "listremotes", "--config", str(RCLONE_CONF)], check=False)
    return [x.strip().rstrip(":") for x in out.stdout.splitlines() if x.strip()]


def upload_job(job_id: str, payload: Dict[str, Any], log_path: Path) -> Dict[str, Any]:
    remote = payload.get("remote")
    remote_path = payload.get("remote_path", "ops-backups")
    run_id = payload.get("run_id")
    if not remote:
        raise RuntimeError("remote is required")
    if remote not in list_rclone_remotes():
        raise RuntimeError("remote not configured")

    if payload.get("latest", False):
        manifests = sorted([p.parent.name for p in RUNS_META.glob("*/manifest.json")])
        if not manifests:
            raise RuntimeError("no runs available")
        run_id = manifests[-1]

    if not run_id:
        raise RuntimeError("run_id required")

    src = RUNS_META / run_id
    if not src.exists():
        raise RuntimeError("run metadata not found")

    shell(
        [
            "rclone",
            "copy",
            str(src),
            f"{remote}:{remote_path}/{run_id}",
            "--config",
            str(RCLONE_CONF),
        ],
        log_path=log_path,
    )
    return {"uploaded": run_id, "remote": remote, "remote_path": remote_path}


def docker_status() -> Dict[str, Any]:
    apps = load_apps()
    result = []
    for app_key, cfg in apps.items():
        containers = []
        container_names = cfg.get("containers", [])
        if not container_names:
            # derive from compose labels if app config was minimal
            container_names = []
        for name in container_names:
            out = shell(["docker", "inspect", name], check=False)
            if out.returncode != 0:
                containers.append({"name": name, "status": "not_found"})
                continue
            data = json.loads(out.stdout)[0]
            state = data.get("State", {})
            containers.append(
                {
                    "name": name,
                    "status": state.get("Status", "unknown"),
                    "health": (state.get("Health") or {}).get("Status", "n/a"),
                    "started_at": state.get("StartedAt"),
                    "image": (data.get("Config") or {}).get("Image"),
                }
            )
        result.append({"app_key": app_key, "containers": containers})
    return {"apps": result, "checked_at": now_iso()}


class BackupRequest(BaseModel):
    apps: Optional[List[str]] = None
    scopes: List[str] = Field(default_factory=lambda: ["db", "files", "env", "caddy"])


class ValidateRequest(BaseModel):
    run_id: Optional[str] = None


class RestoreRequest(BaseModel):
    run_id: str
    mode: str = "validate-only"
    apps: Optional[List[str]] = None
    typed_confirmation: str = ""
    allow_same_server: bool = False


class UploadRequest(BaseModel):
    remote: str
    remote_path: str = "ops-backups"
    run_id: Optional[str] = None
    latest: bool = False


@APP.on_event("startup")
def startup() -> None:
    init_db()
    ensure_restic_init()


@APP.get("/health")
def health() -> Dict[str, Any]:
    return {"status": "ok", "version": APP.version, "timestamp": now_iso(), "deps": {"restic_repo": str(BACKUP_REPO)}}


@APP.get("/metrics")
def metrics() -> PlainTextResponse:
    return PlainTextResponse(generate_latest(registry).decode("utf-8"), media_type=CONTENT_TYPE_LATEST)


@APP.get("/status/apps", dependencies=[Depends(token_guard)])
def status_apps() -> Dict[str, Any]:
    return docker_status()


@APP.get("/runs", dependencies=[Depends(token_guard)])
def runs() -> Dict[str, Any]:
    manifests = []
    for mp in sorted(RUNS_META.glob("*/manifest.json"), reverse=True):
        try:
            manifests.append(json.loads(mp.read_text(encoding="utf-8")))
        except Exception:
            continue
    snapshots = json.loads(
        shell(["restic", "-r", str(BACKUP_REPO), "snapshots", "--json"], env={"RESTIC_PASSWORD_FILE": str(RESTIC_PASSWORD_FILE)}, check=False).stdout
        or "[]"
    )
    return {"runs": manifests, "snapshots": snapshots}


@APP.get("/jobs/{job_id}", dependencies=[Depends(token_guard)])
def job(job_id: str) -> Dict[str, Any]:
    with JOBS_LOCK:
        data = JOBS.get(job_id)
    if data:
        return data
    con = sqlite3.connect(DB_META)
    cur = con.cursor()
    cur.execute("SELECT payload_json FROM runs WHERE job_id=?", (job_id,))
    row = cur.fetchone()
    con.close()
    if not row:
        raise HTTPException(status_code=404, detail="job not found")
    return json.loads(row[0])


@APP.get("/runs/{run_id}/manifest", dependencies=[Depends(token_guard)])
def manifest(run_id: str) -> JSONResponse:
    p = RUNS_META / run_id / "manifest.json"
    if not p.exists():
        raise HTTPException(status_code=404, detail="manifest not found")
    return JSONResponse(content=json.loads(p.read_text(encoding="utf-8")))


@APP.get("/runs/{run_id}/log", dependencies=[Depends(token_guard)])
def run_log(run_id: str) -> PlainTextResponse:
    p = RUN_LOG_DIR / f"{run_id}.log"
    if not p.exists():
        raise HTTPException(status_code=404, detail="run log not found")
    return PlainTextResponse(p.read_text(encoding="utf-8"))


@APP.get("/cloud/remotes", dependencies=[Depends(token_guard)])
def cloud_remotes() -> Dict[str, Any]:
    return {"remotes": list_rclone_remotes()}


@APP.post("/cloud/test", dependencies=[Depends(token_guard)])
def cloud_test(body: Dict[str, str]) -> Dict[str, Any]:
    remote = body.get("remote")
    if not remote:
        raise HTTPException(status_code=400, detail="remote required")
    if remote not in list_rclone_remotes():
        raise HTTPException(status_code=404, detail="remote not configured")
    out = shell(["rclone", "lsd", f"{remote}:", "--config", str(RCLONE_CONF)], check=False)
    return {"ok": out.returncode == 0, "output": out.stdout[-500:], "error": out.stderr[-500:]}


@APP.post("/actions/backup", dependencies=[Depends(token_guard)])
def action_backup(req: BackupRequest, actor: str = Depends(token_guard)) -> Dict[str, Any]:
    return start_job("backup", req.model_dump(), actor, backup_job)


@APP.post("/actions/validate", dependencies=[Depends(token_guard)])
def action_validate(req: ValidateRequest, actor: str = Depends(token_guard)) -> Dict[str, Any]:
    return start_job("validate", req.model_dump(), actor, validate_job)


@APP.post("/actions/prune", dependencies=[Depends(token_guard)])
def action_prune(actor: str = Depends(token_guard)) -> Dict[str, Any]:
    return start_job("prune", {}, actor, prune_job)


@APP.post("/actions/restore", dependencies=[Depends(token_guard)])
def action_restore(req: RestoreRequest, actor: str = Depends(token_guard)) -> Dict[str, Any]:
    return start_job("restore", req.model_dump(), actor, restore_job)


@APP.post("/actions/export", dependencies=[Depends(token_guard)])
def action_export(req: Dict[str, str], actor: str = Depends(token_guard)) -> Dict[str, Any]:
    run_id = req.get("run_id")
    if not run_id:
        raise HTTPException(status_code=400, detail="run_id required")
    return start_job("export_bundle", {"run_id": run_id}, actor, export_bundle_job)


@APP.post("/actions/upload/latest", dependencies=[Depends(token_guard)])
def action_upload_latest(req: UploadRequest, actor: str = Depends(token_guard)) -> Dict[str, Any]:
    payload = req.model_dump()
    payload["latest"] = True
    return start_job("upload_latest", payload, actor, upload_job)


@APP.post("/actions/upload/snapshot", dependencies=[Depends(token_guard)])
def action_upload_snapshot(req: UploadRequest, actor: str = Depends(token_guard)) -> Dict[str, Any]:
    payload = req.model_dump()
    payload["latest"] = False
    return start_job("upload_snapshot", payload, actor, upload_job)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(APP, host="127.0.0.1", port=9753)
