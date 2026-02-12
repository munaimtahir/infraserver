import os
import subprocess
import yaml
import logging
import time
import json
import shutil
import hashlib
from datetime import datetime
from typing import List, Optional, Dict
from fastapi import FastAPI, Header, HTTPException, Request, BackgroundTasks, Depends
from pydantic import BaseModel
from prometheus_client import CollectorRegistry, Gauge, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

app = FastAPI(title="Al-Shifa Ops Agent")

# Logging setup
LOG_DIR = "/home/munaim/srv/ops/logs"
os.makedirs(LOG_DIR, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f"{LOG_DIR}/agent.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("ops-agent")

# Configuration Paths
APPS_CONFIG = "/home/munaim/srv/ops/config/apps.yml"
OPS_TOKEN_FILE = "/home/munaim/srv/ops/config/ops_token.txt"
RESTIC_PW_FILE = "/home/munaim/srv/ops/config/restic_password.txt"
RESTIC_REPO = "/srv/backups/restic_repo"
WORK_DIR = "/srv/backups/work"
META_DIR = "/srv/backups/meta"
ALLOW_PROD_RESTORE_FILE = "/home/munaim/srv/ops/config/ALLOW_PROD_RESTORE"

# Metrics Registry
registry = CollectorRegistry()
backup_success = Gauge('ops_backup_success', 'Backup success status (1=OK, 0=FAIL)', ['app_id'], registry=registry)
backup_duration = Gauge('ops_backup_duration_seconds', 'Duration of last backup', ['app_id'], registry=registry)
last_backup_time = Gauge('ops_last_backup_timestamp', 'Timestamp of last successful backup', ['app_id'], registry=registry)

def get_ops_token():
    try:
        with open(OPS_TOKEN_FILE, 'r') as f:
            return f.read().strip()
    except Exception as e:
        logger.error(f"Failed to read OPS_TOKEN_FILE: {e}")
        return None

def verify_token(x_ops_token: str = Header(None)):
    token = get_ops_token()
    if not token or x_ops_token != token:
        logger.warning(f"Unauthorized access attempt with token: {x_ops_token}")
        raise HTTPException(status_code=403, detail="Invalid or missing OPS Token")

def run_cmd(cmd: List[str], env: Optional[Dict] = None, check: bool = True):
    logger.info(f"Running command: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if check and result.returncode != 0:
        logger.error(f"Command failed: {result.stderr}")
        raise Exception(f"Command failed with exit code {result.returncode}: {result.stderr}")
    return result

def init_restic():
    if not os.path.exists(os.path.join(RESTIC_REPO, "config")):
        logger.info("Initializing restic repository...")
        env = os.environ.copy()
        env["RESTIC_PASSWORD_FILE"] = RESTIC_PW_FILE
        run_cmd(["restic", "-r", RESTIC_REPO, "init"], env=env)

class BackupJob:
    def __init__(self, app_id: str, config: dict):
        self.app_id = app_id
        self.config = config
        self.run_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.work_path = os.path.join(WORK_DIR, self.run_id, app_id)
        self.manifest = {
            "app_id": app_id,
            "run_id": self.run_id,
            "timestamp": datetime.now().isoformat(),
            "files": []
        }

    def execute(self):
        start_time = time.time()
        try:
            os.makedirs(self.work_path, exist_ok=True)
            self._dump_db()
            self._package_files()
            self._extract_env()
            self._run_restic_backup()
            
            duration = time.time() - start_time
            backup_success.labels(app_id=self.app_id).set(1)
            backup_duration.labels(app_id=self.app_id).set(duration)
            last_backup_time.labels(app_id=self.app_id).set(time.time())
            
            self._save_manifest()
            logger.info(f"Backup completed for {self.app_id} in {duration:.2f}s")
            return {"status": "success", "run_id": self.run_id}
        except Exception as e:
            backup_success.labels(app_id=self.app_id).set(0)
            logger.error(f"Backup failed for {self.app_id}: {e}")
            return {"status": "error", "message": str(e)}
        finally:
            if os.path.exists(os.path.dirname(self.work_path)):
                shutil.rmtree(os.path.dirname(self.work_path))

    def _dump_db(self):
        db_container = self.config.get("db_container")
        if not db_container: return
        
        dump_file = f"{self.app_id}_db.sql.gz"
        dest = os.path.join(self.work_path, dump_file)
        cmd = [
            "docker", "exec", db_container, 
            "pg_dump", "-U", self.config.get("db_user", "postgres"), 
            self.config.get("db_name", self.app_id)
        ]
        logger.info(f"Dumping database for {self.app_id}...")
        with open(dest, "wb") as f:
            p1 = subprocess.Popen(cmd, stdout=subprocess.PIPE)
            p2 = subprocess.Popen(["gzip"], stdin=p1.stdout, stdout=f)
            p1.stdout.close()
            p2.communicate()
        
        self.manifest["files"].append({"name": dump_file, "type": "db_dump"})

    def _package_files(self):
        compose_dir = self.config.get("compose_dir")
        if not compose_dir: return
        
        bundle_file = f"{self.app_id}_files.tar.zst"
        dest = os.path.join(self.work_path, bundle_file)
        
        # Paths to include
        paths = ["docker-compose.yml", "compose.yml", "Caddyfile"]
        paths.extend(self.config.get("media_paths", []))
        paths.extend(self.config.get("static_paths", []))
        
        valid_paths = []
        for p in paths:
            full_p = os.path.join(compose_dir, p)
            if os.path.exists(full_p):
                valid_paths.append(p)
        
        if valid_paths:
            run_cmd(["tar", "--zstd", "-cf", dest, "-C", compose_dir] + valid_paths)
            self.manifest["files"].append({"name": bundle_file, "type": "app_files"})

    def _extract_env(self):
        compose_dir = self.config.get("compose_dir")
        env_files = self.config.get("env_files", [])
        for env_f in env_files:
            src = os.path.join(compose_dir, env_f)
            if os.path.exists(src):
                dest = os.path.join(self.work_path, f"{env_f}.bundle")
                # age encryption could be added here, for now just copy carefully
                shutil.copy2(src, dest)
                self.manifest["files"].append({"name": f"{env_f}.bundle", "type": "env_file"})

    def _run_restic_backup(self):
        env = os.environ.copy()
        env["RESTIC_PASSWORD_FILE"] = RESTIC_PW_FILE
        run_cmd([
            "restic", "-r", RESTIC_REPO, "backup", 
            os.path.dirname(self.work_path), 
            "--tag", self.app_id, 
            "--tag", f"run_{self.run_id}"
        ], env=env)

    def _save_manifest(self):
        meta_path = os.path.join(META_DIR, self.app_id)
        os.makedirs(meta_path, exist_ok=True)
        with open(os.path.join(meta_path, f"manifest_{self.run_id}.json"), "w") as f:
            json.dump(self.manifest, f, indent=2)

@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(registry), media_type=CONTENT_TYPE_LATEST)

@app.post("/backup/{app_id}", dependencies=[Depends(verify_token)])
def trigger_backup(app_id: str, background_tasks: BackgroundTasks):
    with open(APPS_CONFIG, 'r') as f:
        config = yaml.safe_load(f)
    
    if app_id not in config.get("apps", {}):
        raise HTTPException(status_code=404, detail="App not found in config")
    
    app_cfg = config["apps"][app_id]
    job = BackupJob(app_id, app_cfg)
    background_tasks.add_task(job.execute)
    
    return {"status": "queued", "run_id": job.run_id}

@app.get("/backups", dependencies=[Depends(verify_token)])
def list_backups(app_id: Optional[str] = None):
    env = os.environ.copy()
    env["RESTIC_PASSWORD_FILE"] = RESTIC_PW_FILE
    cmd = ["restic", "-r", RESTIC_REPO, "snapshots", "--json"]
    if app_id:
        cmd += ["--tag", app_id]
    
    result = run_cmd(cmd, env=env)
    return json.loads(result.stdout)

@app.post("/validate", dependencies=[Depends(verify_token)])
def validate_repo():
    env = os.environ.copy()
    env["RESTIC_PASSWORD_FILE"] = RESTIC_PW_FILE
    result = run_cmd(["restic", "-r", RESTIC_REPO, "check"], env=env)
    return {"status": "ok", "output": result.stdout}

@app.post("/prune", dependencies=[Depends(verify_token)])
def prune_backups():
    env = os.environ.copy()
    env["RESTIC_PASSWORD_FILE"] = RESTIC_PW_FILE
    # keep-daily 14, keep-weekly 8, keep-monthly 12
    cmd = [
        "restic", "-r", RESTIC_REPO, "forget", 
        "--keep-daily", "14", "--keep-weekly", "8", "--keep-monthly", "12", 
        "--prune"
    ]
    result = run_cmd(cmd, env=env)
    return {"status": "ok", "output": result.stdout}

if __name__ == "__main__":
    import uvicorn
    init_restic()
    uvicorn.run(app, host="127.0.0.1", port=9753)
