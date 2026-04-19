#!/usr/bin/env bash
# config.sh — Shared configuration for the Traveler Lambda regression suite.
# Source this file from deploy-all.sh and verify.sh.

DQ_BASE_URL="http://localhost:8787"
PROFILE="cyberpojos"
REGION="us-east-1"
ENV="DEV"
API_ID="9x3d8lfsi8"
AUTHORIZER_ID="q9uyr1"
ARTIFACTS_BUCKET="pojos-sam-artifacts-360660537144-dev"
GH_ORG="barlennan2bb"

# Base URL of the shared POJOS HTTP API Gateway (HTTP API v2 uses no stage prefix)
API_BASE_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com"

# Each entry: "RepoName:StackName:Route"
DEPLOYMENTS=(
  "lambTraveler:lamb-traveler:/traveler"
  "lambTravelerProfile:lamb-traveler-profile:/traveler/profile"
  "lambTravelerPolicy:lamb-traveler-policy:/traveler/policy"
  "lambTravelerHistory:lamb-traveler-history:/traveler/history"
)
