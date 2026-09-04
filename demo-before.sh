#!/usr/bin/env bash
# Shows the ORIGINAL buggy code straight from the first commit.
# Safe to run on camera — read-only, touches nothing.

BASE=d1835ec5d
RED='\033[1;31m'; BLUE='\033[1;36m'; RESET='\033[0m'
hr() { printf "${BLUE}%s${RESET}\n" "------------------------------------------------------------"; }
section() { echo; hr; printf "${BLUE}  %s${RESET}\n" "$1"; hr; }

section "BUG 1 — cache key had no tenant (services/cache.py)"
git show $BASE:backend/app/services/cache.py | sed -n '9,18p'
printf "${RED}  ^ key is 'revenue:<property_id>' — tenant_id is passed in, then ignored.${RESET}\n"

section "BUG 2 — naive datetimes, property timezone never read (services/reservations.py)"
git show $BASE:backend/app/services/reservations.py | sed -n '5,16p'
printf "${RED}  ^ datetime(year, month, 1) has no tzinfo; properties.timezone is never used.${RESET}\n"

section "BUG 3 — Decimal cast to float (api/v1/dashboard.py)"
git show $BASE:backend/app/api/v1/dashboard.py | sed -n '16,25p'
printf "${RED}  ^ float() cannot round-trip NUMERIC(10,3) sub-cent values.${RESET}\n"

section "BUG 4 — pool built from settings that do not exist (core/database_pool.py)"
git show $BASE:backend/app/core/database_pool.py | sed -n '16,22p'
printf "${RED}  ^ settings.supabase_db_* does not exist on Settings -> pool ALWAYS failed.${RESET}\n"

section "BUG 4 — and the failure was swallowed, returning fake money"
git show $BASE:backend/app/services/reservations.py | sed -n '88,101p'
printf "${RED}  ^ every DB error returned hardcoded mock revenue that looked real.${RESET}\n"
echo
