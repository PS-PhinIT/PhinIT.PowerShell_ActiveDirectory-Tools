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

- Windows-Server-Profile ab Build `9600` als tolerierte Zielbasis
- bevorzugt: Windows Server 2019 / 2022 / 2025
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
- optionale Komponenten wie ARR direkt mit installieren: `./setup_dev.ps1 -InstallOptionalComponents:$true -ArrInstallerUrl <URL>`
- optionale Komponenten interaktiv anbieten lassen: Standardverhalten mit `-OfferOptionalComponents:$true`
- nur aus dem vorbereiteten Offline-Cache installieren: `./setup_dev.ps1 -OfflineOnly`
- Offline-Cache für produktive Server vorbereiten: `./setup_dev.ps1 -PrepareOfflineCache`
- automatische Fortsetzung per Scheduled Task deaktivieren: `./setup_dev.ps1 -EnableAutoResumeScheduledTask:$false`
- Neustart bei Pending-Reboot am Laufende anbieten: Standardverhalten mit `-OfferRestartAtEnd:$true`
- Pending-Reboot automatisch sofort auslösen: `./setup_dev.ps1 -RestartAutomaticallyIfNeeded:$true`
- IIS-Proxysite und App-Pool optional anlegen: `./setup_dev.ps1 -ConfigureIis -IisPort 8080 -PythonBackendPort 8010`
- Projektdaten gezielt in Betriebsordner kopieren: `./setup_dev.ps1 -CopyProjectData -ProjectDataRoot D:\easyONBOARDING-V2\runtime`
- lokale Sonderfälle mit nicht Ziel-konformer Python-Version erzwingen: `./setup_dev.ps1 -AllowUnsupportedPythonVersion`

## Automatische Installation bei fehlendem Python

Wenn kein Python 3.13.x gefunden wird, versucht `setup_dev.ps1` jetzt automatisch den Download und die stille Installation eines offiziellen Windows-Installers von `python.org`.

Dabei gilt:

- standardmäßig werden mehrere `3.13.x`-Download-Kandidaten nacheinander ausprobiert
- auf Servern mit Administratorrechten wird `InstallAllUsers=1` verwendet
- ohne Administratorrechte erfolgt die Installation, soweit möglich, benutzerbezogen
- das Setup setzt jetzt zusätzlich ein festes Zielverzeichnis für Python 3.13 und prüft danach auch Registry-, Launcher- und bekannte Installationspfade
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

Standardquellen sind jetzt die offiziellen IIS-/Microsoft-Downloads:

- `IIS URL Rewrite 2.1 x64` über die offiziellen Download-Links der IIS-Seite
- `ARR 3.0 x64` über den offiziellen Microsoft-FWLink

## Reboot-Erkennung und Fortsetzung

Wenn eine Installation einen Neustart auslöst oder bereits ein ausstehender Neustart erkannt wird, stoppt `setup_dev.ps1` jetzt kontrolliert und legt eine State-Datei an.

Standardverhalten:

- Statusdatei: `logs/setup/setup-state.json`
- Fortsetzung erfolgt automatisch beim nächsten Start von `./setup_dev.ps1`
- letzte Phase und Reboot-Gründe werden in der State-Datei festgehalten
- nach erfolgreichem Abschluss wird die State-Datei wieder entfernt
- wenn möglich, wird zusätzlich ein Scheduled Task `easyONBOARDING-V2-Setup-Resume` registriert

Typische Reboot-Erkennungen:

- `Component Based Servicing`
- `Windows Update`
- `PendingFileRenameOperations`
- Exitcode `3010` von MSI-/Installer-Prozessen

Praktischer Ablauf:

1. `./setup_dev.ps1`
2. Skript meldet Reboot-Bedarf und beendet den Lauf kontrolliert.
3. Server neu starten.
4. Entweder startet die Fortsetzung automatisch per Scheduled Task oder `./setup_dev.ps1` wird erneut manuell gestartet.
5. Das Skript erkennt die Fortsetzung automatisch.

Zusätzlich gilt jetzt:

- bei interaktiven Läufen wird am Ende eines pausierten Laufs ein sofortiger Neustart aktiv angeboten
- mit `-RestartAutomaticallyIfNeeded:$true` kann der Neustart direkt ausgelöst werden
- in nicht-interaktiven Läufen bleibt es bei sauberem Logging und klarer Handlungsaufforderung

## Automatische Fortsetzung per Scheduled Task

Wenn Administratorrechte und die Windows-Scheduled-Task-Cmdlets verfügbar sind, registriert das Setup beim Reboot-Bedarf automatisch einen Task:

- Taskname Standard: `easyONBOARDING-V2-Setup-Resume`
- Ausführungskontext: `SYSTEM`
- Trigger: `AtStartup`
- nach erfolgreichem Abschluss wird der Task wieder entfernt

Anpassbar über:

- `-ResumeScheduledTaskName <NAME>`
- `-EnableAutoResumeScheduledTask:$false`

## Optionale Komponenten anbieten

Der Setup-Lauf kann fehlende optionale Komponenten jetzt nicht nur über Parameter, sondern auch interaktiv anbieten.

Aktuell wird insbesondere berücksichtigt:

- `IIS Application Request Routing (ARR)`

Verhalten:

- wenn `-InstallOptionalComponents:$true` gesetzt ist, werden unterstützte optionale Komponenten direkt verarbeitet
- wenn `-InstallOptionalComponents:$false` und `-OfferOptionalComponents:$true` aktiv ist, fragt das Skript in interaktiven Sitzungen nach
- in nicht-interaktiven Sitzungen wird stattdessen ein klarer Hinweis ausgegeben

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
- pro Lauf zusätzlich:
	- `run-summary.json`
	- `run-summary.md`

## Feste Offline-Cache-Strategie für produktive Server

Für produktive oder abgeschottete Server nutzt das Setup jetzt standardmäßig einen festen Cache-first-Ansatz.

Standardstruktur:

- `setup-cache/python/python-3.13-amd64.exe`
- `setup-cache/iis/url-rewrite/rewrite_amd64_en-US.msi`
- `setup-cache/iis/arr/arr-x64.msi`
- `setup-cache/installer-manifest.json`

Suchreihenfolge pro Installer:

1. explizit angegebener lokaler Pfad (`-...InstallerPath`)
2. standardisierter Offline-Cache unter `setup-cache/...`
3. ähnliche Dateinamen im Cache-Ordner
4. Download und Ablage in den Cache, sofern **nicht** `-OfflineOnly` gesetzt ist

## Hash- und Manifest-Validierung

Jeder Installer im Cache wird jetzt in einem Manifest erfasst:

- Standardpfad: `setup-cache/installer-manifest.json`
- pro Datei werden u. a. gespeichert:
	- Komponente
	- relativer Pfad
	- Dateiname
	- Größe
	- `SHA-256`
	- Quelle / SourceReference

Verhalten:

- Downloads und explizit angegebene lokale Installer werden beim Cachen automatisch in das Manifest aufgenommen
- bei bestehendem Cache prüft das Setup die `SHA-256` gegen das Manifest
- bei Hash-Abweichung bricht das Setup mit einer klaren Fehlermeldung ab
- nicht erfasste Cache-Dateien werden mit Warnung in das Manifest übernommen

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
- `-InstallerManifestPath <PFAD>`
- `-ComponentLogRoot <PFAD>`
- `-SetupStatePath <PFAD>`
- `-ResumeScheduledTaskName <NAME>`
- `-OfferRestartAtEnd:$false`
- `-RestartAutomaticallyIfNeeded:$true`
- `-OfferOptionalComponents:$false`

## Optionale IIS-Konfiguration

Mit `-ConfigureIis` richtet das Setup jetzt auf Wunsch direkt ein einfaches IIS-Betriebsprofil ein:

- dedizierter App-Pool `easyONBOARDING-V2`
- dedizierte Site `easyONBOARDING-V2`
- `web.config` mit Reverse-Proxy-Regel auf den lokalen Python-Port
- Windows Authentication an, Anonymous Authentication aus
- Versuch, die serverweite ARR-Proxyfunktion zu aktivieren, sofern ARR/AppCmd verfügbar ist

Wichtige Parameter:

- `-ConfigureIis`
- `-IisSiteName <NAME>`
- `-IisAppPoolName <NAME>`
- `-IisPhysicalPath <PFAD>`
- `-IisPort <PORT>`
- `-IisHostHeader <HOST>`
- `-PythonBackendPort <PORT>`

Beispiel:

- `./setup_dev.ps1 -ConfigureIis -IisPort 8080 -IisHostHeader onboarding.intern -PythonBackendPort 8010`

## Sinnvolle Datenkopie in Betriebsordner

Mit `-CopyProjectData` kopiert das Setup jetzt definierte Projektordner in einen separaten Betriebsdatenpfad.

Standardziel:

- `deploy/project-data`

Kopiert werden aktuell:

- `config`
- `data`
- `DOC`
- `modules`

Das ist besonders sinnvoll für:

- vorbereitete Zielordner auf Management-Servern
- getrennte Runtime-/Betriebsdatenpfade
- spätere Backup- und Restore-Konzepte

Anpassbar über:

- `-CopyProjectData`
- `-ProjectDataRoot <PFAD>`
- `-DeploymentRoot <PFAD>`

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
