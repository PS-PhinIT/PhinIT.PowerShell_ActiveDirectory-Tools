# Installation und Start

Dieses Dokument beschreibt den aktuell **verifizierten** Start- und Prüfpfad für die erste lauffähige V2-Preview.

## Ziel der aktuellen Preview

Der aktuelle Stand ist eine lokal startbare FastAPI-Webanwendung mit validierten Dry-Run-Prozessen, Dokumentationsbrowser und ersten Betriebsseiten.

## Voraussetzungen

- Windows-Umgebung mit PowerShell
- Python gemäß Projektziel `>=3.13`
- lokaler Zugriff auf das Projektverzeichnis `easyONBOARDING/V2.0.0`

## Schnellstart über die vorbereiteten Skripte

### 1. Abhängigkeiten installieren

Für die normale Installation:

`./setup_dev.ps1`

Für Entwicklung inklusive Test- und Linting-Werkzeugen:

`./setup_dev.ps1 -WithDevDependencies`

### Setup-Audit für den Management Server

Das Skript `setup_dev.ps1` prüft jetzt zusätzlich die vorgesehene Management-Server-Basis für `easyONBOARDING V2.0.0`.

Berücksichtigt werden unter anderem:

- Windows Server 2016 / 2019 / 2022 als Zielbasis
- IIS Web Server
- IIS Windows Authentication
- IIS URL Rewrite
- Python 3.13.x
- Windows PowerShell 5.1
- RSAT Active Directory Tools
- .NET Framework
- optionale Komponenten wie ARR, SQL Server, PowerShell 7, Exchange Tools, Cloud-Module und PDF-Rendering-Tools

Nützliche Varianten:

- nur prüfen: `./setup_dev.ps1 -CheckOnly`
- fehlende Pflichtkomponenten automatisch installieren: `./setup_dev.ps1`
- fehlende Pflichtkomponenten nicht automatisch installieren: `./setup_dev.ps1 -InstallMissingRequiredComponents:$false`
- optionale Komponenten wie ARR zusätzlich berücksichtigen: `./setup_dev.ps1 -InstallOptionalComponents:$true -ArrInstallerUrl <URL>`
- nur aus dem vorbereiteten Offline-Cache installieren: `./setup_dev.ps1 -OfflineOnly`
- Offline-Cache für produktive Server vorbereiten: `./setup_dev.ps1 -PrepareOfflineCache`
- lokale Sonderfälle mit nicht Ziel-konformer Python-Version erzwingen: `./setup_dev.ps1 -AllowUnsupportedPythonVersion`

## Automatische Installation bei fehlendem Python

Wenn kein Python 3.13.x gefunden wird, versucht `setup_dev.ps1` jetzt automatisch den Download und die stille Installation eines offiziellen Windows-Installers von `python.org`.

Dabei gilt:

- standardmäßig werden mehrere `3.13.x`-Download-Kandidaten nacheinander ausprobiert
- auf Servern mit Administratorrechten wird `InstallAllUsers=1` verwendet
- ohne Administratorrechte erfolgt die Installation, soweit möglich, benutzerbezogen
- nach der Installation wird die Komponentenerkennung erneut ausgeführt

Optional kann ein fester Installer-Link vorgegeben werden:

- `./setup_dev.ps1 -PythonInstallerUrl <URL>`

Optional kann auch ein lokaler Installerpfad vorgegeben werden:

- `./setup_dev.ps1 -PythonInstallerPath <PFAD>`

## Automatische Installation von Rollen und Features

Fehlende Pflichtrollen und Pflichtfeatures werden jetzt ebenfalls schrittweise nachinstalliert, sofern:

- `-CheckOnly` **nicht** gesetzt ist
- `Install-WindowsFeature` auf dem Host verfügbar ist
- das Skript mit Administratorrechten läuft

Typische automatische Kandidaten sind:

- `Web-Server`
- `Web-Windows-Auth`
- `RSAT-AD-Tools`
- ggf. `.NET Framework`-Featurekomponenten

Zusätzlich versucht das Skript bei fehlendem `IIS URL Rewrite`, den MSI-Installer automatisch herunterzuladen und still zu installieren.

## Reboot-Erkennung und Fortsetzung

Wenn eine Installation einen Neustart auslöst oder bereits ein ausstehender Neustart erkannt wird, stoppt `setup_dev.ps1` jetzt kontrolliert und legt eine State-Datei an.

Standardverhalten:

- Statusdatei: `logs/setup/setup-state.json`
- Fortsetzung erfolgt automatisch beim nächsten Start von `./setup_dev.ps1`
- letzte Phase und Reboot-Gründe werden in der State-Datei festgehalten
- nach erfolgreichem Abschluss wird die State-Datei wieder entfernt

Typische Reboot-Erkennungen:

- `Component Based Servicing`
- `Windows Update`
- `PendingFileRenameOperations`
- Exitcode `3010` von MSI-/Installer-Prozessen

Praktischer Ablauf:

1. `./setup_dev.ps1`
2. Skript meldet Reboot-Bedarf und beendet den Lauf kontrolliert.
3. Server neu starten.
4. `./setup_dev.ps1` erneut starten.
5. Das Skript erkennt die Fortsetzung automatisch.

## Saubere Install-Logs pro Komponente

Jede Installations- oder Cache-Aktion schreibt jetzt eigene Logs pro Komponente.

Standardpfad:

- `logs/setup/<run-id>/...`

Beispiele:

- `logs/setup/setup-20260503-101500/Python-3.13.x/...`
- `logs/setup/setup-20260503-101500/IIS-URL-Rewrite/...`
- `logs/setup/setup-20260503-101500/IIS-Web-Server/...`

Pro Aktion entstehen in der Regel:

- eine `.log`-Datei mit Ablauf und Meldungen
- eine `.json`-Datei mit Metadaten, Ergebnis und Exitcode
- bei MSI-Installationen zusätzlich eine `.msi.log`-Datei

## Feste Offline-Cache-Strategie für produktive Server

Für produktive oder abgeschottete Server nutzt das Setup jetzt standardmäßig einen festen Cache-first-Ansatz.

Standardstruktur:

- `setup-cache/python/python-3.13-amd64.exe`
- `setup-cache/iis/url-rewrite/rewrite_amd64_en-US.msi`
- `setup-cache/iis/arr/arr-x64.msi`

Suchreihenfolge pro Installer:

1. explizit angegebener lokaler Pfad (`-...InstallerPath`)
2. standardisierter Offline-Cache unter `setup-cache/...`
3. ähnliche Dateinamen im Cache-Ordner
4. Download und Ablage in den Cache, sofern **nicht** `-OfflineOnly` gesetzt ist

Empfohlener produktiver Ablauf:

1. Auf einem System mit Internetzugang Cache vorbereiten:
	- `./setup_dev.ps1 -PrepareOfflineCache`
2. Optional ARR lokal ergänzen:
	- `./setup_dev.ps1 -PrepareOfflineCache -ArrInstallerPath <PFAD-ZUR-ARR-MSI>`
3. Ordner `setup-cache` auf den Zielserver kopieren.
4. Installation auf dem Zielserver offline ausführen:
	- `./setup_dev.ps1 -OfflineOnly`

Wichtige Zusatzparameter:

- `-PythonInstallerPath <PFAD>`
- `-UrlRewriteInstallerPath <PFAD>`
- `-ArrInstallerPath <PFAD>`
- `-OfflineCacheRoot <PFAD>`
- `-ComponentLogRoot <PFAD>`

### 2. Entwicklungsserver starten

`./run_dev.ps1`

Standardmäßig startet die Anwendung auf:

- `http://127.0.0.1:8010`

### 3. Browser öffnen

Empfohlene erste Einstiegsseiten:

- `/dashboard`
- `/processes/onboarding`
- `/processes/offboarding`
- `/documentation`

## Manueller Start ohne Helferskripte

Falls nötig, kann die App auch manuell mit Uvicorn gestartet werden:

`python -m uvicorn app.main:app --host 127.0.0.1 --port 8010 --reload`

## Verifizierte Prüfschritte

Die folgenden Prüfungen wurden auf dem aktuellen Stand erfolgreich durchlaufen:

- `pytest`
- `ruff check app tests`
- `python -m compileall app tests`

## Aktuell verfügbare GUI-Bereiche

- `Dashboard`
- `Benutzer`
- `Onboarding`
- `Offboarding`
- `Dokumentation`
- `Jobs`
- `Einstellungen`

## Was diese erste lauffähige Version bereits kann

- serverseitig validierte Onboarding- und Offboarding-Dry-Runs
- standardisierte JSON-Vertragsbildung für spätere PowerShell-Connectoren
- lebende Dokumentation aus `/DOC`
- Doku-Suche, Bereichsindex, Markdown-Vorschau und Kontext-Hilfe-Links
- Test-, Lint- und Syntaxprüfung für den aktuellen Python-Stand

## Was bewusst noch nicht enthalten ist

- produktive AD-Schreiboperationen
- persistente Job-Queue
- Windows Authentication und Rollenprüfung
- echte Audit-Datenspeicherung
- produktive Connector-Orchestrierung

## Zielbild Produktion

- IIS als Reverse Proxy
- Python-Webprozess als App-Schicht
- separater Worker für Jobs und Connectoren
- dokumentierte Backup- und Restore-Wege

## Operative Mindestanforderungen

- nachvollziehbare Logs
- reproduzierbare Starts
- definierte Upgrade- und Rollback-Schritte
- sichtbare System- und Modulzustände in der GUI
