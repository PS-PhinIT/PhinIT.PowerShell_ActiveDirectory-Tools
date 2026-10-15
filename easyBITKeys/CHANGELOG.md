# Changelog

Alle relevanten Änderungen an `easyBITKEYS` werden hier dokumentiert.
Die Versionsnummer wird ausschließlich im Skript (`$ScriptVersion`), in `README.md` und in dieser Datei gepflegt – nicht im Dateinamen.

## [0.7.0] - 2026-10-14

### Added
- Spalte **Key ID** (aus `msFVE-RecoveryGuid`) – entspricht der Wiederherstellungsschlüssel-ID auf dem BitLocker-Wiederherstellungsbildschirm; neues Suchfeld „Key ID“ (Klammern werden ignoriert).
- Computer **ohne** gespeicherten Wiederherstellungsschlüssel werden grau aufgeführt (`$ShowComputersWithoutKey`), neuer Filter „No key available“.
- Erkennung fehlender Leserechte auf das vertrauliche Attribut `msFVE-RecoveryPassword` (Hinweis beim Laden und in der Statuszeile).
- Statuszeile unter der Tabelle (Domain/OU, Anzahl Schlüssel, Computer mit/ohne Schlüssel, Warnungen).
- Konfiguration `$ADServer` und `$ADSearchBase` für andere Domains bzw. Einschränkung auf eine OU (gilt für Abfrage, Selbstdiagnose und Entfernen).
- Client Mode wird beim Start mit Ursache gemeldet und in Fenstertitel/Statuszeile als „SAMPLE DATA“ gekennzeichnet.

### Fixed
- Computername wird über das übergeordnete Computerobjekt ermittelt (statt nur aus dem CN-Text).
- Einträge ohne Schlüssel erscheinen nicht mehr im Altersfilter „Critical“.
- Entfernen prüft vor der Bestätigung, ob ein AD-Objekt existiert, und zeigt Computer, Key ID und Datum an; Fehler von `Remove-ADObject` werden zuverlässig gemeldet.
- Tabellenaktualisierung ohne `Dispatcher.Invoke`-Umweg (Aufruf erfolgt bereits im UI-Thread); Wartecursor während der AD-Abfrage.

### Changed
- Tabelle sortiert initial nach Computername und neuestem Schlüssel zuerst.
- Beispieldaten im Client Mode im echten 48-stelligen Schlüsselformat.
- CSV-Export enthält die Key ID.

## [0.6.0] - 2026-10-14

### Security
- Neustart unter Windows PowerShell 5.1 erfolgt nicht mehr mit `-Verb RunAs` (keine unnötige Rechteerhöhung/UAC; AD-Lesezugriff benötigt keine lokalen Adminrechte).
- Neustart nur noch aus PowerShell 7 (Core) heraus; im EXE-Modus ohne `$PSCommandPath` kein fehlerhafter Neustart mehr. `#Requires -Version 5.1` ergänzt.
- XAML-Platzhalter werden nicht mehr per `ExpandString` (dynamische Code-Auswertung) ersetzt, sondern gezielt und XML-maskiert.
- Zwischenablage wird nach dem Kopieren eines Wiederherstellungsschlüssels nach 30 Sekunden sowie beim Schließen automatisch geleert (nur wenn sie noch den kopierten Key enthält).
- Hinweis auf Klartext-Schlüssel nach CSV-Export.
- Suchbegriffe werden nicht mehr ins Log geschrieben (Suche nach Key-Fragmenten landete im Klartext im Log).
- Eingebautes Zeilen-Kopieren des DataGrids (`Strg+C` kopierte die ganze Zeile inkl. Key ohne Auto-Löschen) deaktiviert; `Strg+C` nutzt jetzt die Copy-Key-Logik mit Auto-Löschen.
- Sucheingaben werden als Literal behandelt (Wildcard-Zeichen wie `[` `*` werden maskiert).

### Fixed
- Selbstdiagnose (`Test-Requirements`) läuft jetzt **vor** dem Import des AD-Moduls (vorher erst nach dem Import – Client-Mode-Entscheidung kam zu spät).
- Datumsspalte sortiert chronologisch (`SortMemberPath` auf DateTime-Feld `DatumSort`) statt alphabetisch nach `dd.MM.yyyy`.
- Eigener Sortier-Handler entfernt, der parallel zur eingebauten DataGrid-Sortierung lief und die Absteigend-Sortierung verhinderte.
- Legende und Filter widersprachen sich (`> 6 months` vs. `7-12 months`); Legende vereinheitlicht und um Eintrag „No key available“ (grau) ergänzt.
- Computername wird robust aus dem DN ermittelt (Split nur an unmaskierten Kommas).
- Fehlendes `whenCreated` führt nicht mehr zum Abbruch der gesamten Abfrage (Eintrag wird grau markiert).
- „Refresh“ meldet keinen Erfolg mehr, wenn die AD-Abfrage fehlgeschlagen ist.
- Skriptdatei als UTF-8 **mit BOM** gespeichert, damit Umlaute unter Windows PowerShell 5.1 korrekt dargestellt werden.

### Changed
- Skriptdatei ohne Versionsnummer: `easyBITKEYS_V0.5.1.ps1` → `easyBITKEYS.ps1`.
- Fenster ist jetzt in der Größe veränderbar (`ResizeMode="CanResize"`).
- Filter nutzt das gespeicherte DateTime-Feld statt mehrfacher String-Parsing-Versuche.

### Performance
- CSV-Export ohne Array-Verkettung (`+=`, O(n²)) – direkte Pipeline mit `Select-Object`.
- Doppelte `Add-Type`-Aufrufe und ungenutzte Variablen (`$LogFile`, `$LogFileName`) entfernt.

### Removed
- Alte Versionen (`# OLD`: 0.3.5, 0.4.2, ZIP-Archiv, Assets) und alle Screenshots aus dem Repository entfernt.

### Documentation
- `README.md` aktualisiert (Dateiname, Voraussetzungen ohne Adminrechte, Sortierung, Zwischenablage, Logging, Sicherheitshinweise).

## [0.5.3] - 2026-06-09

### Changed
- Alle GUI-Verweise auf externe Assets entfernt (Logo/Icons/URLs).
- Header-Logo aus dem XAML entfernt.
- Info-/Exit-Buttons auf feste Textdarstellung (`i` / `X`) umgestellt.
- Asset-Ladecode (`assets/*.png`) vollständig aus der GUI-Initialisierung entfernt.
- Asset-Checks aus `Test-Requirements` entfernt.

### Result
- GUI läuft vollständig ohne externe Dateien und ohne externe Links.

## [0.5.2] - 2026-06-09

### Fixed
- Fehler behoben, bei dem `Join-Path` mit `NULL` für `$script:ScriptRoot` aufgerufen wurde.
- Doppelte Registrierung des `btnExit`-Click-Handlers entfernt.
- Event-Registrierungen (Search-Enter, DataGrid-Loaded) zeitlich korrigiert (jetzt vor `ShowDialog()`).
- Client-Mode robuster gemacht (kein Löschen ohne AD-Kontext, klare Hinweise in der GUI).
- Fallback-Handling für fehlende GUI-Assets verbessert (Info/Close Text-Fallback).

### Changed
- Script-Version auf `0.5.2` angehoben.
- Selbstdiagnose (`Test-Requirements`) so angepasst, dass fehlende Assets/fehlende AD-Rechte nicht mehr hart abbrechen, sondern in den Client-Mode wechseln.
- Header-Logo-Verhalten toleranter gemacht (fehlende Datei blendet Logo aus, kein Abbruch).
- Such-/Filter-Grunddaten werden nach jedem Refresh sauber neu gesetzt.
- Externe URL-Öffnung aus der GUI standardmäßig deaktiviert (`$HeaderLogoURL = ""`).

### Documentation
- `README.md` vollständig aktualisiert (Standalone-Betrieb, Client-Mode, aktuelle Nutzung).
- `CHANGELOG.md` neu eingeführt.

## [0.4.2] - 2025-05-23

### Changed
- GUI von Windows Forms (`DataGridView`) auf WPF (XAML) umgestellt (Header, Navigation, Footer).
- INI-Datei-Verwaltung entfernt; Konfiguration direkt am Anfang des Skripts.
- Farbschwellen auf < 7 Monate / 7–12 Monate / ≥ 12 Monate angepasst.

### Added
- Suche (Computername, BitLocker-Key, alle Felder) und Altersfilter.
- Spaltensortierung, Key in Zwischenablage kopieren, Info-Dialog.
- Logging (`Logs\easyBITKEYS_<Datum>.log`), Debug-Modus und Selbstdiagnose (`Test-Requirements`).
- Client Mode mit Beispieldaten ohne AD-Modul.

### Notes
- Baseline vor den Stabilitätsfixes in 0.5.2. Rekonstruiert aus der Git-Historie (Commit `6fd1d0f`).

## [0.3.5] - 2025-03-02

### Added
- Älteste archivierte Version (`PhinIT-easyBITKEYS`, PowerShell 5.1).
- Auslesen aller `msFVE-RecoveryInformation`-Objekte aus AD in einer farbcodierten Windows-Forms-GUI.
- CSV-Export, Löschen des markierten Eintrags nach Bestätigung.
- Farbschwellen < 3 / 6 / 12 Monate; Header-/Footer-Branding über INI-Datei.

### Notes
- Rekonstruiert aus dem Skript-Header der archivierten Version (Commit `6fd1d0f`).
