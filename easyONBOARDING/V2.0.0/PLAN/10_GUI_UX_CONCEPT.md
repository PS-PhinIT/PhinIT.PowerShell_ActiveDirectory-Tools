# V2.0.0 – GUI- und UX-Konzept

## Zielbild der Oberfläche

Die Oberfläche soll wie ein **Admin-Portal** wirken, nicht wie eine Sammlung zufälliger Einzelformulare.
Wichtig sind daher:

- klare Hauptnavigation
- schnelle Standardaktionen
- wenig Klicks für häufige Aufgaben
- hohe Fehlertoleranz
- gute Sichtbarkeit von Status, Risiken und offenen ToDos

## 1. Designprinzipien

- sachlich, modern, enterprise-tauglich
- hohe Kontrastwerte
- formular- und listenoptimiert
- auf typische Helpdesk-Workflows ausgelegt
- Desktop-first, Tablet-lesbar optional
- nicht verspielt, sondern effizient

## 2. Primäres Navigationsmodell

### Linke Hauptnavigation
- Dashboard
- Benutzer
- Prozesse
- Zugriffe
- Kommunikation
- Assets
- Betrieb
- Reports
- Audit
- Administration

### Topbar
- globale Suche
- Mandant / Firma
- Schnellaktionen
- Benachrichtigungen
- Benutzerprofil / Rollenhinweis
- Health-/Fehlerindikator

## 3. Dashboard-Konzept

Das Dashboard ist die erste Admin-Arbeitsfläche.

### Empfohlene Kacheln
- offene Onboardings
- offene Offboardings
- blockierte Jobs
- überfällige Freigaben
- inaktive Konten
- ungenutzte Lizenzen
- Asset-Rückgaben offen
- Health-Warnungen pro Modul

### Zusätzliche Bereiche
- letzte Aktionen
- zuletzt geöffnete Benutzer
- Favoriten / Quick Actions
- kurze Betriebshinweise

## 4. Seitenmuster

### Listenansicht
Für Benutzer, Gruppen, Assets, Jobs, Reports.

Elemente:
- Filterleiste
- gespeicherte Ansichten
- Spaltenauswahl
- Exportfunktion
- Sammelaktionen nur bei passenden Rechten

### Detailseite
Für einzelne Benutzer, Assets oder Workflows.

Elemente:
- Stammdatenkopf
- Statusbadges
- Tabs oder Sektionen
- verknüpfte Objekte
- Historie / Audit / Aufgaben
- Schnellaktionen rechts oder oben

### Wizard-Seite
Für Onboarding, Offboarding, Mover.

Elemente:
- Fortschrittsleiste
- Pflichtfeldprüfung
- kontextbezogene Hinweise
- Review-/Summary-Seite vor Ausführung
- Dry-Run optional

## 5. Benutzerdetailseite – empfohlene Struktur

### Kopfbereich
- Name
- Status
- Firma / Standort / Abteilung
- Kontotyp
- Start-/Enddatum
- Risiko-/Hinweisbadges

### Sektionen
- Identitäten
- Gruppen und Rollenpakete
- Lizenzen
- Mailbox / Kommunikation
- Geräte / Assets
- Tickets / Aufgaben
- Workflow-Historie
- Audit-Ereignisse

## 6. Workflow-Wizards

### Onboarding Wizard
1. Stammdaten
2. Organisation
3. Rollenpaket / Gruppen / Lizenzen
4. Kommunikation / Telefonie
5. Assets / Software
6. Review
7. Ergebnis / Folgeaufgaben

### Offboarding Wizard
1. Austrittsart und Termin
2. Rechte- und Kommunikationszielzustand
3. Daten-/Asset-Übergabe
4. Review
5. Ausführung
6. Abschlussbericht

### Mover Wizard
1. Ausgangssituation
2. Zielrolle / Zielstandort
3. Delta-Vorschau
4. Review
5. Ausführung

## 7. Such- und Filterkonzept

### Globale Suche
Soll mindestens finden:
- Benutzername
- SamAccountName
- UPN
- E-Mail
- Asset-ID
- Seriennummer
- Ticket-ID
- Gruppenname

### Kontextfilter
Je Modul sollen passende Filter möglich sein, z. B.:
- aktive / deaktivierte Benutzer
- fällige Austritte
- blockierte Jobs
- Assets in Rückgabe
- offene Freigaben

## 8. Status- und Badge-System

### Statusfarben
- Blau: informativ / in Bearbeitung
- Grün: erfolgreich / erledigt
- Gelb: Warnung / Folgeaktion nötig
- Rot: Fehler / kritisch
- Grau: archiviert / inaktiv / deaktiviert

### Beispielbadges
- `Preboarding`
- `Active`
- `PendingOffboarding`
- `Blocked`
- `NeedsApproval`
- `CompletedWithWarnings`
- `VIP`
- `External`

## 9. UX-Regeln für Admin-Prozesse

- häufige Aktionen maximal 2 bis 4 Klicks tief
- gefährliche Aktionen brauchen klare Bestätigung
- Zusammenfassungsseite vor Massenoperationen
- Fehlermeldungen fachlich verständlich formulieren
- technische Details optional aufklappbar
- nach wichtigen Aktionen immer klarer Ergebniszustand

## 10. Leere Zustände und Hilfetexte

Leere Zustände sollen nicht leer wirken, sondern orientieren:

- „Noch keine offenen Jobs“
- „Kein passender Benutzer gefunden“
- „Dieses Modul ist für diesen Mandanten nicht aktiviert“
- „Sie haben keine Berechtigung für diese Aktion“

## 11. Freigaben und Review in der Oberfläche

Freigaben brauchen eine gut sichtbare UX:

- wer muss genehmigen?
- warum ist Genehmigung nötig?
- bis wann ist Freigabe offen?
- welche Folgeaktionen hängen daran?

## 12. Mobile / kleinere Ansichten

Nicht primär für Smartphones gedacht, aber auf kleineren Auflösungen sollten mindestens nutzbar bleiben:

- Dashboard lesen
- Benutzer suchen
- Freigaben prüfen
- Jobstatus ansehen

## 13. Empfohlene erste Mockup-Seiten

- Dashboard
- Benutzerliste
- Benutzerdetailseite
- Onboarding-Wizard
- Offboarding-Wizard
- Jobübersicht
- Auditansicht
- Modul-/Mandantenverwaltung
