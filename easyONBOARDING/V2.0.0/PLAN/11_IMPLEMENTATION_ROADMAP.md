# V2.0.0 – Implementierungs-Roadmap

## Ziel der Roadmap

Dieses Dokument übersetzt den großen Backlog in eine realistische Ausbaureihenfolge.
Ziel ist ein **schrittweiser, produktionsnaher Aufbau** statt einer riesigen Einmal-Umsetzung.

## Status-Update – 2026-05-03

Der Roadmap-Stand wurde mit dem realen V2-Iststand abgeglichen.

### Bereits praktisch erreicht

- `Release 0.1 – Foundations` ist technisch im Projektstand angekommen
- eine **erste lauffähige Preview 0.1.0** ist lokal startbar und dokumentiert
- die GUI umfasst bereits `Dashboard`, `Benutzer`, `Onboarding`, `Offboarding`, `Dokumentation`, `Jobs` und `Einstellungen`
- Onboarding und Offboarding laufen aktuell als validierte Dry-Run-Webflows
- die Dokumentation wird live aus `/DOC` gelesen und bietet Suche, Kontext-Hilfe, Abschnitts-Index und Markdown-Vorschau
- Start- und Prüfpfade sind über `README.md`, `run_dev.ps1`, `setup_dev.ps1` und die Betriebsdoku beschrieben

### Nächster echter Ausbaukorridor

- Jobpersistenz und Audit-Speicherung
- produktiver PowerShell-Runner statt nur Contract-Vorbereitung
- Windows Authentication und rollenbasierte Zugriffskontrolle
- erste echte AD-Core-Funktion wie Benutzersuche

## 1. Grundstrategie

Die V2 sollte in klaren, testbaren Wellen entstehen:

1. Plattformkern
2. Identity Lifecycle
3. M365 und Collaboration
4. Telefonie und Integrationen
5. Governance und Betriebsreife

## 2. Empfohlene Release-Wellen

### Release 0.1 – Foundations
- Projektstruktur
- Startbare Web-App
- Basislayout
- Konfigurations- und Modulgrundlagen
- Jobmodell und Audit-Korrelation

**Iststand:** praktisch erreicht

### Release 0.1.1 – erste lauffähige Preview
- lokaler Entwicklungsstart über `setup_dev.ps1` und `run_dev.ps1`
- validierte Dry-Run-Flows für Onboarding und Offboarding
- lebende GUI-Dokumentation mit Suchfilter, Auto-Index und Vorschau
- verifizierte Tests, Linting und Syntax-Prüfung
- Betriebs- und Startdokumentation für Pilot- und Entwicklerbetrieb

**Iststand:** erreicht

### Release 0.2 – AD Core
- Benutzersuche
- AD-Anlage
- AD-Deaktivierung
- Gruppen-Grundfunktionen
- erster PowerShell-Runner produktiv nutzbar

### Release 0.3 – Lifecycle Core
- Onboarding Wizard
- Offboarding Wizard
- Mover Grundprozess
- Aufgabenketten und Folgetasks

### Release 0.4 – Reporting & Operations
- Jobmonitor
- Auditansichten
- erste Reports
- Health und Wartungsübersichten

### Release 0.5 – M365 Core
- ADSync / Entra Connect
- M365-Lizenzen
- Exchange-Folgeaktionen
- OneDrive-/SharePoint-bezogene Aufgaben

### Release 0.6 – Integrationen
- 3CX
- STARFACE
- Jira/JSM
- Confluence
- optionale HR-Importstrecken

### Release 1.0 – produktiver Erststand
- stabiler Plattformkern
- dokumentierte Betriebsprozesse
- Pilot-/Produktivbetrieb mit Kernmodulen
- Audit, Rollen, Reports und Freigaben in tragfähigem Stand

## 3. Empfohlene MVP-Definition

### MVP muss können
- Windows Login
- Rollenprüfung
- Benutzer suchen
- Onboarding starten
- Offboarding starten
- Gruppen-/Lizenzpakete anwenden
- Audit schreiben
- Folgeaufgaben anlegen
- Jobstatus anzeigen

### MVP sollte möglichst schon können
- ADSync anstoßen
- PDF-/HTML-Berichte erzeugen
- Ticketing-Aufgabe auslösen
- Asset-Rückgabe festhalten

## 4. Reihenfolge nach Risiko und Nutzen

### Zuerst
- alles, was Kernidentitäten betrifft
- alles, was Audit und Rechte absichert
- alles, was tägliche Helpdesk-Arbeit unmittelbar vereinfacht

### Danach
- M365- und Kommunikationsfolgen
- Asset- und Ticket-Anbindungen
- vertiefte Reports und Governance-Funktionen

### Später
- Spezialmodule
- seltene Drittsysteme
- umfassende Self-Service-Szenarien
- Workflow-Designer

## 5. Vorschlag für Implementierungsblöcke

### Block A – technische Fundamente
- App-Shell
- Config-Layer
- Runner
- Jobmodell
- Audit

### Block B – Benutzer-Lifecycle
- Person-/Identity-Modell
- Onboarding
- Offboarding
- Mover
- Checklisten

### Block C – Rechte und Pakete
- Gruppenpakete
- Lizenzpakete
- Delta-Berechnung
- Genehmigungspflichten

### Block D – Betriebsreife
- Monitoring
- Reports
- Fehlerbilder
- Wiederholbarkeit / Nacharbeit

## 6. Release-Kriterien je Welle

Jede Release-Welle sollte nur dann als abgeschlossen gelten, wenn:

- UI nutzbar ist
- Logs/Audit vorhanden sind
- Rechte sauber geprüft werden
- Fehlerfälle nachvollziehbar sind
- Testfälle dokumentiert oder automatisiert sind
- Betriebshinweise ergänzt wurden

## 7. Pilotstrategie

### Empfohlener Start
- ein Pilotmandant
- wenige Adminrollen
- wenige klar definierte Rollenpakete
- nur Kernmodule aktiv

### Danach
- echte Helpdesk- und IAM-Rückmeldungen einsammeln
- Prozesszeiten messen
- häufige Fehlerwege korrigieren
- zusätzliche Module nur nach Stabilität freischalten

## 8. Technische Schulden bewusst steuern

Nicht alles muss beim Start perfekt sein, aber offen bleiben soll es auch nicht.
Daher:

- bekannte Restpunkte dokumentieren
- technische Schulden priorisieren
- Sonderlogik pro Kunde möglichst einkapseln
- Legacy-Skripte schrittweise in Connectoren überführen

## 9. Erfolgskennzahlen für den Ausbau

- Zeit bis Benutzeranlage
- Zeit bis vollständiges Offboarding
- Anteil automatisierter Folgeaufgaben
- Anzahl manueller Nacharbeiten
- Anzahl Connector-Fehler pro Woche
- Durchlaufzeit genehmigungspflichtiger Prozesse

## 10. Empfehlung für den ersten echten Umsetzungsschritt

Der ursprüngliche erste Bauschritt aus der Planungsphase wurde bereits umgesetzt. Der sinnvollste **nächste** technische Schritt ist jetzt:

1. lokale Jobpersistenz für Webflows einführen
2. produktiven Runner mit Exitcode-, Timeout- und Logging-Handhabung anschließen
3. Windows Authentication und Rollenauflösung vorbereiten
4. echte Benutzersuche als ersten AD-Core-Anwendungsfall liefern
5. Audit-Ansichten und Jobhistorie für Pilotbetrieb sichtbar machen
