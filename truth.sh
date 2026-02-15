# TRUTH AUDIT PROMPT (READ-ONLY) — run from: /home/munaim/srv
# Produces a single ground-truth report + raw artifacts for: Docker, Caddy, domains, ports, health/API/auth/CORS probes.
# No config changes. No restarts. Safe to run on prod.

set -euo pipefail

ROOT="/home/munaim/srv"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$ROOT/ops/truth_audit/$TS"
mkdir -p "$OUT"/{raw,probes,compose}

LOG="$OUT/raw/run.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== TRUTH AUDIT START $(date -Is) ==="
echo "OUT=$OUT"
echo

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing required command: $1"; exit 1; }; }
need docker
need curl
need ss
need awk
need sed
need grep
need sha256sum

# Optional tools (nice-to-have)
# yq / jq may not be installed. We'll degrade gracefully.
HAS_JQ=0; command -v jq >/dev/null 2>&1 && HAS_JQ=1
HAS_YQ=0; command -v yq >/dev/null 2>&1 && HAS_YQ=1

echo "== 0) Host + OS + Disk + Memory =="
{
  echo "### Host & OS"
  hostnamectl 2>/dev/null || true
  echo
  echo "### Uptime"
  uptime || true
  echo
  echo "### Time"
  date -Is
  echo
  echo "### Disk"
  df -hT || true
  echo
  echo "### Memory"
  free -h || true
  echo
  echo "### Top processes (brief)"
  ps aux --sort=-%mem | head -n 20 || true
} | tee "$OUT/raw/host.txt" >/dev/null
echo

echo "== 1) Networking: listening ports + UFW =="
{
  echo "### Listening TCP"
  ss -ltnp || true
  echo
  echo "### Listening UDP"
  ss -lunp || true
  echo
  echo "### UFW"
  sudo ufw status verbose 2>/dev/null || true
} | tee "$OUT/raw/network.txt" >/dev/null
echo

echo "== 2) Caddy: service status + config snapshot =="
CADDY_SRV_CADDYFILE="$ROOT/proxy/caddy/Caddyfile"
CADDY_ETC_CADDYFILE="/etc/caddy/Caddyfile"

{
  echo "### Caddy service status"
  sudo systemctl status caddy --no-pager 2>/dev/null || true
  echo
  echo "### Caddy recent logs (last 200 lines)"
  sudo journalctl -u caddy --no-pager -n 200 2>/dev/null || true
} | tee "$OUT/raw/caddy_status_and_logs.txt" >/dev/null

if [ -f "$CADDY_SRV_CADDYFILE" ]; then
  cp -a "$CADDY_SRV_CADDYFILE" "$OUT/raw/Caddyfile.srv"
  sha256sum "$CADDY_SRV_CADDYFILE" | tee "$OUT/raw/Caddyfile.srv.sha256" >/dev/null
else
  echo "WARN: Missing $CADDY_SRV_CADDYFILE"
fi

if [ -f "$CADDY_ETC_CADDYFILE" ]; then
  cp -a "$CADDY_ETC_CADDYFILE" "$OUT/raw/Caddyfile.etc"
  sha256sum "$CADDY_ETC_CADDYFILE" | tee "$OUT/raw/Caddyfile.etc.sha256" >/dev/null
else
  echo "WARN: Missing $CADDY_ETC_CADDYFILE"
fi

if [ -f "$CADDY_SRV_CADDYFILE" ] && [ -f "$CADDY_ETC_CADDYFILE" ]; then
  (diff -u "$CADDY_SRV_CADDYFILE" "$CADDY_ETC_CADDYFILE" || true) | tee "$OUT/raw/Caddyfile.diff" >/dev/null
fi
echo

echo "== 3) Docker: inventory (containers, images, volumes, networks) =="
{
  echo "### docker version"
  docker version || true
  echo
  echo "### docker info (trimmed)"
  docker info 2>/dev/null | sed -n '1,140p' || true
  echo
  echo "### containers (ps -a)"
  docker ps -a --no-trunc || true
  echo
  echo "### containers (formatted)"
  docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}' || true
  echo
  echo "### images"
  docker images --digests || true
  echo
  echo "### volumes"
  docker volume ls || true
  echo
  echo "### networks"
  docker network ls || true
} | tee "$OUT/raw/docker_inventory.txt" >/dev/null

# Per-container inspection (light)
echo "== 3b) Docker: per-container inspect (selected fields) =="
docker ps -a --format '{{.ID}} {{.Names}}' | while read -r CID CNAME; do
  INS="$OUT/raw/inspect.${CNAME}.json"
  docker inspect "$CID" > "$INS" || true
done
echo

echo "== 4) Compose discovery under /home/munaim/srv =="
# Find compose files and snapshot them
find "$ROOT" -maxdepth 5 -type f \( -iname "docker-compose*.yml" -o -iname "compose*.yml" \) \
  -print | sort > "$OUT/raw/compose_files.list" || true

while read -r CF; do
  [ -f "$CF" ] || continue
  # store a copy preserving relative path
  REL="${CF#${ROOT}/}"
  DEST="$OUT/compose/$REL"
  mkdir -p "$(dirname "$DEST")"
  cp -a "$CF" "$DEST"
done < "$OUT/raw/compose_files.list"

echo "Compose files captured: $(wc -l < "$OUT/raw/compose_files.list" 2>/dev/null || echo 0)"
echo

echo "== 5) Domain -> upstream extraction from Caddyfile (best-effort) =="
DOMAINS_TXT="$OUT/raw/domains_from_caddy.txt"
UPSTREAMS_TXT="$OUT/raw/upstreams_from_caddy.txt"

if [ -f "$CADDY_SRV_CADDYFILE" ]; then
  # Extract site labels (very best-effort): lines with something like "example.com {" or "a.com, b.com {"
  awk '
    BEGIN{FS="{"}
    /^[[:space:]]*($|#)/{next}
    $0 ~ /\{/ {
      left=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", left)
      # exclude common snippets blocks like (something) { or @matcher { or route { etc.
      if (left ~ /^\(/) next
      if (left ~ /^@/) next
      if (left ~ /^(handle|route|log|tls|encode|header|redir|respond|reverse_proxy|import|php_fastcgi|file_server)[[:space:]]*$/) next
      # split by comma/space
      n=split(left, parts, /[, ]+/)
      for(i=1;i<=n;i++){
        p=parts[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", p)
        if(p=="" ) continue
        if(p ~ /:\/\//) continue
        if(p ~ /\./ || p ~ /localhost/){
          print p
        }
      }
    }
  ' "$CADDY_SRV_CADDYFILE" | sort -u > "$DOMAINS_TXT"

  # Extract upstream targets from reverse_proxy directives
  grep -RIn --no-messages 'reverse_proxy' "$CADDY_SRV_CADDYFILE" \
    | sed -E 's/.*reverse_proxy[[:space:]]+([^[:space:]{]+).*/\1/' \
    | sort -u > "$UPSTREAMS_TXT" || true
else
  echo "WARN: cannot parse domains; missing $CADDY_SRV_CADDYFILE"
  : > "$DOMAINS_TXT"
  : > "$UPSTREAMS_TXT"
fi

echo "Domains found: $(wc -l < "$DOMAINS_TXT" 2>/dev/null || echo 0)"
echo "Upstreams found: $(wc -l < "$UPSTREAMS_TXT" 2>/dev/null || echo 0)"
echo

echo "== 6) Probes: domain health checks (HTTPS) =="
# Probe known key domains even if parser misses them
KNOWN_DOMAINS=(
  "portal.alshifalab.pk"
  "lims.alshifalab.pk"
  "rims.alshifalab.pk"
  "ops.alshifalab.pk"
  "mediq.alshifalab.pk"
)

# Combine parsed + known
ALL_DOMAINS="$OUT/raw/all_domains.txt"
( cat "$DOMAINS_TXT" 2>/dev/null; printf "%s\n" "${KNOWN_DOMAINS[@]}" ) \
  | sed '/^$/d' | sort -u > "$ALL_DOMAINS"

probe_url () {
  local url="$1"
  local name="$2"
  local out="$3"
  echo "## $name" >> "$out"
  echo "$url" >> "$out"
  # HEAD (fast) then GET (captures JSON/html snippet)
  curl -k -sS -D - -o /dev/null -I --max-time 10 "$url" 2>&1 | sed 's/\r$//' >> "$out" || true
  echo >> "$out"
  curl -k -sS -D - --max-time 15 "$url" 2>&1 | head -n 60 | sed 's/\r$//' >> "$out" || true
  echo -e "\n----\n" >> "$out"
}

DOM_REPORT="$OUT/probes/domain_probes.txt"
: > "$DOM_REPORT"

# Paths to test (covers common patterns that caused your “requested path” failures)
PATHS=(
  "/"
  "/health"
  "/healthz"
  "/api"
  "/api/"
  "/api/v1"
  "/api/v1/"
  "/api/auth"
  "/api/auth/"
  "/auth"
  "/auth/"
  "/admin"
  "/admin/"
  "/api/schema"
  "/api/docs"
)

while read -r D; do
  # skip non-domain labels like ":443" etc.
  if [[ "$D" =~ ^: ]]; then continue; fi
  if [[ "$D" =~ ^\* ]]; then continue; fi

  echo "Probing domain: $D"
  for P in "${PATHS[@]}"; do
    probe_url "https://${D}${P}" "${D}${P}" "$DOM_REPORT"
  done

  # CORS preflight probe for a likely API endpoint
  CORS_OUT="$OUT/probes/cors_${D}.txt"
  : > "$CORS_OUT"
  curl -k -sS -D - -o /dev/null -X OPTIONS --max-time 10 \
    -H "Origin: https://${D}" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: authorization,content-type" \
    "https://${D}/api/" 2>&1 | sed 's/\r$//' >> "$CORS_OUT" || true
done < "$ALL_DOMAINS"

echo

echo "== 7) Probes: localhost upstream checks (best-effort) =="
# Parse upstream ports like 127.0.0.1:8012, localhost:8013, :8015, etc.
UPSTREAM_REPORT="$OUT/probes/localhost_upstreams.txt"
: > "$UPSTREAM_REPORT"

extract_port () {
  local u="$1"
  # supports host:port or :port
  echo "$u" | sed -nE 's/.*:([0-9]{2,5}).*/\1/p' | head -n1
}

if [ -s "$UPSTREAMS_TXT" ]; then
  while read -r U; do
    P="$(extract_port "$U" || true)"
    if [ -z "${P:-}" ]; then continue; fi
    # Probe http on localhost
    for path in "/" "/health" "/healthz" "/api/" "/api/v1/"; do
      echo "## http://127.0.0.1:${P}${path}" >> "$UPSTREAM_REPORT"
      curl -sS -D - -o /dev/null --max-time 6 "http://127.0.0.1:${P}${path}" 2>&1 | sed 's/\r$//' >> "$UPSTREAM_REPORT" || true
      echo >> "$UPSTREAM_REPORT"
    done
    echo -e "----\n" >> "$UPSTREAM_REPORT"
  done < "$UPSTREAMS_TXT"
fi
echo

echo "== 8) Generate human-friendly Truth Report (Markdown) =="
REPORT="$OUT/SRV_TRUTH_REPORT.md"

# Helper for markdown code blocks
mblock () { local title="$1"; local file="$2"; echo -e "\n### ${title}\n\n\`\`\`\n$(sed -n '1,220p' "$file" 2>/dev/null || true)\n\`\`\`\n"; }

{
  echo "# SRV Truth Report"
  echo
  echo "- Generated: $(date -Is)"
  echo "- Root: $ROOT"
  echo "- Artifacts: $OUT"
  echo
  echo "## Canonical paths (as detected)"
  echo
  echo "- Caddy (srv): \`$CADDY_SRV_CADDYFILE\`  $( [ -f "$CADDY_SRV_CADDYFILE" ] && echo "✅" || echo "❌" )"
  echo "- Caddy (etc): \`$CADDY_ETC_CADDYFILE\`  $( [ -f "$CADDY_ETC_CADDYFILE" ] && echo "✅" || echo "❌" )"
  echo
  echo "## Executive truth summary"
  echo
  echo "- This report is **read-only** inventory + probes."
  echo "- Any FAIL in probes usually indicates **path mismatch, auth mismatch, CORS mismatch, upstream down, or DNS/TLS issue**."
  echo
  echo "## Domains discovered"
  echo
  echo "Parsed from Caddyfile + known:"
  echo
  echo '```'
  sed -n '1,250p' "$ALL_DOMAINS" 2>/dev/null || true
  echo '```'
  echo
  echo "## Upstreams discovered"
  echo
  echo '```'
  sed -n '1,250p' "$UPSTREAMS_TXT" 2>/dev/null || true
  echo '```'
  echo
  echo "## Docker inventory (top)"
  mblock "docker inventory snapshot" "$OUT/raw/docker_inventory.txt"
  echo
  echo "## Caddy service + recent logs (top)"
  mblock "caddy status + logs" "$OUT/raw/caddy_status_and_logs.txt"
  echo
  echo "## Caddyfile diff (srv vs /etc) (top)"
  mblock "Caddyfile diff" "$OUT/raw/Caddyfile.diff"
  echo
  echo "## Domain probes (top)"
  mblock "domain probes (headers + short bodies)" "$OUT/probes/domain_probes.txt"
  echo
  echo "## Localhost upstream probes (top)"
  mblock "localhost upstream probes" "$OUT/probes/localhost_upstreams.txt"
  echo
  echo "## Networking snapshot (top)"
  mblock "listening ports + ufw" "$OUT/raw/network.txt"
  echo
  echo "## Compose files discovered"
  echo
  echo '```'
  sed -n '1,400p' "$OUT/raw/compose_files.list" 2>/dev/null || true
  echo '```'
  echo
  echo "## Where to look next (actionable triage list)"
  echo
  echo "1) If **domain probes show 200 for /** but API paths 404 → fix frontend API base + standardize API prefix."
  echo "2) If **domain probes show 502/504** → upstream not reachable; check container binding + port map."
  echo "3) If **CORS preflight missing Access-Control-Allow-Origin** → fix Caddy headers or app CORS allowlist."
  echo "4) If **Caddyfile diff is non-empty** → /etc/caddy may not match srv truth; sync drift exists."
  echo "5) If **localhost probes pass but domain probes fail** → Caddy routing rule mismatch."
  echo
} > "$REPORT"

echo "=== TRUTH AUDIT COMPLETE ==="
echo "Report: $REPORT"
echo "Artifacts: $OUT"
echo
echo "Quick view:"
sed -n '1,80p' "$REPORT" || true
