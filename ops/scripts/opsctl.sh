#!/bin/bash
TOKEN_FILE="/home/munaim/srv/ops/config/ops_token.txt"
if [ ! -f "$TOKEN_FILE" ]; then
    echo "Error: Token file not found"
    exit 1
fi
TOKEN=$(cat "$TOKEN_FILE")
ENDPOINT="http://127.0.0.1:9753"

case "$1" in
    backup)
        if [ -z "$2" ]; then
            echo "Usage: $0 backup <app_id|all>"
            exit 1
        fi
        curl -X POST -H "X-OPS-TOKEN: $TOKEN" "$ENDPOINT/backup/$2"
        ;;
    list)
        curl -H "X-OPS-TOKEN: $TOKEN" "$ENDPOINT/backups" | jq .
        ;;
    validate)
        curl -X POST -H "X-OPS-TOKEN: $TOKEN" "$ENDPOINT/validate"
        ;;
    prune)
        curl -X POST -H "X-OPS-TOKEN: $TOKEN" "$ENDPOINT/prune"
        ;;
    health)
        curl "$ENDPOINT/health"
        ;;
    *)
        echo "Usage: $0 {backup|list|validate|prune|health}"
        exit 1
        ;;
esac
