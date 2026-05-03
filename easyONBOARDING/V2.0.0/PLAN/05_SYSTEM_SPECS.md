# V2.0.0 – SystemSpecs-Liste

## 1. Zielplattform

Das System ist für **Windows-zentrierte IT-Umgebungen** vorgesehen.
Primäres Einsatzszenario:

- Windows Server mit IIS
- Python 3.13
- RSAT Tools
- PowerShell 5.1 als Ausführungsbasis für AD-nahe Aktionen
- optional PowerShell 7.x für moderne oder API-lastige Zusatzmodule

## 2. Unterstützte Zielsysteme

### Serverbetrieb
- Windows Server 2016
- Windows Server 2019
- Windows Server 2022

### Admin-Clients
- Windows 10
- Windows 11

### Browser
- Microsoft Edge (empfohlen)
- Google Chrome
- optional Firefox für reine Weboberfläche

## 3. Laufzeit- und Softwareanforderungen

### Pflicht
- Python 3.13.x
- Windows PowerShell 5.1
- IIS Web Server
- IIS Windows Authentication
- IIS URL Rewrite
- optional IIS Application Request Routing (ARR) für Reverse Proxy
- RSAT Active Directory Tools
- .NET Framework / Windows-Komponenten laut Serverstandard

### Optional je Modul
- Exchange Management Tools
- Microsoft Graph PowerShell / REST-Zugriffe
- Teams PowerShell Module
- PnP / SharePoint-bezogene Bibliotheken
- Telefonie-/Drittsystem-APIs
- SQL Server Express oder SQL Server Standard
- wkhtmltopdf / WeasyPrint / Playwright-basierte PDF-Erzeugung

## 4. Empfohlene Betriebsarchitektur

### Webschicht
- IIS übernimmt TLS, Windows Authentication und Reverse Proxy
- Python-Anwendung läuft als lokaler Dienst auf demselben Server oder App-Server
- Kommunikation lokal über `http://127.0.0.1:<port>`

### Backend-Schicht
- Python-Service für Web, API, Jobs, Audit und Orchestrierung
- separater Job Runner / Worker als Windows-Dienst
- PowerShell-Runner für RSAT-/AD-Aufgaben

### Persistenz
- Pilot / Einzelserver: SQLite
- kleine bis mittlere Produktion: SQL Server Express
- größere Produktion / Multi-Admin: SQL Server

## 5. Hardware-Empfehlungen

### Minimal für Pilot / Test
- 4 vCPU
- 8 GB RAM
- 80 GB SSD
- 1 Gbit Netzwerk

### Empfohlen für Produktion
- 8 vCPU
- 16 bis 32 GB RAM
- 150+ GB SSD
- getrennte Volumes für Logs, Daten, Reports und Backups
- 1 Gbit Netzwerk oder besser

### Für größere Umgebungen
- 8 bis 16 vCPU
- 32 GB RAM+
- SQL Server separat oder hochverfügbar
- dedizierter Worker für API-/Telefonie-/Reporting-lastige Jobs

## 6. Active-Directory- und Rechteanforderungen

- Leserechte auf relevante OUs, Benutzer, Gruppen und Computer
- Schreibrechte nur dort, wo wirklich benötigt
- getrennte technische Konten je Integrationsbereich empfohlen
- Dienstkonten für AD, M365, Ticketing und Telefonie möglichst trennen
- Zugriff auf Domain Controller nur über notwendige Schnittstellen
- JEA/JIT oder least privilege bevorzugen

## 7. PowerShell-Anforderungen

### PowerShell 5.1 – Pflichtpfad
Für folgende Aktionen bevorzugt/empfohlen:

- Active Directory
- RSAT
- Dateiserver / SMB / NTFS
- klassische Windows-Administration
- Exchange-Hybrid-/On-Prem-naher Betrieb

### PowerShell 7 – optionaler Zusatzpfad
Sinnvoll für:

- API-lastige Module
- moderne REST-Aufrufe
- Cross-Module-Utilities
- neue Reporting- oder Hilfsjobs

## 8. Python-Stack-Empfehlung

### Primärer Stack
- FastAPI
- Jinja2
- HTMX
- Bootstrap 5 oder Fluent-inspirierte Komponenten
- SQLModel oder SQLAlchemy
- Pydantic
- APScheduler oder eigener DB-basierter Jobplaner
- Uvicorn als App-Server

### Warum nicht zuerst React/Vue?
Für diese Admin-Plattform ist serverseitiges Rendering mit HTMX anfangs meist sinnvoller:

- schnellere Umsetzung
- weniger Frontend-Overhead
- einfacher auf Windows/IIS zu betreiben
- leichter für klassische Admin-Tools mit Formular- und Listenfokus

## 9. Sicherheitsanforderungen

- TLS intern und extern sauber absichern
- keine Klartext-Secrets in Dateien
- Audit-Logging für jede schreibende Aktion
- Rollen- und Berechtigungskontrolle pro Modul und Aktion
- Freigabe für kritische Workflows
- PowerShell-Skripte signieren
- Eingabevalidierung auf Python- und PowerShell-Seite
- Logs gegen Manipulation schützen
- Reports mit sensitiven Daten entsprechend absichern

## 10. Betriebs- und Monitoring-Anforderungen

- strukturierte Logs (App, Jobs, Connectoren, Audit)
- Health Checks pro Modul
- Dashboard für Fehler und Warnungen
- Mail- oder Teams-Benachrichtigungen bei Fehlern
- Überwachung von Diskspace, Zertifikaten und Queue-Stau
- Backup der Konfiguration und Datenbank
- Archivierung von Reports und Audit-Daten nach Policy

## 11. Kompatibilitätsrahmen

### Muss zwingend berücksichtigt werden
- Windows Server 2016 Basisbetrieb
- PowerShell 5.1 kompatible Script-Ausführung
- RSAT-abhängige AD-Funktionen
- Betrieb ohne Cloud-Zwang
- Hybrid-Szenarien unterstützbar

### Soll optional möglich sein
- paralleler Betrieb mit M365 / Entra / Exchange Online
- Multi-Company / Multi-Tenant
- Moduldeaktivierung ohne Codeänderung
- Anbindung externer APIs

## 12. Netzwerk- und Firewall-Anforderungen

Je nach Modul typischerweise:

- LDAP / LDAPS / Kerberos intern
- WinRM / PowerShell Remoting optional
- HTTPS zu M365 / Graph / Ticketing / Telefonie-APIs
- SMB-Zugriffe für Dateifreigaben
- SMTP optional für Benachrichtigungen
- SQL-Port intern bei externer DB

## 13. Dateisystem- und Verzeichnisanforderungen

Empfohlene Ordnerbereiche:

- `config/`
- `logs/`
- `data/`
- `reports/`
- `assets/`
- `scripts/powershell/`
- `modules/`
- `temp/`
- `backups/`

## 14. Nicht-funktionale Ziele

- schnelle Bedienbarkeit für Helpdesk und Admins
- hohe Nachvollziehbarkeit aller Änderungen
- geringe Einstiegshürde für neue Module
- robustes Verhalten bei API-/Netzwerkfehlern
- saubere Trennung von Anzeige, Workflow und Ausführung
- wartbarer Betrieb auch in konservativen Windows-Umgebungen

## 15. Empfehlung als Standard-Betriebsprofil

### Standardprofil V2
- IIS auf Windows Server 2019 oder 2022 bevorzugt
- Python 3.13
- FastAPI + Jinja2 + HTMX
- SQL Server Express oder SQL Server
- PowerShell 5.1 für Kernautomation
- Windows Authentication
- AD-Gruppenbasierte Rollensteuerung
- signierte PowerShell-Connectoren

## 16. Empfohlenes IIS-Betriebsprofil

### IIS-Rolle
- TLS-Terminierung
- Windows Authentication
- Reverse Proxy auf lokalen Python-Port
- zentrale Header-/Timeout-/Request-Size-Regeln

### Empfohlene Zusatzpunkte
- dedizierter App-Pool / getrennte Site für das Portal
- Request- und Idle-Timeouts passend für Admin-Workflows abstimmen
- großes Upload-Limit nur dort erlauben, wo CSV-/Excel-Import wirklich nötig ist
- Protokollierung von Zugriffslogs getrennt von Applikationslogs halten

## 17. Dienstkonten und technische Identitäten

Für einen sauberen Betrieb sollten technische Identitäten nach Integrationsbereich getrennt werden:

- Web-App-Identität
- Worker-/Job-Identität
- AD-/RSAT-nahe technische Identität
- M365-/Graph-bezogene Identität
- Ticketing-/Telefonie-bezogene API-Identitäten

### Empfehlung
- keine universelle Super-Identität für alles
- Rechte und Secrets je Connector trennen
- privilegierte Module nur mit explizit zugewiesenem technischen Kontext ausführen

## 18. Performance- und Reaktionsziele

### Zielwerte für typische UI-Aufrufe
- Dashboard-Aufruf: ideal unter 3 Sekunden
- Benutzersuche: ideal unter 2 Sekunden bei Index / Cache
- Start eines Workflows: sofortige Bestätigung unter 2 Sekunden
- langlaufende Aktionen: asynchron als Job mit Live-Status

### Zielwerte für Betriebsstabilität
- keine Blockierung der Weboberfläche durch langlaufende PowerShell-Aufgaben
- klare Zeitüberschreitungen je Connector
- Wiederholungsstrategien nur für idempotente Aktionen

## 19. Backup-, Restore- und Aufbewahrungsrahmen

- Konfigurationsdateien regelmäßig sichern
- Datenbank mit Audit- und Workflowdaten sichern
- Reports je nach Schutzklasse versioniert oder archiviert halten
- Wiederherstellung für Pilot und Produktion dokumentieren
- Restore-Test zyklisch prüfen, nicht nur theoretisch aufschreiben

## 20. Betriebsnahe Mindestpakete für Module

### AD-/Dateiserver-nahe Basis
- RSAT AD Module
- Netzpfade / SMB-Erreichbarkeit
- ggf. Remoting-Freigaben

### Microsoft-Cloud-Basis
- HTTPS-Zugriff auf relevante Microsoft-Endpunkte
- Graph-Berechtigungen
- definierte Tenant- und Lizenzkontexte

### Telefonie-Basis
- API-Zugriff oder Script-Endpunkte
- technische Accounts / Tokens
- Test- und Produktivprofile getrennt
