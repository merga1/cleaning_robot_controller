from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=200)
    password: str = Field(min_length=1, max_length=200)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=10)


class CommandRequest(BaseModel):
    command: str = Field(min_length=1, max_length=64)
    idempotency_key: str = Field(min_length=1, max_length=128)
    parameters: dict[str, Any] = Field(default_factory=dict)


class ZoneStartRequest(BaseModel):
    idempotency_key: str = Field(min_length=1, max_length=128)
    parameters: dict[str, Any] = Field(default_factory=dict)


class ReadNotificationRequest(BaseModel):
    is_read: bool = True


class ManualDriveRequest(BaseModel):
    linear_x: float = Field(ge=-1.0, le=1.0)
    angular_z: float = Field(ge=-2.0, le=2.0)
    duration_ms: int = Field(default=250, ge=50, le=3000)


class SettingsPatch(BaseModel):
    robot_name: str | None = None
    cleaning_speed: Literal["quiet", "standard", "deep"] | None = None
    auto_dock: bool | None = None
    simulation_enabled: bool | None = None
