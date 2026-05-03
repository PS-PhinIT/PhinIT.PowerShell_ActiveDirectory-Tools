from fastapi.testclient import TestClient

from app.core.settings import get_settings
from app.main import app


class FakeDirectorySearchService:
    def search_users(self, search_term: str, *, requested_by: str = "web-ui") -> dict[str, object]:
        return {
            "job_id": "JOB-TEST-SEARCH-0001",
            "status": "Completed",
            "success": True,
            "message": "1 Benutzer gefunden.",
            "warnings": [],
            "errors": [],
            "correlation_id": "USR-TEST-0001",
            "exit_code": 0,
            "duration_ms": 12,
            "count": 1,
            "search_term": search_term,
            "users": [
                {
                    "display_name": "Max Muster",
                    "sam_account_name": "mmuster",
                    "department": "IT Service",
                    "location": "Bielefeld",
                    "primary_mail": "max.muster@example.local",
                    "user_principal_name": "mmuster@example.local",
                    "enabled": True,
                }
            ],
        }


def test_root_redirects_to_dashboard(client: TestClient) -> None:
    response = client.get("/", follow_redirects=False)

    assert response.status_code == 302
    assert response.headers["location"] == "/dashboard"


def test_healthcheck_exposes_runtime_metadata(client: TestClient) -> None:
    response = client.get("/health")
    payload = response.json()

    assert response.status_code == 200
    assert payload["status"] == "ok"
    assert payload["app"] == get_settings().app_name
    assert payload["environment"] == get_settings().app_environment
    assert payload["started_at"]


def test_dashboard_renders_expected_template_context(client: TestClient) -> None:
    response = client.get("/dashboard")

    assert response.status_code == 200
    assert response.template.name == "pages/dashboard.html"
    assert response.context["page_title"] == "Dashboard"
    assert response.context["app_name"] == get_settings().app_name
    assert response.context["current_path"] == "/dashboard"
    assert response.context["metrics"]
    assert "request" in response.context


def test_dashboard_metrics_fragment_uses_partial_template(client: TestClient) -> None:
    response = client.get("/dashboard/fragments/metrics")

    assert response.status_code == 200
    assert response.template.name == "partials/dashboard_metrics.html"
    assert response.context["metrics"]


def test_users_page_allows_settings_override() -> None:
    base_settings = get_settings()

    def override_settings():
        return base_settings.model_copy(update={"app_name": "easyONBOARDING Testmodus"})

    app.dependency_overrides[get_settings] = override_settings

    try:
        with TestClient(app) as client:
            response = client.get("/users")

        assert response.status_code == 200
        assert response.template.name == "pages/users.html"
        assert response.context["app_name"] == "easyONBOARDING Testmodus"
    finally:
        app.dependency_overrides.clear()


def test_users_page_executes_directory_search_when_query_is_present(client: TestClient) -> None:
    app.state.directory_search_service = FakeDirectorySearchService()

    response = client.get("/users?q=muster")

    assert response.status_code == 200
    assert response.template.name == "pages/users.html"
    assert response.context["search_result"]["count"] == 1
    assert response.context["users"][0]["sam_account_name"] == "mmuster"


def test_users_page_validates_short_search_terms(client: TestClient) -> None:
    response = client.get("/users?q=a")

    assert response.status_code == 200
    assert response.template.name == "pages/users.html"
    assert response.context["form_errors"]


def test_onboarding_page_renders_form_defaults(client: TestClient) -> None:
    response = client.get("/processes/onboarding")

    assert response.status_code == 200
    assert response.template.name == "pages/onboarding.html"
    assert response.context["form_values"]["role_package"] == "standard-user"
    assert response.context["field_errors"] == {}
    assert response.context["help_links"]


def test_onboarding_submission_returns_contract_preview(client: TestClient) -> None:
    response = client.post(
        "/processes/onboarding",
        data={
            "given_name": "Mara",
            "family_name": "Beispiel",
            "primary_mail": "mara.beispiel@example.local",
            "department": "IT Service",
            "location": "Bielefeld",
            "start_date": "2099-05-03",
            "manager_display_name": "Lea Leitung",
            "role_package": "it-admin",
            "needs_mailbox": "on",
            "needs_device": "on",
            "generate_welcome_letter": "on",
        },
    )

    assert response.status_code == 201
    assert response.template.name == "pages/onboarding.html"
    assert response.context["submission_result"]["module"] == "Lifecycle.Onboarding"
    assert response.context["submission_result"]["dry_run"] is True
    assert response.context["submission_result"]["job_id"].startswith("JOB-")
    assert response.context["submission_result"]["summary_rows"][0][1] == "Mara Beispiel"


def test_onboarding_submission_shows_validation_errors(client: TestClient) -> None:
    response = client.post(
        "/processes/onboarding",
        data={
            "given_name": "A",
            "family_name": "",
            "primary_mail": "not-an-email",
            "department": "I",
            "location": "",
            "start_date": "2001-01-01",
            "manager_display_name": "",
            "role_package": "unknown",
        },
    )

    assert response.status_code == 400
    assert response.template.name == "pages/onboarding.html"
    assert "given_name" in response.context["field_errors"]
    assert "primary_mail" in response.context["field_errors"]
    assert response.context["submission_result"] is None


def test_offboarding_immediate_exit_requires_immediate_disable(client: TestClient) -> None:
    response = client.post(
        "/processes/offboarding",
        data={
            "display_name": "Max Muster",
            "primary_mail": "max.muster@example.local",
            "department": "Vertrieb",
            "exit_date": "2099-06-01",
            "manager_display_name": "Nina Nachfolge",
            "exit_type": "immediate",
            "collect_assets": "on",
            "preserve_home_drive": "on",
        },
    )

    assert response.status_code == 400
    assert response.template.name == "pages/offboarding.html"
    assert "Sofort-Austritt" in response.context["form_errors"][0]


def test_offboarding_submission_returns_contract_preview(client: TestClient) -> None:
    response = client.post(
        "/processes/offboarding",
        data={
            "display_name": "Anna Beispiel",
            "primary_mail": "anna.beispiel@example.local",
            "department": "Finance",
            "exit_date": "2099-08-01",
            "manager_display_name": "Kai Koordination",
            "exit_type": "standard",
            "forward_mail_to": "team.finance@example.local",
            "mailbox_access_delegate": "backoffice.finance",
            "collect_assets": "on",
            "preserve_home_drive": "on",
        },
    )

    assert response.status_code == 201
    assert response.template.name == "pages/offboarding.html"
    assert response.context["submission_result"]["module"] == "Lifecycle.Offboarding"
    assert response.context["submission_result"]["dry_run"] is True
    assert response.context["submission_result"]["job_id"].startswith("JOB-")


def test_jobs_page_lists_persisted_dry_run_jobs(client: TestClient) -> None:
    client.post(
        "/processes/onboarding",
        data={
            "given_name": "Mara",
            "family_name": "Beispiel",
            "primary_mail": "mara.beispiel@example.local",
            "department": "IT Service",
            "location": "Bielefeld",
            "start_date": "2099-05-03",
            "manager_display_name": "Lea Leitung",
            "role_package": "it-admin",
        },
    )

    response = client.get("/jobs")

    assert response.status_code == 200
    assert response.template.name == "pages/jobs.html"
    assert response.context["jobs"]
    assert response.context["jobs"][0]["module"] == "Lifecycle.Onboarding"


def test_documentation_page_loads_live_doc_tree(client: TestClient) -> None:
    response = client.get("/documentation")

    assert response.status_code == 200
    assert response.template.name == "pages/documentation.html"
    assert response.context["doc_sections"]
    assert response.context["doc_count"] >= 1
    assert response.context["selected_doc"] is not None


def test_documentation_page_can_select_specific_markdown_file(client: TestClient) -> None:
    response = client.get("/documentation?doc=02_ARCHITECTURE/A_Platform_Architecture.md")

    assert response.status_code == 200
    assert response.template.name == "pages/documentation.html"
    assert response.context["selected_doc"].relative_path == "02_ARCHITECTURE/A_Platform_Architecture.md"
    assert "IIS" in str(response.context["selected_doc_html"])


def test_documentation_page_filters_results_by_search_query(client: TestClient) -> None:
    response = client.get("/documentation?q=PowerShell Runner")

    assert response.status_code == 200
    assert response.template.name == "pages/documentation.html"
    assert response.context["search_active"] is True
    assert response.context["doc_count"] >= 1
    assert response.context["selected_doc"].relative_path == "02_ARCHITECTURE/C_PowerShell_Runner_Contract.md"


def test_documentation_page_can_render_auto_index_for_section(client: TestClient) -> None:
    response = client.get("/documentation?section=07_OPERATIONS")

    assert response.status_code == 200
    assert response.template.name == "pages/documentation.html"
    assert response.context["selected_section"]["folder_path"] == "07_OPERATIONS"
    assert "Automatisch generiertes Bereichsverzeichnis" in str(response.context["selected_doc_html"])


def test_documentation_preview_renders_sanitized_markdown(client: TestClient) -> None:
    response = client.post(
        "/documentation/preview",
        data={"preview_markdown": "# Hallo\n\n<script>alert('x')</script>"},
    )

    assert response.status_code == 200
    assert response.template.name == "partials/documentation_preview.html"
    assert "<h1" in response.text
    assert "<script>" not in response.text


def test_documentation_page_rejects_invalid_relative_path(client: TestClient) -> None:
    response = client.get("/documentation?doc=../../secrets.txt")

    assert response.status_code == 404
    assert response.template.name == "pages/documentation.html"
    assert response.context["error_message"]
