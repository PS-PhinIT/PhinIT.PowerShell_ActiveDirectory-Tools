<#
  ####################################################################################################
  # easyADgroup - PowerShell GUI for Active Directory Group Management
  # Author:         Andreas Hepp
  # Website:        https://phinit.de/easyit-tools/
  # GitHub:         https://github.com/PS-easyIT
  # Version:        0.2.8 (Stand: 16.03.2025)
  ####################################################################################################
  
  Dieses Skript stellt eine GUI-basierte Benutzeroberfläche für die Verwaltung von
  Active Directory-Gruppen bereit.

  Funktionen:
  - Einfache Erstellung von AD-Gruppen mit verschiedenen Parametern
  - Erstellung einzelner oder mehrerer Gruppen in Serien (mit Nummernbereichen)
  - Spezielle Modus für JIRA/Confluence Gruppensets
  - Flexible Gruppenkonfiguration (Sicherheits- vs. Verteilungsgruppen)
  - Einstellung des Gruppengeltungsbereichs (Global, Universal, DomainLocal)
  - Automatische Zuweisung von Benutzern zu den erstellten Gruppen
  - OU-Filterung und Auswahl für präzise Gruppenplatzierung
  
  Voraussetzungen:
  - Administratorrechte erforderlich
  - PowerShell 5.1 oder höher
  - Active Directory-Modul für PowerShell
  - Erforderliche Dateien:
    - INI-Konfigurationsdatei ("easyADGroups.ini")
    - XAML-Datei für die GUI ("ADGroupsGUI.xaml")

  ----------------------------------------------------------------------------------------------------
  
  This script provides a GUI-based interface for managing Active Directory groups.

  Features:
  - Simple creation of AD groups with various parameters
  - Creation of single groups or multiple groups in series (with number ranges)
  - Special mode for JIRA/Confluence group sets
  - Flexible group configuration (Security vs. Distribution groups)
  - Group scope settings (Global, Universal, DomainLocal)
  - Automatic assignment of users to created groups
  - OU filtering and selection for precise group placement

  Requirements:
  - Administrative rights required
  - PowerShell 5.1 or higher
  - Active Directory module for PowerShell
  - Required files:
    - INI configuration file ("easyADGroups.ini")
    - XAML file for GUI ("ADGroupsGUI.xaml")

  ####################################################################################################
#>

# [1.0 | SCRIPT PATH DETECTION]
# [ENGLISH - Determines the directory of the EXE or script file]
# [GERMAN - Ermittelt das Verzeichnis der EXE- oder Skriptdatei]
#region Script Path Detection
if ($MyInvocation.MyCommand.Definition -match '\.exe$') {
    $scriptDir = [System.IO.Path]::GetDirectoryName([System.Reflection.Assembly]::GetEntryAssembly().Location)
} else {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
#endregion

# [2.0 | DEPENDENCY VERIFICATION]
# [ENGLISH - Verifies required PowerShell version, administrator rights and necessary modules]
# [GERMAN - Überprüft benötigte PowerShell-Version, Administratorrechte und erforderliche Module]
#region Dependency Verification
# [2.1 | POWERSHELL VERSION CHECK]
# [ENGLISH - Ensures minimum PowerShell version 5.1]
# [GERMAN - Stellt sicher, dass mindestens PowerShell 5.1 vorhanden ist]
if ($PSVersionTable.PSVersion -lt [Version]"5.1") {
    Write-Error "Dieses Script benötigt mindestens PowerShell 5.1. Aktuelle Version: $($PSVersionTable.PSVersion)"
    exit
}

# [2.2 | ADMIN RIGHTS CHECK]
# [ENGLISH - Verifies administrator privileges]
# [GERMAN - Überprüft Administratorrechte]
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Dieses Script muss als Administrator ausgeführt werden."
    exit
}

# [2.3 | MODULE AVAILABILITY CHECK]
# [ENGLISH - Checks for required PowerShell modules]
# [GERMAN - Prüft auf benötigte PowerShell-Module]
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "Das benötigte Modul 'ActiveDirectory' wurde nicht gefunden. Bitte installieren und erneut ausführen."
    exit
}

# Importiere das AD-Modul, falls es nicht geladen ist
if (-not (Get-Module -Name ActiveDirectory)) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Host "ActiveDirectory-Modul erfolgreich importiert" -ForegroundColor Green
    }
    catch {
        Write-Error "Fehler beim Importieren des ActiveDirectory-Moduls: $($_.Exception.Message)"
        exit
    }
}

$os = Get-WmiObject Win32_OperatingSystem
if ($os.ProductType -eq 1) {
    # [2.3.1 | WINDOWS CLIENT RSAT TOOLS CHECK]
    # [ENGLISH - Proper verification for RSAT-AD-PowerShell as Windows feature]
    # [GERMAN - Korrekte Prüfung für RSAT-AD-PowerShell als Windows-Feature]
    if ((Get-CimInstance -ClassName Win32_OperatingSystem).Version -ge "10.0.17763") {
        $adToolsInstalled = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'Rsat.ActiveDirectory.DS-LDS.Tools*' -and $_.State -eq 'Installed' }
        if (-not $adToolsInstalled) {
            Write-Error "Die benötigten RSAT-AD-Tools wurden nicht gefunden. Bitte installieren und erneut ausführen."
            exit
        }
    }
    # [2.3.2 | OLDER WINDOWS VERSIONS CHECK]
    # [ENGLISH - Check for older Windows versions]
    # [GERMAN - Prüfung für ältere Windows-Versionen]
    else {
        $adToolsInstalled = (Get-WindowsOptionalFeature -Online -FeatureName RSATClient-Roles-AD-DS).State -eq 'Enabled'
        if (-not $adToolsInstalled) {
            Write-Error "Die benötigten RSAT-AD-Tools wurden nicht gefunden. Bitte installieren und erneut ausführen."
            exit
        }
    }
}
#endregion

# [3.0 | TYPE IMPORTS AND ASSEMBLIES]
# [ENGLISH - Loads required .NET assemblies for GUI and VB functionality]
# [GERMAN - Lädt erforderliche .NET-Assemblies für GUI und VB Funktionalität]
#region Type Imports
# WPF-spezifische Assemblies laden
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, Microsoft.VisualBasic
#endregion

# [3.1 | GLOBAL VARIABLES INITIALIZATION]
# [ENGLISH - Initialize global variables for script operation]
# [GERMAN - Initialisiere globale Variablen für die Skriptausführung]
$script:createdGroups = New-Object System.Collections.ArrayList

# Initialisiere Variable für ausgewählte Benutzer
$script:selectedUsers = @()

# [4.0 | INI CONFIGURATION]
# [ENGLISH - Functions and logic for INI file handling and configuration]
# [GERMAN - Funktionen und Logik für INI-Datei-Verarbeitung und Konfiguration]
#region INI Processing
# [4.1 | INI PARSER]
# [ENGLISH - Function to parse INI file content]
# [GERMAN - Funktion zum Parsen von INI-Datei-Inhalten]
function Get-IniContent {
    param(
        [string]$Path
    )
    $ini = @{}
    $section = ""
    foreach ($line in Get-Content $Path) {
        $line = $line.Trim()
        if ($line.StartsWith(";") -or $line -eq "") { continue }
        if ($line -match "^\[(.+?)\]") {
            $section = $matches[1]
            $ini[$section] = @{}
        }
        elseif ($line -match "^(.*?)=(.*)$" -and $section) {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $ini[$section][$key] = $value
        }
    }
    return $ini
}

# [4.2 | CONFIGURATION LOADING]
# [ENGLISH - Loads and validates INI configuration sections]
# [GERMAN - Lädt und validiert INI-Konfigurationsabschnitte]
$iniPath = Join-Path -Path $scriptDir -ChildPath "easyADGroups.ini"
if (Test-Path $iniPath) {
    $iniContent = Get-IniContent -Path $iniPath
    Write-Host "INI-Datei erfolgreich geladen: $iniPath" -ForegroundColor Green
} else {
    [System.Windows.MessageBox]::Show("INI-Datei nicht gefunden: $iniPath")
    Write-Host "FEHLER: INI-Datei nicht gefunden: $iniPath" -ForegroundColor Red
    exit
}

# [4.3 | SECTION VALIDATION]
# [ENGLISH - Validate all required configuration sections]
# [GERMAN - Validiert alle benötigten Konfigurationsabschnitte]
$requiredSections = @("General", "LOGGING", "GUI", "AD", "ADGROUPS")
foreach ($section in $requiredSections) {
    if (-not $iniContent.ContainsKey($section)) {
        [System.Windows.MessageBox]::Show("Fehlender Abschnitt in INI-Datei: $section")
        Write-Host "FEHLER: Fehlender Abschnitt in INI-Datei: $section" -ForegroundColor Red
        exit
    }
}

# [4.4 | CONFIGURATION ASSIGNMENT]
# [ENGLISH - Assign configuration sections to specific variables]
# [GERMAN - Weist Konfigurationsabschnitte bestimmten Variablen zu]
$generalConfig  = $iniContent.General
$loggingConfig  = $iniContent.LOGGING
$guiConfig      = $iniContent.GUI
$adConfig       = $iniContent.AD
$adgroupsConfig = $iniContent.ADGROUPS

# [4.5 | DEBUG MODE CHECK]
# [ENGLISH - Output debug mode status]
# [GERMAN - Debug-Modus Status ausgeben]
if ($generalConfig.Debug -eq "1") {
    Write-Host "DEBUG-MODUS AKTIVIERT" -ForegroundColor Cyan
}

# [4.6 | PLACEHOLDER REPLACEMENT]
# [ENGLISH - Function to replace placeholders in text]
# [GERMAN - Funktion zum Ersetzen von Platzhaltern in Texten]
function Replace-InfoTextPlaceholders {
    param(
        [string]$Text
    )
    
    $result = $Text
    
    # Ersetze Platzhalter durch tatsächliche Werte
    if ($generalConfig.ContainsKey("ScriptVersion")) {
        $result = $result -replace 'ScriptVersion', $generalConfig.ScriptVersion
    }
    
    # LastUpdate - Verwende INI-Wert oder aktuelles Datum
    if ($generalConfig.ContainsKey("LastUpdate")) {
        $result = $result -replace 'LastUpdate', $generalConfig.LastUpdate
    } else {
        $result = $result -replace 'LastUpdate', (Get-Date -Format "dd.MM.yyyy")
    }
    
    # Author - Verwende INI-Wert oder Standard
    if ($generalConfig.ContainsKey("Author")) {
        $result = $result -replace 'Author', $generalConfig.Author
    } else {
        $result = $result -replace 'Author', "Andreas Hepp"
    }
    
    # WebsiteURLText - Verwende INI-Wert oder Standard
    if ($generalConfig.ContainsKey("WebsiteURLText")) {
        $result = $result -replace 'WebsiteURLText', $generalConfig.WebsiteURLText
    } else {
        $result = $result -replace 'WebsiteURLText', "https://phinit.de"
    }
    
    # Entferne überschüssige Leerzeichen und Pipe-Zeichen
    $result = $result -replace '\s*\|\s*', ' | '
    
    return $result
}

# [4.7 | LOG DIRECTORY SETUP]
# [ENGLISH - Setup log directory in a subfolder of the script directory]
# [GERMAN - Richtet das Log-Verzeichnis in einem Unterordner des Skriptverzeichnisses ein]
$logDir = Join-Path $scriptDir "logs"
if (-not (Test-Path $logDir)) { 
    New-Item -Path $logDir -ItemType Directory | Out-Null 
    Write-Host "Log-Verzeichnis erstellt: $logDir" -ForegroundColor Yellow
}
$script:config = @{
    LogPath = Join-Path $logDir ("LOG_easyADGroups-" + (Get-Date -Format "yyyy-MM-dd") + "-" + $loggingConfig.LogFileName)
}
Write-Host "Log-Datei wird erstellt unter: $($script:config.LogPath)" -ForegroundColor Gray
#endregion

# [5.0 | LOGGING FUNCTIONS]
# [ENGLISH - Defines logging capabilities for different message levels]
# [GERMAN - Definiert Protokollierungsfunktionen für verschiedene Nachrichtenebenen]
#region Logging Message Functions
function Write-LogMessage {
    # [5.1 | PRIMARY LOGGING WRAPPER]
    # [ENGLISH - Primary logging wrapper for consistent message formatting]
    # [GERMAN - Primärer Logging-Wrapper für konsistente Nachrichtenformatierung]
    param(
        [string]$message,
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        [string]$logLevel = "INFO"
    )
    Write-Log -message $message -Level $logLevel
    
    # [5.1.1 | CONSOLE OUTPUT]
    # [ENGLISH - Console output based on log level]
    # [GERMAN - Konsolenausgabe basierend auf Log-Level]
    if ($logLevel -eq "DEBUG" -and $generalConfig.Debug -eq "1") {
        Write-Host "[DEBUG] $message" -ForegroundColor Cyan
    }
    # [5.1.2 | ERROR DISPLAY]
    # [ENGLISH - Always show console output for errors]
    # [GERMAN - Konsolenausgabe für Fehler immer anzeigen]
    elseif ($logLevel -eq "ERROR") {
        Write-Host "[ERROR] $message" -ForegroundColor Red
    }
    # [5.1.3 | WARNING DISPLAY]
    # [ENGLISH - Always show console output for warnings]
    # [GERMAN - Konsolenausgabe für Warnungen immer anzeigen]
    elseif ($logLevel -eq "WARNING") {
        Write-Host "[WARN] $message" -ForegroundColor Yellow
    }
}

function Write-DebugMessage {
    # [5.2 | DEBUG LOGGING]
    # [ENGLISH - Debug-specific logging with conditional execution]
    # [GERMAN - Debug-spezifische Protokollierung mit bedingter Ausführung]
    param(
        [string]$Message
    )
    if ($generalConfig.Debug -eq "1") {
        Write-LogMessage -message $Message -logLevel "DEBUG"
    }
}
# [5.3 | LOG LEVELS]
# [ENGLISH - Available log levels: "INFO" (default), "WARNING", "ERROR", "DEBUG"]
# [GERMAN - Verfügbare Log-Level (Standard ist "INFO"): "WARN", "ERROR", "DEBUG"]
#endregion

# [6.0 | LOGGING FUNCTIONALITY]
# [ENGLISH - Logging function implementation with multiple severity levels]
# [GERMAN - Implementierung der Protokollierungsfunktion mit verschiedenen Schweregradeni]
#region Logging Implementation
function Write-Log {
    # [6.1 | LOG ENTRY CREATION]
    # [ENGLISH - Create formatted log entries with timestamps]
    # [GERMAN - Erstellt formatierte Log-Einträge mit Zeitstempeln]
    param(
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry  = "$timestamp [$Level] - $Message"
    try {
        Add-Content -Path $script:config.LogPath -Value $logEntry -ErrorAction Stop
    }
    catch {
        [System.Windows.MessageBox]::Show("Logfile-Schreibfehler: $($_.Exception.Message)")
        Write-Host "FEHLER beim Schreiben ins Logfile: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# [6.2 | INITIAL LOG ENTRIES]
# [ENGLISH - Create initial log entries on script start]
# [GERMAN - Erstellt die ersten Log-Einträge beim Skriptstart]
Write-LogMessage "Script gestartet - Version $($generalConfig.ScriptVersion)" -logLevel "INFO"
Write-DebugMessage "Debug-Modus aktiv - Detaillierte Ausgaben werden angezeigt"
Write-DebugMessage "Script-Verzeichnis: $scriptDir"
Write-DebugMessage "INI-Datei: $iniPath"
Write-DebugMessage "Log-Datei: $($script:config.LogPath)"
#endregion

# [7.0 | ACTIVE DIRECTORY OPERATIONS]
# [ENGLISH - AD data retrieval and manipulation functions]
# [GERMAN - Funktionen zum Abrufen und Bearbeiten von AD-Daten]
#region AD Operations
function Get-ADData {
    # [7.1 | AD DATA RETRIEVAL]
    # [ENGLISH - Retrieve and process Active Directory data]
    # [GERMAN - Active Directory-Daten abrufen und verarbeiten]
    Write-LogMessage "AD-Daten werden abgerufen..." -logLevel "INFO"
    try {
        # [7.1.1 | OU RETRIEVAL]
        # [ENGLISH - Retrieve all organizational units from AD]
        # [GERMAN - Ruft alle Organisationseinheiten aus AD ab]
        Write-DebugMessage "Rufe alle OUs aus AD ab..."
        $script:allOUs = Get-ADOrganizationalUnit -Filter * -Properties Name, DistinguishedName |
            # Filtere Standard-OUs heraus (basierend auf deren Standardnamen oder Strukturen)
            Where-Object {
                # Filtere Standard-OUs wie "Domain Controllers", "Users", "Computers" heraus
                $excludedOUs = @('Domain Controllers', 'Users', 'Computers', 'Builtin')
                $_.Name -notin $excludedOUs -and
                # Filtere auch Container-Objekte heraus (beginnen mit CN= statt OU=)
                $_.DistinguishedName -notlike "CN=*"
            } |
            ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    DN   = $_.DistinguishedName
                }
            } | Sort-Object Name
        Write-DebugMessage "Anzahl gefundener OUs nach Filterung: $($script:allOUs.Count)"
        
        # [7.1.2 | USER RETRIEVAL - ÜBERARBEITET]
        # [ENGLISH - Retrieve users from AD (limited to 200) with better display]
        # [GERMAN - Ruft Benutzer aus AD ab (begrenzt auf 200) mit besserer Anzeige]
        Write-DebugMessage "Rufe Benutzer aus AD ab (max. 200)..."

        # Verbesserte Benutzeranzeige mit ObservableCollection statt DataTable
        $script:allUsers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
        
        try {
            $adUsers = Get-ADUser -Filter * -Properties DisplayName, SamAccountName -ErrorAction Stop | 
                Sort-Object DisplayName | 
                Select-Object -First 200
                
            foreach ($user in $adUsers) {
                $displayText = if ([string]::IsNullOrEmpty($user.DisplayName)) { 
                    "$($user.SamAccountName)" 
                } else { 
                    "$($user.DisplayName) ($($user.SamAccountName))" 
                }
                
                $userObject = [PSCustomObject]@{
                    DisplayText = $displayText
                    SamAccountName = $user.SamAccountName
                }
                
                $script:allUsers.Add($userObject)
            }
            
            Write-DebugMessage "Benutzerabfrage erfolgreich: $($script:allUsers.Count) Benutzer geladen"
        }
        catch {
            Write-LogMessage "Warnung bei Benutzerabfrage: $($_.Exception.Message)" -logLevel "WARNING"
            # Fallback für leere Benutzersammlung
            $userObject = [PSCustomObject]@{
                DisplayText = "Keine Benutzer gefunden"
                SamAccountName = ""
            }
            $script:allUsers.Add($userObject)
        }

        # [7.1.3 | UI UPDATES - ANGEPASST FÜR BENUTZERANZEIGE]
        # Für WPF-Implementierung angepasst
        $window.Dispatcher.Invoke([Action]{
            # ComboBox mit OUs befüllen
            Write-DebugMessage "Befülle OU-ComboBox..."
            $comboBoxOU.ItemsSource = $script:allOUs
            
            # ListBox mit Benutzern befüllen - VERBESSERTE METHODE
            Write-DebugMessage "Befülle User-ListBox mit verbessertem Format..."
            $listBoxUsers.ItemsSource = $script:allUsers
            
            # Setze DisplayMemberPath für korrekte Anzeige
            $listBoxUsers.DisplayMemberPath = "DisplayText"
            $listBoxUsers.SelectedValuePath = "SamAccountName"
        })
        
        Write-LogMessage "AD-Daten erfolgreich geladen" -logLevel "INFO"
    }
    catch {
        # [7.1.4 | ERROR HANDLING]
        # [ENGLISH - Handle errors during AD data retrieval]
        # [GERMAN - Behandelt Fehler während des Abrufs von AD-Daten]
        Write-LogMessage "Fehler beim Abrufen von AD-Daten: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("AD-Verbindungsfehler: $($_.Exception.Message)")
        exit
    }
}
#endregion

# [8.0 | INPUT VALIDATION]
# [ENGLISH - Validation logic for user inputs]
# [GERMAN - Validierungslogik für Benutzereingaben]
#region Input Validation
function Test-Input {
    # [8.1 | USER INPUT VALIDATION]
    # [ENGLISH - Validate form inputs before processing]
    # [GERMAN - Validiert Formulareingaben vor der Verarbeitung]
    Write-DebugMessage "Validiere Benutzereingaben..."
    $errors = @()
    
    # [8.1.1 | STANDARD MODE VALIDATION]
    # [ENGLISH - If special mode is NOT activated, validate start/end fields]
    # [GERMAN - Falls Spezialmodus NICHT aktiviert ist, Start/End-Felder validieren]
    if (-not ($chkSpecial.IsChecked -eq $true)) {
        Write-DebugMessage "Standard-Modus: Prüfe Start/End-Felder"
        if (($textBoxStart.Text.Trim() -eq "") -and ($textBoxEnd.Text.Trim() -eq "")) {
            Write-DebugMessage "Start/End-Felder sind leer - Einzelgruppen-Erstellung"
            # [8.1.1.1 | SINGLE GROUP CREATION]
            # [ENGLISH - OK – Single group creation]
            # [GERMAN - OK – Einzelgruppen-Erstellung]
        }
        elseif (($textBoxStart.Text.Trim() -eq "") -or ($textBoxEnd.Text.Trim() -eq "")) {
            Write-DebugMessage "Nur ein Feld ist gefüllt - Validierungsfehler"
            $errors += "Bitte entweder beide Felder (Start und Endnummer) ausfüllen oder beide leer lassen."
        }
        else {
            # [8.1.1.2 | NUMERIC VALUES CHECK]
            # [ENGLISH - Check numeric values for start/end]
            # [GERMAN - Prüft nummerische Werte für Start/End]
            Write-DebugMessage "Prüfe nummerische Werte für Start/End"
            $startNum = 0
            $endNum = 0
            
            if (-not [int]::TryParse($textBoxStart.Text.Trim(), [ref]$startNum)) { 
                Write-DebugMessage "Startnummer ist keine gültige Zahl: $($textBoxStart.Text)"
                $errors += "Ungültiges Startnummernformat" 
            }
            if (-not [int]::TryParse($textBoxEnd.Text.Trim(), [ref]$endNum)) { 
                Write-DebugMessage "Endnummer ist keine gültige Zahl: $($textBoxEnd.Text)"
                $errors += "Ungültiges Endnummernformat" 
            }
            
            # [8.1.1.3 | RANGE CHECK]
            # [ENGLISH - Check if start number is less than end number]
            # [GERMAN - Prüft, ob Startnummer kleiner als Endnummer ist]
            if (($errors.Count -eq 0) -and ($startNum -gt $endNum)) { 
                Write-DebugMessage "Startnummer ($startNum) größer als Endnummer ($endNum)"
                $errors += "Startnummer muss kleiner als Endnummer sein" 
            }
        }
    } else {
        # [8.1.2 | SPECIAL MODE VALIDATION]
        # [ENGLISH - Validate for JIRA/Confluence groups special mode]
        # [GERMAN - Validiert für Spezial-Modus JIRA/Confluence-Gruppen]
        Write-DebugMessage "Spezial-Modus aktiviert: Validiere für JIRA/Confluence-Gruppen"
    }
    
    # [8.1.3 | OU SELECTION CHECK]
    # [ENGLISH - Check if OU is selected]
    # [GERMAN - Prüft, ob eine OU ausgewählt wurde]
    if ($comboBoxOU.SelectedIndex -eq -1) { 
        Write-DebugMessage "Keine OU ausgewählt"
        $errors += "Keine OU ausgewählt" 
    } else {
        Write-DebugMessage "Ausgewählte OU: $($comboBoxOU.SelectedValue)"
    }
    
    # Erweiterte Validierung für Gruppennamen
    if ([string]::IsNullOrWhiteSpace($textBoxPrefix.Text)) {
        $errors += "Gruppenname darf nicht leer sein."
    }
    elseif ($textBoxPrefix.Text -match '[\\/:*?"<>|]') {
        $errors += 'Gruppenname enthält ungültige Zeichen: \ / : * ? ` " < > |'
    }
    
    # [NEUE FUNKTION] - Validierung der Gruppennamen auf ungültige AD-Zeichen
    $groupsToValidate = @()
    
    if ($chkSpecial.Checked) {
        $suffixes = $adgroupsConfig.AdditionalSuffixes.Split(",")
        foreach ($suffix in $suffixes) {
            $groupsToValidate += "$($textBoxPrefix.Text.Trim())$($textBoxSeparator.Text.Trim())$suffix"
        }
    }
    elseif (($textBoxStart.Text.Trim() -eq "") -and ($textBoxEnd.Text.Trim() -eq "")) {
        $groupsToValidate += "$($textBoxPrefix.Text.Trim())"
    }
    else {
        if ($errors.Count -eq 0) { # Nur ausführen, wenn keine Fehler bei Start/End
            $start = [int]$textBoxStart.Text.Trim()
            $end = [int]$textBoxEnd.Text.Trim()
            for ($i = $start; $i -le $end; $i++) {
                $groupsToValidate += "$($textBoxPrefix.Text.Trim())$($textBoxSeparator.Text.Trim())$i"
            }
        }
    }
    
    # Validiere alle Gruppennamen
    foreach ($groupName in $groupsToValidate) {
        # Prüfe auf ungültige AD-Zeichen (ergänzt zu den bereits geprüften Zeichen)
        if ($groupName -match '[,;@\[\]{}+=&~!#%^()''`]') {
            $errors += "Gruppenname '$groupName' enthält ungültige Zeichen für Active Directory."
            break # Stoppe nach dem ersten fehlerhaften Namen
        }
        
        # Prüfe auf Längenbeschränkungen
        if ($groupName.Length > 256) {
            $errors += "Gruppenname '$groupName' ist zu lang (max. 256 Zeichen)."
            break
        }
        
        # Prüfe SAMAccountName-Länge
        if ($groupName.Length > 20) {
            Write-DebugMessage "SAMAccountName für '$groupName' wird auf 20 Zeichen gekürzt"
        }
    }
    
    # [8.1.4 | VALIDATION RESULT]
    # [ENGLISH - Log validation results]
    # [GERMAN - Protokolliert Validierungsergebnisse]
    if ($errors.Count -gt 0) {
        Write-DebugMessage "Validierung fehlgeschlagen mit $($errors.Count) Fehlern: $($errors -join ', ')"
    } else {
        Write-DebugMessage "Validierung erfolgreich"
    }
    
    return $errors
}
#endregion

# [9.0 | GUI CONSTRUCTION]
# Die GUI-Konstruktion wird nun für WPF statt für WinForms implementiert
# Ihre aktuelle Implementierung sieht aus, als würde sie stattdessen die GUI aus einer XAML-Datei laden

# [10.0 | ACTION BUTTONS]
# [ENGLISH - Implementation of button click handlers and related functionality]
# [GERMAN - Implementierung von Button-Click-Handlern und zugehöriger Funktionalität]
#region Action Buttons
function Add-ButtonEventHandlers {
    # [10.1 | PREVIEW BUTTON]
    # [ENGLISH - Button for previewing group creation]
    # [GERMAN - Button für die Vorschau der Gruppenerstellung]
    $buttonPreview.Add_Click({
        Write-DebugMessage "Vorschau-Button geklickt"
        $errors = Test-Input
        if ($errors.Count -gt 0) {
            Write-LogMessage "Validierungsfehler bei Vorschau: $($errors -join ', ')" -logLevel "WARNING"
            [System.Windows.MessageBox]::Show(($errors -join "`n"), "Validierungsfehler")
            return
        }
        $groups = @()
        if ($chkSpecial.IsChecked -eq $true) {
            Write-DebugMessage "Spezial-Modus: Verwende Suffixe aus INI"
            $suffixes = $adgroupsConfig.AdditionalSuffixes.Split(",")
            Write-DebugMessage "Gefundene Suffixe: $($suffixes -join ', ')"
            foreach ($suffix in $suffixes) {
                $groupName = "$($textBoxPrefix.Text.Trim())$($textBoxSeparator.Text.Trim())$suffix"
                Write-DebugMessage "Vorschau-Gruppe: $groupName"
                $groups += "Gruppe: $groupName"
            }
        }
        elseif (($textBoxStart.Text.Trim() -eq "") -and ($textBoxEnd.Text.Trim() -eq "")) {
            $groupName = "$($textBoxPrefix.Text.Trim())"
            Write-DebugMessage "Einzelgruppen-Modus: $groupName"
            $groups += "Gruppe: $groupName"
        }
        else {
            Write-DebugMessage "Nummern-Sequenz-Modus: Von $($textBoxStart.Text) bis $($textBoxEnd.Text)"
            for ($i = [int]$textBoxStart.Text.Trim(); $i -le [int]$textBoxEnd.Text.Trim(); $i++) {
                $groupName = "$($textBoxPrefix.Text.Trim())$($textBoxSeparator.Text.Trim())$i"
                Write-DebugMessage "Vorschau-Gruppe: $groupName"
                $groups += "Gruppe: $groupName"
            }
        }
        Write-LogMessage "Vorschau generiert für $($groups.Count) Gruppen" -logLevel "INFO"
        [System.Windows.MessageBox]::Show($groups -join "`n----------------`n", "Vorschau")
    })

    # [10.2 | CREATE BUTTON]
    # [ENGLISH - Button for creating groups]
    # [GERMAN - Button für die Erstellung von Gruppen]
    $buttonCreate.Add_Click({
        Write-LogMessage "Erstellungs-Button geklickt" -logLevel "INFO"
        $errors = Test-Input
        if ($errors.Count -gt 0) {
            Write-LogMessage "Validierungsfehler bei Gruppenerstellung: $($errors -join ', ')" -logLevel "WARNING"
            [System.Windows.MessageBox]::Show(($errors -join "`n"), "Validierungsfehler")
            return
        }
        
        # Für WPF angepasste Fortschrittsanzeige
        $progressWindow = New-Object System.Windows.Window
        $progressWindow.Title = "Erstellung läuft..."
        $progressWindow.Width = 300
        $progressWindow.Height = 100
        $progressWindow.WindowStartupLocation = "CenterScreen"
        $progressWindow.ResizeMode = "NoResize"
        $progressWindow.Topmost = $true
        
        $progressGrid = New-Object System.Windows.Controls.Grid
        $progressBar = New-Object System.Windows.Controls.ProgressBar
        $progressBar.Height = 20
        $progressBar.Margin = New-Object System.Windows.Thickness(10)
        $progressBar.Minimum = 0
        $progressBar.Maximum = 100
        $progressBar.Value = 0
        
        $progressGrid.Children.Add($progressBar)
        $progressWindow.Content = $progressGrid
        $progressWindow.Show()
        
        # FIXIERT: Verbesserte Benutzerauswahl-Extraktion für das neue Format
        $script:selectedUsers = @()
        if ($listBoxUsers.SelectedItems.Count -gt 0) {
            Write-DebugMessage "Ausgewählte Benutzer werden extrahiert... ($($listBoxUsers.SelectedItems.Count) Elemente)"
            
            foreach ($selectedItem in $listBoxUsers.SelectedItems) {
                try {
                    # Angepasst für das neue PSObject-Format mit SamAccountName-Eigenschaft
                    if ($selectedItem -and $selectedItem.SamAccountName -and -not [string]::IsNullOrWhiteSpace($selectedItem.SamAccountName)) {
                        $script:selectedUsers += $selectedItem.SamAccountName
                        Write-DebugMessage "Benutzer ausgewählt: $($selectedItem.SamAccountName) ($($selectedItem.DisplayText))"
                    }
                }
                catch {
                    Write-LogMessage "Fehler beim Extrahieren des SamAccountName: $($_.Exception.Message)" -logLevel "WARNING"
                }
            }
            
            Write-LogMessage "Es wurden $($script:selectedUsers.Count) Benutzer für die Gruppenmitgliedschaft ausgewählt" -logLevel "INFO"
            Write-DebugMessage "Ausgewählte Benutzer: $($script:selectedUsers -join ', ')"
        } else {
            Write-LogMessage "Keine Benutzer für Gruppenmitgliedschaft ausgewählt" -logLevel "INFO"
        }
        
        try {
            $groupsToCreate = @()
            if ($chkSpecial.IsChecked -eq $true) {
                Write-DebugMessage "Spezial-Modus aktiviert für Gruppenerstellung"
                $suffixes = $adgroupsConfig.AdditionalSuffixes.Split(",")
                foreach ($suffix in $suffixes) {
                    $groupsToCreate += "$($textBoxPrefix.Text.Trim())$($textBoxSeparator.Text.Trim())$suffix"
                }
            }
            elseif (($textBoxStart.Text.Trim() -eq "") -and ($textBoxEnd.Text.Trim() -eq "")) {
                Write-DebugMessage "Einzelgruppen-Modus aktiviert"
                $groupsToCreate += "$($textBoxPrefix.Text.Trim())"
            }
            else {
                Write-DebugMessage "Nummern-Sequenz-Modus aktiviert: $($textBoxStart.Text) bis $($textBoxEnd.Text)"
                $start = [int]$textBoxStart.Text.Trim()
                $end   = [int]$textBoxEnd.Text.Trim()
                for ($i = $start; $i -le $end; $i++) {
                    $groupsToCreate += "$($textBoxPrefix.Text.Trim())$($textBoxSeparator.Text.Trim())$i"
                }
            }
            $total = $groupsToCreate.Count
            Write-LogMessage "Starte Erstellung von $total Gruppen" -logLevel "INFO"
            $count = 0
            
            foreach ($groupName in $groupsToCreate) {
                # SAMAccountName-Überprüfung (max. 256 Zeichen für Namen, 20 für SAM)
                $samAccountName = $groupName
                if ($samAccountName.Length > 20) {
                    $samAccountName = $samAccountName.Substring(0, 20)
                    Write-LogMessage "SAMAccountName für $groupName wurde auf $samAccountName gekürzt (max. 20 Zeichen)" -logLevel "WARNING"
                }
                
                if ($groupName.Length > 256) {
                    $groupName = $groupName.Substring(0, 256)
                    Write-LogMessage "Gruppenname wurde auf $groupName gekürzt (max. 256 Zeichen)" -logLevel "WARNING"
                }
                
                # Prüfe auf problematische Zeichen, die nicht bereits durch die Validierung abgefangen wurden
                if ($groupName -match '[,;@\[\]{}+=&~!#%^()''`]' -or $groupName -match '[\\/:*?"<>|]') {
                    Write-LogMessage "Gruppenname $groupName enthält ungültige Zeichen - wird übersprungen" -logLevel "ERROR"
                    continue
                }
                
                $params = @{
                    Name          = $groupName
                    SamAccountName = $samAccountName
                    Path          = if ($comboBoxOU.SelectedItem -and $comboBoxOU.SelectedItem.DN) {
                        $comboBoxOU.SelectedItem.DN
                    } elseif ($comboBoxOU.SelectedValue -is [string]) {
                        $comboBoxOU.SelectedValue
                    } else {
                        $comboBoxOU.SelectedValue.DN
                    }
                    GroupScope    = if ($radioGlobal.IsChecked -eq $true) { 
                        "Global" 
                    } elseif ($radioUniversal.IsChecked -eq $true) { 
                        "Universal" 
                    } else { 
                        "DomainLocal" 
                    }
                    GroupCategory = if ($radioSecurity.IsChecked -eq $true) { 
                        "Security" 
                    } else { 
                        "Distribution" 
                    }
                    Description   = if ($textBoxDescription.Text) { 
                        $textBoxDescription.Text 
                    } else { 
                        $adgroupsConfig.GroupDescription 
                    }
                    DisplayName   = $groupName
                }
                
                # Debug-Ausgabe erweitern zur besseren Fehlerdiagnose
                Write-DebugMessage "Erstelle Gruppe: $groupName mit Pfad: $($params.Path)"
                
                # Server-Parameter nur hinzufügen, wenn ADServer definiert ist
                if ($os.ProductType -eq 1 -and $adConfig.ADServer) { 
                    $params["Server"] = $adConfig.ADServer 
                }
                
                Write-DebugMessage "Erstelle Gruppe mit Parametern: $($params | ConvertTo-Json -Compress)"
                try {
                    # Verbesserte Prüfung, ob die Gruppe bereits existiert (nach SAMAccountName)
                    $existingGroup = $null
                    try {
                        $existingGroup = Get-ADGroup -Identity $samAccountName -Properties * -ErrorAction SilentlyContinue
                    }
                    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                        Write-DebugMessage "Gruppe ${samAccountName} existiert nicht - kann erstellt werden"
                    }
                    catch {
                        Write-LogMessage "Fehler bei Prüfung auf existierende Gruppe ${samAccountName}: $($_.Exception.Message)" -logLevel "WARNING"
                    }
                    
                    if ($existingGroup) {
                        Write-LogMessage "Gruppe mit SAMAccountName $samAccountName existiert bereits - wird übersprungen" -logLevel "WARNING"
                        continue
                    }
                    
                    Write-LogMessage "Erstelle Gruppe: $($params.Name) in OU: $($params.Path) mit Scope: $($params.GroupScope) und Category: $($params.GroupCategory)" -logLevel "INFO"
                    
                    # Verbessertes Error-Handling beim Erstellen der Gruppe
                    try {
                        $group = New-ADGroup @params -PassThru -ErrorAction Stop
                        
                        # Kleine Verzögerung für AD-Replikation
                        Start-Sleep -Milliseconds 500
                        
                        [void]$script:createdGroups.Add($group.Name)
                        Write-DebugMessage "Gruppe $groupName erfolgreich erstellt"
                        
                        # Benutzerverarbeitung für WPF angepasst
                        if ($script:selectedUsers.Count -gt 0) { 
                            Write-DebugMessage "Füge $($script:selectedUsers.Count) ausgewählte Mitglieder hinzu: $($script:selectedUsers -join ', ')"
                            try {
                                # Verzögerung vor dem Hinzufügen von Mitgliedern
                                Start-Sleep -Milliseconds 1000
                                
                                # Hinzufügen von ausgewählten Benutzern sicherstellen
                                Add-ADGroupMember -Identity $samAccountName -Members $script:selectedUsers -ErrorAction Stop
                                Write-LogMessage "Mitglieder zu $groupName hinzugefügt: $($script:selectedUsers -join ', ')" -logLevel "INFO"
                            } catch {
                                Write-LogMessage "Fehler beim Hinzufügen von Mitgliedern zu ${groupName}: $($_.Exception.Message)" -logLevel "ERROR"
                                
                                # Fallback: Versuche es erneut mit dem DN der Gruppe
                                try {
                                    # Gruppe erneut abrufen, um sicherzustellen, dass wir den aktuellen DN haben
                                    $freshGroup = Get-ADGroup -Identity $samAccountName -Properties DistinguishedName -ErrorAction Stop
                                    Add-ADGroupMember -Identity $freshGroup.DistinguishedName -Members $script:selectedUsers -ErrorAction Stop
                                    Write-LogMessage "Mitglieder zu $groupName hinzugefügt (2. Versuch mit DN)" -logLevel "INFO"
                                } catch {
                                    Write-LogMessage "Auch 2. Versuch zum Hinzufügen der Mitglieder fehlgeschlagen: $($_.Exception.Message)" -logLevel "ERROR"
                                }
                            }
                        }
                        
                        # INI-basierte Benutzer
                        if ($adgroupsConfig.GroupMembersAddActive -eq "1") {
                            $fixedMembers = $adgroupsConfig.GroupMembersAdd.Split(",") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                            if ($fixedMembers -and $fixedMembers.Count -gt 0) { 
                                Write-DebugMessage "Füge feste Mitglieder aus INI hinzu: $($fixedMembers -join ', ')"
                                try {
                                    Add-ADGroupMember -Identity $samAccountName -Members $fixedMembers -ErrorAction Stop
                                    Write-LogMessage "Feste Mitglieder zu $groupName hinzugefügt: $($fixedMembers -join ', ')" -logLevel "INFO"
                                } catch {
                                    Write-LogMessage "Fehler beim Hinzufügen fester Mitglieder zu ${groupName}: $($_.Exception.Message)" -logLevel "WARNING"
                                    
                                    # Fallback: Versuche es erneut mit dem DN der Gruppe
                                    try {
                                        $freshGroup = Get-ADGroup -Identity $samAccountName -Properties DistinguishedName -ErrorAction Stop
                                        Add-ADGroupMember -Identity $freshGroup.DistinguishedName -Members $fixedMembers -ErrorAction Stop
                                        Write-LogMessage "Feste Mitglieder zu $groupName hinzugefügt (2. Versuch mit DN)" -logLevel "INFO"
                                    } catch {
                                        Write-LogMessage "Auch 2. Versuch zum Hinzufügen der festen Mitglieder fehlgeschlagen: $($_.Exception.Message)" -logLevel "ERROR"
                                    }
                                }
                            }
                        }
                        
                        Write-LogMessage "Gruppe $groupName erfolgreich erstellt" -logLevel "INFO"
                    } 
                    catch {
                        Write-LogMessage "Fehler beim Erstellen der Gruppe ${groupName}: $($_.Exception.Message)" -logLevel "ERROR"
                        if ($generalConfig.Debug -eq "1") {
                            Write-DebugMessage "Exception-Details: $($_ | Format-List -Force | Out-String)"
                        }
                    }
                }
                catch {
                    Write-LogMessage "Fehler bei ${groupName}: $($_.Exception.Message)" -logLevel "ERROR"
                }
                
                $count++
                # UI-Thread-sichere Aktualisierung der ProgressBar für WPF
                $progressWindow.Dispatcher.Invoke([Action]{
                    $progressBar.Value = [Math]::Min([int](($count / $total) * 100), 100)
                    $progressWindow.Title = "Fortschritt: $($count)/$($total)"
                }, "Normal")
                
                Write-DebugMessage "Fortschritt: $count/$total Gruppen erstellt"
            }
            
            Write-LogMessage "Gruppenerstellung abgeschlossen. $count/$total Gruppen erstellt." -logLevel "INFO"
            [System.Windows.MessageBox]::Show("$count Gruppen erfolgreich erstellt.", "Erstellung abgeschlossen")
        }
        finally {
            $progressWindow.Close()
        }
    })

    # [10.3 | CLOSE BUTTON]
    # [ENGLISH - Close button for better usability]
    # [GERMAN - Schließen-Button für bessere Benutzerfreundlichkeit]
    $buttonClose.Add_Click({
        Write-LogMessage "Anwendung wird beendet" -logLevel "INFO"
        $window.Close()
    })
}
#endregion

# [11.0 | MAIN EXECUTION]
# [ENGLISH - Main script execution and form display]
# [GERMAN - Hauptskriptausführung und Formularanzeige]
function Initialize-MainApplication {
    # XAML-Datei laden
    $xamlFile = Join-Path -Path $scriptDir -ChildPath "ADGroupsGUI.xaml"
    if (-not (Test-Path $xamlFile)) {
        [System.Windows.MessageBox]::Show("XAML-Datei nicht gefunden: $xamlFile")
        Write-Host "FEHLER: XAML-Datei nicht gefunden: $xamlFile" -ForegroundColor Red
        exit
    }
    
    try {
        # XAML laden und WPF-Objekte erstellen
        $xamlContent = Get-Content $xamlFile -Raw
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlContent)
        $script:window = [Windows.Markup.XamlReader]::Load($reader)
        
        # Elemente der GUI anhand von Namen abrufen
        $script:comboBoxOU = $window.FindName("comboBoxOU")
        $script:listBoxUsers = $window.FindName("listBoxUsers")
        $script:textBoxPrefix = $window.FindName("textBoxPrefix")
        $script:textBoxSeparator = $window.FindName("textBoxSeparator")
        $script:textBoxStart = $window.FindName("textBoxStart")
        $script:textBoxEnd = $window.FindName("textBoxEnd")
        $script:textBoxDescription = $window.FindName("textBoxDescription")
        $script:radioSecurity = $window.FindName("radioSecurity")
        $script:radioDistribution = $window.FindName("radioDistribution")
        $script:radioGlobal = $window.FindName("radioGlobal")
        $script:radioUniversal = $window.FindName("radioUniversal")
        $script:radioDomainLocal = $window.FindName("radioDomainLocal")
        $script:chkSpecial = $window.FindName("chkSpecial")
        $script:buttonPreview = $window.FindName("buttonPreview")
        $script:buttonCreate = $window.FindName("buttonCreate")
        $script:buttonClose = $window.FindName("buttonClose")
        
        # Header TextBlocks referenzieren
        $script:labelAppName = $window.FindName("labelAppName")
        $script:labelInfo = $window.FindName("labelInfo")
        
        # Header-Texte aus der INI-Datei setzen
        if ($script:labelAppName) {
            $script:labelAppName.Text = $guiConfig.AppName
            Write-DebugMessage "App-Name aus INI gesetzt: $($guiConfig.AppName)"
        }
        
        # Für labelInfo mit Binding - mit Platzhalter-Ersetzung
        if ($script:labelInfo) {
            # Ersetze Platzhalter im AppInfoText
            $processedInfoText = Replace-InfoTextPlaceholders -Text $guiConfig.AppInfoText
            
            # Data-Context für Binding erstellen
            $dataContext = New-Object PSObject -Property @{
                LabelInfo = $processedInfoText
            }
            $script:window.DataContext = $dataContext
            Write-DebugMessage "Info-Label mit ersetzten Platzhaltern gesetzt: $($dataContext.LabelInfo)"
        }
        
        # Standardwerte setzen
        $script:textBoxSeparator.Text = "-"
        $script:textBoxDescription.Text = $adgroupsConfig.GroupDescription
        
        # Event Handler hinzufügen
        Add-ButtonEventHandlers
        
        # Daten aus AD laden
        Write-DebugMessage "Starte AD-Datenabfrage"
        Get-ADData
        
        Write-LogMessage "Anwendung gestartet und bereit" -logLevel "INFO"
        
        # GUI anzeigen
        [void]$script:window.ShowDialog()
        
    } catch {
        Write-LogMessage "Fehler beim Initialisieren der Anwendung: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Initialisieren der Anwendung: $($_.Exception.Message)")
        exit
    }
}

# Starte die Hauptanwendung
Initialize-MainApplication