# easyLAPS – AD LAPS Passwort-Manager (GUI)

**easyLAPS** ist ein PowerShell-WPF-Tool zum Auslesen und Verwalten von LAPS-Passwörtern im Active Directory.

## 🚀 Funktionen

- LAPS-Passwort für ausgewählten Computer anzeigen
- LAPS-Passwort für Einzelcomputer zurücksetzen
- AD-Computerliste laden und per Namen filtern
- Passwort in Zwischenablage kopieren
- CSV-Export für einen oder alle Computer
- Passwortrotation für alle gelisteten Computer
- Lokaler LAPS-Status-/GPO-Check
- Optionaler **Run Policy (local)**-Button für `Invoke-LapsPolicyProcessing` (nur lokales System)
- Optionaler **Diagnose**-Button für `Get-LapsDiagnostics` (ZIP wird nach Erstellung direkt geöffnet)
- Unterstützung für:
	- **Windows LAPS** (`Get-LapsADPassword`, `Set-LapsADPasswordExpirationTime`)
	- **Legacy LAPS (AdmPwd)** (`Get-AdmPwdPassword`, `Reset-AdmPwdPassword`)

> Hinweis zur Rotation gemäß Microsoft Learn: Für **AD-Objekte** wird das Passwort über
> `Set-LapsADPasswordExpirationTime` auf „abgelaufen“ gesetzt. Die tatsächliche Rotation
> erfolgt beim nächsten LAPS-Policy-Processing auf dem Zielgerät.

> Hinweis zu Berechtigungen: Für das Auslesen wird i. d. R. Leserechte benötigt,
> für das Zurücksetzen in AD dagegen die Berechtigung zum Setzen der Expiration Time
> (siehe `Set-LapsADResetPasswordPermission`). Das Tool behandelt beide Pfade getrennt.

> Erweiterter Berechtigungshinweis (MS Learn):
> - Leserechte auf OU-Ebene über `Set-LapsADReadPasswordPermission`
> - Expiration-Reset-Rechte über `Set-LapsADResetPasswordPermission`
> - Bei verschlüsselten Kennwörtern zusätzlich Entschlüsselungsberechtigung über die Richtlinie `ADPasswordEncryptionPrincipal`

## 🧩 Voraussetzungen

- **Windows PowerShell 5.1** (GUI/WPF)
- **ActiveDirectory-Modul** (für `Get-ADComputer`)
- Mindestens ein unterstützter LAPS-Pfad:
	- Windows LAPS Modul **oder**
	- Legacy LAPS Cmdlets (AdmPwd)

## ▶️ Verwendung

1. Skript in **Windows PowerShell 5.1** starten.
2. AD-Liste laden.
3. Computer auswählen oder Namen eingeben.
4. Passwort anzeigen / zurücksetzen / exportieren.
5. Optional: **Diagnose** klicken, um LAPS-Logs als ZIP zu erzeugen und direkt zu öffnen.
6. Optional: **Run Policy (local)** klicken, um sofort eine lokale LAPS-Policy-Verarbeitung anzustoßen.

## ✅ Verifizierung im Eventlog (Best Practice)

Für eine schnelle Erfolgskontrolle nach Policy-/Reset-Aktionen prüfe im Kanal
`Applications and Services Logs > Microsoft > Windows > LAPS > Operational` insbesondere:

- `10003` = Policy Processing gestartet
- `10004` = Policy Processing erfolgreich
- `10005` = Policy Processing fehlgeschlagen
- `10018` = Passwort erfolgreich in AD aktualisiert
- `10020` = lokales Admin-Konto erfolgreich aktualisiert

## 🔐 Hinweis

CSV-Exporte enthalten das Passwort im Klartext und sollten nur in geschützten Speicherorten abgelegt werden.

## 📚 MS Learn Referenzen

- Windows LAPS PowerShell Overview: https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-management-powershell
- `Get-LapsADPassword`: https://learn.microsoft.com/en-us/powershell/module/laps/get-lapsadpassword
- `Set-LapsADPasswordExpirationTime`: https://learn.microsoft.com/en-us/powershell/module/laps/set-lapsadpasswordexpirationtime
- `Set-LapsADReadPasswordPermission`: https://learn.microsoft.com/en-us/powershell/module/laps/set-lapsadreadpasswordpermission
- `Set-LapsADResetPasswordPermission`: https://learn.microsoft.com/en-us/powershell/module/laps/set-lapsadresetpasswordpermission
- `Reset-LapsPassword` (lokaler Account): https://learn.microsoft.com/en-us/powershell/module/laps/reset-lapspassword
- `Invoke-LapsPolicyProcessing`: https://learn.microsoft.com/en-us/powershell/module/laps/invoke-lapspolicyprocessing
- AD-Szenario (Setup/Berechtigungen/Rotation): https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-scenarios-windows-server-active-directory
- Eventlog-Referenz: https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-management-event-log
- Legacy-Emulation und Einschränkungen: https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-scenarios-legacy
- Troubleshooting (Event IDs): https://learn.microsoft.com/en-us/troubleshoot/windows-server/windows-security/windows-laps-troubleshooting-guidance

## 📝 Changelog

Siehe `CHANGELOG.md`.
