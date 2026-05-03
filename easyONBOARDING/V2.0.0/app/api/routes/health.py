from datetime import datetime

from fastapi import APIRouter, Request

router = APIRouter(tags=["health"])


@router.get("/health")
def healthcheck(request: Request) -> dict[str, str]:
    settings = request.app.state.settings
    started_at = getattr(request.app.state, "started_at", None)

    return {
        "status": "ok",
        "app": settings.app_name,
        "version": settings.app_version,
        "environment": settings.app_environment,
        "started_at": started_at.isoformat() if isinstance(started_at, datetime) else "",
    }
