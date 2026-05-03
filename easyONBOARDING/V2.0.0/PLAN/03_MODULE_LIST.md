# V2.0.0 – Modul-Liste

## Ziel des Modulkonzepts

Jede größere Fachfunktion soll als eigenes, aktivierbares Modul geplant werden.
Ein Modul besteht idealerweise aus:

- UI-Bereich
- Python-Service-Schicht
- PowerShell- oder API-Connector
- Konfiguration
- Health Check
- Berechtigungsdefinition
- Audit-Events
- optionalen Reports / Templates / Aufgabenlisten

## A. Kernmodule der Plattform

| Modul | Zweck | Typische Aktionen | Priorität |
|---|---|---|---|
| Core.Auth | Anmeldung und Session | Windows Auth, Session-Handling, Rollenauflösung | Hoch |
| Core.RBAC | Rechte- und Rollensystem | Modulrechte, Aktionsrechte, Approval-Regeln | Hoch |
| Core.Config | Konfigurationsverwaltung | Mandanten, Module, Templates, Policies | Hoch |
| Core.Audit | Protokollierung | Audit-Trail, Diff-Logging, Export | Hoch |
| Core.Jobs | Job- und Queue-System | Async Jobs, Retries, Zeitplanung | Hoch |
| Core.RunnerPS51 | PowerShell-Runner 5.1 | Scriptstart, JSON I/O, Exitcode-Handling | Hoch |
| Core.Notifications | Benachrichtigungen | Mail, Teams, Webhook, Reminder | Mittel |
| Core.Reporting | Reporting-Engine | PDF, HTML, CSV, JSON | Hoch |
| Core.Templates | Template-Engine | Mail-Templates, Report-Templates, Checklisten | Mittel |
| Core.Health | Plattformzustand | Modulstatus, Abhängigkeitsprüfungen | Mittel |

## B. Identity- und Directory-Module

| Modul | Zweck | Typische Aktionen | Abhängigkeiten | Priorität |
|---|---|---|---|---|
| Identity.AD.Users | AD-Benutzerverwaltung | anlegen, ändern, deaktivieren, reaktivieren | RSAT AD | Hoch |
| Identity.AD.Groups | AD-Gruppenverwaltung | Gruppenpakete, Mitgliedschaften, Rezertifizierung | RSAT AD | Hoch |
| Identity.AD.OUs | OU-Management | Ziel-OUs, Vorlagen, Standortmapping | RSAT AD | Mittel |
| Identity.AD.Computers | Computerobjekte | suchen, deaktivieren, inaktiv melden | RSAT AD | Mittel |
| Identity.AD.Passwords | Passwortprozesse | Reset, Unlock, Policy-Check | RSAT AD | Hoch |
| Identity.AD.LAPS | LAPS-Funktionen | Passwort lesen, Rotation anstoßen | LAPS / RSAT | Mittel |
| Identity.AD.BitLocker | BitLocker-Wiederherstellung | Recovery Keys suchen/exportieren | RSAT / MBAM / AD | Mittel |
| Identity.AD.HomeFolders | Dateifreigaben | Homefolder anlegen, Rechte setzen, Übergaben | SMB / NTFS | Hoch |
| Identity.AD.ProfilePaths | Profilpfade | Terminalserver-/Profilpfade pflegen | Fileserver | Niedrig |
| Identity.AD.GPOHints | GPO-Hinweise | Zielrichtlinien / OU-Vererbung anzeigen | GPMC optional | Niedrig |

## C. Joiner / Mover / Leaver Fachmodule

| Modul | Zweck | Typische Aktionen | Priorität |
|---|---|---|---|
| Lifecycle.Onboarding | strukturierte Benutzeranlage | Wizard, Rollenpakete, Startdatum | Hoch |
| Lifecycle.Offboarding | Austrittsprozesse | Disable, Entzug, Übergaben, Report | Hoch |
| Lifecycle.Mover | Rollen-/Abteilungswechsel | Gruppen-/Lizenzdelta, Standortwechsel | Hoch |
| Lifecycle.Rehire | Reaktivierung | ehemaliges Konto prüfen, Rehire-Vorlage | Mittel |
| Lifecycle.Checklists | Aufgabenketten | Geräte, Telefonie, Doku, Freigaben | Hoch |
| Lifecycle.Approvals | Genehmigungen | Vier-Augen-Prinzip, Eskalation | Mittel |
| Lifecycle.BulkImport | Massenverarbeitung | CSV/Excel/API Import | Hoch |

## D. Microsoft- und Cloud-Module

| Modul | Zweck | Typische Aktionen | Abhängigkeiten | Priorität |
|---|---|---|---|---|
| Cloud.ADSync | ADSync / Entra Connect | Delta Sync, Full Sync, Health Check | ADSync Server | Hoch |
| Cloud.M365.Licensing | Lizenzverwaltung | zuweisen, entziehen, Reports | Graph API | Hoch |
| Cloud.Entra.Users | Entra-Benutzerstatus | Prüfen, ergänzende Cloud-Aktionen | Graph API | Hoch |
| Cloud.ExchangeOnline | Exchange Online | Mailbox, Aliase, Shared Mailbox | EXO / Graph | Hoch |
| Cloud.ExchangeOnPrem | Exchange On-Prem / Hybrid | RemoteMailbox, Hybrid-Fälle | Exchange Tools | Mittel |
| Cloud.Teams | Teams | Team-Mitgliedschaften, Policies | Graph / Teams PS | Mittel |
| Cloud.TeamsPhone | Teams Telefonie | Nummern, Policies, Voice Routing | Teams Voice | Mittel |
| Cloud.SharePoint | SharePoint | Site-Zugriff, Gruppen, Links | Graph / PnP | Mittel |
| Cloud.OneDrive | OneDrive | Übergaben, Zugriff, Offboarding | Graph | Mittel |
| Cloud.Intune | Geräteverwaltung | Compliance-Infos, Gerät zuordnen | Graph / Intune | Mittel |
| Cloud.Autopilot | Autopilot | Gerätezuordnung / Bereitstellung | Graph | Niedrig |
| Cloud.Defender | Sicherheitsstatus | Geräte- oder Benutzerstatus | Defender APIs | Niedrig |
| Cloud.Purview | Compliance-Hinweise | DLP / Governance-Readiness | Purview APIs | Niedrig |

## E. Telefonie- und UC-Module

| Modul | Zweck | Typische Aktionen | Integrationsart | Priorität |
|---|---|---|---|---|
| UC.3CX | 3CX-Verwaltung | Benutzer, Durchwahl, Gruppen, Voicemail | API / Script | Hoch |
| UC.STARFACE | STARFACE-Verwaltung | Benutzer, Nebenstellen, Gruppen | API / Script | Hoch |
| UC.TeamsPhone | Microsoft Teams Phone | Nummern, Voice Policies | Graph / Teams | Mittel |
| UC.CiscoWebexCalling | Webex Calling | User- und Calling-Prozesse | API | Niedrig |
| UC.Swyx | Swyx / Enreach | Nebenstellen, User, Deaktivierung | API / Script | Niedrig |
| UC.Unify | Unify / OpenScape | Benutzer- und Rufnummernlogik | API / CSV | Niedrig |
| UC.NFON | NFON | Nebenstellen, User, Rufprofile | API | Niedrig |
| UC.SIPGeneral | generische SIP-Telefonie | Rufnummernpools, Dokumentation | generisch | Mittel |

## F. Ticketing-, Doku- und Wissensmodule

| Modul | Zweck | Typische Aktionen | Priorität |
|---|---|---|---|
| ITSM.Jira | Jira Software | Issues erzeugen, Status lesen | Mittel |
| ITSM.JSM | Jira Service Management | Tickets anlegen, Worklogs, Status | Hoch |
| ITSM.Confluence | Wissensbasis | Seiten verlinken, Vorlagen öffnen | Mittel |
| ITSM.ServiceNow | Enterprise ITSM | Tickets / Catalog / Approvals | Mittel |
| ITSM.TOPdesk | TOPdesk | Meldungen, Assets, Aufgaben | Mittel |
| ITSM.Matrix42 | Matrix42 Service Management | Tickets und Assetbezug | Niedrig |
| ITSM.OTRS | OTRS / Znuny | Ticketanlage / Rückmeldung | Niedrig |
| ITSM.Freshservice | Freshservice | Service Requests | Niedrig |
| ITSM.GLPI | GLPI | Tickets und Assets | Niedrig |
| Knowledge.Intranet | Firmenintranet | Links, Hilfeseiten, Mitarbeiterportale | Mittel |

## G. HR-, ERP- und Import-Module

| Modul | Zweck | Typische Aktionen | Priorität |
|---|---|---|---|
| HR.CSVImport | Standard-CSV-Import | Joiner-/Leaver-Dateien einlesen | Hoch |
| HR.ExcelImport | Excel-Import | Fachbereichslisten verarbeiten | Mittel |
| HR.Personio | Personio-Schnittstelle | Mitarbeiterdaten / Events importieren | Mittel |
| HR.SAPHCM | SAP HCM | HR-Events / Stammdaten | Mittel |
| HR.DATEV | DATEV-nahe Mitarbeiterdaten | Stammdatenimport | Niedrig |
| HR.RESTGeneric | generischer HR-REST-Connector | Webhook / API Import | Mittel |
| HR.XMLDrop | XML-Dateiimport | Dateibasierte Importe | Niedrig |

## H. Asset-, Client- und Software-Module

| Modul | Zweck | Typische Aktionen | Priorität |
|---|---|---|---|
| Asset.Inventory | Inventarverwaltung | Geräte, Seriennummern, Status | Hoch |
| Asset.Handover | Übergabe / Rückgabe | Checklisten, PDF-Protokolle | Hoch |
| Asset.SoftwareCatalog | Softwarepakete | Rollenzuordnung, Paketkatalog | Mittel |
| Client.Intune | moderne Geräteverwaltung | Gerätestatus, Compliance | Mittel |
| Client.SCCM | MECM / SCCM | Softwarebereitstellung, Collections | Mittel |
| Client.PDQ | PDQ Deploy / Inventory | Pakete, Inventarinfos | Niedrig |
| Client.Opsi | opsi | Softwaredeployment / Inventar | Mittel |
| Client.Baramundi | Baramundi | Software / Geräte / Policies | Niedrig |
| Client.Empirum | Matrix42 Empirum | Clientmanagement | Niedrig |
| Client.Lansweeper | Discovery / Inventar | Assetdaten lesen | Niedrig |

## I. Infrastruktur- und Betriebs-Module

| Modul | Zweck | Typische Aktionen | Priorität |
|---|---|---|---|
| Infra.FileServer | Fileserver-Tasks | Shares, Berechtigungen, Übergaben | Hoch |
| Infra.PrintServer | Druckerprozesse | Zuweisungen / Dokumentation | Niedrig |
| Infra.DNSDHCP | Infrastrukturprüfungen | Basic Health Checks | Niedrig |
| Infra.RDS | Terminalserver-Prozesse | Profilpfade, Sammlungen, Rechte | Niedrig |
| Infra.VMware | vCenter / ESXi | Infoabfragen, VM-Zuordnungen | Niedrig |
| Infra.HyperV | Hyper-V | Grundoperationen / Inventar | Niedrig |
| Infra.Veeam | Backup-bezogene Aufgaben | Status / Offboarding-Sicherung | Niedrig |
| Infra.PKI | Zertifikate | Ablaufprüfungen, Vorwarnungen | Mittel |
| Infra.VPN | VPN-Accounts | Berechtigungen, Gruppen, Offboarding | Mittel |

## J. Sicherheits- und Compliance-Module

| Modul | Zweck | Typische Aktionen | Priorität |
|---|---|---|---|
| Sec.MFA | MFA-Status | prüfen, Erinnerungen, Basiskontrolle | Mittel |
| Sec.AdminRights | privilegierte Rechte | Audits, Rezertifizierung | Hoch |
| Sec.GroupRecertification | Gruppenrezertifizierung | Owner-Prüfung, Review-Zyklen | Mittel |
| Sec.AccountReview | Benutzerreview | Externe, Inaktive, Ausnahmen | Hoch |
| Sec.SecretStore | Geheimnisverwaltung | DPAPI, Credential Store, Rotation | Hoch |
| Sec.ScriptSigning | Signierungskette | PowerShell-Signing und Trust | Hoch |
| Sec.ComplianceExport | Nachweise | Audit-Export, Nachvollziehbarkeit | Mittel |

## K. Spezial-/Kundenmodule und Erweiterbarkeit

| Modul | Zweck | Beispiel |
|---|---|---|
| Custom.M354Sync | kundenspezifische Synchronisation | falls intern vorhandenes System „M354Sync“ oder gleichnamiger Prozess existiert |
| Custom.LOBAppConnector | Fachanwendungsanbindung | ERP, CRM, Branchensoftware |
| Custom.WebhookActions | Webhook-Bausteine | Prozessstart durch Drittsystem |
| Custom.ScriptBundle | kundenspezifische PS-Skripte | Legacy-Skripte kontrolliert einbinden |
| Custom.ReportPack | Sonderberichte | Management- oder Audit-Reports |

## Priorisierte erste Modulwelle

### Welle 1
- Core.Auth
- Core.RBAC
- Core.Audit
- Core.Jobs
- Core.RunnerPS51
- Lifecycle.Onboarding
- Lifecycle.Offboarding
- Lifecycle.Mover
- Identity.AD.Users
- Identity.AD.Groups
- Cloud.ADSync
- Cloud.M365.Licensing
- Cloud.ExchangeOnline
- Asset.Handover

### Welle 2
- UC.3CX
- UC.STARFACE
- ITSM.JSM
- ITSM.Confluence
- Identity.AD.LAPS
- Identity.AD.BitLocker
- Infra.FileServer
- Cloud.OneDrive
- Cloud.SharePoint
- Sec.AdminRights

### Welle 3
- HR.Personio
- Client.Intune
- Client.Opsi
- ServiceNow / TOPdesk
- MFA / Compliance / Rezertifizierung

## Modul-Lebenszyklus und Reifegrade

Jedes Modul sollte zusätzlich einen fachlichen und technischen Reifegrad besitzen.

| Status | Bedeutung |
|---|---|
| Planned | fachlich geplant, noch nicht technisch umgesetzt |
| Prototype | Grundfunktion vorhanden, noch nicht produktionsreif |
| Pilot | im Testbetrieb mit begrenztem Scope |
| Productive | produktiv freigegeben |
| Restricted | nur für bestimmte Tenants / Sonderkunden |
| Deprecated | abgekündigt, Ersatz vorgesehen |
| Retired | nicht mehr nutzbar |

## Mindestangaben pro Modulmanifest

Jedes Modulmanifest sollte mindestens folgende Informationen enthalten:

- Modulname und interne ID
- semantische Version
- Fachkategorie
- Owner / verantwortliches Team
- Zielsysteme und technische Voraussetzungen
- benötigte Rechte und Secrets
- unterstützte Aktionen
- UI-Sichtbarkeit / Navigationsbereich
- Health-Check-Definition
- Audit-Kategorien
- Fallback-/Fehlerverhalten
- Abhängigkeiten zu anderen Modulen

## Empfohlene Modulabhängigkeiten

### Typische harte Abhängigkeiten
- `Lifecycle.Onboarding` → `Identity.AD.Users`
- `Lifecycle.Offboarding` → `Identity.AD.Users`
- `Cloud.M365.Licensing` → `Core.Auth`, `Core.Audit`, `Core.Jobs`
- `Cloud.ExchangeOnline` → `Cloud.Entra.Users` oder Tenant-/Identity-Kontext
- ``Lifecycle.Checklists`, `Core.Notifications`

### Typische optionale Abhängigkeiten
- `Asset.Handover` → `ITSM.JSM` oder anderes Ticketmodul
- `Cloud.OneDrive` → `Lifecycle.Offboarding`
- `Sec.GroupRecertification` → `Identity.AD.Groups`
- `Knowledge.Intranet` → `Core.Templates`

## Weitere sinnvolle Modulklassen für späteren Ausbau

| Modul | Zweck | Priorität |
|---|---|---|
| Core.Search | globale Suche über Personen, Gruppen, Assets, Tickets | Mittel |
| Core.ApprovalEngine | zentrale Freigabe- und Eskalationslogik | Hoch |
| Core.Retention | Lösch- und Aufbewahrungsregeln | Mittel |
| Identity.Passwordless | FIDO2 / Passkeys / Passwordless Readiness | Niedrig |
| Infra.CertificateStore | Zertifikats- und Ablaufübersicht | Mittel |
| Infra.MailRelay | Benachrichtigungs- und SMTP-Management | Niedrig |
| ITSM.WebhookBridge | generische Ticket-/Webhook-Brücke | Mittel |
| Reporting.KPI | Management- und KPI-Auswertungen | Mittel |

## Empfehlungen für Modulgrenzen

- keine Fachlogik im UI verstecken
- keine direkten Abhängigkeiten vom Frontend auf Legacy-Skripte
- keine Secrets im Modulcode hinterlegen
- je Modul klarer JSON-Input und JSON-Output
- Fehlertexte fachlich verständlich und technisch protokollierbar halten
