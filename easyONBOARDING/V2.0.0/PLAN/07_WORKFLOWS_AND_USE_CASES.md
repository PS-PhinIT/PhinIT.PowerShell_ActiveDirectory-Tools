# V2.0.0 – Workflows und Use Cases

## Ziel

Dieses Dokument beschreibt die wichtigsten End-to-End-Prozesse, die V2 unterstützen soll.
Nicht nur Benutzer anlegen, sondern den kompletten täglichen IT-Betrieb rund um Mitarbeitende, Identitäten, Rechte, Geräte und Kommunikation.

## 1. Standard-Onboarding

### Auslöser
- HR-Import
- manuelle Anlage durch IT
- Ticket / Freigabeprozess

### Hauptschritte
1. Personendaten erfassen oder importieren
2. Pflichtfelder validieren
3. Mandant / Firma / Standort wählen
4. Rolle / Rollenpaket auswählen
5. AD-Konto anlegen
6. Gruppenpakete anwenden
7. Lizenzpaket anwenden
8. Mailbox vorbereiten
9. ADSync / Entra-Sync anstoßen
10. Telefonie-Aufgabe erzeugen
11. Asset-/Geräteaufgabe erzeugen
12. Welcome-Dokument und Ticket erzeugen
13. Abschluss protokollieren

### Ergebnis
- Benutzer ist startklar dokumentiert
- Folgeaufgaben sind sichtbar
- Audit- und Reportdaten sind vorhanden

## 2. Vorab-Onboarding / Preboarding

### Ziel
Konten und Ressourcen vor dem ersten Arbeitstag vorbereiten, aber erst zu definiertem Zeitpunkt aktivieren.

### Funktionen
- Startdatum-gesteuerte Aktivierung
- temporär deaktivierter Zustand
- Vorab-Lizenzierung optional
- vorbereitete Gruppen, Geräte und Telefonieaufgaben

## 3. Bulk-Onboarding

### Typischer Ablauf
- CSV / Excel / HR-Daten einlesen
- Validierung und Fehlerliste anzeigen
- Dubletten erkennen
- Dry-Run-Vorschau
- Sammelausführung
- Ergebnisse exportieren

### Wichtig
- Teilfehler sauber behandeln
- pro Datensatz Audit-Einträge erzeugen
- Wiederholung einzelner fehlerhafter Datensätze ermöglichen

## 4. Mover-Prozess

### Typische Anlässe
- Abteilungswechsel
- Standortwechsel
- Managerwechsel
- Rollenwechsel
- Kostenstellenwechsel
- Namensänderung

### Typische Schritte
1. bisherigen Zustand erfassen
2. Zielrolle und Zielpakete bestimmen
3. Delta zwischen alt und neu berechnen
4. Gruppen anpassen
5. Lizenzen anpassen
6. Telefonie anpassen
7. Teams / SharePoint / Fileserver-Aufgaben erzeugen
8. Änderung dokumentieren

## 5. Offboarding Standard

### Auslöser
- Austrittsmeldung
- Ticket
- HR-Import
- Sofortmaßnahme durch IT

### Standardkette
1. Austrittsdatum / Art des Offboardings festlegen
2. offene Aufgaben und Owner prüfen
3. AD-Konto sperren oder terminieren
4. Passwort randomisieren
5. aktive Sitzungen / Tokens / MFA-Status prüfen
6. Gruppen entziehen oder archivieren
7. Lizenzen entziehen
8. Mailbox in Zielzustand überführen
9. OneDrive / Homefolder / Fileserver-Übergabe einleiten
10. Telefonie deaktivieren
11. Assets und Geräte zurückfordern
12. Abschlussbericht erzeugen

## 6. Emergency Offboarding

### Ziel
Sofortige Reaktion bei Sicherheitsvorfällen oder fristlosen Austritten.

### Unterschiede zum Standard
- sofortige Kontensperre
- sofortiger Entzug kritischer Rechte
- sofortige Token-/Session-Betrachtung
- priorisierte Alarmierung
- spätere Nachbearbeitung der Übergabethemen

## 7. Rehire / Wiederkehrer

### Ziel
Ehemalige Mitarbeitende schneller wieder aktivieren.

### Prozess
- Altidentität suchen
- entscheiden: reaktivieren oder neu anlegen
- neue Rolle / neue Gruppen / neue Firma prüfen
- Mailbox- und Lizenzstrategie festlegen
- Audit sauber vom Altverhältnis trennen

## 8. Passwort- und Kontoservice

### Use Cases
- Passwort zurücksetzen
- Konto entsperren
- Kennwort läuft ab
- Verdacht auf Kompromittierung
- Service Desk Schnellaktionen

### Anforderungen
- klare Rechteprüfung
- Grund / Ticketnummer dokumentieren
- Benutzerbenachrichtigung optional
- sichere Ausgabe nur an Berechtigte

## 9. Gruppen- und Rechteprozesse

### Standardprozesse
- Gruppenmitgliedschaften anzeigen
- Gruppenpaket zuweisen
- Gruppenmitgliedschaften vergleichen
- Rollenwechsel-Deltas ermitteln
- Owner-Prüfungen und Rezertifizierungen starten
- zeitlich befristete Zugriffe vergeben

## 10. Lizenz- und M365-Prozesse

### Use Cases
- Lizenzpaket zuweisen
- Lizenzpaket entziehen
- Konflikte bei Paketen erkennen
- ungenutzte Lizenzen finden
- Sonderlizenzen freigabepflichtig machen

## 11. Mailbox- und Kommunikationsprozesse

### Exchange / M365
- Mailbox anlegen
- Shared Mailbox erstellen
- Aliase setzen
- Weiterleitung setzen
- Delegationen anpassen
- OOO / Stellvertretung vorbereiten

### Telefonie
- 3CX-Benutzer anlegen
- STARFACE-Benutzer anlegen
- Durchwahl vergeben
- Rufgruppe zuweisen
- Voicemail zurücksetzen
- Offboarding in Telefonie ausführen

## 12. Asset- und Geräteprozesse

### Übergabe
- Gerät auswählen
- Zubehör hinzufügen
- Seriennummer / Inventarnummer erfassen
- Übergabeprotokoll erzeugen
- zugehörige Softwarepakete notieren

### Rückgabe
- Gerät zurücknehmen
- Zustand dokumentieren
- Datenlöschung / Neuinstallation veranlassen
- offene Peripherie markieren
- Rückgabeprotokoll erzeugen

## 13. Wartungs- und Health-Workflows

### Wiederkehrende Jobs
- inaktive Benutzer prüfen
- inaktive Computer prüfen
- ablaufende Verträge / Externe prüfen
- ungenutzte Lizenzen prüfen
- Gruppen ohne Owner prüfen
- offene Offboarding-Aufgaben prüfen
- Zertifikatswarnungen sammeln

### Darstellung
- Dashboard-Kacheln
- tägliche / wöchentliche Jobreports
- Eskalation bei Schwellwertüberschreitung

## 14. Ticketing-Workflows

### Standardidee
- bei Prozessstart optional Ticket anlegen
- Subtasks je Modul erzeugen
- Rückmeldungen in Tool und Ticket synchron halten
- Abschlussbericht ans Ticket anhängen

## 15. Fachbereichs- und Freigabeworkflows

### Beispiele
- Teamleiter genehmigt Sonderlizenz
- HR bestätigt Startdatum
- IT-Security genehmigt privilegierte Rechte
- Asset-Management bestätigt Geräteausgabe

## 16. Typische Rollen im Workflow

- Helpdesk
- IAM / AD-Admin
- M365-Admin
- Telefonie-Admin
- Asset-Admin
- Teamleiter / Genehmiger
- Auditor
- HR-Viewer

## 17. Workflow-Qualitätsregeln

- jeder schreibende Schritt bekommt Audit-Eintrag
- jeder Fehler muss verständlich rückgemeldet werden
- Folgeaufgaben dürfen nicht still verschwinden
- kritische Schritte brauchen Idempotenz oder Schutz vor Doppelstart
- Dry-Run sollte für riskante Sammeloperationen Standard sein

## 18. Zusätzliche wichtige Alltagsszenarien

### Zugriffsanfrage / Access Request
- Benutzer oder Fachbereich beantragt Zugriff
- Genehmiger bestätigt Bedarf
- IT prüft technische Umsetzbarkeit
- Zuweisung wird dokumentiert und optional befristet

### Projekt-Onboarding
- mehrere Mitarbeitende bekommen temporäre Projektzugriffe
- Gruppen, Teams, SharePoint und Fileshares werden in Paketform zugewiesen
- Frist und Reviewdatum werden mitgeführt

### Elternzeit / Langzeitabwesenheit
- Konto bleibt grundsätzlich erhalten
- ausgewählte Rechte können temporär reduziert werden
- Mailbox- und Vertretungslogik wird angepasst
- Wiedervorlage für Rückkehr wird erzeugt

### Geräte-Refresh
- Altgerät markieren
- Nachfolgegerät zuweisen
- Datenübernahme / Rückgabe / Softwarepakete koordinieren

## 19. Sonderfallprozesse

### Externe / Freelancer
- befristete Identität
- Sponsor / interner Owner zwingend
- automatisches Ablaufdatum
- Review und Offboarding ohne HR-Abhängigkeit möglich

### VIP- / Sonderkonto-Prozesse
- zusätzliche Freigaben
- höhere Sichtbarkeitsbeschränkung
- gesondertes Logging für kritische Änderungen

### Servicekonten / Funktionskonten
- kein klassischer Mitarbeitendenprozess
- Owner, Zweck und Ablaufdatum dokumentieren
- Sonderbehandlung für Passwortrotation und Audit

## 20. SLA- und Eskalationsgedanken

- Aufgaben sollten Fälligkeiten besitzen
- blockierte technische Tasks müssen sichtbar eskalieren
- Freigaben sollten nach definierter Zeit erneut erinnert werden
- überfällige Offboarding-Schritte gehören prominent ins Dashboard

## 21. Fehlerbehandlung innerhalb von Workflows

### Prinzipien
- Fehler nicht verschweigen
- Teilerfolge sichtbar machen
- Nacharbeitspfade erzeugen
- Wiederholung einzelner Schritte ermöglichen

### Beispielstatus
- `CompletedWithWarnings`
- `WaitingExternal`
- `ManualFollowUpRequired`
