def get_dashboard_view_model() -> dict[str, list[dict[str, str]]]:
    return {
        "metrics": [
            {
                "title": "Offene Onboardings",
                "value": "12",
                "detail": "3 starten innerhalb der nächsten 48 Stunden",
                "tone": "primary",
                "icon": "bi-person-plus-fill",
            },
            {
                "title": "Offene Offboardings",
                "value": "4",
                "detail": "1 Austritt benötigt Sofortmaßnahme",
                "tone": "danger",
                "icon": "bi-person-dash-fill",
            },
            {
                "title": "Blockierte Jobs",
                "value": "2",
                "detail": "Telefonie- und Ticketing-Nacharbeit offen",
                "tone": "warning",
                "icon": "bi-exclamation-triangle-fill",
            },
            {
                "title": "Health-Warnungen",
                "value": "3",
                "detail": "ADSync, STARFACE-Test und Report-Worker prüfen",
                "tone": "info",
                "icon": "bi-heart-pulse-fill",
            },
        ],
        "alerts": [
            {
                "title": "ADSync-Kontext noch nicht verbunden",
                "detail": "Das Modul ist vorbereitet, aber noch nicht mit einem produktiven Sync-Server verknüpft.",
                "tone": "warning",
            },
            {
                "title": "PowerShell-Runner aktuell im Stub-Modus",
                "detail": "Der Runner-Vertrag ist vorhanden, produktive Connectoren werden im nächsten Schritt angeschlossen.",
                "tone": "info",
            },
        ],
        "quick_actions": [
            {"label": "Neues Onboarding", "href": "/processes/onboarding", "icon": "bi-person-plus"},
            {"label": "Offboarding starten", "href": "/processes/offboarding", "icon": "bi-person-dash"},
            {"label": "Benutzer suchen", "href": "/users", "icon": "bi-search"},
            {"label": "Jobs prüfen", "href": "/jobs", "icon": "bi-list-check"},
        ],
        "recent_activity": [
            {
                "title": "Max Muster – Preboarding angelegt",
                "detail": "Rollenpaket Vertrieb + M365 Standard vorbereitet",
                "timestamp": "vor 12 Minuten",
            },
            {
                "title": "Leaver-Prozess für Anna Beispiel abgeschlossen",
                "detail": "AD deaktiviert, Mailbox-Übergabe als Folgeaufgabe erzeugt",
                "timestamp": "vor 46 Minuten",
            },
            {
                "title": "Job #2026-0510 blockiert",
                "detail": "STARFACE-API nicht erreichbar – Nacharbeit erforderlich",
                "timestamp": "vor 1 Stunde",
            },
        ],
        "module_health": [
            {"name": "Core.Auth", "status": "Geplant", "tone": "primary"},
            {"name": "Core.RunnerPS51", "status": "Stub aktiv", "tone": "info"},
            {"name": "Lifecycle.Onboarding", "status": "UI-Grundgerüst", "tone": "success"},
            {"name": "UC.STARFACE", "status": "noch offen", "tone": "secondary"},
        ],
    }
