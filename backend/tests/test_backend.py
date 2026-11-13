"""End-to-end tests for the CleanBot backend API.

The tests force the deterministic simulator so they run without ROS 2 or a
serial port. Run from the repository root:

    backend/.venv/bin/python -m pytest backend/tests -q
"""

from __future__ import annotations

import os
import time

os.environ.setdefault("CLEANBOT_FORCE_SIMULATION", "true")
os.environ.setdefault("CLEANBOT_ENABLE_SIM_ROBOT", "true")
os.environ.setdefault("CLEANBOT_JWT_SECRET", "test-secret-not-for-production-0123456789")

import pytest
from fastapi.testclient import TestClient

from app.main import app

OPERATOR = {"username": "operator@cleanbot.io", "password": "CleanBot#2026"}


@pytest.fixture(scope="module")
def client() -> TestClient:
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(scope="module")
def token(client: TestClient) -> str:
    response = client.post("/api/v1/auth/login", json=OPERATOR)
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


@pytest.fixture(scope="module")
def headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_health_is_public(client: TestClient) -> None:
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["robot_id"] == "robot-alpha-01"


def test_login_rejects_bad_password(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"username": OPERATOR["username"], "password": "wrong"},
    )
    assert response.status_code == 401


def test_dashboard_requires_auth(client: TestClient) -> None:
    assert client.get("/api/v1/dashboard/summary").status_code == 401


def test_dashboard_payload_matches_flutter_models(
    client: TestClient, headers: dict[str, str]
) -> None:
    response = client.get("/api/v1/dashboard/summary", headers=headers)
    assert response.status_code == 200
    body = response.json()
    for key in (
        "robot_id",
        "active_job",
        "waste_fill_percentage",
        "latest_cleanliness",
        "active_alert_count",
        "last_data_received_at",
    ):
        assert key in body


def test_telemetry_and_map(client: TestClient, headers: dict[str, str]) -> None:
    telemetry = client.get("/api/v1/robots/robot-alpha-01/telemetry", headers=headers)
    assert telemetry.status_code == 200
    assert {"battery", "pose", "odom", "scan", "status"} <= telemetry.json().keys()

    map_payload = client.get("/api/v1/robots/robot-alpha-01/map", headers=headers)
    assert map_payload.status_code == 200
    assert "robot_pose" in map_payload.json()


def test_command_lifecycle(client: TestClient, headers: dict[str, str]) -> None:
    response = client.post(
        "/api/v1/robots/robot-alpha-01/commands",
        headers=headers,
        json={
            "command": "startCleaning",
            "idempotency_key": "pytest-clean-1",
            "parameters": {"zone_id": "zone-lobby"},
        },
    )
    assert response.status_code in (200, 201, 202), response.text
    command = response.json()
    command_id = command["command_id"]
    assert command["command_type"] == "startCleaning"

    # The simulator advances pending -> dispatched -> accepted -> executing.
    state = command["state"]
    deadline = time.time() + 8.0
    while time.time() < deadline and state in {"pending", "dispatched", "accepted"}:
        time.sleep(0.4)
        polled = client.get(f"/api/v1/commands/{command_id}", headers=headers)
        assert polled.status_code == 200
        state = polled.json()["state"]

    assert state in {"executing", "completed"}

    # Idempotency: the same key returns the same command.
    again = client.post(
        "/api/v1/robots/robot-alpha-01/commands",
        headers=headers,
        json={
            "command": "startCleaning",
            "idempotency_key": "pytest-clean-1",
            "parameters": {"zone_id": "zone-lobby"},
        },
    )
    assert again.json()["command_id"] == command_id


def test_zone_start(client: TestClient, headers: dict[str, str]) -> None:
    response = client.post(
        "/api/v1/robots/robot-alpha-01/zones/zone-cafeteria/start",
        headers=headers,
        json={"idempotency_key": "pytest-zone-1"},
    )
    assert response.status_code in (200, 201, 202), response.text


def test_websocket_streams_telemetry(client: TestClient, token: str) -> None:
    with client.websocket_connect(f"/api/v1/ws?token={token}") as websocket:
        types = {websocket.receive_json()["type"] for _ in range(4)}
    assert types & {"robot_state", "telemetry"}


def test_websocket_rejects_missing_token(client: TestClient) -> None:
    with pytest.raises(Exception):
        with client.websocket_connect("/api/v1/ws") as websocket:
            websocket.receive_json()
