# easyBITKEYS

**Version:** 0.7.0  
**Datei:** `easyBITKEYS.ps1`  
**Autor:** Andreas Hepp  
**Letztes Update:** 14.10.2026

`easyBITKEYS` liest BitLocker-Wiederherstellungsschlüssel (`msFVE-RecoveryInformation`) aus Active Directory und zeigt sie in einer WPF-GUI farbcodiert an.

## Funktionen

- AD-Abfrage aller BitLocker-Wiederherstellungsschlüssel (optional eingeschränkt auf Server/Domain und OU)
- **Key ID** (Wiederherstellungsschlüssel-ID) je Eintrag – entspricht der ID auf dem BitLocker-Wiederherstellungsbildschirm; Suche über das Suchfeld „Key ID“ (die ersten 8 Zeichen genügen)
- **Computer ohne gespeicherten Schlüssel** werden grau mit aufgeführt (abschaltbar)
- Erkennung fehlender Leserechte: Sind Wiederherstellungsobjekte sichtbar, das Attribut `msFVE-RecoveryPassword` aber leer, erscheint ein Hinweis
- Statuszeile mit Domain/OU, Anzahl Schlüssel, Computer mit/ohne Schlüssel und Warnungen
- Farbliche Bewertung nach Alter:
  - **Grau**: kein Key vorhanden bzw. nicht lesbar
  - **Grün**: jünger als 7 Monate
  - **Orange**: 7 bis unter 12 Monate
  - **Rot**: 12 Monate oder älter
- Suche (Computername, Key ID, Key oder alle Felder) und Filter (Alter, „No key available“)
- Spaltensortierung per Klick auf den Spaltenkopf (auf-/absteigend, Datum chronologisch)
- CSV-Export der aktuell angezeigten Einträge inkl. Key ID (berücksichtigt Suche/Filter)
- Key in Zwischenablage kopieren (`Copy Key` oder `Strg+C` in der Liste) – die Zwischenablage wird nach **30 Sekunden** automatisch geleert (`$ClipboardClearSeconds`, `0` = deaktiviert) sowie beim Schließen des Tools
- Entfernen eines AD-Eintrags nach Bestätigung mit Computername, Key ID und Datum (nur im AD-Modus)

## Konfiguration

Am Anfang von `easyBITKEYS.ps1`:

| Variable | Standard | Bedeutung |
|---|---|---|
| `$ADServer` | leer | Domain-Controller oder Domain (leer = Domain des angemeldeten Benutzers) |
| `$ADSearchBase` | leer | OU, auf die die Abfrage beschränkt wird (leer = gesamte Domain) |
| `$ShowComputersWithoutKey` | `$true` | Computer ohne Wiederherstellungsschlüssel grau anzeigen |
| `$ClipboardClearSeconds` | `30` | Zwischenablage automatisch leeren (`0` = aus) |

## Standalone-Verhalten

Das Tool läuft **eigenständig** ohne externe Konfigurationsdatei:

- Keine INI-Datei erforderlich – die Konfiguration steht am Anfang von `easyBITKEYS.ps1`
- GUI nutzt **keine externen Assets** (keine Logo-/Icon-Dateien)
- GUI öffnet **keine externen URLs**

Wenn das AD-Modul fehlt oder das AD nicht erreichbar ist, schaltet das Tool in den **Client Mode** (Beispieldaten, Entfernen deaktiviert). Der Client Mode wird beim Start mit Ursache gemeldet und in Fenstertitel und Statuszeile deutlich angezeigt.

## Voraussetzungen

- **Windows PowerShell 5.1** – wird das Skript unter PowerShell 7 gestartet, startet es sich automatisch (ohne Rechteerhöhung) in Windows PowerShell 5.1 neu
- Für echten AD-Betrieb:
  - RSAT / ActiveDirectory-Modul
  - Leserechte auf `msFVE-RecoveryInformation` **inkl. des vertraulichen Attributs `msFVE-RecoveryPassword`** (standardmäßig nur Domänen-Admins; sonst per Delegation „Read msFVE-RecoveryPassword“ auf der OU)
  - Löschrechte nur bei Nutzung der Remove-Funktion
- Lokale Administratorrechte sind **nicht** erforderlich

## Nutzung

1. `easyBITKEYS.ps1` in Windows PowerShell 5.1 starten.
2. Die GUI lädt AD-Daten oder automatisch Beispieldaten (Client Mode).
3. Navigation links: `Refresh List`, `Export CSV`, `Copy Key`, `Remove Key`.
4. Suche/Filter oben im Inhaltsbereich, Sortierung über die Spaltenköpfe.

## Logging

Logs werden unter `Logs\easyBITKEYS_<yyyy-MM-dd>.log` neben dem Skript geschrieben (Fallback: `%TEMP%\easyBITKEYS_fallback.log`). Wiederherstellungsschlüssel und Suchbegriffe werden **nicht** geloggt.

## Sicherheitshinweise

- CSV-Exporte enthalten Wiederherstellungsschlüssel im **Klartext** – nur an geschützten Orten ablegen und nach Gebrauch löschen.
- Exporte und Logs sind per `.gitignore` von der Versionsverwaltung ausgeschlossen.
- Siehe auch [`SECURITY.md`](../SECURITY.md).

## Changelog

Siehe [`CHANGELOG.md`](CHANGELOG.md).

## Lizenz

MIT-Lizenz, siehe [`LICENSE`](LICENSE).
