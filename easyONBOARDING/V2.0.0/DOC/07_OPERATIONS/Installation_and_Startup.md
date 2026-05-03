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
