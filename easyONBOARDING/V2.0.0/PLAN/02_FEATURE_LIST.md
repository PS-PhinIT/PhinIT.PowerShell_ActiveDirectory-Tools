# V2.0.0 – Feature-Liste

## 1. Plattformweite Basisfunktionen

- rollenbasierte Anmeldung via Windows Authentication
- mandantenfähige Konfiguration
- mehrsprachige Oberfläche (DE zuerst, EN optional)
- zentrale Suche über Benutzer, Gruppen, Geräte, Assets und Tickets
- Aufgabenliste / Inbox / Freigabeübersicht
- Dashboard mit KPI-Kacheln
- Modulaktivierung per Konfiguration
- Jobhistorie und Wiederholung fehlgeschlagener Jobs
- Favoriten / Quick Actions / Admin-Shortcuts
- revisionssicheres Audit-Logging
- Export von Aktionen und Berichten
- Health-Check-Status pro Modul

## 2. Benutzer-Lifecycle

### Joiner / Onboarding
- Benutzeranlage aus Vorlage
- Benutzeranlage aus CSV / Excel / API / HR-Import
- vorgefertigte Rollenpakete
- Namensschema-Generator
- UPN-/SMTP-/Alias-Generator
- Manager- und Vertretungslogik
- Startdatum-Planung
- Preboarding-Modus
- Welcome-Paket mit Dokumenten und Links
- optionale Freigaben vor Anlage

### Mover / Änderungen
- Abteilungswechsel
- Rollenwechsel
- Standortwechsel
- Teamwechsel
- Kostenstellenwechsel
- Firmenwechsel / Domänenwechsel
- Anzeige-/Namensänderungen
- Lizenzwechsel
- Gruppenneuberechnung
- Telefonie-/Mailbox-Anpassung

### Leaver / Offboarding
- Terminierte Deaktivierung
- Sofortsperre / Emergency Disable
- Lizenzentzug
- Gruppenentzug
- Geräte- und Asset-Rückgabe-Checkliste
- Mailbox-Konvertierung / Weiterleitung / Delegation
- OneDrive-/Fileserver-Übergabe
- Teams-/Telefonie-Bereinigung
- Austrittsbericht
- Nachlauf-Tasks und Wiedervorlagen

### Rehire / Sonderfälle
- Reaktivierung ehemaliger Konten
- Saisonkräfte / Praktikanten / Freelancer
- befristete Konten mit Ablaufdatum
- Sammelkonten / Funktionskonten / Shared Identities
- VIP- / Sonderrollenprozesse

## 3. Active Directory und Entra Features

- Benutzer anlegen, ändern, deaktivieren, reaktivieren
- Gruppen hinzufügen/entfernen
- Gruppenpakete und Rollenprofile
- OU-Auswahl und OU-Vorlagen
- Homefolder / Profilpfade / Logonskripte
- Passwort setzen / zurücksetzen / entsperren
- Kennwortregeln prüfen
- LAPS lesen / rotieren
- BitLocker-Keys abrufen
- Computerobjekte suchen und prüfen
- AD-Attribute editieren
- ADSync / Entra Connect anstoßen und prüfen
- Entra ID / Azure AD Prüf- und Folgeaktionen

## 4. Microsoft 365 / Exchange / Collaboration

- Lizenzzuweisung und -entzug
- Lizenzpakete nach Rolle oder Abteilung
- Exchange Online Mailbox-Erstellung
- Shared Mailboxes anlegen / verwalten
- Mail-Aliase und ProxyAddresses verwalten
- Verteilerlisten und M365-Gruppen verwalten
- Teams-Berechtigungen und Team-Mitgliedschaften
- Teams Phone / Calling Policies / Rufnummern-Workflows
- OneDrive-Besitzerwechsel / Zugriff für Vorgesetzte
- SharePoint-Gruppen und Sites als Aufgaben im Workflow
- MFA-Readiness / Basisauswertung
- Mailweiterleitungen / Abwesenheitsregeln / Delegationen

## 5. Telefonie- und Kommunikationsfeatures

- 3CX-User anlegen / ändern / deaktivieren
- STARFACE-User anlegen / ändern / deaktivieren
- Durchwahl-Pools verwalten
- Rufnummern reservieren
- Queue-/Ringgruppen-Zuweisung
- Softphone-Freischaltung
- Mobil-App-Freigabe
- Voicemail aktivieren / zurücksetzen
- BLF-/Pickup-/Chef-Sekretariat-Szenarien
- Teams Phone und klassische Telefonanlage parallel abbilden

## 6. Asset-, Geräte- und Softwarefeatures

- Notebook-/Desktop-Zuweisung
- Smartphone-/Tablet-Zuweisung
- Monitor-/Docking-/Peripherie-Zuweisung
- Token-/Smartcard-/YubiKey-Zuweisung
- Inventarnummern erfassen
- Seriennummern erfassen
- Geräte-Rückgabe tracken
- Übergabeprotokolle erzeugen
- Softwarepakete nach Rolle bereitstellen
- Lizenzschlüssel / Portale / Zugangsinfos bündeln
- QR-Codes und Download-Links für Endnutzer bereitstellen

## 7. Allgemeine IT-Administration und Wartung

- Benutzer schnell suchen
- Gruppenmitgliedschaften vergleichen
- inaktive Benutzer erkennen
- inaktive Computer erkennen
- lokale Adminrechte-Audits
- offene Austritte prüfen
- Kennwortabläufe prüfen
- Zertifikatsabläufe prüfen
- Freigabeberechtigungen prüfen
- Homefolder-Struktur prüfen
- fehlende Pflichtattribute erkennen
- verwaiste Gruppen erkennen
- verwaiste Verteiler erkennen
- ungenutzte Lizenzen identifizieren
- offene Tickets je Benutzer anzeigen
- wiederkehrende Wartungsjobs planen

## 8. Ticketing, Doku und Collaboration Features

- Ticket automatisch erzeugen
- Ticket-Status zurückschreiben
- Confluence-/Wiki-Seiten als Hilfe verlinken
- Jira-/JSM-Integration
- ServiceNow-Integration
- TOPdesk-Integration
- GLPI-/OTRS-/Znuny-Anbindung
- Kommentare / Notizen / interne Übergaben
- Checklisten pro Prozessschritt
- Wissensdatenbank-Verlinkungen je Modul

## 9. HR- und Datenimport-Features

- CSV-Import
- Excel-Import
- REST-Import
- HR-Dateiexporte einlesen
- Validierung vor Ausführung
- Dublettenprüfung
- Vorschau vor Verarbeitung
- Fehlerlisten exportieren
- automatische Rollenpaketzuordnung anhand HR-Daten
- zeitgesteuerte Imports

## 10. Reporting und Nachweise

- Joiner-Report
- Leaver-Report
- Rollen- und Rechte-Report
- Lizenz-Report
- Telefonie-Report
- Asset-Übergabebericht
- PDF-Ausgabe
- HTML-Ausgabe
- CSV-/Excel-Export
- JSON-Export für Drittsysteme
- Compliance-Report
- Audit-Detailansicht

## 11. Workflow- und Freigabefunktionen

- Freigaben pro Aktion
- Vier-Augen-Prinzip
- Eskalationsstufen
- Wiedervorlagen
- Aufgabenketten / Checklisten
- automatische Folgejobs
- rückrollbare Teilprozesse
- Dry-Run / Simulation
- geplante Ausführung zu Datum/Uhrzeit
- manuelle Overrides mit Audit-Eintrag

## 12. UX-/GUI-Funktionen

- klares Kachel- oder Sidebar-Navigationskonzept
- Schnellaktionen auf dem Dashboard
- Dark-/Light-Mode optional
- konfigurierbare Firmenlogos und Modulicons
- Statusfarben und Badges
- Suchfilter und gespeicherte Ansichten
- mobile Lesbarkeit für Admin-Tablet optional
- Druckansicht für Reports
- Wizard-Ansichten für komplexe Prozesse
- Detailseiten für Benutzer / Gerät / Modul / Historie

## 13. Zukunftsoptionen

- Self-Service für Fachbereiche mit eingeschränkten Rechten
- Approval-App für Teamleiter
- API für externe Systeme
- Event/Webhook-basierte Automatisierung
- internes Marketplace-Konzept für Module
- Template-Builder für Rollenpakete
- Workflow-Designer
- Mandantenübergreifende Betriebsübersicht

## 14. Datei-, Rechte- und Fileservice-Features

- Homefolder anlegen / verschieben / archivieren
- SMB-Freigaben prüfen und dokumentieren
- NTFS-Rechte auf Teamverzeichnisse prüfen
- Zugriffspakete für Fileshares definieren
- persönliche Laufwerke im Offboarding übergeben
- Projektordner temporär freigeben und wieder entziehen
- Owner-/Verantwortlichenmodell für Freigaben
- Archiv- und Löschfristen für Benutzerordner abbilden

## 15. Delegation, Self-Service und eingeschränkte Bedienmodi

- Teamleiter darf Standard-Onboarding vorbereiten
- Fachbereich darf Rollenpaket beantragen
- Asset-Verantwortliche dürfen Geräteübergaben pflegen
- HR darf Eintritts- und Austrittsdaten importieren
- Auditoren sehen Reports und Historie nur lesend
- delegierte Admin-Views mit reduzierter Navigation
- gesperrte Aktionen mit klarer Freigabebegründung anzeigen

## 16. Sicherheits- und Sonderfall-Features

- Notfall-Sperrung von Konten
- VIP-Kennzeichnung mit Sonderprozess
- zeitlich befristete Rechte mit automatischem Entzug
- Review für privilegierte Gruppen
- MFA-/Passwordless-Readiness-Anzeige
- Auffälligkeiten bei Massenänderungen markieren
- Genehmigungspflicht bei externen Mailweiterleitungen
- Schutzmodus für Tier-0-/Admin-nahe Identitäten

## 17. API-, Webhook- und Automationsfeatures

- REST-Endpunkte für Workflow-Start
- Webhook-Empfang für HR-/Ticketing-Systeme
- Webhook-Ausgabe für Statusänderungen
- Import-/Export-API für Rollenpakete
- externe Trigger für Geräte- oder Ticketprozesse
- API-Schlüssel nur für freigegebene Maschinenkonten
- technische Events für Monitoring und SIEM nutzbar machen

## 18. Analyse-, KPI- und Controlling-Features

- durchschnittliche Onboarding-Dauer je Standort
- offene Offboarding-Aufgaben je Verantwortungsbereich
- Lizenzverbrauch nach Abteilung / Firma
- häufigste Fehlerursachen pro Modul
- inaktive Konten / Geräte nach Alterungsklasse
- SLA-Erfüllung bei Freigaben und Aufgaben
- Anzahl manueller Overrides je Zeitraum
- Trendberichte für Joiner / Mover / Leaver

## 19. Feature-Bündel für Release-Planung

| Feature-Bündel | Inhalt | Zielphase |
|---|---|---|
| Foundation Pack | Login, Rollen, Audit, Jobs, Basiskonfiguration | MVP 1 |
| Identity Pack | AD Users, Gruppen, Passwörter, Onboarding, Offboarding | MVP 2 |
| Collaboration Pack | M365, Exchange, Teams, SharePoint, OneDrive | MVP 3 |
| Operations Pack | Wartung, Reports, Health, Wiedervorlagen, ToDos | MVP 3 |
| Telephony Pack | 3CX, STARFACE, Teams Phone, Rufnummernlogik | MVP 4 |
| Integration Pack | Jira/JSM, Confluence, HR-Importe, Webhooks | MVP 4 |
| Governance Pack | Freigaben, Rezertifizierung, Compliance, Exporte | MVP 4+ |

## Priorisierungsempfehlung

### Muss in frühe V2
- Login / RBAC / Audit
- AD-Onboarding
- AD-Offboarding
- Mover-Prozesse
- M365-Lizenzen
- Reporting
- Aufgaben- und Checklistenmodell
- ADSync / Entra Sync

### Sollte früh folgen
- Exchange / Teams / SharePoint
- 3CX / STARFACE
- Asset- und Geräteverwaltung light
- Ticketing-Anbindung
- Health Checks / Wartungsjobs

### Kann später ausgebaut werden
- HR-API tief integriert
- Workflow-Designer
- mobile Begleitoberfläche
- Self-Service für Fachbereiche
