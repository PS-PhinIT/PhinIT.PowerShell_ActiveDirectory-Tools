from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parents[2]
ENV_FILE = BASE_DIR / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="EASYONB_",
        case_sensitive=False,
        env_file=ENV_FILE,
        env_file_encoding="utf-8",
        env_ignore_empty=True,
        extra="ignore",
    )

    app_name: str = "easyONBOARDING V2.0.0"
    app_version: str = "0.1.0"
    app_environment: str = "development"
    debug: bool = False

    base_dir: Path = Field(default=BASE_DIR)
    data_dir: Path = Field(default=BASE_DIR / "data")
    docs_dir: Path = Field(default=BASE_DIR / "DOC")
    templates_dir: Path = Field(default=BASE_DIR / "app" / "templates")
    static_dir: Path = Field(default=BASE_DIR / "app" / "static")
    sqlite_path: Path = Field(default=BASE_DIR / "data" / "easyonb_v2.db")
    runner_logs_dir: Path = Field(default=BASE_DIR / "data" / "runner_logs")
    powershell_dir: Path = Field(default=BASE_DIR / "modules" / "powershell")
    ad_user_search_connector: Path = Field(default=BASE_DIR / "modules" / "powershell" / "Search-EasyOnbAdUser.ps1")
    powershell_connector_timeout_seconds: int = 30
    ad_user_search_max_results: int = 25

    @property
    def is_development(self) -> bool:
        return self.app_environment.lower() == "development"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
