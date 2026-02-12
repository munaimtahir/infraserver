#!/usr/bin/env bash
set -euo pipefail

CADDYFILE="/home/munaim/srv/proxy/caddy/Caddyfile"

json=$(caddy adapt --config "$CADDYFILE" --adapter caddyfile 2>/dev/null)

mapfile -t hosts < <(jq -r '.apps.http.servers|to_entries[]|.value.routes[]?|.match[]?.host[]?' <<<"$json" | sort -u)
mapfile -t pairs < <(jq -r '
  .apps.http.servers
  | to_entries[]
  | .value.routes[]? as $r
  | ($r.match[]?.host[]? // empty) as $h
  | select($h != "")
  | [ $r | .. | objects | select(.handler? == "reverse_proxy") | .upstreams[]?.dial ] as $ups
  | $ups[]
  | "\($h)|\(.)"
' <<<"$json")

declare -A upmap
for p in "${pairs[@]}"; do
  h=${p%%|*}
  u=${p##*|}
  if [[ -n "${upmap[$h]:-}" ]]; then
    upmap[$h]="${upmap[$h]},$u"
  else
    upmap[$h]="$u"
  fi
done

dedupe_csv() {
  local csv="$1"
  printf '%s\n' "$csv" | tr ',' '\n' | awk 'NF && !seen[$0]++' | paste -sd, -
}

compose_hint() {
  local ups="$1"
  case "$ups" in
    *8012*) echo "/home/munaim/srv/apps/lims/docker-compose.prod.yml" ;;
    *8015*|*8081*) echo "/home/munaim/srv/apps/radreport/docker-compose.prod.yml" ;;
    *8016*) echo "/home/munaim/srv/apps/accredivault/infra/docker-compose.prod.yml" ;;
    *8013*|*4000*) echo "/home/munaim/srv/dashboard/docker-compose.yml + /home/munaim/srv/apps/launchpad/docker-compose.yml" ;;
    *13000*) echo "/home/munaim/srv/observability/docker-compose.yml" ;;
    *8010*) echo "/home/munaim/srv/apps/fmu-platform/docker-compose.yml" ;;
    *8011*) echo "/home/munaim/srv/apps/consult/docker-compose.yml" ;;
    *8014*|*8082*) echo "/home/munaim/srv/apps/pgsims/docker-compose.yml" ;;
    *8017*|*8083*) echo "/home/munaim/srv/apps/accredivault/infra/docker-compose.prod.yml (sos planned)" ;;
    *) echo "-" ;;
  esac
}

printf '%-32s %-28s %-20s %-6s %-10s %-12s %s\n' "DOMAIN" "UPSTREAMS" "COMPOSE_HINT" "LISTEN" "HTTP" "FLAGS" "NOTES"
for h in "${hosts[@]}"; do
  ups="${upmap[$h]:--}"
  [[ "$ups" != "-" ]] && ups="$(dedupe_csv "$ups")"
  listen="n/a"
  flags=()

  if [[ "$ups" != "-" ]]; then
    listen="up"
    IFS=',' read -r -a arr <<< "$ups"
    for u in "${arr[@]}"; do
      hostpart="${u%:*}"
      port="${u##*:}"
      if [[ "$hostpart" != "127.0.0.1" && "$hostpart" != "localhost" ]]; then
        flags+=("DEV_LEAK")
      fi
      if [[ "$port" == "8080" || "$port" == "8082" || "$port" == "8083" ]]; then
        flags+=("DEV_LEAK")
      fi
      if ! ss -ltn "( sport = :$port )" | grep -q ":$port"; then
        listen="down"
      fi
    done
    [[ "$listen" == "down" ]] && flags+=("UPSTREAM_DOWN")
  fi

  code=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 8 --resolve "$h:443:127.0.0.1" "https://$h" 2>/dev/null || true)
  if [[ -z "$code" || "$code" == "000" ]]; then
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 6 -H "Host: $h" "http://127.0.0.1/" 2>/dev/null || echo "ERR")
  fi
  [[ "$code" == "503" ]] && flags+=("OFFLINE_DOMAIN")
  if [[ "$ups" == "-" && "$h" != "34.16.82.13" ]]; then
    flags+=("OFFLINE_DOMAIN")
  fi

  if [[ ${#flags[@]} -eq 0 ]]; then
    flag_txt="OK"
  else
    flag_txt=$(printf '%s\n' "${flags[@]}" | awk '!seen[$0]++' | paste -sd, -)
  fi

  note=""
  [[ "$ups" == "-" ]] && note="maintenance/no-upstream"
  printf '%-32s %-28s %-20s %-6s %-10s %-12s %s\n' "$h" "$ups" "$(compose_hint "$ups")" "$listen" "$code" "$flag_txt" "$note"
done
