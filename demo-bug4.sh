#!/usr/bin/env bash
# Beat 3 — proves the dashboard was serving a hardcoded number, not the database.
# Read-only. Safe on camera.

BASE=d1835ec5d
RED='\033[1;31m'; GREEN='\033[1;32m'; BLUE='\033[1;36m'; RESET='\033[0m'
hr() { printf "${BLUE}%s${RESET}\n" "------------------------------------------------------------"; }
section() { echo; hr; printf "${BLUE}  %s${RESET}\n" "$1"; hr; }

section "A. What the DATABASE actually holds for prop-001"
docker exec new_devs_app-db-1 psql -U postgres -d propertyflow -c \
"SELECT tenant_id, property_id, total_amount, check_in_date
 FROM reservations
 WHERE property_id='prop-001' AND tenant_id='tenant-a'
 ORDER BY check_in_date;"
docker exec new_devs_app-db-1 psql -U postgres -d propertyflow -c \
"SELECT SUM(total_amount) AS true_total, COUNT(*) AS bookings
 FROM reservations WHERE property_id='prop-001' AND tenant_id='tenant-a';"
printf "${GREEN}  Truth: 2250.000 across 4 bookings.${RESET}\n"

section "B. What the OLD code returned instead — a hardcoded literal"
git show $BASE:backend/app/services/reservations.py | sed -n '93,99p'
printf "${RED}  prop-001 was hardcoded to 1000.00 / 3 bookings. Never read the DB.${RESET}\n"

section "C. Why the DB was never reached"
git show $BASE:backend/app/core/database_pool.py | sed -n '17,18p'
printf "${RED}  settings.supabase_db_* does not exist -> pool init threw on every call.${RESET}\n"

section "D. The same endpoint today"
TA=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"sunset@propertyflow.com","password":"client_a_2024"}' \
  | py -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
printf "  "; curl -s "http://localhost:8000/api/v1/dashboard/summary?property_id=prop-001" \
  -H "Authorization: Bearer $TA"; echo
printf "${GREEN}  2250.000 / 4 — matches the database exactly.${RESET}\n"
echo
