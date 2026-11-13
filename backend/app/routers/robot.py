from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

from ..schemas import CommandRequest, ManualDriveRequest, SettingsPatch, ZoneStartRequest
from ..security import AuthUser, get_current_user, require_controller
from ..state import RobotStore

router = APIRouter(tags=["robot"])


def _store(request: Request) -> RobotStore:
    return request.app.state.store


def _ensure_robot(store: RobotStore, robot_id: str | None) -> None:
    if store.get_robot(robot_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Robot '{robot_id}' not found.",
        )


@router.get("/robots")
def list_robots(
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> list[dict]:
    return _store(request).list_robots()


@router.get("/robots/{robot_id}")
def get_robot(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> dict:
    robot = _store(request).get_robot(robot_id)
    if robot is None:
        raise HTTPException(status_code=404, detail="Robot not found.")
    return robot


@router.get("/dashboard/summary")
def dashboard_summary(
    request: Request,
    robot_id: str | None = Query(default=None),
    _: AuthUser = Depends(get_current_user),
) -> dict:
    store = _store(request)
    try:
        return store.dashboard(robot_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Robot not found.") from exc


@router.get("/robots/{robot_id}/telemetry")
def telemetry(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> dict:
    store = _store(request)
    _ensure_robot(store, robot_id)
    return store.telemetry(robot_id)


@router.get("/robots/{robot_id}/map")
def map_payload(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> dict:
    store = _store(request)
    _ensure_robot(store, robot_id)
    return store.map_payload(robot_id)


@router.get("/zones")
def all_zones(
    request: Request,
    robot_id: str | None = Query(default=None),
    _: AuthUser = Depends(get_current_user),
) -> list[dict]:
    return _store(request).zones(robot_id)


@router.get("/robots/{robot_id}/zones")
def robot_zones(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> list[dict]:
    store = _store(request)
    _ensure_robot(store, robot_id)
    return store.zones(robot_id)


@router.get("/robots/{robot_id}/detections")
def detections(
    robot_id: str,
    request: Request,
    limit: int = Query(default=100, ge=1, le=500),
    _: AuthUser = Depends(get_current_user),
) -> list[dict]:
    store = _store(request)
    _ensure_robot(store, robot_id)
    return store.detections(robot_id, limit=limit)


@router.get("/robots/{robot_id}/history")
def history(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> list[dict]:
    store = _store(request)
    _ensure_robot(store, robot_id)
    return store.history(robot_id)


@router.get("/robots/{robot_id}/reports")
def reports(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> dict:
    store = _store(request)
    _ensure_robot(store, robot_id)
    return store.reports(robot_id)


@router.get("/robots/{robot_id}/waste")
def waste(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> dict:
    store = _store(request)
    _ensure_robot(store, robot_id)
    return store.waste(robot_id)


@router.get("/robots/{robot_id}/inspection")
def inspection(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> dict:
    store = _store(request)
    _ensure_robot(store, robot_id)
    latest = store.cleanliness(robot_id)
    return {
        "robot_id": robot_id,
        "latest": latest,
        "history": [latest] if latest else [],
    }


@router.get("/robots/{robot_id}/maintenance")
def maintenance(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> dict:
    store = _store(request)
    _ensure_robot(store, robot_id)
    return store.maintenance(robot_id)


@router.get("/robots/{robot_id}/notifications")
def notifications(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> list[dict]:
    store = _store(request)
    _ensure_robot(store, robot_id)
    return store.notifications(robot_id)


@router.post("/notifications/{notification_id}/read")
def read_notification(
    notification_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> dict:
    item = _store(request).mark_notification(notification_id, True)
    if item is None:
        raise HTTPException(status_code=404, detail="Notification not found.")
    return item


@router.post("/notifications/read-all")
def read_all_notifications(
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> dict:
    return {"updated": _store(request).mark_all_notifications()}


@router.post("/robots/{robot_id}/commands")
def create_command(
    robot_id: str,
    payload: CommandRequest,
    request: Request,
    user: AuthUser = Depends(require_controller),
) -> dict:
    store = _store(request)
    _ensure_robot(store, robot_id)
    try:
        command = store.create_command(
            robot_id,
            payload.command,
            payload.idempotency_key,
            payload.parameters,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    bridge = request.app.state.bridge
    if command["state"] == "pending":
        bridge.dispatch(command)

    return {
        "command_id": command["id"],
        "id": command["id"],
        "robot_id": command["robot_id"],
        "command_type": command["command_type"],
        "state": command["state"],
        "created_at": command["created_at"],
        "accepted_by": user.email,
    }


@router.post("/robots/{robot_id}/zones/{zone_id}/start")
def start_zone_cleaning(
    robot_id: str,
    zone_id: str,
    payload: ZoneStartRequest,
    request: Request,
    user: AuthUser = Depends(require_controller),
) -> dict:
    store = _store(request)
    _ensure_robot(store, robot_id)
    zone = next((z for z in store.zones(robot_id) if z["id"] == zone_id), None)
    if zone is None:
        raise HTTPException(status_code=404, detail="Zone not found.")
    parameters = dict(payload.parameters)
    parameters.update({"zone_id": zone_id, "zone_name": zone["name"]})
    command = store.create_command(
        robot_id,
        "startCleaning",
        payload.idempotency_key,
        parameters,
    )
    request.app.state.bridge.dispatch(command)
    return command


@router.get("/commands/{command_id}")
def command_status(
    command_id: str,
    request: Request,
    _: AuthUser = Depends(get_current_user),
) -> dict:
    command = _store(request).get_command(command_id)
    if command is None:
        raise HTTPException(status_code=404, detail="Command not found.")
    return command


@router.post("/robots/{robot_id}/manual-drive")
def manual_drive(
    robot_id: str,
    payload: ManualDriveRequest,
    request: Request,
    _: AuthUser = Depends(require_controller),
) -> dict:
    store = _store(request)
    _ensure_robot(store, robot_id)
    request.app.state.bridge.manual_drive(
        payload.linear_x, payload.angular_z, payload.duration_ms
    )
    return {"status": "dispatched", "robot_id": robot_id}


@router.post("/robots/{robot_id}/estop")
def emergency_stop(
    robot_id: str,
    request: Request,
    _: AuthUser = Depends(require_controller),
) -> dict:
    store = _store(request)
    _ensure_robot(store, robot_id)
    request.app.state.bridge.publish_estop(True)
    store.update_status({"status": "fault"})
    return {"status": "estopped", "robot_id": robot_id}


@router.patch("/settings")
def patch_settings(
    payload: SettingsPatch,
    request: Request,
    _: AuthUser = Depends(require_controller),
) -> dict:
    store = _store(request)
    if payload.robot_name:
        store.robot["name"] = payload.robot_name
    if payload.cleaning_speed:
        store.cleaning_mode = payload.cleaning_speed
    if payload.auto_dock is not None:
        store.auto_dock = payload.auto_dock
    return store.system_status()
