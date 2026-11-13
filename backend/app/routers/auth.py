from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from ..schemas import LoginRequest, RefreshRequest
from ..security import (
    AuthUser,
    create_token_pair,
    decode_token,
    get_current_user,
    user_directory,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login")
def login(payload: LoginRequest) -> dict:
    user = user_directory.authenticate(payload.username, payload.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
        )
    return create_token_pair(user)


@router.post("/refresh")
def refresh(payload: RefreshRequest) -> dict:
    claims = decode_token(payload.refresh_token, expected_type="refresh")
    user = user_directory.by_id(str(claims.get("sub")))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User no longer exists.",
        )
    return create_token_pair(user)


@router.post("/logout")
def logout(_: AuthUser = Depends(get_current_user)) -> dict:
    return {"status": "ok"}


@router.get("/me")
def me(user: AuthUser = Depends(get_current_user)) -> dict:
    return user.as_api()
