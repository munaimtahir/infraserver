#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <compose-file> <local-port> <domain1,domain2,...> [health-path]"
  exit 1
fi

COMPOSE_FILE="$1"
LOCAL_PORT="$2"
DOMAINS_CSV="$3"
HEALTH_PATH="${4:-/health}"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Compose file not found: $COMPOSE_FILE"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$COMPOSE_FILE")" && pwd)"
IFS=',' read -r -a DOMAINS <<< "$DOMAINS_CSV"

echo "== Validate compose =="
docker compose -f "$COMPOSE_FILE" config >/dev/null

echo "== Current status =="
docker compose -f "$COMPOSE_FILE" ps || true

echo "== Deploy =="
cd "$PROJECT_DIR"
docker compose -f "$COMPOSE_FILE" pull || true
docker compose -f "$COMPOSE_FILE" build || true
docker compose -f "$COMPOSE_FILE" up -d

echo "== Post-deploy status =="
docker compose -f "$COMPOSE_FILE" ps

echo "== Local verify =="
curl -fsS -I "http://127.0.0.1:${LOCAL_PORT}" | head -n 20
curl -fsS "http://127.0.0.1:${LOCAL_PORT}${HEALTH_PATH}" | head -c 300 || true
echo

echo "== Public verify =="
for domain in "${DOMAINS[@]}"; do
  echo "-- $domain"
  curl -fsS -I "https://${domain}" | head -n 20 || true
  curl -fsS -I "https://${domain}/api/" | head -n 20 || true
  curl -fsS -I "https://${domain}/admin/" | head -n 20 || true
  echo
done

