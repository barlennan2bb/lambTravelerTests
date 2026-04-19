# lambTravelerTests

Regression test harness for the four Traveler Lambda microservices deployed via the AWS Patterns tool.

## Repos under test

| Repo | Stack | Route |
|---|---|---|
| `lambTraveler` | `lamb-traveler` | `GET /traveler` |
| `lambTravelerProfile` | `lamb-traveler-profile` | `GET /traveler/profile` |
| `lambTravelerPolicy` | `lamb-traveler-policy` | `GET /traveler/policy` |
| `lambTravelerHistory` | `lamb-traveler-history` | `GET /traveler/history` |

All four routes live on the single shared POJOS API Gateway (`9x3d8lfsi8`).

## Files

- `config.sh` — shared variables (API ID, profile, bucket, etc.)
- `deploy-all.sh` — deploy all four stacks, then run verify
- `verify.sh` — curl all four endpoints and assert HTTP 200 + correct JSON
- `tests/test_endpoints.py` — pytest suite (16 parametrized assertions)

## Run the full regression

```bash
./deploy-all.sh
```

## Verify without re-deploying

```bash
./deploy-all.sh --verify-only
# or
./verify.sh
# or
pytest tests/test_endpoints.py -v
```

## Override the API base URL

```bash
API_BASE_URL=https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com pytest tests/test_endpoints.py -v
```
