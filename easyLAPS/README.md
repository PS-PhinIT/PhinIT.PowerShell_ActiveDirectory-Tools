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
- Unterstützung für:
	- **Windows LAPS** (`Get-LapsADPassword`, `Reset-LapsPassword`)
	- **Legacy LAPS (AdmPwd)** (`Get-AdmPwdPassword`, `Reset-AdmPwdPassword`)

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

## 🔐 Hinweis

CSV-Exporte enthalten das Passwort im Klartext und sollten nur in geschützten Speicherorten abgelegt werden.

## 📝 Changelog

Siehe `CHANGELOG.md`.
