import pytest
from fastapi.testclient import TestClient

from app.core.settings import get_settings
from app.main import app


@pytest.fixture
def client(tmp_path, monkeypatch: pytest.MonkeyPatch) -> TestClient:
    temp_root = tmp_path
    monkeypatch.setenv("EASYONB_DATA_DIR", str(temp_root / "data"))
    monkeypatch.setenv("EASYONB_SQLITE_PATH", str(temp_root / "data" / "easyonb_test.db"))
    monkeypatch.setenv("EASYONB_RUNNER_LOGS_DIR", str(temp_root / "data" / "runner_logs"))
    get_settings.cache_clear()

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    get_settings.cache_clear()
