# Erste lauffähige Version – Stand 0.1.0

Dieses Dokument beschreibt den Umfang der aktuell lauffähigen V2-Preview.

## Charakter des aktuellen Stands

Die Version `0.1.0` ist **kein produktiver Vollausbau**, sondern eine bewusst begrenzte, lokal startbare Vorschau mit echten GUI-Pfaden, serverseitiger Validierung und dokumentiertem Entwicklungsbetrieb.

## Bereits funktional vorhanden

- FastAPI-Webanwendung mit App-Factory und Lifespan
- Seiten für Dashboard, Benutzer, Onboarding, Offboarding, Dokumentation, Jobs und Einstellungen
- Dry-Run-Onboarding mit serverseitiger Formularvalidierung
- Dry-Run-Offboarding mit sensitiven Regelprüfungen
- produktiver PowerShell-Runner mit JSON-Verträgen, Exitcodes, Timeout und Logdateien
- SQLite-basierte Jobpersistenz light für lokale Pilotläufe
- echte AD-Benutzersuche als erster produktiver PowerShell-Connector
- lebende Dokumentation aus dem Verzeichnis `/DOC`
- Doku-Suche, Ordner-Auto-Index und Markdown-Vorschau
- Kontext-Hilfe-Links aus Modulen direkt in die Doku

## Was diese Version bewusst noch nicht tut

- keine produktiven Änderungen in AD, Exchange, Entra oder M365
- keine echte asynchrone Worker-Queue
- keine vollwertige Audit-Datenbank
- keine Windows Authentication
- keine Rollenprüfung gegen AD-Gruppen

## Zielgruppe dieser Preview

- Architektur- und UX-Abstimmung
- technische Grundlage für nächste Umsetzungswellen
- lokaler Entwickler- und Pilotvorbereitungsbetrieb
- frühe Sichtbarkeit für Helpdesk- und Admin-Feedback

## Empfohlener Startpfad

1. `./setup_dev.ps1 -WithDevDependencies`
2. `./run_dev.ps1`
3. Browser auf `http://127.0.0.1:8010`
4. zuerst `Dashboard`, `Onboarding`, `Offboarding` und `Dokumentation` prüfen

## Verifizierte Qualitätsbasis

Der aktuelle Stand wurde mit folgenden Prüfungen erfolgreich validiert:

- `pytest`
- `ruff check app tests`
- `python -m compileall app tests`

## Nächster technischer Sprung nach 0.1.0

- Windows Authentication
- AD-basierte Rollenprüfung
- weitere AD-Core-Funktionen wie Benutzer anlegen oder deaktivieren
- echte Audit-Ansichten auf Basis der vorhandenen Persistenz
- asynchrone Jobverarbeitung mit Worker-Modell
