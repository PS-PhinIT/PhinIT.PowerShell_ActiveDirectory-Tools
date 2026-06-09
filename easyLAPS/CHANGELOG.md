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
- Reset-Logik auf Microsoft Learn abgestimmt:
	- **Windows LAPS AD-Reset** jetzt über `Set-LapsADPasswordExpirationTime` (statt ungültiger Remote-Nutzung von `Reset-LapsPassword`).
	- **Legacy-LAPS-Fallback** weiterhin über `Reset-AdmPwdPassword`.
- Erkennung von Legacy-/Windows-LAPS beim Abruf verbessert (Auswertung von `Source`/`DecryptionStatus`).
- Entschlüsselungs-/Berechtigungsfehler beim Abruf klarer behandelt (statt nur generischer „kein Passwort“-Meldung).
- Passwortabruf auf „aktuellen Wert“ stabilisiert (`Get-LapsADPassword` ohne `-IncludeHistory`), um unnötige Historien-/Sortierungsabhängigkeiten zu vermeiden.
- AD-Reset robuster gemacht:
	- Kein vorgelagerter Pflicht-Lesezugriff mehr für den Reset erforderlich.
	- Primärer Resetpfad bleibt `Set-LapsADPasswordExpirationTime` (MS Learn).
	- Legacy-Fallback (`Reset-AdmPwdPassword`) erfolgt nur bei geeignetem Kontext.
- Diagnose-ZIP-Erkennung verbessert (Regex für Windows-Pfad korrigiert).
- Passwortverarbeitung robuster gemacht: `Get-LapsADPassword`-Ergebnis wird typabhängig verarbeitet (`string` oder `SecureString`), um Konvertierungsfehler zu vermeiden.
- Rückgabestatus von `Set-LapsADPasswordExpirationTime` wird auf erwarteten Status (`PasswordReset`) geprüft, um stille Fehlschläge besser zu erkennen.
- Doppelte/überlappende GUI-Statushandler bereinigt, um redundante Statusmeldungen zu vermeiden.

### Hinzugefügt
- Optionaler GUI-Button **Diagnose** (`btnRunDiagnostics`) ergänzt.
- Optionaler GUI-Button **Run Policy (local)** (`btnRunPolicyProcessing`) ergänzt.
- Diagnose-Workflow integriert:
	- Führt `Get-LapsDiagnostics` mit Zielordner unter `Logs\Diagnostics` aus.
	- Ermittelt die erzeugte ZIP-Datei robust (Cmdlet-Output + Fallback über neuesten ZIP-Fund).
	- Öffnet die ZIP-Datei direkt nach erfolgreicher Erstellung (Fallback: öffnet Diagnosenordner).
- Lokaler Policy-Workflow integriert:
	- Führt `Invoke-LapsPolicyProcessing` auf dem lokalen System aus.
	- Gibt klaren Scope-Hinweis aus (wirkt nicht auf Remote-Zielcomputer).
	- Verweist für Ergebnisprüfung auf Event-IDs `10003/10004/10005`.

### Dokumentation
- `README.md` auf aktuellen Funktions- und Modulstand aktualisiert.
- `README.md` um Best-Practice-Verifizierung via LAPS-Eventlog (u. a. IDs 10003/10004/10005/10018/10020) erweitert.
- `README.md` um präzisierte Berechtigungs-Hinweise erweitert (Read vs. Reset vs. Entschlüsselung über `ADPasswordEncryptionPrincipal`).
