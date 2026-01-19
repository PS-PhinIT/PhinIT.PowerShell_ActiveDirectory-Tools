<#
  ####################################################################################################
  # easyADgroup - PowerShell GUI for Active Directory Group Management
  # Author:         Andreas Hepp
  # Website:        https://phinit.de/easyit-tools/
  # GitHub:         https://github.com/PS-easyIT
  # Version:        0.4.0 (Build: 2025-05-26)
  ####################################################################################################
  
  Modern GUI-based interface for Active Directory group management with enhanced features:
  
  Features:
  - Bulk group creation with advanced templates
  - RBAC integration and approval workflows
  - REST API support for external integrations
  - Real-time validation and duplicate detection
  - Advanced reporting with PowerBI integration
  - Multi-domain support with forest-wide operations
  - Modern dark/light theme support
  - Automated group lifecycle management
  - Azure AD/Entra ID synchronization
  - PowerShell 7+ compatibility with cross-platform support

  Requirements:
  - PowerShell 7.0+ (recommended for modern features)
  - Active Directory module
  - Administrator privileges
  - .NET 6.0+ for enhanced GUI performance

  ####################################################################################################
#>

#Requires -Version 7.0
#Requires -Modules ActiveDirectory
#Requires -RunAsAdministrator

using namespace System.Collections.Generic
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation

# Script path detection with enhanced error handling
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

# Modern configuration with JSON-based settings
$script:Config = @{
    Version = "0.4.0"
    Build = Get-Date -Format "yyyy-MM-dd"
    Features = @{
        RestAPI = $true
        AzureADSync = $true
        ApprovalWorkflow = $true
        AdvancedReporting = $true
        MultiDomain = $true
        DarkTheme = $true
    }
    Performance = @{
        MaxConcurrentOperations = 10
        BatchSize = 100
        CacheTimeout = 300
    }
    Security = @{
        AuditLogging = $true
        EncryptedStorage = $true
        TwoFactorAuth = $false
    }
}

# [1.0 | SCRIPT PATH DETECTION]
#region Script Path Detection
if ($MyInvocation.MyCommand.Definition -match '\.exe$') {
    $scriptDir = [System.IO.Path]::GetDirectoryName([System.Reflection.Assembly]::GetEntryAssembly().Location)
} else {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
#endregion

# [2.0 | DEPENDENCY VERIFICATION]
#region Dependency Verification
# [2.1 | POWERSHELL VERSION CHECK]
if ($PSVersionTable.PSVersion -lt [Version]"7.0") {
    Write-Error "PowerShell 7.0+ required for optimal performance"
    exit
}

# [2.2 | ADMIN RIGHTS CHECK]
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Dieses Script muss als Administrator ausgeführt werden."
    exit
}

# [2.3 | MODULE AVAILABILITY CHECK]
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
    if ((Get-CimInstance -ClassName Win32_OperatingSystem).Version -ge "10.0.17763") {
        $adToolsInstalled = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'Rsat.ActiveDirectory.DS-LDS.Tools*' -and $_.State -eq 'Installed' }
        if (-not $adToolsInstalled) {
            Write-Error "Die benötigten RSAT-AD-Tools wurden nicht gefunden. Bitte installieren und erneut ausführen."
            exit
        }
    }
    # [2.3.2 | OLDER WINDOWS VERSIONS CHECK]
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
#region Type Imports
# WPF-spezifische Assemblies laden
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, Microsoft.VisualBasic
#endregion

# [3.1 | GLOBAL VARIABLES INITIALIZATION]
$script:createdGroups = New-Object System.Collections.ArrayList
$script:selectedUsers = @()
$script:allUsers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
$script:filteredUsers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
$script:templates = @{}
$script:currentTemplate = $null
$script:templates = @{}
$script:currentTemplate = $null

# [4.0 | EMBEDDED CONFIGURATION]
#region Embedded Configuration

# [4.1 | CONFIGURATION DEFINITION]
$generalConfig = @{
    ScriptVersion = "0.3.1"
    LastUpdate = "26.05.2025"
    Author = "Andreas Hepp"
    WebsiteURL = "https://github.com/PS-easyIT"
    WebsiteURLText = "www.PSscripts.de"
    Debug = "0"
}

$loggingConfig = @{
    LogFileName = "easyADGroups.log"
    LogActive = "1"
    LogLevel = "INFO"
}

$guiConfig = @{
    HeaderBackColor = "#0078D4"
    FooterBackColor = "#F8F8F8"
    FooterFontColor = "#605E5C"
    AppName = "easyADgroup"
    AppNameFontSize = "20"
    AppNameFontColor = "White"
    AppFont = "Segoe UI"
    AppInfoText = "ScriptVersion | LastUpdate | Author | WebsiteURLText"
    PrimaryColor = "#0078D4"
    SecondaryColor = "#F3F2F1"
    AccentColor = "#005A9E"
    BackgroundColor = "#F3F3F3"
    TextColor = "#323130"
}

$adConfig = @{
    ADServer = "localhost"
    ADServerPort = "389"
    MaxUsersToLoad = "500"
    DefaultGroupOU = "OU=Groups,DC=domain,DC=com"
}

$adgroupsConfig = @{
    GroupDescription = "Created with easyADgroup"
    AdditionalSuffixes = "RW,R,ADM"
    GroupMembersAddActive = "0"
    GroupMembersAdd = ""
    DefaultGroupType = "Security"
    DefaultGroupScope = "Global"
    AutoNamingEnabled = "0"
    NamingTemplate = "GRP_{NAME}_{SUFFIX}"
}

$validationConfig = @{
    ValidateGroupNames = "1"
    CheckDuplicates = "1"
    MaxGroupNameLength = "200"
    MaxSamAccountNameLength = "20"
    InvalidCharacters = '\/:*?"<>|,;@[]{}+=&~!#%^()''`'
    MaxGroupsPerBatch = "1000"
}

$advancedConfig = @{
    AdvancedOptionsEnabled = "1"
    AutoCreateOUEnabled = "1"
    DefaultDryRun = "0"
    ShowProgressBar = "1"
    SearchDelayMs = "500"
}

Write-Host "Embedded configuration loaded successfully" -ForegroundColor Green
#endregion

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
    Write-Host "Log directory created: $logDir" -ForegroundColor Yellow
}

# Erstelle eindeutigen Log-Dateinamen mit Zeitstempel
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFileName = "LOG_easyADGroups-$timestamp-$($loggingConfig.LogFileName)"
$script:config = @{
    LogPath = Join-Path $logDir $logFileName
}

# Teste Schreibzugriff auf Log-Datei
try {
    "Log file initialized at $(Get-Date)" | Out-File -FilePath $script:config.LogPath -Encoding UTF8 -ErrorAction Stop
    Write-Host "Log file created: $($script:config.LogPath)" -ForegroundColor Gray
}
catch {
    Write-Host "WARNING: Cannot create log file: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Logging will be done to console only." -ForegroundColor Yellow
    $script:config.LogPath = $null
}

# [4.8 | TEMPLATES DIRECTORY SETUP]
# [ENGLISH - Setup templates directory for saving/loading configurations]
# [GERMAN - Richtet das Vorlagen-Verzeichnis zum Speichern/Laden von Konfigurationen ein]
$templatesDir = Join-Path $scriptDir "templates"
if (-not (Test-Path $templatesDir)) { 
    New-Item -Path $templatesDir -ItemType Directory | Out-Null 
    Write-Host "Vorlagen-Verzeichnis erstellt: $templatesDir" -ForegroundColor Yellow
}
#endregion

# [5.0 | LOGGING FUNCTIONS]
# [ENGLISH - Defines logging capabilities for different message levels]
# [GERMAN - Definiert Protokollierungsfunktionen für verschiedene Nachrichtenebenen]
#region Logging Message Functions
function Write-LogMessage {
    # [5.1 | PRIMARY LOGGING WRAPPER]
    param(
        [string]$message,
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        [string]$logLevel = "INFO"
    )
    Write-Log -message $message -Level $logLevel
    
    # [5.1.1 | CONSOLE OUTPUT]
    if ($logLevel -eq "DEBUG" -and $generalConfig.Debug -eq "1") {
        Write-Host "[DEBUG] $message" -ForegroundColor Cyan
    }
    # [5.1.2 | ERROR DISPLAY]
    elseif ($logLevel -eq "ERROR") {
        Write-Host "[ERROR] $message" -ForegroundColor Red
    }
    # [5.1.3 | WARNING DISPLAY]
    elseif ($logLevel -eq "WARNING") {
        Write-Host "[WARN] $message" -ForegroundColor Yellow
    }
}

function Write-DebugMessage {
    # [5.2 | DEBUG LOGGING]
    param(
        [string]$Message
    )
    if ($generalConfig.Debug -eq "1") {
        Write-LogMessage -message $Message -logLevel "DEBUG"
    }
}

function Update-StatusLabel {
    # [5.3 | STATUS UPDATE]
    param(
        [string]$Status
    )
    if ($script:statusLabel) {
        $script:window.Dispatcher.Invoke([Action]{
            $script:statusLabel.Text = $Status
        })
    }
}
# [5.4 | LOG LEVELS]
# [ENGLISH - Available log levels: "INFO" (default), "WARNING", "ERROR", "DEBUG"]
#endregion

# [6.0 | LOGGING FUNCTIONALITY]
#region Logging Implementation
function Write-Log {
    # [6.1 | LOG ENTRY CREATION]
    param(
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry  = "$timestamp [$Level] - $Message"
    
    # Prüfe ob LogPath verfügbar ist
    if (-not $script:config.LogPath) {
        # Nur Konsolen-Output wenn kein LogPath verfügbar
        Write-Host "[$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                'ERROR' { 'Red' }
                'WARNING' { 'Yellow' }
                'DEBUG' { 'Cyan' }
                default { 'White' }
            }
        )
        return
    }
    
    # Mehrere Versuche mit verschiedenen Methoden
    $attempts = 0
    $maxAttempts = 3
    $success = $false
    
    while ($attempts -lt $maxAttempts -and -not $success) {
        try {
            $attempts++
            
            # Verwende Out-File mit UTF8 Encoding und -Append
            $logEntry | Out-File -FilePath $script:config.LogPath -Append -Encoding UTF8 -ErrorAction Stop
            $success = $true
        }
        catch {
            if ($attempts -eq 1) {
                # Zweiter Versuch: Verwende Add-Content mit UTF8
                try {
                    Add-Content -Path $script:config.LogPath -Value $logEntry -Encoding UTF8 -ErrorAction Stop
                    $success = $true
                }
                catch {
                    # Warte kurz vor dem nächsten Versuch
                    Start-Sleep -Milliseconds 100
                }
            }
            elseif ($attempts -eq 2) {
                # Dritter Versuch: Verwende StreamWriter
                try {
                    $streamWriter = [System.IO.StreamWriter]::new($script:config.LogPath, $true, [System.Text.Encoding]::UTF8)
                    $streamWriter.WriteLine($logEntry)
                    $streamWriter.Close()
                    $streamWriter.Dispose()
                    $success = $true
                }
                catch {
                    # Letzter Versuch fehlgeschlagen
                    Write-Host "ERROR writing to logfile after $maxAttempts attempts: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
    
    # Falls alle Versuche fehlschlagen, nur Konsolen-Output
    if (-not $success) {
        Write-Host "[$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                'ERROR' { 'Red' }
                'WARNING' { 'Yellow' }
                'DEBUG' { 'Cyan' }
                default { 'White' }
            }
        )
    }
}

# [6.2 | INITIAL LOG ENTRIES]
Write-LogMessage "Script gestartet - Version $($generalConfig.ScriptVersion)" -logLevel "INFO"
Write-DebugMessage "Debug-Modus aktiv - Detaillierte Ausgaben werden angezeigt"
Write-DebugMessage "Script-Verzeichnis: $scriptDir"
Write-DebugMessage "INI-Datei: $iniPath"
Write-DebugMessage "Log-Datei: $($script:config.LogPath)"
Write-DebugMessage "Vorlagen-Verzeichnis: $templatesDir"
#endregion

# [7.0 | TEMPLATE MANAGEMENT]
#region Template Management
function Save-Template {
    param(
        [string]$TemplateName
    )
    
    try {
        $template = @{
            GroupName = $textBoxPrefix.Text
            Separator = $textBoxSeparator.Text
            StartNumber = $textBoxStart.Text
            EndNumber = $textBoxEnd.Text
            Description = $textBoxDescription.Text
            GroupType = if ($radioSecurity.IsChecked) { "Security" } else { "Distribution" }
            GroupScope = if ($radioGlobal.IsChecked) { "Global" } elseif ($radioUniversal.IsChecked) { "Universal" } else { "DomainLocal" }
            SpecialMode = $chkSpecial.IsChecked
            AutoNaming = $chkAutoNaming.IsChecked
            CreateOUIfNotExists = $chkCreateOUIfNotExists.IsChecked
            ValidateNames = $chkValidateNames.IsChecked
            CheckDuplicates = $chkCheckDuplicates.IsChecked
            EmailNotification = $chkEmailNotification.IsChecked
            NotificationEmail = $textBoxNotificationEmail.Text
            SelectedOU = $comboBoxOU.SelectedValue
        }
        
        $templatePath = Join-Path $templatesDir "$TemplateName.json"
        $template | ConvertTo-Json | Set-Content -Path $templatePath -Encoding UTF8
        
        Write-LogMessage "Vorlage '$TemplateName' erfolgreich gespeichert" -logLevel "INFO"
        [System.Windows.MessageBox]::Show("Vorlage '$TemplateName' wurde erfolgreich gespeichert.", "Vorlage gespeichert")
        
        # Aktualisiere Vorlagen-Liste
        Load-AvailableTemplates
    }
    catch {
        Write-LogMessage "Fehler beim Speichern der Vorlage '$TemplateName': $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Speichern der Vorlage: $($_.Exception.Message)", "Fehler")
    }
}

function Load-Template {
    param(
        [string]$TemplateName
    )
    
    try {
        $templatePath = Join-Path $templatesDir "$TemplateName.json"
        if (-not (Test-Path $templatePath)) {
            [System.Windows.MessageBox]::Show("Vorlage '$TemplateName' nicht gefunden.", "Fehler")
            return
        }
        
        $template = Get-Content -Path $templatePath -Encoding UTF8 | ConvertFrom-Json
        
        # Lade Werte in die GUI
        $textBoxPrefix.Text = $template.GroupName
        $textBoxSeparator.Text = $template.Separator
        $textBoxStart.Text = $template.StartNumber
        $textBoxEnd.Text = $template.EndNumber
        $textBoxDescription.Text = $template.Description
        $textBoxNotificationEmail.Text = $template.NotificationEmail
        
        # Setze RadioButtons
        if ($template.GroupType -eq "Security") {
            $radioSecurity.IsChecked = $true
        } else {
            $radioDistribution.IsChecked = $true
        }
        
        switch ($template.GroupScope) {
            "Global" { $radioGlobal.IsChecked = $true }
            "Universal" { $radioUniversal.IsChecked = $true }
            "DomainLocal" { $radioDomainLocal.IsChecked = $true }
        }
        
        # Setze CheckBoxes
        $chkSpecial.IsChecked = $template.SpecialMode
        $chkAutoNaming.IsChecked = $template.AutoNaming
        $chkCreateOUIfNotExists.IsChecked = $template.CreateOUIfNotExists
        $chkValidateNames.IsChecked = $template.ValidateNames
        $chkCheckDuplicates.IsChecked = $template.CheckDuplicates
        $chkEmailNotification.IsChecked = $template.EmailNotification
        
        # Setze OU-Auswahl
        if ($template.SelectedOU) {
            $comboBoxOU.SelectedValue = $template.SelectedOU
        }
        
        Write-LogMessage "Vorlage '$TemplateName' erfolgreich geladen" -logLevel "INFO"
        Update-StatusLabel "Vorlage '$TemplateName' geladen"
    }
    catch {
        Write-LogMessage "Fehler beim Laden der Vorlage '$TemplateName': $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Laden der Vorlage: $($_.Exception.Message)", "Fehler")
    }
}

function Load-AvailableTemplates {
    $script:templates = @{}
    $templateFiles = Get-ChildItem -Path $templatesDir -Filter "*.json" -ErrorAction SilentlyContinue
    
    foreach ($file in $templateFiles) {
        $templateName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $script:templates[$templateName] = $file.FullName
    }
    
            Write-DebugMessage "Available templates loaded: $($script:templates.Keys -join ', ')"
}

function Reset-FormFields {
    # [7.1 | FORM RESET]
    # [ENGLISH - Resets all form fields to default values]
    # [GERMAN - Setzt alle Formularfelder auf Standardwerte zurück]
    $textBoxPrefix.Text = ""
    $textBoxSeparator.Text = "-"
    $textBoxStart.Text = ""
    $textBoxEnd.Text = ""
    $textBoxDescription.Text = $adgroupsConfig.GroupDescription
    $textBoxNotificationEmail.Text = ""
    $textBoxUserSearch.Text = ""
    
    $radioSecurity.IsChecked = $true
    $radioGlobal.IsChecked = $true
    
    $chkSpecial.IsChecked = $false
    $chkAutoNaming.IsChecked = $false
    $chkCreateOUIfNotExists.IsChecked = $false
    $chkValidateNames.IsChecked = $true
    $chkCheckDuplicates.IsChecked = $true
    $chkDryRun.IsChecked = $false
    $chkEmailNotification.IsChecked = $false
    
    $comboBoxOU.SelectedIndex = -1
    $listBoxUsers.SelectedItems.Clear()
    
    Update-StatusLabel "Felder zurückgesetzt"
    Write-LogMessage "Formularfelder wurden zurückgesetzt" -logLevel "INFO"
}
#endregion

# [8.0 | CSV IMPORT/EXPORT FUNCTIONS]
#region CSV Functions
function Export-CSVTemplate {
    # [8.1 | CSV TEMPLATE EXPORT]
    # [ENGLISH - Exports a CSV template for bulk group creation]
    # [GERMAN - Exportiert eine CSV-Vorlage für die Massen-Gruppenerstellung]
    try {
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.Filter = "CSV-Dateien (*.csv)|*.csv"
        $saveDialog.Title = "CSV-Vorlage speichern"
        $saveDialog.FileName = "ADGroups_Template.csv"
        
        if ($saveDialog.ShowDialog() -eq $true) {
            $csvTemplate = @"
GroupName,Description,GroupType,GroupScope,OU,Members
"Beispiel-Gruppe-1","Beispiel Beschreibung","Security","Global","OU=Groups,DC=domain,DC=com","user1;user2"
"Beispiel-Gruppe-2","Weitere Beschreibung","Distribution","Universal","OU=Groups,DC=domain,DC=com","user3;user4"
"@
            
            Set-Content -Path $saveDialog.FileName -Value $csvTemplate -Encoding UTF8
            Write-LogMessage "CSV-Vorlage exportiert nach: $($saveDialog.FileName)" -logLevel "INFO"
            [System.Windows.MessageBox]::Show("CSV-Vorlage wurde erfolgreich exportiert.", "Export erfolgreich")
        }
    }
    catch {
        Write-LogMessage "Fehler beim Exportieren der CSV-Vorlage: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Exportieren der CSV-Vorlage: $($_.Exception.Message)", "Fehler")
    }
}

function Import-CSVGroups {
    # [8.2 | CSV IMPORT]
    # [ENGLISH - Imports group configurations from CSV file]
    # [GERMAN - Importiert Gruppenkonfigurationen aus CSV-Datei]
    try {
        $openDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openDialog.Filter = "CSV-Dateien (*.csv)|*.csv"
        $openDialog.Title = "CSV-Datei für Import auswählen"
        
        if ($openDialog.ShowDialog() -eq $true) {
            $csvData = Import-Csv -Path $openDialog.FileName -Encoding UTF8
            
            $groupsToCreate = @()
            foreach ($row in $csvData) {
                $groupInfo = @{
                    Name = $row.GroupName
                    Description = $row.Description
                    GroupType = $row.GroupType
                    GroupScope = $row.GroupScope
                    OU = $row.OU
                    Members = if ($row.Members) { $row.Members.Split(';') } else { @() }
                }
                $groupsToCreate += $groupInfo
            }
            
            # Zeige Vorschau
            $previewText = "Folgende Gruppen werden aus der CSV-Datei erstellt:`n`n"
            foreach ($group in $groupsToCreate) {
                $previewText += "• $($group.Name) ($($group.GroupType), $($group.GroupScope))`n"
            }
            
            $result = [System.Windows.MessageBox]::Show($previewText + "`nMöchten Sie fortfahren?", "CSV-Import Vorschau", [System.Windows.MessageBoxButton]::YesNo)
            
            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                Create-GroupsFromCSV -Groups $groupsToCreate
            }
        }
    }
    catch {
        Write-LogMessage "Fehler beim CSV-Import: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim CSV-Import: $($_.Exception.Message)", "Fehler")
    }
}

function Create-GroupsFromCSV {
    param(
        [array]$Groups
    )
    
    $total = $Groups.Count
    $count = 0
    $errors = @()
    
    # Zeige Progress Bar
    $progressBarMain.Visibility = "Visible"
    $progressBarMain.Value = 0
    
    foreach ($group in $Groups) {
        try {
            # Validiere Gruppendaten
            if ([string]::IsNullOrWhiteSpace($group.Name)) {
                $errors += "Gruppenname darf nicht leer sein"
                continue
            }
            
            # Erstelle Gruppe
            $params = @{
                Name = $group.Name
                Description = $group.Description
                GroupCategory = $group.GroupType
                GroupScope = $group.GroupScope
                Path = $group.OU
            }
            
            if ($chkDryRun.IsChecked -eq $false) {
                $newGroup = New-ADGroup @params -PassThru
                
                # Füge Mitglieder hinzu
                if ($group.Members -and $group.Members.Count -gt 0) {
                    Add-ADGroupMember -Identity $newGroup -Members $group.Members -ErrorAction SilentlyContinue
                }
                
                [void]$script:createdGroups.Add($group.Name)
            }
            
            Write-LogMessage "CSV-Gruppe erstellt: $($group.Name)" -logLevel "INFO"
        }
        catch {
            $errorMsg = "Fehler bei Gruppe '$($group.Name)': $($_.Exception.Message)"
            $errors += $errorMsg
            Write-LogMessage $errorMsg -logLevel "ERROR"
        }
        
        $count++
        $progressBarMain.Value = ($count / $total) * 100
    }
    
    $progressBarMain.Visibility = "Collapsed"
    
    $resultMsg = "CSV-Import abgeschlossen.`n$count von $total Gruppen verarbeitet."
    if ($errors.Count -gt 0) {
        $resultMsg += "`n`nFehler:`n" + ($errors -join "`n")
    }
    
    [System.Windows.MessageBox]::Show($resultMsg, "CSV-Import Ergebnis")
    Write-LogMessage "CSV-Import abgeschlossen: $count/$total Gruppen erstellt, $($errors.Count) Fehler" -logLevel "INFO"
}
#endregion

# [9.0 | USER SEARCH AND MANAGEMENT]
#region User Management
function Search-Users {
    param(
        [string]$SearchTerm
    )
    
    Update-StatusLabel "Suche Benutzer..."
    
    try {
        $script:filteredUsers.Clear()
        
        if ([string]::IsNullOrWhiteSpace($SearchTerm)) {
            # Zeige alle Benutzer
            foreach ($user in $script:allUsers) {
                $script:filteredUsers.Add($user)
            }
        } else {
            # Filtere Benutzer basierend auf Suchbegriff
            foreach ($user in $script:allUsers) {
                if ($user.DisplayText -like "*$SearchTerm*" -or $user.SamAccountName -like "*$SearchTerm*") {
                    $script:filteredUsers.Add($user)
                }
            }
        }
        
        # Aktualisiere ListBox
        $window.Dispatcher.Invoke([Action]{
            $listBoxUsers.ItemsSource = $script:filteredUsers
        })
        
        Update-StatusLabel "Search completed: $($script:filteredUsers.Count) users found"
        Write-DebugMessage "User search for '$SearchTerm': $($script:filteredUsers.Count) results"
    }
    catch {
        Write-LogMessage "Fehler bei Benutzersuche: $($_.Exception.Message)" -logLevel "ERROR"
        Update-StatusLabel "Fehler bei Benutzersuche"
    }
}

function Select-AllUsers {
    try {
        $listBoxUsers.SelectAll()
        Update-StatusLabel "Alle Benutzer ausgewählt"
        Write-DebugMessage "All visible users have been selected"
    }
    catch {
        Write-LogMessage "Fehler beim Auswählen aller Benutzer: $($_.Exception.Message)" -logLevel "ERROR"
    }
}

function Deselect-AllUsers {
    try {
        $listBoxUsers.SelectedItems.Clear()
        Update-StatusLabel "Benutzerauswahl aufgehoben"
        Write-DebugMessage "User selection has been cleared"
    }
    catch {
        Write-LogMessage "Fehler beim Aufheben der Benutzerauswahl: $($_.Exception.Message)" -logLevel "ERROR"
    }
}

function Refresh-UserList {
    Update-StatusLabel "Aktualisiere Benutzerliste..."
    
    try {
        $script:allUsers.Clear()
        
                    $maxUsers = [int]$adConfig.MaxUsersToLoad
            $adUsers = Get-ADUser -Filter * -Properties DisplayName, SamAccountName -ErrorAction Stop | 
                Sort-Object DisplayName | 
                Select-Object -First $maxUsers
            
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
            $script:filteredUsers.Add($userObject)
        }
        
        # Aktualisiere gefilterte Liste
        Search-Users -SearchTerm $textBoxUserSearch.Text
        
        Update-StatusLabel "Benutzerliste aktualisiert: $($script:allUsers.Count) Benutzer geladen"
        Write-LogMessage "Benutzerliste aktualisiert: $($script:allUsers.Count) Benutzer geladen" -logLevel "INFO"
    }
    catch {
        Write-LogMessage "Fehler beim Aktualisieren der Benutzerliste: $($_.Exception.Message)" -logLevel "ERROR"
        Update-StatusLabel "Fehler beim Aktualisieren der Benutzerliste"
    }
}
#endregion

# [10.0 | ACTIVE DIRECTORY OPERATIONS]
#region AD Operations
function Get-ADData {
    # [10.1 | AD DATA RETRIEVAL]
    # [ENGLISH - Retrieve and process Active Directory data]
    # [GERMAN - Active Directory-Daten abrufen und verarbeiten]
    Write-LogMessage "AD-Daten werden abgerufen..." -logLevel "INFO"
    Update-StatusLabel "Lade AD-Daten..."
    
    try {
        # [10.1.1 | OU RETRIEVAL]
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
        
        # [10.1.2 | USER RETRIEVAL - ÜBERARBEITET]
        # [ENGLISH - Retrieve users from AD with better display]
        # [GERMAN - Ruft Benutzer aus AD ab mit besserer Anzeige]
        Write-DebugMessage "Rufe Benutzer aus AD ab..."

        # Verbesserte Benutzeranzeige mit ObservableCollection
        $script:allUsers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
        $script:filteredUsers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
        
        try {
            $maxUsers = [int]$adConfig.MaxUsersToLoad
            $adUsers = Get-ADUser -Filter * -Properties DisplayName, SamAccountName -ErrorAction Stop | 
                Sort-Object DisplayName | 
                Select-Object -First $maxUsers
                
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
                $script:filteredUsers.Add($userObject)
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
            $script:filteredUsers.Add($userObject)
        }

        # [10.1.3 | UI UPDATES - ANGEPASST FÜR BENUTZERANZEIGE]
        # Für WPF-Implementierung angepasst
        $window.Dispatcher.Invoke([Action]{
            # ComboBox mit OUs befüllen
            Write-DebugMessage "Befülle OU-ComboBox..."
            $comboBoxOU.ItemsSource = $script:allOUs
            
            # ListBox mit Benutzern befüllen - VERBESSERTE METHODE
            Write-DebugMessage "Befülle User-ListBox mit verbessertem Format..."
            $listBoxUsers.ItemsSource = $script:filteredUsers
            
            # Setze DisplayMemberPath für korrekte Anzeige
            $listBoxUsers.DisplayMemberPath = "DisplayText"
            $listBoxUsers.SelectedValuePath = "SamAccountName"
        })
        
        Update-StatusLabel "AD-Daten erfolgreich geladen"
        Write-LogMessage "AD-Daten erfolgreich geladen" -logLevel "INFO"
    }
    catch {
        # [10.1.4 | ERROR HANDLING]
        Write-LogMessage "Fehler beim Abrufen von AD-Daten: $($_.Exception.Message)" -logLevel "ERROR"
        Update-StatusLabel "Fehler beim Laden der AD-Daten"
        [System.Windows.MessageBox]::Show("AD-Verbindungsfehler: $($_.Exception.Message)")
        exit
    }
}

function Create-OUIfNotExists {
    param(
        [string]$OUPath
    )
    
    try {
        # Prüfe ob OU existiert
        $existingOU = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OUPath'" -ErrorAction SilentlyContinue
        
        if (-not $existingOU) {
            # Extrahiere OU-Name und Parent-Path
            $ouName = ($OUPath -split ',')[0] -replace 'OU=', ''
            $parentPath = ($OUPath -split ',', 2)[1]
            
            # Erstelle OU
            New-ADOrganizationalUnit -Name $ouName -Path $parentPath
            Write-LogMessage "OU erstellt: $OUPath" -logLevel "INFO"
            return $true
        }
        
        return $true
    }
    catch {
        Write-LogMessage "Fehler beim Erstellen der OU '$OUPath': $($_.Exception.Message)" -logLevel "ERROR"
        return $false
    }
}
#endregion

# [11.0 | INPUT VALIDATION]
#region Input Validation
function Test-Input {
    # [11.1 | USER INPUT VALIDATION]
    # [ENGLISH - Validate form inputs before processing]
    # [GERMAN - Validiert Formulareingaben vor der Verarbeitung]
    Write-DebugMessage "Validiere Benutzereingaben..."
    $errors = @()
    
    # [11.1.1 | STANDARD MODE VALIDATION]
    if (-not ($chkSpecial.IsChecked -eq $true)) {
        Write-DebugMessage "Standard-Modus: Prüfe Start/End-Felder"
        if (($textBoxStart.Text.Trim() -eq "") -and ($textBoxEnd.Text.Trim() -eq "")) {
            Write-DebugMessage "Start/End fields are empty - single group creation"
            # [11.1.1.1 | SINGLE GROUP CREATION]
        }
        elseif (($textBoxStart.Text.Trim() -eq "") -or ($textBoxEnd.Text.Trim() -eq "")) {
            Write-DebugMessage "Only one field is filled - validation error"
            $errors += "Please fill both fields (start and end number) or leave both empty."
        }
        else {
            # [11.1.1.2 | NUMERIC VALUES CHECK]
            Write-DebugMessage "Prüfe nummerische Werte für Start/End"
            $startNum = 0
            $endNum = 0
            
            if (-not [int]::TryParse($textBoxStart.Text.Trim(), [ref]$startNum)) { 
                Write-DebugMessage "Start number is not a valid number: $($textBoxStart.Text)"
                $errors += "Invalid start number format" 
            }
            if (-not [int]::TryParse($textBoxEnd.Text.Trim(), [ref]$endNum)) { 
                Write-DebugMessage "End number is not a valid number: $($textBoxEnd.Text)"
                $errors += "Invalid end number format" 
            }
            
            # [11.1.1.3 | RANGE CHECK]
            # [ENGLISH - Check if start number is less than end number]
            # [GERMAN - Prüft, ob Startnummer kleiner als Endnummer ist]
            if (($errors.Count -eq 0) -and ($startNum -gt $endNum)) { 
                Write-DebugMessage "Start number ($startNum) greater than end number ($endNum)"
                $errors += "Start number must be less than end number" 
            }
            
            # [11.1.1.4 | RANGE SIZE CHECK]
            # [ENGLISH - Check if range is reasonable (not too large)]
            # [GERMAN - Prüft, ob der Bereich angemessen ist (nicht zu groß)]
            if (($errors.Count -eq 0) -and (($endNum - $startNum) -gt [int]$validationConfig.MaxGroupsPerBatch)) {
                $errors += "Number range is too large (max. $($validationConfig.MaxGroupsPerBatch) groups per operation)"
            }
        }
    } else {
        # [11.1.2 | SPECIAL MODE VALIDATION]
        # [ENGLISH - Validate for JIRA/Confluence groups special mode]
        # [GERMAN - Validiert für Spezial-Modus JIRA/Confluence-Gruppen]
        Write-DebugMessage "Spezial-Modus aktiviert: Validiere für JIRA/Confluence-Gruppen"
    }
    
    # [11.1.3 | OU SELECTION CHECK]
    # [ENGLISH - Check if OU is selected]
    # [GERMAN - Prüft, ob eine OU ausgewählt wurde]
    if ($comboBoxOU.SelectedIndex -eq -1) { 
        Write-DebugMessage "No OU selected"
        $errors += "No OU selected" 
    } else {
        Write-DebugMessage "Selected OU: $($comboBoxOU.SelectedValue)"
        
        # [11.1.3.1 | OU EXISTENCE CHECK]
        # [ENGLISH - Check if selected OU exists (if auto-create is disabled)]
        # [GERMAN - Prüft, ob ausgewählte OU existiert (falls Auto-Erstellung deaktiviert ist)]
        if ($chkCreateOUIfNotExists.IsChecked -eq $false) {
            try {
                $ouExists = Get-ADOrganizationalUnit -Identity $comboBoxOU.SelectedValue -ErrorAction SilentlyContinue
                if (-not $ouExists) {
                    $errors += "Die ausgewählte OU existiert nicht. Aktivieren Sie 'OU automatisch erstellen' oder wählen Sie eine andere OU."
                }
            }
            catch {
                $errors += "Fehler beim Überprüfen der OU-Existenz: $($_.Exception.Message)"
            }
        }
    }
    
    # [11.1.4 | GROUP NAME VALIDATION]
    # [ENGLISH - Enhanced group name validation]
    # [GERMAN - Erweiterte Gruppennamen-Validierung]
    if ([string]::IsNullOrWhiteSpace($textBoxPrefix.Text)) {
        $errors += "Group name cannot be empty."
    }
    elseif ($textBoxPrefix.Text -match '[\\/:*?"<>|]') {
        $errors += 'Group name contains invalid characters: \ / : * ? " < > |'
    }
    elseif ($textBoxPrefix.Text.Length -gt [int]$validationConfig.MaxGroupNameLength) {
        $errors += "Group name is too long (max. $($validationConfig.MaxGroupNameLength) characters for base names)"
    }
    
    # [11.1.5 | DUPLICATE CHECK]
    # [ENGLISH - Check for duplicate groups if enabled]
    # [GERMAN - Prüft auf doppelte Gruppen falls aktiviert]
    if ($chkCheckDuplicates.IsChecked -eq $true) {
        $groupsToValidate = Get-GroupsToCreate
        foreach ($groupName in $groupsToValidate) {
            try {
                $existingGroup = Get-ADGroup -Identity $groupName -ErrorAction SilentlyContinue
                if ($existingGroup) {
                    $errors += "Gruppe '$groupName' existiert bereits"
                    break  # Stoppe nach dem ersten Duplikat
                }
            }
            catch {
                # Gruppe existiert nicht - das ist gut
            }
        }
    }
    
    # [11.1.6 | EMAIL VALIDATION]
    # [ENGLISH - Validate email address if notification is enabled]
    # [GERMAN - Validiert E-Mail-Adresse falls Benachrichtigung aktiviert]
    if ($chkEmailNotification.IsChecked -eq $true) {
        if ([string]::IsNullOrWhiteSpace($textBoxNotificationEmail.Text)) {
            $errors += "E-Mail-Adresse für Benachrichtigung ist erforderlich"
        }
        elseif ($textBoxNotificationEmail.Text -notmatch '^[^@]+@[^@]+\.[^@]+$') {
            $errors += "Ungültige E-Mail-Adresse für Benachrichtigung"
        }
    }
    
    # [11.1.7 | VALIDATION RESULT]
    # [ENGLISH - Log validation results]
    # [GERMAN - Protokolliert Validierungsergebnisse]
    if ($errors.Count -gt 0) {
        Write-DebugMessage "Validierung fehlgeschlagen mit $($errors.Count) Fehlern: $($errors -join ', ')"
        Update-StatusLabel "Validierungsfehler gefunden"
    } else {
        Write-DebugMessage "Validierung erfolgreich"
        Update-StatusLabel "Validierung erfolgreich"
    }
    
    return $errors
}

function Get-GroupsToCreate {
    # [11.2 | GET GROUPS TO CREATE]
    # [ENGLISH - Returns list of group names that would be created]
    # [GERMAN - Gibt Liste der Gruppennamen zurück, die erstellt würden]
    $groupsToCreate = @()
    
    if ($chkSpecial.IsChecked -eq $true) {
        $suffixes = $adgroupsConfig.AdditionalSuffixes.Split(",")
        foreach ($suffix in $suffixes) {
            $groupsToCreate += "$($textBoxPrefix.Text.Trim())$($textBoxSeparator.Text.Trim())$suffix"
        }
    }
    elseif (($textBoxStart.Text.Trim() -eq "") -and ($textBoxEnd.Text.Trim() -eq "")) {
        $groupsToCreate += "$($textBoxPrefix.Text.Trim())"
    }
    else {
        $start = [int]$textBoxStart.Text.Trim()
        $end = [int]$textBoxEnd.Text.Trim()
        for ($i = $start; $i -le $end; $i++) {
            $groupsToCreate += "$($textBoxPrefix.Text.Trim())$($textBoxSeparator.Text.Trim())$i"
        }
    }
    
    return $groupsToCreate
}
#endregion

# [12.0 | NOTIFICATION FUNCTIONS]
#region Notification Functions
function Send-EmailNotification {
    param(
        [string]$EmailAddress,
        [string]$Subject,
        [string]$Body
    )
    
    try {
        # Hier würde normalerweise die E-Mail-Funktionalität implementiert
        # Da dies eine komplexe Konfiguration erfordert, zeigen wir erstmal nur eine Simulation
        
        Write-LogMessage "E-Mail-Benachrichtigung würde gesendet an: $EmailAddress" -logLevel "INFO"
        Write-LogMessage "Betreff: $Subject" -logLevel "INFO"
        Write-LogMessage "Inhalt: $Body" -logLevel "INFO"
        
        # Für Testzwecke
        [System.Windows.MessageBox]::Show("E-Mail-Benachrichtigung (Simulation):`n`nAn: $EmailAddress`nBetreff: $Subject`n`n$Body", "E-Mail gesendet")
        
        return $true
    }
    catch {
        Write-LogMessage "Fehler beim Senden der E-Mail-Benachrichtigung: $($_.Exception.Message)" -logLevel "ERROR"
        return $false
    }
}

function Test-EmailConfiguration {
    if ([string]::IsNullOrWhiteSpace($textBoxNotificationEmail.Text)) {
        [System.Windows.MessageBox]::Show("Bitte geben Sie eine E-Mail-Adresse ein.", "Fehler")
        return
    }
    
    $testSubject = "easyADgroup - Test-Benachrichtigung"
    $testBody = "Dies ist eine Test-E-Mail von easyADgroup.`n`nZeitpunkt: $(Get-Date)`nBenutzer: $env:USERNAME`nComputer: $env:COMPUTERNAME"
    
    $success = Send-EmailNotification -EmailAddress $textBoxNotificationEmail.Text -Subject $testSubject -Body $testBody
    
    if ($success) {
        Update-StatusLabel "Test-E-Mail gesendet"
    } else {
        Update-StatusLabel "Fehler beim Senden der Test-E-Mail"
    }
}

function Generate-Report {
    # [12.1 | GENERATE REPORT]
    # [ENGLISH - Generates a detailed report of created groups]
    # [GERMAN - Erstellt einen detaillierten Bericht der erstellten Gruppen]
    try {
        if ($script:createdGroups.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Keine Gruppen zum Berichten vorhanden. Erstellen Sie zuerst Gruppen.", "Kein Bericht verfügbar")
            return
        }
        
        $reportContent = @"
easyADgroup - Gruppenerstellungs-Bericht
========================================

Datum: $(Get-Date -Format "dd.MM.yyyy HH:mm:ss")
Benutzer: $env:USERNAME
Computer: $env:COMPUTERNAME

Erstellte Gruppen ($($script:createdGroups.Count)):
"@
        
        foreach ($groupName in $script:createdGroups) {
            $reportContent += "`n• $groupName"
        }
        
        $reportContent += @"


Konfiguration:
- OU: $($comboBoxOU.Text)
- Gruppentyp: $(if ($radioSecurity.IsChecked) { "Security" } else { "Distribution" })
- Geltungsbereich: $(if ($radioGlobal.IsChecked) { "Global" } elseif ($radioUniversal.IsChecked) { "Universal" } else { "DomainLocal" })
- Spezial-Modus: $(if ($chkSpecial.IsChecked) { "Ja" } else { "Nein" })

Log-Datei: $($script:config.LogPath)
"@
        
        # Speichere Bericht
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.Filter = "Text-Dateien (*.txt)|*.txt"
        $saveDialog.Title = "Bericht speichern"
        $saveDialog.FileName = "easyADgroup_Bericht_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
        
        if ($saveDialog.ShowDialog() -eq $true) {
            Set-Content -Path $saveDialog.FileName -Value $reportContent -Encoding UTF8
            Write-LogMessage "Bericht gespeichert: $($saveDialog.FileName)" -logLevel "INFO"
            [System.Windows.MessageBox]::Show("Bericht wurde erfolgreich gespeichert.", "Bericht erstellt")
            
            # Öffne Bericht
            Start-Process notepad.exe -ArgumentList $saveDialog.FileName
        }
    }
    catch {
        Write-LogMessage "Fehler beim Erstellen des Berichts: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Erstellen des Berichts: $($_.Exception.Message)", "Fehler")
    }
}
#endregion

# [13.0 | ACTION BUTTONS]
#region Action Buttons
function Add-ButtonEventHandlers {
    # [13.1 | TEMPLATE BUTTONS]
    $buttonLoadTemplate.Add_Click({
        Write-DebugMessage "Vorlagen-Laden-Button geklickt"
        
        if ($script:templates.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Keine Vorlagen gefunden. Erstellen Sie zuerst eine Vorlage.", "Keine Vorlagen")
            return
        }
        
        # Erstelle Auswahldialog
        $templateNames = $script:templates.Keys | Sort-Object
        $selectedTemplate = [Microsoft.VisualBasic.Interaction]::InputBox("Wählen Sie eine Vorlage:`n`n" + ($templateNames -join "`n"), "Vorlage laden", $templateNames[0])
        
        if (-not [string]::IsNullOrWhiteSpace($selectedTemplate) -and $script:templates.ContainsKey($selectedTemplate)) {
            Load-Template -TemplateName $selectedTemplate
        }
    })

    $buttonSaveTemplate.Add_Click({
        Write-DebugMessage "Vorlagen-Speichern-Button geklickt"
        
        $templateName = [Microsoft.VisualBasic.Interaction]::InputBox("Geben Sie einen Namen für die Vorlage ein:", "Vorlage speichern", "Meine_Vorlage")
        
        if (-not [string]::IsNullOrWhiteSpace($templateName)) {
            # Entferne ungültige Zeichen für Dateinamen
            $templateName = $templateName -replace '[\\/:*?"<>|]', '_'
            Save-Template -TemplateName $templateName
        }
    })

    $buttonReset.Add_Click({
        Write-DebugMessage "Reset-Button geklickt"
        Reset-FormFields
    })

    # [13.2 | USER MANAGEMENT BUTTONS]
    $buttonSearchUsers.Add_Click({
        Write-DebugMessage "Benutzersuche-Button geklickt"
        Search-Users -SearchTerm $textBoxUserSearch.Text
    })

    $buttonSelectAllUsers.Add_Click({
        Write-DebugMessage "Alle-Benutzer-auswählen-Button geklickt"
        Select-AllUsers
    })

    $buttonDeselectAllUsers.Add_Click({
        Write-DebugMessage "Benutzerauswahl-aufheben-Button geklickt"
        Deselect-AllUsers
    })

    $buttonRefreshUsers.Add_Click({
        Write-DebugMessage "Benutzerliste-aktualisieren-Button geklickt"
        Refresh-UserList
    })

    # [13.3 | CSV IMPORT/EXPORT BUTTONS]
    $buttonDownloadTemplate.Add_Click({
        Write-DebugMessage "CSV-Vorlage-herunterladen-Button geklickt"
        Export-CSVTemplate
    })

    $buttonImportCSV.Add_Click({
        Write-DebugMessage "CSV-Import-Button geklickt"
        Import-CSVGroups
    })

    # [13.4 | EMAIL NOTIFICATION BUTTONS]
    $buttonTestEmail.Add_Click({
        Write-DebugMessage "Test-E-Mail-Button geklickt"
        Test-EmailConfiguration
    })

    # [13.5 | SEARCH BOX EVENT]
    $textBoxUserSearch.Add_TextChanged({
        # Verzögerte Suche implementieren (konfigurierbare Verzögerung)
        if ($script:searchTimer) {
            $script:searchTimer.Stop()
        }
        
        $script:searchTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:searchTimer.Interval = [TimeSpan]::FromMilliseconds([int]$advancedConfig.SearchDelayMs)
        $script:searchTimer.Add_Tick({
            $script:searchTimer.Stop()
            Search-Users -SearchTerm $textBoxUserSearch.Text
        })
        $script:searchTimer.Start()
    })

    # [13.6 | PREVIEW BUTTON]
    $buttonPreview.Add_Click({
        Write-DebugMessage "Vorschau-Button geklickt"
        Update-StatusLabel "Erstelle Vorschau..."
        
        $errors = Test-Input
        if ($errors.Count -gt 0) {
            Write-LogMessage "Validierungsfehler bei Vorschau: $($errors -join ', ')" -logLevel "WARNING"
            [System.Windows.MessageBox]::Show(($errors -join "`n"), "Validierungsfehler")
            Update-StatusLabel "Validierungsfehler"
            return
        }
        
        $groupsToCreate = Get-GroupsToCreate
        $previewText = "Folgende Gruppen würden erstellt werden:`n`n"
        
        foreach ($groupName in $groupsToCreate) {
            $previewText += "• $groupName`n"
        }
        
        $previewText += "`nAnzahl: $($groupsToCreate.Count) Gruppen"
        $previewText += "`nOU: $($comboBoxOU.Text)"
        $previewText += "`nTyp: $(if ($radioSecurity.IsChecked) { 'Security' } else { 'Distribution' })"
        $previewText += "`nBereich: $(if ($radioGlobal.IsChecked) { 'Global' } elseif ($radioUniversal.IsChecked) { 'Universal' } else { 'DomainLocal' })"
        
        if ($chkDryRun.IsChecked) {
            $previewText += "`n`nTEST RUN ACTIVATED - No changes will be made"
        }
        
        Write-LogMessage "Vorschau generiert für $($groupsToCreate.Count) Gruppen" -logLevel "INFO"
        Update-StatusLabel "Vorschau erstellt"
        [System.Windows.MessageBox]::Show($previewText, "Group Creation Preview")
    })

    # [13.7 | CREATE BUTTON]
    $buttonCreate.Add_Click({
        Write-LogMessage "Erstellungs-Button geklickt" -logLevel "INFO"
        Update-StatusLabel "Validiere Eingaben..."
        
        $errors = Test-Input
        if ($errors.Count -gt 0) {
            Write-LogMessage "Validierungsfehler bei Gruppenerstellung: $($errors -join ', ')" -logLevel "WARNING"
            [System.Windows.MessageBox]::Show(($errors -join "`n"), "Validierungsfehler")
            Update-StatusLabel "Validierungsfehler"
            return
        }
        
        # Bestätigungsdialog
        $groupsToCreate = Get-GroupsToCreate
        $confirmText = "Möchten Sie $($groupsToCreate.Count) Gruppen erstellen?"
        if ($chkDryRun.IsChecked) {
            $confirmText += "`n`n⚠️ TESTLAUF AKTIVIERT - Keine Aenderungen werden vorgenommen"
        }
        
        $result = [System.Windows.MessageBox]::Show($confirmText, "Gruppenerstellung bestätigen", [System.Windows.MessageBoxButton]::YesNo)
        if ($result -ne [System.Windows.MessageBoxResult]::Yes) {
            Update-StatusLabel "Gruppenerstellung abgebrochen"
            return
        }
        
        # Zeige Progress Bar
        $progressBarMain.Visibility = "Visible"
        $progressBarMain.Value = 0
        Update-StatusLabel "Erstelle Gruppen..."
        
        # Extrahiere ausgewählte Benutzer
        $script:selectedUsers = @()
        if ($listBoxUsers.SelectedItems.Count -gt 0) {
            Write-DebugMessage "Ausgewaehlte Benutzer werden extrahiert... ($($listBoxUsers.SelectedItems.Count) Elemente)"
            
            foreach ($selectedItem in $listBoxUsers.SelectedItems) {
                try {
                    if ($selectedItem -and $selectedItem.SamAccountName -and -not [string]::IsNullOrWhiteSpace($selectedItem.SamAccountName)) {
                        $script:selectedUsers += $selectedItem.SamAccountName
                        Write-DebugMessage "Benutzer ausgewaehlt: $($selectedItem.SamAccountName) ($($selectedItem.DisplayText))"
                    }
                }
                catch {
                    Write-LogMessage "Fehler beim Extrahieren des SamAccountName: $($_.Exception.Message)" -logLevel "WARNING"
                }
            }
            
            Write-LogMessage "Es wurden $($script:selectedUsers.Count) Benutzer fuer die Gruppenmitgliedschaft ausgewaehlt" -logLevel "INFO"
        }
        
        try {
            $total = $groupsToCreate.Count
            $count = 0
            $errors = @()
            
            foreach ($groupName in $groupsToCreate) {
                try {
                    # OU automatisch erstellen falls aktiviert
                    if ($chkCreateOUIfNotExists.IsChecked -eq $true) {
                        $ouPath = $comboBoxOU.SelectedValue
                        if (-not (Create-OUIfNotExists -OUPath $ouPath)) {
                            $errors += "Fehler beim Erstellen der OU: $ouPath"
                            continue
                        }
                    }
                    
                    # SAMAccountName-Überprüfung
                    $samAccountName = $groupName
                    $maxSamLength = [int]$validationConfig.MaxSamAccountNameLength
                    if ($samAccountName.Length -gt $maxSamLength) {
                        $samAccountName = $samAccountName.Substring(0, $maxSamLength)
                        Write-LogMessage "SAMAccountName for $groupName was truncated to $samAccountName" -logLevel "WARNING"
                    }
                    
                    # Gruppenerstellungs-Parameter
                    $params = @{
                        Name = $groupName
                        SamAccountName = $samAccountName
                        Path = $comboBoxOU.SelectedValue
                        GroupScope = if ($radioGlobal.IsChecked) { "Global" } elseif ($radioUniversal.IsChecked) { "Universal" } else { "DomainLocal" }
                        GroupCategory = if ($radioSecurity.IsChecked) { "Security" } else { "Distribution" }
                        Description = if ($textBoxDescription.Text) { $textBoxDescription.Text } else { $adgroupsConfig.GroupDescription }
                        DisplayName = $groupName
                    }
                    
                    Write-DebugMessage "Erstelle Gruppe: $groupName mit Parametern: $($params | ConvertTo-Json -Compress)"
                    
                    if ($chkDryRun.IsChecked -eq $false) {
                        # Prüfe auf existierende Gruppe
                        $existingGroup = $null
                        try {
                            $existingGroup = Get-ADGroup -Identity $samAccountName -ErrorAction SilentlyContinue
                        }
                        catch { }
                        
                        if ($existingGroup) {
                            Write-LogMessage "Gruppe mit SAMAccountName $samAccountName existiert bereits - wird uebersprungen" -logLevel "WARNING"
                            continue
                        }
                        
                        # Erstelle Gruppe
                        $group = New-ADGroup @params -PassThru -ErrorAction Stop
                        Start-Sleep -Milliseconds 500  # Kurze Verzögerung für AD-Replikation
                        
                        [void]$script:createdGroups.Add($group.Name)
                        
                        # Füge Benutzer hinzu
                        if ($script:selectedUsers.Count -gt 0) {
                            try {
                                Add-ADGroupMember -Identity $samAccountName -Members $script:selectedUsers -ErrorAction Stop
                                Write-LogMessage "Mitglieder zu $groupName hinzugefuegt: $($script:selectedUsers -join ', ')" -logLevel "INFO"
                            }
                            catch {
                                Write-LogMessage "Fehler beim Hinzufuegen von Mitgliedern zu ${groupName}: $($_.Exception.Message)" -logLevel "ERROR"
                            }
                        }
                        
                        # INI-basierte Benutzer hinzufügen
                        if ($adgroupsConfig.GroupMembersAddActive -eq "1") {
                            $fixedMembers = $adgroupsConfig.GroupMembersAdd.Split(",") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                            if ($fixedMembers -and $fixedMembers.Count -gt 0) {
                                try {
                                    Add-ADGroupMember -Identity $samAccountName -Members $fixedMembers -ErrorAction Stop
                                    Write-LogMessage "Feste Mitglieder zu $groupName hinzugefuegt: $($fixedMembers -join ', ')" -logLevel "INFO"
                                }
                                catch {
                                    Write-LogMessage "Fehler beim Hinzufuegen fester Mitglieder zu ${groupName}: $($_.Exception.Message)" -logLevel "WARNING"
                                }
                            }
                        }
                        
                        Write-LogMessage "Gruppe $groupName erfolgreich erstellt" -logLevel "INFO"
                    } else {
                        Write-LogMessage "TESTLAUF: Gruppe $groupName wuerde erstellt werden" -logLevel "INFO"
                        [void]$script:createdGroups.Add($groupName)
                    }
                }
                catch {
                    $errorMsg = "Fehler bei Gruppe '$groupName': $($_.Exception.Message)"
                    $errors += $errorMsg
                    Write-LogMessage $errorMsg -logLevel "ERROR"
                }
                
                $count++
                $progressBarMain.Value = ($count / $total) * 100
                Update-StatusLabel "Fortschritt: $count/$total Gruppen"
            }
            
            $progressBarMain.Visibility = "Collapsed"
            
            # Ergebnis anzeigen
            $resultMsg = if ($chkDryRun.IsChecked) { "TESTLAUF abgeschlossen" } else { "Gruppenerstellung abgeschlossen" }
            $resultMsg += "`n$count von $total Gruppen verarbeitet."
            
            if ($errors.Count -gt 0) {
                $resultMsg += "`n`nFehler ($($errors.Count)):`n" + ($errors -join "`n")
            }
            
            [System.Windows.MessageBox]::Show($resultMsg, "Erstellung abgeschlossen")
            Update-StatusLabel "Erstellung abgeschlossen: $count/$total Gruppen"
            
            # E-Mail-Benachrichtigung senden
            if ($chkEmailNotification.IsChecked -eq $true -and -not [string]::IsNullOrWhiteSpace($textBoxNotificationEmail.Text)) {
                $emailSubject = "easyADgroup - Gruppenerstellung abgeschlossen"
                $emailBody = $resultMsg
                Send-EmailNotification -EmailAddress $textBoxNotificationEmail.Text -Subject $emailSubject -Body $emailBody
            }
            
            Write-LogMessage "Gruppenerstellung abgeschlossen. $count/$total Gruppen erstellt, $($errors.Count) Fehler" -logLevel "INFO"
        }
        catch {
            $progressBarMain.Visibility = "Collapsed"
            Write-LogMessage "Kritischer Fehler bei Gruppenerstellung: $($_.Exception.Message)" -logLevel "ERROR"
            Update-StatusLabel "Kritischer Fehler"
            [System.Windows.MessageBox]::Show("Kritischer Fehler: $($_.Exception.Message)", "Fehler")
        }
    })

    # [13.8 | REPORT BUTTON]
    $buttonReport.Add_Click({
        Write-DebugMessage "Bericht-Button geklickt"
        Generate-Report
    })

    # [13.9 | CLOSE BUTTON]
    $buttonClose.Add_Click({
        Write-LogMessage "Anwendung wird beendet" -logLevel "INFO"
        $window.Close()
    })
}
#endregion

# [14.0 | MAIN EXECUTION]
function Initialize-MainApplication {
    # XAML direkt im Script definiert
    $xamlContent = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="easyADgroup - Modern AD Group Manager" 
    Width="1400" 
    Height="1003" 
    WindowStartupLocation="CenterScreen" 
    ResizeMode="CanResize"
    MinWidth="1200"
    MinHeight="800"
    Background="#F3F3F3"
    WindowStyle="SingleBorderWindow">

    <Window.Resources>
        <!-- Modern Windows 11 Style Resources -->
        <Style x:Key="ModernButton" TargetType="Button">
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                CornerRadius="4" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                BorderBrush="{TemplateBinding BorderBrush}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#106EBE"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#005A9E"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="#F3F2F1"/>
            <Setter Property="Foreground" Value="#323130"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#D2D0CE"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#EDEBE9"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#E1DFDD"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="#D13438"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#B02E32"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#A02B2F"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="CompactGroupBox" TargetType="GroupBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="BorderBrush" Value="#E1DFDD"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Margin" Value="0,4,0,4"/>
            <Setter Property="Padding" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="GroupBox">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <Border Grid.Row="0" Background="#F8F8F8" CornerRadius="6,6,0,0" Padding="12,8">
                                    <ContentPresenter ContentSource="Header" TextElement.FontWeight="SemiBold" TextElement.FontSize="14"/>
                                </Border>
                                <ContentPresenter Grid.Row="1" Margin="{TemplateBinding Padding}"/>
                            </Grid>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="InfoGroupBox" TargetType="GroupBox" BasedOn="{StaticResource CompactGroupBox}">
            <Setter Property="Background" Value="#F0F8FF"/>
            <Setter Property="BorderBrush" Value="#B3D9FF"/>
        </Style>

        <Style x:Key="ModernTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="#323130"/>
            <Setter Property="BorderBrush" Value="#D2D0CE"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="CaretBrush" Value="#323130"/>
            <Setter Property="SelectionBrush" Value="#0078D4"/>
        </Style>

        <Style x:Key="ModernComboBox" TargetType="ComboBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="BorderBrush" Value="#D2D0CE"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="3">
                            <Grid>
                                <ToggleButton x:Name="ToggleButton" Background="Transparent" BorderThickness="0" 
                                              IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}}"
                                              ClickMode="Press"/>
                                <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False" 
                                                  Content="{TemplateBinding SelectionBoxItem}"
                                                  ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                                  ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                                  Margin="{TemplateBinding Padding}"
                                                  VerticalAlignment="Center"
                                                  HorizontalAlignment="Left"/>
                                <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                                       AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                    <Border Background="White" BorderBrush="#D2D0CE" BorderThickness="1" CornerRadius="3"
                                            MinWidth="{TemplateBinding ActualWidth}" MaxHeight="200">
                                        <ScrollViewer>
                                            <StackPanel IsItemsHost="True"/>
                                        </ScrollViewer>
                                    </Border>
                                </Popup>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter Property="BorderBrush" Value="#0078D4"/>
                                <Setter Property="BorderThickness" Value="2"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ModernListBox" TargetType="ListBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="BorderBrush" Value="#D2D0CE"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBox">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="3">
                            <ScrollViewer>
                                <StackPanel IsItemsHost="True"/>
                            </ScrollViewer>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ModernRadioButton" TargetType="RadioButton">
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,2"/>
            <Setter Property="Padding" Value="6,0,0,0"/>
        </Style>

        <Style x:Key="ModernCheckBox" TargetType="CheckBox">
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,4"/>
            <Setter Property="Padding" Value="6,0,0,0"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="70" />
            <RowDefinition Height="*" />
            <RowDefinition Height="40" />
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#0078D4" Height="70">
            <Grid Margin="20,12">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                    <TextBlock x:Name="labelAppName" 
                               Text="easyADgroup" 
                               FontSize="20" 
                               FontWeight="Bold" 
                               Foreground="White"/>
                    <TextBlock x:Name="labelInfo" 
                               Text="{Binding LabelInfo}" 
                               FontSize="11" 
                               Foreground="#E1F5FE" 
                               Margin="0,2,0,0"/>
                </StackPanel>

                <Border Grid.Column="1" 
                        Background="White" 
                        CornerRadius="6" 
                        Padding="12,6" 
                        VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="?" FontSize="16" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,6,0"/>
                        <TextBlock Text="HELP" 
                                   FontWeight="SemiBold" 
                                   FontSize="13"
                                   VerticalAlignment="Center" 
                                   Foreground="#323130"/>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>

        <!-- Main Content -->
        <Grid Grid.Row="1" Margin="16,8">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="2*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="3*"/>
            </Grid.ColumnDefinitions>

            <!-- Left Column: Configuration -->
            <StackPanel Grid.Column="0">

                <!-- Quick Actions -->
                <GroupBox Header="Quick Actions" Style="{StaticResource CompactGroupBox}">
                    <UniformGrid Columns="3" Margin="0,4">
                        <Button Content="Templates" Style="{StaticResource SecondaryButton}" 
                                x:Name="buttonLoadTemplate" Margin="0,0,4,0" Height="28"/>
                        <Button Content="Save" Style="{StaticResource SecondaryButton}" 
                                x:Name="buttonSaveTemplate" Margin="2,0" Height="28"/>
                        <Button Content="Reset" Style="{StaticResource SecondaryButton}" 
                                x:Name="buttonReset" Margin="4,0,0,0" Height="28"/>
                    </UniformGrid>
                </GroupBox>

                <!-- OU Selection -->
                <GroupBox Header="OU Selection" Style="{StaticResource CompactGroupBox}" Margin="0,8,0,8">
                    <StackPanel>
                        <TextBlock Text="Target OU for new groups:" Margin="0,0,0,4" FontSize="12"/>
                        <ComboBox x:Name="comboBoxOU" 
                                  Style="{StaticResource ModernComboBox}"
                                  DisplayMemberPath="Name" 
                                  SelectedValuePath="DN"
                                  Height="35"/>
                    </StackPanel>
                </GroupBox>

                <!-- Group Configuration -->
                <GroupBox Header="Group Configuration" Style="{StaticResource CompactGroupBox}" Height="365">
                    <Grid Height="320">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Group Name -->
                        <Grid Grid.Row="0" Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="100"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="Name:" VerticalAlignment="Center" FontWeight="SemiBold" FontSize="12"/>
                            <TextBox Grid.Column="1" x:Name="textBoxPrefix" Height="25"/>
                        </Grid>

                        <!-- Number Range -->
                        <Grid Grid.Row="1" Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="100"/>
                                <ColumnDefinition Width="120"/>
                                <ColumnDefinition Width="80"/>
                                <ColumnDefinition Width="80"/>
                            </Grid.ColumnDefinitions>

                            <TextBlock Grid.Column="0" Text="Range:" VerticalAlignment="Center" FontWeight="SemiBold" FontSize="12"/>

                            <StackPanel Grid.Column="1" Margin="0,0,4,0">
                                <TextBlock Text="Seperator" FontSize="10" Margin="0,0,0,2"/>
                                <TextBox x:Name="textBoxSeparator" Text="-" Height="25"/>
                            </StackPanel>

                            <StackPanel Grid.Column="2" Margin="2,0">
                                <TextBlock Text="Start" FontSize="10" Margin="0,0,0,2"/>
                                <TextBox x:Name="textBoxStart" Height="25"/>
                            </StackPanel>

                            <StackPanel Grid.Column="3" Margin="4,0,0,0">
                                <TextBlock Text="End" FontSize="10" Margin="0,0,0,2"/>
                                <TextBox x:Name="textBoxEnd" Height="25"/>
                            </StackPanel>
                        </Grid>

                        <!-- Description -->
                        <Grid Grid.Row="2" Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="100"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="Description:" VerticalAlignment="Center" FontWeight="SemiBold" FontSize="12"/>
                            <TextBox Grid.Column="1" x:Name="textBoxDescription" Height="25"/>
                        </Grid>

                        <!-- Type and Scope -->
                        <Grid Grid.Row="3" Margin="0,10,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="4"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <Border Grid.Column="0" Background="#F8F8F8" CornerRadius="4" Padding="8">
                                <StackPanel>
                                    <TextBlock Text="Type" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,4"/>
                                    <RadioButton x:Name="radioSecurity" Content="Security" 
                                                 IsChecked="True" Style="{StaticResource ModernRadioButton}"/>
                                    <RadioButton x:Name="radioDistribution" Content="Distribution" 
                                                 Style="{StaticResource ModernRadioButton}"/>
                                </StackPanel>
                            </Border>

                            <Border Grid.Column="2" Background="#F8F8F8" CornerRadius="4" Padding="8">
                                <StackPanel>
                                    <TextBlock Text="Scope" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,4"/>
                                    <RadioButton x:Name="radioGlobal" Content="Global" 
                                                 IsChecked="True" Style="{StaticResource ModernRadioButton}"/>
                                    <RadioButton x:Name="radioUniversal" Content="Universal" 
                                                 Style="{StaticResource ModernRadioButton}"/>
                                    <RadioButton x:Name="radioDomainLocal" Content="Domain Local" 
                                                 Style="{StaticResource ModernRadioButton}"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <!-- Options -->
                        <UniformGrid Grid.Row="4" Columns="3">
                            <CheckBox x:Name="chkSpecial" 
                                      Content="JIRA/Confluence Mode" 
                                      Style="{StaticResource ModernCheckBox}" Margin="0,10,2,0"/>
                            <CheckBox x:Name="chkAutoNaming" 
                                      Content="Auto-Naming" 
                                      Style="{StaticResource ModernCheckBox}" Margin="2,10,2,0"/>
                            <CheckBox x:Name="chkCreateOUIfNotExists" 
                                      Content="Auto-create OU" 
                                      Style="{StaticResource ModernCheckBox}" Margin="2,10,0,0"/>
                        </UniformGrid>
                    </Grid>
                </GroupBox>

                <!-- Advanced Options -->
                <GroupBox Header="Advanced Options" Style="{StaticResource CompactGroupBox}" Height="218" Margin="0,11,0,0">
                    <Grid Height="150">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- CSV Operations -->
                        <Border Grid.Row="0" Background="#FFF4E6" CornerRadius="4" Padding="8" Margin="0,0,0,8">
                            <StackPanel>
                                <TextBlock Text="CSV Import/Export" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,4"/>
                                <UniformGrid Columns="2">
                                    <Button Content="Template" Style="{StaticResource SecondaryButton}" 
                                            x:Name="buttonDownloadTemplate" Margin="0,0,2,0" Height="24"/>
                                    <Button Content="Import" Style="{StaticResource SecondaryButton}" 
                                            x:Name="buttonImportCSV" Margin="2,0,0,0" Height="24"/>
                                </UniformGrid>
                            </StackPanel>
                        </Border>

                        <!-- Validation and Email in one row -->
                        <Grid Grid.Row="1">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="8"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Validation -->
                            <Border Grid.Column="0" Background="#E8F5E8" CornerRadius="4" Padding="8">
                                <StackPanel>
                                    <TextBlock Text="Validation" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,4"/>
                                    <UniformGrid Columns="3">
                                        <CheckBox x:Name="chkValidateNames" Content="Names" 
                                                  IsChecked="True" Style="{StaticResource ModernCheckBox}" FontSize="11" Margin="0,0,2,0"/>
                                        <CheckBox x:Name="chkCheckDuplicates" Content="Duplicates" 
                                                  IsChecked="True" Style="{StaticResource ModernCheckBox}" FontSize="11" Margin="2,0,2,0"/>
                                        <CheckBox x:Name="chkDryRun" Content="Test Run" 
                                                  Style="{StaticResource ModernCheckBox}" FontSize="11" Margin="2,0,0,0"/>
                                    </UniformGrid>
                                </StackPanel>
                            </Border>

                            <!-- Email -->
                            <Border Grid.Column="2" Background="#F0F8FF" CornerRadius="4" Padding="8">
                                <StackPanel>
                                    <TextBlock Text="Email Notification" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,4"/>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <CheckBox Grid.Column="0" x:Name="chkEmailNotification" Content="" 
                                                  Style="{StaticResource ModernCheckBox}" Margin="0,0,4,0"/>
                                        <TextBox Grid.Column="1" x:Name="textBoxNotificationEmail"  
                                                 Margin="0,0,4,0" Height="25"/>
                                        <Button Grid.Column="2" Content="Test" Style="{StaticResource SecondaryButton}" 
                                                x:Name="buttonTestEmail" Width="40" Height="24"/>
                                    </Grid>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </Grid>
                </GroupBox>
            </StackPanel>

            <!-- Right Column: Users and Info -->
            <Grid Grid.Column="2">
                <Grid.RowDefinitions>
                    <RowDefinition Height="2*"/>
                    <RowDefinition Height="8"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="8"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <!-- Group Members -->
                <GroupBox Grid.Row="0" Header="Group Members" Style="{StaticResource CompactGroupBox}">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Search Field -->
                        <Grid Grid.Row="0" Margin="0,0,0,6">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox Grid.Column="0" x:Name="textBoxUserSearch" 
                                     Margin="0,0,6,0" Height="32"
                                     ToolTip="Enter username or display name to search" 
                                     Foreground="Black"
                                     Background="White"
                                     BorderBrush="#D2D0CE"
                                     BorderThickness="1"
                                     Padding="8,6"
                                     FontSize="13"/>
                            <Button Grid.Column="1" Content="Search" 
                                    Style="{StaticResource SecondaryButton}" 
                                    x:Name="buttonSearchUsers" Width="60" Height="28"/>
                        </Grid>

                        <TextBlock Grid.Row="1" Text="Select users (Ctrl+Click):" 
                                   Margin="0,0,0,4" FontSize="12"/>

                        <ListBox Grid.Row="2" x:Name="listBoxUsers" 
                                 Style="{StaticResource ModernListBox}"
                                 SelectionMode="Extended"/>

                        <!-- User Actions -->
                        <UniformGrid Grid.Row="3" Columns="3" Margin="0,6,0,0">
                            <Button Content="Select All" Style="{StaticResource SecondaryButton}" 
                                    x:Name="buttonSelectAllUsers" Margin="0,0,2,0" Height="26"/>
                            <Button Content="Clear" Style="{StaticResource SecondaryButton}" 
                                    x:Name="buttonDeselectAllUsers" Margin="1,0" Height="26"/>
                            <Button Content="Refresh" Style="{StaticResource SecondaryButton}" 
                                    x:Name="buttonRefreshUsers" Margin="2,0,0,0" Height="26"/>
                        </UniformGrid>
                    </Grid>
                </GroupBox>

                <!-- Info Box -->
                <GroupBox Grid.Row="2" Header="Quick Guide" Style="{StaticResource InfoGroupBox}" Height="120">
                    <StackPanel>
                        <TextBlock Text="1. Select target OU for group creation   ->   2. Enter an optional group name prefix and number range / if left blank, only one group will be created." FontSize="11" Margin="0,2"/>
                        <TextBlock Text="3. Choose group type (Security/Distribution) and scope   ->   4. Select users to add to groups (optional)   ->   5. Use Preview to check and create group(s)" FontSize="11" Margin="0,2" FontWeight="SemiBold"/>
                    </StackPanel>
                </GroupBox>

                <!-- Action Buttons -->
                <Grid Grid.Row="4">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Progress Bar -->
                    <ProgressBar Grid.Row="0" x:Name="progressBarMain" 
                                 Height="6" 
                                 Visibility="Collapsed" 
                                 Background="#F3F2F1" 
                                 Foreground="#0078D4"
                                 Margin="0,0,0,8"/>

                    <!-- Buttons -->
                    <UniformGrid Grid.Row="1" Columns="4">
                        <Button Content="Preview" 
                                Style="{StaticResource SecondaryButton}" 
                                x:Name="buttonPreview" 
                                Height="36" 
                                Margin="0,0,4,0"/>

                        <Button Content="Create" 
                                Style="{StaticResource ModernButton}" 
                                x:Name="buttonCreate" 
                                Height="36" 
                                Margin="2,0"/>

                        <Button Content="Report" 
                                Style="{StaticResource SecondaryButton}" 
                                x:Name="buttonReport" 
                                Height="36" 
                                Margin="2,0"/>

                        <Button Content="Close" 
                                Style="{StaticResource DangerButton}" 
                                x:Name="buttonClose" 
                                Height="36" 
                                Margin="4,0,0,0"/>
                    </UniformGrid>
                </Grid>
            </Grid>
        </Grid>

        <!-- Footer -->
        <Border Grid.Row="2" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,1,0,0" Height="40">
            <Grid Margin="20,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="Web:" FontSize="12" VerticalAlignment="Center" Margin="0,0,6,0"/>
                    <TextBlock x:Name="linkLabel" VerticalAlignment="Center">
                        <Hyperlink x:Name="hyperlinkWebsite" NavigateUri="https://phinit.de" 
                                   TextDecorations="None" Foreground="#0078D4" FontSize="12">
                            https://phinit.de
                        </Hyperlink>
                    </TextBlock>
                </StackPanel>

                <TextBlock Grid.Column="1" x:Name="statusLabel" 
                           Text="Ready" 
                           VerticalAlignment="Center" 
                           FontSize="11" 
                           Foreground="#605E5C" 
                           Margin="0,0,12,0"/>

                <TextBlock Grid.Column="2" x:Name="footerInfo" 
                           VerticalAlignment="Center" 
                           FontSize="11" 
                           Foreground="#605E5C"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@
    
    try {
        # XAML laden und WPF-Objekte erstellen
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlContent)
        $script:window = [Windows.Markup.XamlReader]::Load($reader)
        
        Write-DebugMessage "XAML erfolgreich aus eingebettetem String geladen"
        
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
        
        # Neue GUI-Elemente referenzieren
        $script:textBoxUserSearch = $window.FindName("textBoxUserSearch")
        $script:textBoxNotificationEmail = $window.FindName("textBoxNotificationEmail")
        $script:chkAutoNaming = $window.FindName("chkAutoNaming")
        $script:chkCreateOUIfNotExists = $window.FindName("chkCreateOUIfNotExists")
        $script:chkValidateNames = $window.FindName("chkValidateNames")
        $script:chkCheckDuplicates = $window.FindName("chkCheckDuplicates")
        $script:chkDryRun = $window.FindName("chkDryRun")
        $script:chkEmailNotification = $window.FindName("chkEmailNotification")
        $script:buttonLoadTemplate = $window.FindName("buttonLoadTemplate")
        $script:buttonSaveTemplate = $window.FindName("buttonSaveTemplate")
        $script:buttonReset = $window.FindName("buttonReset")
        $script:buttonSearchUsers = $window.FindName("buttonSearchUsers")
        $script:buttonSelectAllUsers = $window.FindName("buttonSelectAllUsers")
        $script:buttonDeselectAllUsers = $window.FindName("buttonDeselectAllUsers")
        $script:buttonRefreshUsers = $window.FindName("buttonRefreshUsers")
        $script:buttonDownloadTemplate = $window.FindName("buttonDownloadTemplate")
        $script:buttonImportCSV = $window.FindName("buttonImportCSV")
        $script:buttonTestEmail = $window.FindName("buttonTestEmail")
        $script:buttonReport = $window.FindName("buttonReport")
        $script:progressBarMain = $window.FindName("progressBarMain")
        $script:statusLabel = $window.FindName("statusLabel")
        
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
        
        # Lade verfügbare Vorlagen
        Load-AvailableTemplates
        
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

# Entferne die fehlerhaften Zeilen am Ende und ersetze durch den korrekten Start
try {
    Write-LogMessage "easyADGroups v$($generalConfig.ScriptVersion) wird gestartet..." -logLevel "INFO"
    Write-Host "easyADGroups v$($generalConfig.ScriptVersion) - Modern AD Group Management" -ForegroundColor Green
    Write-Host "Build: $($generalConfig.LastUpdate)" -ForegroundColor Gray
    
    Initialize-MainApplication
} 
catch {
    Write-Error "Application startup failed: $($_.Exception.Message)"
    exit 1
}
# SIG # Begin signature block
# MIIoiQYJKoZIhvcNAQcCoIIoejCCKHYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBQubKBlurx7tDS
# /Tzab/CmcrOEjbaC+S98a7RuNV7z56CCILswggXJMIIEsaADAgECAhAbtY8lKt8j
# AEkoya49fu0nMA0GCSqGSIb3DQEBDAUAMH4xCzAJBgNVBAYTAlBMMSIwIAYDVQQK
# ExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVzdGVkIE5l
# dHdvcmsgQ0EwHhcNMjEwNTMxMDY0MzA2WhcNMjkwOTE3MDY0MzA2WjCBgDELMAkG
# A1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAl
# BgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMb
# Q2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAvfl4+ObVgAxknYYblmRnPyI6HnUBfe/7XGeMycxca6mR5rlC
# 5SBLm9qbe7mZXdmbgEvXhEArJ9PoujC7Pgkap0mV7ytAJMKXx6fumyXvqAoAl4Va
# qp3cKcniNQfrcE1K1sGzVrihQTib0fsxf4/gX+GxPw+OFklg1waNGPmqJhCrKtPQ
# 0WeNG0a+RzDVLnLRxWPa52N5RH5LYySJhi40PylMUosqp8DikSiJucBb+R3Z5yet
# /5oCl8HGUJKbAiy9qbk0WQq/hEr/3/6zn+vZnuCYI+yma3cWKtvMrTscpIfcRnNe
# GWJoRVfkkIJCu0LW8GHgwaM9ZqNd9BjuiMmNF0UpmTJ1AjHuKSbIawLmtWJFfzcV
# WiNoidQ+3k4nsPBADLxNF8tNorMe0AZa3faTz1d1mfX6hhpneLO/lv403L3nUlbl
# s+V1e9dBkQXcXWnjlQ1DufyDljmVe2yAWk8TcsbXfSl6RLpSpCrVQUYJIP4ioLZb
# MI28iQzV13D4h1L92u+sUS4Hs07+0AnacO+Y+lbmbdu1V0vc5SwlFcieLnhO+Nqc
# noYsylfzGuXIkosagpZ6w7xQEmnYDlpGizrrJvojybawgb5CAKT41v4wLsfSRvbl
# jnX98sy50IdbzAYQYLuDNbdeZ95H7JlI8aShFf6tjGKOOVVPORa5sWOd/7cCAwEA
# AaOCAT4wggE6MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLahVDkCw6A/joq8
# +tT4HKbROg79MB8GA1UdIwQYMBaAFAh2zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1Ud
# DwEB/wQEAwIBBjAvBgNVHR8EKDAmMCSgIqAghh5odHRwOi8vY3JsLmNlcnR1bS5w
# bC9jdG5jYS5jcmwwawYIKwYBBQUHAQEEXzBdMCgGCCsGAQUFBzABhhxodHRwOi8v
# c3ViY2Eub2NzcC1jZXJ0dW0uY29tMDEGCCsGAQUFBzAChiVodHRwOi8vcmVwb3Np
# dG9yeS5jZXJ0dW0ucGwvY3RuY2EuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQG
# CCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEM
# BQADggEBAFHCoVgWIhCL/IYx1MIy01z4S6Ivaj5N+KsIHu3V6PrnCA3st8YeDrJ1
# BXqxC/rXdGoABh+kzqrya33YEcARCNQOTWHFOqj6seHjmOriY/1B9ZN9DbxdkjuR
# mmW60F9MvkyNaAMQFtXx0ASKhTP5N+dbLiZpQjy6zbzUeulNndrnQ/tjUoCFBMQl
# lVXwfqefAcVbKPjgzoZwpic7Ofs4LphTZSJ1Ldf23SIikZbr3WjtP6MZl9M7JYjs
# NhI9qX7OAo0FmpKnJ25FspxihjcNpDOO16hO0EoXQ0zF8ads0h5YbBRRfopUofbv
# n3l6XYGaFpAP4bvxSgD5+d2+7arszgowggaDMIIEa6ADAgECAhEAnpwE9lWotKcC
# bUmMbHiNqjANBgkqhkiG9w0BAQwFADBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMY
# QXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0
# YW1waW5nIDIwMjEgQ0EwHhcNMjUwMTA5MDg0MDQzWhcNMzYwMTA3MDg0MDQzWjBQ
# MQswCQYDVQQGEwJQTDEhMB8GA1UECgwYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEu
# MR4wHAYDVQQDDBVDZXJ0dW0gVGltZXN0YW1wIDIwMjUwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDHKV9n+Kwr3ZBF5UCLWOQ/NdbblAvQeGMjfCi/bibT
# 71hPkwKV4UvQt1MuOwoaUCYtsLhw8jrmOmoz2HoHKKzEpiS3A1rA3ssXUZMnSrbi
# iVpDj+5MtnbXSVEJKbccuHbmwcjl39N4W72zccoC/neKAuwO1DJ+9SO+YkHncRiV
# 95idWhxRAcDYv47hc9GEFZtTFxQXLbrL4N7N90BqLle3ayznzccEPQ+E6H6p00zE
# 9HUp++3bZTF4PfyPRnKCLc5ezAzEqqbbU5F/nujx69T1mm02jltlFXnTMF1vlake
# QXWYpGIjtrR7WP7tIMZnk78nrYSfeAp8le+/W/5+qr7tqQZufW9invsRTcfk7P+m
# nKjJLuSbwqgxelvCBryz9r51bT0561aR2c+joFygqW7n4FPCnMLOj40X4ot7wP2u
# 8kLRDVHbhsHq5SGLqr8DbFq14ws2ALS3tYa2GGiA7wX79rS5oDMnSY/xmJO5cupu
# SvqpylzO7jzcLOwWiqCrq05AXp51SRrj9xRt8KdZWpDdWhWmE8MFiFtmQ0AqODLJ
# Bn1hQAx3FvD/pte6pE1Bil0BOVC2Snbeq/3NylDwvDdAg/0CZRJsQIaydHswJwyY
# BlYUDyaQK2yUS57hobnYx/vStMvTB96ii4jGV3UkZh3GvwdDCsZkbJXaU8ATF/z6
# DwIDAQABo4IBUDCCAUwwdQYIKwYBBQUHAQEEaTBnMDsGCCsGAQUFBzAChi9odHRw
# Oi8vc3ViY2EucmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3RzY2EyMDIxLmNlcjAoBggr
# BgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTAfBgNVHSMEGDAW
# gBS+VAIvv0Bsc0POrAklTp5DRBru4DAMBgNVHRMBAf8EAjAAMDkGA1UdHwQyMDAw
# LqAsoCqGKGh0dHA6Ly9zdWJjYS5jcmwuY2VydHVtLnBsL2N0c2NhMjAyMS5jcmww
# FgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMCIGA1UdIAQb
# MBkwCAYGZ4EMAQQCMA0GCyqEaAGG9ncCBQELMB0GA1UdDgQWBBSBjAagKFP8AD/b
# fp5KwR8i7LISiTANBgkqhkiG9w0BAQwFAAOCAgEAmQ8ZDBvrBUPnaL87AYc4Jlmf
# H1ZP5yt65MtzYu8fbmsL3d3cvYs+Enbtfu9f2wMehzSyved3Rc59a04O8NN7plw4
# PXg71wfSE4MRFM1EuqL63zq9uTjm/9tA73r1aCdWmkprKp0aLoZolUN0qGcvr9+Q
# G8VIJVMcuSqFeEvRrLEKK2xVkMSdTTbDhseUjI4vN+BrXm5z45EA3aDpSiZQuoNd
# 4RFnDzddbgfcCQPaY2UyXqzNBjnuz6AyHnFzKtNlCevkMBgh4dIDt/0DGGDOaTEA
# WZtUEqK5AlHd0PBnd40Lnog4UATU3Bt6GHfeDmWEHFTjHKsmn9Q8wiGj906bVgL8
# 35tfEH9EgYDklqrOUxWxDf1cOA7ds/r8pIc2vjLQ9tOSkm9WXVbnTeLG3Q57frTg
# CvTObd/qf3UzE97nTNOU7vOMZEo41AgmhuEbGsyQIDM/V6fJQX1RnzzJNoqfTTkU
# zUoP2tlNHnNsjFo2YV+5yZcoaawmNWmR7TywUXG2/vFgJaG0bfEoodeeXp7A4I4H
# aDDpfRa7ypgJEPeTwHuBRJpj9N+1xtri+6BzHPwsAAvUJm58PGoVsteHAXwvpg4N
# VgvUk3BKbl7xFulWU1KHqH/sk7T0CFBQ5ohuKPmFf1oqAP4AO9a3Yg2wBMwEg1zP
# Oh6xbUXskzs9iSa9yGwwgga5MIIEoaADAgECAhEAmaOACiZVO2Wr3G6EprPqOTAN
# BgkqhkiG9w0BAQwFADCBgDELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8g
# VGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9u
# IEF1dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAy
# MB4XDTIxMDUxOTA1MzIxOFoXDTM2MDUxODA1MzIxOFowVjELMAkGA1UEBhMCUEwx
# ITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2Vy
# dHVtIENvZGUgU2lnbmluZyAyMDIxIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAnSPPBDAjO8FGLOczcz5jXXp1ur5cTbq96y34vuTmflN4mSAfgLKT
# vggv24/rWiVGzGxT9YEASVMw1Aj8ewTS4IndU8s7VS5+djSoMcbvIKck6+hI1shs
# ylP4JyLvmxwLHtSworV9wmjhNd627h27a8RdrT1PH9ud0IF+njvMk2xqbNTIPsnW
# tw3E7DmDoUmDQiYi/ucJ42fcHqBkbbxYDB7SYOouu9Tj1yHIohzuC8KNqfcYf7Z4
# /iZgkBJ+UFNDcc6zokZ2uJIxWgPWXMEmhu1gMXgv8aGUsRdaCtVD2bSlbfsq7Biq
# ljjaCun+RJgTgFRCtsuAEw0pG9+FA+yQN9n/kZtMLK+Wo837Q4QOZgYqVWQ4x6cM
# 7/G0yswg1ElLlJj6NYKLw9EcBXE7TF3HybZtYvj9lDV2nT8mFSkcSkAExzd4prHw
# YjUXTeZIlVXqj+eaYqoMTpMrfh5MCAOIG5knN4Q/JHuurfTI5XDYO962WZayx7AC
# Ff5ydJpoEowSP07YaBiQ8nXpDkNrUA9g7qf/rCkKbWpQ5boufUnq1UiYPIAHlezf
# 4muJqxqIns/kqld6JVX8cixbd6PzkDpwZo4SlADaCi2JSplKShBSND36E/ENVv8u
# rPS0yOnpG4tIoBGxVCARPCg1BnyMJ4rBJAcOSnAWd18Jx5n858JSqPECAwEAAaOC
# AVUwggFRMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFN10XUwA23ufoHTKsW73
# PMAywHDNMB8GA1UdIwQYMBaAFLahVDkCw6A/joq8+tT4HKbROg79MA4GA1UdDwEB
# /wQEAwIBBjATBgNVHSUEDDAKBggrBgEFBQcDAzAwBgNVHR8EKTAnMCWgI6Ahhh9o
# dHRwOi8vY3JsLmNlcnR1bS5wbC9jdG5jYTIuY3JsMGwGCCsGAQUFBwEBBGAwXjAo
# BggrBgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTAyBggrBgEF
# BQcwAoYmaHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBsL2N0bmNhMi5jZXIwOQYD
# VR0gBDIwMDAuBgRVHSAAMCYwJAYIKwYBBQUHAgEWGGh0dHA6Ly93d3cuY2VydHVt
# LnBsL0NQUzANBgkqhkiG9w0BAQwFAAOCAgEAdYhYD+WPUCiaU58Q7EP89DttyZqG
# Yn2XRDhJkL6P+/T0IPZyxfxiXumYlARMgwRzLRUStJl490L94C9LGF3vjzzH8Jq3
# iR74BRlkO18J3zIdmCKQa5LyZ48IfICJTZVJeChDUyuQy6rGDxLUUAsO0eqeLNhL
# Vsgw6/zOfImNlARKn1FP7o0fTbj8ipNGxHBIutiRsWrhWM2f8pXdd3x2mbJCKKtl
# 2s42g9KUJHEIiLni9ByoqIUul4GblLQigO0ugh7bWRLDm0CdY9rNLqyA3ahe8Wlx
# VWkxyrQLjH8ItI17RdySaYayX3PhRSC4Am1/7mATwZWwSD+B7eMcZNhpn8zJ+6MT
# yE6YoEBSRVrs0zFFIHUR08Wk0ikSf+lIe5Iv6RY3/bFAEloMU+vUBfSouCReZwSL
# o8WdrDlPXtR0gicDnytO7eZ5827NS2x7gCBibESYkOh1/w1tVxTpV2Na3PR7nxYV
# lPu1JPoRZCbH86gc96UTvuWiOruWmyOEMLOGGniR+x+zPF/2DaGgK2W1eEJfo2qy
# rBNPvF7wuAyQfiFXLwvWHamoYtPZo0LHuH8X3n9C+xN4YaNjt2ywzOr+tKyEVAot
# nyU9vyEVOaIYMk3IeBrmFnn0gbKeTTyYeEEUz/Qwt4HOUBCrW602NCmvO1nm+/80
# nLy5r0AZvCQxaQ4wgga5MIIEoaADAgECAhEA5/9pxzs1zkuRJth0fGilhzANBgkq
# hkiG9w0BAQwFADCBgDELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVj
# aG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1
# dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMB4X
# DTIxMDUxOTA1MzIwN1oXDTM2MDUxODA1MzIwN1owVjELMAkGA1UEBhMCUEwxITAf
# BgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2VydHVt
# IFRpbWVzdGFtcGluZyAyMDIxIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEA6RIfBDXtuV16xaaVQb6KZX9Od9FtJXXTZo7b+GEof3+3g0ChWiKnO7R4
# +6MfrvLyLCWZa6GpFHjEt4t0/GiUQvnkLOBRdBqr5DOvlmTvJJs2X8ZmWgWJjC7P
# BZLYBWAs8sJl3kNXxBMX5XntjqWx1ZOuuXl0R4x+zGGSMzZ45dpvB8vLpQfZkfMC
# /1tL9KYyjU+htLH68dZJPtzhqLBVG+8ljZ1ZFilOKksS79epCeqFSeAUm2eMTGpO
# iS3gfLM6yvb8Bg6bxg5yglDGC9zbr4sB9ceIGRtCQF1N8dqTgM/dSViiUgJkcv5d
# LNJeWxGCqJYPgzKlYZTgDXfGIeZpEFmjBLwURP5ABsyKoFocMzdjrCiFbTvJn+bD
# 1kq78qZUgAQGGtd6zGJ88H4NPJ5Y2R4IargiWAmv8RyvWnHr/VA+2PrrK9eXe5q7
# M88YRdSTq9TKbqdnITUgZcjjm4ZUjteq8K331a4P0s2in0p3UubMEYa/G5w6jSWP
# UzchGLwWKYBfeSu6dIOC4LkeAPvmdZxSB1lWOb9HzVWZoM8Q/blaP4LWt6JxjkI9
# yQsYGMdCqwl7uMnPUIlcExS1mzXRxUowQref/EPaS7kYVaHHQrp4XB7nTEtQhkP0
# Z9Puz/n8zIFnUSnxDof4Yy650PAXSYmK2TcbyDoTNmmt8xAxzcMCAwEAAaOCAVUw
# ggFRMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFL5UAi+/QGxzQ86sCSVOnkNE
# Gu7gMB8GA1UdIwQYMBaAFLahVDkCw6A/joq8+tT4HKbROg79MA4GA1UdDwEB/wQE
# AwIBBjATBgNVHSUEDDAKBggrBgEFBQcDCDAwBgNVHR8EKTAnMCWgI6Ahhh9odHRw
# Oi8vY3JsLmNlcnR1bS5wbC9jdG5jYTIuY3JsMGwGCCsGAQUFBwEBBGAwXjAoBggr
# BgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTAyBggrBgEFBQcw
# AoYmaHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBsL2N0bmNhMi5jZXIwOQYDVR0g
# BDIwMDAuBgRVHSAAMCYwJAYIKwYBBQUHAgEWGGh0dHA6Ly93d3cuY2VydHVtLnBs
# L0NQUzANBgkqhkiG9w0BAQwFAAOCAgEAuJNZd8lMFf2UBwigp3qgLPBBk58BFCS3
# Q6aJDf3TISoytK0eal/JyCB88aUEd0wMNiEcNVMbK9j5Yht2whaknUE1G32k6uld
# 7wcxHmw67vUBY6pSp8QhdodY4SzRRaZWzyYlviUpyU4dXyhKhHSncYJfa1U75cXx
# Ce3sTp9uTBm3f8Bj8LkpjMUSVTtMJ6oEu5JqCYzRfc6nnoRUgwz/GVZFoOBGdrSE
# tDN7mZgcka/tS5MI47fALVvN5lZ2U8k7Dm/hTX8CWOw0uBZloZEW4HB0Xra3qE4q
# zzq/6M8gyoU/DE0k3+i7bYOrOk/7tPJg1sOhytOGUQ30PbG++0FfJioDuOFhj99b
# 151SqFlSaRQYz74y/P2XJP+cF19oqozmi0rRTkfyEJIvhIZ+M5XIFZttmVQgTxfp
# fJwMFFEoQrSrklOxpmSygppsUDJEoliC05vBLVQ+gMZyYaKvBJ4YxBMlKH5ZHkRd
# loRYlUDplk8GUa+OCMVhpDSQurU6K1ua5dmZftnvSSz2H96UrQDzA6DyiI1V3ejV
# tvn2azVAXg6NnjmuRZ+wa7Pxy0H3+V4K4rOTHlG3VYA6xfLsTunCz72T6Ot4+tkr
# DYOeaU1pPX1CBfYj6EW2+ELq46GP8KCNUQDirWLU4nOmgCat7vN0SD6RlwUiSsMe
# CiQDmZwgwrUwggbpMIIE0aADAgECAhBiOsZKIV2oSfsf25d4iu6HMA0GCSqGSIb3
# DQEBCwUAMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0
# ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNpZ25pbmcgMjAyMSBDQTAe
# Fw0yNTA3MzExMTM4MDhaFw0yNjA3MzExMTM4MDdaMIGOMQswCQYDVQQGEwJERTEb
# MBkGA1UECAwSQmFkZW4tV8O8cnR0ZW1iZXJnMRQwEgYDVQQHDAtCYWllcnNicm9u
# bjEeMBwGA1UECgwVT3BlbiBTb3VyY2UgRGV2ZWxvcGVyMSwwKgYDVQQDDCNPcGVu
# IFNvdXJjZSBEZXZlbG9wZXIsIEhlcHAgQW5kcmVhczCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAOt2txKXx2UtfBNIw2kVihIAcgPkK3lp7np/qE0evLq2
# J/L5kx8m6dUY4WrrcXPSn1+W2/PVs/XBFV4fDfwczZnQ/hYzc8Ot5YxPKLx6hZxK
# C5v8LjNIZ3SRJvMbOpjzWoQH7MLIIj64n8mou+V0CMk8UElmU2d0nxBQyau1njQP
# CLvlfInu4tDndyp3P87V5bIdWw6MkZFhWDkILTYInYicYEkut5dN9hT02t/3rXu2
# 30DEZ6S1OQtm9loo8wzvwjRoVX3IxnfpCHGW8Z9ie9I9naMAOG2YpvpoUbLG3fL/
# B6JVNNR1mm/AYaqVMtAXJpRlqvbIZyepcG0YGB+kOQLdoQCWlIp3a14Z4kg6bU9C
# U1KNR4ueA+SqLNu0QGtgBAdTfqoWvyiaeyEogstBHglrZ39y/RW8OOa50pSleSRx
# SXiGW+yH+Ps5yrOopTQpKHy0kRincuJpYXgxGdGxxKHwuVJHKXL0nWScEku0C38p
# M9sYanIKncuF0Ed7RvyNqmPP5pt+p/0ZG+zLNu/Rce0LE5FjAIRtW2hFxmYMyohk
# afzyjCCCG0p2KFFT23CoUfXx59nCU+lyWx/iyDMV4sqrcvmZdPZF7lkaIb5B4PYP
# vFFE7enApz4Niycj1gPUFlx4qTcXHIbFLJDp0ry6MYelX+SiMHV7yDH/rnWXm5d3
# AgMBAAGjggF4MIIBdDAMBgNVHRMBAf8EAjAAMD0GA1UdHwQ2MDQwMqAwoC6GLGh0
# dHA6Ly9jY3NjYTIwMjEuY3JsLmNlcnR1bS5wbC9jY3NjYTIwMjEuY3JsMHMGCCsG
# AQUFBwEBBGcwZTAsBggrBgEFBQcwAYYgaHR0cDovL2Njc2NhMjAyMS5vY3NwLWNl
# cnR1bS5jb20wNQYIKwYBBQUHMAKGKWh0dHA6Ly9yZXBvc2l0b3J5LmNlcnR1bS5w
# bC9jY3NjYTIwMjEuY2VyMB8GA1UdIwQYMBaAFN10XUwA23ufoHTKsW73PMAywHDN
# MB0GA1UdDgQWBBQYl6R41hwxInb9JVvqbCTp9ILCcTBLBgNVHSAERDBCMAgGBmeB
# DAEEATA2BgsqhGgBhvZ3AgUBBDAnMCUGCCsGAQUFBwIBFhlodHRwczovL3d3dy5j
# ZXJ0dW0ucGwvQ1BTMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIH
# gDANBgkqhkiG9w0BAQsFAAOCAgEAQ4guyo7zysB7MHMBOVKKY72rdY5hrlxPci8u
# 1RgBZ9ZDGFzhnUM7iIivieAeAYLVxP922V3ag9sDVNR+mzCmu1pWCgZyBbNXykue
# KJwOfE8VdpmC/F7637i8a7Pyq6qPbcfvLSqiXtVrT4NX4NIvODW3kIqf4nGwd0h3
# 1tuJVHLkdpGmT0q4TW0gAxnNoQ+lO8uNzCrtOBk+4e1/3CZXSDnjR8SUsHrHdhnm
# qkAnYb40vf69dfDR148tToUj872yYeBUEGUsQUDgJ6HSkMVpLQz/Nb3xy9qkY33M
# 7CBWKuBVwEcbGig/yj7CABhIrY1XwRddYQhEyozUS4mXNqXydAD6Ylt143qrECD2
# s3MDQBgP2sbRHdhVgzr9+n1iztXkPHpIlnnXPkZrt89E5iGL+1PtjETrhTkr7nxj
# yMFjrbmJ8W/XglwopUTCGfopDFPlzaoFf5rH/v3uzS24yb6+dwQrvCwFA9Y9ZHy2
# ITJx7/Ll6AxWt7Lz9JCJ5xRyYeRUHs6ycB8EuMPAKyGpzdGtjWv2rkTXbkIYUjkl
# FTpquXJBc/kO5L+Quu0a0uKn4ea16SkABy052XHQqd87cSJg3rGxsagi0IAfxGM6
# 08oupufSS/q9mpQPgkDuMJ8/zdre0st8OduAoG131W+XJ7mm0gIuh2zNmSIet5RD
# oa8THmwxggckMIIHIAIBATBqMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3Nl
# Y28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNpZ25p
# bmcgMjAyMSBDQQIQYjrGSiFdqEn7H9uXeIruhzANBglghkgBZQMEAgEFAKCBhDAY
# BgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3
# AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEi
# BCAlHKqUK0aVr7zpg2ZLqabJ6R3MfbK3WzMH6ISOWy36qDANBgkqhkiG9w0BAQEF
# AASCAgB0S4PXWyxQj5aJ2Nb3Oaa37dv14L47ThwdAhN1on1OMQv98aaOr8eAe7G0
# 8+m8FkmvVSczLbazEwiDIT1ahNvnz3Jxc2XuKShnydW9YUnACMVon+oR+jKTjeIF
# ueeA1ui2SotdIRzXIPujQ3d59Q/CtwUJgt+n41JzlRcgLZWq2MpteEPoAIWGyYK9
# 7+MLjaXqR+cT2sPew7XpaSJuqPRduRyM/PlTI43qyR84fWP7PZjNXNVdLO2pfOnf
# a7XxMePOM0V8S02VgYqnLxHsm5zgxQSRU/W1IYhIW2Bn5G7fmAmUNKwHfoA1tTBL
# j/Wvkdw/GIMO8c4BxbHkmUN6DkhHANSfcBKFCuu5qA6PVbltQ1Zd39YZhR0PPsUo
# 0vQPbxI70Hp9NyVH0H9tWBEQt00mC8c/HHC/OdhJ5dMTkYgaIpHidGYSkRhpzB64
# jyL5ezjg2FlbaOAPkL3orFdGwt21yd0aV7v31arTuQ5/eOaam0VVHX/FoH3G/Krv
# irLE+6JA5Ms4Ur94Hxc3UDaFI99vqBevPnGVW7dKQy5m1pSfcv993psRTfvmDApT
# 4AibdRDX3pz2UokxcdGGBKn0G8h2Mb1n7OtlVxsgqyy8YuyWDy56eG3d1guL7ufQ
# r/RTSqCImGe9vfezOWajaHmYSnJupid5Pu8WgsMfsbpEX2f6eKGCBAQwggQABgkq
# hkiG9w0BCQYxggPxMIID7QIBATBrMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3Rh
# bXBpbmcgMjAyMSBDQQIRAJ6cBPZVqLSnAm1JjGx4jaowDQYJYIZIAWUDBAICBQCg
# ggFXMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcN
# MjUxMDI1MTc1NzIxWjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDPodw1ne0rw8uJ
# D6Iw5dr3e1QPGm4rI93PF1ThjPqg1TA/BgkqhkiG9w0BCQQxMgQwj2DXVSedmF0v
# BRhEXS16D7/juiIAnSlMP/pIljVlt64nFiFmdReP0ja+FfY5+9a5MIGgBgsqhkiG
# 9w0BCRACDDGBkDCBjTCBijCBhwQUwyW4mxf8xQJgYc4rcXtFB92camowbzBapFgw
# VjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhEAnpwE9lWo
# tKcCbUmMbHiNqjANBgkqhkiG9w0BAQEFAASCAgA4VqNVh9ThCbGjC7wfBpqimrtS
# 0xgbzzVtvLECHqXKg9Ui0HsHRsCEGB8dhFiXSXcp1wgVyy+rnRjJ5h4vJJT5BBHW
# zOxSXEU5i+P0hXlh4MEilTz3wAg1jvR/wEjTbF4eik0iDoXd+FBW0nQzlERcvf2l
# XZq5OiqVAmacVQRdcT7pvuvW3yTTD8rQMU7/HHgUKbTAX4MuOOxo3at2P6q4bWAC
# VVXJaLWzfXL3X1x+u87Hb1WajLt2QcLl0a+Qa6AhmMLZjmaWrZpQ9UrFqy2lU0tT
# orFb5tkbsHureaZpBH3E03jHCKg5CjXVmSszpffotQCGXBXwoNqCkEzVb0YlPfo9
# 5dEJlJAy5kByEgttV6mo95N2QkF8/t7zFM1E0HUqWKzt/264zcDQSP0vk1XXf0ul
# NLv+oySGUUNkRX8xKiHdKqCG/x1EjB+2PJozVS3xYd22pnoTsXyhz645ZoH7vkOs
# uyCK4Tk2+Kt24tobce4melDEN/Edqis+R9npEPziJFBYP7dpXCN+x4yraks7yMq2
# O2AB7YQtzoT59LYlNUAo1FbQSw/p3r0pGbgN4tFL9XceU0WNvMCKrVAvhKWwivvm
# cqJ2wadCmjGUBbpoAmGW+lRRgUugkTyiUHhfmFlF5U5sMRqV8c1m9mPQ6GGEpO/X
# iC5rV0PcD4Q+kfkuxA==
# SIG # End signature block
