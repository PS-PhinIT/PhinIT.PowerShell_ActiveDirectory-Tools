# JSON-Datenverträge

Dieses Dokument sammelt die wichtigsten JSON-Verträge der aktuellen V2-Basis.

## Web -> Orchestrierung

Die Weboberfläche erzeugt derzeit Dry-Run-Verträge für PowerShell- und spätere API-Connectoren.

## Vertragsbeispiel Onboarding

```json
{
  "module": "Lifecycle.Onboarding",
  "action": "prepare",
  "requested_by": "web-ui",
  "correlation_id": "ONB-ABCDEFG123",
  "dry_run": true,
  "payload": {
    "given_name": "Mara",
    "family_name": "Beispiel"
  }
}
```

## Vertragsbeispiel Offboarding

```json
{
  "module": "Lifecycle.Offboarding",
  "action": "prepare",
  "requested_by": "web-ui",
  "correlation_id": "OFF-ABCDEFG123",
  "dry_run": true,
  "payload": {
    "display_name": "Anna Beispiel"
  }
}
```

## Geplante Ergänzungen

- Job-Create-Response
- Connector-Result-Contract
- Audit-Event-Schema
- Task-/Checklist-Schema
