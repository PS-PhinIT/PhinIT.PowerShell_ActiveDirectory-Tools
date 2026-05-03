from contextlib import asynccontextmanager
from datetime import UTC, datetime
from typing import AsyncIterator

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.api.router import router as api_router
from app.core.settings import get_settings
from app.services.directory_search import DirectorySearchService
from app.services.job_store import JobStore
from app.services.powershell_runner import PowerShellRunner
from app.web.router import router as web_router


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    settings.runner_logs_dir.mkdir(parents=True, exist_ok=True)

    job_store = JobStore(settings.sqlite_path)
    job_store.initialize()

    runner = PowerShellRunner()

    app.state.settings = settings
    app.state.started_at = datetime.now(UTC)
    app.state.job_store = job_store
    app.state.powershell_runner = runner
    app.state.directory_search_service = DirectorySearchService(
        settings=settings,
        runner=runner,
        job_store=job_store,
    )
    yield
    app.state.started_at = None


def create_app() -> FastAPI:
    settings = get_settings()

    application = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        debug=settings.debug,
        lifespan=lifespan,
    )

    application.mount("/static", StaticFiles(directory=str(settings.static_dir)), name="static")
    application.include_router(api_router)
    application.include_router(web_router)

    return application


app = create_app()
