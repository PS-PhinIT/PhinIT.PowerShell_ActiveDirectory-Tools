# PhinIT – PowerShell AD Tools

Sammlung von PowerShell-GUI-Tools (WPF) für die Active-Directory-Administration.

## Tools

| Tool | Version | Zweck | Dokumentation |
|---|---|---|---|
| **easyBITKEYS** | 0.6.0 | BitLocker-Wiederherstellungsschlüssel aus AD anzeigen, filtern, exportieren, entfernen | [README](easyBITKeys/README.md) · [CHANGELOG](easyBITKeys/CHANGELOG.md) |
| **easyLAPS** | 0.4.0 | LAPS-Passwörter (Windows LAPS / Legacy) anzeigen, zurücksetzen, exportieren; lokaler LAPS-Status und Diagnose | [README](easyLAPS/README.md) · [CHANGELOG](easyLAPS/CHANGELOG.md) |

## Ordnerstruktur

```
.
├── README.md            # Diese Übersicht
├── CHANGELOG.md         # Änderungen auf Repository-Ebene
├── SECURITY.md          # Sicherheitshinweise und Meldung von Schwachstellen
├── easyBITKeys/
│   ├── easyBITKEYS.ps1
│   ├── README.md
│   ├── CHANGELOG.md
│   └── LICENSE
└── easyLAPS/
    ├── easyLAPS.ps1
    ├── README.md
    ├── CHANGELOG.md
    ├── LICENSE
    └── Install/         # Optionale LAPS-Einrichtung (Schema, Rechte, Legacy-MSI)
        └── README.md
```

Laufzeitdaten (`Logs/`, CSV-Exporte, Diagnose-ZIPs) werden neben dem jeweiligen Skript erzeugt und sind per `.gitignore` ausgeschlossen.

## Konventionen

- **Keine Versionsnummern in Dateinamen.** Die Version steht im Skript, im jeweiligen `README.md` und im `CHANGELOG.md`.
- Ältere Versionen werden nicht im Repository abgelegt – sie sind über die Git-Historie erreichbar.
- Jede Version erhält im `CHANGELOG.md` einen Eintrag mit Versionsnummer und Datum (kein „Unreleased“-Abschnitt).
- Skripte werden als **UTF-8 mit BOM** gespeichert, damit Umlaute unter Windows PowerShell 5.1 korrekt dargestellt werden.

## Voraussetzungen (allgemein)

- Windows mit **Windows PowerShell 5.1**
- RSAT / ActiveDirectory-Modul
- Tool-spezifische Rechte und Module: siehe README des jeweiligen Tools

## Sicherheit

Beide Tools zeigen hochsensible Daten (Wiederherstellungsschlüssel, Administratorkennwörter) an. Bitte [`SECURITY.md`](SECURITY.md) beachten.

## Lizenz

MIT – siehe `LICENSE` im jeweiligen Tool-Ordner.
