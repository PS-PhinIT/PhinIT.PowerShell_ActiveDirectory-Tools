# Changelog

## 2026-10-14 – Funktionserweiterung BitLocker-/LAPS-Auslesen

### Hinzugefügt / Behoben
- easyBITKEYS 0.7.0: Key ID, Computer ohne Schlüssel, Erkennung fehlender Leserechte, Statuszeile, konfigurierbarer Server/OU.
- easyLAPS 0.5.0: Fallback-Kette für das Auslesen (Windows LAPS → Legacy → AD-Attribute), Reset-Fallback, Neustart in PowerShell 5.1.
- `easyLAPS/Install/LAPS_INSTALL.ps1` überarbeitet; veraltete Authenticode-Signatur entfernt.

## 2026-10-14 – Audit und Bereinigung

### Sicherheit / Fehlerbehebung
- Audit beider Tools (Sicherheit, Performance, Funktionen, Verweise, GUI, Befehle) und Behebung der Befunde:
  easyBITKEYS 0.6.0, easyLAPS 0.4.0 (Details in den Tool-Changelogs).

### Geändert
- Versionsnummern aus Dateinamen entfernt: `easyBITKEYS.ps1`, `easyLAPS.ps1`.
- Einheitliche Ordnerstruktur; LAPS-Installationsdateien nach `easyLAPS/Install/` verschoben.
- `.gitignore` auf Root- und Tool-Ebene für Logs, CSV-Exporte und Diagnose-Archive.

### Entfernt
- Alle alten Versionen (`easyBITKeys/# OLD`, `easyLAPS/# Old`, inkl. EXE und ZIP) und alle Screenshots.

### Dokumentation
- Neu: `README.md` (Übersicht), `CHANGELOG.md`, `SECURITY.md`, `easyLAPS/Install/README.md`.
- Tool-READMEs und -CHANGELOGs aktualisiert, Historie ergänzt.

## 2026-10-14 – Repository-Reduktion (Commit `4a9a400`)

### Entfernt
- Tools `easyADGroups`, `easyADPW` und `easyONBOARDING` aus diesem Repository entfernt.

## 2026-06-09 – Pflege easyBITKEYS / easyLAPS (Commits `3dec9b9`, `1ff47ac`, `a7a0de7`, `1f1a9fc`)

### Geändert
- easyBITKEYS 0.5.2 und 0.5.3 (Standalone-Betrieb ohne Assets), `CHANGELOG.md` eingeführt.
- easyLAPS 0.3.4 inkl. Diagnose- und „Run Policy (local)“-Button, `CHANGELOG.md` eingeführt.
- Alte Versionen in Unterordner verschoben, `SimpleLapsGui.ps1` entfernt.

### Entfernt
- Tool `easyFolder` entfernt.

## 2026-05-03 – easyONBOARDING (Commits `d3d2180`, `42b85b3`)

### Geändert
- Umstrukturierung und Erweiterungen an easyONBOARDING (inzwischen entfernt), `.vscode`-Einstellungen ergänzt.

## 2026-01-19 – Initialer Import (Commits `6f37458`, `6fd1d0f`)

### Hinzugefügt
- Repository angelegt.
- Import der Tools easyADGroups, easyADPW, easyBITKeys, easyFolder, easyLAPS und easyONBOARDING.
