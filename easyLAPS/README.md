# easyLAPS – AD LAPS Passwort-Manager (GUI)

**Version:** 0.4.0  
**Datei:** `easyLAPS.ps1`  
**Autor:** Andreas Hepp  
**Letztes Update:** 14.10.2026

**easyLAPS** ist ein PowerShell-WPF-Tool zum Auslesen und Verwalten von LAPS-Passwörtern im Active Directory.

## 🚀 Funktionen

- LAPS-Passwort für ausgewählten Computer anzeigen
- LAPS-Passwort für Einzelcomputer zurücksetzen
- AD-Computerliste laden und per Namen filtern
- Passwort in Zwischenablage kopieren – wird nach **30 Sekunden** und beim Schließen automatisch geleert
- CSV-Export für einen oder alle Computer
- Passwortrotation für alle gelisteten Computer
- Lokaler LAPS-Status-/Richtlinien-Check (Windows LAPS `laps.dll`/Modul, Legacy `AdmPwd.dll`; Richtlinienquellen CSP, GPO, lokale Konfiguration, Legacy)
- Skalierbares Fenster (Mindestgröße 700×1000)
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

1. `easyLAPS.ps1` in **Windows PowerShell 5.1** starten.
2. AD-Liste laden (optional mit Filter, `Strg+F`).
3. Computer in der Liste auswählen (übernimmt nur den Namen) oder Namen eingeben.
4. Passwort per **Doppelklick**, `Enter` oder **Show Password** abrufen – die Auswahl allein liest kein Passwort aus.
5. Passwort kopieren (`Copy Password` bzw. `Strg+C` ohne Textmarkierung), zurücksetzen oder exportieren.
6. Optional: **Diagnose** klicken, um LAPS-Logs als ZIP zu erzeugen und direkt zu öffnen.
7. Optional: **Run Policy (local)** klicken, um sofort eine lokale LAPS-Policy-Verarbeitung anzustoßen.

## ✅ Verifizierung im Eventlog (Best Practice)

Für eine schnelle Erfolgskontrolle nach Policy-/Reset-Aktionen prüfe im Kanal
`Applications and Services Logs > Microsoft > Windows > LAPS > Operational` insbesondere:

- `10003` = Policy Processing gestartet
- `10004` = Policy Processing erfolgreich
- `10005` = Policy Processing fehlgeschlagen
- `10018` = Passwort erfolgreich in AD aktualisiert
- `10020` = lokales Admin-Konto erfolgreich aktualisiert

## 🔐 Sicherheitshinweise

- CSV-Exporte enthalten Passwörter im **Klartext** – nur in geschützten Speicherorten ablegen und nach Gebrauch löschen.
- Passwörter werden nicht geloggt; Logs liegen unter `Logs\` neben dem Skript (rotierend).
- Benutzereinstellungen: `HKCU:\Software\easyIT\easyLAPS`.
- Siehe auch [`SECURITY.md`](../SECURITY.md).

## 📁 Ordnerstruktur

```
easyLAPS/
├── easyLAPS.ps1        # GUI-Tool
├── README.md
├── CHANGELOG.md
├── LICENSE
└── Install/            # LAPS-Installations-/Schema-Skript und Legacy-MSI (siehe Install/README.md)
```

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

Siehe [`CHANGELOG.md`](CHANGELOG.md).

## ⚖️ Lizenz

MIT-Lizenz, siehe [`LICENSE`](LICENSE).
