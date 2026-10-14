# easyLAPS – Install

Hilfsdateien zur Einrichtung von LAPS im Active Directory. Sie werden von `easyLAPS.ps1` **nicht** aufgerufen und sind optional.

| Datei | Zweck |
|---|---|
| `LAPS_INSTALL.ps1` | Kleine Windows-Forms-GUI für **Windows LAPS**: Schema-Erweiterung (`Update-LapsADSchema`), Self-Permission für die OU des lokalen Computers (`Set-LapsADComputerSelfPermission`) und Testabruf (`Get-LapsADPassword`). |
| `LAPS.x64.msi` | Installer des **Legacy Microsoft LAPS** (AdmPwd). Nur für Altumgebungen ohne Windows LAPS. |

## Voraussetzungen

- Windows PowerShell 5.1
- RSAT-AD-PowerShell und Windows-LAPS-Modul (`LAPS`)
- Für die Schema-Erweiterung: Mitglied der Gruppe **Schema-Admins**
- Für die Rechtevergabe: Schreibrechte auf die Ziel-OU

## Wichtige Hinweise

- `LAPS_INSTALL.ps1` ist **Authenticode-signiert**. Jede Änderung macht die Signatur ungültig – nach Anpassungen neu signieren.
- **LAPS installieren** führt `Update-LapsADSchema` **ohne zusätzliche Rückfrage** aus. Eine Schema-Erweiterung ist forest-weit und **nicht rückgängig zu machen** – vorher Backup/Change-Prozess beachten.
- **LAPS konfigurieren** verwendet die OU des **lokalen** Computers, nicht die eines Zielcomputers.
- **LAPS testen** zeigt das Passwort im Klartext in einer MessageBox an.
- Legacy Microsoft LAPS ist von Microsoft abgekündigt. Für neue Umgebungen Windows LAPS verwenden; Legacy und Windows LAPS nicht für dasselbe Konto parallel betreiben.

## Referenzen

- Windows LAPS – AD-Szenario: https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-scenarios-windows-server-active-directory
- `Update-LapsADSchema`: https://learn.microsoft.com/en-us/powershell/module/laps/update-lapsadschema
- `Set-LapsADComputerSelfPermission`: https://learn.microsoft.com/en-us/powershell/module/laps/set-lapsadcomputerselfpermission
- Legacy-LAPS-Szenarien: https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-scenarios-legacy
