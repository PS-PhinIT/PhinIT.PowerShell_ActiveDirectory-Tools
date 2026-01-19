<#
  ####################################################################################################
  # easyADgroup - PowerShell GUI for Active Directory Group Management
  # Author:         Andreas Hepp
  # Website:        https://phinit.de
  # GitHub:         https://github.com/PS-easyIT
  # Version:        0.2.7 (Stand: 16.03.2025)
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
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic
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
    [System.Windows.Forms.MessageBox]::Show("INI-Datei nicht gefunden: $iniPath")
    Write-Host "FEHLER: INI-Datei nicht gefunden: $iniPath" -ForegroundColor Red
    exit
}

# [4.3 | SECTION VALIDATION]
# [ENGLISH - Validate all required configuration sections]
# [GERMAN - Validiert alle benötigten Konfigurationsabschnitte]
$requiredSections = @("General", "LOGGING", "GUI", "AD", "ADGROUPS")
foreach ($section in $requiredSections) {
    if (-not $iniContent.ContainsKey($section)) {
        [System.Windows.Forms.MessageBox]::Show("Fehlender Abschnitt in INI-Datei: $section")
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

# [4.6 | LOG DIRECTORY SETUP]
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
        [System.Windows.Forms.MessageBox]::Show("Logfile-Schreibfehler: $($_.Exception.Message)")
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
        
        # [7.1.2 | USER RETRIEVAL]
        # [ENGLISH - Retrieve users from AD (limited to 200)]
        # [GERMAN - Ruft Benutzer aus AD ab (begrenzt auf 200)]
        Write-DebugMessage "Rufe Benutzer aus AD ab (max. 200)..."
        # [7.1.2.1 | USER DATATABLE]
        # [ENGLISH - Create DataTable for better ListBox compatibility]
        # [GERMAN - Erstelle ein DataTable für bessere ListBox-Kompatibilität]
        $usersTable = New-Object System.Data.DataTable
        [void]$usersTable.Columns.Add("DisplayName", [string])
        [void]$usersTable.Columns.Add("SamAccountName", [string])
        
        # Verbesserte Fehlerbehandlung bei der Benutzerabfrage
        try {
            Get-ADUser -Filter * -Properties DisplayName, SamAccountName -ErrorAction Stop | 
                Sort-Object DisplayName | 
                Select-Object -First 200 | 
                ForEach-Object {
                    [void]$usersTable.Rows.Add("$($_.DisplayName) ($($_.SamAccountName))", $_.SamAccountName)
                }
        }
        catch {
            Write-LogMessage "Warnung bei Benutzerabfrage: $($_.Exception.Message)" -logLevel "WARNING"
            # Füge leere Zeile hinzu, damit DataTable nicht leer ist
            [void]$usersTable.Rows.Add("Keine Benutzer gefunden", "")
        }
        
        $script:allUsers = $usersTable
        Write-DebugMessage "Anzahl abgerufener Benutzer: $($script:allUsers.Rows.Count)"

        # [7.1.3 | UI UPDATES]
        # [ENGLISH - Update UI components with retrieved AD data]
        # [GERMAN - Aktualisiert UI-Komponenten mit abgerufenen AD-Daten]
        # [7.1.3.1 | OU COMBOBOX POPULATION]
        # [ENGLISH - Populate OU ComboBox with retrieved OUs]
        # [GERMAN - Befüllt die OU-ComboBox mit abgerufenen OUs]
        Write-DebugMessage "Befülle OU-ComboBox..."
        $comboBoxOU.BeginUpdate()
        $comboBoxOU.DisplayMember = "Name"
        $comboBoxOU.ValueMember   = "DN"
        $comboBoxOU.DataSource    = $script:allOUs
        $comboBoxOU.EndUpdate()

        # [7.1.3.2 | USER LISTBOX POPULATION]
        # [ENGLISH - Populate User ListBox with retrieved users]
        # [GERMAN - Befüllt die Benutzer-ListBox mit abgerufenen Benutzern]
        Write-DebugMessage "Befülle User-ListBox..."
        $listBoxUsers.BeginUpdate()
        $listBoxUsers.DataSource    = $script:allUsers
        $listBoxUsers.DisplayMember = "DisplayName"
        $listBoxUsers.ValueMember   = "SamAccountName"
        $listBoxUsers.BackColor = [System.Drawing.Color]::LightGray
        $listBoxUsers.ForeColor = [System.Drawing.Color]::DarkBlue
        $listBoxUsers.EndUpdate()
        
        Write-LogMessage "AD-Daten erfolgreich geladen" -logLevel "INFO"
    }
    catch {
        # [7.1.4 | ERROR HANDLING]
        # [ENGLISH - Handle errors during AD data retrieval]
        # [GERMAN - Behandelt Fehler während des Abrufs von AD-Daten]
        Write-LogMessage "Fehler beim Abrufen von AD-Daten: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.Forms.MessageBox]::Show("AD-Verbindungsfehler: $($_.Exception.Message)")
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
    if (-not $chkSpecial.Checked) {
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
# [ENGLISH - GUI element creation and layout definition]
# [GERMAN - GUI-Element-Erstellung und Layout-Definition]
#region GUI Construction
# [9.1 | MAIN FORM DIMENSIONS]
# [ENGLISH - Define main form dimensions and properties]
# [GERMAN - Definiert Abmessungen und Eigenschaften des Hauptformulars]
$frmWidth  = 650
$frmHeight = 850

# [9.2 | MAIN FORM]
# [ENGLISH - Create the main application form]
# [GERMAN - Erstellt das Hauptformular der Anwendung]
$form = New-Object System.Windows.Forms.Form
$form.Text = "AD Gruppenmanager v$($generalConfig.ScriptVersion)"
$form.Size = New-Object System.Drawing.Size($frmWidth, $frmHeight)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# [9.3 | HEADER SECTION]
# [ENGLISH - Create header panel with application title and logo]
# [GERMAN - Erstellt den Header-Bereich mit Anwendungstitel und Logo]
$headerPanel = New-Object System.Windows.Forms.Panel -Property @{
    Size      = New-Object System.Drawing.Size($frmWidth, 80)
    Location  = New-Object System.Drawing.Point(0, 0)
    BackColor = [System.Drawing.Color]::FromName($guiConfig.HeaderBackColor)
}
$headerLeft = New-Object System.Windows.Forms.Panel -Property @{
    Size     = New-Object System.Drawing.Size(($frmWidth - 260), 80)
    Location = New-Object System.Drawing.Point(10, 10)
}
$labelAppName = New-Object System.Windows.Forms.Label -Property @{
    Text      = $guiConfig.AppName
    Font      = New-Object System.Drawing.Font($guiConfig.AppFont, [int]$guiConfig.AppNameFontSize, [System.Drawing.FontStyle]::Bold)
    ForeColor = [System.Drawing.Color]::FromName($guiConfig.AppNameFontColor)
    AutoSize  = $true
    Location  = New-Object System.Drawing.Point(10, 20)
}
$headerLeft.Controls.Add($labelAppName)
$logoSizeParts = $guiConfig.AppLogoSize.Split(",")
$logoWidth  = [int]$logoSizeParts[0]
$logoHeight = [int]$logoSizeParts[1]
$headerRight = New-Object System.Windows.Forms.Panel -Property @{
    Size     = New-Object System.Drawing.Size($logoWidth, $logoHeight)
    Location = New-Object System.Drawing.Point(($frmWidth - $logoWidth - 20), 10)
}
$pictureBox = New-Object System.Windows.Forms.PictureBox -Property @{
    Size     = New-Object System.Drawing.Size($logoWidth, $logoHeight)
    SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
}
$logoPath = Join-Path $scriptDir $guiConfig.AppLogoPath
if (Test-Path $logoPath) {
    try { 
        $pictureBox.Image = [System.Drawing.Image]::FromFile($logoPath) 
    }
    catch { 
        Write-LogMessage "Fehler beim Laden des Logos: $($_.Exception.Message)" -logLevel "ERROR"
        # [9.3.1 | LOGO ERROR HANDLING]
        # [ENGLISH - Attempt to load default image or set to null]
        # [GERMAN - Versuche, ein Standardbild zu laden oder setze auf null]
        $pictureBox.Image = $null
    }
} else {
    Write-LogMessage "Logo-Datei nicht gefunden: $logoPath" -logLevel "WARNING"
}
$headerRight.Controls.Add($pictureBox)
$headerPanel.Controls.Add($headerLeft)
$headerPanel.Controls.Add($headerRight)
$form.Controls.Add($headerPanel)

# [9.4 | FOOTER SECTION]
# [ENGLISH - Create footer with application information and links]
# [GERMAN - Erstellt den Footer mit Anwendungsinformationen und Links]
$footerPanel = New-Object System.Windows.Forms.Panel -Property @{
    Size      = New-Object System.Drawing.Size($frmWidth, 30)
    Location  = New-Object System.Drawing.Point(0, ($frmHeight - 70))
    BackColor = [System.Drawing.Color]::FromName($guiConfig.FooterBackColor)
}
$linkLabel = New-Object System.Windows.Forms.LinkLabel -Property @{
    Text      = $generalConfig.WebsiteURLText
    Location  = New-Object System.Drawing.Point(10, 5)
    AutoSize  = $true
    ForeColor = [System.Drawing.Color]::FromName($guiConfig.FooterFontColor)
}
[void]$linkLabel.Links.Add(0, $linkLabel.Text.Length, $generalConfig.WebsiteURL)
$linkLabel.add_LinkClicked({ param($sender, $e) Start-Process $e.Link.LinkData })
$footerPanel.Controls.Add($linkLabel)
$labelInfo = New-Object System.Windows.Forms.Label -Property @{
    Text      = "Version: $($generalConfig.ScriptVersion) | Last Update: $($generalConfig.LastUpdate) | Author: $($generalConfig.Author)"
    AutoSize  = $true
    Location  = New-Object System.Drawing.Point(150, 5)
    ForeColor = [System.Drawing.Color]::FromName($guiConfig.FooterFontColor)
}
$footerPanel.Controls.Add($labelInfo)
$form.Controls.Add($footerPanel)

# [9.5 | MAIN PANEL]
# [ENGLISH - Create main panel for form content]
# [GERMAN - Erstellt das Hauptpanel für Formularinhalte]
$mainPanel = New-Object System.Windows.Forms.Panel -Property @{
    Location    = New-Object System.Drawing.Point(10, ($headerPanel.Height + 10))
    Size        = New-Object System.Drawing.Size(($frmWidth - 20), ($frmHeight - $headerPanel.Height - $footerPanel.Height - 20))
    BorderStyle = [System.Windows.Forms.BorderStyle]::None
}
$form.Controls.Add($mainPanel)
$topLine = New-Object System.Windows.Forms.Panel -Property @{
    BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
    Location    = New-Object System.Drawing.Point(0, 0)
    Size        = New-Object System.Drawing.Size($mainPanel.Width, 2)
    Anchor      = "Top,Left,Right"
}
$mainPanel.Controls.Add($topLine)

# [9.6 | OU SELECTION PANEL]
# [ENGLISH - Create panel for OU selection]
# [GERMAN - Erstellt ein Panel für die OU-Auswahl]
$ouPanel = New-Object System.Windows.Forms.Panel -Property @{
    Location    = New-Object System.Drawing.Point(10, 10)
    Size        = New-Object System.Drawing.Size(600, 120)
    BorderStyle = "FixedSingle"
}
$labelOUFilter = New-Object System.Windows.Forms.Label -Property @{
    Location = New-Object System.Drawing.Point(10, 10)
    Size     = New-Object System.Drawing.Size(580, 20)
    Text     = "OU Filter:"
    Font     = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
}
$ouPanel.Controls.Add($labelOUFilter)
$textBoxOUFilter = New-Object System.Windows.Forms.TextBox -Property @{
    Location = New-Object System.Drawing.Point(10, 35)
    Size     = New-Object System.Drawing.Size(580, 20)
}
$textBoxOUFilter.Add_TextChanged({
    $filter = $textBoxOUFilter.Text.Trim()
    $filtered = if ($filter) { $script:allOUs | Where-Object { $_.Name -like "*$filter*" } } else { $script:allOUs }
    $comboBoxOU.BeginUpdate()
    $comboBoxOU.DataSource = $filtered
    $comboBoxOU.EndUpdate()
})
$ouPanel.Controls.Add($textBoxOUFilter)
$comboBoxOU = New-Object System.Windows.Forms.ComboBox -Property @{
    Location = New-Object System.Drawing.Point(10, 70)
    Size     = New-Object System.Drawing.Size(580, 20)
    DropDownStyle = "DropDownList"
}
$ouPanel.Controls.Add($comboBoxOU)
$mainPanel.Controls.Add($ouPanel)

# [9.7 | GROUP CREATION PANEL]
# [ENGLISH - Create panel for group creation]
# [GERMAN - Erstellt ein Panel für die Gruppenerstellung]
$groupPanel = New-Object System.Windows.Forms.Panel -Property @{
    Location    = New-Object System.Drawing.Point(10, 140)
    Size        = New-Object System.Drawing.Size(600, 480)
    BorderStyle = "FixedSingle"
}
# [9.7.1 | GROUP NAME]
# [ENGLISH - Group name input fields]
# [GERMAN - Eingabefelder für Gruppennamen]
$labelGroupName = New-Object System.Windows.Forms.Label -Property @{
    Location = New-Object System.Drawing.Point(10, 10)
    Size     = New-Object System.Drawing.Size(280, 20)
    Text     = "Group Name:"
    Font     = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
}
$groupPanel.Controls.Add($labelGroupName)
$textBoxPrefix = New-Object System.Windows.Forms.TextBox -Property @{
    Location = New-Object System.Drawing.Point(10, 35)
    Size     = New-Object System.Drawing.Size(420, 20)
}
$groupPanel.Controls.Add($textBoxPrefix)
# [9.7.2 | SEPARATOR]
# [ENGLISH - Separator input field]
# [GERMAN - Eingabefeld für Trenner]
$labelSeparator = New-Object System.Windows.Forms.Label -Property @{
    Location = New-Object System.Drawing.Point(435, 10)
    Size     = New-Object System.Drawing.Size(125, 20)
    Text     = "Separator:"
    Font     = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
}
$groupPanel.Controls.Add($labelSeparator)
$textBoxSeparator = New-Object System.Windows.Forms.TextBox -Property @{
    Location = New-Object System.Drawing.Point(435, 35)
    Size     = New-Object System.Drawing.Size(150, 20)
    Text     = "-"  # Gültiger Trenner
}
$groupPanel.Controls.Add($textBoxSeparator)
# [9.7.3 | START NUMBER, END NUMBER, DESCRIPTION]
# [ENGLISH - Start number, end number, and description input fields]
# [GERMAN - Eingabefelder für Startnummer, Endnummer und Beschreibung]
$labelStart = New-Object System.Windows.Forms.Label -Property @{
    Location = New-Object System.Drawing.Point(10, 70)
    Size     = New-Object System.Drawing.Size(100, 20)
    Text     = "Start Number:"
    Font     = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
}
$groupPanel.Controls.Add($labelStart)
$textBoxStart = New-Object System.Windows.Forms.TextBox -Property @{
    Location = New-Object System.Drawing.Point(10, 95)
}
$groupPanel.Controls.Add($textBoxStart)
$labelEnd = New-Object System.Windows.Forms.Label -Property @{
    Location = New-Object System.Drawing.Point(120, 70)
    Size     = New-Object System.Drawing.Size(100, 20)
    Text     = "End Number:"
    Font     = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
}
$groupPanel.Controls.Add($labelEnd)
$textBoxEnd = New-Object System.Windows.Forms.TextBox -Property @{
    Location = New-Object System.Drawing.Point(120, 95)
}
$groupPanel.Controls.Add($textBoxEnd)
$labelDescription = New-Object System.Windows.Forms.Label -Property @{
    Location = New-Object System.Drawing.Point(230, 70)
    Size     = New-Object System.Drawing.Size(560, 20)
    Text     = "Description:"
    Font     = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
}
$groupPanel.Controls.Add($labelDescription)
$textBoxDescription = New-Object System.Windows.Forms.TextBox -Property @{
    Location = New-Object System.Drawing.Point(230, 95)
    Size     = New-Object System.Drawing.Size(355, 20)
    Text     = $adgroupsConfig.GroupDescription
}
$groupPanel.Controls.Add($textBoxDescription)

# [9.7.4 | GROUP TYPE PANEL]
# [ENGLISH - Panel for group type selection]
# [GERMAN - Panel für die Auswahl des Gruppentyps]
$panelGroupType = New-Object System.Windows.Forms.Panel -Property @{
    Location = New-Object System.Drawing.Point(10, 130)
    Size     = New-Object System.Drawing.Size(300, 30)
}
$labelGroupType = New-Object System.Windows.Forms.Label -Property @{
    Text     = "Group Type:"
    Location = New-Object System.Drawing.Point(0, 5)
    Size     = New-Object System.Drawing.Size(70, 20)
    Font     = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
}
$panelGroupType.Controls.Add($labelGroupType)
$radioSecurity = New-Object System.Windows.Forms.RadioButton -Property @{
    Text     = "Security"
    Location = New-Object System.Drawing.Point(75, 5)
    AutoSize = $true
    Checked  = $true
}
$radioDistribution = New-Object System.Windows.Forms.RadioButton -Property @{
    Text     = "Distribution"
    Location = New-Object System.Drawing.Point(140, 5)
    AutoSize = $true
}
$panelGroupType.Controls.Add($radioSecurity)
$panelGroupType.Controls.Add($radioDistribution)
$groupPanel.Controls.Add($panelGroupType)

# [9.7.5 | GROUP SCOPE PANEL]
# [ENGLISH - Panel for group scope selection]
# [GERMAN - Panel für die Auswahl des Gruppenscopes]
$panelGroupScope = New-Object System.Windows.Forms.Panel -Property @{
    Location = New-Object System.Drawing.Point(325, 130)
    Size     = New-Object System.Drawing.Size(220, 30)
}
$labelGroupScope = New-Object System.Windows.Forms.Label -Property @{
    Text     = "Scope:"
    Location = New-Object System.Drawing.Point(25, 5)
    Size     = New-Object System.Drawing.Size(45, 20)
    Font     = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
}
$panelGroupScope.Controls.Add($labelGroupScope)
$radioGlobal = New-Object System.Windows.Forms.RadioButton -Property @{
    Text     = "Global"
    Location = New-Object System.Drawing.Point(70, 5)
    AutoSize = $true
    Checked  = $true
}
$radioUniversal = New-Object System.Windows.Forms.RadioButton -Property @{
    Text     = "Universal"
    Location = New-Object System.Drawing.Point(140, 5)
    AutoSize = $true
}
$radioDomainLocal = New-Object System.Windows.Forms.RadioButton -Property @{
    Text     = "DomainLocal"
    Location = New-Object System.Drawing.Point(220, 5)
    AutoSize = $true
}
$panelGroupScope.Controls.Add($radioGlobal)
$panelGroupScope.Controls.Add($radioUniversal)
$panelGroupScope.Controls.Add($radioDomainLocal)
$groupPanel.Controls.Add($panelGroupScope)

# [9.7.6 | SPECIAL MODE CHECKBOX]
# [ENGLISH - Checkbox for special mode (JIRA/Confluence groups)]
# [GERMAN - Checkbox für Spezialmodus (JIRA/Confluence-Gruppen)]
$chkSpecial = New-Object System.Windows.Forms.CheckBox -Property @{
    Text     = "JIRA / Confluence Gruppe(n) erstellen (Suffix aus INI)"
    Location = New-Object System.Drawing.Point(10, 450)
    AutoSize = $true
}
$groupPanel.Controls.Add($chkSpecial)

# [9.7.7 | MEMBERS LISTBOX]
# [ENGLISH - ListBox for group members]
# [GERMAN - ListBox für Gruppenmitglieder]
$labelMembers = New-Object System.Windows.Forms.Label -Property @{
    Location = New-Object System.Drawing.Point(10, 170)
    Size     = New-Object System.Drawing.Size(580, 20)
    Text     = "Members:"
    Font     = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
}
$groupPanel.Controls.Add($labelMembers)
$listBoxUsers = New-Object System.Windows.Forms.ListBox -Property @{
    Location = New-Object System.Drawing.Point(10, 190)
    Size     = New-Object System.Drawing.Size(580, 250)
    SelectionMode = "MultiExtended"
    BackColor = [System.Drawing.Color]::LightGray
    ForeColor = [System.Drawing.Color]::DarkBlue
}
$groupPanel.Controls.Add($listBoxUsers)
$mainPanel.Controls.Add($groupPanel)

# [10.0 | ACTION BUTTONS]
# [ENGLISH - Implementation of button click handlers and related functionality]
# [GERMAN - Implementierung von Button-Click-Handlern und zugehöriger Funktionalität]
#region Action Buttons
# [10.1 | PREVIEW BUTTON]
# [ENGLISH - Button for previewing group creation]
# [GERMAN - Button für die Vorschau der Gruppenerstellung]
$buttonPreview = New-Object System.Windows.Forms.Button -Property @{
    Location = New-Object System.Drawing.Point(30, 630)
    Size     = New-Object System.Drawing.Size(90, 30)
    Text     = "Preview"
    BackColor= [System.Drawing.Color]::LightBlue
}
$buttonPreview.Add_Click({
    Write-DebugMessage "Vorschau-Button geklickt"
    $errors = Test-Input
    if ($errors.Count -gt 0) {
        Write-LogMessage "Validierungsfehler bei Vorschau: $($errors -join ', ')" -logLevel "WARNING"
        [System.Windows.Forms.MessageBox]::Show(($errors -join "`n"), "Validierungsfehler")
        return
    }
    $groups = @()
    if ($chkSpecial.Checked) {
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
    [System.Windows.Forms.MessageBox]::Show($groups -join "`n----------------`n", "Vorschau")
})
$mainPanel.Controls.Add($buttonPreview)

# [10.2 | CREATE BUTTON]
# [ENGLISH - Button for creating groups]
# [GERMAN - Button für die Erstellung von Gruppen]
$buttonCreate = New-Object System.Windows.Forms.Button -Property @{
    Location = New-Object System.Drawing.Point(130, 630)
    Size     = New-Object System.Drawing.Size(90, 30)
    Text     = "Create"
    BackColor= [System.Drawing.Color]::LightGreen
}
$buttonCreate.Add_Click({
    Write-LogMessage "Erstellungs-Button geklickt" -logLevel "INFO"
    $errors = Test-Input
    if ($errors.Count -gt 0) {
        Write-LogMessage "Validierungsfehler bei Gruppenerstellung: $($errors -join ', ')" -logLevel "WARNING"
        [System.Windows.Forms.MessageBox]::Show(($errors -join "`n"), "Validierungsfehler")
        return
    }
    $progressForm = New-Object System.Windows.Forms.Form -Property @{
        Text = "Erstellung läuft..."
        Size = New-Object System.Drawing.Size(300, 100)
        StartPosition = "CenterScreen"
        FormBorderStyle = "FixedDialog"
        TopMost = $true
    }
    $progressBar = New-Object System.Windows.Forms.ProgressBar -Property @{
        Location = New-Object System.Drawing.Point(10, 10)
        Size     = New-Object System.Drawing.Size(280, 20)
        Style    = "Continuous"
        Minimum  = 0
        Maximum  = 100
        Value    = 0
    }
    $progressForm.Controls.Add($progressBar)
    $progressForm.Show()
    $progressForm.Refresh()
    
    # FIXIERT: Verbesserte Benutzerauswahl-Extraktion
    $script:selectedUsers = @()
    if ($listBoxUsers.SelectedItems.Count -gt 0) {
        Write-DebugMessage "Ausgewählte Benutzer werden extrahiert... ($($listBoxUsers.SelectedItems.Count) Elemente)"
        
        foreach ($selectedItem in $listBoxUsers.SelectedItems) {
            try {
                # Korrekter Zugriff auf die SamAccountName-Eigenschaft
                $samAccountName = $selectedItem.Item("SamAccountName")
                if (-not [string]::IsNullOrWhiteSpace($samAccountName)) {
                    $script:selectedUsers += $samAccountName
                    Write-DebugMessage "Benutzer ausgewählt: $samAccountName"
                }
            }
            catch {
                Write-LogMessage "Fehler beim Extrahieren des SamAccountName: $($_.Exception.Message)" -logLevel "WARNING"
                Write-DebugMessage "Ausgewähltes Item-Typ: $($selectedItem.GetType().FullName)"
                Write-DebugMessage "Properties: $($selectedItem | Format-List | Out-String)"
            }
        }
        
        Write-LogMessage "Es wurden $($script:selectedUsers.Count) Benutzer für die Gruppenmitgliedschaft ausgewählt" -logLevel "INFO"
        Write-DebugMessage "Ausgewählte Benutzer: $($script:selectedUsers -join ', ')"
    } else {
        Write-LogMessage "Keine Benutzer für Gruppenmitgliedschaft ausgewählt" -logLevel "INFO"
    }
    
    try {
        $groupsToCreate = @()
        if ($chkSpecial.Checked) {
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
                Path          = if ($comboBoxOU.SelectedValue -is [string]) { $comboBoxOU.SelectedValue } else { $comboBoxOU.SelectedValue.DN }
                GroupScope    = if ($radioGlobal.Checked) { "Global" } elseif ($radioUniversal.Checked) { "Universal" } else { "DomainLocal" }
                Description   = if ($textBoxDescription.Text) { $textBoxDescription.Text } else { $adgroupsConfig.GroupDescription }
                DisplayName   = $groupName
            }
            
            # Debug-Ausgabe erweitern zur besseren Fehlerdiagnose
            Write-DebugMessage "Erstelle Gruppe: $groupName mit Pfad: $($params.Path) (Typ: $($params.Path.GetType().FullName))"
            
            # Server-Parameter nur hinzufügen, wenn ADServer definiert ist
            if ($os.ProductType -eq 1 -and $adConfig.ADServer) { 
                $params["Server"] = $adConfig.ADServer 
            }
            
            Write-DebugMessage "Erstelle Gruppe: $($params | ConvertTo-Json -Compress)"
            try {
                # Verbesserte Prüfung, ob die Gruppe bereits existiert (nach SAMAccountName)
                $existingGroup = $null
                try {
                    $existingGroup = Get-ADGroup -Identity $samAccountName -Properties * -ErrorAction SilentlyContinue
                }
                catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                    # Gruppe existiert nicht - das ist gut
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
                    
                    # FIXIERT: Verbesserte Benutzerverarbeitung
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
                            Write-DebugMessage "Vollständige Fehlerdetails: $($_ | Format-List -Force | Out-String)"
                            
                            # Fallback: Versuche es erneut mit dem DN der Gruppe
                            try {
                                Add-ADGroupMember -Identity $group.DistinguishedName -Members $script:selectedUsers -ErrorAction Stop
                                Write-LogMessage "Mitglieder zu $groupName hinzugefügt (2. Versuch mit DN)" -logLevel "INFO"
                            } catch {
                                Write-LogMessage "Auch 2. Versuch zum Hinzufügen der Mitglieder fehlgeschlagen" -logLevel "ERROR"
                            }
                        }
                    } else {
                        Write-DebugMessage "Keine Benutzer aus GUI zur Gruppe hinzuzufügen"
                    }
                    
                    # INI-basierte Benutzer
                    if ($adgroupsConfig.GroupMembersAddActive -eq "1") {
                        $fixedMembers = $adgroupsConfig.GroupMembersAdd.Split(",")
                        if ($fixedMembers) { 
                            Write-DebugMessage "Füge feste Mitglieder aus INI hinzu: $($fixedMembers -join ', ')"
                            try {
                                Add-ADGroupMember -Identity $group -Members $fixedMembers -ErrorAction Stop
                                Write-LogMessage "Feste Mitglieder zu $groupName hinzugefügt: $($fixedMembers -join ', ')" -logLevel "INFO"
                            } catch {
                                Write-LogMessage "Fehler beim Hinzufügen fester Mitglieder zu ${groupName}: $($_.Exception.Message)" -logLevel "WARNING"
                            }
                        }
                    }
                    
                    Write-LogMessage "Gruppe $groupName erfolgreich erstellt" -logLevel "INFO"
                } 
                catch {
                    Write-LogMessage "Fehler beim Erstellen der Gruppe ${groupName}: $($_.Exception.Message)" -logLevel "ERROR"
                    # Detaillierte Fehlerinformationen ausgeben
                    if ($generalConfig.Debug -eq "1") {
                        Write-DebugMessage "Exception-Details: $($_ | Format-List -Force | Out-String)"
                    }
                }
            }
            catch {
                Write-LogMessage "Fehler bei ${groupName}: $($_.Exception.Message)" -logLevel "ERROR"
            }
            
            $count++
            # UI-Thread-sichere Aktualisierung der ProgressBar
            $progressBar.Value = [Math]::Min([int](($count / $total) * 100), 100)
            $progressForm.Text = "Fortschritt: $($count)/$($total)"
            [System.Windows.Forms.Application]::DoEvents()
            
            Write-DebugMessage "Fortschritt: $count/$total Gruppen erstellt"
        }
        
        Write-LogMessage "Gruppenerstellung abgeschlossen. $count/$total Gruppen erstellt." -logLevel "INFO"
        [System.Windows.Forms.MessageBox]::Show("$count Gruppen erfolgreich erstellt.", "Erstellung abgeschlossen", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    finally {
        $progressForm.Close()
    }
})
$mainPanel.Controls.Add($buttonCreate)

# [10.3 | CLOSE BUTTON]
# Hinzufügen eines Schließen-Buttons für bessere Benutzerfreundlichkeit
$buttonClose = New-Object System.Windows.Forms.Button -Property @{
    Location = New-Object System.Drawing.Point(230, 630)
    Size     = New-Object System.Drawing.Size(90, 30)
    Text     = "Schließen"
    BackColor= [System.Drawing.Color]::LightCoral
}
$buttonClose.Add_Click({
    Write-LogMessage "Anwendung wird beendet" -logLevel "INFO"
    $form.Close()
})
$mainPanel.Controls.Add($buttonClose)
#endregion

# [11.0 | MAIN EXECUTION]
# [ENGLISH - Main script execution and form display]
# [GERMAN - Hauptskriptausführung und Formularanzeige]
Write-DebugMessage "Starte AD-Datenabfrage"
Get-ADData
Write-DebugMessage "GUI wird angezeigt"
$form.Add_Shown({ 
    Write-DebugMessage "Formular wird aktiviert"
    $form.Activate() 
})
[void]$form.ShowDialog()
Write-LogMessage "Script beendet" -logLevel "INFO"

# SIG # Begin signature block
# MIIcCAYJKoZIhvcNAQcCoIIb+TCCG/UCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBpplLFFFa78lYv
# d6lIODG+KOb27VdlrC68YzVpiiuyCaCCFk4wggMQMIIB+KADAgECAhB3jzsyX9Cg
# jEi+sBC2rBMTMA0GCSqGSIb3DQEBCwUAMCAxHjAcBgNVBAMMFVBoaW5JVC1QU3Nj
# cmlwdHNfU2lnbjAeFw0yNTA3MDUwODI4MTZaFw0yNzA3MDUwODM4MTZaMCAxHjAc
# BgNVBAMMFVBoaW5JVC1QU3NjcmlwdHNfU2lnbjCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBALmz3o//iDA5MvAndTjGX7/AvzTSACClfuUR9WYK0f6Ut2dI
# mPxn+Y9pZlLjXIpZT0H2Lvxq5aSI+aYeFtuJ8/0lULYNCVT31Bf+HxervRBKsUyi
# W9+4PH6STxo3Pl4l56UNQMcWLPNjDORWRPWHn0f99iNtjI+L4tUC/LoWSs3obzxN
# 3uTypzlaPBxis2qFSTR5SWqFdZdRkcuI5LNsJjyc/QWdTYRrfmVqp0QrvcxzCv8u
# EiVuni6jkXfiE6wz+oeI3L2iR+ywmU6CUX4tPWoS9VTtmm7AhEpasRTmrrnSg20Q
# jiBa1eH5TyLAH3TcYMxhfMbN9a2xDX5pzM65EJUCAwEAAaNGMEQwDgYDVR0PAQH/
# BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQO7XOqiE/EYi+n
# IaR6YO5M2MUuVTANBgkqhkiG9w0BAQsFAAOCAQEAjYOKIwBu1pfbdvEFFaR/uY88
# peKPk0NnvNEc3dpGdOv+Fsgbz27JPvItITFd6AKMoN1W48YjQLaU22M2jdhjGN5i
# FSobznP5KgQCDkRsuoDKiIOTiKAAknjhoBaCCEZGw8SZgKJtWzbST36Thsdd/won
# ihLsuoLxfcFnmBfrXh3rTIvTwvfujob68s0Sf5derHP/F+nphTymlg+y4VTEAijk
# g2dhy8RAsbS2JYZT7K5aEJpPXMiOLBqd7oTGfM7y5sLk2LIM4cT8hzgz3v5yPMkF
# H2MdR//K403e1EKH9MsGuGAJZddVN8ppaiESoPLoXrgnw2SY5KCmhYw1xRFdjTCC
# BY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290
# IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE9
# 8orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9S
# H8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g
# 1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RY
# jgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgD
# EI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNA
# vwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDg
# ohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQA
# zH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOk
# GLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHF
# ynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gd
# LfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
# FOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNy
# dDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkq
# hkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7
# IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/5
# 9PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0
# POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISf
# b8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhU
# LSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDCCBrQwggScoAMCAQICEA3H
# rFcF/yGZLkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEh
# MB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1MDUwNzAwMDAw
# MFoXDTM4MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFt
# cGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2tjQ2UtZmWgyxU
# 7UNqEY81FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWCWgzbNfiR
# +2fkHUiljNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vtLa4+gKPsYfwE
# u7EEbkC9+0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0XaF9DPfNBKS7Za
# zch8NF5vp7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhxKTVVgtmUPAW3
# 5xUUFREmDrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXKFifinT7zL2gd
# FpBP9qh8SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x5HHKS+rq
# BvKWxdCyQEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F20HHfIY4/6vH
# espYMQmUiote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQyogxG9QE
# PHrPV6/7umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u70EwgWbVRSX1
# Wd4+zoFpp4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczsG7ZrIGNTAgMB
# AAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTvb1NK6eQG
# fHrK4pBW9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAO
# BgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEE
# azBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYB
# BQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0
# ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYG
# Z4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAF877FoAc/gc9
# EXZxML2+C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI9NAzaoQk
# 97frPBtIj+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ3essBS3q8nL2
# UwM+NMvEuBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qKtntujB71
# WPYAgwPyWLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I+ZI2rVQf
# jXQA1WSjjf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q17r0z0noD
# js6+BFo+z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9M+MtucVGyOxi
# Df06VXxyKkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSmE+9JGYxOGLS/
# D284NHNboDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlHqhpB/8Ml
# uDezooIs8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7GELH3IdvG
# 2XlM9q7WP/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKdvlarEvf8EA+8
# hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAKgO8YS43xBYLR
# xHanlXRoMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5E
# aWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1l
# U3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAwMDAw
# WhcNMzYwOTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNl
# cnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRpbWVz
# dGFtcCBSZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEA0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfMGUIwYzKomd8U1nH7C8Dr
# 0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFPJIDZHhAqlUPt281mHrBb
# ZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMUNg7MOLxI6E9RaUueHTQK
# WXymOtRwJXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjKs3SKO1QNUdFd2adw44wD
# cKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8odbkqoK+lJ25LCHBSai25
# CFyD23DZgPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK40uhktzUd/Yk0xUvhDU6l
# vJukx7jphx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk12hE5FVs9HVVWcO5J4dV
# mVzix4A77p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2hSgctaepZTd0ILIUbWuh
# KuAeNIeWrzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6CtjuuVHJOVoIJ/DtpJRE7C
# e7vMRHoRon4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT3pXWETTJkhd76CIDBbTR
# ofOsNyEhzZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A9/z7eacCAwEAAaOCAZUw
# ggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx7f391/ORcWMZUEPPYYzo
# MB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIH
# gDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZR
# aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGlt
# ZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBS
# oFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRp
# bWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgG
# BmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAGUqrfEcJwS5
# rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP2AGr181o2YWPoSHz9iZE
# N/FPsLSTwVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7YXwB
# D9R0oU62PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75ZSpbh1oipOhcUT8lD8QA
# GB9lctZTTOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihsQyfFg5fxUFEp7W42fNBV
# N4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQJmmrJTV3Qhtfparz+BW6
# 0OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz0BZwhB9WOfOu/CIJnzkQ
# TwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8MmB10nfldPF9SVD7weCC
# 3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjFBtXVLcKtapnMG3VH3EmA
# p/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJVxwC+UpX2MSey2ueIu9T
# HFVkT+um1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFlTxq25+T4QwX9xa6ILs84
# ZPvmpovq90K8eWyG2N01c4IhSOxqt81nMYIFEDCCBQwCAQEwNDAgMR4wHAYDVQQD
# DBVQaGluSVQtUFNzY3JpcHRzX1NpZ24CEHePOzJf0KCMSL6wELasExMwDQYJYIZI
# AWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0B
# CQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAv
# BgkqhkiG9w0BCQQxIgQgVOs3T6AfN09RL0d/LeJmldM1U7HzdByQzE53ZM4eZAkw
# DQYJKoZIhvcNAQEBBQAEggEAl0VhzuZWovU9+YY4yglLLROlcI9p/vb4Q7dYXgBe
# YgqifqkodgNvpIlM28uoUR2fbXOV4zLggvGFHEOPhrWVNSY2PUwKUSBhuo5xyO8a
# PnGyEtk5Xvqc0TUv9o7X65aekzgFZvYtQI0cHoJ+YGEnmxsPnIKplikhpwgYUcdu
# p2DJRSfcOzxTjqq5jMuwPJqCda134m5bHfR7ETeXHIFIxU/gQ0zoj/0ro7+8Srr6
# vPZBCl1CES/KZgtogziuDMA4d/X+0vvx6OGFESqWoUVJJlm5UlPhtVW9yRh/PFSJ
# J0wFH3APCOHIDa7G0nAb5O44wvDFmHZwIPRDWup4m+j7caGCAyYwggMiBgkqhkiG
# 9w0BCQYxggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdp
# Q2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3Rh
# bXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgw
# DQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqG
# SIb3DQEJBTEPFw0yNTA3MTIwODAwMThaMC8GCSqGSIb3DQEJBDEiBCC6woftAWgc
# FLmemMnQGF9He1lB9mHt3/ZFBFG3rI7aRzANBgkqhkiG9w0BAQEFAASCAgCth1+t
# aPBTCHHqHlYMe0gZUVBa5wHsPSfivE4PZ5AwbbD9I9SUVdMEgfLgnK9Gc6pQNhZS
# PvfvJoq1NeTlfUUdQaXX13Bs1ydm+GOQ9kQiyDGGI9HmP8uV6T3F8Lgg2dp7kXfi
# rieWljdHY3FiDZa09erRciMof3gGgbKfBG5z8rX2DT3Apc7C4Xu2KS+10nU0jMDr
# 4AsGmYkXczsPvJR2um9j0O+gncetfk+rwOcuGAjxlk48ILNoif75rUb/ZF5uOD84
# RvBina1i46B3RXG9hjtko4nmg9isCo8dskCy6FyQwX/FrJl2zJhsq2AOkKwDMEby
# e8hbgu0NPX+2Q2kdQdCvSB1bsb/7j24MwBKii1/7MUtWGGCAP3wq110LnPHcowBF
# 5ox17/BMpGxn9mirchXz4KQpXZbY9sti3ff9nnHGQFr3HYi+94oKv+XFPaW5dgV9
# qfKUbw2MTsAcbQnkCFJ1+SGt/75n5huseBfQlEI704vS7II5mEls8L7Ei6zi0hT7
# qBpWOsN2GpB6LAjO3/PRW7EHq6zFNtsNGG0Yv9HbRR5hcJmJxxzACKS2h/qTNyin
# eBaYF+uC9Gb9Pd6/DITx30mazOq9dKaj683IvM8+osnKfviX9K0lTiHA2pTEvy7q
# SaCppdvFYWJdaruKz4yJnXVp4PkDNxr1C9bkmQ==
# SIG # End signature block
