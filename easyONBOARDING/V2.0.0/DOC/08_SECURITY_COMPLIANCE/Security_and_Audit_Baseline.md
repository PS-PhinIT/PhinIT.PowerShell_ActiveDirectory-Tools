# Security- und Audit-Baseline

Dieses Dokument beschreibt den aktuell vorgesehenen Sicherheitsrahmen für `easyONBOARDING V2.0.0`.

## Grundprinzipien

- Rechteprüfung vor jeder schreibenden Aktion
- klare Trennung zwischen Dry-Run und produktiver Ausführung
- auditierbare Korrelations-IDs für Prozessläufe
- standardisierte Fehlerbilder ohne Secret-Leaks
- geplante Trennung von lesenden und schreibenden Berechtigungen

## Bereits im aktuellen Stand sichtbar

- serverseitige Validierung für sensible Lifecycle-Formulare
- korrelierbare Dry-Run-Verträge
- vorbereiteter Doku-Bereich für Betriebs- und Sicherheitswissen

## Noch offen für den produktiven Ausbau

- Windows Authentication und RBAC im Webfrontend
- persistente Audit-Trails
- Secret-Management für Connectoren
- Genehmigungs- und Vier-Augen-Prinzip für kritische Aktionen
- Code-Signing und Integritätsprüfung für produktive PowerShell-Connectoren

## Compliance-Richtung

Das System wird auf DSGVO-konforme Nachvollziehbarkeit, eingeschränkte Sichtbarkeit sensibler Daten und dokumentierte Aufbewahrungsregeln ausgerichtet.
