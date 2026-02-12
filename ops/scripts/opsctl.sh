#!/usr/bin/env bash
set -euo pipefail

OPS_URL="${OPS_URL:-http://127.0.0.1:9753}"
TOKEN_FILE="${OPS_TOKEN_FILE:-/home/munaim/srv/ops/config/ops_token.txt}"
TOKEN="$(cat "$TOKEN_FILE")"

json_post() {
  local endpoint="$1"
  local body="${2:-{}}"
  curl -sS -X POST "$OPS_URL$endpoint" \
    -H "Content-Type: application/json" \
    -H "X-OPS-TOKEN: $TOKEN" \
    -d "$body"
}

case "${1:-}" in
  health)
    curl -sS "$OPS_URL/health"
    ;;
  runs)
    curl -sS -H "X-OPS-TOKEN: $TOKEN" "$OPS_URL/runs"
    ;;
  backup)
    apps="${2:-}"
    if [[ -n "$apps" ]]; then
      json_post "/actions/backup" "{\"apps\":[$(echo "$apps" | awk -F, '{for(i=1;i<=NF;i++)printf "\""$i"\"%s",(i<NF?",":"") }')],\"scopes\":[\"db\",\"files\",\"env\",\"caddy\"]}"
    else
      json_post "/actions/backup" '{"scopes":["db","files","env","caddy"]}'
    fi
    ;;
  validate)
    run_id="${2:-}"
    if [[ -n "$run_id" ]]; then
      json_post "/actions/validate" "{\"run_id\":\"$run_id\"}"
    else
      json_post "/actions/validate" '{}'
    fi
    ;;
  prune)
    json_post "/actions/prune" '{}'
    ;;
  restore)
    run_id="${2:-}"
    mode="${3:-validate-only}"
    typed="${4:-}"
    allow="${5:-false}"
    [[ -n "$run_id" ]] || { echo "usage: $0 restore <run_id> <mode> [typed] [allow_same_server]"; exit 1; }
    json_post "/actions/restore" "{\"run_id\":\"$run_id\",\"mode\":\"$mode\",\"typed_confirmation\":\"$typed\",\"allow_same_server\":$allow}"
    ;;
  export)
    run_id="${2:-}"
    [[ -n "$run_id" ]] || { echo "usage: $0 export <run_id>"; exit 1; }
    json_post "/actions/export" "{\"run_id\":\"$run_id\"}"
    ;;
  upload-latest)
    remote="${2:-}"
    [[ -n "$remote" ]] || { echo "usage: $0 upload-latest <remote> [remote_path]"; exit 1; }
    remote_path="${3:-ops-backups}"
    json_post "/actions/upload/latest" "{\"remote\":\"$remote\",\"remote_path\":\"$remote_path\"}"
    ;;
  upload-run)
    remote="${2:-}"
    run_id="${3:-}"
    remote_path="${4:-ops-backups}"
    [[ -n "$remote" && -n "$run_id" ]] || { echo "usage: $0 upload-run <remote> <run_id> [remote_path]"; exit 1; }
    json_post "/actions/upload/snapshot" "{\"remote\":\"$remote\",\"run_id\":\"$run_id\",\"remote_path\":\"$remote_path\"}"
    ;;
  remotes)
    curl -sS -H "X-OPS-TOKEN: $TOKEN" "$OPS_URL/cloud/remotes"
    ;;
  test-remote)
    remote="${2:-}"
    [[ -n "$remote" ]] || { echo "usage: $0 test-remote <remote>"; exit 1; }
    json_post "/cloud/test" "{\"remote\":\"$remote\"}"
    ;;
  job)
    job_id="${2:-}"
    [[ -n "$job_id" ]] || { echo "usage: $0 job <job_id>"; exit 1; }
    curl -sS -H "X-OPS-TOKEN: $TOKEN" "$OPS_URL/jobs/$job_id"
    ;;
  *)
    echo "usage: $0 {health|runs|backup|validate|prune|restore|export|upload-latest|upload-run|remotes|test-remote|job}"
    exit 1
    ;;
esac
