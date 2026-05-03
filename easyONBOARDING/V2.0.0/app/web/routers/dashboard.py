from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from app.services.dashboard_service import get_dashboard_view_model
from app.web.dependencies import SettingsDep
from app.web.templating import render_page, templates

router = APIRouter(include_in_schema=False)


@router.get("/dashboard", response_class=HTMLResponse)
def dashboard(request: Request, settings: SettingsDep) -> HTMLResponse:
    return render_page(
        request,
        "pages/dashboard.html",
        page_title="Dashboard",
        settings=settings,
        **get_dashboard_view_model(),
    )


@router.get("/dashboard/fragments/metrics", response_class=HTMLResponse)
def dashboard_metrics(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(
        request=request,
        name="partials/dashboard_metrics.html",
        context={
            "metrics": get_dashboard_view_model()["metrics"],
        },
    )
