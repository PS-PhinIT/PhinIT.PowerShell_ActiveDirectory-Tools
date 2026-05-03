# Benutzerübersicht-Modul

Das Modul `Benutzerübersicht` dient in `easyONBOARDING V2.0.0` als Startpunkt für spätere Personen-, Such- und Lifecycle-Sichten.

## Aktueller Stand

Die GUI bietet jetzt eine erste echte AD-Benutzersuche über einen PowerShell-Connector.

Aktuell enthalten sind:

- Suchfeld für Name, SAM, UPN oder Mail
- produktiver Runner-Aufruf statt reinem Mock
- Ergebnisliste mit Kernattributen aus Active Directory
- SQLite-Jobeintrag pro Suchlauf
- Fehler- und Hinweisanzeige bei Modul-, Timeout- oder Connector-Problemen

## Zielbild

Später soll dieses Modul unter anderem folgende Fähigkeiten bündeln:

- Suche nach Personen und Identitäten
- Schnellfilter nach Lifecycle-Status
- Direktnavigation zu Onboarding, Offboarding und Mover-Prozessen
- Detailansichten für Rollen, Gruppen, Lizenzen und Historie
- Aufgaben und Hinweise zu offenen Nacharbeiten

## Geplante Ausbaustufen

1. Detailseite pro Person
2. gekoppelte Timeline mit Audit- und Jobdaten
3. kontextuelle Aktionen für Joiner, Mover und Leaver
4. erweiterte Filter für Status, Firma, Rolle und Standort
