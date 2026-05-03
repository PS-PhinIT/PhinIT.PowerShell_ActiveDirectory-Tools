# PowerShell-Runner-Contract

Der PowerShell-Runner bildet die standardisierte Übergabeschicht zwischen Python-Weblogik und Windows-/AD-nahen Connectoren.

## Ziel

Jeder produktive Connector soll definierte Eingaben, definierte Ausgaben und auditierbare Korrelationen verwenden.

## Aktueller JSON-Grundvertrag

```json
{
  "module": "Lifecycle.Onboarding",
  "action": "prepare",
  "requested_by": "web-ui",
  "correlation_id": "ONB-ABCDEFG123",
  "dry_run": true,
  "payload": {}
}
```

## Pflichtfelder

| Feld | Bedeutung |
| --- | --- |
| `module` | fachliches Modul oder Zielsystem |
| `action` | angeforderte Operation |
| `requested_by` | aufrufender Kanal oder Benutzerkontext |
| `correlation_id` | technische Klammer für Logs und Audit |
| `dry_run` | trennt Vorschau von produktiver Ausführung |
| `payload` | fachliche Nutzdaten |

## Erwartete Connector-Ausgabe

Eine produktive Ausgabe sollte mindestens enthalten:

- `success`
- `message`
- `warnings`
- `errors`
- `data`
- `audit_delta`
- `follow_up_tasks`
- `duration_ms`

## Aktueller produktiver V2-Stand

Der Runner ist im aktuellen Stand nicht mehr nur ein Vertragsgenerator, sondern kann Connectoren bereits kontrolliert ausführen.

Aktuell umgesetzt sind:

- Aufruf kontrollierter PowerShell-Connectoren über `powershell.exe`
- Übergabe der Vertragsdaten über temporäre JSON-Dateien
- Erfassung von `stdout`, `stderr`, `exit_code` und Laufzeit
- Timeout-Behandlung mit vereinheitlichtem Fehlerbild
- Ablage von Logdateien im lokalen Datenverzeichnis
- Rückgabe eines normalisierten Ergebnisobjekts an Weblogik und Jobpersistenz

## Verbindung zur Jobpersistenz

Jeder relevante Runner-Aufruf kann im aktuellen Pilotstand in der SQLite-Jobpersistenz erfasst werden.

Damit stehen bereits erste Bausteine für folgende Betriebsfälle bereit:

- Nachvollziehen technischer Ausführungen
- Sichtbarkeit von Exitcodes und Fehlbildern
- Zuordnung über Korrelations-ID
- Vorbereitung späterer Audit- und Retry-Ansichten

## Technische Regeln

- PowerShell-Skripte werden nicht frei, sondern nur kontrolliert aufgerufen.
- JSON ist die Standard-Schnittstelle in beide Richtungen.
- Timeouts, Exitcodes und Fehlertexte müssen vereinheitlicht werden.
- Jeder Lauf braucht eine Korrelations-ID für spätere Audit-Nachweise.
