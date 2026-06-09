# Changelog

Alle relevanten Änderungen an `easyBITKEYS` werden hier dokumentiert.

## [0.5.2] - 2026-06-09

### Fixed
- Fehler behoben, bei dem `Join-Path` mit `NULL` für `$script:ScriptRoot` aufgerufen wurde.
- Doppelte Registrierung des `btnExit`-Click-Handlers entfernt.
- Event-Registrierungen (Search-Enter, DataGrid-Loaded) zeitlich korrigiert (jetzt vor `ShowDialog()`).
- Client-Mode robuster gemacht (kein Löschen ohne AD-Kontext, klare Hinweise in der GUI).
- Fallback-Handling für fehlende GUI-Assets verbessert (Info/Close Text-Fallback).

### Changed
- Script-Version auf `0.5.2` angehoben.
- Selbstdiagnose (`Test-Requirements`) so angepasst, dass fehlende Assets/fehlende AD-Rechte nicht mehr hart abbrechen, sondern in den Client-Mode wechseln.
- Header-Logo-Verhalten toleranter gemacht (fehlende Datei blendet Logo aus, kein Abbruch).
- Such-/Filter-Grunddaten werden nach jedem Refresh sauber neu gesetzt.
- Externe URL-Öffnung aus der GUI standardmäßig deaktiviert (`$HeaderLogoURL = ""`).

### Documentation
- `README.md` vollständig aktualisiert (Standalone-Betrieb, Client-Mode, aktuelle Nutzung).
- `CHANGELOG.md` neu eingeführt.

## [0.4.2] - 2025-05-23

### Notes
- Vorherige dokumentierte Version (Baseline vor den Stabilitätsfixes in 0.5.2).
