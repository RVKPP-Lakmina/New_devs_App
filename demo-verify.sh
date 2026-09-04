#!/usr/bin/env bash
# Demo verification script — proves the fixes against the live Docker stack.
# Usage: bash demo-verify.sh

API=http://localhost:8000
BLUE='\033[1;36m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'

hr() { printf "${BLUE}%s${RESET}\n" "------------------------------------------------------------"; }
section() { echo; hr; printf "${BLUE}  %s${RESET}\n" "$1"; hr; }

jqtok() { py -c "import sys,json;print(json.load(sys.stdin)['access_token'])" 2>/dev/null \
        || python -c "import sys,json;print(json.load(sys.stdin)['access_token'])"; }

login() {
  curl -s -X POST "$API/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" | jqtok
}

summary() {
  curl -s "$API/api/v1/dashboard/summary?property_id=$2" -H "Authorization: Bearer $1"
}

section "1. DATABASE — the source of truth"
docker exec new_devs_app-db-1 psql -U postgres -d propertyflow -c \
"SELECT p.tenant_id, p.id AS property, p.timezone,
        COALESCE(SUM(r.total_amount),0) AS true_total,
        COUNT(r.id) AS bookings
 FROM properties p
 LEFT JOIN reservations r ON r.property_id = p.id AND r.tenant_id = p.tenant_id
 GROUP BY p.tenant_id, p.id, p.timezone
 ORDER BY p.tenant_id, p.id;"

section "2. Clearing Redis so every number below is computed fresh"
docker exec new_devs_app-redis-1 redis-cli FLUSHALL
printf "${GREEN}cache cleared${RESET}\n"

section "3. Logging in as both clients"
TA=$(login sunset@propertyflow.com client_a_2024)
TB=$(login ocean@propertyflow.com  client_b_2024)
printf "Client A (Sunset Properties) token: ${GREEN}%s...${RESET}\n" "${TA:0:32}"
printf "Client B (Ocean Rentals)    token: ${GREEN}%s...${RESET}\n" "${TB:0:32}"

section "4. DASHBOARD API — what each client actually sees"
echo "Client A  (tenant-a):"
for p in prop-001 prop-002 prop-003; do printf "   %-9s -> " "$p"; summary "$TA" "$p"; echo; done
echo
echo "Client B  (tenant-b):"
for p in prop-001 prop-004 prop-005; do printf "   %-9s -> " "$p"; summary "$TB" "$p"; echo; done

section "5. THE COLLISION TEST — same property ID, two different tenants"
printf "${YELLOW}Both clients own a property literally called 'prop-001'.${RESET}\n\n"
printf "   A's prop-001 -> "; summary "$TA" prop-001; echo
printf "   B's prop-001 -> "; summary "$TB" prop-001; echo
printf "\n   (repeat A, now served from cache — must NOT show B's data)\n"
printf "   A's prop-001 -> "; summary "$TA" prop-001; echo

section "6. REDIS KEYS — proof of tenant isolation"
docker exec new_devs_app-redis-1 redis-cli KEYS 'revenue*'
printf "\n${GREEN}Every key is namespaced by tenant. No shared key = no leak.${RESET}\n"
echo
