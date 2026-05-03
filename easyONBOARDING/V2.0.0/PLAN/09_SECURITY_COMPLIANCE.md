# V2.0.0 – Security und Compliance

## Grundsatz

Je universeller ein Admin-Tool wird, desto gefährlicher wird es ohne klare Leitplanken.
V2 muss daher **Sicherheit, Nachvollziehbarkeit und Rechtebegrenzung** von Anfang an mitdenken.

## 1. Sicherheitsziele

- Schutz privilegierter Aktionen
- Nachvollziehbarkeit jeder Änderung
- Minimierung von Fehlbedienung
- sichere Ablage von Secrets
- saubere Trennung von Rollen
- Compliance-fähige Reports und Exporte
- Schutz sensibler Personen- und Kontodaten

## 2. Rollen- und Rechteprinzip

### Beispielrollen
- Helpdesk.Read
- Helpdesk.WriteLimited
- IAM.Admin
- M365.Admin
- Telephony.Admin
- Asset.Admin
- Security.Auditor
- Workflow.Approver
- Tenant.Admin

### Regeln
- Least Privilege
- Rechte pro Modul und pro Aktion
- kritische Aktionen zusätzlich genehmigungspflichtig
- lesende und schreibende Rechte trennen
- Admin-Notfallrechte separat absichern

## 3. Kritische Aktionen mit erhöhter Schutzstufe

- Benutzer mit privilegierten Rechten anlegen
- Admin-/Tier-0-Gruppen ändern
- Offboarding von Sonderkonten
- Mailweiterleitung nach extern setzen
- MFA-relevante Änderungen
- Secret-/Credential-Änderungen
- LAPS-/BitLocker-Daten anzeigen
- Massenänderungen an Gruppen oder Lizenzen
- Sync- oder Löschprozesse mit großer Auswirkung

## 4. Secret-Management

### Verbote
- keine Tokens im Klartext in Git
- keine Passwörter in INI/JSON/YAML im Klartext
- keine Secrets in Logausgaben

### Empfehlung
- Windows Credential Manager
- DPAPI-geschützte Secrets
- optional separates Secret-Backend
- Secret-Referenzen in Modulkonfiguration statt direkter Werte

## 5. PowerShell-Sicherheit

- signierte Skripte bevorzugen
- definierte Connector-Skripte statt beliebiger Scriptausführung
- Eingabevalidierung vor Scriptstart
- standardisierte Exitcodes
- keine ungeprüften Shell-Injections
- Transkript-/Audit-Erfassung da, wo sinnvoll

## 6. API- und Websicherheit

- IIS Windows Authentication
- HTTPS verpflichtend
- CSRF-Schutz für Formaktionen
- Validierung aller Eingaben
- sichere Session-Behandlung
- Schutz vor XSS in Reports und GUI
- Rate-Limits oder Schutz für sensible Aktionen
- sichere Fehlerseiten ohne Detail-Leaks

## 7. Audit- und Nachvollziehbarkeit

Jede schreibende Aktion sollte protokollieren:

- Wer?
- Wann?
- Was?
- Gegen welches Zielobjekt?
- Mit welchem Ergebnis?
- Mit welcher Freigabe / welchem Ticket?
- Welcher alte und neue Zustand?

## 8. Compliance-relevante Themen

- DSGVO-konforme Verarbeitung personenbezogener Daten
- Aufbewahrungs- und Löschfristen für Reports und Auditdaten
- Nachweisbarkeit von Berechtigungsänderungen
- Nachweisbarkeit von Austritten und Zugriffsentzug
- Protokollierung privilegierter Tätigkeiten
- Exportfähigkeit für interne/externe Audits

## 9. Freigaben und Vier-Augen-Prinzip

Empfohlen für:

- Sonderlizenzen
- privilegierte Gruppen
- VIP-Konten
- Massenoperationen
- Offboarding mit Datenübergabe an Dritte
- externe Weiterleitungen / Delegationen

## 10. Schutz sensibler Inhalte

### besonders sensibel
- Zugangsdaten
- Secret-Referenzen
- Recovery Keys
- LAPS-Passwörter
- personenbezogene HR-Daten
- Auditdaten mit Sicherheitsbezug

### Maßnahmen
- Sichtbarkeiten einschränken
- Anzeige nur bei Bedarf
- Exporte absichern
- Download protokollieren

## 11. Betriebs- und Härtungsmaßnahmen

- separater Dienstaccount je nach Modulklasse
- regelmäßige Secret-Rotation
- Patchmanagement für Python, Bibliotheken und Windows Server
- Monitoring auf Fehler, Queue-Stau und fehlgeschlagene Logins
- Backups der Konfiguration und Datenbank
- Wiederanlauf- und Restore-Prozeduren dokumentieren

## 12. Datenklassifizierungsvorschlag

- **Öffentlich intern:** allgemeine Hilfetexte, Modulbeschreibungen
- **Vertraulich:** Benutzerstammdaten, Rollenpakete, Ticketdetails
- **Streng vertraulich:** Secrets, Recovery Keys, privilegierte Auditdaten

## 13. Mindestanforderungen für Produktionsfreigabe

- Rollenmodell umgesetzt
- Audit-Logging aktiv
- HTTPS aktiv
- Secrets geschützt
- kritische Aktionen genehmigungsfähig
- PowerShell-Connectoren kontrolliert und dokumentiert
- Backup-/Restore-Konzept vorhanden
- Log- und Reportaufbewahrung definiert

## 14. Sicherheits-Backlog für spätere Ausbaustufen

- feinere Policy-Engine
- Session-Risikobewertung
- besondere Schutzmechanismen für VIP-Konten
- SIEM-Anbindung
- Alarmierung bei ungewöhnlichen Massenänderungen
- Rezertifizierungsworkflows für Gruppen und Rollen

## 15. Vereinfachtes Threat-Modeling

### Relevante Bedrohungsklassen
- Fehlbedienung durch berechtigte Admins
- überprivilegierte technische Konten
- Secret-Leaks in Dateien oder Logs
- unzureichend abgesicherte Importdateien
- Missbrauch von Massenoperationen
- unvollständiges Offboarding mit Restzugriffen
- Manipulation oder Lücken im Audit-Trail

## 16. Secure Defaults

Die Plattform sollte standardmäßig eher zu restriktiv als zu offen starten:

- Module zunächst deaktiviert ausliefern
- sensible Aktionen nur nach expliziter Freigabe aktivieren
- externe Weiterleitungen standardmäßig blockiert oder genehmigungspflichtig
- Exporte sensibler Daten nur für berechtigte Rollen sichtbar machen
- Debug- und Detailfehler in Produktion reduzieren

## 17. Beispielhafte Freigabematrix

| Aktion | Standardrolle | Zusätzliche Freigabe |
|---|---|---|
| Standard-Onboarding | IAM.Admin / delegierter Bereich | optional |
| privilegierte Gruppe zuweisen | IAM.Admin | Security / Approver |
| externe Mailweiterleitung | M365.Admin | Security / Teamlead |
| LAPS-Passwort anzeigen | Security.Auditor / definierte Adminrolle | ggf. Ticketpflicht |
| Bulk-Offboarding | IAM.Admin | zweite Freigabe empfohlen |

## 18. Aufbewahrungs- und Schutzgedanken

Für jede Datenklasse sollte mindestens grob definiert werden:

- wie lange Daten benötigt werden
- wer sie sehen darf
- ob sie exportierbar sind
- wann sie archiviert oder gelöscht werden

## 19. Sicherheitsprüfung vor Produktivgang

- Rollenmodell testen
- kritische Workflows mit Vier-Augen-Prinzip prüfen
- Logging und Audit-Korrelation verifizieren
- Secretspeicher praktisch testen
- Berechtigungsgrenzen zwischen Modulen prüfen
- Offboarding-Szenarien als Negativtest durchführen
