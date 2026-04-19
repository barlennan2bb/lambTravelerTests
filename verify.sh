#!/usr/bin/env bash
# verify.sh — Verify all four Traveler endpoints on the shared POJOS API Gateway.
# Usage: ./verify.sh
# Exit code 0 = all pass. Non-zero = one or more failures.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

PASS=0
FAIL=0

check_endpoint() {
  local route=$1 expected_service=$2
  local url="${API_BASE_URL}${route}"
  local http_code body

  http_code=$(curl -s -o /tmp/_verify_body.json -w "%{http_code}" "$url")
  body=$(cat /tmp/_verify_body.json)

  local status service
  status=$(echo "$body" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('status',''))" 2>/dev/null || echo "")
  service=$(echo "$body" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('service',''))" 2>/dev/null || echo "")

  if [ "$http_code" = "200" ] && [ "$status" = "ok" ] && [ "$service" = "$expected_service" ]; then
    echo "  PASS  $route  →  HTTP $http_code  service=$service  status=$status"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $route  →  HTTP $http_code  service=$service  status=$status"
    echo "        body: $body"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== Traveler Endpoint Verification ==="
echo "    API base: $API_BASE_URL"
echo ""

check_endpoint "/traveler"         "traveler"
check_endpoint "/traveler/profile" "traveler-profile"
check_endpoint "/traveler/policy"  "traveler-policy"
check_endpoint "/traveler/history" "traveler-history"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo ""

[ "$FAIL" -eq 0 ] || exit 1
