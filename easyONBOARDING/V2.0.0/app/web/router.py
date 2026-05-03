from fastapi import APIRouter

from app.web.routers.dashboard import router as dashboard_router
from app.web.routers.platform import router as platform_router

router = APIRouter(include_in_schema=False)
router.include_router(platform_router)
router.include_router(dashboard_router)
