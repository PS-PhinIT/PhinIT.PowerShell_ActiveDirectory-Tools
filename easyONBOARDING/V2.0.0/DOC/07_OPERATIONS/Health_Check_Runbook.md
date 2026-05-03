# Health-Check-Runbook

Dieses Runbook beschreibt, welche Bereiche nach Änderungen oder vor Pilotbetrieb geprüft werden sollten.

## Tägliche Kernprüfungen

- startet die FastAPI-Webanwendung fehlerfrei?
- laden Dashboard, Onboarding, Offboarding und Dokumentation?
- ist die Navigation vollständig und ohne Templatefehler?
- sind Tests und Linting grün?

## Vor einem Pilot-Rollout

1. Validierung aller Formularpfade
2. Sichtprüfung der Dokumentationsstruktur
3. Prüfung der `.env`-Werte
4. Kontrolle der PowerShell-Contract-Ausgabe
5. Durchlauf mindestens eines Onboarding- und Offboarding-Dry-Runs

## Spätere technische Health-Signale

- Job Queue Rückstau
- Connector-Zeitüberschreitungen
- Audit-Write-Fehler
- nicht erreichbare Zielsysteme
- Fehlerhäufungen nach Modul oder Mandant
