# Changelog

Alle nennenswerten Änderungen an `easyLAPS` werden in dieser Datei dokumentiert.
Die Versionsnummer wird ausschließlich im Skript (`ScriptVersion`), in `README.md` und in dieser Datei gepflegt – nicht im Dateinamen.

## [0.4.0] - 2026-10-14

### Sicherheit
- Zwischenablage wird nach dem Kopieren eines LAPS-Passworts nach 30 Sekunden sowie beim Schließen des Tools automatisch geleert (nur wenn sie noch das kopierte Passwort enthält).
- Auswahl in der AD-Liste lädt das Passwort **nicht mehr automatisch** – Abruf nur noch bewusst per Doppelklick, Enter oder **Show Password** (kein unbeabsichtigtes Auslesen/Protokollieren beim Durchblättern).
- `Strg+C` kopiert das Passwort nur noch, wenn in einem Textfeld keine Markierung besteht (normales Kopieren bleibt möglich).
- Debug-Einträge werden nur noch im Debug-Modus geschrieben.
- Kein automatisches Öffnen von Webseiten (Microsoft Learn) mehr beim Start; toter Logo-Link inkl. `Open-URLInBrowser` entfernt.
- `#Requires -Version 5.1` ergänzt.

### Behoben
- **Copy Password** nutzte `Set-Clipboard -Text` (Parameter existiert nicht) und kopierte ggf. Platzhaltertexte – kopiert jetzt das zuletzt abgerufene Passwort.
- Lokale LAPS-Statusprüfung prüfte falsche/unvollständige Registry-Pfade; jetzt in Microsoft-Reihenfolge: CSP (`HKLM\Software\Microsoft\Policies\LAPS`), GPO (`HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\LAPS`), lokale Konfiguration (`...\CurrentVersion\LAPS\Config`) und Legacy (`HKLM\Software\Policies\Microsoft Services\AdmPwd`); Erkennung von `laps.dll`/LAPS-Modul/`AdmPwd.dll`.
- Filter mit genau einem Treffer lieferte einen String statt einer Liste (fehlerhafte Anzeige) – Ergebnis wird als Array behandelt; Sonderzeichen im Filter werden maskiert.
- Reset zeigte ein erfundenes „Last Set“-Datum – zeigt jetzt „als abgelaufen markiert“ und die Ablaufzeit; Rotation erfolgt beim nächsten Policy-Processing.
- Log-Rotation lief bei jedem Logeintrag statt einmal pro Start.
- Fehlender Datei-Verweis `resources\logo.png` (Header-Logo) entfernt.
- WPF-Assemblies werden vor den Versions-/Modulprüfungen geladen (MessageBoxen bei fehlenden Voraussetzungen funktionierten nicht).
- `Get-WmiObject` durch `Get-CimInstance` ersetzt bzw. entfernt.
- Skriptdatei als UTF-8 **mit BOM** gespeichert, damit Umlaute unter Windows PowerShell 5.1 korrekt dargestellt werden.

### Geändert
- Skriptdatei ohne Versionsnummer: `easyLAPS_V0.3.4.ps1` → `easyLAPS.ps1`.
- Responsives Layout: Fenster skalierbar (Mindestgröße 700×1000), Liste und Statusbereich füllen den verfügbaren Platz, Buttons umbrechen statt fester Margins.
- Statusprüfung (Button und Start) in einer gemeinsamen Routine zusammengeführt; Statusfenster scrollt automatisch ans Ende.
- Wartecursor bei AD-Liste, Export All und Rotate All.
- Installationsdateien von `# LAPS Install` nach `Install/` verschoben.

### Performance
- Export und Rotation sammeln Ergebnisse in einer `List[object]` statt Array-Verkettung (`+=`).
- AD-Abfrage ohne unnötiges `-Properties Name` (Standardattribut).

### Entfernt
- Alte Versionen (`# Old`: 0.0.14, 0.1.3, 0.2.1 inkl. EXE) und alle Screenshots aus dem Repository entfernt.

### Dokumentation
- `README.md` aktualisiert (Version, Bedienung, Zwischenablage, Statusprüfung, Ordnerstruktur).
- `Install/README.md` neu (Installationsskript, Schema-Update-Hinweis, Legacy-MSI).

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
- `CHANGELOG.md` neu eingeführt.

### Hinweise
- Export Selected/Export All und Rotate All waren bereits im Stand vom 2026-01-19 enthalten (interne Versionskennung damals noch `0.1.3`).
- Alte Versionen nach `# Old` verschoben, `SimpleLapsGui.ps1` entfernt.

## [0.2.1]

### Hinzugefügt
- EXE-Kompatibilität (PS2EXE): Pfadermittlung für Skript- und EXE-Modus, kompilierte `easyLAPS_V0.2.1.exe`.
- Erweiterte Abruf-/Reset-Funktionen mit Windows-LAPS- und Legacy-Fallback.

### Hinweise
- Veröffentlichungsdatum nicht überliefert (vor 2026-01-19); interne Versionskennung im Skript war `0.1.3`. Rekonstruiert aus der Git-Historie (Commit `6fd1d0f`).

## [0.1.3]

### Geändert
- INI-Datei durch Konfiguration im Skript (`ScriptInfo`/GUI-Hashtable) ersetzt.
- Benutzereinstellungen in der Registry (`HKCU:\Software\easyIT\easyLAPS`).

### Hinzugefügt
- Log-Rotation, Footer mit Version/Datum/Autor, Buttons Refresh / Get / Reset / Copy / Check Status.

### Hinweise
- Veröffentlichungsdatum nicht überliefert (vor 2026-01-19). Rekonstruiert aus der Git-Historie (Commit `6fd1d0f`).

## [0.0.14]

### Hinzugefügt
- Erste archivierte Version: WPF-GUI (XAML) zum Anzeigen und Zurücksetzen von LAPS-Passwörtern.
- Konfiguration (Branding, Footer-Platzhalter `{ScriptVersion}`, `{LastUpdate}`, `{Author}`) über INI-Datei.

### Hinweise
- Veröffentlichungsdatum nicht überliefert (vor 2026-01-19). Rekonstruiert aus der Git-Historie (Commit `6fd1d0f`).
