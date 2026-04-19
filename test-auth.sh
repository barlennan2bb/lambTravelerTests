#!/usr/bin/env bash
# test-auth.sh — Verify all Traveler endpoints have JWT auth enforced.
#
# Checks (per route):
#   1. AuthorizationType=JWT confirmed via the API Gateway control plane
#   2. Unauthenticated request → HTTP 401 (no token supplied)
#   3. Authenticated request   → HTTP 200 with correct JSON payload (requires TOKEN)
#
# Usage:
#   ./test-auth.sh                       # checks 1+2 only
#   TOKEN=eyJhbGci... ./test-auth.sh     # checks 1+2+3

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

PASS=0; FAIL=0; SKIP=0
TOKEN="${TOKEN:-}"

# route_key : expected_service
ROUTES=(
  "GET /traveler:traveler"
  "GET /traveler/profile:traveler-profile"
  "GET /traveler/policy:traveler-policy"
  "GET /traveler/history:traveler-history"
)

pass() { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }
skip() { echo "  ○ $*"; SKIP=$((SKIP+1)); }

check_route() {
  local route_key=$1 expected_service=$2
  local path
  path=$(echo "$route_key" | awk '{print $2}')
  local url="${API_BASE_URL}${path}"

  printf "\n── %s ──\n" "$route_key"

  # ── 1. Control-plane: AuthorizationType must be JWT ─────────────────────
  local auth_type authorizer_id
  auth_type=$(AWS_PROFILE="$PROFILE" AWS_DEFAULT_REGION="$REGION" \
    aws apigatewayv2 get-routes --api-id "$API_ID" \
    --query "Items[?RouteKey=='${route_key}'].AuthorizationType" \
    --output text 2>/dev/null || echo "LOOKUP_FAILED")

  authorizer_id=$(AWS_PROFILE="$PROFILE" AWS_DEFAULT_REGION="$REGION" \
    aws apigatewayv2 get-routes --api-id "$API_ID" \
    --query "Items[?RouteKey=='${route_key}'].AuthorizerId" \
    --output text 2>/dev/null || echo "")

  if [ "$auth_type" = "JWT" ]; then
    pass "AuthorizationType=JWT  AuthorizerId=${authorizer_id:-?}"
  elif [ "$auth_type" = "NONE" ]; then
    fail "AuthorizationType=NONE — route is OPEN, redeploy with JWT auth"
  elif [ "$auth_type" = "LOOKUP_FAILED" ]; then
    fail "Could not query API Gateway — check AWS credentials/profile"
  else
    fail "AuthorizationType=${auth_type:-NOT_FOUND} — route may not be deployed yet"
  fi

  # ── 2. Data-plane: no token → must get 401 ──────────────────────────────
  local unauth_code
  unauth_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "ERR")
  if [ "$unauth_code" = "401" ]; then
    pass "Unauthenticated → HTTP 401 (access denied as expected)"
  elif [ "$unauth_code" = "403" ]; then
    pass "Unauthenticated → HTTP 403 (access denied as expected)"
  elif [ "$unauth_code" = "200" ]; then
    fail "Unauthenticated → HTTP 200 (route is OPEN — auth not enforced)"
  elif [ "$unauth_code" = "000" ] || [ "$unauth_code" = "ERR" ]; then
    fail "Unauthenticated → connection error / timeout"
  else
    fail "Unauthenticated → HTTP $unauth_code (unexpected)"
  fi

  # ── 3. Data-plane: valid token → must get 200 with correct payload ───────
  if [ -n "$TOKEN" ]; then
    local auth_code body svc status
    auth_code=$(curl -s -o /tmp/_tauth.json -w "%{http_code}" --max-time 10 \
      -H "Authorization: Bearer $TOKEN" "$url" 2>/dev/null || echo "ERR")
    body=$(cat /tmp/_tauth.json 2>/dev/null || echo "")
    svc=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('service',''))" 2>/dev/null || echo "")
    status=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")

    if [ "$auth_code" = "200" ] && [ "$svc" = "$expected_service" ] && [ "$status" = "ok" ]; then
      pass "Authenticated  → HTTP 200  service=$svc  status=$status"
    elif [ "$auth_code" = "200" ]; then
      fail "Authenticated  → HTTP 200 but payload wrong: $body"
    else
      fail "Authenticated  → HTTP $auth_code  $body"
    fi
  else
    skip "Authenticated check skipped (export TOKEN=<bearer-token> to enable)"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║     Traveler Lambda — Auth Protection Test Suite     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo "  API base : $API_BASE_URL"
echo "  API ID   : $API_ID"
echo "  Profile  : $PROFILE / $REGION"
[ -n "$TOKEN" ] && echo "  Token    : ${TOKEN:0:20}…  (authenticated checks ON)" \
                || echo "  Token    : not set   (authenticated checks OFF)"

for entry in "${ROUTES[@]}"; do
  IFS=: read -r route_key expected_service <<< "$entry"
  check_route "$route_key" "$expected_service"
done

echo ""
echo "══════════════════════════════════════════════════════"
printf   "  Results : %d passed  %d failed  %d skipped\n" "$PASS" "$FAIL" "$SKIP"
echo "══════════════════════════════════════════════════════"
echo ""

[ "$FAIL" -eq 0 ]
