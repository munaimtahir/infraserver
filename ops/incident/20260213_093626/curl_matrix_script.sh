#!/bin/bash
OUT=$1
echo "Domain,Type,URL,Status,Server,Time" > "$OUT/curl_matrix.csv"

test_curl() {
    local domain=$1
    local type=$2
    local url=$3
    local host_header=$4
    
    echo "Testing $domain ($type) via $url with Host: $host_header"
    res=$(curl -k -sS -D- "$url" -H "Host: $host_header" -o /dev/null -w "%{http_code},%{time_total}")
    code=$(echo $res | cut -d',' -f1)
    time=$(echo $res | cut -d',' -f2)
    server=$(curl -k -sS -I "$url" -H "Host: $host_header" 2>/dev/null | grep -i "^Server:" | cut -d' ' -f2- | tr -d '\r')
    
    echo "$domain,$type,$url,$code,\"$server\",$time" >> "$OUT/curl_matrix.csv"
}

# Domains to test
DOMAINS=(
    "portal.alshifalab.pk:8013"
    "lims.alshifalab.pk:8012"
    "api.lims.alshifalab.pk:8012"
    "rims.alshifalab.pk:8081"
    "api.rims.alshifalab.pk:8015"
    "phc.alshifalab.pk:8016"
    "api.phc.alshifalab.pk:8016"
    "dashboard.alshifalab.pk:8013"
    "ops.alshifalab.pk:18001"
    "grafana.alshifalab.pk:13000"
)

# Test via localhost HTTPS
for entry in "${DOMAINS[@]}"; do
    domain=${entry%%:*}
    port=${entry##*:}
    test_curl "$domain" "HTTPS-Local" "https://127.0.0.1/" "$domain"
    test_curl "$domain" "Upstream" "http://127.0.0.1:$port/" "$domain"
done

# Special paths
test_curl "portal.alshifalab.pk" "API" "https://127.0.0.1/api/apps" "portal.alshifalab.pk"
test_curl "ops.alshifalab.pk" "API" "https://127.0.0.1/api/" "ops.alshifalab.pk"
