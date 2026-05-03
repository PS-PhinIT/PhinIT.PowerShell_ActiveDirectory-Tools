# V2.0.0 – Asset-Liste

## Ziel der Asset-Planung

Die V2 soll nicht nur funktional, sondern auch visuell und dokumentarisch konsistent sein.
Dafür werden **UI-Assets**, **Branding-Assets**, **Report-Assets**, **Workflow-Assets** und **Test-/Demo-Assets** benötigt.

## 1. Bereits erkennbare Alt-Assets aus dem Bestand

Aus den vorhandenen Versionen existieren bereits sinnvolle thematische Asset-Kategorien, die als Vorlage dienen können:

- Onboarding-Headerbilder
- Icons für `Jira`, `Confluence`, `Intranet`, `SharePoint`, `Telefonanlage`
- Symbole für `Upload`, `Suche`, `PDF`, `Info`, `FAQ`
- Branding-Varianten von `PHINIT easyONBOARDING`
- QR-Codes für Android / Apple / App-Downloads
- Bilder für Mitarbeiter-Welcome-Dokumente
- Assets für AD-Update, Passwort, Software, M365, Support

## 2. Branding-Assets

- Primärlogo `easyONBOARDING`
- Sublogos für Module
- Favicon für Weboberfläche
- kompaktes Headerlogo
- monochrome Logo-Varianten
- dunkle / helle Logo-Varianten
- Splash-/Login-Grafik
- Firmen-/Mandantenlogos pro Tenant
- Wasserzeichen für Reports
- Print-Logo für PDF-Dokumente

## 3. Navigations- und UI-Icons

### Kernnavigation
- Dashboard
- Benutzer
- Onboarding
- Offboarding
- Rollenwechsel
- Gruppen
- Lizenzen
- M365
- Exchange
- Teams
- Telefonie
- Assets
- Tickets
- Reports
- Einstellungen
- Audit
- Jobs
- Health

### Aktionsicons
- Anlegen
- Bearbeiten
- Deaktivieren
- Reaktivieren
- Löschen
- Suchen
- Importieren
- Exportieren
- Synchronisieren
- Starten
- Stoppen
- Bestätigen
- Warnung
- Fehler
- Erfolg
- Info
- Download
- Upload
- PDF
- CSV
- Excel
- Drucken

## 4. Modul- und Connector-Assets

Für jedes größere Integrationsmodul sollte ein eigenes Erkennungssymbol vorgesehen werden:

- Active Directory
- Entra ID
- Exchange Online
- Exchange On-Prem
- Microsoft 365
- Teams
- Teams Phone
- SharePoint
- OneDrive
- Intune
- ADSync / Entra Connect
- 3CX
- STARFACE
- Jira
- Jira Service Management
- Confluence
- ServiceNow
- TOPdesk
- Personio
- SAP
- DATEV
- Fileserver
- LAPS
- BitLocker
- VPN
- SCCM
- opsi
- Baramundi
- Veeam
- VMware
- Hyper-V

## 5. Workflow-Assets

- Wizard-Step-Icons für Joiner / Mover / Leaver
- Rollenpaket-Symbole
- Freigabe-Symbole
- Wiedervorlage-Symbole
- Fristen- und SLA-Badges
- Checklisten-Indikatoren
- Prioritätskennzeichen
- Risiko-/Kritikalitätskennzeichen
- Tenant-/Standortkennzeichen
- Prozessstatusleisten

## 6. Report- und Dokument-Assets

- HTML-Report-Template
- PDF-Report-Template
- Mitarbeiter-Welcome-Template
- Offboarding-Abschlussbericht
- Geräte-Übergabeprotokoll
- Geräte-Rückgabeprotokoll
- Freigabeprotokoll
- Lizenzübersicht
- Gruppenmitgliedschaftsbericht
- Audit-Zusammenfassung
- Management-KPI-Template
- QR-Code-Slots für Portale / App-Downloads / Helpdesk

## 7. Kommunikations-Assets

- E-Mail-Templates für Onboarding
- E-Mail-Templates für Offboarding
- Freigabe-Anfragen
- Erinnerungen an Geräte-Rückgabe
- Passwort-Reset-Benachrichtigungen
- Lizenzfreigabe-Benachrichtigungen
- Vorab-Info an Führungskräfte
- Ticket-Bestätigungen
- Fehler- und Eskalationsmails
- Vorlagen für Teams-/Webhook-Nachrichten

## 8. Inhalts- und Hilfemedien

- FAQ-Illustrationen
- Tooltips / Inline-Hilfe-Icons
- Screenshots für Doku
- Mockups für Navigationskonzept
- Hilfegrafiken für Telefonie und Geräteübergabe
- Prozessgrafiken für Onboarding / Offboarding
- Architekturdiagramme
- Legenden für Berichte
- Schulungsunterlagen / GIFs / kurze Screencasts (optional)

## 9. Test-, Demo- und Seed-Assets

- Demo-Firmendaten
- Demo-Benutzer
- Demo-Abteilungen
- Demo-Rollenpakete
- Demo-Standorte
- Demo-Gruppen und Lizenzpakete
- Beispiel-CSV-Dateien
- Test-Bilder / Platzhalterfotos
- Test-Dokumente für PDF-/HTML-Ausgabe
- Dummy-Tickets / Demo-Telefonieprofile

## 10. Empfohlene Zielstruktur

```text
V2.0.0/
  assets/
    branding/
    favicons/
    icons/
      core/
      modules/
      actions/
      status/
    illustrations/
    report-templates/
      html/
      pdf/
    mail-templates/
    screenshots/
    demo/
    qr/
```

## 11. Mindest-Asset-Set für MVP

### UI-MVP
- Logo
- Favicon
- Dashboard-Iconset
- Aktionsicons
- Statusicons
- Modulicons für AD / M365 / Offboarding / Tickets / Assets / Telefonie

### Report-MVP
- PDF-Basislayout
- HTML-Basislayout
- Welcome-Dokument-Basislayout
- Offboarding-Bericht-Basislayout

### Help-MVP
- Info-Symbole
- FAQ-Bereich
- leere Zustände („Noch keine Daten“, „Keine offenen Tasks“)

## 12. Design-Richtlinien

- klare, sachliche Enterprise-Optik
- gut lesbar auf Windows-Server-Adminsystemen
- hoher Kontrast
- drucktaugliche Berichtstemplates
- neutrale, professionelle Farbpalette
- Mandantenbranding optional übersteuerbar
- Icons konsistent zwischen Web, PDF und E-Mail verwenden

## 13. Zusätzliche Wunsch-Assets für später

- Standortkarten
- Organigramm-Grafiken
- animierte Prozessstatusanzeigen
- Admin-Startseiten-Widgets
- Mandantenfarbsets
- individuelle Telefonie-Provider-Icons
- QR-Starterpakete je Plattform

## 14. Technische Asset-Richtlinien

### Empfohlene Dateiformate
- `SVG` für Icons und einfache Vektorlogos
- `PNG` für UI-Bilder mit Transparenz
- `JPG` nur für große Hintergrund- oder Fotomotive
- `PDF` für druckfertige Dokumentvorlagen, sofern extern gepflegt

### Empfohlene Qualitätsstandards
- Web-Icons in mindestens 16, 24, 32 und 64 px vorsehen
- wichtige Modulgrafiken zusätzlich als hochauflösende Variante halten
- Print-/Report-Logos getrennt von Web-Logos pflegen
- transparente Hintergründe für wiederverwendbare UI-Grafiken bevorzugen

## 15. Barrierefreiheit und Bedienbarkeit

- Icons nie als alleinige Bedeutungsträger verwenden
- Farbzustände zusätzlich über Texte oder Badges unterstützen
- Kontraststarke Statusfarben vorsehen
- Reports auch in Graustufen lesbar halten
- klickbare UI-Elemente mit konsistenter Ikonografie gestalten

## 16. Asset-Ownership und Pflegeprozess

Für jedes wichtige Asset sollte geklärt sein:

- wer es fachlich verantwortet
- wo die Masterdatei liegt
- welche Formate exportiert werden
- ob Mandantenvarianten existieren
- wann Änderungen dokumentiert werden müssen

## 17. Produktions-Backlog für fehlende Assets

### Sofort sinnvoll
- einheitliches Dashboard-Set
- Modulicons für AD, M365, Ticketing, Telefonie, Assets, Security
- Statusbadges für `Open`, `Running`, `Blocked`, `Done`, `Failed`
- Layoutvorlagen für Welcome- und Offboarding-Berichte

### Danach sinnvoll
- Tenant-/Branding-Sets
- Freigabe- und Eskalationsgrafiken
- KPI-Karten und Diagrammthemen
- erklärende Prozessillustrationen

## 18. Lizenz- und Herkunftsdokumentation

Da Assets später eventuell aus verschiedenen Quellen stammen, sollte pro Asset dokumentiert werden:

- Quelle
- Nutzungsrecht / Lizenzstatus
- Bearbeitungsdatum
- interne Anpassungen
- zugehörige Zielkanäle (Web, PDF, Mail, Doku)
