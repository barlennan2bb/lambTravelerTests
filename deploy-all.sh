#!/usr/bin/env bash
# deploy-all.sh — Deploy all four Traveler Lambda stacks via the AWS Patterns tool.
# Usage: ./deploy-all.sh [--verify-only]
#
# On success, runs verify.sh to confirm all endpoints respond.
# Exit code 0 = full pass. Non-zero = deploy or verification failed.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

VERIFY_ONLY=false
[[ "${1:-}" == "--verify-only" ]] && VERIFY_ONLY=true

# ── Helpers ───────────────────────────────────────────────────────────────────

log()  { echo "[deploy-all] $*"; }
fail() { echo "[deploy-all] FAIL: $*" >&2; exit 1; }

poll_deploy() {
  local request_id=$1 stack=$2
  local timeout=1800 interval=10 elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    local status
    status=$(curl -s "$DQ_BASE_URL/api/deploy/status?request_id=$request_id" \
      | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))")
    case "$status" in
      SUCCEEDED) log "$stack: SUCCEEDED"; return 0 ;;
      FAILED|TIMED_OUT|ERROR) fail "$stack deploy reached $status" ;;
    esac
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  fail "$stack: polling timed out after ${timeout}s"
}

deploy_stack() {
  local repo=$1 stack=$2 route=$3
  log "Deploying $repo → stack=$stack  route=$route"

  local payload
  payload=$(python3 - << PYEOF
import json
print(json.dumps({
    "stack_name":   "$stack",
    "profile":      "$PROFILE",
    "region":       "$REGION",
    "access_token": "$GH_TOKEN",
    "parameters": {
        "Env":              "$ENV",
        "Repository":       "https://github.com/$GH_ORG/$repo",
        "Branch":           "main",
        "SamSubdir":        ".",
        "ApiId":            "$API_ID",
        "AuthorizerId":     "$AUTHORIZER_ID",
        "ArtifactsBucket":  "$ARTIFACTS_BUCKET",
        "AccessToken":      "$GH_TOKEN",
    }
}))
PYEOF
)

  local resp
  resp=$(curl -s -X POST "$DQ_BASE_URL/api/patterns/sam-api-from-github/prepare-deploy" \
    -H "Content-Type: application/json" \
    -d "$payload")

  local ok request_id error
  ok=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok',''))")
  request_id=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('request_id',''))")
  error=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',''))")

  [ "$ok" = "True" ] || fail "prepare-deploy rejected for $stack: $error"
  poll_deploy "$request_id" "$stack"
}

# ── Main ──────────────────────────────────────────────────────────────────────

if ! $VERIFY_ONLY; then
  GH_TOKEN=$(gh auth token --hostname github.com)
  PASS=0; FAIL_COUNT=0

  for entry in "${DEPLOYMENTS[@]}"; do
    IFS=: read -r repo stack route <<< "$entry"
    if deploy_stack "$repo" "$stack" "$route"; then
      PASS=$((PASS + 1))
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  done

  log "Deploy phase: $PASS succeeded, $FAIL_COUNT failed"
  [ "$FAIL_COUNT" -eq 0 ] || fail "$FAIL_COUNT stack(s) failed to deploy"
fi

log "Running endpoint verification..."
exec "$SCRIPT_DIR/verify.sh"
