from __future__ import annotations

import json
from uuid import uuid4

from fastapi import APIRouter, Query, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse

from app.services.directory_search import DirectorySearchService
from app.services.documentation_service import (
    DocumentationNotFoundError,
    build_documentation_view,
    build_documentation_href,
    render_markdown,
)
from app.services.job_store import JobStore
from app.services.lifecycle_forms import (
    OFFBOARDING_EXIT_TYPES,
    ONBOARDING_ROLE_PACKAGES,
    offboarding_form_defaults,
    onboarding_form_defaults,
    parse_offboarding_form,
    parse_onboarding_form,
)
from app.services.powershell_runner import PowerShellRunner
from app.web.dependencies import SettingsDep
from app.web.templating import render_page

router = APIRouter(include_in_schema=False)

ONBOARDING_STEPS = [
    "Stammdaten und HR-Quelle prüfen",
    "Organisation und Zielrolle festlegen",
    "Rollenpakete, Gruppen und Lizenzen auswählen",
    "Kommunikation, Telefonie und Assets vorbereiten",
    "Review, Dry-Run und Folgeaufgaben erzeugen",
]

OFFBOARDING_STEPS = [
    "Austrittsart und Termin festlegen",
    "AD- und Lizenzzielzustand definieren",
    "Mailbox-, Daten- und Geräteübergaben prüfen",
    "Telefonie und Drittsysteme bereinigen",
    "Abschlussbericht und Wiedervorlagen erzeugen",
]

CONTEXT_HELP_LINKS = {
    "onboarding": [
        {
            "label": "Onboarding-Handbuch",
            "description": "Eingaben, Validierung und aktueller Dry-Run-Umfang des Formulars.",
            "href": build_documentation_href(doc="01_USER_GUIDES/B_Onboarding_Handbook.md"),
        },
        {
            "label": "Standard-Onboarding-Flow",
            "description": "Prozesssicht für Joiner, Review, Folgeaufgaben und Übergaben.",
            "href": build_documentation_href(doc="04_WORKFLOWS/Standard_Onboarding_Flow.md"),
        },
        {
            "label": "Rollenpakete und Bundles",
            "description": "Welche Rolle das Rollenpaket im Formular und späteren Connectoren spielt.",
            "href": build_documentation_href(doc="05_CONFIGURATION/Role_Bundles_Definition.md"),
        },
    ],
    "offboarding": [
        {
            "label": "Offboarding-Handbuch",
            "description": "Leitfaden für Austrittsdaten, Übergaben und sensible Prüfpunkte.",
            "href": build_documentation_href(doc="01_USER_GUIDES/C_Offboarding_Handbook.md"),
        },
        {
            "label": "Standard-Offboarding-Flow",
            "description": "Schrittfolge für Sperrung, Übergabe, Audit und Nacharbeiten.",
            "href": build_documentation_href(doc="04_WORKFLOWS/Standard_Offboarding_Flow.md"),
        },
        {
            "label": "Security- und Audit-Baseline",
            "description": "Sicherheitsleitplanken für produktive Abschaltprozesse.",
            "href": build_documentation_href(doc="08_SECURITY_COMPLIANCE/Security_and_Audit_Baseline.md"),
        },
    ],
    "users": [
        {
            "label": "Benutzerübersicht-Modul",
            "description": "Wofür die Benutzerliste gedacht ist und wie sie ausgebaut werden soll.",
            "href": build_documentation_href(doc="03_MODULES/User_Overview_Module.md"),
        },
        {
            "label": "Core Foundation",
            "description": "Grundsätzliche Architektur- und Navigationsprinzipien der V2-Plattform.",
            "href": build_documentation_href(doc="03_MODULES/Core_Foundation.md"),
        },
    ],
    "jobs": [
        {
            "label": "Jobmonitor-Modul",
            "description": "Zielbild für Queue, Worker, Wiederholungen und Fehlernacharbeit.",
            "href": build_documentation_href(doc="03_MODULES/Job_Monitor_Module.md"),
        },
        {
            "label": "Health-Check-Runbook",
            "description": "Betriebsleitfaden für Prüfung, Beobachtung und Störungen.",
            "href": build_documentation_href(doc="07_OPERATIONS/Health_Check_Runbook.md"),
        },
    ],
    "settings": [
        {
            "label": "Plattform-Einstellungen",
            "description": "Übersicht zu Mandanten, Connectoren, Richtlinien und Plattformsteuerung.",
            "href": build_documentation_href(doc="05_CONFIGURATION/Platform_Settings_Module.md"),
        },
        {
            "label": "Configuration Overview",
            "description": "Aktuelle Konfigurationsquellen und deren technische Zuständigkeiten.",
            "href": build_documentation_href(doc="05_CONFIGURATION/Configuration_Overview.md"),
        },
        {
            "label": "Security- und Audit-Baseline",
            "description": "Rahmen für Freigaben, Audit, Secrets und sensible Aktionen.",
            "href": build_documentation_href(doc="08_SECURITY_COMPLIANCE/Security_and_Audit_Baseline.md"),
        },
    ],
}


def _build_submission_result(*, title: str, message: str, contract: dict[str, object], summary_rows: list[tuple[str, str]], next_actions: list[str]) -> dict[str, object]:
    return {
        "title": title,
        "message": message,
        "correlation_id": contract["correlation_id"],
        "module": contract["module"],
        "action": contract["action"],
        "requested_by": contract["requested_by"],
        "dry_run": contract["dry_run"],
        "summary_rows": summary_rows,
        "next_actions": next_actions,
        "contract_payload_pretty": json.dumps(contract, indent=2, ensure_ascii=False),
    }


def _get_runner(request: Request) -> PowerShellRunner:
    return request.app.state.powershell_runner


def _get_job_store(request: Request) -> JobStore:
    return request.app.state.job_store


def _get_directory_search_service(request: Request) -> DirectorySearchService:
    return request.app.state.directory_search_service


def _render_onboarding_page(
    request: Request,
    settings: SettingsDep,
    *,
    form_values: dict[str, object] | None = None,
    field_errors: dict[str, list[str]] | None = None,
    form_errors: list[str] | None = None,
    submission_result: dict[str, object] | None = None,
    status_code: int = status.HTTP_200_OK,
) -> HTMLResponse:
    response = render_page(
        request,
        "pages/onboarding.html",
        page_title="Onboarding Wizard",
        settings=settings,
        steps=ONBOARDING_STEPS,
        role_packages=ONBOARDING_ROLE_PACKAGES,
        form_values=form_values or onboarding_form_defaults(),
        field_errors=field_errors or {},
        form_errors=form_errors or [],
        submission_result=submission_result,
        help_links=CONTEXT_HELP_LINKS["onboarding"],
    )
    response.status_code = status_code
    return response


def _render_offboarding_page(
    request: Request,
    settings: SettingsDep,
    *,
    form_values: dict[str, object] | None = None,
    field_errors: dict[str, list[str]] | None = None,
    form_errors: list[str] | None = None,
    submission_result: dict[str, object] | None = None,
    status_code: int = status.HTTP_200_OK,
) -> HTMLResponse:
    response = render_page(
        request,
        "pages/offboarding.html",
        page_title="Offboarding Wizard",
        settings=settings,
        steps=OFFBOARDING_STEPS,
        exit_types=OFFBOARDING_EXIT_TYPES,
        form_values=form_values or offboarding_form_defaults(),
        field_errors=field_errors or {},
        form_errors=form_errors or [],
        submission_result=submission_result,
        help_links=CONTEXT_HELP_LINKS["offboarding"],
    )
    response.status_code = status_code
    return response


def _render_documentation_page(
    request: Request,
    settings: SettingsDep,
    *,
    selected_doc_path: str | None,
    selected_section_path: str | None = None,
    search_query: str | None = None,
    error_message: str | None = None,
    status_code: int = status.HTTP_200_OK,
) -> HTMLResponse:
    view = build_documentation_view(
        settings.docs_dir,
        selected_doc_path,
        selected_section_path=selected_section_path,
        search_query=search_query,
    )
    response = render_page(
        request,
        "pages/documentation.html",
        page_title="Dokumentation",
        settings=settings,
        error_message=error_message,
        **view,
    )
    response.status_code = status_code
    return response


@router.get("/", response_class=RedirectResponse, status_code=status.HTTP_302_FOUND)
def index() -> RedirectResponse:
    return RedirectResponse(url="/dashboard", status_code=status.HTTP_302_FOUND)


@router.get("/users", response_class=HTMLResponse)
def users(request: Request, settings: SettingsDep, q: str | None = Query(default=None)) -> HTMLResponse:
    search_query = (q or "").strip()
    search_result: dict[str, object] | None = None
    form_errors: list[str] = []
    users: list[dict[str, object]] = []

    if search_query:
        try:
            search_result = _get_directory_search_service(request).search_users(search_query, requested_by="web-ui")
            users = list(search_result.get("users", []))
        except ValueError as exc:
            form_errors = [str(exc)]
        except Exception as exc:  # pragma: no cover - hard failure path
            search_result = {
                "job_id": None,
                "status": "Failed",
                "success": False,
                "message": "Benutzersuche konnte nicht erfolgreich ausgeführt werden.",
                "warnings": [],
                "errors": [str(exc)],
                "correlation_id": None,
                "exit_code": None,
                "duration_ms": None,
                "count": 0,
                "search_term": search_query,
                "users": [],
            }

    return render_page(
        request,
        "pages/users.html",
        page_title="Benutzerübersicht",
        settings=settings,
        users=users,
        search_query=search_query,
        search_result=search_result,
        form_errors=form_errors,
        help_links=CONTEXT_HELP_LINKS["users"],
    )


@router.get("/processes/onboarding", response_class=HTMLResponse)
def onboarding(request: Request, settings: SettingsDep) -> HTMLResponse:
    return _render_onboarding_page(request, settings)


@router.post("/processes/onboarding", response_class=HTMLResponse)
async def submit_onboarding(request: Request, settings: SettingsDep) -> HTMLResponse:
    form_data = await request.form()
    onboarding_request, form_values, field_errors, form_errors = parse_onboarding_form(form_data)

    if onboarding_request is None:
        return _render_onboarding_page(
            request,
            settings,
            form_values=form_values,
            field_errors=field_errors,
            form_errors=form_errors,
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    runner = _get_runner(request)
    contract = runner.create_contract_payload(
        module="Lifecycle.Onboarding",
        action="prepare",
        requested_by="web-ui",
        payload=onboarding_request.model_dump(mode="json"),
        correlation_id=f"ONB-{uuid4().hex[:10].upper()}",
        dry_run=True,
    )
    summary_rows = [
        ("Mitarbeiter", f"{onboarding_request.given_name} {onboarding_request.family_name}"),
        ("E-Mail", onboarding_request.primary_mail),
        ("Startdatum", onboarding_request.start_date.isoformat()),
        ("Rollenpaket", onboarding_request.role_package),
        ("Manager", onboarding_request.manager_display_name),
    ]
    next_actions = [
        "Connector-Aufruf für AD/M365 anbinden",
        "Freigabe-Workflow und Audit-Eintrag ergänzen",
        "Job in die spätere Worker-Queue überführen",
    ]
    job_id = _get_job_store(request).create_job(
        module=contract["module"],
        action=contract["action"],
        status="DryRun",
        detail="Dry-Run-Vertrag für Onboarding erstellt.",
        requested_by="web-ui",
        correlation_id=str(contract["correlation_id"]),
        dry_run=True,
        contract_payload=contract,
        result_payload={"summary_rows": summary_rows, "next_actions": next_actions},
        success=True,
    )
    submission_result = _build_submission_result(
        title="Onboarding-Request vorbereitet",
        message="Die Eingaben wurden validiert und als Dry-Run-Vertrag für den späteren PowerShell-Connector aufgebaut.",
        contract=contract,
        summary_rows=summary_rows,
        next_actions=next_actions,
    )
    submission_result["job_id"] = job_id
    submission_result["job_status"] = "DryRun"
    return _render_onboarding_page(
        request,
        settings,
        form_values=onboarding_form_defaults(),
        submission_result=submission_result,
        status_code=status.HTTP_201_CREATED,
    )


@router.get("/processes/offboarding", response_class=HTMLResponse)
def offboarding(request: Request, settings: SettingsDep) -> HTMLResponse:
    return _render_offboarding_page(request, settings)


@router.post("/processes/offboarding", response_class=HTMLResponse)
async def submit_offboarding(request: Request, settings: SettingsDep) -> HTMLResponse:
    form_data = await request.form()
    offboarding_request, form_values, field_errors, form_errors = parse_offboarding_form(form_data)

    if offboarding_request is None:
        return _render_offboarding_page(
            request,
            settings,
            form_values=form_values,
            field_errors=field_errors,
            form_errors=form_errors,
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    runner = _get_runner(request)
    contract = runner.create_contract_payload(
        module="Lifecycle.Offboarding",
        action="prepare",
        requested_by="web-ui",
        payload=offboarding_request.model_dump(mode="json"),
        correlation_id=f"OFF-{uuid4().hex[:10].upper()}",
        dry_run=True,
    )
    summary_rows = [
        ("Benutzer", offboarding_request.display_name),
        ("Postfach", offboarding_request.primary_mail),
        ("Austrittsdatum", offboarding_request.exit_date.isoformat()),
        ("Austrittsart", offboarding_request.exit_type),
        ("Manager", offboarding_request.manager_display_name),
    ]
    next_actions = [
        "AD-Sperre und Lizenz-Entzug orchestrieren",
        "Mailbox-Weiterleitung bzw. Delegation prüfen",
        "Asset-Rückgabe und Abschlussbericht an Job-Queue übergeben",
    ]
    job_id = _get_job_store(request).create_job(
        module=contract["module"],
        action=contract["action"],
        status="DryRun",
        detail="Dry-Run-Vertrag für Offboarding erstellt.",
        requested_by="web-ui",
        correlation_id=str(contract["correlation_id"]),
        dry_run=True,
        contract_payload=contract,
        result_payload={"summary_rows": summary_rows, "next_actions": next_actions},
        success=True,
    )
    submission_result = _build_submission_result(
        title="Offboarding-Request vorbereitet",
        message="Der sensible Abschaltprozess wurde validiert und als Dry-Run-Vertrag für die spätere Ausführung vorbereitet.",
        contract=contract,
        summary_rows=summary_rows,
        next_actions=next_actions,
    )
    submission_result["job_id"] = job_id
    submission_result["job_status"] = "DryRun"
    return _render_offboarding_page(
        request,
        settings,
        form_values=offboarding_form_defaults(),
        submission_result=submission_result,
        status_code=status.HTTP_201_CREATED,
    )


@router.get("/jobs", response_class=HTMLResponse)
def jobs(request: Request, settings: SettingsDep) -> HTMLResponse:
    job_items = _get_job_store(request).list_jobs(limit=50)
    return render_page(
        request,
        "pages/jobs.html",
        page_title="Jobs und Hintergrundaufgaben",
        settings=settings,
        jobs=job_items,
        help_links=CONTEXT_HELP_LINKS["jobs"],
    )


@router.get("/documentation", response_class=HTMLResponse)
def documentation(
    request: Request,
    settings: SettingsDep,
    doc: str | None = Query(default=None),
    section: str | None = Query(default=None),
    q: str | None = Query(default=None),
) -> HTMLResponse:
    try:
        return _render_documentation_page(
            request,
            settings,
            selected_doc_path=doc,
            selected_section_path=section,
            search_query=q,
        )
    except DocumentationNotFoundError as exc:
        return _render_documentation_page(
            request,
            settings,
            selected_doc_path=None,
            selected_section_path=None,
            search_query=q,
            error_message=str(exc),
            status_code=status.HTTP_404_NOT_FOUND,
        )


@router.post("/documentation/preview", response_class=HTMLResponse)
async def documentation_preview(request: Request, settings: SettingsDep) -> HTMLResponse:
    form_data = await request.form()
    preview_markdown = str(form_data.get("preview_markdown", ""))
    return render_page(
        request,
        "partials/documentation_preview.html",
        page_title="Markdown-Vorschau",
        settings=settings,
        preview_html=render_markdown(preview_markdown if preview_markdown.strip() else "_Noch kein Markdown für die Vorschau vorhanden._"),
        preview_has_content=bool(preview_markdown.strip()),
        preview_source_length=len(preview_markdown),
    )


@router.get("/settings", response_class=HTMLResponse)
def settings_page(request: Request, settings: SettingsDep) -> HTMLResponse:
    setting_groups = [
        {
            "title": "Mandanten und Branding",
            "detail": "Firma, Logos, Domänen, Standardpfade und Reportprofile verwalten.",
        },
        {
            "title": "Module und Connectoren",
            "detail": "Aktivierung, Health, Rechte und technische Zielsysteme konfigurieren.",
        },
        {
            "title": "Security und Audit",
            "detail": "Freigaben, sensible Aktionen, Exportregeln und Logging-Richtlinien steuern.",
        },
    ]
    return render_page(
        request,
        "pages/settings.html",
        page_title="Einstellungen und Plattformsteuerung",
        settings=settings,
        setting_groups=setting_groups,
        help_links=CONTEXT_HELP_LINKS["settings"],
    )
