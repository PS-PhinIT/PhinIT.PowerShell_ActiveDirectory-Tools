# Modulreferenz – Core Foundation

Dieses Dokument beschreibt die aktuell sichtbaren Kernbausteine der Plattform.

## Zweck

`Core Foundation` umfasst alles, was unabhängig von Fachmodulen für den Betrieb der Webplattform nötig ist.

## Enthaltene Bausteine

- App-Factory und Lifespan
- zentrale Settings-Instanz
- Layout, Navigation und Template-Rendering
- Dashboard- und Basis-Webrouter
- vorbereiteter PowerShell-Runner-Contract
- Live-Dokumentation aus dem Dateisystem

## Reifegrad

| Baustein | Status |
| --- | --- |
| Web-App Start | produktiv startbar |
| Navigation | aktiv |
| Settings/.env | aktiv |
| Job-Backend | vorbereitet |
| Auth/RBAC | geplant |
| Audit-Persistenz | geplant |

## Sichtbare Grenzen des aktuellen Stands

- noch kein produktiver Login-/Rechtepfad
- noch keine echte Datenpersistenz für Jobs und Workflows
- Modulstatus und Health aktuell überwiegend als UI-/Planungsvorschau

## Nächster Ausbau

Die Foundation soll als nächstes um Jobpersistenz, echte Modulzustände und kontextbezogene Dokumentationsverlinkung erweitert werden.
