# lambTravelerTests

Regression test harness for the four Traveler Lambda microservices deployed via the AWS Patterns tool. Tests both the deploy pipeline and the live API endpoints on the shared POJOS API Gateway.

## Architecture

All four Lambdas attach to a single shared HTTP API Gateway (`POJOS-GW-DEV`). Each is deployed as an independent CloudFormation stack via the **SAM API from GitHub** pattern. Routes are JWT-protected via the shared Cognito authorizer.

```
POJOS-GW-DEV (9x3d8lfsi8)
├── GET /traveler         → lamb-trav         (barlennan2bb/lambTraveler)
├── GET /traveler/profile → lamb-trav-prof    (barlennan2bb/lambTravelerProfile)
├── GET /traveler/policy  → lamb-trav-pol     (barlennan2bb/lambTravelerPolicy)
└── GET /traveler/history → lamd-trav-hist2   (barlennan2bb/lambTravelerHistory)
```

## Infrastructure

| Resource | Value |
|---|---|
| Shared API Gateway ID | `9x3d8lfsi8` |
| API Base URL | `https://9x3d8lfsi8.execute-api.us-east-1.amazonaws.com` |
| JWT Authorizer ID | `q9uyr1` |
| Cognito User Pool | `us-east-1_ARGjZ5yHx` |
| Cognito App Client | `1nutoktgo69f1gr7muf24r0jl1` (POJOS-DEV-spa) |
| AWS Profile | `cyberpojos` / `us-east-1` |
| Artifacts Bucket | `pojos-sam-artifacts-360660537144-dev` |

## Test service account

A dedicated service account exists in the Cognito pool for regression testing:

```
Username : svc-test@example.com
Pool     : us-east-1_ARGjZ5yHx
```

This represents the M2M pattern — any AWS app or 3rd-party service that holds valid Cognito credentials passes its IdToken as `Authorization: Bearer <token>`.

### Get a fresh token (expires in 1 hour)

```bash
TOKEN=$(python3 -c "
import boto3
idp = boto3.Session(profile_name='cyberpojos', region_name='us-east-1').client('cognito-idp')
r = idp.admin_initiate_auth(
    UserPoolId='us-east-1_ARGjZ5yHx', ClientId='1nutoktgo69f1gr7muf24r0jl1',
    AuthFlow='ADMIN_USER_PASSWORD_AUTH',
    AuthParameters={'USERNAME':'svc-test@example.com','PASSWORD':'SvcTestService1'})
print(r['AuthenticationResult']['IdToken'], end='')
")
```

## Scripts

| Script | Purpose |
|---|---|
| `config.sh` | Shared variables (API IDs, profile, bucket, stacks) |
| `deploy-all.sh` | Deploy all 4 stacks then verify endpoints |
| `verify.sh` | curl all 4 endpoints — checks HTTP 200 + JSON payload |
| `test-auth.sh` | Full auth test: JWT config + 401 unauth + 200 with token |
| `tests/test_endpoints.py` | pytest equivalent of verify.sh |

## Running the regression suite

### Full deploy + verify (redeploy everything from GitHub)

```bash
cd ~/devl2/lambTravelerTests
./deploy-all.sh
```

### Verify endpoints only (no redeploy)

```bash
# Get a fresh token first (see "Get a fresh token" above), then:
TOKEN=$TOKEN ./deploy-all.sh --verify-only
# or
TOKEN=$TOKEN ./verify.sh
```

### Auth protection test

```bash
# Gate-only: confirms AuthorizationType=JWT and HTTP 401 without token
./test-auth.sh

# Full suite: also confirms HTTP 200 with valid token (12/12)
TOKEN=$TOKEN ./test-auth.sh
```

### pytest

```bash
pip install pytest
pytest tests/test_endpoints.py -v
```

## Expected results (all passing)

```
GET /traveler         AuthorizationType=JWT ✓  HTTP 401 unauth ✓  HTTP 200 authed ✓
GET /traveler/profile AuthorizationType=JWT ✓  HTTP 401 unauth ✓  HTTP 200 authed ✓
GET /traveler/policy  AuthorizationType=JWT ✓  HTTP 401 unauth ✓  HTTP 200 authed ✓
GET /traveler/history AuthorizationType=JWT ✓  HTTP 401 unauth ✓  HTTP 200 authed ✓

test-auth.sh with valid token: 12 passed, 0 failed, 0 skipped
```
