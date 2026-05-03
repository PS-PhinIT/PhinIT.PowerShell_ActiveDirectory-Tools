# V2.0.0 – Umfangreicher ToDo-Plan

## Leitidee

Die V2 wird als modulare Plattform geplant, die **Joiner / Mover / Leaver / IT-Operations / Wartung / Reporting / Integrationen** in einem einheitlichen Portal zusammenführt.

## Status-Update – 2026-05-03

### Bereits umgesetzt im aktuellen V2-Stand

- [x] Python-Webstack praktisch bestätigt (`FastAPI`, `Jinja2`, `HTMX`, `Pydantic Settings`)
- [x] startbare Web-App mit App-Factory und Lifespan aufgebaut
- [x] Basislayout, Navigation und Dashboard-Shell umgesetzt
- [x] Jobübersicht als erste GUI-Ansicht angelegt
- [x] standardisierter JSON-Contract zwischen Python und PowerShell-Runtime vorbereitet
- [x] zentrale Settings- und `.env`-Struktur eingeführt
- [x] zentrale Template- und Seitenrenderer-Struktur aufgebaut
- [x] validierte Onboarding-Maske als Dry-Run-Webflow umgesetzt
- [x] validierte Offboarding-Maske als Dry-Run-Webflow umgesetzt
- [x] lebende Dokumentation aus `/DOC` mit Unterordnern in die GUI integriert
- [x] Doku-Suche, Abschnitts-Index, Markdown-Vorschau und Kontext-Hilfe-Links eingebaut
- [x] Benutzer-, Job- und Einstellungsbereiche mit passender Modul-Dokumentation verknüpft
- [x] Start-, Betriebs- und GUI-Dokumentation für eine erste lauffähige Version ergänzt
- [x] SQLite-basierte Jobpersistenz light für lokale Pilotläufe eingebaut
- [x] produktiver PowerShell-Runner mit Exitcodes, Timeout, Logdateien und Fehlerbildern umgesetzt
- [x] erste echte AD-Core-Funktion als Benutzersuche über PowerShell-Connector umgesetzt
- [x] Testbasis mit `pytest`, `ruff` und Syntax-Prüfung etabliert

### Derzeit in Arbeit / nächster sinnvoller Ausbau

- [x] echte Job-Erzeugung statt nur Dry-Run-Verträge
- [x] Connector-Ausführung für PowerShell-Module produktiv anbinden
- [ ] Windows Authentication und AD-basierte Rollenprüfung integrieren
- [x] erste persistente Job-/Audit-Datenhaltung für lokale Pilotläufe anschließen
- [x] AD-Kernfunktion „Benutzer suchen“ von Vorschau auf echte Backend-Logik heben
- [ ] Modulstatus von „Gerüst“ auf „pilotierbare Kernfunktionen“ weiter anheben

### Aus der Planung abgeleitete kurzfristige Fokus-Sprints

- [x] Sprint 01 – Projektstruktur, Startpunkt und Webgerüst
- [x] Sprint 03 – Basislayout, Navigation, Dashboard-Shell
- [x] Sprint 04 – JSON-Contract und Runner-Vorbereitung
- [x] Sprint 07 – Onboarding-Wizard-Maske mit Rollenpaketauswahl als Dry-Run
- [x] Sprint 08 – Offboarding-Wizard-Maske mit Sicherheitsvalidierung als Dry-Run
- [x] Zusatz-Sprint – Live-Dokumentation, Kontext-Hilfe und First-Run-Dokumentation
- [x] nächster Sprint – Jobpersistenz, produktiver Runner und erste AD-Core-Funktion
- [ ] nächster Sprint – Windows Authentication, Rollenprüfung und AD-User-Detailansichten

## Phase 0 – Discovery, Konzeption und Altbestand

- [ ] Ist-Analyse aller Alt-Skripte in `easyONBOARDING`, `easyADGroups`, `easyADPW`, `easyBITKeys`, `easyLAPS`, `easyFolder`
- [ ] Wiederverwendbare PowerShell-Funktionen identifizieren
- [ ] Legacy-INI-Strukturen inventarisieren
- [ ] vorhandene Reports, Templates und Assets erfassen
- [ ] bestehende AD-/M365-/Exchange-Abhängigkeiten dokumentieren
- [ ] vorhandene GUI-Workflows aus WPF in Web-Workflows übersetzen
- [ ] Namenskonventionen für Module, Jobs, Workflows und Connectors definieren
- [ ] Rollenmodell festlegen: Helpdesk, Admin, Auditor, Teamlead, HR-Viewer, Freigabeinstanz
- [ ] Sicherheitsklassifikation für Aktionen festlegen
- [ ] Freigabepflichtige Aktionen markieren
- [ ] Datenschutz- und Protokollierungsanforderungen definieren
- [ ] Versions- und Release-Strategie für V2 festlegen

## Phase 1 – Architektur und Projektgrundgerüst

- [x] Python-Webstack final bestätigen
- [ ] IIS-Betriebsmodell festlegen
- [ ] Python-Service-Deployment unter Windows Service definieren
- [ ] Reverse-Proxy-Konfiguration für IIS planen
- [ ] Datenbank-Strategie festlegen (SQLite Pilot / SQL Server Produktion)
- [ ] Logging- und Audit-Architektur definieren
- [ ] Konfigurationsformat definieren (YAML/JSON + Legacy-INI-Import)
- [ ] Modul-Manifest-Schema definieren
- [ ] Job-/Queue-Konzept definieren
- [ ] Fehler- und Retry-Konzept definieren
- [ ] Secret-Handling definieren
- [ ] Mehrmandanten-/Mehrfirma-Support definieren
- [ ] Verzeichnisstruktur und Coding-Standards festlegen
- [ ] Teststrategie für Python und PowerShell festlegen
- [ ] Code-Signing-Strategie für PowerShell-Skripte festlegen

## Phase 2 – Core Plattform

- [ ] Login über Windows Authentication integrieren
- [ ] Rollen- und Rechteprüfung implementieren
- [x] Dashboard mit Statuskarten und offenen Aufgaben planen
- [ ] globales Suchkonzept für Benutzer, Gruppen, Geräte und Tickets definieren
- [ ] Benachrichtigungscenter planen
- [x] Aufgaben-/Jobübersicht planen
- [ ] Audit-Ansicht planen
- [ ] Fehler- und Health-Ansicht planen
- [ ] globale Konfiguration / Mandantenkonfiguration / Modulkonfiguration trennen
- [x] Script Runner für PowerShell 5.1 bauen
- [x] Standardisierte JSON-Ein-/Ausgabe zwischen Python und PowerShell definieren
- [ ] zentrale Validierungslogik aufbauen
- [ ] zentrale Template-Engine für E-Mail, PDF, HTML und Aufgabenlisten definieren
- [ ] API-Schicht für Module festlegen

## Phase 3 – Identity Lifecycle Kernprozesse

### Onboarding
- [ ] Einzel-Onboarding
- [ ] Bulk-Onboarding via CSV/Excel/API
- [ ] Vorlagen pro Abteilung / Rolle / Standort / Firma
- [ ] UPN-, Mail-, DisplayName- und SAM-Regelwerk
- [ ] Startdatum-basierte Aktivierung
- [ ] temporäre Benutzer / Praktikanten / Externe / Dienstleister
- [ ] Manager-Zuweisung
- [ ] Gruppenpakete / Rollenpakete / Lizenzpakete
- [ ] Willkommensdokumente generieren
- [ ] Mailbox-, Teams-, SharePoint- und Telefonie-Folgeschritte erzeugen

### Offboarding
- [ ] Soft-Offboarding mit Vorwarnstufe
- [ ] hartes Offboarding am Austrittsdatum
- [ ] AD-Account deaktivieren
- [ ] Passwort randomisieren
- [ ] Sitzungen / Tokens / Geräte prüfen
- [ ] Gruppen und Lizenzen entziehen
- [ ] Mailbox-Konvertierung / Forwarding / Shared Mailbox
- [ ] OneDrive-/Home-Laufwerk-/Mailbox-Übergabeprozess
- [ ] Ticket- und Asset-Rückgabe-Checkliste
- [ ] Revisionssicheren Abschlussbericht erzeugen

### Mover / Änderungsprozesse
- [ ] Abteilungswechsel
- [ ] Firmenwechsel / Tenantwechsel
- [ ] Standortwechsel
- [ ] Rollenwechsel
- [ ] Namensänderung
- [ ] Managerwechsel
- [ ] Lizenzwechsel
- [ ] Gruppenrezertifizierung
- [ ] Telefonie-/Durchwahlwechsel

## Phase 4 – AD, Entra, Exchange und Collaboration

- [ ] AD-User-Management
- [ ] AD-Group-Management
- [ ] OU- und Vorlagenlogik
- [ ] Passwort-Reset / Unlock / Ablauf prüfen
- [ ] LAPS-Integration
- [ ] BitLocker-Key-Abfrage
- [ ] ADSync / Entra Connect ansteuern
- [ ] Entra ID User-Lifecycle
- [ ] M365-Lizenzmanagement
- [ ] Exchange Online Mailbox-Prozesse
- [ ] Exchange On-Prem Hybrid-Szenarien
- [ ] Shared Mailboxes / Ressourcenpostfächer
- [ ] Teams / Teams Phone / Gruppen / Policies
- [ ] SharePoint / OneDrive Berechtigungen
- [ ] Verteilerlisten / Mailkontakte / Freigegebene Kalender

## Phase 5 – Telefonie und Kommunikationssysteme

- [ ] 3CX-Modul planen
- [ ] STARFACE-Modul planen
- [ ] Teams Phone-Modul planen
- [ ] Telefonanlagen-Zuweisung aus Rollenpaketen
- [ ] Durchwahl-Reservierung / Vergabe / Rücknahme
- [ ] Voicemail-Initialisierung
- [ ] Weiterleitungen / Pickup / Warteschlangen
- [ ] Softphone- und App-Zuweisung
- [ ] Telefonie-Offboarding-Prozesse
- [ ] Rufnummernreporting

## Phase 6 – IT-Wartung, ToDos und Administrationsaufgaben

- [ ] Health Checks für AD / DNS / DHCP / Fileserver / Printserver
- [ ] Wartungsjobs und Erinnerungen
- [ ] Zertifikatsabläufe prüfen
- [ ] Gruppen ohne Owner finden
- [ ] inaktive Benutzer erkennen
- [ ] inaktive Computer erkennen
- [ ] lokale Adminrechte prüfen
- [ ] MFA-Status auswerten
- [ ] Lizenz-Leichen aufräumen
- [ ] temporäre Zugriffe prüfen und widerrufen
- [ ] Verteiler- und Shared-Mailbox-Owner prüfen
- [ ] Homefolder-/NTFS-Rechte-Audits
- [ ] Ablaufdaten für Externe überwachen
- [ ] offene Offboarding-Aufgaben verfolgen

## Phase 7 – Ticketing, Doku und HR-Integration

- [ ] Jira/JSM-Anbindung
- [ ] Confluence-Anbindung
- [ ] ServiceNow-Anbindung
- [ ] TOPdesk-Anbindung
- [ ] Personio-Import
- [ ] CSV-/Excel-/HR-Imports
- [ ] Webhook-basierte Prozessstarts
- [ ] PDF-/HTML-/E-Mail-Templates harmonisieren
- [ ] Checklisten je Prozess und Fachbereich pflegen

## Phase 8 – Assets, Endgeräte, Software und Softwarepakete

- [ ] Asset-Erfassung pro Person
- [ ] Gerätezuweisung / Gerätewechsel / Rückgabe
- [ ] Notebook / Desktop / Smartphone / Tablet / Token / Smartcard
- [ ] Softwarepakete je Rolle definieren
- [ ] Paketzuweisung an SCCM / Intune / PDQ / opsi / Baramundi
- [ ] Seriennummern und Inventarnummern pflegen
- [ ] Übergabeprotokolle erzeugen
- [ ] QR-/Dokument-/Willkommenspakete erzeugen

## Phase 9 – Reporting, Audit und Compliance

- [ ] Audit-Trail je Aktion
- [ ] Dashboard für kritische Änderungen
- [ ] Joiner/Mover/Leaver-Reports
- [ ] Lizenznutzungsberichte
- [ ] Gruppenmitgliedschaftsberichte
- [ ] DSGVO-relevante Export- und Löschprozesse
- [ ] Rollen- und Rezertifizierungsreports
- [ ] PDF-Managementberichte
- [ ] CSV-/Excel-/JSON-Exporte

## Phase 10 – Qualität, Betrieb und Rollout

- [ ] Unit-Tests Python
- [ ] Pester-Tests PowerShell
- [ ] Testumgebung aufbauen
- [ ] Staging-Deployment dokumentieren
- [ ] Backup-/Restore-Verfahren definieren
- [ ] Monitoring und Alerting integrieren
- [ ] Betriebsdokumentation schreiben
- [ ] Admin-Handbuch erstellen
- [ ] Runbooks für Ausfälle dokumentieren
- [ ] Pilotgruppe definieren
- [ ] Rolloutplan je Standort/Firma definieren

## Phase 11 – Governance, Betriebsübergabe und Langzeitbetrieb

- [ ] Betriebsrollen und Verantwortlichkeiten definieren
- [ ] Ownership je Modul festlegen
- [ ] Freigabematrix dokumentieren
- [ ] Supportmodell (1st / 2nd / 3rd Level) beschreiben
- [ ] SLA-/Reaktionsmodelle definieren
- [ ] Datenaufbewahrung und Archivierung je Dokumenttyp definieren
- [ ] Rezertifizierungszyklen für Rollen und Gruppen festlegen
- [ ] Lizenz- und Vertragsabhängigkeiten dokumentieren
- [ ] Schulungsplan für Helpdesk und Fachadmins aufbauen
- [ ] Übergabe in Regelbetrieb vorbereiten

## Erste empfohlene Umsetzungssprints

### Sprint 01 – Technisches Grundgerüst
- [x] Projektstruktur, Linting, Build- und Startkonzept festlegen
- [x] Python Web-App-Startpunkt vorbereiten
- [ ] Windows-Service-/Worker-Modell festlegen

### Sprint 02 – Sicherheit und Login
- [ ] Windows Authentication und Rollenauflösung grob vorbereiten
- [ ] Audit-Korrelation und Request-IDs definieren
- [ ] Secret-Konzept technisch vorbereiten

### Sprint 03 – Core UI
- [x] Basislayout, Navigation, Dashboard-Shell
- [x] Modulnavigation und Statusbadges
- [ ] Fehler- und Leerseitenkonzept

### Sprint 04 – PowerShell Runner
- [x] JSON-Contract umsetzen
- [x] Job-Start, Exitcodes, Timeout-Handling
- [x] Logging und Korrelations-IDs im Runner

### Sprint 05 – AD User Kernfunktionen
- [x] Benutzer suchen
- [ ] Benutzer anlegen
- [ ] Benutzer deaktivieren

### Sprint 06 – Gruppen und Rollenpakete
- [ ] Gruppenpakete definieren
- [ ] Zuweisung und Vergleich
- [ ] Audit-Deltas für Gruppenänderungen

### Sprint 07 – Onboarding Wizard
- [x] Wizard-Maske
- [x] Rollenpaketauswahl
- [ ] Folgeaufgabenmodell

### Sprint 08 – Offboarding Wizard
- [x] Terminierte und sofortige Offboarding-Varianten
- [ ] Übergabe- und Rückgabe-Tasks
- [ ] Abschlussbericht-Grundlage

### Sprint 09 – Reporting und Historie
- [ ] Report-Grundlagen
- [x] Jobhistorie
- [ ] Audit-Ansichten

### Sprint 10 – M365 und ADSync
- [ ] ADSync-Connector
- [ ] Lizenzzuweisung
- [ ] Exchange-/Mailbox-Folgeschritte

### Sprint 11 – Telefonie und Tickets
- [ ] 3CX-/STARFACE-Basisintegration
- [ ] Ticketing-Trigger
- [ ] Verlinkte Aufgabenketten

### Sprint 12 – Pilot-Rollout
- [ ] Testdaten / Pilotmandant
- [ ] Betriebsdokumentation
- [ ] Pilotabnahme

## Priorisierte MVP-Reihenfolge

### MVP 1 – Plattformkern
- [ ] IIS + Python + Login + Rollen + Dashboard
- [x] Script Runner für PowerShell 5.1
- [ ] Audit-Logging
- [ ] Konfiguration / Mandantenfähigkeit light

### MVP 2 – User Lifecycle
- [ ] Onboarding
- [ ] Offboarding
- [ ] Mover
- [ ] Gruppen- und Lizenzpakete

### MVP 3 – Betriebsreife
- [ ] Reporting
- [ ] Wartungsjobs
- [ ] Benachrichtigungen
- [ ] Freigabe-Workflows

### MVP 4 – Connector-Ausbau
- [ ] M365 / Exchange / ADSync
- [ ] 3CX / STARFACE
- [ ] Jira / Confluence / Ticketing
- [ ] Asset- und Softwareverteilung

## Offene Architekturentscheidungen

- [ ] SQLite oder SQL Server als Standard?
- [ ] HTMX-first oder React/Vue für einzelne Module?
- [ ] kompletter Workflow-Designer oder feste Prozessvorlagen?
- [ ] Wie fein granuliert sollen PowerShell-Runner und Berechtigungen getrennt werden?
- [ ] Zentraler Service-Account oder modulabhängige technische Konten?
- [ ] Reine AD-Gruppensteuerung oder zusätzlich interne RBAC-Matrix?

## Abnahmekriterien der Planungsphase

- [x] Architektur dokumentiert
- [x] Feature-Katalog vollständig versioniert
- [x] Modul-Katalog vollständig versioniert
- [x] Systemanforderungen definiert
- [x] Sicherheitsrahmen dokumentiert
- [x] Datenmodell grob definiert
- [x] erste UI-Navigation festgelegt
- [x] Implementierungsreihenfolge priorisiert

## Definition of Done je Umsetzungsstufe

Ein Themenblock gilt erst dann als wirklich erledigt, wenn mindestens folgende Punkte erfüllt sind:

- fachliche Beschreibung ist dokumentiert
- Rechte- und Sicherheitsauswirkung ist bewertet
- UI-/Workflow-Verhalten ist beschrieben
- technische Abhängigkeiten sind bekannt
- Logging/Audit-Verhalten ist festgelegt
- Testfälle oder Prüfkriterien sind benannt
- offene Restpunkte sind explizit als späterer Ausbau markiert
