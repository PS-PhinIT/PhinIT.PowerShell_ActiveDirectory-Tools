from typing import Any

from fastapi import Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from app.core.navigation import build_primary_navigation
from app.core.settings import Settings, get_settings


def build_shared_context(request: Request) -> dict[str, object]:
    return {
        "current_path": request.url.path,
        "nav_items": build_primary_navigation(request.url.path),
    }


templates = Jinja2Templates(
    directory=str(get_settings().templates_dir),
    context_processors=[build_shared_context],
)


def render_page(
    request: Request,
    template_name: str,
    *,
    page_title: str,
    settings: Settings,
    **extra_context: Any,
) -> HTMLResponse:
    context: dict[str, Any] = {
        "page_title": page_title,
        "app_name": settings.app_name,
        "app_environment": settings.app_environment,
    }
    context.update(extra_context)

    return templates.TemplateResponse(
        request=request,
        name=template_name,
        context=context,
    )
