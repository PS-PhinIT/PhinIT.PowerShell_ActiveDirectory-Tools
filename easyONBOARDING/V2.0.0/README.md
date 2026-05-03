# easyONBOARDING V2.0.0 – erste lauffähige Preview 0.1.0

## Zielbild

`easyONBOARDING V2.0.0` wird als **universelle User-Lifecycle- und IT-Operations-Plattform** geplant.
Der Fokus liegt nicht mehr nur auf klassischem Onboarding, sondern auf dem vollständigen Mitarbeitenden- und IT-Betriebszyklus:

- Onboarding
- Offboarding
- Reboarding
- Jobwechsel / Abteilungswechsel / Standortwechsel
- Rechte- und Gruppenmanagement
- Lizenz- und Postfachverwaltung
- Telefonie- und Kommunikationssysteme
- Geräte-, Asset- und Software-Prozesse
- Standard-Adminaufgaben und Wartungsjobs
- Reporting, Audit, Compliance und Nachvollziehbarkeit

## Empfohlene technische Richtung

Für den geplanten Zielbetrieb auf **Windows Server + IIS + Python 3.13 + RSAT** ist die sinnvollste GUI **keine lokale Desktop-GUI**, sondern eine **webbasierte Admin-Oberfläche**.

### Bevorzugter Stack

- **Frontend / GUI:** serverseitiges Web-UI mit `FastAPI`, `Jinja2`, `HTMX`, `Bootstrap 5` oder Fluent-inspiriertem Design
- **Hosting:** IIS als Reverse Proxy vor einem lokalen Python-Service
- **Backend-Orchestrierung:** Python 3.13
- **Automations-Layer:** PowerShell 5.1-Skripte für AD/RSAT-nahe Operationen, optional PowerShell 7 für nicht-RSAT-spezifische Jobs
- **Datenspeicherung:** zunächst SQLite oder SQL Server Express, später optional vollwertiger SQL Server
- **Authentifizierung:** IIS Windows Authentication + rollenbasierte Freigaben über AD-Gruppen
- **Secrets:** DPAPI / Windows Credential Manager / geschützte Secret-Backends

## Warum diese Richtung?

### Vorteile gegenüber einer reinen lokalen GUI

- mehrere Admins können parallel arbeiten
- sauberer Betrieb unter IIS möglich
- einfacher Rollout im Rechenzentrum
- zentrale Protokollierung und Rechtevergabe
- bessere Eignung für Workflows, Freigaben und Hintergrundjobs
- einfachere spätere Erweiterung um REST-Schnittstellen

### Warum PowerShell 5.1 weiterhin Pflicht bleibt

Da viele Windows-/RSAT-/Active-Directory-nahe Vorgänge auf Windows Server 2016+ mit **PowerShell 5.1** am stabilsten laufen, sollte V2 diese Ebene gezielt weiterverwenden.
Python übernimmt also primär:

- GUI
- Workflow-Orchestrierung
- Datenhaltung
- API
- Queue / Job-Management
- Audit und Reporting

PowerShell übernimmt primär:

- AD DS
- RSAT-Aktionen
- Exchange-/Hybrid-nahe Aufgaben
- Dateiserver-/NTFS-/SMB-Aufgaben
- Systemnahe Windows-Administration

## Zielgruppen

- IT-Administration
- Helpdesk / 1st- und 2nd-Level-Support
- IT-Operations
- IAM / Identity-Management
- HR-nahe IT-Prozesse
- Teamleitungen mit eingeschränkten Freigaberechten
- externe Dienstleister mit delegiertem Zugriff

## Geplante Grundprinzipien

- modulare Architektur
- tenant-/mandantenfähige Konfiguration
- klare Trennung zwischen GUI, Orchestrierung und PowerShell-Aktionen
- vollständige Auditierbarkeit aller Änderungen
- Freigabeprozesse für kritische Aktionen
- wiederverwendbare Checklisten und Workflow-Vorlagen
- Import aus bestehenden INI-/CSV-basierten Altbeständen
- API- und Connector-fähiger Ausbau

## Leitende Betriebsprinzipien

Damit die Plattform im Alltag nicht nur „viel kann“, sondern auch zuverlässig administrierbar bleibt, gelten folgende Leitlinien:

- **Automation first, aber kontrolliert:** wiederkehrende Tätigkeiten sollen automatisiert sein, jedoch mit Dry-Run, Audit und Rollenkontext
- **Modular statt monolithisch:** neue Integrationen werden als Module ergänzt, nicht als Sondercode im Kernsystem
- **Windows-kompatibel vor fancy:** alles muss auf konservativen Windows-Server-Umgebungen robust betreibbar sein
- **Hybrid-fähig statt Cloud-Zwang:** lokale AD-/Fileserver-Szenarien bleiben gleichwertig neben M365-/Entra-Szenarien
- **Operator Experience:** Helpdesk und Admins sollen typische Aufgaben in wenigen Schritten sicher ausführen können
- **Freigabefähig:** sensible Änderungen müssen bei Bedarf durch definierte Approval-Stufen abgesichert werden

## Abgrenzung der ersten V2-Ausbaustufe

Die erste produktive V2 soll bewusst noch **kein allmächtiges Universum im Universum** werden. Für die frühe Ausbaustufe gelten daher folgende Grenzen:

### Nicht-Ziele von MVP / frühem produktiven Stand

- kein freier Workflow-Designer für beliebige Endanwender
- keine vollumfängliche CMDB als Ersatz für spezialisierte Asset-Systeme
- keine vollständige IAM-Suite mit SoD-Engine wie in Enterprise-Governance-Produkten
- keine sofortige Vollintegration sämtlicher Drittsysteme in der ersten Welle
- kein Ersatz für bestehende Ticketing-Systeme, sondern gezielte Anbindung

## Aktueller Lieferstand

Der Stand `0.1.0` ist eine **erste lokal lauffähige Vorschau** der neuen V2-Plattform.

### Bereits enthalten

- startbare FastAPI-Webanwendung
- Basisnavigation und Dashboard
- Benutzer-, Job- und Einstellungs-Vorschauseiten
- serverseitig validierte Dry-Run-Flows für Onboarding und Offboarding
- standardisierter JSON-Contract für spätere PowerShell-Runner
- lebende Dokumentation aus `/DOC`
- Doku-Suche, Kontext-Hilfe, Auto-Index und Markdown-Vorschau
- Python-Tests, Linting und Syntaxprüfung

### Noch nicht produktiv umgesetzt

- Windows Authentication
- AD-basierte Rollenprüfung
- persistente Jobs und Audit-Trails
- produktive AD-/M365-Connectoren
- echte Schreiboperationen in Zielsystemen

## Dokumentenübersicht

Die strategischen Planungs- und Konzeptdokumente liegen im Unterordner `PLAN/`:

- `PLAN/01_TODO_PLAN.md` – großer Umsetzungs- und Planungs-Backlog
- `PLAN/02_FEATURE_LIST.md` – vollständige Funktionssammlung
- `PLAN/03_MODULE_LIST.md` – Modul- und Connector-Katalog
- `PLAN/04_ASSET_LIST.md` – benötigte UI-, Report- und Medien-Assets
- `PLAN/05_SYSTEM_SPECS.md` – Zielplattform, technische Anforderungen und Betriebsrahmen
- `PLAN/06_ARCHITECTURE.md` – empfohlene Zielarchitektur und Projektstruktur
- `PLAN/07_WORKFLOWS_AND_USE_CASES.md` – End-to-End-Prozesse für Joiner, Mover, Leaver und IT-Aufgaben
- `PLAN/08_DATA_MODEL_AND_CONFIG.md` – Datenmodell, Konfiguration und Script-Verträge
- `PLAN/09_SECURITY_COMPLIANCE.md` – Sicherheits-, Freigabe- und Compliance-Rahmen
- `PLAN/10_GUI_UX_CONCEPT.md` – Navigations-, Seiten- und Bedienkonzept der Weboberfläche
- `PLAN/11_IMPLEMENTATION_ROADMAP.md` – konkrete Release-, Sprint- und Ausbauempfehlung
- `PLAN/12_RISKS_AND_DEPENDENCIES.md` – Risiko-, Abhängigkeits- und Entscheidungsregister

Die lebende, direkt in der GUI angezeigte Betriebs- und Benutzerdokumentation liegt in `DOC/`.

## Aktueller Implementierungsstand

Das Projekt enthält jetzt ein erstes technisches Grundgerüst:

- `pyproject.toml` für den Python-Stack
- `app/` mit FastAPI-Application-Factory, Lifespan, modularen Routern und Templates
- `app/static/` mit CSS- und JS-Basis
- `config/` mit ersten Beispielkonfigurationen
- `modules/manifests/` mit ersten Manifest-Stubs
- `modules/powershell/` mit einem PowerShell-Connector-Starter
- `workers/` als vorbereiteter Bereich für Hintergrundjobs
- `tests/python/` für erste Python-Tests

## Erste verfügbare GUI-Seiten

Nach dem Start sind aktuell als Foundation-GUI verfügbar:

- `/dashboard`
- `/users`
- `/processes/onboarding`
- `/processes/offboarding`
- `/jobs`
- `/settings`

## Schnellstart für die erste lauffähige Version

### Voraussetzungen

- Python gemäß Projektziel `>=3.13`
- PowerShell auf dem Entwicklungs- oder Administrationssystem
- optional lokale Einstellungen in `.env`

### Abhängigkeiten installieren

Normale Installation:

`./setup_dev.ps1`

Entwicklungsinstallation inklusive Test- und Linting-Werkzeugen:

`./setup_dev.ps1 -WithDevDependencies`

### Entwicklungsserver starten

`./run_dev.ps1`

Danach ist die Anwendung standardmäßig unter `http://127.0.0.1:8010` erreichbar.

### Verifikation

Folgende Prüfungen sind für den aktuellen Stand erfolgreich verifiziert:

- `pytest`
- `ruff check app tests`
- `python -m compileall app tests`

## Lokaler Start für Entwicklung

### Voraussetzungen

- Python 3.13
- installierte Python-Abhängigkeiten aus `pyproject.toml`
- optionale lokale Konfiguration in `.env`

### Schnellstart

Nutzen Sie zuerst das vorbereitete Setup-Skript und danach `run_dev.ps1` oder starten Sie die App mit Uvicorn.

Empfohlene Reihenfolge:

1. Abhängigkeiten installieren, z. B. mit `setup_dev.ps1`
2. Entwicklungsserver starten
3. Browser auf `http://127.0.0.1:8010` öffnen

### Entwicklungsinstallation

- Standard: `./setup_dev.ps1`
- mit Dev-Abhängigkeiten: `./setup_dev.ps1 -WithDevDependencies`

### Lokale Konfiguration

Für lokale Entwicklungswerte ist jetzt eine `.env` im Projektroot vorbereitet.
Sie wird automatisch über `pydantic-settings` eingelesen. Produktionswerte sollten später weiterhin über die Zielumgebung bzw. IIS-/Server-Konfiguration gesetzt werden.

### Qualitätssicherung

Nach Installation der Dev-Abhängigkeiten können die HTTP- und Template-Tests mit `pytest` ausgeführt werden.

## Nächste sinnvolle technische Schritte

1. lokale Jobpersistenz und Audit-Grundlage
2. produktiver PowerShell-Runner mit Exitcode-, Timeout- und Logging-Verhalten
3. Windows Authentication und AD-Rollenauflösung
4. erste echte AD-User-Suche
5. schrittweise Connector-Anbindung für AD- und M365-Kernprozesse

## Strategische Zielbilder der V2

### Zielbild 1 – Zentrale Admin-Arbeitsfläche

Die Plattform soll die tägliche Arbeitsfläche für wiederkehrende Admin-Aufgaben werden:

- Benutzer suchen
- Lifecycle-Prozesse starten
- Aufgaben verfolgen
- Fehler erkennen
- Reports erzeugen
- Änderungen nachvollziehen

### Zielbild 2 – Prozess-Hub für Joiner / Mover / Leaver

V2 soll nicht nur technische Aktionen ausführen, sondern organisatorische Prozessketten zusammenführen:

- Identität
- Berechtigungen
- Kommunikation
- Assets
- Dokumentation
- Freigaben

### Zielbild 3 – Brücke zwischen Python und PowerShell-Bestand

Die V2 soll den vorhandenen PowerShell-Bestand nicht entsorgen, sondern in ein kontrolliertes, modernes Portal überführen.

## Bereits aus Vorgängerversionen bestätigte Basis

Aus den bisherigen Ständen sind bereits gute inhaltliche Vorlagen vorhanden, die V2 übernehmen oder modernisieren sollte:

- AD-Benutzeranlage und Benutzer-Update
- Gruppen- und Lizenzzuweisung
- Reporting / PDF / HTML / CSV
- ADSync / M365-Sync-Anbindung
- CSV-Import
- Passwort-Generierung
- modulare Funktionen
- Asset- und Icon-basierte Benutzerführung
- Jira / Confluence / Intranet / Telefonie-nahe Touchpoints

## Nächste sinnvolle Ausbaustufe nach der Planung

1. Zielarchitektur und Verzeichnisstruktur finalisieren
2. Mockups / Navigationsstruktur definieren
3. Modul-Manifestformat festlegen
4. Python-Host + Job Runner + PowerShell Runner als Grundgerüst bauen
5. zuerst die Kernmodule `AD`, `Workflow`, `Audit`, `Offboarding`, `M365`, `Telefonie`, `Assets` umsetzen

## Ergebnis dieser Planungsphase

Der Ordner `V2.0.0` dient ab jetzt als **Masterplan** für die neue Plattformgeneration.
Nicht mehr nur „User anlegen“, sondern ein **universelles Admin-, Lifecycle- und Wartungstool** für Windows- und Microsoft-zentrierte IT-Umgebungen.
