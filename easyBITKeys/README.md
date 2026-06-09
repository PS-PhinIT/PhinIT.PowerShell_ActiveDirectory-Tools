# easyBITKEYS

**Version (Script):** 0.5.2  
**Datei:** `easyBITKEYS_V0.5.1.ps1`  
**Author:** Andreas Hepp  
**Last Update:** 09.06.2026

`easyBITKEYS` liest BitLocker-Wiederherstellungsschlüssel (`msFVE-RecoveryInformation`) aus Active Directory und zeigt sie in einer WPF-GUI farbcodiert an.

## Funktionen

- AD-Abfrage von BitLocker-Keys
- Farbliche Bewertung nach Alter:
  - **Grau**: kein Key vorhanden
  - **Grün**: jünger als 7 Monate
  - **Orange**: 7 bis unter 12 Monate
  - **Rot**: 12 Monate oder älter
- Suche, Filter und Spaltensortierung
- CSV-Export
- Key in Zwischenablage kopieren
- Entfernen eines AD-Eintrags (nur im AD-Modus)

## Standalone-Verhalten (wichtig)

Das Tool läuft **eigenständig** ohne externe Konfigurationsdatei:

- Keine INI-Datei erforderlich
- Fehlende GUI-Assets (`assets/info.png`, `assets/close.png`) blockieren den Start nicht (Text-Fallback)
- Fehlendes Header-Logo blockiert den Start nicht
- Standardmäßig wird **keine externe URL** aus der GUI geöffnet

Wenn das AD-Modul oder Berechtigungen fehlen, schaltet das Tool automatisch in den **Client Mode** (Beispieldaten) und bleibt bedienbar.

## Voraussetzungen

- **PowerShell 5.1** (wird geprüft; bei Bedarf Neustart in 5.1)
- Für echten AD-Betrieb:
  - RSAT / ActiveDirectory-Modul
  - Leserechte auf `msFVE-RecoveryInformation`
  - Löschrechte nur bei Nutzung der Remove-Funktion

## Nutzung

1. `easyBITKEYS_V0.5.1.ps1` starten (PowerShell 5.1).
2. Die GUI lädt AD-Daten oder automatisch Beispieldaten (Client Mode).
3. Über Navigation links: `Refresh`, `Export CSV`, `Copy Key`, `Remove Key`.

## Changelog

Siehe `CHANGELOG.md` für alle Änderungen.

## Lizenz

MIT-Lizenz, siehe `LICENSE`.
