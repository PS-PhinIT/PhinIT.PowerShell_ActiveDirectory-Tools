# Changelog

Alle nennenswerten Änderungen an `easyLAPS_V0.3.4.ps1` werden in dieser Datei dokumentiert.

## [0.3.4] - 2026-06-09

### Behoben
- Mehrere fehlerhafte Aufrufe von `Write-Log` korrigiert (`-Type` -> `-Level`), damit Fehlerpfade wieder korrekt loggen.
- Fehlende Funktion `Open-URLInBrowser` ergänzt, damit der Logo-Link sauber geöffnet werden kann.
- Fehlendes GUI-Element `txtFilter` ergänzt und Filterlogik stabilisiert (inkl. Live-Filter über `TextChanged`).
- Event-Handler für **Show Password** (`btnGetLapsPassword`) ergänzt, damit Passwortabruf auch ohne Listenklick funktioniert.
- Potenzielle Analyse-Warnungen bei Event-Parametern entschärft (`$sender` ersetzt).
- Modulprüfung im Startblock erweitert: Tool akzeptiert jetzt Windows LAPS **oder** Legacy-LAPS-Cmdlets.
- `Convert-SecureStringToPlainText` auf `PtrToStringBSTR` umgestellt für saubere BSTR-Auswertung.
- Validierung beim Passwortabruf robuster gemacht (nicht mehr zwingend `ExpirationTimestamp`, solange Passwort vorhanden ist).

### Dokumentation
- `README.md` auf aktuellen Funktions- und Modulstand aktualisiert.
