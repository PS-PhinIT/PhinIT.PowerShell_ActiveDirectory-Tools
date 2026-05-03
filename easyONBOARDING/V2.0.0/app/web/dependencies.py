from typing import Annotated

from fastapi import Depends

from app.core.settings import Settings, get_settings

SettingsDep = Annotated[Settings, Depends(get_settings)]
