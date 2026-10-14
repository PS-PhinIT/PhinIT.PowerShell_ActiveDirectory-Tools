# easyBITKEYS

**Version:** 0.6.0  
**Datei:** `easyBITKEYS.ps1`  
**Autor:** Andreas Hepp  
**Letztes Update:** 14.10.2026

`easyBITKEYS` liest BitLocker-Wiederherstellungsschlüssel (`msFVE-RecoveryInformation`) aus Active Directory und zeigt sie in einer WPF-GUI farbcodiert an.

## Funktionen

- AD-Abfrage aller BitLocker-Wiederherstellungsschlüssel
- Farbliche Bewertung nach Alter:
  - **Grau**: kein Key vorhanden
  - **Grün**: jünger als 7 Monate
  - **Orange**: 7 bis unter 12 Monate
  - **Rot**: 12 Monate oder älter
- Suche (Computername, Key oder alle Felder) und Altersfilter
- Spaltensortierung per Klick auf den Spaltenkopf (auf-/absteigend, Datum chronologisch)
- CSV-Export der aktuell angezeigten Einträge (berücksichtigt Suche/Filter)
- Key in Zwischenablage kopieren (`Copy Key` oder `Strg+C` in der Liste) – die Zwischenablage wird nach **30 Sekunden** automatisch geleert (`$ClipboardClearSeconds`, `0` = deaktiviert) sowie beim Schließen des Tools
- Entfernen eines AD-Eintrags nach Bestätigung (nur im AD-Modus)

## Standalone-Verhalten

Das Tool läuft **eigenständig** ohne externe Konfigurationsdatei:

- Keine INI-Datei erforderlich – die Konfiguration steht am Anfang von `easyBITKEYS.ps1`
- GUI nutzt **keine externen Assets** (keine Logo-/Icon-Dateien)
- GUI öffnet **keine externen URLs**

Wenn das AD-Modul oder Berechtigungen fehlen, schaltet das Tool automatisch in den **Client Mode** (Beispieldaten, Entfernen deaktiviert) und bleibt bedienbar.

## Voraussetzungen

- **Windows PowerShell 5.1** – wird das Skript unter PowerShell 7 gestartet, startet es sich automatisch (ohne Rechteerhöhung) in Windows PowerShell 5.1 neu
- Für echten AD-Betrieb:
  - RSAT / ActiveDirectory-Modul
  - Leserechte auf `msFVE-RecoveryInformation` (inkl. `msFVE-RecoveryPassword`)
  - Löschrechte nur bei Nutzung der Remove-Funktion
- Lokale Administratorrechte sind **nicht** erforderlich

## Nutzung

1. `easyBITKEYS.ps1` in Windows PowerShell 5.1 starten.
2. Die GUI lädt AD-Daten oder automatisch Beispieldaten (Client Mode).
3. Navigation links: `Refresh List`, `Export CSV`, `Copy Key`, `Remove Key`.
4. Suche/Filter oben im Inhaltsbereich, Sortierung über die Spaltenköpfe.

## Logging

Logs werden unter `Logs\easyBITKEYS_<yyyy-MM-dd>.log` neben dem Skript geschrieben (Fallback: `%TEMP%\easyBITKEYS_fallback.log`). Wiederherstellungsschlüssel und Suchbegriffe werden **nicht** geloggt.

## Sicherheitshinweise

- CSV-Exporte enthalten Wiederherstellungsschlüssel im **Klartext** – nur an geschützten Orten ablegen und nach Gebrauch löschen.
- Exporte und Logs sind per `.gitignore` von der Versionsverwaltung ausgeschlossen.
- Siehe auch [`SECURITY.md`](../SECURITY.md).

## Changelog

Siehe [`CHANGELOG.md`](CHANGELOG.md).

## Lizenz

MIT-Lizenz, siehe [`LICENSE`](LICENSE).
