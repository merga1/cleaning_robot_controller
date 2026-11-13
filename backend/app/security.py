"""Authentication helpers: PBKDF2 password hashing and HS256 JWTs.

The implementation only uses the Python standard library for password
hashing, which keeps the Raspberry Pi installation small.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import os
import time
from dataclasses import dataclass
from typing import Any

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import Settings, settings

_PBKDF2_ITERATIONS = 210_000
_bearer = HTTPBearer(auto_error=False)


@dataclass(slots=True)
class AuthUser:
    id: str
    username: str
    email: str
    full_name: str
    role: str

    @property
    def can_control(self) -> bool:
        return self.role in {"admin", "operator"}

    def as_api(self) -> dict[str, str]:
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "full_name": self.full_name,
            "role": self.role,
        }


def hash_password(password: str, salt: bytes | None = None) -> str:
    salt = salt or os.urandom(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt, _PBKDF2_ITERATIONS
    )
    return "pbkdf2_sha256${}${}${}".format(
        _PBKDF2_ITERATIONS,
        base64.b64encode(salt).decode("ascii"),
        base64.b64encode(digest).decode("ascii"),
    )


def verify_password(password: str, encoded: str) -> bool:
    try:
        algorithm, iterations, salt_b64, digest_b64 = encoded.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        salt = base64.b64decode(salt_b64)
        expected = base64.b64decode(digest_b64)
        actual = hashlib.pbkdf2_hmac(
            "sha256", password.encode("utf-8"), salt, int(iterations)
        )
        return hmac.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False


class UserDirectory:
    def __init__(self, user_config: list[dict[str, Any]]) -> None:
        self._users: dict[str, dict[str, Any]] = {}
        for entry in user_config:
            username = str(entry.get("username") or entry.get("email") or "").lower()
            if not username:
                continue
            record = dict(entry)
            password = str(entry.get("password", ""))
            record["password_hash"] = entry.get("password_hash") or hash_password(
                password
            )
            self._users[username] = record

    def authenticate(self, username: str, password: str) -> AuthUser | None:
        record = self._users.get(username.strip().lower())
        if record is None:
            return None
        if not verify_password(password, str(record["password_hash"])):
            return None
        return self._to_user(record)

    def by_id(self, user_id: str) -> AuthUser | None:
        for record in self._users.values():
            if record.get("id") == user_id:
                return self._to_user(record)
        return None

    @staticmethod
    def _to_user(record: dict[str, Any]) -> AuthUser:
        return AuthUser(
            id=str(record.get("id") or record.get("username") or "usr"),
            username=str(record.get("username") or record.get("email") or "user"),
            email=str(record.get("email") or record.get("username") or ""),
            full_name=str(record.get("full_name") or "CleanBot User"),
            role=str(record.get("role") or "readonly").lower(),
        )


user_directory = UserDirectory(settings.users)


def create_token(
    user: AuthUser,
    token_type: str,
    ttl_seconds: int,
    config: Settings = settings,
) -> str:
    now = int(time.time())
    payload = {
        "sub": user.id,
        "username": user.username,
        "email": user.email,
        "role": user.role,
        "type": token_type,
        "iat": now,
        "nbf": now,
        "exp": now + ttl_seconds,
        "iss": "cleanbot-pi",
    }
    return jwt.encode(payload, config.jwt_secret, algorithm="HS256")


def create_token_pair(user: AuthUser, config: Settings = settings) -> dict[str, Any]:
    access = create_token(
        user, "access", config.access_token_minutes * 60, config
    )
    refresh = create_token(
        user, "refresh", config.refresh_token_days * 24 * 3600, config
    )
    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "bearer",
        "expires_in": config.access_token_minutes * 60,
        "user": user.as_api(),
    }


def decode_token(token: str, expected_type: str = "access") -> dict[str, Any]:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            issuer="cleanbot-pi",
            options={"require": ["exp", "sub", "type"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired. Please sign in again.",
        ) from exc
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token.",
        ) from exc

    if payload.get("type") != expected_type:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type.",
        )
    return payload


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> AuthUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = decode_token(credentials.credentials)
    user = user_directory.by_id(str(payload.get("sub")))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User no longer exists.",
        )
    return user


def require_controller(user: AuthUser = Depends(get_current_user)) -> AuthUser:
    if not user.can_control:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has read-only access.",
        )
    return user
