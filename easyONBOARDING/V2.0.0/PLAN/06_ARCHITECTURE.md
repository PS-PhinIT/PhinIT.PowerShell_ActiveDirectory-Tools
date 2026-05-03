# V2.0.0 – Zielarchitektur

## Architekturentscheidung

Für `easyONBOARDING V2.0.0` wird eine **webbasierte, modulare Mehrschicht-Architektur** empfohlen.

### Primärer Architekturansatz

1. **IIS** als Front Door
2. **Python 3.13 Webanwendung** als Portal- und API-Schicht
3. **Windows Service / Worker** für Hintergrundjobs
4. **PowerShell 5.1 Runner** für AD-/RSAT-/Windows-nahe Aktionen
5. **optionale API-Connectoren** für Cloud- und Drittsysteme
6. **DB-Schicht** für Konfiguration, Jobs, Audit, Checklisten und Reports

## Warum keine reine Desktop-GUI?

Da das Zielsystem unter **Windows Server + IIS** laufen soll, bietet eine Browser-GUI klare Vorteile:

- zentrale Bereitstellung
- kein Client-Rollout nötig
- mehrere Admins gleichzeitig möglich
- einfacher für Freigaben, Audit, Dashboards und Hintergrundprozesse
- besser geeignet für modulare Skalierung

## Schichtenmodell

## 1. Präsentationsschicht

### Bestandteile
- serverseitig gerenderte HTML-Seiten
- HTMX für partielle Aktualisierung
- Formular-Wizards für komplexe Prozesse
- Dashboards, Listen, Detailseiten und Job-Monitore

### Hauptbereiche der GUI
- Dashboard
- Benutzer / Identitäten
- Joiner / Mover / Leaver
- Gruppen / Rollen / Lizenzen
- Telefonie
- Assets / Geräte
- Tickets / Doku / Links
- Reports / Audit
- Jobs / Wartung / Health
- Einstellungen / Module / Mandanten

## 2. Applikationsschicht

### Aufgaben
- Request-Verarbeitung
- Rechteprüfung
- Validierung
- Workflow-Auswahl
- Job-Erstellung
- Modulrouting
- Antwortaufbereitung für UI und API

### Typische Services
- UserLifecycleService
- WorkflowService
- GroupAccessService
- LicenseService
- TelephonyService
- AssetService
- TicketService
- ReportingService
- AuditService
- HealthService

## 3. Orchestrierungs- und Workflow-Schicht

Diese Schicht entscheidet:

- welche Schritte für einen Prozess nötig sind
- in welcher Reihenfolge sie laufen
- welche Genehmigungen gebraucht werden
- welche Schritte synchron oder asynchron laufen
- wie Fehler behandelt oder kompensiert werden

### Beispiel Onboarding-Workflow

1. Personendaten validieren
2. Rollenpaket wählen
3. AD-Konto anlegen
4. Gruppen zuweisen
5. Lizenzpaket zuweisen
6. Mailbox vorbereiten
7. ADSync anstoßen
8. Telefonie-Aufgabe erzeugen
9. Asset-Aufgabe erzeugen
10. Welcome-Dokument erzeugen
11. Audit-Einträge schreiben

## 4. Integrations- und Ausführungsschicht

### Trennung der Ausführung

#### PowerShell-Connectoren
Für alles, was nah an Windows, AD und RSAT liegt:

- AD DS
- Gruppen
- LAPS
- BitLocker
- File- und NTFS-Rechte
- klassische Windows-Administration
- Exchange Hybrid / On-Prem

#### API-Connectoren
Für SaaS- und Drittsysteme:

- Microsoft Graph
- Teams / SharePoint / OneDrive
- Jira / Confluence / ServiceNow / TOPdesk
- 3CX / STARFACE
- HR-Systeme
- Inventarsysteme

## 5. Datenhaltung

### Fachliche Daten
- Personenstammdaten-Referenzen
- Workflowinstanzen
- Aufgaben / Checklisten
- Jobstatus
- Modulstatus
- Audit-Ereignisse
- Vorlagen / Policies / Konfigurationen
- Reports / Report-Metadaten

### Nicht in der Datenbank speichern
- Klartext-Secrets
- ungeschützte Zugangsdaten
- sensible Rohdaten ohne Schutzbedarfskonzept

## Komponentenübersicht

```text
[IIS + Windows Auth]
        |
        v
[Python Web App / FastAPI]
        |
        +--> [UI / Jinja2 / HTMX]
        +--> [REST API]
        +--> [Workflow Engine]
        +--> [Audit / Reporting]
        +--> [Config / RBAC]
        |
        v
[Job Queue / Worker Service]
        |
        +--> [PowerShell 5.1 Runner]
        +--> [PowerShell 7 Runner optional]
        +--> [API Connectors]
        |
        v
[AD / RSAT / M365 / Ticketing / Telefonie / Fileserver / SQL]
```

## Vorschlag für Projektstruktur

```text
V2.0.0/
  app/
    web/
    api/
    services/
    workflows/
    models/
    repositories/
    templates/
    static/
  workers/
  modules/
    manifests/
    python/
    powershell/
  config/
    tenants/
    modules/
    policies/
  data/
  reports/
  assets/
  docs/
  tests/
    python/
    powershell/
```

## Modulmanifest-Idee

Jedes Modul soll maschinenlesbar beschreiben:

- Name
- Version
- Kategorie
- sichtbare GUI-Bereiche
- benötigte Rechte
- benötigte Secrets
- benötigte Zielsysteme
- Health-Check-Methode
- unterstützte Aktionen
- Eingabe-/Ausgabe-Verträge

## Ausführungsmodell für PowerShell

### Prinzip
Python startet keine „freien“ Legacy-Skripte ohne Rahmen, sondern nur kontrollierte Connectoren.

### Vorgaben
- definierte Eingabe als JSON
- definierte Ausgabe als JSON
- standardisierte Exitcodes
- standardisierte Logs
- Timeouts
- Retry-Regeln
- Audit-Korrelation via `job_id` / `correlation_id`

## Security by Design

- RBAC auf Modul- und Aktionsebene
- Freigabe-Workflow für kritische Aktionen
- Secrets nur geschützt ablegen
- Code-Signing für PowerShell
- abgesicherte Fehlerausgaben ohne Secret-Leaks
- Eingaben doppelt validieren
- Trennung von lesenden und schreibenden Rechten

## UI-Navigationsvorschlag

### Hauptnavigation
- Start
- Benutzer
- Prozesse
- Zugriffe
- Kommunikation
- Assets
- Betrieb
- Reports
- Audit
- Administration

### Unterbereiche

#### Benutzer
- Suche
- Detailansicht
- Historie
- verknüpfte Konten

#### Prozesse
- Onboarding
- Offboarding
- Mover
- Rehire
- Bulk Import

#### Zugriffe
- Gruppen
- Rollenpakete
- Lizenzen
- Rezertifizierung

#### Kommunikation
- Exchange
- Teams
- 3CX
- STARFACE
- Portale / Links

#### Assets
- Geräte
- Übergaben
- Rückgaben
- Softwarepakete

#### Betrieb
- Jobs
- Wartung
- Health Checks
- offene ToDos

## Deployment-Empfehlung

### Startvariante
- Einzelserver
- IIS + Python App + Worker lokal
- SQLite oder SQL Express
- AD und APIs per Connector

### Ausbauvariante
- separater App-Server
- separater SQL Server
- optional mehrere Worker
- zentrale Secrets / Monitoring / HA-Konzepte

## API- und Seitenbereiche der Anwendung

### Webbereiche
- `/dashboard`
- `/users`
- `/workflows`
- `/groups`
- `/licenses`
- `/telephony`
- `/assets`
- `/reports`
- `/jobs`
- `/audit`
- `/settings`

### API-Bereiche
- `/api/workflows/*`
- `/api/jobs/*`
- `/api/modules/*`
- `/api/users/*`
- `/api/reports/*`
- `/api/health/*`

## Typischer Request-/Job-Lebenszyklus

1. Benutzer startet Aktion in der Weboberfläche
2. Web-App validiert Rechte, Pflichtdaten und Mandantenkontext
3. Workflow-Service zerlegt die Aktion in Schritte
4. kurzer synchroner Teil wird sofort beantwortet
5. schreibende oder langlaufende Schritte werden als Job eingeplant
6. Worker ruft Connectoren / Runner auf
7. Ergebnisse werden als Audit, Task, Status und Report-Metadaten zurückgeschrieben
8. UI aktualisiert den Status live oder per Polling/Refresh

## Fehler- und Fallback-Strategie

### Grundregeln
- UI darf bei Connectorfehlern nicht abstürzen
- Fachfehler und technische Fehler klar unterscheiden
- Teilfehler in Workflowketten explizit anzeigen
- manuelle Nacharbeit als Task erzeugen, wenn Automatik nicht sauber weiterkommt

### Beispiele
- M365-Lizenz fehlgeschlagen → AD-Anlage bleibt bestehen, Lizenz-Task wird als `Blocked` markiert
- Telefonie-API nicht erreichbar → Onboarding läuft weiter, Telefonie-Aufgabe bleibt offen
- Ticketing nicht verfügbar → Report wird trotzdem erzeugt, Ticket-Nachtrag wird nachgelagert

## Observability und Betriebsdiagnostik

Die Plattform sollte parallel mehrere Ebenen von Beobachtbarkeit anbieten:

- strukturierte App-Logs
- Worker-/Job-Logs
- Connector-Logs
- Audit-Logs
- Health-Endpunkte
- Admin-Dashboard mit Fehler- und Warnindikatoren

## Caching- und Performance-Grundsätze

- lesende Stammdaten können begrenzt gecacht werden
- Schreiboperationen dürfen nie mit veralteten Cache-Werten blind entscheiden
- Mandanten- und Rollenpakete eignen sich für gezielten In-Memory- oder DB-Cache
- Health- und Dashboard-Daten sollten aggregiert und nicht bei jedem Aufruf vollständig neu berechnet werden

## Architekturentscheidungen mit hoher Tragweite

- serverseitiges UI zuerst, SPA nur bei echtem Bedarf
- PowerShell 5.1 für RSAT-nahe Kernaufgaben beibehalten
- modulare Connectoren statt unkontrollierter Legacy-Skriptstarts
- asynchrones Jobmodell für alle potenziell langlaufenden Schritte

## Architekturgrundsätze

- zuerst stabil und betriebssicher, dann verspielt
- modulare Erweiterung ohne Umbau des Gesamtsystems
- klare Grenzen zwischen UI, Orchestrierung und Script-Ausführung
- Alt-Skripte nur über saubere Contracts einbinden
- Prozesse müssen auditierbar und nachvollziehbar bleiben
