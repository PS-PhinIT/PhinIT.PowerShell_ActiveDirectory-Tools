# Jobmonitor-Modul

Der `Jobmonitor` ist die spätere Betriebszentrale für Hintergrundjobs, Connector-Ausführungen und technische Nacharbeiten.

## Aktueller Stand

Der Bereich liest jetzt echte Jobdaten aus einer lokalen SQLite-Persistenz.

Aktuell sichtbar sind unter anderem:

- Dry-Run-Jobs aus Onboarding und Offboarding
- Runner-Aufrufe aus der AD-Benutzersuche
- Modul, Aktion, Status, Korrelations-ID und Exitcode
- Detailtext sowie technischer Zeitstempel

## Zielbild

Das Modul soll künftig folgende Informationen und Steuerungsmöglichkeiten liefern:

- Status aller Workflow- und Connector-Jobs
- Retry- und Eskalationsinformationen
- technische Fehlerdetails pro Ausführung
- Owner, Zuständigkeiten und betroffene Module
- Drilldown auf Korrelations-ID und Audit-Spur

## Relevanz für den Betrieb

Schon im aktuellen Pilotstand ist das Modul hilfreich für Incident-Triage, Nachverfolgung und die Vorbereitung späterer Audit- und Retry-Mechanismen.
