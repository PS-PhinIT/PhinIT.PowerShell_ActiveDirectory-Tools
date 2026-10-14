# easyLAPS – Install

Hilfsdateien zur Einrichtung von LAPS im Active Directory. Sie werden von `easyLAPS.ps1` **nicht** aufgerufen und sind optional.

| Datei | Zweck |
|---|---|
| `LAPS_INSTALL.ps1` | Windows-Forms-GUI zur Einrichtung von **Windows LAPS** (Schema, Rechte, Test). |
| `LAPS.x64.msi` | Installer des **Legacy Microsoft LAPS** (AdmPwd). Nur für Altumgebungen ohne Windows LAPS. |

## LAPS_INSTALL.ps1

| Schaltfläche | Cmdlet | Hinweis |
|---|---|---|
| Lokale OU ermitteln | `Get-ADComputer` | Füllt die Ziel-OU mit der OU des lokalen Computers (auch beim Start). |
| 1. Schema prüfen / erweitern | `Update-LapsADSchema` | Prüft zuerst, ob die Attribute existieren. Erweiterung nur nach Bestätigung. |
| 2. Computer-Selbstrechte auf OU setzen | `Set-LapsADComputerSelfPermission` | Computer dürfen ihr Passwort im AD speichern. |
| 3. Leserechte für Gruppe delegieren | `Set-LapsADReadPasswordPermission` | Gruppe darf Passwörter lesen. |
| 4. Reset-Rechte für Gruppe delegieren | `Set-LapsADResetPasswordPermission` | Gruppe darf die Ablaufzeit setzen (Rotation). |
| Berechtigungen der OU anzeigen | `Find-LapsADExtendedRights` | Ausgabe im Protokollfenster. |
| LAPS testen | `Get-LapsADPassword` | Zeigt Konto, Quelle, Entschlüsselungsstatus, Passwortlänge und Zeiten – **nicht** das Passwort. |

Alle Änderungen werden vorher bestätigt und im Protokollfenster ausgegeben. Unter PowerShell 7 startet sich das Skript automatisch in Windows PowerShell 5.1 neu.

## Voraussetzungen

- Windows PowerShell 5.1
- Windows-LAPS-Modul (`LAPS`) und RSAT ActiveDirectory-Modul
- Schema-Erweiterung: Mitglied der Gruppe **Schema-Admins**
- Rechtevergabe: Schreibrechte auf die Ziel-OU

## Wichtige Hinweise

- Eine Schema-Erweiterung ist forest-weit und **nicht rückgängig zu machen** – vorher Backup/Change-Prozess beachten.
- Die frühere Authenticode-Signatur war veraltet und wurde entfernt. Bei `AllSigned`-Richtlinie das Skript nach Anpassungen neu signieren.
- Für verschlüsselte Passwörter zusätzlich die LAPS-Richtlinie `ADPasswordEncryptionPrincipal` konfigurieren.
- Legacy Microsoft LAPS ist von Microsoft abgekündigt. Für neue Umgebungen Windows LAPS verwenden; Legacy und Windows LAPS nicht für dasselbe Konto parallel betreiben.

## Referenzen

- Windows LAPS – AD-Szenario: https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-scenarios-windows-server-active-directory
- `Update-LapsADSchema`: https://learn.microsoft.com/en-us/powershell/module/laps/update-lapsadschema
- `Set-LapsADComputerSelfPermission`: https://learn.microsoft.com/en-us/powershell/module/laps/set-lapsadcomputerselfpermission
- `Set-LapsADReadPasswordPermission`: https://learn.microsoft.com/en-us/powershell/module/laps/set-lapsadreadpasswordpermission
- `Set-LapsADResetPasswordPermission`: https://learn.microsoft.com/en-us/powershell/module/laps/set-lapsadresetpasswordpermission
- `Find-LapsADExtendedRights`: https://learn.microsoft.com/en-us/powershell/module/laps/find-lapsadextendedrights
- Legacy-LAPS-Szenarien: https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-scenarios-legacy
