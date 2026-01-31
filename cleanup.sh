
```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# App-only Docker cleanup (keeps Caddy untouched)
# - Removes non-Caddy containers (running + stopped)
# - Removes now-unused images
# - Prunes builder cache
# - Optionally prunes unused volumes (OFF by default)
#
# Usage:
#   ./docker_app_cleanup.sh --dry-run
#   ./docker_app_cleanup.sh --force
#   ./docker_app_cleanup.sh --force --prune-volumes
#
# Notes:
# - "Caddy containers" are detected by:
#   * container name containing "caddy"
#   * OR image repo containing "caddy"
#   * OR label caddy=true (if you add it in the future)
# ============================================================

DRY_RUN=0
FORCE=0
PRUNE_VOLUMES=0

for arg in "${@:-}"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --prune-volumes) PRUNE_VOLUMES=1 ;;
    -h|--help)
      cat <<'EOF'
Usage:
  docker_app_cleanup.sh [--dry-run] [--force] [--prune-volumes]

Flags:
  --dry-run        Show what would be removed, do nothing
  --force          Do not ask for confirmation
  --prune-volumes  ALSO remove unused volumes (dangerous if you keep data in volumes)
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }; }
need_cmd docker

echo "==> Docker app-only cleanup (Caddy will be preserved)"
echo "    Dry-run:        $DRY_RUN"
echo "    Force:          $FORCE"
echo "    Prune volumes:  $PRUNE_VOLUMES"
echo

# --- Identify Caddy containers (to exclude) ---
# Criteria:
# 1) name contains 'caddy' (case-insensitive)
# 2) image contains '/caddy' or starts with 'caddy'
# 3) label caddy=true (optional)
mapfile -t CADDY_IDS < <(
  docker ps -a --format '{{.ID}} {{.Names}} {{.Image}} {{.Labels}}' | awk '
    BEGIN{IGNORECASE=1}
    {
      id=$1; name=$2; image=$3; labels=$0;
      if (name ~ /caddy/ || image ~ /(^|\/)caddy(:|$)/ || labels ~ /caddy=true/) {
        print id
      }
    }'
)

# --- Identify NON-Caddy containers (targets) ---
mapfile -t TARGET_IDS < <(
  docker ps -a --format '{{.ID}} {{.Names}} {{.Image}}' | awk -v caddy_ids="${CADDY_IDS[*]:-}" '
    BEGIN{
      split(caddy_ids, arr, " ");
      for(i in arr) if(arr[i]!="") keep[arr[i]]=1;
    }
    {
      id=$1;
      if(!(id in keep)) print id;
    }'
)

if ((${#TARGET_IDS[@]} == 0)); then
  echo "No non-Caddy containers found. Nothing to remove."
else
  echo "Non-Caddy containers that will be removed:"
  docker ps -a --format '  - {{.ID}}  {{.Names}}  ({{.Image}})' | \
    awk -v targets="${TARGET_IDS[*]}" '
      BEGIN{split(targets,t," "); for(i in t) sel[t[i]]=1;}
      {id=$2; if(sel[id]) print $0;}
    ' || true

  echo
  if ((DRY_RUN==1)); then
    echo "[DRY-RUN] Would stop & remove the above containers."
  else
    if ((FORCE==0)); then
      read -r -p "Proceed to stop & remove these containers? Type YES to continue: " ans
      if [[ "$ans" != "YES" ]]; then
        echo "Aborted."
        exit 0
      fi
    fi

    echo "Stopping non-Caddy containers (if running)..."
    docker stop "${TARGET_IDS[@]}" >/dev/null 2>&1 || true

    echo "Removing non-Caddy containers..."
    docker rm -f "${TARGET_IDS[@]}" >/dev/null
  fi
fi

echo
echo "==> Removing unused images (safe: in-use images like Caddy will not be removed)"
if ((DRY_RUN==1)); then
  echo "[DRY-RUN] Would run: docker image prune -a -f"
else
  docker image prune -a -f >/dev/null
fi

echo
echo "==> Pruning Docker build cache (builder cache)"
if ((DRY_RUN==1)); then
  echo "[DRY-RUN] Would run: docker builder prune -a -f"
else
  docker builder prune -a -f >/dev/null
fi

if ((PRUNE_VOLUMES==1)); then
  echo
  echo "==> Pruning unused volumes (WARNING: this can delete data if apps stored data in named volumes)"
  if ((DRY_RUN==1)); then
    echo "[DRY-RUN] Would run: docker volume prune -f"
  else
    docker volume prune -f >/dev/null
  fi
else
  echo
  echo "==> Volume prune skipped (recommended)."
fi

echo
echo "==> Summary"
docker system df
echo
echo "Done. Caddy containers were not modified."
```

