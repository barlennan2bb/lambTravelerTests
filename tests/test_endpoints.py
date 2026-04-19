"""
test_endpoints.py — Regression tests for the four Traveler Lambda endpoints.

Run with:
    pytest tests/test_endpoints.py -v

Override the base URL:
    API_BASE_URL=https://... pytest tests/test_endpoints.py -v
"""

import json
import os

import pytest
import urllib.request
import urllib.error

API_BASE_URL = os.environ.get(
    "API_BASE_URL",
    "https://9x3d8lfsi8.execute-api.us-east-1.amazonaws.com",
).rstrip("/")

ENDPOINTS = [
    ("/traveler",         "traveler"),
    ("/traveler/profile", "traveler-profile"),
    ("/traveler/policy",  "traveler-policy"),
    ("/traveler/history", "traveler-history"),
]


def get(path: str):
    """Simple HTTP GET; returns (status_code, parsed_json_or_None)."""
    url = f"{API_BASE_URL}{path}"
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            body = json.loads(resp.read().decode())
            return resp.status, body
    except urllib.error.HTTPError as exc:
        try:
            body = json.loads(exc.read().decode())
        except Exception:
            body = {}
        return exc.code, body


@pytest.mark.parametrize("route,expected_service", ENDPOINTS)
def test_endpoint_responds_200(route, expected_service):
    status, _ = get(route)
    assert status == 200, f"Expected HTTP 200 on {route}, got {status}"


@pytest.mark.parametrize("route,expected_service", ENDPOINTS)
def test_endpoint_status_ok(route, expected_service):
    _, body = get(route)
    assert body.get("status") == "ok", (
        f"Expected status=ok on {route}, got: {body}"
    )


@pytest.mark.parametrize("route,expected_service", ENDPOINTS)
def test_endpoint_service_name(route, expected_service):
    _, body = get(route)
    assert body.get("service") == expected_service, (
        f"Expected service={expected_service!r} on {route}, got: {body}"
    )


@pytest.mark.parametrize("route,expected_service", ENDPOINTS)
def test_endpoint_path_echoed(route, expected_service):
    _, body = get(route)
    assert body.get("path") == route, (
        f"Expected path={route!r} in response body on {route}, got: {body}"
    )
