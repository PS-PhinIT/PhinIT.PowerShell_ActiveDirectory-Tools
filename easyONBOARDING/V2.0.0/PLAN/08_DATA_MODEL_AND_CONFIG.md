# V2.0.0 – Datenmodell und Konfigurationskonzept

## Ziel

Die Plattform braucht ein sauberes Datenmodell, damit Prozesse nicht nur „Skripte starten“, sondern fachlich nachvollziehbar werden.

## 1. Kernobjekte

### Person
Beschreibt die natürliche Person oder den externen Mitarbeitenden.

Beispieleigenschaften:
- Personalnummer
- Vorname / Nachname
- bevorzugter Name
- Eintrittsdatum / Austrittsdatum
- Beschäftigungsart
- Firma / Mandant
- Standort
- Abteilung
- Kostenstelle
- Manager
- Status

### Identity
Technische Identität einer Person.

Beispieleigenschaften:
- samAccountName
- UPN
- Primärmailadresse
- Alias-Adressen
- Tenant / Domäne
- AD-Status
- Entra-Status
- Kontotyp
- Aktiv von / bis

### AccessBundle
Bündelt Berechtigungen nach Rolle.

Beispieleigenschaften:
- Name
- Beschreibung
- Gruppenliste
- Lizenzliste
- Telefonieprofil
- Assetprofil
- Softwarepakete
- Genehmigungspflicht

### Asset
Gerät oder ausgegebenes Objekt.

Beispieleigenschaften:
- Asset-ID
- Typ
- Hersteller
- Modell
- Seriennummer
- Inventarnummer
- Status
- zugewiesen an
- Übergabedatum
- Rückgabedatum

### WorkflowInstance
Konkreter gestarteter Prozess.

Beispieleigenschaften:
- Workflowtyp
- Trigger
- Status
- Startzeit
- Endzeit
- Initiator
- Zielperson
- Korrelations-ID

### TaskItem
Einzelaufgabe innerhalb eines Workflows.

Beispieleigenschaften:
- Titel
- Kategorie
- Verantwortlicher
- Fälligkeitsdatum
- Status
- Freigabe erforderlich
- verknüpftes Modul

### AuditEvent
Protokolleintrag.

Beispieleigenschaften:
- Zeitstempel
- Benutzer
- Aktion
- Zielobjekt
- Modul
- Vorher/Nachher-Snapshot
- Ergebnis
- Job-ID
- Ticketreferenz

### Connector
Beschreibt ein Modul oder ein externes Zielsystem.

Beispieleigenschaften:
- Name
- Typ
- Version
- Aktiviert
- Health-Status
- Timeout
- Secret-Referenzen

## 2. Fachliche Beziehungen

- Eine `Person` kann mehrere `Identity`-Einträge haben
- Eine `Person` kann mehrere `Assets` besitzen
- Eine `WorkflowInstance` gehört meist zu genau einer `Person`
- Eine `WorkflowInstance` enthält viele `TaskItems`
- Ein `AccessBundle` kann in mehreren Workflows verwendet werden
- Ein `AuditEvent` referenziert Workflow, Job und Zielobjekt

## 3. Konfigurationsprinzip

Konfiguration soll **nicht** mehr nur in einer großen INI-Datei liegen.
Stattdessen:

- globale Systemkonfiguration
- Mandantenkonfiguration
- Modulkonfiguration
- Rollen- und Bundle-Definitionen
- Template-Konfiguration
- Connector-Definitionen
- Policy-Definitionen

## 4. Empfohlene Konfigurationsstruktur

```text
config/
  app.yaml
  security.yaml
  database.yaml
  tenants/
    default.yaml
    firma-a.yaml
  modules/
    ad.yaml
    m365.yaml
    exchange.yaml
    3cx.yaml
    starface.yaml
  bundles/
    roles.yaml
    licenses.yaml
    onboarding-packages.yaml
  templates/
    reports.yaml
    mails.yaml
  policies/
    approvals.yaml
    retention.yaml
    password.yaml
```

## 5. Legacy-Kompatibilität

Da bisher viel INI-basiert ist, sollte V2 zusätzlich bieten:

- INI-Import-Wizard
- Mapping alter INI-Sektionen auf neues Konfigurationsmodell
- Validierungsreport für migrierte Einstellungen
- Altbestand dokumentierbar übernehmen statt hart zu brechen

## 6. Script-Vertrag zwischen Python und PowerShell

Jeder Connector-Scriptlauf sollte einem festen Vertrag folgen.

### Eingabe
- `job_id`
- `correlation_id`
- `module`
- `action`
- `tenant`
- `requested_by`
- `payload`
- `dry_run`

### Ausgabe
- `success`
- `message`
- `warnings`
- `errors`
- `data`
- `audit_delta`
- `follow_up_tasks`
- `duration_ms`

## 7. Statusmodelle

### Workflowstatus
- Draft
- Validating
- WaitingApproval
- Running
- PartiallyCompleted
- Completed
- Failed
- Cancelled

### Taskstatus
- Open
- InProgress
- WaitingExternal
- Blocked
- Done
- Skipped
- Cancelled

### Benutzerstatus fachlich
- Preboarding
- Active
- OnLeave
- PendingOffboarding
- Disabled
- Archived
- Rehired

## 8. Bundle- und Paketmodell

### Rollenpakete können enthalten
- AD-Gruppen
- M365-Lizenzen
- Teams-/SharePoint-Zielzuweisungen
- Telefonieprofil
- Softwarepakete
- Asset-Standardprofil
- Prüf- und Freigabevorgaben

## 9. Audit-Delta-Konzept

Bei schreibenden Aktionen sollte gespeichert werden:

- alter Wert
- neuer Wert
- Quelle der Änderung
- fachlicher Grund
- Ticket / Genehmigung / Workflowbezug

## 10. Reporting-Datenmodell

Ein Report sollte nicht nur ein Dokument sein, sondern Metadaten besitzen:

- Reporttyp
- Zielperson
- Zeitraum
- generiert von
- generiert am
- Dateipfad oder Blob-Referenz
- Schutzklasse / Sichtbarkeit

## 11. Tenant- und Mehrfirmenmodell

### Tenant kann enthalten
- Firmenname
- AD-Domäne
- Maildomäne
- Branding
- OU-Mappings
- Rollenpakete
- Modulaktivierungen
- Ticketing-Ziele
- Telefonie-Mappings
- Reportvorlagen

## 12. Minimal notwendige Tabellen / Sammlungen

- users / persons
- identities
- workflows
- tasks
- audit_events
- connectors
- reports
- assets
- role_bundles
- module_settings
- tenant_settings
- approval_requests
- scheduled_jobs

## 13. Wichtige Modellregeln

- Personen- und technische Identitätsdaten trennen
- Bundle-Definitionen nicht hart in Skripte codieren
- Workflows und Tasks immer historisieren
- Externe Systemfehler dürfen die Historie nicht unbrauchbar machen
- Jede Aktion braucht eine Korrelations-ID

## 14. Benennungs- und Modellkonventionen

### Empfohlene Konventionen
- technische IDs stabil und sprachneutral halten
- Anzeigenamen dürfen benutzerfreundlich und tenantabhängig sein
- Statuswerte zentral definieren und nicht je Modul neu erfinden
- Bundle- und Modulnamen mit klaren Präfixen strukturieren

### Beispiele
- Rollenpaket: `role.sales.internal`
- Lizenzpaket: `license.m365.e3.standard`
- Workflowtyp: `workflow.offboarding.standard`
- Modul-ID: `cloud.exchange_online`

## 15. Beispiel für Rollen-/Bundle-Konfiguration

```yaml
bundleId: role.sales.internal
displayName: Vertrieb Standard intern
groups:
  - GRP-SALES-USERS
  - GRP-CRM-ACCESS
licenses:
  - M365_E3
  - POWER_BI_FREE
telephonyProfile: starface.standard
assetProfile: notebook.standard
requiresApproval: false
```

## 16. Import- und Mappingkonzept

Für CSV-/Excel-/HR-Importe sollte es definierte Mappingebenen geben:

- Quelldatenfelder
- Zielfelder im Fachmodell
- Transformationsregeln
- Validierungsregeln
- Defaultwerte
- Fehlerbehandlung pro Datensatz

### Beispielhafte Mappingfragen
- `Department` aus HR → Abteilung / Rollenpaket?
- `ManagerEmployeeId` → Manager-Identität per Lookup?
- `EmploymentType` → befristeter Workflow oder Standardprozess?

## 17. Versionierung von Konfiguration und Bundles

- Modulkonfiguration versionieren
- Rollenpakete versionieren
- Änderungen historisieren
- optional Vergleich zwischen alter und neuer Bundle-Version ermöglichen

## 18. Datenhaltungsregeln je Objektklasse

### Personen- und Identitätsdaten
- fachliche Daten und technische IDs getrennt verwalten
- Lösch- und Archivierungsregeln beachten

### Workflows und Tasks
- Historie nicht überschreiben
- Statuswechsel mit Zeitstempel dokumentieren

### Auditdaten
- append-only bevorzugen
- Sichtbarkeit nach Rolle einschränken

## 19. Erweiterungspunkt für tenantabhängige Defaults

Je Tenant oder Firma können Standardwerte definiert werden für:

- OU-Ziele
- Maildomänen
- DisplayName-Schemata
- Lizenzpakete
- Telefonieprofile
- Branding und Reports
