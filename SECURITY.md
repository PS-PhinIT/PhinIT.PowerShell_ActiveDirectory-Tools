# Sicherheit

Die Tools in diesem Repository verarbeiten **hochsensible Daten**:

- **easyBITKEYS**: BitLocker-Wiederherstellungsschlüssel (ermöglichen das Entsperren verschlüsselter Datenträger)
- **easyLAPS**: Kennwörter lokaler Administratorkonten

## Grundsätze für den Betrieb

- **Least Privilege:** Nur die minimal benötigten AD-Rechte delegieren (Lesen bzw. Reset getrennt). Lokale Administratorrechte sind für die Tools nicht erforderlich; easyBITKEYS fordert keine Rechteerhöhung an.
- **Zwischenablage:** Kopierte Schlüssel/Kennwörter werden nach 30 Sekunden und beim Schließen der Tools automatisch aus der Zwischenablage entfernt. Clipboard-Verlauf (`Win+V`) bzw. Cloud-Synchronisierung der Zwischenablage auf Admin-Systemen deaktivieren.
- **CSV-Exporte** enthalten Geheimnisse im **Klartext**. Nur auf verschlüsselten, zugriffsbeschränkten Speicherorten ablegen und nach Gebrauch sicher löschen. Niemals ins Repository einchecken (per `.gitignore` ausgeschlossen).
- **Logs** enthalten keine Schlüssel oder Kennwörter, aber Computernamen und Benutzeraktionen. Speicherort: `Logs\` neben dem jeweiligen Skript.
- **Ausführung:** Skripte nur aus vertrauenswürdigen Quellen starten. `easyLAPS/Install/LAPS_INSTALL.ps1` ist Authenticode-signiert; nach Änderungen neu signieren.
- **Schema-Änderungen** (`Update-LapsADSchema`) sind forest-weit und irreversibel – nur nach Change-Prozess durchführen.
- **Legacy Microsoft LAPS** ist abgekündigt; bevorzugt Windows LAPS mit Kennwortverschlüsselung (`ADPasswordEncryptionEnabled`) verwenden.

## Bekannte Einschränkungen

- `LAPS_INSTALL.ps1` führt die Schema-Erweiterung ohne zusätzliche Rückfrage aus und zeigt beim Test das Kennwort im Klartext an (Datei bleibt wegen Signatur unverändert).
- easyBITKEYS startet sich unter PowerShell 7 mit `-ExecutionPolicy Bypass` (nur für den eigenen Prozess) in Windows PowerShell 5.1 neu.

## Schwachstellen melden

Sicherheitsprobleme bitte **nicht** als öffentliches Issue melden, sondern vertraulich über
[GitHub Security Advisories](../../security/advisories/new) dieses Repositorys bzw. direkt an den Maintainer (PhinIT, Andreas Hepp).
