#Requires -Version 7.0

<#
.SYNOPSIS
    easyONBOARDING - GUI-basiertes Tool zur Erstellung neuer Benutzer in Active Directory und Microsoft 365.
.DESCRIPTION
    Dieses Skript bietet eine grafische Benutzeroberfläche zur Vereinfachung und Standardisierung des Onboarding-Prozesses.
    Es führt durch verschiedene Schritte, von der Erfassung der Benutzerdaten bis zur Zuweisung von Lizenzen und Gruppen.
.AUTHOR
    Andreas Hepp
.VERSION
    2.0.8
.NOTES
    Stellen Sie sicher, dass die PowerShell-Ausführungsrichtlinie das Ausführen von Skripten erlaubt.
    Das Skript muss in einem Kontext mit den erforderlichen AD- und MS365-Berechtigungen ausgeführt werden.
#>

# --- PREREQUISITE CHECKS ---

# Check for Administrator Privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Add-Type -AssemblyName PresentationFramework
    $result = [System.Windows.MessageBox]::Show(
        "Dieses Skript erfordert Administratorrechte, um ordnungsgemäß zu funktionieren.`n`nMöchten Sie es mit erhöhten Rechten neu starten?",
        "Administratorrechte erforderlich",
        "YesNo",
        "Warning"
    )

    if ($result -eq "Yes") {
        try {
            $scriptPath = $MyInvocation.MyCommand.Definition
            Start-Process pwsh -ArgumentList "-File `"$scriptPath`"" -Verb RunAs -ErrorAction Stop
        }
        catch {
            [System.Windows.MessageBox]::Show("Fehler beim Neustart mit Administratorrechten: $($_.Exception.Message)", "Fehler", "OK", "Error")
        }
        exit # Exit the current non-elevated instance
    }
    else {
        [System.Windows.MessageBox]::Show("Das Skript wird ohne Administratorrechte fortgesetzt. Einige Funktionen sind möglicherweise nicht verfügbar.", "Warnung", "OK", "Warning")
    }
}

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Dieses Skript erfordert PowerShell 7 oder höher.`n`nAktuelle Version: $($PSVersionTable.PSVersion)",
        "Versionsfehler",
        "OK",
        "Error"
    )
    exit
}

# --- SCRIPT ROOT DEFINITION ---
# Using $PSScriptRoot to get the directory where this script is located
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    # Fallback if $PSScriptRoot is not available (older PowerShell versions)
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Log script root for debugging purposes
Write-Output "Script is running from directory: $ScriptRoot"

# --- KONFIGURATION ---
# Diese Werte können nach Bedarf angepasst werden

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-AsAdmin {
    $scriptPath = $MyInvocation.MyCommand.Definition
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "pwsh.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
    $psi.Verb = "runas" # This triggers the UAC prompt
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    }
    catch {
        Write-Warning "Failed to restart as administrator: $($_.Exception.Message)"
        return $false
    }
    return $true
}

# Check for admin privileges
if (-not (Test-Admin)) {
    # If not running as admin, show a dialog to restart with elevated permissions
    Add-Type -AssemblyName PresentationFramework
    $result = [System.Windows.MessageBox]::Show(
        "This script requires administrator privileges to run properly.`n`nDo you want to restart with elevated permissions?",
        "Administrator Rights Required",
        "YesNo",
        "Warning"
    )

    if ($result -eq "Yes") {
        if (Start-AsAdmin) {
            # Exit this instance as we've started a new elevated instance
            exit
        }
    }
    else {
        Write-Warning "The script will continue without administrator privileges. Some functions may not work properly."
    }
}

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "This script requires PowerShell 7 or higher.`n`nCurrent version: $($PSVersionTable.PSVersion)",
        "Version Error",
        "OK",
        "Error"
    )
    exit
}

# Prüfe kritische Module
try {
    if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Das ActiveDirectory PowerShell-Modul ist nicht installiert oder nicht verfügbar.`n`nBitte installieren Sie die 'Remote Server Administration Tools (RSAT)' oder führen Sie das Skript auf einem Domain Controller aus.",
            "Fehlende Abhängigkeit",
            "OK",
            "Error"
        )
        exit 1
    }
}
catch {
    Write-Warning "Fehler beim Prüfen der Module: $($_.Exception.Message)"
}

# Variable entfernt - war unbenutzt
#endregion

#region INI FILE LOADING
function Get-IniContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    # Temporärer Fallback für Logging vor Write-Log verfügbar ist
    $debugOutput = $true # Wird später durch INI-Konfiguration überschrieben

    if ($debugOutput) { Write-Host "Lade Konfigurationsdatei: $Path" -ForegroundColor Cyan }

    # Prüft ob die INI-Datei existiert und zugänglich ist
    if (-not (Test-Path $Path)) {
        $errorMessage = "INI-Datei nicht gefunden: $Path"
        Write-Host $errorMessage -ForegroundColor Red
        Throw $errorMessage
    }

    $ini = [ordered]@{}
    $currentSection = "Global"
    $ini[$currentSection] = [ordered]@{}

    try {
        $lines = Get-Content -Path $Path -Encoding UTF8 -ErrorAction Stop
        if ($debugOutput) { Write-Host "INI-Datei erfolgreich gelesen. Anzahl Zeilen: $($lines.Count)" -ForegroundColor Cyan }
    }
    catch {
        $errorMessage = "Fehler beim Lesen der INI-Datei: $($_.Exception.Message)"
        Write-Host $errorMessage -ForegroundColor Red
        Throw $errorMessage
    }

    # Verarbeitet die INI-Datei zeilenweise um Sektionen und Schlüssel-Wert-Paare zu extrahieren
    $lineNumber = 0
    foreach ($line in $lines) {
        $lineNumber++
        $originalLine = $line
        $line = $line.Trim()

        # Überspringe leere Zeilen und Kommentarzeilen (beginnend mit ; oder #)
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*[;#]') {
            continue
        }

        # Sektion gefunden [SectionName]
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $matches[1].Trim()
            if (-not $ini.Contains($currentSection)) {
                $ini[$currentSection] = [ordered]@{}
            }
        }
        # Schlüssel-Wert-Paar gefunden Key=Value
        elseif ($line -match '^([^=]+?)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Erweiterte Wert-Verarbeitung
            $processedValue = Convert-IniValue -Value $value

            $ini[$currentSection][$key] = $processedValue
        }
        # Ungültige Zeile
        else {
            Write-Host "Ungültige Zeile $lineNumber ignoriert: $originalLine" -ForegroundColor Yellow
        }
    }

    Write-Host "INI-Datei erfolgreich geparst. Anzahl Sektionen: $($ini.Keys.Count)" -ForegroundColor Green
    return $ini
}

function Convert-IniValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    # Entferne Anführungszeichen falls vorhanden
    if ($Value -match '^"(.*)"$' -or $Value -match "^'(.*)'$") {
        $Value = $matches[1]
    }

    # Konvertiere Boolean-Werte
    if ($Value -match '^(true|false)$') {
        return [bool]::Parse($Value)
    }

    # Konvertiere numerische Werte
    if ($Value -match '^\d+$') {
        return [int]$Value
    }

    # Konvertiere Dezimalzahlen
    if ($Value -match '^\d+\.\d+$') {
        return [double]$Value
    }

    # Behandle kommagetrennte Listen
    if ($Value.Contains(',') -and $Value -notmatch '^\s*$') {
        $list = $Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        if ($list.Count -gt 1) {
            return $list
        }
    }

    # Rückgabe als String für alle anderen Fälle
    return $Value
}

function Get-ConfigValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Section,

        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $false)]
        [object]$DefaultValue = $null,

        [Parameter(Mandatory = $false)]
        $Config = $global:Config
    )

    # Verwende Contains() statt Contains() für OrderedDictionary
    if ($Config.Contains($Section) -and $Config[$Section].Contains($Key)) {
        $value = $Config[$Section][$Key]
        return $value  # Wert ist bereits beim Laden der INI-Datei konvertiert worden
    }
    return $DefaultValue
}

function Set-GlobalConfigVariables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Config
    )

    # Prüfe Debug-Einstellung frühzeitig
    $global:DebugMode = Get-ConfigValue -Section "Logging" -Key "Debug" -DefaultValue $false -Config $Config

    if ($global:DebugMode) {
        Write-Host "Setze globale Konfigurationsvariablen..." -ForegroundColor Cyan
    }

    try {
        # General Settings
        $global:CompanyName = Get-ConfigValue -Section "General" -Key "CompanyName" -DefaultValue "Unbekanntes Unternehmen" -Config $Config
        $global:DomainName = Get-ConfigValue -Section "General" -Key "DomainName" -DefaultValue "domain.local" -Config $Config
        $global:DomainMail = Get-ConfigValue -Section "General" -Key "DomainMail" -DefaultValue "domain.com" -Config $Config
        $global:DebugMode = Get-ConfigValue -Section "General" -Key "DebugMode" -DefaultValue $false -Config $Config
        $global:LogLevel = Get-ConfigValue -Section "General" -Key "LogLevel" -DefaultValue 2 -Config $Config
        $global:LogPath = Get-ConfigValue -Section "General" -Key "LogPath" -DefaultValue (Join-Path $ScriptRoot "Logs") -Config $Config
        $global:DefaultOU = Get-ConfigValue -Section "General" -Key "DefaultOU" -DefaultValue "CN=Users,DC=domain,DC=local" -Config $Config

        # Templates Settings
        $global:WelcomeEmailUser = Get-ConfigValue -Section "Templates" -Key "WelcomeEmailUser" -DefaultValue ".\assets\templates\WelcomeEmail_User.html" -Config $Config
        $global:Signature = Get-ConfigValue -Section "Templates" -Key "Signature" -DefaultValue ".\assets\templates\Signature.html" -Config $Config
        $global:InitialCredentialsPDF = Get-ConfigValue -Section "Templates" -Key "InitialCredentialsPDF" -DefaultValue ".\assets\templates\InitialCredentials_Template.html" -Config $Config
        $global:NotifyManagerEmail = Get-ConfigValue -Section "Templates" -Key "NotifyManagerEmail" -DefaultValue ".\assets\templates\NotifyManager_Template.html" -Config $Config
        $global:NotifyHelpdeskEmail = Get-ConfigValue -Section "Templates" -Key "NotifyHelpdeskEmail" -DefaultValue ".\assets\templates\NotifyHelpdesk_Template.html" -Config $Config
        $global:OffboardingInfoEmail = Get-ConfigValue -Section "Templates" -Key "OffboardingInfoEmail" -DefaultValue ".\assets\templates\OffboardingInfo_Template.html" -Config $Config

        # User Creation Settings
        $global:NamingConvention = Get-ConfigValue -Section "UserCreation" -Key "NamingConvention" -DefaultValue 1 -Config $Config
        $global:DefaultPassword = Get-ConfigValue -Section "UserCreation" -Key "DefaultPassword" -DefaultValue "Willkommen2025!" -Config $Config
        $global:ChangePasswordAtNextLogon = Get-ConfigValue -Section "UserCreation" -Key "ChangePasswordAtNextLogon" -DefaultValue $true -Config $Config
        $global:UPNSuffix = Get-ConfigValue -Section "UserCreation" -Key "UPNSuffix" -DefaultValue $global:DomainName -Config $Config
        $global:UPNFormat = Get-ConfigValue -Section "UserCreation" -Key "UPNFormat" -DefaultValue 1 -Config $Config
        $global:ProfilePath = Get-ConfigValue -Section "UserCreation" -Key "ProfilePath" -DefaultValue "\\server\profiles\%username%" -Config $Config
        $global:HomeDirectory = Get-ConfigValue -Section "UserCreation" -Key "HomeDirectory" -DefaultValue "\\server\home\%username%" -Config $Config
        $global:HomeDrive = Get-ConfigValue -Section "UserCreation" -Key "HomeDrive" -DefaultValue "H:" -Config $Config
        $global:LogonScript = Get-ConfigValue -Section "UserCreation" -Key "LogonScript" -DefaultValue "logon.bat" -Config $Config

        # Password Policy Settings
        $global:UsePasswordPolicy = Get-ConfigValue -Section "PasswordPolicy" -Key "UsePolicy" -DefaultValue $false -Config $Config
        $global:PasswordLength = Get-ConfigValue -Section "PasswordPolicy" -Key "PasswordLength" -DefaultValue 14 -Config $Config
        $global:IncludeUppercase = Get-ConfigValue -Section "PasswordPolicy" -Key "IncludeUppercase" -DefaultValue $true -Config $Config
        $global:IncludeLowercase = Get-ConfigValue -Section "PasswordPolicy" -Key "IncludeLowercase" -DefaultValue $true -Config $Config
        $global:IncludeNumbers = Get-ConfigValue -Section "PasswordPolicy" -Key "IncludeNumbers" -DefaultValue $true -Config $Config
        $global:IncludeSpecialChars = Get-ConfigValue -Section "PasswordPolicy" -Key "IncludeSpecialChars" -DefaultValue $true -Config $Config
        $global:SpecialChars = Get-ConfigValue -Section "PasswordPolicy" -Key "SpecialChars" -DefaultValue '!@#$%^&*()' -Config $Config

        # Groups Settings
        $global:DefaultGroups = Get-ConfigValue -Section "Groups" -Key "DefaultGroups" -DefaultValue @() -Config $Config
        if ($global:DefaultGroups -is [string] -and $global:DefaultGroups.Contains(',')) {
            $global:DefaultGroups = $global:DefaultGroups -split ',' | ForEach-Object { $_.Trim() }
        }

        # Exchange Settings
        $global:ExchangeEnvironment = Get-ConfigValue -Section "Exchange" -Key "ExchangeEnvironment" -DefaultValue "Hybrid" -Config $Config
        $global:EmailAddressPolicy = Get-ConfigValue -Section "Exchange" -Key "EmailAddressPolicy" -DefaultValue "SMTP:%firstname%.%lastname%@%DomainMail%" -Config $Config
        $global:EnableOnPremMailbox = Get-ConfigValue -Section "Exchange" -Key "EnableOnPremMailbox" -DefaultValue $false -Config $Config
        $global:EnableRemoteMailbox = Get-ConfigValue -Section "Exchange" -Key "EnableRemoteMailbox" -DefaultValue $true -Config $Config
        $global:ExchangeServer = Get-ConfigValue -Section "Exchange" -Key "ExchangeServer" -DefaultValue $null -Config $Config
        $global:MailboxDatabase = Get-ConfigValue -Section "Exchange" -Key "MailboxDatabase" -DefaultValue $null -Config $Config
        $global:MailboxOU = Get-ConfigValue -Section "Exchange" -Key "MailboxOU" -DefaultValue $null -Config $Config
        $global:EnableOnlineMailbox = Get-ConfigValue -Section "Exchange" -Key "EnableOnlineMailbox" -DefaultValue $true -Config $Config
        $global:EnableArchiving = Get-ConfigValue -Section "Exchange" -Key "EnableArchiving" -DefaultValue $false -Config $Config
        $global:LitigationHoldEnabled = Get-ConfigValue -Section "Exchange" -Key "LitigationHoldEnabled" -DefaultValue $false -Config $Config
        $global:LitigationHoldDurationDays = Get-ConfigValue -Section "Exchange" -Key "LitigationHoldDurationDays" -DefaultValue 3650 -Config $Config

        # ADSync Settings (jetzt unter [Exchange])
        $global:ADSyncGroup = Get-ConfigValue -Section "Exchange" -Key "SyncGroup" -DefaultValue $null -Config $Config
        $global:ADSyncServer = Get-ConfigValue -Section "Exchange" -Key "SyncServer" -DefaultValue $null -Config $Config
        $global:ADSyncServiceAccount = Get-ConfigValue -Section "Exchange" -Key "SyncServiceAccount" -DefaultValue $null -Config $Config
        $global:ADSyncServicePassword = Get-ConfigValue -Section "Exchange" -Key "SyncServicePassword" -DefaultValue $null -Config $Config
        $global:ADSyncEnabled = $null -ne $global:ADSyncServer

        # Microsoft 365 Settings
        $global:M365TenantId = Get-ConfigValue -Section "Microsoft365" -Key "TenantID" -DefaultValue $null -Config $Config
        $global:M365AssignLicense = Get-ConfigValue -Section "Microsoft365" -Key "AssignLicense" -DefaultValue $true -Config $Config
        $global:M365LicenseSKU = Get-ConfigValue -Section "Microsoft365" -Key "LicenseSKU" -DefaultValue $null -Config $Config
        $global:M365DisabledServicePlans = Get-ConfigValue -Section "Microsoft365" -Key "DisabledServicePlans" -DefaultValue @() -Config $Config
        $global:DefaultSharePointGroups = Get-ConfigValue -Section "Microsoft365" -Key "DefaultSharePointGroups" -DefaultValue @() -Config $Config
        $global:DefaultTeams = Get-ConfigValue -Section "Microsoft365" -Key "DefaultTeams" -DefaultValue @() -Config $Config
        $global:EnableTeamsCalling = Get-ConfigValue -Section "Microsoft365" -Key "EnableTeamsCalling" -DefaultValue $false -Config $Config

        # Telephony Settings - erweitert um neue Werte
        $global:StarfaceEnabled = Get-ConfigValue -Section "Telephony" -Key "CreateExtension" -DefaultValue $false -Config $Config
        $global:StarfaceBaseURL = Get-ConfigValue -Section "Telephony" -Key "BaseURL" -DefaultValue $null -Config $Config
        $global:StarfaceUsername = Get-ConfigValue -Section "Telephony" -Key "Username" -DefaultValue $null -Config $Config
        $global:TelephonyExtensionPrefix = Get-ConfigValue -Section "Telephony" -Key "ExtensionPrefix" -DefaultValue "498912345" -Config $Config
        $global:TelephonyExtensionRangeStart = Get-ConfigValue -Section "Telephony" -Key "ExtensionRangeStart" -DefaultValue 100 -Config $Config
        $global:TelephonyExtensionRangeEnd = Get-ConfigValue -Section "Telephony" -Key "ExtensionRangeEnd" -DefaultValue 999 -Config $Config
        $global:TelephonyDefaultVoicemailPin = Get-ConfigValue -Section "Telephony" -Key "DefaultVoicemailPin" -DefaultValue "1234" -Config $Config

        # GUI Settings - neue Sektion
        $global:DefaultTerminalAccess = Get-ConfigValue -Section "GuiSettings" -Key "DefaultTerminalAccess" -DefaultValue $false -Config $Config
        $global:DefaultVPNAccess = Get-ConfigValue -Section "GuiSettings" -Key "DefaultVPNAccess" -DefaultValue $true -Config $Config
        $global:DefaultMS365Sync = Get-ConfigValue -Section "GuiSettings" -Key "DefaultMS365Sync" -DefaultValue $true -Config $Config
        $global:DefaultJiraAccess = Get-ConfigValue -Section "GuiSettings" -Key "DefaultJiraAccess" -DefaultValue $false -Config $Config

        # Access Group Mapping - neue Sektion
        $global:TerminalServerGroup = Get-ConfigValue -Section "AccessGroupMapping" -Key "TerminalServerGroup" -DefaultValue "GRP_Terminalserver_Access" -Config $Config
        $global:VPNAccessGroup = Get-ConfigValue -Section "AccessGroupMapping" -Key "VPNAccessGroup" -DefaultValue "GRP_VPN_Users" -Config $Config
        $global:MS365SyncGroup = Get-ConfigValue -Section "AccessGroupMapping" -Key "MS365SyncGroup" -DefaultValue "GRP_AzureAD_Sync" -Config $Config
        $global:JiraAccessGroup = Get-ConfigValue -Section "AccessGroupMapping" -Key "JiraAccessGroup" -DefaultValue "GRP_Jira_Users" -Config $Config
        $global:ConfluenceAccessGroup = Get-ConfigValue -Section "AccessGroupMapping" -Key "ConfluenceAccessGroup" -DefaultValue "GRP_Confluence_Users" -Config $Config

        # Application Roles - neue Sektion
        $global:JiraDefaultRole = Get-ConfigValue -Section "ApplicationRoles" -Key "JiraDefaultRole" -DefaultValue "jira-software-users" -Config $Config
        $global:ConfluenceDefaultRole = Get-ConfigValue -Section "ApplicationRoles" -Key "ConfluenceDefaultRole" -DefaultValue "confluence-users" -Config $Config

        # Software Settings - neue Sektion
        $global:DefaultSoftware = Get-ConfigValue -Section "Software" -Key "DefaultSoftware" -DefaultValue @() -Config $Config
        if ($global:DefaultSoftware -is [string] -and $global:DefaultSoftware.Contains(',')) {
            $global:DefaultSoftware = $global:DefaultSoftware -split ',' | ForEach-Object { $_.Trim() }
        }

        # Hardware Settings - neue Sektion
        $global:DefaultLaptopModel = Get-ConfigValue -Section "Hardware" -Key "DefaultLaptopModel" -DefaultValue "Laptop Modell XYZ" -Config $Config
        $global:DefaultPhoneModel = Get-ConfigValue -Section "Hardware" -Key "DefaultPhoneModel" -DefaultValue "Smartphone Modell ABC" -Config $Config

        # Notifications Settings - neue Sektion
        $global:NotifyManager = Get-ConfigValue -Section "Notifications" -Key "NotifyManager" -DefaultValue $true -Config $Config
        $global:NotifyITHelpdesk = Get-ConfigValue -Section "Notifications" -Key "NotifyITHelpdesk" -DefaultValue $true -Config $Config
        $global:SMTPServer = Get-ConfigValue -Section "Notifications" -Key "SMTPServer" -DefaultValue "smtp.ihredomain.com" -Config $Config
        $global:SMTPPort = Get-ConfigValue -Section "Notifications" -Key "SMTPPort" -DefaultValue 587 -Config $Config
        $global:SMTPFrom = Get-ConfigValue -Section "Notifications" -Key "SMTPFrom" -DefaultValue "it-noreply@ihredomain.com" -Config $Config
        $global:SMTPTo = Get-ConfigValue -Section "Notifications" -Key "SMTPTo" -DefaultValue "it-helpdesk@ihredomain.com" -Config $Config
        $global:SMTPUseSSL = Get-ConfigValue -Section "Notifications" -Key "SMTPUseSSL" -DefaultValue $true -Config $Config

        # Logging Settings
        $global:LogLevel = Get-ConfigValue -Section "Logging" -Key "LogLevel" -DefaultValue "INFO" -Config $Config
        $global:UseVerboseLogging = Get-ConfigValue -Section "Logging" -Key "UseVerboseLogging" -DefaultValue $false -Config $Config

        if ($global:DebugMode) {
            Write-Host "Globale Konfigurationsvariablen erfolgreich gesetzt:" -ForegroundColor Green
            Write-Host "--- General ---" -ForegroundColor Yellow
            Write-Host "  - CompanyName: $global:CompanyName"
            Write-Host "  - DomainName: $global:DomainName"
            Write-Host "  - DomainMail: $global:DomainMail"
            Write-Host "  - DebugMode: $global:DebugMode"
            Write-Host "  - DefaultOU: $global:DefaultOU"

            Write-Host "--- Templates ---" -ForegroundColor Yellow
            Write-Host "  - WelcomeEmailUser: $global:WelcomeEmailUser"
            Write-Host "  - Signature: $global:Signature"
            Write-Host "  - InitialCredentialsPDF: $global:InitialCredentialsPDF"
            Write-Host "  - NotifyManagerEmail: $global:NotifyManagerEmail"
            Write-Host "  - NotifyHelpdeskEmail: $global:NotifyHelpdeskEmail"
            Write-Host "  - OffboardingInfoEmail: $global:OffboardingInfoEmail"

            Write-Host "--- UserCreation ---" -ForegroundColor Yellow
            Write-Host "  - NamingConvention: $global:NamingConvention"
            Write-Host "  - DefaultPassword: ******** (hidden)"
            Write-Host "  - ChangePasswordAtNextLogon: $global:ChangePasswordAtNextLogon"
            Write-Host "  - UPNSuffix: $global:UPNSuffix"
            Write-Host "  - UPNFormat: $global:UPNFormat"
            Write-Host "  - ProfilePath: $global:ProfilePath"
            Write-Host "  - HomeDirectory: $global:HomeDirectory"
            Write-Host "  - HomeDrive: $global:HomeDrive"
            Write-Host "  - LogonScript: $global:LogonScript"

            Write-Host "--- PasswordPolicy ---" -ForegroundColor Yellow
            Write-Host "  - UsePasswordPolicy: $global:UsePasswordPolicy"
            Write-Host "  - PasswordLength: $global:PasswordLength"
            Write-Host "  - IncludeUppercase: $global:IncludeUppercase"
            Write-Host "  - IncludeLowercase: $global:IncludeLowercase"
            Write-Host "  - IncludeNumbers: $global:IncludeNumbers"
            Write-Host "  - IncludeSpecialChars: $global:IncludeSpecialChars"
            Write-Host "  - SpecialChars: $global:SpecialChars"

            Write-Host "--- Groups ---" -ForegroundColor Yellow
            Write-Host "  - DefaultGroups: $($global:DefaultGroups -join ', ')"

            Write-Host "--- Exchange ---" -ForegroundColor Yellow
            Write-Host "  - ExchangeEnvironment: $global:ExchangeEnvironment"
            Write-Host "  - EmailAddressPolicy: $global:EmailAddressPolicy"
            Write-Host "  - EnableOnPremMailbox: $global:EnableOnPremMailbox"
            Write-Host "  - EnableRemoteMailbox: $global:EnableRemoteMailbox"
            Write-Host "  - ExchangeServer: $global:ExchangeServer"
            Write-Host "  - MailboxDatabase: $global:MailboxDatabase"
            Write-Host "  - MailboxOU: $global:MailboxOU"
            Write-Host "  - EnableOnlineMailbox: $global:EnableOnlineMailbox"
            Write-Host "  - EnableArchiving: $global:EnableArchiving"
            Write-Host "  - LitigationHoldEnabled: $global:LitigationHoldEnabled"
            Write-Host "  - LitigationHoldDurationDays: $global:LitigationHoldDurationDays"
            Write-Host "  - ADSyncGroup: $global:ADSyncGroup"
            Write-Host "  - ADSyncServer: $global:ADSyncServer"
            Write-Host "  - ADSyncServiceAccount: $global:ADSyncServiceAccount"
            Write-Host "  - ADSyncServicePassword: ******** (hidden)"
            Write-Host "  - ADSyncEnabled: $global:ADSyncEnabled"

            Write-Host "--- Microsoft365 ---" -ForegroundColor Yellow
            Write-Host "  - M365TenantId: $global:M365TenantId"
            Write-Host "  - M365AssignLicense: $global:M365AssignLicense"
            Write-Host "  - M365LicenseSKU: $global:M365LicenseSKU"
            Write-Host "  - M365DisabledServicePlans: $($global:M365DisabledServicePlans -join ', ')"
            Write-Host "  - DefaultSharePointGroups: $($global:DefaultSharePointGroups -join ', ')"
            Write-Host "  - DefaultTeams: $($global:DefaultTeams -join ', ')"
            Write-Host "  - EnableTeamsCalling: $global:EnableTeamsCalling"

            Write-Host "--- Telephony ---" -ForegroundColor Yellow
            Write-Host "  - StarfaceEnabled: $global:StarfaceEnabled"
            Write-Host "  - StarfaceBaseURL: $global:StarfaceBaseURL"
            Write-Host "  - StarfaceUsername: $global:StarfaceUsername"
            Write-Host "  - TelephonyExtensionPrefix: $global:TelephonyExtensionPrefix"
            Write-Host "  - TelephonyExtensionRangeStart: $global:TelephonyExtensionRangeStart"
            Write-Host "  - TelephonyExtensionRangeEnd: $global:TelephonyExtensionRangeEnd"
            Write-Host "  - TelephonyDefaultVoicemailPin: $global:TelephonyDefaultVoicemailPin"

            Write-Host "--- GuiSettings ---" -ForegroundColor Yellow
            Write-Host "  - DefaultTerminalAccess: $global:DefaultTerminalAccess"
            Write-Host "  - DefaultVPNAccess: $global:DefaultVPNAccess"
            Write-Host "  - DefaultMS365Sync: $global:DefaultMS365Sync"
            Write-Host "  - DefaultJiraAccess: $global:DefaultJiraAccess"

            Write-Host "--- AccessGroupMapping ---" -ForegroundColor Yellow
            Write-Host "  - TerminalServerGroup: $global:TerminalServerGroup"
            Write-Host "  - VPNAccessGroup: $global:VPNAccessGroup"
            Write-Host "  - MS365SyncGroup: $global:MS365SyncGroup"
            Write-Host "  - JiraAccessGroup: $global:JiraAccessGroup"
            Write-Host "  - ConfluenceAccessGroup: $global:ConfluenceAccessGroup"

            Write-Host "--- ApplicationRoles ---" -ForegroundColor Yellow
            Write-Host "  - JiraDefaultRole: $global:JiraDefaultRole"
            Write-Host "  - ConfluenceDefaultRole: $global:ConfluenceDefaultRole"

            Write-Host "--- Software ---" -ForegroundColor Yellow
            Write-Host "  - DefaultSoftware: $($global:DefaultSoftware -join ', ')"

            Write-Host "--- Hardware ---" -ForegroundColor Yellow
            Write-Host "  - DefaultLaptopModel: $global:DefaultLaptopModel"
            Write-Host "  - DefaultPhoneModel: $global:DefaultPhoneModel"

            Write-Host "--- Notifications ---" -ForegroundColor Yellow
            Write-Host "  - NotifyManager: $global:NotifyManager"
            Write-Host "  - NotifyITHelpdesk: $global:NotifyITHelpdesk"
            Write-Host "  - SMTPServer: $global:SMTPServer"
            Write-Host "  - SMTPPort: $global:SMTPPort"
            Write-Host "  - SMTPFrom: $global:SMTPFrom"
            Write-Host "  - SMTPTo: $global:SMTPTo"
            Write-Host "  - SMTPUseSSL: $global:SMTPUseSSL"

            Write-Host "--- Logging ---" -ForegroundColor Yellow
            Write-Host "  - LogLevel: $global:LogLevel"
            Write-Host "  - UseVerboseLogging: $global:UseVerboseLogging"
            Write-Host "  - LogPath: $global:LogPath"
            Write-Host "======================================" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Fehler beim Setzen der globalen Konfigurationsvariablen: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# INI-Datei laden und globale Variablen setzen
$INIPath = Join-Path $ScriptRoot "assets\onbconfig.ini"
try {
    Write-Host "Lade Konfigurationsdatei von: $INIPath" -ForegroundColor Green
    $global:Config = Get-IniContent -Path $INIPath

    # Setze globale Konfigurationsvariablen für einfachen Zugriff
    Set-GlobalConfigVariables -Config $global:Config

    Write-Host "Konfiguration erfolgreich geladen" -ForegroundColor Green

    # Stelle sicher, dass das Log-Verzeichnis existiert
    if (-not [string]::IsNullOrWhiteSpace($global:LogPath) -and -not (Test-Path $global:LogPath)) {
        try {
            New-Item -Path $global:LogPath -ItemType Directory -Force | Out-Null
            Write-Host "Log-Verzeichnis erstellt: $global:LogPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Fehler beim Erstellen des Log-Verzeichnisses: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}
catch {
    $errorMessage = "Fehler beim Laden der Konfigurationsdatei: $($_.Exception.Message)"
    Write-Host $errorMessage -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show($errorMessage, "Konfigurationsfehler", "OK", "Error")
    exit 1
}
#endregion

#region Logging Functions
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )

    # Fallback-Konfiguration wenn globale Konfiguration nicht verfügbar ist
    $logDirectory = $null
    $debugMode = $false
    $verboseLogging = $false

    try {
        if ($global:Config -and $global:Config.Contains("General") -and $global:Config.General.Contains("LogPath")) {
            $logDirectory = $global:Config.General.LogPath
        }
        elseif ($global:Config -and $global:Config.Contains("Logging") -and $global:Config.Logging.Contains("LogPath")) {
            $logDirectory = $global:Config.Logging.LogPath
        }

        if ($global:Config -and $global:Config.Contains("Logging")) {
            $debugMode = $global:Config.Logging.Contains("Debug") -and $global:Config.Logging.Debug
            $verboseLogging = $global:Config.Logging.Contains("UseVerboseLogging") -and $global:Config.Logging.UseVerboseLogging
        }
    }
    catch {
        # Ignoriere Konfigurationsfehler beim Logging
    }

    # Fallback auf Skript-Verzeichnis wenn kein LogPath konfiguriert
    if ([string]::IsNullOrWhiteSpace($logDirectory)) {
        $logDirectory = if ($ScriptRoot) { Join-Path $ScriptRoot "Logs" } else { Join-Path $PWD "Logs" }
    }

    # Skip DEBUG messages if debug mode is disabled
    if ($Level -eq "DEBUG" -and -not $debugMode) {
        return
    }

    # Ensure the log directory exists
    try {
        if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not (Test-Path -Path $logDirectory)) {
            New-Item -Path $logDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
    }
    catch {
        # Fallback zu Console-Output wenn Log-Verzeichnis nicht erstellt werden kann
        if (-not $NoConsole) {
            Write-Warning "Failed to create log directory '$logDirectory': $($_.Exception.Message)"
        }
        $logDirectory = $null
    }

    # Format the log entry
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Add caller information for non-INFO messages if verbose logging is enabled
    if ($verboseLogging -and $Level -ne "INFO") {
        try {
            $callStack = Get-PSCallStack | Select-Object -Skip 1 | Select-Object -First 1
            $caller = if ($callStack) { "$($callStack.Command) [Line:$($callStack.ScriptLineNumber)]" } else { "Unknown" }
            $logEntry = "$logEntry [Caller: $caller]"
        }
        catch {
            # Ignoriere Fehler beim Abrufen des Call Stacks
        }
    }

    # Write to console with color coding based on level
    if (-not $NoConsole) {
        try {
            switch ($Level) {
                "INFO" { Write-Host $logEntry -ForegroundColor White }
                "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
                "ERROR" { Write-Host $logEntry -ForegroundColor Red }
                "DEBUG" { Write-Host $logEntry -ForegroundColor Cyan }
            }
        }
        catch {
            # Fallback zu Write-Output wenn Write-Host fehlschlägt
            Write-Output $logEntry
        }
    }

    # Write to log file only if directory is available
    if (-not [string]::IsNullOrWhiteSpace($logDirectory)) {
        try {
            # Use daily log files for better log management
            $logDate = Get-Date -Format 'yyyy-MM-dd'
            $LogFile = Join-Path -Path $logDirectory -ChildPath "easyONB_$logDate.log"

            Add-Content -Path $LogFile -Value $logEntry -ErrorAction Stop

            # Log rotation - check file size and archive if needed
            $logFileInfo = Get-Item $LogFile -ErrorAction SilentlyContinue
            $maxSizeMB = 10 # 10MB max file size
            if ($logFileInfo -and $logFileInfo.Length -gt ($maxSizeMB * 1MB)) {
                $archiveFile = Join-Path -Path $logDirectory -ChildPath "easyONB_$logDate`_$((Get-Date).ToString('HHmmss')).log"
                Rename-Item -Path $LogFile -NewName $archiveFile -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            # Nur bei erstem Fehler warnen, um Endlosschleifen zu vermeiden
            if (-not $global:LogWriteErrorShown) {
                $global:LogWriteErrorShown = $true
                if (-not $NoConsole) {
                    Write-Warning "Failed to write to log file: $($_.Exception.Message)"
                }
            }
        }
    }
}

#region ACTIVE DIRECTORY CONNECTION HELPER
# Helper function to test AD connectivity before operations
function Test-ADConnectivity {
    [CmdletBinding()]
    param(
        [switch]$ShowError
    )

    try {
        # Check if a specific AD server is configured
        $adServer = $null
        if ($global:Config -and $global:Config.Contains("ActiveDirectory") -and
            $global:Config.ActiveDirectory.Contains("PreferredDomainController") -and
            -not [string]::IsNullOrWhiteSpace($global:Config.ActiveDirectory.PreferredDomainController)) {
            $adServer = $global:Config.ActiveDirectory.PreferredDomainController
        }

        # Quick test of AD connectivity
        if ($adServer) {
            $null = Get-ADDomain -Server $adServer -ErrorAction Stop
        }
        else {
            $null = Get-ADDomain -ErrorAction Stop
        }
        return $true
    }
    catch {
        if ($ShowError) {
            Write-Log -Message "AD connectivity test failed: $($_.Exception.Message)" -LogLevel "ERROR"
        }
        return $false
    }
}

function Get-ADConnectionStatus {
    [CmdletBinding()]
    param()

    if ($null -eq $global:ADConnectionAvailable) {
        $global:ADConnectionAvailable = Test-ADConnectivity
    }

    return $global:ADConnectionAvailable
}
#endregion

#region ACTIVE DIRECTORY
#region Organizational Units for Dropdown
function Get-ADOrganizationalUnits {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SearchBase = $null,

        [Parameter(Mandatory = $false)]
        [switch]$ExcludeDefaultOUs,

        [Parameter(Mandatory = $false)]
        [string[]]$IncludeDefaultOUs = @("Users", "Computers"),

        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config
    )

    Write-Log -Message "Lade Organizational Units aus Active Directory..." -Level "DEBUG"

    try {
        # Prüfe AD-Verbindung
        if (-not (Get-ADConnectionStatus)) {
            Write-Log -Message "Keine AD-Verbindung verfügbar. Kann OUs nicht laden." -Level "WARN"
            return @()
        }

        # Bestimme SearchBase falls nicht angegeben
        if ([string]::IsNullOrWhiteSpace($SearchBase)) {
            try {
                $adDomain = Get-ADDomain -ErrorAction Stop
                $SearchBase = $adDomain.DistinguishedName
            }
            catch {
                throw "Konnte AD-Domain nicht ermitteln: $($_.Exception.Message)"
            }
        }

        Write-Log -Message "Suche OUs in SearchBase: $SearchBase" -Level "DEBUG"

        # Hole alle OUs aus dem Active Directory
        $allOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $SearchBase -Properties Name, DistinguishedName, Description -ErrorAction Stop

        Write-Log -Message "Gefundene OUs gesamt: $($allOUs.Count)" -Level "DEBUG"

        # Standard-OUs die normalerweise ausgeschlossen werden
        $defaultOUsToExclude = @(
            "Domain Controllers",
            "Microsoft Exchange Security Groups",
            "Builtin",
            "ForeignSecurityPrincipals",
            "Program Data",
            "System",
            "NTDS Quotas",
            "Managed Service Accounts"
        )

        # Filtere OUs basierend auf Parametern
        $filteredOUs = $allOUs | Where-Object {
            $ou = $_
            $ouName = $ou.Name

            # Prüfe ob es sich um eine Standard-OU handelt, die ausgeschlossen werden soll
            $isDefaultExcluded = $defaultOUsToExclude -contains $ouName

            # Prüfe ob es sich um eine explizit einzuschließende Standard-OU handelt
            $isIncludedDefault = $IncludeDefaultOUs -contains $ouName

            if ($ExcludeDefaultOUs) {
                # Schließe Standard-OUs aus, außer sie sind explizit eingeschlossen
                return (-not $isDefaultExcluded) -or $isIncludedDefault
            }
            else {
                # Schließe nur die problematischen Standard-OUs aus
                return -not $isDefaultExcluded
            }
        }

        # Erstelle ein Array mit OU-Objekten für die GUI
        $ouList = @()

        foreach ($ou in $filteredOUs) {
            $ouObject = [PSCustomObject]@{
                Name              = $ou.Name
                DistinguishedName = $ou.DistinguishedName
                Description       = $ou.Description
                DisplayName       = "$($ou.Name) ($($ou.DistinguishedName))"
                Path              = $ou.DistinguishedName
            }
            $ouList += $ouObject
        }

        # Sortiere die Liste alphabetisch nach Name
        $ouList = $ouList | Sort-Object Name

        Write-Log -Message "Gefilterte OUs für GUI: $($ouList.Count)" -Level "INFO"

        return $ouList

    }
    catch {
        $errorMessage = "Fehler beim Laden der Organizational Units: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        return @()
    }
}

function Get-ADOrganizationalUnitsForDropdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludeUsersAndComputers,

        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config
    )

    Write-Log -Message "Lade OUs für Dropdown-Befüllung..." -Level "DEBUG"

    try {
        # Bestimme welche Standard-OUs eingeschlossen werden sollen
        $includeDefaults = @()
        if ($IncludeUsersAndComputers) {
            $includeDefaults = @("Users")
        }

        # Hole gefilterte OUs
        $ous = Get-ADOrganizationalUnits -ExcludeDefaultOUs -IncludeDefaultOUs $includeDefaults -Config $Config

        if ($ous.Count -eq 0) {
            Write-Log -Message "Keine OUs gefunden. Erstelle Fallback-Liste." -Level "WARN"

            # Fallback: Erstelle eine Standard-Liste basierend auf Konfiguration
            $defaultOUs = Get-ConfigValue -Section "ActiveDirectory" -Key "DefaultOUs" -DefaultValue "CN=Users,DC=domain,DC=local" -Config $Config

            if ($defaultOUs -is [string]) {
                $defaultOUs = $defaultOUs -split ','
            }

            $fallbackOUs = @()
            foreach ($ouPath in $defaultOUs) {
                $ouPath = $ouPath.Trim()
                $ouName = if ($ouPath -match 'CN=([^,]+)') { $matches[1] } else { $ouPath }

                $fallbackOUs += [PSCustomObject]@{
                    Name = $ouName
                    Path = $ouPath
                }
            }

            return $fallbackOUs
        }

        # Reduziere OU-Objekte auf nur Name und Path
        $simplifiedOUs = @()
        foreach ($ou in $ous) {
            $simplifiedOUs += [PSCustomObject]@{
                Name = $ou.Name
                Path = $ou.DistinguishedName
            }
        }

        Write-Log -Message "OUs für Dropdown erfolgreich geladen: $($simplifiedOUs.Count) Einträge" -Level "INFO"
        return $simplifiedOUs

    }
    catch {
        Write-Log -Message "Fehler beim Laden der OUs für Dropdown: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Update-OUDropdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$ComboBox,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeUsersAndComputers,

        [Parameter(Mandatory = $false)]
        [string]$SelectedOUPath
    )

    try {
        # Check if the ComboBox object was provided
        if (-not $ComboBox) {
            Write-Log -Message "Update-OUDropdown was called without a valid ComboBox object. The call will be ignored." -Level "WARN"
            return
        }

        Write-Log -Message "Aktualisiere OU-Dropdown..." -Level "DEBUG"

        # Lade die OUs
        $ous = Get-ADOrganizationalUnitsForDropdown -IncludeUsersAndComputers:$IncludeUsersAndComputers

        # ComboBox zurücksetzen
        $ComboBox.ItemsSource = $null
        $ComboBox.Items.Clear()

        if ($ous.Count -eq 0) {
            Write-Log -Message "Keine OUs zum Anzeigen im Dropdown verfügbar." -Level "WARN"

            # Fallback-Eintrag hinzufügen
            $fallbackOU = [PSCustomObject]@{
                Name = "Keine OUs verfügbar"
                Path = ""
            }
            $ComboBox.Items.Add($fallbackOU)
            $ComboBox.SelectedIndex = 0
            return
        }

        # Erstelle vereinfachte Einträge für bessere Darstellung
        $formattedOUs = @()
        foreach ($ou in $ous) {
            $formattedOU = [PSCustomObject]@{
                Name = if ($ou.Name) { $ou.Name } else { "Unbekannt" }
                Path = $ou.DistinguishedName
            }

            $formattedOUs += $formattedOU
        }

        # Sortiere die OUs alphabetisch nach Name
        $sortedOUs = $formattedOUs | Sort-Object Name

        # Füge die formatierten OUs zur ComboBox hinzu
        foreach ($ou in $sortedOUs) {
            $ComboBox.Items.Add($ou)
        }

        # Konfiguriere die ComboBox-Darstellung
        $ComboBox.DisplayMemberPath = "Name"
        $ComboBox.SelectedValuePath = "Path"

        # Setze die Vorauswahl
        $selectedItem = $null
        if (-not [string]::IsNullOrWhiteSpace($SelectedOUPath)) {
            $selectedItem = $sortedOUs | Where-Object { $_.Path -eq $SelectedOUPath } | Select-Object -First 1
        }

        if ($selectedItem) {
            $ComboBox.SelectedItem = $selectedItem
            Write-Log -Message "Vorausgewählte OU '$SelectedOUPath' im Dropdown gesetzt." -Level "DEBUG"
        }
        else {
            $ComboBox.SelectedIndex = 0
            Write-Log -Message "Erste verfügbare OU vorausgewählt: $($sortedOUs[0].Name)" -Level "DEBUG"
        }

        Write-Log -Message "OU-Dropdown erfolgreich mit $($sortedOUs.Count) Einträgen aktualisiert." -Level "INFO"

    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren des OU-Dropdowns: $($_.Exception.Message)" -Level "ERROR"

        # Im Fehlerfall eine Fehlermeldung in der ComboBox anzeigen
        if ($ComboBox) {
            $ComboBox.Items.Clear()
            $errorOU = [PSCustomObject]@{
                Name = "Fehler beim Laden der OUs"
                Path = ""
            }
            $ComboBox.Items.Add($errorOU)
            $ComboBox.SelectedIndex = 0
        }
    }
}

function Update-OUDropdownFromDepartment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$OUComboBox,

        [Parameter(Mandatory = $false)]
        [string]$DepartmentName = $null
    )

    try {
        Write-Log -Message "Aktualisiere OU-Dropdown basierend auf Abteilung: $DepartmentName" -Level "DEBUG"

        # Wenn eine Abteilung ausgewählt ist, versuche die entsprechende OU zu finden
        if (-not [string]::IsNullOrWhiteSpace($DepartmentName)) {
            $departmentConfig = Get-DepartmentConfig -DepartmentName $DepartmentName

            if ($departmentConfig -and -not [string]::IsNullOrWhiteSpace($departmentConfig.OU)) {
                Write-Log -Message "Abteilungs-spezifische OU gefunden: $($departmentConfig.OU)" -Level "DEBUG"
                Update-OUDropdown -ComboBox $OUComboBox -SelectedOUPath $departmentConfig.OU
                return
            }
        }

        # Fallback: Standard-OU aus Konfiguration
        $defaultOU = Get-ConfigValue -Section "ActiveDirectory" -Key "DefaultOU" -DefaultValue $null
        Update-OUDropdown -ComboBox $OUComboBox -SelectedOUPath $defaultOU

    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren des OU-Dropdowns für Abteilung: $($_.Exception.Message)" -Level "ERROR"
        # Fallback zu Standard-Update
        Update-OUDropdown -ComboBox $OUComboBox
    }
}

function Test-OUPathValidity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OUPath
    )

    try {
        if ([string]::IsNullOrWhiteSpace($OUPath)) {
            return $false
        }

        # Prüfe AD-Verbindung
        if (-not (Get-ADConnectionStatus)) {
            Write-Log -Message "Keine AD-Verbindung für OU-Validierung verfügbar" -Level "WARN"
            return $false
        }

        # Versuche die OU zu finden
        $ou = Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction Stop

        if ($ou) {
            Write-Log -Message "OU-Pfad ist gültig: $OUPath" -Level "DEBUG"
            return $true
        }

        return $false

    }
    catch {
        Write-Log -Message "OU-Pfad ungültig: $OUPath - $($_.Exception.Message)" -Level "DEBUG"
        return $false
    }
}
#endregion

#region User Principal Name (UPN) Generation
# Function to generate User Principal Name (UPN)
function New-UserPrincipalName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FirstName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LastName,

        [Parameter(Mandatory = $false)]
        [string]$Domain,

        [Parameter(Mandatory = $false)]
        [ValidateSet("FirstnameLastname", "FirstnameLastnameNumber", "FirstnameMiddleLastname", "FirstnameLastnameInitial")]
        [string]$NamingConvention = "FirstnameLastname",

        [Parameter(Mandatory = $false)]
        [switch]$CheckAvailability
    )

    Write-Log -Message "Generiere UPN für: $FirstName $LastName" -Level "DEBUG"

    try {
        # Normalisiere die Eingaben (Entferne Sonderzeichen, konvertiere zu Kleinbuchstaben)
        $cleanFirstName = ($FirstName -replace '[^a-zA-Z]', '').ToLower()
        $cleanLastName = ($LastName -replace '[^a-zA-Z]', '').ToLower()

        if ([string]::IsNullOrWhiteSpace($cleanFirstName) -or [string]::IsNullOrWhiteSpace($cleanLastName)) {
            throw "Vorname und Nachname müssen gültige Buchstaben enthalten."
        }

        # Bestimme die Domain aus der Konfiguration falls nicht angegeben
        if ([string]::IsNullOrWhiteSpace($Domain)) {
            $Domain = Get-ConfigValue -Section "ActiveDirectory" -Key "DefaultUPNSuffix" -DefaultValue $null

            if ([string]::IsNullOrWhiteSpace($Domain)) {
                # Fallback: Verwende die General Domain-Konfiguration
                $Domain = Get-ConfigValue -Section "General" -Key "DomainName" -DefaultValue $null
            }

            if ([string]::IsNullOrWhiteSpace($Domain)) {
                # Letzter Fallback: Verwende die AD-Domain
                try {
                    $adDomain = Get-ADDomain -ErrorAction Stop
                    $Domain = $adDomain.DNSRoot
                }
                catch {
                    Write-Log -Message "Konnte AD-Domain nicht ermitteln: $($_.Exception.Message)" -Level "WARN"
                    throw "Domain muss angegeben werden oder in der Konfiguration verfügbar sein."
                }
            }
        }

        # Hole die Standard-Namenskonvention aus der Konfiguration falls nicht explizit angegeben
        if ($NamingConvention -eq "FirstnameLastname" -and $PSBoundParameters.Contains('NamingConvention') -eq $false) {
            $configNamingConvention = Get-ConfigValue -Section "ActiveDirectory" -Key "UPNNamingConvention" -DefaultValue "FirstnameLastname"
            $NamingConvention = $configNamingConvention
        }

        # Generiere den UPN basierend auf der Namenskonvention
        $baseUPN = switch ($NamingConvention) {
            "FirstnameLastname" {
                "$cleanFirstName.$cleanLastName"
            }
            "FirstnameLastnameNumber" {
                "$cleanFirstName.$cleanLastName"
            }
            "FirstnameMiddleLastname" {
                # Für diese Konvention wird der mittlere Buchstabe des Vornamens verwendet
                $middleInitial = if ($cleanFirstName.Length -gt 1) { $cleanFirstName[1] } else { "" }
                "$cleanFirstName$middleInitial.$cleanLastName"
            }
            "FirstnameLastnameInitial" {
                # Verwendet nur den ersten Buchstaben des Nachnamens
                "$cleanFirstName.$($cleanLastName[0])"
            }
            default {
                "$cleanFirstName.$cleanLastName"
            }
        }

        $proposedUPN = "$baseUPN@$Domain"

        Write-Log -Message "Basis-UPN generiert: $proposedUPN (Konvention: $NamingConvention)" -Level "DEBUG"

        # Prüfe Verfügbarkeit wenn gewünscht
        if ($CheckAvailability) {
            $finalUPN = Test-UPNAvailability -BaseUPN $baseUPN -Domain $Domain -NamingConvention $NamingConvention
        }
        else {
            $finalUPN = $proposedUPN
        }

        Write-Log -Message "Finaler UPN: $finalUPN" -Level "INFO"
        return $finalUPN

    }
    catch {
        Write-Log -Message "Fehler bei UPN-Generierung: $($_.Exception.Message)" -Level "ERROR"
        throw $_
    }
}

# Function to test UPN availability and generate alternatives if needed
function Test-UPNAvailability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUPN,

        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [Parameter(Mandatory = $false)]
        [int]$NamingConvention = 1
    )

    Write-Log -Message "Prüfe UPN-Verfügbarkeit für: $BaseUPN@$Domain" -Level "DEBUG"

    try {
        # Prüfe Active Directory-Verbindung
        if (-not (Get-ADConnectionStatus)) {
            Write-Log -Message "Keine AD-Verbindung verfügbar. UPN-Verfügbarkeit kann nicht geprüft werden." -Level "WARN"
            return "$BaseUPN@$Domain"
        }

        $counter = 1
        $maxAttempts = 99
        $currentUPN = "$BaseUPN@$Domain"

        while ($counter -le $maxAttempts) {
            try {
                # Prüfe ob UPN bereits existiert
                $existingUser = Get-ADUser -Filter "UserPrincipalName -eq '$currentUPN'" -ErrorAction Stop

                if ($null -eq $existingUser) {
                    Write-Log -Message "UPN '$currentUPN' ist verfügbar." -Level "DEBUG"
                    return $currentUPN
                }
                else {
                    Write-Log -Message "UPN '$currentUPN' bereits vergeben an: $($existingUser.SamAccountName)" -Level "DEBUG"

                    # Generiere alternative UPN basierend auf NamingConvention
                    $currentUPN = "$BaseUPN$counter@$Domain"
                    $counter++
                }
            }
            catch {
                Write-Log -Message "Fehler bei UPN-Prüfung: $($_.Exception.Message)" -Level "ERROR"
                # Bei Fehlern gebe ursprünglichen UPN zurück
                return "$BaseUPN@$Domain"
            }
        }

        Write-Log -Message "Maximale Anzahl von Versuchen ($maxAttempts) erreicht. Verwende ursprünglichen UPN." -Level "WARN"
        return "$BaseUPN@$Domain"

    }
    catch {
        Write-Log -Message "Fehler bei UPN-Verfügbarkeits-Prüfung: $($_.Exception.Message)" -Level "ERROR"
        return "$BaseUPN@$Domain"
    }
}

# Function to validate UPN format
function Test-UPNFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UPN
    )

    # UPN-Format-Regex: lokaler_teil@domain
    $upnRegex = '^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

    if ($UPN -match $upnRegex) {
        Write-Log -Message "UPN-Format ist gültig: $UPN" -Level "DEBUG"
        return $true
    }
    else {
        Write-Log -Message "UPN-Format ist ungültig: $UPN" -Level "WARN"
        return $false
    }
}

# Function to get UPN suggestions based on name
function Get-UPNSuggestions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstName,

        [Parameter(Mandatory = $true)]
        [string]$LastName,

        [Parameter(Mandatory = $false)]
        [string]$Domain,

        [Parameter(Mandatory = $false)]
        [int]$MaxSuggestions = 5
    )

    Write-Log -Message "Generiere UPN-Vorschläge für: $FirstName $LastName" -Level "DEBUG"

    $suggestions = @()

    # Hole UPN-Format aus der Konfiguration
    $upnFormat = Get-ConfigValue -Section "UserCreation" -Key "UPNFormat" -DefaultValue 1

    # Verwende die Konfiguration für UPNSuffix falls verfügbar
    if ([string]::IsNullOrWhiteSpace($Domain)) {
        $Domain = Get-ConfigValue -Section "UserCreation" -Key "UPNSuffix" -DefaultValue $null
        if ([string]::IsNullOrWhiteSpace($Domain)) {
            $Domain = Get-ConfigValue -Section "General" -Key "DomainName" -DefaultValue "domain.local"
        }
    }

    # Generiere verschiedene UPN-Varianten basierend auf dem konfigurierten Format
    try {
        switch ($upnFormat) {
            1 {
                # vorname.nachname@domain.com
                $suggestions += "$($FirstName.ToLower()).$($LastName.ToLower())@$Domain"
            }
            2 {
                # v.nachname@domain.com
                $suggestions += "$($FirstName[0].ToString().ToLower()).$($LastName.ToLower())@$Domain"
            }
            3 {
                # vornamenachname@domain.com
                $suggestions += "$($FirstName.ToLower())$($LastName.ToLower())@$Domain"
            }
            default {
                # Standard: vorname.nachname@domain.com
                $suggestions += "$($FirstName.ToLower()).$($LastName.ToLower())@$Domain"
            }
        }
        # Basis-UPN generieren
        $baseUpn = New-UserPrincipalName -FirstName $FirstName -LastName $LastName -Domain $Domain -CheckAvailability
        if ($baseUpn -and $suggestions -notcontains $baseUpn) {
            $suggestions += $baseUpn
        }

        # Zusätzliche Varianten für verschiedene Formate
        $conventions = @(1, 2, 3, 4)
        foreach ($convention in $conventions) {
            if ($suggestions.Count -ge $MaxSuggestions) {
                break
            }

            try {
                # Temporär den UPNFormat überschreiben für Varianten
                $originalFormat = Get-ConfigValue -Section "UserCreation" -Key "UPNFormat" -DefaultValue 1
                $global:Config.UserCreation.UPNFormat = $convention

                $upn = New-UserPrincipalName -FirstName $FirstName -LastName $LastName -Domain $Domain -CheckAvailability

                # Format zurücksetzen
                $global:Config.UserCreation.UPNFormat = $originalFormat

                if ($upn -and $suggestions -notcontains $upn) {
                    $suggestions += $upn
                }
            }
            catch {
                Write-Log -Message "Fehler bei UPN-Vorschlag mit Format '$convention': $($_.Exception.Message)" -Level "DEBUG"
            }
        }

    }
    catch {
        Write-Log -Message "Fehler bei der UPN-Vorschlagsgenerierung: $($_.Exception.Message)" -Level "ERROR"
    }

    Write-Log -Message "Generiert $($suggestions.Count) UPN-Vorschläge" -Level "DEBUG"
    return $suggestions
}
#endregion

#region Password Generation
function New-SecurePassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config,

        [Parameter(Mandatory = $false)]
        [int]$LengthOverride,

        [Parameter(Mandatory = $false)]
        [switch]$ExcludeAmbiguousChars
    )

    try {
        # Lade Passwortrichtlinie aus der Konfiguration
        $usePolicy = Get-ConfigValue -Section "PasswordPolicy" -Key "UsePolicy" -DefaultValue $true -Config $Config

        if ($usePolicy) {
            $length = Get-ConfigValue -Section "PasswordPolicy" -Key "PasswordLength" -DefaultValue 14 -Config $Config
            $includeUpper = Get-ConfigValue -Section "PasswordPolicy" -Key "IncludeUppercase" -DefaultValue $true -Config $Config
            $includeLower = Get-ConfigValue -Section "PasswordPolicy" -Key "IncludeLowercase" -DefaultValue $true -Config $Config
            $includeNumbers = Get-ConfigValue -Section "PasswordPolicy" -Key "IncludeNumbers" -DefaultValue $true -Config $Config
            $includeSpecial = Get-ConfigValue -Section "PasswordPolicy" -Key "IncludeSpecialChars" -DefaultValue $true -Config $Config
            $specialCharsSet = Get-ConfigValue -Section "PasswordPolicy" -Key "SpecialChars" -DefaultValue '!@#$%^&*()' -Config $Config
        }
        else {
            # Fallback auf Standardwerte, wenn die Richtlinie deaktiviert ist
            $length = 12
            $includeUpper = $true
            $includeLower = $true
            $includeNumbers = $true
            $includeSpecial = $true
            $specialCharsSet = '!@#$%^&*'
        }

        # Überschreibe Länge, wenn explizit angegeben
        if ($PSBoundParameters.ContainsKey('LengthOverride')) {
            $length = $LengthOverride
        }

        # Definiere Zeichen-Sets
        $charUpper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        $charLower = "abcdefghijklmnopqrstuvwxyz"
        $charNumbers = "0123456789"

        # Entferne mehrdeutige Zeichen, falls gewünscht
        if ($ExcludeAmbiguousChars) {
            $charUpper = $charUpper -replace '[O0I1]'
            $charLower = $charLower -replace '[lo]'
            $charNumbers = $charNumbers -replace '[01]'
            $specialCharsSet = $specialCharsSet -replace '[|!l]'
        }

        $passwordChars = New-Object System.Collections.Generic.List[char]
        $fullCharset = ""

        # Stelle sicher, dass jede geforderte Zeichenart mindestens einmal vorkommt
        if ($includeUpper) {
            $passwordChars.Add(($charUpper.ToCharArray() | Get-Random))
            $fullCharset += $charUpper
        }
        if ($includeLower) {
            $passwordChars.Add(($charLower.ToCharArray() | Get-Random))
            $fullCharset += $charLower
        }
        if ($includeNumbers) {
            $passwordChars.Add(($charNumbers.ToCharArray() | Get-Random))
            $fullCharset += $charNumbers
        }
        if ($includeSpecial -and -not [string]::IsNullOrEmpty($specialCharsSet)) {
            $passwordChars.Add(($specialCharsSet.ToCharArray() | Get-Random))
            $fullCharset += $specialCharsSet
        }

        # Prüfe, ob überhaupt Zeichen ausgewählt wurden
        if ([string]::IsNullOrEmpty($fullCharset)) {
            throw "Keine Zeichenkategorien für die Passwortgenerierung ausgewählt."
        }

        # Fülle das Passwort auf die gewünschte Länge mit zufälligen Zeichen aus dem gesamten Set
        $remainingLength = $length - $passwordChars.Count
        if ($remainingLength -gt 0) {
            $randomChars = -join ($fullCharset.ToCharArray() | Get-Random -Count $remainingLength)
            $passwordChars.AddRange($randomChars.ToCharArray())
        }

        # Mische alle Zeichen im Passwort für eine bessere Zufälligkeit
        $finalPassword = -join ($passwordChars | Get-Random -Count $passwordChars.Count)

        Write-Log -Message "Sicheres Passwort generiert (Länge: $($finalPassword.Length))" -Level "DEBUG"
        return $finalPassword
    }
    catch {
        Write-Log -Message "Fehler beim Generieren des Passworts: $($_.Exception.Message)" -Level "ERROR"
        # Sicherer Fallback
        return "Willkommen2025!"
    }
}
#endregion

#region AD User Creation
function New-ADUserAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject]$UserData,

        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config
    )

    Write-Log -Message "Starte AD-Benutzeranlage für: $($UserData.FirstName) $($UserData.LastName)" -Level "INFO"

    try {
        # 1) Generiere SAM Account Name basierend auf NamingConvention aus Config
        $namingConvention = Get-ConfigValue -Section "UserCreation" -Key "NamingConvention" -DefaultValue 1 -Config $Config
        $samAccountName = New-SamAccountName -FirstName $UserData.FirstName -LastName $UserData.LastName -NamingConvention $namingConvention

        # 2) Generiere UPN basierend auf UPNFormat aus Config
        $upnFormat = Get-ConfigValue -Section "UserCreation" -Key "UPNFormat" -DefaultValue 1 -Config $Config
        $upnSuffix = Get-ConfigValue -Section "UserCreation" -Key "UPNSuffix" -DefaultValue $null -Config $Config
        if ([string]::IsNullOrWhiteSpace($upnSuffix)) {
            $upnSuffix = Get-ConfigValue -Section "General" -Key "DomainName" -DefaultValue "domain.local" -Config $Config
        }
        $userPrincipalName = New-UserPrincipalName -FirstName $UserData.FirstName -LastName $UserData.LastName -Domain $upnSuffix -NamingConvention $upnFormat -CheckAvailability

        Write-Log -Message "Generierte SAM: $samAccountName, UPN: $userPrincipalName" -Level "DEBUG"

        # 3) Prüfe ob Benutzer bereits existiert
        if (Get-ADConnectionStatus) {
            try {
                $existingUser = Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction Stop
                if ($existingUser) {
                    Write-Log -Message "Benutzer $samAccountName existiert bereits" -Level "ERROR"
                    return @{
                        Success        = $false
                        Message        = "Benutzer $samAccountName existiert bereits."
                        SamAccountName = $samAccountName
                    }
                }
            }
            catch {
                # Benutzer existiert nicht - das ist gut
            }
        }
        else {
            Write-Log -Message "Keine AD-Verbindung verfügbar - kann Verfügbarkeit nicht prüfen" -Level "WARN"
        }

        # 4) Bestimme OU-Pfad - aus UserData oder abteilungsspezifisch oder Default
        $ouPath = $UserData.OUPath
        if ([string]::IsNullOrWhiteSpace($ouPath)) {
            # Versuche abteilungsspezifische OU zu finden
            if (-not [string]::IsNullOrWhiteSpace($UserData.Department)) {
                $deptSection = "Department_$($UserData.Department)"
                $ouPath = Get-ConfigValue -Section $deptSection -Key "OU" -DefaultValue $null -Config $Config
            }

            # Fallback auf Default OU
            if ([string]::IsNullOrWhiteSpace($ouPath)) {
                $ouPath = Get-ConfigValue -Section "General" -Key "DefaultOU" -DefaultValue "CN=Users,DC=domain,DC=local" -Config $Config
            }
        }

        # 5) Passwort generieren oder verwenden
        $password = $UserData.Password
        if ([string]::IsNullOrWhiteSpace($password)) {
            # Passwort nach Richtlinie generieren
            $password = New-SecurePassword -Config $Config
        }

        # 6) DisplayName generieren
        $displayName = "$($UserData.FirstName) $($UserData.LastName)"
        if (-not [string]::IsNullOrWhiteSpace($UserData.DisplayName)) {
            $displayName = $UserData.DisplayName
        }

        # 7) E-Mail-Adresse generieren falls EmailAddressPolicyEnabled = false
        $emailAddress = $null
        $emailPolicyEnabled = Get-ConfigValue -Section "Exchange" -Key "EmailAddressPolicyEnabled" -DefaultValue $true -Config $Config
        if (-not $emailPolicyEnabled) {
            $emailAddress = "$samAccountName@$upnSuffix"
        }

        # 8) Sammle AD-Benutzerparameter
        $adUserParams = @{
            SamAccountName    = $samAccountName
            UserPrincipalName = $userPrincipalName
            Name              = $displayName
            DisplayName       = $displayName
            GivenName         = $UserData.FirstName
            Surname           = $UserData.LastName
            Path              = $ouPath
            AccountPassword   = (ConvertTo-SecureString -String $password -AsPlainText -Force)
            Enabled           = $true
        }

        # Füge optionale Attribute hinzu wenn vorhanden
        if (-not [string]::IsNullOrWhiteSpace($UserData.Description)) {
            $adUserParams.Description = $UserData.Description
        }

        if (-not [string]::IsNullOrWhiteSpace($UserData.Position)) {
            $adUserParams.Title = $UserData.Position
        }

        if (-not [string]::IsNullOrWhiteSpace($UserData.Department)) {
            $adUserParams.Department = $UserData.Department
        }

        if (-not [string]::IsNullOrWhiteSpace($UserData.Phone)) {
            $adUserParams.OfficePhone = $UserData.Phone
        }

        if (-not [string]::IsNullOrWhiteSpace($UserData.Mobile)) {
            $adUserParams.MobilePhone = $UserData.Mobile
        }

        if (-not [string]::IsNullOrWhiteSpace($UserData.Office)) {
            $adUserParams.Office = $UserData.Office
        }

        if (-not [string]::IsNullOrWhiteSpace($UserData.Location)) {
            $adUserParams.City = $UserData.Location
        }

        if ($emailAddress) {
            $adUserParams.EmailAddress = $emailAddress
        }

        # Profilpfad und Home-Verzeichnis aus Config
        $profilePath = Get-ConfigValue -Section "UserCreation" -Key "ProfilePath" -DefaultValue $null -Config $Config
        if ($profilePath) {
            $profilePath = $profilePath -replace "%username%", $samAccountName
            $adUserParams.ProfilePath = $profilePath
        }

        $homeDirectory = Get-ConfigValue -Section "UserCreation" -Key "HomeDirectory" -DefaultValue $null -Config $Config
        if ($homeDirectory) {
            $homeDirectory = $homeDirectory -replace "%username%", $samAccountName
            $adUserParams.HomeDirectory = $homeDirectory

            $homeDrive = Get-ConfigValue -Section "UserCreation" -Key "HomeDrive" -DefaultValue $null -Config $Config
            if ($homeDrive) {
                $adUserParams.HomeDrive = $homeDrive
            }
        }

        $logonScript = Get-ConfigValue -Section "UserCreation" -Key "LogonScript" -DefaultValue $null -Config $Config
        if ($logonScript) {
            $adUserParams.ScriptPath = $logonScript
        }

        # Weitere Attribute aus CustomAttributes Section
        $otherAttributes = @{}
        $customAttribSection = "CustomAttributes"
        if ($Config.Contains($customAttribSection)) {
            foreach ($key in $Config[$customAttribSection].Keys) {
                $value = $Config[$customAttribSection][$key]
                # Ersetze Platzhalter
                $value = $value -replace "%username%", $samAccountName
                $value = $value -replace "%firstname%", $UserData.FirstName
                $value = $value -replace "%lastname%", $UserData.LastName
                $value = $value -replace "%department%", $UserData.Department
                $value = $value -replace "%random%", (Get-Random -Minimum 1000 -Maximum 9999)

                $otherAttributes[$key] = $value
            }
        }

        if ($otherAttributes.Count -gt 0) {
            $adUserParams["OtherAttributes"] = $otherAttributes
        }

        # 9) Erstelle den Benutzer
        Write-Log -Message "Erstelle AD-Benutzer: $samAccountName in OU: $ouPath" -Level "INFO"

        if (Get-ADConnectionStatus) {
            try {
                $newUser = New-ADUser @adUserParams -PassThru -ErrorAction Stop
                Write-Log -Message "AD-Benutzer $samAccountName erfolgreich erstellt mit GUID: $($newUser.ObjectGUID)" -Level "INFO"
            }
            catch {
                Write-Log -Message "Fehler beim Erstellen des AD-Benutzers: $($_.Exception.Message)" -Level "ERROR"
                throw "Fehler beim Erstellen des AD-Benutzers: $($_.Exception.Message)"
            }
        }
        else {
            Write-Log -Message "Simulation: AD-Benutzer würde erstellt werden (keine AD-Verbindung)" -Level "WARN"
            $newUser = @{ SamAccountName = $samAccountName; UserPrincipalName = $userPrincipalName; ObjectGUID = [System.Guid]::NewGuid() }
        }

        # 10) Setze Manager falls angegeben
        if (-not [string]::IsNullOrWhiteSpace($UserData.Manager) -and (Get-ADConnectionStatus)) {
            try {
                $manager = Get-ADUser -Filter "SamAccountName -eq '$($UserData.Manager)' -or DisplayName -eq '$($UserData.Manager)'" -ErrorAction Stop
                if ($manager) {
                    Set-ADUser -Identity $samAccountName -Manager $manager -ErrorAction Stop
                    Write-Log -Message "Manager '$($manager.DisplayName)' für $samAccountName gesetzt" -Level "INFO"
                }
                else {
                    Write-Log -Message "Manager '$($UserData.Manager)' nicht gefunden" -Level "WARN"
                }
            }
            catch {
                Write-Log -Message "Fehler beim Setzen des Managers: $($_.Exception.Message)" -Level "WARN"
            }
        }

        # 11) Konto-Optionen anwenden
        if (Get-ADConnectionStatus) {
            $changePasswordAtLogon = Get-ConfigValue -Section "UserCreation" -Key "ChangePasswordAtNextLogon" -DefaultValue $true -Config $Config
            if ($null -ne $UserData.MustChangePassword) {
                $changePasswordAtLogon = $UserData.MustChangePassword
            }

            if ($changePasswordAtLogon) {
                try {
                    Set-ADUser -Identity $samAccountName -ChangePasswordAtLogon $true -ErrorAction Stop
                    Write-Log -Message "Passwort-Änderung bei nächster Anmeldung aktiviert für $samAccountName" -Level "DEBUG"
                }
                catch {
                    Write-Log -Message "Fehler beim Setzen der Passwort-Änderung: $($_.Exception.Message)" -Level "WARN"
                }
            }

            # Weitere Konto-Optionen aus UserData
            if ($UserData.PasswordNeverExpires) {
                try {
                    Set-ADUser -Identity $samAccountName -PasswordNeverExpires $true -ErrorAction Stop
                }
                catch {
                    Write-Log -Message "Fehler beim Setzen 'Passwort läuft nie ab': $($_.Exception.Message)" -Level "WARN"
                }
            }

            if ($UserData.CannotChangePassword) {
                try {
                    Set-ADUser -Identity $samAccountName -CannotChangePassword $true -ErrorAction Stop
                }
                catch {
                    Write-Log -Message "Fehler beim Setzen 'Kann Passwort nicht ändern': $($_.Exception.Message)" -Level "WARN"
                }
            }

            if ($UserData.AccountDisabled) {
                try {
                    Set-ADUser -Identity $samAccountName -Enabled $false -ErrorAction Stop
                }
                catch {
                    Write-Log -Message "Fehler beim Deaktivieren des Kontos: $($_.Exception.Message)" -Level "WARN"
                }
            }
        }

        # Nach der Benutzererstellung (nach New-ADUser)
        $groups = $null
        if ($UserData.Groups -and $UserData.Groups.Count -gt 0) {
            $groups = $UserData.Groups
        } elseif ($UserData.SelectedGroups -and $UserData.SelectedGroups.Count -gt 0) {
            $groups = $UserData.SelectedGroups
        }

        if ($groups -and $groups.Count -gt 0 -and (Get-ADConnectionStatus)) {
            foreach ($group in $groups) {
                try {
                    Add-ADGroupMember -Identity $group -Members $samAccountName -ErrorAction Stop
                    Write-Log -Message "Benutzer $samAccountName zur Gruppe $group hinzugefügt" -Level "INFO"
                }
                catch {
                    Write-Log -Message "Fehler beim Hinzufügen zur Gruppe $group`: $($_.Exception.Message)" -Level "WARN"
                }
            }
        }

        # 12) Erfolgreiche Rückgabe
        Write-Log -Message "Benutzeranlage für $samAccountName erfolgreich abgeschlossen" -Level "INFO"
        return @{
            Success           = $true
            Message           = "Benutzer wurde erfolgreich erstellt."
            SamAccountName    = $samAccountName
            UserPrincipalName = $userPrincipalName
            Password          = $password
            DisplayName       = $displayName
            EmailAddress      = $emailAddress
        }

    }
    catch {
        $errorMessage = "Fehler bei der Benutzeranlage: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        return @{
            Success        = $false
            Message        = $errorMessage
            SamAccountName = $samAccountName
        }
    }
}

function New-SamAccountName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstName,

        [Parameter(Mandatory = $true)]
        [string]$LastName,

        [Parameter(Mandatory = $false)]
        [int]$NamingConvention = 1
    )

    # Normalisiere Namen (entferne Sonderzeichen, konvertiere zu Kleinbuchstaben)
    $cleanFirstName = ($FirstName -replace '[^a-zA-Z]', '').ToLower()
    $cleanLastName = ($LastName -replace '[^a-zA-Z]', '').ToLower()

    # Stelle sicher, dass Namen nicht leer sind
    if ([string]::IsNullOrEmpty($cleanFirstName)) { $cleanFirstName = "user" }
    if ([string]::IsNullOrEmpty($cleanLastName)) { $cleanLastName = "unknown" }

    $samAccountName = switch ($NamingConvention) {
        1 { "$cleanFirstName.$cleanLastName" }    # Vorname.Nachname
        2 { "$($cleanFirstName[0]).$cleanLastName" }  # V.Nachname
        3 { "$cleanLastName$($cleanFirstName[0])" }   # NachnameV
        default { "$cleanFirstName.$cleanLastName" }
    }

    # Beschränke auf 20 Zeichen (SAM Account Name Limit)
    if ($samAccountName.Length -gt 20) {
        $samAccountName = $samAccountName.Substring(0, 20)
    }

    Write-Log -Message "Generierter SAM Account Name: $samAccountName (Konvention: $NamingConvention)" -Level "DEBUG"
    return $samAccountName
}

function Test-SamAccountNameAvailability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseSamAccountName
    )

    try {
        Write-Log -Message "Prüfe SAM Account Name Verfügbarkeit: $BaseSamAccountName" -Level "DEBUG"

        # Prüfe Active Directory-Verbindung
        if (-not (Get-ADConnectionStatus)) {
            Write-Log -Message "Keine AD-Verbindung verfügbar - kann SAM Account Name nicht prüfen" -Level "WARN"
            return $BaseSamAccountName
        }

        $counter = 1
        $maxAttempts = 99
        $currentSamAccountName = $BaseSamAccountName

        while ($counter -le $maxAttempts) {
            try {
                # Prüfe ob SAM Account Name bereits existiert
                $existingUser = Get-ADUser -Filter "SamAccountName -eq '$currentSamAccountName'" -ErrorAction Stop
                if (-not $existingUser) {
                    Write-Log -Message "SAM Account Name '$currentSamAccountName' ist verfügbar" -Level "DEBUG"
                    return $currentSamAccountName
                }

                Write-Log -Message "SAM Account Name '$currentSamAccountName' bereits vergeben, versuche nächste Variante" -Level "DEBUG"
                $currentSamAccountName = "$BaseSamAccountName$counter"

                # Beschränke auf 20 Zeichen
                if ($currentSamAccountName.Length -gt 20) {
                    $currentSamAccountName = $currentSamAccountName.Substring(0, 20)
                }

                $counter++
            }
            catch {
                Write-Log -Message "Fehler bei SAM Account Name Prüfung: $($_.Exception.Message)" -Level "WARN"
                return $BaseSamAccountName
            }
        }

        Write-Log -Message "Maximale Anzahl von Versuchen ($maxAttempts) erreicht. Verwende ursprünglichen SAM Account Name." -Level "WARN"
        return $BaseSamAccountName

    }
    catch {
        Write-Log -Message "Fehler bei SAM Account Name-Verfügbarkeits-Prüfung: $($_.Exception.Message)" -Level "ERROR"
        return $BaseSamAccountName
    }
}
#endregion

#region Import-Departments
function Import-Departments {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Lade Abteilungskonfigurationen aus INI..." -Level "DEBUG"

        if ($null -eq $global:Config) {
            throw "Globale Konfiguration ist nicht geladen."
        }

        # Finde alle Abteilungssektionen in der Konfiguration
        $departmentSections = $global:Config.Keys | Where-Object { $_ -match '^Department_' }

        if ($departmentSections.Count -eq 0) {
            Write-Log -Message "Keine Abteilungssektionen in der Konfiguration gefunden." -Level "WARN"
            return @{}
        }

        Write-Log -Message "Gefundene Abteilungen: $($departmentSections.Count)" -Level "DEBUG"

        # Erstelle eine Sammlung für die Abteilungsdaten
        $departmentData = @{}

        foreach ($sectionName in $departmentSections) {
            try {
                # Extrahiere den Abteilungsnamen aus dem Sektionsnamen (entferne "Department_")
                $departmentName = $sectionName -replace '^Department_', ''

                Write-Log -Message "Verarbeite Abteilung: $departmentName" -Level "DEBUG"

                # Lade alle Konfigurationswerte für diese Abteilung
                $departmentConfig = @{
                    Name            = $departmentName
                    SectionName     = $sectionName
                    OU              = Get-ConfigValue -Section $sectionName -Key "OU" -DefaultValue $null
                    Groups          = Get-ConfigValue -Section $sectionName -Key "Groups" -DefaultValue @()
                    LicenseSKU      = Get-ConfigValue -Section $sectionName -Key "LicenseSKU" -DefaultValue $null
                    Software        = Get-ConfigValue -Section $sectionName -Key "Software" -DefaultValue @()
                    SharePointSites = Get-ConfigValue -Section $sectionName -Key "SharePointSites" -DefaultValue @()
                    Teams           = Get-ConfigValue -Section $sectionName -Key "Teams" -DefaultValue @()
                }

                # Konvertiere Komma-getrennte Strings in Arrays falls nötig
                if ($departmentConfig.Groups -is [string] -and $departmentConfig.Groups.Contains(',')) {
                    $departmentConfig.Groups = $departmentConfig.Groups -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                }

                if ($departmentConfig.Software -is [string] -and $departmentConfig.Software.Contains(',')) {
                    $departmentConfig.Software = $departmentConfig.Software -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                }

                if ($departmentConfig.SharePointSites -is [string] -and $departmentConfig.SharePointSites.Contains(',')) {
                    $departmentConfig.SharePointSites = $departmentConfig.SharePointSites -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                }

                if ($departmentConfig.Teams -is [string] -and $departmentConfig.Teams.Contains(',')) {
                    $departmentConfig.Teams = $departmentConfig.Teams -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                }

                # Füge die Abteilungskonfiguration zur Sammlung hinzu
                $departmentData[$departmentName] = $departmentConfig

                Write-Log -Message "Abteilung '$departmentName' geladen: OU='$($departmentConfig.OU)', Gruppen=$($departmentConfig.Groups.Count), LizenzSKU='$($departmentConfig.LicenseSKU)'" -Level "DEBUG"

            }
            catch {
                Write-Log -Message "Fehler beim Laden der Abteilung '$sectionName': $($_.Exception.Message)" -Level "WARN"
            }
        }

        # Speichere die Abteilungsdaten in einer globalen Variable für späteren Zugriff
        $global:DepartmentData = $departmentData

        Write-Log -Message "Abteilungskonfigurationen erfolgreich geladen: $($departmentData.Keys.Count) Abteilungen" -Level "INFO"

        return $departmentData

    }
    catch {
        $errorMessage = "Fehler beim Laden der Abteilungskonfigurationen: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        return @{}
    }
}

function Get-DepartmentConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DepartmentName
    )

    try {
        # Lade Abteilungsdaten falls noch nicht geladen
        if (-not $global:DepartmentData) {
            $global:DepartmentData = Import-Departments
        }

        # Suche nach der Abteilung (case-insensitive)
        $department = $global:DepartmentData.GetEnumerator() | Where-Object { $_.Key -eq $DepartmentName -or $_.Key.ToLower() -eq $DepartmentName.ToLower() }

        if ($department) {
            Write-Log -Message "Abteilungskonfiguration für '$DepartmentName' gefunden" -Level "DEBUG"
            return $department.Value
        }
        else {
            Write-Log -Message "Keine Konfiguration für Abteilung '$DepartmentName' gefunden" -Level "WARN"
            return $null
        }

    }
    catch {
        Write-Log -Message "Fehler beim Abrufen der Abteilungskonfiguration für '$DepartmentName': $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}
#endregion

#region User Templates
function Import-UserTemplates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TemplateFile = $null
    )

    try {
        Write-Log -Message "Lade Benutzervorlagen..." -Level "DEBUG"

        # Standardpfad für Template-Datei
        if ([string]::IsNullOrWhiteSpace($TemplateFile)) {
            $TemplateFile = Join-Path $ScriptRoot "assets\user_templates.ini"
        }

        # Prüfe ob Template-Datei existiert
        if (-not (Test-Path $TemplateFile)) {
            Write-Log -Message "Template-Datei nicht gefunden: $TemplateFile" -Level "WARN"
            return @{}
        }

        # Lade Templates mit INI-Parser
        $templateConfig = Get-IniContent -Path $TemplateFile

        # Filtere nur Template-Sektionen
        $templateSections = $templateConfig.Keys | Where-Object { $_ -match '^Template_' }

        if ($templateSections.Count -eq 0) {
            Write-Log -Message "Keine Template-Sektionen gefunden." -Level "WARN"
            return @{}
        }

        Write-Log -Message "Gefundene Templates: $($templateSections.Count)" -Level "DEBUG"

        # Erstelle Template-Datenstruktur
        $templateData = @{}

        foreach ($sectionName in $templateSections) {
            try {
                # Extrahiere den Template-Namen
                $templateName = $sectionName -replace '^Template_', ''

                Write-Log -Message "Verarbeite Template: $templateName" -Level "DEBUG"

                # Lade alle Template-Werte mit sicheren Fallback-Werten
                $templateSettings = @{
                    Name                      = if ($templateConfig[$sectionName].Contains("Name")) { $templateConfig[$sectionName]["Name"] } else { $templateName }
                    Description               = if ($templateConfig[$sectionName].Contains("Description")) { $templateConfig[$sectionName]["Description"] } else { "Keine Beschreibung" }
                    SectionName               = $sectionName
                    DefaultGroups             = if ($templateConfig[$sectionName].Contains("DefaultGroups")) { $templateConfig[$sectionName]["DefaultGroups"] } else { @() }
                    DefaultOU                 = if ($templateConfig[$sectionName].Contains("DefaultOU")) { $templateConfig[$sectionName]["DefaultOU"] } else { $null }
                    DefaultPassword           = if ($templateConfig[$sectionName].Contains("DefaultPassword")) { $templateConfig[$sectionName]["DefaultPassword"] } else { $null }
                    ChangePasswordAtNextLogon = if ($templateConfig[$sectionName].Contains("ChangePasswordAtNextLogon")) { $templateConfig[$sectionName]["ChangePasswordAtNextLogon"] } else { $true }
                    PasswordNeverExpires      = if ($templateConfig[$sectionName].Contains("PasswordNeverExpires")) { $templateConfig[$sectionName]["PasswordNeverExpires"] } else { $false }
                    AccountDisabled           = if ($templateConfig[$sectionName].Contains("AccountDisabled")) { $templateConfig[$sectionName]["AccountDisabled"] } else { $false }
                    CreateHomeDirectory       = if ($templateConfig[$sectionName].Contains("CreateHomeDirectory")) { $templateConfig[$sectionName]["CreateHomeDirectory"] } else { $true }
                    CreateProfile             = if ($templateConfig[$sectionName].Contains("CreateProfile")) { $templateConfig[$sectionName]["CreateProfile"] } else { $true }
                    EnableExchange            = if ($templateConfig[$sectionName].Contains("EnableExchange")) { $templateConfig[$sectionName]["EnableExchange"] } else { $true }
                    EnableM365                = if ($templateConfig[$sectionName].Contains("EnableM365")) { $templateConfig[$sectionName]["EnableM365"] } else { $true }
                    M365LicenseSKU            = if ($templateConfig[$sectionName].Contains("M365LicenseSKU")) { $templateConfig[$sectionName]["M365LicenseSKU"] } else { $null }
                    TerminalAccess            = if ($templateConfig[$sectionName].Contains("TerminalAccess")) { $templateConfig[$sectionName]["TerminalAccess"] } else { $false }
                    VPNAccess                 = if ($templateConfig[$sectionName].Contains("VPNAccess")) { $templateConfig[$sectionName]["VPNAccess"] } else { $true }
                    JiraAccess                = if ($templateConfig[$sectionName].Contains("JiraAccess")) { $templateConfig[$sectionName]["JiraAccess"] } else { $false }
                    DefaultSoftware           = if ($templateConfig[$sectionName].Contains("DefaultSoftware")) { $templateConfig[$sectionName]["DefaultSoftware"] } else { @() }
                    PhoneExtension            = if ($templateConfig[$sectionName].Contains("PhoneExtension")) { $templateConfig[$sectionName]["PhoneExtension"] } else { $false }
                    VoicemailEnabled          = if ($templateConfig[$sectionName].Contains("VoicemailEnabled")) { $templateConfig[$sectionName]["VoicemailEnabled"] } else { $false }
                    DefaultRole               = if ($templateConfig[$sectionName].Contains("DefaultRole")) { $templateConfig[$sectionName]["DefaultRole"] } else { $null }
                    ExpirationDate            = if ($templateConfig[$sectionName].Contains("ExpirationDate")) { $templateConfig[$sectionName]["ExpirationDate"] } else { $null }
                    IsServiceAccount          = if ($templateConfig[$sectionName].Contains("IsServiceAccount")) { $templateConfig[$sectionName]["IsServiceAccount"] } else { $false }
                }

                # Konvertiere Komma-getrennte Strings in Arrays
                if ($templateSettings.DefaultGroups -is [string] -and $templateSettings.DefaultGroups.Contains(',')) {
                    $templateSettings.DefaultGroups = $templateSettings.DefaultGroups -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                }

                if ($templateSettings.DefaultSoftware -is [string] -and $templateSettings.DefaultSoftware.Contains(',')) {
                    $templateSettings.DefaultSoftware = $templateSettings.DefaultSoftware -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                }

                # Stelle sicher, dass DefaultOU ein String ist
                if ($templateSettings.DefaultOU -is [Array] -and $templateSettings.DefaultOU.Count -gt 0) {
                    $templateSettings.DefaultOU = $templateSettings.DefaultOU[0].ToString()
                }
                elseif ($templateSettings.DefaultOU -and $templateSettings.DefaultOU -isnot [string]) {
                    $templateSettings.DefaultOU = $templateSettings.DefaultOU.ToString()
                }

                # Füge Template zur Sammlung hinzu
                $templateData[$templateName] = $templateSettings

                Write-Log -Message "Template '$templateName' geladen: '$($templateSettings.Name)'" -Level "DEBUG"

            }
            catch {
                Write-Log -Message "Fehler beim Laden des Templates '$sectionName': $($_.Exception.Message)" -Level "WARN"
            }
        }

        # Speichere Templates in globaler Variable
        $global:UserTemplateData = $templateData

        Write-Log -Message "Benutzervorlagen erfolgreich geladen: $($templateData.Keys.Count) Templates" -Level "INFO"

        return $templateData

    }
    catch {
        $errorMessage = "Fehler beim Laden der Benutzervorlagen: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        return @{}
    }
}

function Get-UserTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateName
    )

    try {
        # Lade Templates falls noch nicht geladen
        if (-not $global:UserTemplateData) {
            $global:UserTemplateData = Import-UserTemplates
        }

        # Suche nach dem Template (case-insensitive)
        $template = $global:UserTemplateData.GetEnumerator() | Where-Object { $_.Key -eq $TemplateName -or $_.Key.ToLower() -eq $TemplateName.ToLower() }

        if ($template) {
            Write-Log -Message "Benutzervorlage '$TemplateName' gefunden" -Level "DEBUG"
            return $template.Value
        }
        else {
            Write-Log -Message "Keine Vorlage '$TemplateName' gefunden" -Level "WARN"
            return $null
        }

    }
    catch {
        Write-Log -Message "Fehler beim Abrufen der Benutzervorlage '$TemplateName': $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-AvailableUserTemplates {
    [CmdletBinding()]
    param()

    try {
        # Lade Templates falls noch nicht geladen
        if (-not $global:UserTemplateData) {
            $global:UserTemplateData = Import-UserTemplates
        }

        # Konvertiere zu einer Liste für die GUI
        $templateList = @()
        foreach ($template in $global:UserTemplateData.GetEnumerator()) {
            $templateList += [PSCustomObject]@{
                Key              = $template.Key
                Name             = $template.Value.Name
                Description      = $template.Value.Description
                SectionName      = $template.Value.SectionName
                DefaultOU        = $template.Value.DefaultOU
                DefaultGroups    = $template.Value.DefaultGroups
                M365LicenseSKU   = $template.Value.M365LicenseSKU
                IsServiceAccount = $template.Value.IsServiceAccount
            }
        }

        # Sortiere alphabetisch
        $templateList = $templateList | Sort-Object Name

        Write-Log -Message "Verfügbare Benutzervorlagen geladen: $($templateList.Count)" -Level "DEBUG"
        return $templateList

    }
    catch {
        Write-Log -Message "Fehler beim Laden der verfügbaren Benutzervorlagen: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

#region GUI Core Functions
function Import-RequiredAssemblies {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Lade benötigte Assemblies..." -Level "DEBUG"

        # Lade die erforderlichen .NET-Assemblies
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        Add-Type -AssemblyName Microsoft.VisualBasic

        Write-Log -Message "Assemblies erfolgreich geladen" -Level "DEBUG"
        return $true
    }
    catch {
        Write-Log -Message "Fehler beim Laden der Assemblies: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-FilteredAvailableGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$CurrentlySelectedGroups = @(),

        [Parameter(Mandatory = $false)]
        [string]$SearchFilter
    )

    try {
        Write-Log -Message "Lade und filtere AD-Gruppen..." -Level "DEBUG"

        # Lade alle verfügbaren AD-Gruppen und speichere sie zwischen, um wiederholte AD-Abfragen zu vermeiden
        if (-not $global:AllADGroups) {
            $global:AllADGroups = Get-ADGroup -Filter 'GroupCategory -eq "Security"' -Properties Name, DistinguishedName
            Write-Log -Message "Alle AD-Gruppen zwischengespeichert: $($global:AllADGroups.Count) Gruppen." -Level "DEBUG"
        }

        # Stelle sicher, dass $global:AllADGroups ein Array ist, auch wenn die Abfrage fehlschlägt
        if (-not $global:AllADGroups) {
            $global:AllADGroups = @()
        }

        # Filtere Standard-AD-Gruppen aus (Englisch und Deutsch)
        $standardGroupsToExclude = @(
            # Englische Standardgruppen
            'Domain Admins', 'Domain Users', 'Domain Guests', 'Domain Controllers',
            'Enterprise Admins', 'Schema Admins', 'Administrators', 'Users',
            'Guests', 'Power Users', 'Account Operators', 'Server Operators',
            'Print Operators', 'Backup Operators', 'Replicator', 'Remote Desktop Users',
            'Network Configuration Operators', 'Performance Monitor Users',
            'Performance Log Users', 'Distributed COM Users', 'IIS_IUSRS',
            'Cryptographic Operators', 'Event Log Readers', 'Certificate Service DCOM Access',

            # Deutsche Standardgruppen
            'Domänen-Admins', 'Domänen-Benutzer', 'Domänen-Gäste', 'Domänencontroller',
            'Organisations-Admins', 'Schema-Admins', 'Administratoren', 'Benutzer',
            'Gäste', 'Hauptbenutzer', 'Konten-Operatoren', 'Server-Operatoren',
            'Druck-Operatoren', 'Sicherungs-Operatoren', 'Replikations-Operator', 'Remotedesktopbenutzer',
            'Netzwerkkonfigurations-Operatoren', 'Leistungsüberwachungsbenutzer',
            'Leistungsprotokollbenutzer', 'Distributed COM-Benutzer',
            'Krypto-Operatoren', 'Ereignisprotokollleser', 'Zertifikatdienst-DCOM-Zugriff'
        )

        # Filtere die Gruppen
        $filteredGroups = $global:AllADGroups | Where-Object {
            $null -ne $_ -and $null -ne $_.Name -and $_.Name -notin $standardGroupsToExclude -and $_.Name -notin $CurrentlySelectedGroups
        }

        # Wende den Suchfilter an, falls vorhanden
        if (-not [string]::IsNullOrWhiteSpace($SearchFilter)) {
            $filteredGroups = $filteredGroups | Where-Object { $null -ne $_ -and $null -ne $_.Name -and $_.Name -like "*$SearchFilter*" }
        }

        # Extrahiere nur die Namen und sortiere sie
        $groupNames = $filteredGroups | ForEach-Object { $_.Name } | Sort-Object

        Write-Log -Message "Gefilterte Gruppenliste zurückgegeben: $($groupNames.Count) Gruppen." -Level "DEBUG"
        return $groupNames
    }
    catch {
        Write-Log -Message "Fehler beim Filtern der Gruppen: $($_.Exception.Message)" -Level "ERROR"
        return @() # Gib ein leeres Array im Fehlerfall zurück
    }
}

function Update-GroupCount {
    [CmdletBinding()]
    param()

    try {
        if ($global:Variables.ContainsKey('lstSelectedGroups') -and $global:Variables.ContainsKey('groupCountText')) {
            $count = $global:Variables['lstSelectedGroups'].Items.Count
            $global:Variables['groupCountText'].Text = "$count Gruppe(n) ausgewählt"
        }
    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren der Gruppen-Anzahl: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Initialize-GroupLists {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Initialisiere Gruppenlisten..." -Level "DEBUG"

        # Prüfe ob die ListBox-Elemente existieren
        if (-not $global:Variables.ContainsKey('lstAvailableGroups')) {
            Write-Log -Message "lstAvailableGroups nicht in globalen Variablen gefunden" -Level "WARN"
            return
        }

        if (-not $global:Variables.ContainsKey('lstSelectedGroups')) {
            Write-Log -Message "lstSelectedGroups nicht in globalen Variablen gefunden" -Level "WARN"
            return
        }

        $lstAvailableGroups = $global:Variables['lstAvailableGroups']
        $lstSelectedGroups = $global:Variables['lstSelectedGroups']

        # Leere bestehende Listen
        $lstAvailableGroups.Items.Clear()
        $lstSelectedGroups.Items.Clear()

        # Lade AD-Gruppen
        Write-Log -Message "Lade AD-Gruppen für Gruppenlisten..." -Level "DEBUG"

        if (Get-ADConnectionStatus) {
            # Verwende die gefilterte Gruppenliste
            $availableGroups = Get-FilteredAvailableGroups -CurrentlySelectedGroups @()

            Write-Log -Message "Gefundene verfügbare Gruppen: $($availableGroups.Count)" -Level "DEBUG"

            # Füge Gruppen zur verfügbaren Liste hinzu
            foreach ($groupName in $availableGroups) {
                if (-not [string]::IsNullOrWhiteSpace($groupName)) {
                    $lstAvailableGroups.Items.Add($groupName)
                }
            }

            Write-Log -Message "Gruppenlisten erfolgreich initialisiert: $($lstAvailableGroups.Items.Count) verfügbare Gruppen" -Level "INFO"
        }
        else {
            Write-Log -Message "Keine AD-Verbindung verfügbar - lade Fallback-Gruppen" -Level "WARN"

            # Fallback-Gruppen wenn keine AD-Verbindung verfügbar
            $fallbackGroups = @(
                "!!! Keine AD-Verbindung !!!"
            )

            foreach ($groupName in $fallbackGroups) {
                $lstAvailableGroups.Items.Add($groupName)
            }

            Write-Log -Message "Fallback-Gruppen geladen: $($fallbackGroups.Count) Gruppen" -Level "INFO"
        }

        # Aktualisiere Gruppen-Anzahl
        Update-GroupCount

    }
    catch {
        Write-Log -Message "Fehler beim Initialisieren der Gruppenlisten: $($_.Exception.Message)" -Level "ERROR"

        # Notfall-Fallback
        if ($global:Variables.ContainsKey('lstAvailableGroups')) {
            $global:Variables['lstAvailableGroups'].Items.Clear()
            $global:Variables['lstAvailableGroups'].Items.Add("Fehler beim Laden der Gruppen")
        }
    }
}

function Move-SelectedGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ListBox]$FromList,

        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ListBox]$ToList
    )

    try {
        Write-Log -Message "Verschiebe ausgewählte Gruppen..." -Level "DEBUG"

        # Null-Checks
        if (-not $FromList) {
            Write-Log -Message "FromList Parameter ist null - kann Gruppen nicht verschieben" -Level "ERROR"
            [System.Windows.MessageBox]::Show("Fehler: Quell-Liste ist nicht verfügbar.", "Fehler", "OK", "Error")
            return
        }

        if (-not $ToList) {
            Write-Log -Message "ToList Parameter ist null - kann Gruppen nicht verschieben" -Level "ERROR"
            [System.Windows.MessageBox]::Show("Fehler: Ziel-Liste ist nicht verfügbar.", "Fehler", "OK", "Error")
            return
        }

        # Ausgewählte Items in ein Array kopieren, da die Collection während der Iteration verändert wird
        $selectedItems = @($FromList.SelectedItems)

        # Alle ausgewählten Items verschieben
        foreach ($item in $selectedItems) {
            $FromList.Items.Remove($item)
            $ToList.Items.Add($item)
        }

        # Aktualisiere Gruppen-Anzahl
        Update-GroupCount

        Write-Log -Message "Alle $($selectedItems.Count) ausgewählten Gruppen erfolgreich verschoben" -Level "INFO"

    }
    catch {
        Write-Log -Message "Fehler beim Verschieben der ausgewählten Gruppen: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Verschieben der Gruppen: $($_.Exception.Message)", "Fehler", "OK", "Error")
    }
}

function Move-AllGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ListBox]$FromList,

        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ListBox]$ToList
    )

    try {
        Write-Log -Message "Verschiebe alle Gruppen..." -Level "DEBUG"

        # Null-Checks
        if (-not $FromList) {
            Write-Log -Message "FromList Parameter ist null - kann Gruppen nicht verschieben" -Level "ERROR"
            [System.Windows.MessageBox]::Show("Fehler: Quell-Liste ist nicht verfügbar.", "Fehler", "OK", "Error")
            return
        }

        if (-not $ToList) {
            Write-Log -Message "ToList Parameter ist null - kann Gruppen nicht verschieben" -Level "ERROR"
            [System.Windows.MessageBox]::Show("Fehler: Ziel-Liste ist nicht verfügbar.", "Fehler", "OK", "Error")
            return
        }

        # Alle Items in ein Array kopieren, da die Collection während der Iteration verändert wird
        $allItems = @($FromList.Items)

        if ($allItems.Count -eq 0) {
            Write-Log -Message "Keine Gruppen zum Verschieben vorhanden" -Level "DEBUG"
            return
        }

        # Alle Items verschieben
        foreach ($item in $allItems) {
            $FromList.Items.Remove($item)
            $ToList.Items.Add($item)
        }

        # Aktualisiere Gruppen-Anzahl
        Update-GroupCount

        Write-Log -Message "Alle $($allItems.Count) Gruppen erfolgreich verschoben" -Level "INFO"

    }
    catch {
        Write-Log -Message "Fehler beim Verschieben aller Gruppen: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Verschieben der Gruppen: $($_.Exception.Message)", "Fehler", "OK", "Error")
    }
}

function Update-GeneratedFields {
    [CmdletBinding()]
    param()

    try {
        if (-not $global:Variables.ContainsKey('txtFirstName') -or -not $global:Variables.ContainsKey('txtLastName')) {
            return
        }

        $firstName = $global:Variables['txtFirstName'].Text.Trim()
        $lastName = $global:Variables['txtLastName'].Text.Trim()

        if ([string]::IsNullOrWhiteSpace($firstName) -or [string]::IsNullOrWhiteSpace($lastName)) {
            return
        }

        # Normalisiere Namen für Generierung
        $cleanFirstName = ($firstName -replace '[^a-zA-Z]', '').ToLower()
        $cleanLastName = ($lastName -replace '[^a-zA-Z]', '').ToLower()

        # Sicherheitsprüfung für leere Namen nach Normalisierung
        if ([string]::IsNullOrEmpty($cleanFirstName)) {
            $cleanFirstName = "user"
        }
        if ([string]::IsNullOrEmpty($cleanLastName)) {
            $cleanLastName = "unknown"
        }

        $initials = $cleanFirstName[0]

        # Generiere SAM Account Name basierend auf SAMFormat
        $samFormat = Get-ConfigValue -Section "UserCreation" -Key "SAMFormat" -DefaultValue 1
        $samAccountName = switch ($samFormat) {
            1 { "$cleanFirstName.$cleanLastName" }
            2 { "$initials.$cleanLastName" }
            3 { "$cleanLastName$initials" }
            4 { "$cleanFirstName.$cleanLastName" } # Fallback auf Format 1
            5 { "$cleanFirstName`_$cleanLastName" }
            6 { "$cleanFirstName-$cleanLastName" }
            7 { "$cleanFirstName$cleanLastName" }
            8 { "$cleanLastName.$cleanFirstName" }
            9 { "$initials`_$cleanLastName" }
            10 { "$cleanLastName-$initials" }
            default { "$cleanFirstName.$cleanLastName" }
        }

        # Beschränke SAM auf 20 Zeichen
        if ($samAccountName.Length -gt 20) {
            $samAccountName = $samAccountName.Substring(0, 20)
        }

        if ($global:Variables.ContainsKey('txtUsername')) {
            $global:Variables['txtUsername'].Text = $samAccountName
        }

        # Generiere UPN basierend auf UPNFormat
        $upnFormat = Get-ConfigValue -Section "UserCreation" -Key "UPNFormat" -DefaultValue 1
        $upnSuffix = Get-ConfigValue -Section "UserCreation" -Key "UPNSuffix" -DefaultValue $null
        if ([string]::IsNullOrWhiteSpace($upnSuffix)) {
            $upnSuffix = Get-ConfigValue -Section "General" -Key "DomainName" -DefaultValue "domain.local"
        }

        $upnLocalPart = switch ($upnFormat) {
            1 { "$cleanFirstName.$cleanLastName" }
            2 { "$initials.$cleanLastName" }
            3 { "$cleanLastName$initials" }
            4 { $samAccountName }
            5 { "$cleanFirstName`_$cleanLastName" }
            6 { "$cleanFirstName-$cleanLastName" }
            7 { "$cleanFirstName$cleanLastName" }
            8 { "$cleanLastName.$cleanFirstName" }
            9 { "$initials`_$cleanLastName" }
            10 { "$cleanLastName-$initials" }
            default { "$cleanFirstName.$cleanLastName" }
        }

        $userPrincipalName = "$upnLocalPart@$upnSuffix"
        if ($global:Variables.ContainsKey('txtUPN')) {
            $global:Variables['txtUPN'].Text = $userPrincipalName
        }

        # Generiere primäre E-Mail-Adresse basierend auf MailAddressFormat
        $mailFormat = Get-ConfigValue -Section "UserCreation" -Key "MailAddressFormat" -DefaultValue 1
        $domainMail = Get-ConfigValue -Section "General" -Key "DomainMail" -DefaultValue "domain.com"

        $emailLocalPart = switch ($mailFormat) {
            1 { "$cleanFirstName.$cleanLastName" }
            2 { "$initials.$cleanLastName" }
            3 { "$cleanLastName$initials" }
            4 { $samAccountName }
            5 { "$cleanFirstName`_$cleanLastName" }
            6 { "$cleanFirstName-$cleanLastName" }
            7 { "$cleanFirstName$cleanLastName" }
            8 { "$cleanLastName.$cleanFirstName" }
            9 { "$initials`_$cleanLastName" }
            10 { "$cleanLastName-$initials" }
            default { "$cleanFirstName.$cleanLastName" }
        }

        $primaryEmail = "$emailLocalPart@$domainMail"
        if ($global:Variables.ContainsKey('txtEmail')) {
            $global:Variables['txtEmail'].Text = $primaryEmail
        }

        # Generiere Display Name
        $displayName = "$firstName $lastName"
        if ($global:Variables.ContainsKey('txtDisplayName')) {
            $global:Variables['txtDisplayName'].Text = $displayName
        }

        # Check password field with safe property access
        $passwordValue = ""
        if ($global:Variables.ContainsKey('pwdPassword') -and $global:Variables['pwdPassword']) {
            try {
                if ($global:Variables['pwdPassword'].GetType().Name -eq "PasswordBox") {
                    $passwordValue = $global:Variables['pwdPassword'].Password
                }
                elseif ($global:Variables['pwdPassword'].GetType().Name -eq "TextBox") {
                    $passwordValue = $global:Variables['pwdPassword'].Text
                }
                else {
                    # Try both properties as fallback
                    try {
                        $passwordValue = $global:Variables['pwdPassword'].Password
                    }
                    catch {
                        $passwordValue = $global:Variables['pwdPassword'].Text
                    }
                }
            }
            catch {
                Write-Log -Message "Fehler beim Zugriff auf Passwort-Feld: $($_.Exception.Message)" -Level "WARN"
            }
        }

        # Setze Standardpasswort falls leer
        if ([string]::IsNullOrWhiteSpace($passwordValue)) {
            $defaultPassword = Get-ConfigValue -Section "UserCreation" -Key "DefaultPassword" -DefaultValue "Willkommen2025!"
            if ($global:Variables.ContainsKey('pwdPassword') -and $global:Variables['pwdPassword']) {
                try {
                    if ($global:Variables['pwdPassword'].GetType().Name -eq "PasswordBox") {
                        $global:Variables['pwdPassword'].Password = $defaultPassword
                    }
                    elseif ($global:Variables['pwdPassword'].GetType().Name -eq "TextBox") {
                        $global:Variables['pwdPassword'].Text = $defaultPassword
                    }
                }
                catch {
                    Write-Log -Message "Fehler beim Setzen des Standardpassworts: $($_.Exception.Message)" -Level "WARN"
                }
            }
        }

        Write-Log -Message "Generierte Felder aktualisiert: SAM = $samAccountName, UPN = $userPrincipalName, Email = $primaryEmail, DisplayName = $displayName" -Level "DEBUG"

        # Debug-Ausgabe für die verwendeten Formate
        Write-Log -Message "Verwendete Formate: SAMFormat = $samFormat, UPNFormat = $upnFormat, MailAddressFormat = $mailFormat" -Level "DEBUG"

    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren der generierten Felder: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Initialize-MenuSystem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )

    try {
        Write-Log -Message "Initialisiere Menü-System..." -Level "DEBUG"

        # Step 1 Event-Handler
        if ($global:Variables.ContainsKey('btnLoadTemplates')) {
            $global:Variables['btnLoadTemplates'].add_Click({
                    try {
                        Write-Log -Message "Lade Benutzervorlagen..." -Level "INFO"
                        [System.Windows.MessageBox]::Show("Test: btnLoadTemplates wurde geklickt!", "Button Test", "OK", "Information")
                        Invoke-LoadTemplatesAndOverrideGlobals -Window $Window
                        [System.Windows.MessageBox]::Show("Benutzervorlagen erfolgreich geladen!", "Erfolg", "OK", "Information")
                    }
                    catch {
                        [System.Windows.MessageBox]::Show("Fehler beim Laden der Vorlagen: $($_.Exception.Message)", "Fehler", "OK", "Error")
                    }
                })
            Write-Log -Message "Event-Handler für btnLoadTemplates registriert" -Level "DEBUG"
        }

        if ($global:Variables.ContainsKey('btnGeneratePassword')) {
            $global:Variables['btnGeneratePassword'].add_Click({
                    try {
                        $password = New-SecurePassword
                        if ($global:Variables.ContainsKey('pwdPassword') -and $global:Variables['pwdPassword']) {
                            # Check if it's a PasswordBox (WPF) or TextBox
                            if ($global:Variables['pwdPassword'].GetType().Name -eq "PasswordBox") {
                                $global:Variables['pwdPassword'].Password = $password
                            }
                            elseif ($global:Variables['pwdPassword'].GetType().Name -eq "TextBox") {
                                $global:Variables['pwdPassword'].Text = $password
                            }
                            else {
                                Write-Log -Message "Unbekannter Passwort-Control-Typ: $($global:Variables['pwdPassword'].GetType().Name)" -Level "WARN"
                                # Try both properties as fallback
                                try {
                                    $global:Variables['pwdPassword'].Password = $password
                                }
                                catch {
                                    $global:Variables['pwdPassword'].Text = $password
                                }
                            }
                        }
                        [System.Windows.MessageBox]::Show("Passwort wurde generiert und gesetzt!", "Passwort generiert", "OK", "Information")
                        Write-Log -Message "Passwort erfolgreich generiert und gesetzt" -Level "INFO"
                    }
                    catch {
                        Write-Log -Message "Fehler bei der Passwort-Generierung: $($_.Exception.Message)" -Level "ERROR"
                        [System.Windows.MessageBox]::Show("Fehler bei der Passwort-Generierung: $($_.Exception.Message)", "Fehler", "OK", "Error")
                    }
                })
            Write-Log -Message "Event-Handler für btnGeneratePassword registriert" -Level "DEBUG"
        }

        if ($global:Variables.ContainsKey('btnBrowseOU')) {
            $global:Variables['btnBrowseOU'].add_Click({
                    try {
                        [System.Windows.MessageBox]::Show("Test: btnBrowseOU wurde geklickt!", "Button Test", "OK", "Information")
                        $ou = Select-ADOU -Title "OU auswählen"
                        if ($ou) {
                            $global:Variables['cmbOUPath'].Text = $ou.DistinguishedName
                        }
                    }
                    catch {
                        [System.Windows.MessageBox]::Show("Fehler beim Auswählen der OU: $($_.Exception.Message)", "Fehler", "OK", "Error")
                    }
                })
            Write-Log -Message "Event-Handler für btnBrowseOU registriert" -Level "DEBUG"
        }

        if ($global:Variables.ContainsKey('btnValidateStep1')) {
            $global:Variables['btnValidateStep1'].add_Click({
                    try {
                        # Validierung und automatische Generierung
                        $validationResult = Invoke-ValidateStep1 -ShowMessages $true

                        if ($validationResult.IsValid) {
                            # Generiere Benutzername und E-Mail automatisch
                            Update-GeneratedFields

                            # Zeige Erfolg
                            if ($global:Variables.ContainsKey('validationPanel1')) {
                                $global:Variables['validationPanel1'].Visibility = "Collapsed"
                            }

                            [System.Windows.MessageBox]::Show("Validierung erfolgreich! Benutzername und E-Mail wurden automatisch generiert.", "Validierung", "OK", "Information")
                            Write-Log -Message "Step 1 Validierung erfolgreich" -Level "INFO"
                        }
                        else {
                            # Zeige Fehler
                            if ($global:Variables.ContainsKey('validationPanel1')) {
                                $global:Variables['validationPanel1'].Visibility = "Visible"
                            }
                            if ($global:Variables.ContainsKey('validationText1')) {
                                $global:Variables['validationText1'].Text = $validationResult.ErrorMessage
                            }

                            [System.Windows.MessageBox]::Show($validationResult.ErrorMessage, "Validierung fehlgeschlagen", "OK", "Warning")
                            Write-Log -Message "Step 1 Validierung fehlgeschlagen: $($validationResult.ErrorMessage)" -Level "WARN"
                        }
                    }
                    catch {
                        Write-Log -Message "Fehler bei der Validierung: $($_.Exception.Message)" -Level "ERROR"
                        [System.Windows.MessageBox]::Show("Fehler bei der Validierung: $($_.Exception.Message)", "Fehler", "OK", "Error")
                    }
                })
            Write-Log -Message "Event-Handler für btnValidateStep1 registriert" -Level "DEBUG"
        }

        if ($global:Variables.ContainsKey('btnNextStep1')) {
            $global:Variables['btnNextStep1'].add_Click({
                    try {
                        $validationResult = Invoke-ValidateStep1 -ShowMessages:$false
                        if ($validationResult.IsValid) {
                            Switch-Tab -TargetPanel $global:Variables['step2Panel']
                            Write-Log -Message "Wechsle zu Schritt 2" -Level "INFO"
                        }
                        else {
                            [System.Windows.MessageBox]::Show("Bitte beheben Sie die Validierungsfehler, bevor Sie fortfahren.", "Validierung fehlgeschlagen", "OK", "Warning")
                        }
                    }
                    catch {
                        Write-Log -Message "Fehler beim Wechseln zu Schritt 2: $($_.Exception.Message)" -Level "ERROR"
                        [System.Windows.MessageBox]::Show("Fehler beim Wechseln zu Schritt 2: $($_.Exception.Message)", "Fehler", "OK", "Error")
                    }
                })
            Write-Log -Message "Event-Handler für btnNextStep1 registriert" -Level "DEBUG"
        }

        # Step 2 Event-Handler
        if ($global:Variables.ContainsKey('btnAddGroup')) {
            $global:Variables['btnAddGroup'].add_Click({
                    try {
                        # Prüfe ob die benötigten ListBoxes existieren
                        if ($global:Variables.ContainsKey('lstAvailableGroups') -and $global:Variables['lstAvailableGroups'] -and
                            $global:Variables.ContainsKey('lstSelectedGroups') -and $global:Variables['lstSelectedGroups']) {
                            Move-SelectedGroups -FromList $global:Variables['lstAvailableGroups'] -ToList $global:Variables['lstSelectedGroups']
                            Update-GroupCount
                            Write-Log -Message "Ausgewählte Gruppen hinzugefügt" -Level "INFO"
                        }
                        else {
                            Write-Log -Message "Gruppenlisten nicht verfügbar - kann keine Gruppen hinzufügen" -Level "WARN"
                            [System.Windows.MessageBox]::Show("Gruppenlisten sind nicht verfügbar.", "Warnung", "OK", "Warning")
                        }
                    }
                    catch {
                        Write-Log -Message "Fehler beim Hinzufügen der Gruppen: $($_.Exception.Message)" -Level "ERROR"
                        [System.Windows.MessageBox]::Show("Fehler beim Hinzufügen der Gruppen: $($_.Exception.Message)", "Fehler", "OK", "Error")
                    }
                })
            Write-Log -Message "Event-Handler für btnAddGroup registriert" -Level "DEBUG"
        }

        if ($global:Variables.ContainsKey('btnAddAllGroups')) {
            $global:Variables['btnAddAllGroups'].add_Click({
                    try {
                        # Prüfe ob die benötigten ListBoxes existieren
                        if ($global:Variables.ContainsKey('lstAvailableGroups') -and $global:Variables['lstAvailableGroups'] -and
                            $global:Variables.ContainsKey('lstSelectedGroups') -and $global:Variables['lstSelectedGroups']) {
                            Move-AllGroups -FromList $global:Variables['lstAvailableGroups'] -ToList $global:Variables['lstSelectedGroups']
                            Update-GroupCount
                            Write-Log -Message "Alle verfügbaren Gruppen hinzugefügt" -Level "INFO"
                        }
                        else {
                            Write-Log -Message "Gruppenlisten nicht verfügbar - kann keine Gruppen hinzufügen" -Level "WARN"
                            [System.Windows.MessageBox]::Show("Gruppenlisten sind nicht verfügbar.", "Warnung", "OK", "Warning")
                        }
                    }
                    catch {
                        Write-Log -Message "Fehler beim Hinzufügen aller Gruppen: $($_.Exception.Message)" -Level "ERROR"
                        [System.Windows.MessageBox]::Show("Fehler beim Hinzufügen aller Gruppen: $($_.Exception.Message)", "Fehler", "OK", "Error")
                    }
                })
            Write-Log -Message "Event-Handler für btnAddAllGroups registriert" -Level "DEBUG"
        }

        if ($global:Variables.ContainsKey('btnRemoveGroup')) {
            $global:Variables['btnRemoveGroup'].add_Click({
                    try {
                        # Prüfe ob die benötigten ListBoxes existieren
                        if ($global:Variables.ContainsKey('lstAvailableGroups') -and $global:Variables['lstAvailableGroups'] -and
                            $global:Variables.ContainsKey('lstSelectedGroups') -and $global:Variables['lstSelectedGroups']) {
                            Move-SelectedGroups -FromList $global:Variables['lstSelectedGroups'] -ToList $global:Variables['lstAvailableGroups']
                            Update-GroupCount
                            Write-Log -Message "Ausgewählte Gruppen entfernt" -Level "INFO"
                        }
                        else {
                            Write-Log -Message "Gruppenlisten nicht verfügbar - kann keine Gruppen entfernen" -Level "WARN"
                            [System.Windows.MessageBox]::Show("Gruppenlisten sind nicht verfügbar.", "Warnung", "OK", "Warning")
                        }
                    }
                    catch {
                        Write-Log -Message "Fehler beim Entfernen der Gruppen: $($_.Exception.Message)" -Level "ERROR"
                        [System.Windows.MessageBox]::Show("Fehler beim Entfernen der Gruppen: $($_.Exception.Message)", "Fehler", "OK", "Error")
                    }
                })
            Write-Log -Message "Event-Handler für btnRemoveGroup registriert" -Level "DEBUG"
        }

        if ($global:Variables.ContainsKey('btnRemoveAllGroups')) {
            $global:Variables['btnRemoveAllGroups'].add_Click({
                    try {
                        # Prüfe ob die benötigten ListBoxes existieren
                        if ($global:Variables.ContainsKey('lstAvailableGroups') -and $global:Variables['lstAvailableGroups'] -and
                            $global:Variables.ContainsKey('lstSelectedGroups') -and $global:Variables['lstSelectedGroups']) {
                            Move-AllGroups -FromList $global:Variables['lstSelectedGroups'] -ToList $global:Variables['lstAvailableGroups']
                            Update-GroupCount
                            Write-Log -Message "Alle ausgewählten Gruppen entfernt" -Level "INFO"
                        }
                        else {
                            Write-Log -Message "Gruppenlisten nicht verfügbar - kann keine Gruppen entfernen" -Level "WARN"
                            [System.Windows.MessageBox]::Show("Gruppenlisten sind nicht verfügbar.", "Warnung", "OK", "Warning")
                        }
                    }
                    catch {
                        Write-Log -Message "Fehler beim Entfernen aller Gruppen: $($_.Exception.Message)" -Level "ERROR"
                        [System.Windows.MessageBox]::Show("Fehler beim Entfernen aller Gruppen: $($_.Exception.Message)", "Fehler", "OK", "Error")
                    }
                })
            Write-Log -Message "Event-Handler für btnRemoveAllGroups registriert" -Level "DEBUG"
        }

        if ($global:Variables.ContainsKey('btnPrevStep2')) {
            $global:Variables['btnPrevStep2'].add_Click({
                    [System.Windows.MessageBox]::Show("Test: btnPrevStep2 wurde geklickt!", "Button Test", "OK", "Information")
                    Switch-Tab -TargetPanel $global:Variables['step1Panel']
                })
            Write-Log -Message "Event-Handler für btnPrevStep2 registriert" -Level "DEBUG"
        }

        if ($global:Variables.ContainsKey('btnCreateUser')) {
            $global:Variables['btnCreateUser'].add_Click({
                    [System.Windows.MessageBox]::Show("Test: btnCreateUser wurde geklickt!", "Button Test", "OK", "Information")
                    Invoke-CreateUser
                })
            Write-Log -Message "Event-Handler für btnCreateUser registriert" -Level "DEBUG"
        }

        # Name-Änderungs-Handler für automatische Generierung
        if ($global:Variables.ContainsKey('txtFirstName')) {
            $global:Variables['txtFirstName'].add_TextChanged({
                    Write-Log -Message "txtFirstName Text geändert - rufe Update-GeneratedFields auf" -Level "DEBUG"
                    Update-GeneratedFields
                })
            Write-Log -Message "Event-Handler für txtFirstName registriert" -Level "DEBUG"
        }

        if ($global:Variables.ContainsKey('txtLastName')) {
            $global:Variables['txtLastName'].add_TextChanged({
                    Write-Log -Message "txtLastName Text geändert - rufe Update-GeneratedFields auf" -Level "DEBUG"
                    Update-GeneratedFields
                })
            Write-Log -Message "Event-Handler für txtLastName registriert" -Level "DEBUG"
        }

        # Abteilungs-Änderungs-Handler
        if ($global:Variables.ContainsKey('cmbDepartment')) {
            $global:Variables['cmbDepartment'].add_SelectionChanged({
                    Write-Log -Message "cmbDepartment Auswahl geändert - rufe Update-OUDropdownFromDepartment auf" -Level "DEBUG"
                    $cmbOUPath = $Window.FindName("cmbOUPath")
                    $selectedDepartment = $global:Variables['cmbDepartment'].SelectedItem
                    if ($cmbOUPath -and $selectedDepartment) {
                        Update-OUDropdownFromDepartment -OUComboBox $cmbOUPath -DepartmentName $selectedDepartment.ToString()
                    }
                    else {
                        Write-Log -Message "cmbOUPath or selectedDepartment is null. Skipping OU update." -Level "WARN"
                    }
                })
            Write-Log -Message "Event-Handler für cmbDepartment registriert" -Level "DEBUG"
        }

        # Template-Änderungs-Handler
        if ($global:Variables.ContainsKey('cmbTemplate')) {
            $global:Variables['cmbTemplate'].add_SelectionChanged({
                    param($eventSender, $eventData)
                    $selectedTemplate = $eventSender.SelectedItem
                    Write-Log -Message "cmbTemplate Auswahl geändert: $selectedTemplate" -Level "DEBUG"
                    if ($selectedTemplate -and $selectedTemplate -ne "-- Keine Vorlage --") {
                        Apply-UserTemplate -TemplateName $selectedTemplate -Window $Window
                    }
                })
            Write-Log -Message "Event-Handler für cmbTemplate registriert" -Level "DEBUG"
        }

        Write-Log -Message "Menü-System erfolgreich initialisiert" -Level "DEBUG"

    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung des Menü-Systems: $($_.Exception.Message)" -Level "ERROR"
    }
}



function Update-NavigationIndicators {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$CurrentStep
    )

    try {
        # Aktualisiere Progress Bar
        if ($global:Variables.ContainsKey('mainProgressBar')) {
            $global:Variables['mainProgressBar'].Value = $CurrentStep
        }

        # Aktualisiere Progress Text
        if ($global:Variables.ContainsKey('progressText')) {
            $percentage = [math]::Round(($CurrentStep / 7) * 100, 0)
            $global:Variables['progressText'].Text = "$percentage% abgeschlossen"
        }

        # Aktualisiere Info Text
        if ($global:Variables.ContainsKey('infoText')) {
            switch ($CurrentStep) {
                1 { $global:Variables['infoText'].Text = "Geben Sie die Grunddaten des neuen Benutzers ein." }
                2 { $global:Variables['infoText'].Text = "Der Benutzer wird nach diesem Schritt erstellt!" }
                3 { $global:Variables['infoText'].Text = "Erweiterte Einstellungen werden auf den erstellten Benutzer angewendet." }
                default { $global:Variables['infoText'].Text = "Weitere Konfiguration des Benutzers." }
            }
        }

        Write-Log -Message "Navigation-Indikatoren aktualisiert für Schritt $CurrentStep" -Level "DEBUG"

    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren der Navigation-Indikatoren: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Safe-SwitchTab {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PanelName
    )

    try {
        Write-Log -Message "Versuche sicheren Tab-Wechsel zu: $PanelName" -Level "DEBUG"

        # Prüfe, ob das Panel in der Global Variables verfügbar ist
        if ($global:Variables -and $global:Variables.ContainsKey($PanelName) -and $global:Variables[$PanelName]) {
            $panel = $global:Variables[$PanelName]
            Write-Log -Message "Panel '$PanelName' gefunden (Typ: $($panel.GetType().FullName)), wechsle Tab" -Level "DEBUG"

            # Debug: Prüfe Eigenschaften des Panels
            if ($panel.GetType().GetProperty("Visibility")) {
                Write-Log -Message "Panel '$PanelName' hat Visibility-Eigenschaft" -Level "DEBUG"
            }
            else {
                Write-Log -Message "Panel '$PanelName' hat KEINE Visibility-Eigenschaft!" -Level "WARN"
            }

            Switch-Tab -TargetPanel $panel
        }
        else {
            Write-Log -Message "Panel '$PanelName' nicht in Global Variables verfügbar, versuche direkte Suche" -Level "WARN"

            # Versuche direktes FindName
            if ($global:Window) {
                $panel = $global:Window.FindName($PanelName)
                if ($panel) {
                    Write-Log -Message "Panel '$PanelName' direkt gefunden (Typ: $($panel.GetType().FullName)), wechsle Tab" -Level "INFO"

                    # Debug: Prüfe Eigenschaften des Panels
                    if ($panel.GetType().GetProperty("Visibility")) {
                        Write-Log -Message "Direkt gefundenes Panel '$PanelName' hat Visibility-Eigenschaft" -Level "DEBUG"
                    }
                    else {
                        Write-Log -Message "Direkt gefundenes Panel '$PanelName' hat KEINE Visibility-Eigenschaft!" -Level "WARN"
                    }

                    Switch-Tab -TargetPanel $panel
                }
                else {
                    Write-Log -Message "FEHLER: Panel '$PanelName' konnte nicht gefunden werden" -Level "ERROR"
                    throw "Panel '$PanelName' ist nicht verfügbar"
                }
            }
            else {
                Write-Log -Message "FEHLER: Globales Window-Objekt nicht verfügbar" -Level "ERROR"
                throw "Window-Objekt ist nicht verfügbar"
            }
        }

    }
    catch {
        Write-Log -Message "Fehler beim sicheren Tab-Wechsel zu '$PanelName': $($_.Exception.Message)" -Level "ERROR"
    }
}

# Fallback-Funktion für Tab-Navigation ohne Visibility-Eigenschaften
function Set-PanelVisibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Panel,

        [Parameter(Mandatory = $true)]
        [string]$Visibility
    )

    try {
        if ($null -eq $Panel) {
            Write-Log -Message "Panel ist null - kann Visibility nicht setzen" -Level "WARN"
            return $false
        }

        Write-Log -Message "Versuche Visibility '$Visibility' für Panel-Typ '$($Panel.GetType().FullName)' zu setzen" -Level "DEBUG"

        # Methode 1: Direkte Eigenschaft
        try {
            if ($Panel.PSObject.Properties.Name -contains "Visibility") {
                $Panel.Visibility = $Visibility
                Write-Log -Message "Visibility über PSObject Property gesetzt: $Visibility" -Level "DEBUG"
                return $true
            }
        }
        catch {
            Write-Log -Message "PSObject Property Methode fehlgeschlagen: $($_.Exception.Message)" -Level "DEBUG"
        }

        # Methode 2: Reflection Property
        try {
            $visibilityProp = $Panel.GetType().GetProperty("Visibility")
            if ($visibilityProp) {
                $visibilityProp.SetValue($Panel, $Visibility, $null)
                Write-Log -Message "Visibility über Reflection Property gesetzt: $Visibility" -Level "DEBUG"
                return $true
            }
        }
        catch {
            Write-Log -Message "Reflection Property Methode fehlgeschlagen: $($_.Exception.Message)" -Level "DEBUG"
        }

        # Methode 3: DependencyProperty mit enum conversion
        try {
            $visibilityEnum = if ($Visibility -eq "Visible") {
                [System.Windows.Visibility]::Visible
            }
            elseif ($Visibility -eq "Hidden") {
                [System.Windows.Visibility]::Hidden
            }
            else {
                [System.Windows.Visibility]::Collapsed
            }

            # Direkte Zuweisung mit konvertiertem Enum
            $Panel.Visibility = $visibilityEnum
            Write-Log -Message "Visibility über direkte Enum-Zuweisung gesetzt: $Visibility" -Level "DEBUG"
            return $true
        }
        catch {
            Write-Log -Message "Direkte Enum-Methode fehlgeschlagen: $($_.Exception.Message)" -Level "DEBUG"
        }

        # Methode 4: DependencyProperty über SetValue
        try {
            $visibilityProperty = [System.Windows.UIElement]::VisibilityProperty
            $visibilityEnum = if ($Visibility -eq "Visible") {
                [System.Windows.Visibility]::Visible
            }
            elseif ($Visibility -eq "Hidden") {
                [System.Windows.Visibility]::Hidden
            }
            else {
                [System.Windows.Visibility]::Collapsed
            }
            $Panel.SetValue($visibilityProperty, $visibilityEnum)
            Write-Log -Message "Visibility über DependencyProperty SetValue gesetzt: $Visibility" -Level "DEBUG"
            return $true
        }
        catch {
            Write-Log -Message "DependencyProperty SetValue Methode fehlgeschlagen: $($_.Exception.Message)" -Level "DEBUG"
        }

        # Methode 5: String-basierte Eigenschaftszuweisung
        try {
            $Panel."Visibility" = $Visibility
            Write-Log -Message "Visibility über String-Property gesetzt: $Visibility" -Level "DEBUG"
            return $true
        }
        catch {
            Write-Log -Message "String-Property Methode fehlgeschlagen: $($_.Exception.Message)" -Level "DEBUG"
        }

        Write-Log -Message "Alle Methoden zur Visibility-Setzung fehlgeschlagen für Panel-Typ '$($Panel.GetType().FullName)'" -Level "WARN"
        return $false
    }
    catch {
        Write-Log -Message "Fehler beim Setzen der Panel-Visibility: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Invoke-ValidateStep1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$ShowMessages = $true
    )

    try {
        Write-Log -Message "Validiere Schritt 1..." -Level "DEBUG"

        $errors = @()

        # Pflichtfelder prüfen
        if ([string]::IsNullOrWhiteSpace($global:Variables['txtFirstName'].Text)) {
            $errors += "Vorname ist erforderlich"
        }

        if ([string]::IsNullOrWhiteSpace($global:Variables['txtLastName'].Text)) {
            $errors += "Nachname ist erforderlich"
        }

        if ([string]::IsNullOrWhiteSpace($global:Variables['cmbOUPath'].Text)) {
            $errors += "OU-Pfad ist erforderlich"
        }

        if ([string]::IsNullOrWhiteSpace($global:Variables['pwdPassword'].Password)) {
            $errors += "Passwort ist erforderlich"
        }

        # Generiere E-Mail-Adresse wenn noch nicht vorhanden
        if ([string]::IsNullOrWhiteSpace($global:Variables['txtEmail'].Text)) {
            $firstName = $global:Variables['txtFirstName'].Text.Trim()
            $lastName = $global:Variables['txtLastName'].Text.Trim()

            if (-not [string]::IsNullOrWhiteSpace($firstName) -and -not [string]::IsNullOrWhiteSpace($lastName)) {
                $domain = Get-ConfigValue -Section "UserCreation" -Key "EmailDomain" -DefaultValue "company.local"
                $emailFormat = Get-ConfigValue -Section "UserCreation" -Key "EmailFormat" -DefaultValue 1

                switch ($emailFormat) {
                    1 { $email = "$($firstName.ToLower()).$($lastName.ToLower())@$domain" }
                    2 { $email = "$($firstName.ToLower()[0]).$($lastName.ToLower())@$domain" }
                    3 { $email = "$($lastName.ToLower())@$domain" }
                    default { $email = "$($firstName.ToLower()).$($lastName.ToLower())@$domain" }
                }

                $global:Variables['txtEmail'].Text = $email
            }
        }

        # Zeige Validierungsergebnisse
        if ($errors.Count -gt 0) {
            $errorMessage = "Folgende Fehler wurden gefunden:`n" + ($errors -join "`n")

            if ($global:Variables.ContainsKey('validationPanel1')) {
                $global:Variables['validationPanel1'].Visibility = "Visible"
                $global:Variables['validationText1'].Text = $errorMessage
            }

            if ($ShowMessages) {
                [System.Windows.MessageBox]::Show($errorMessage, "Validierungsfehler", "OK", "Warning")
            }

            return @{
                IsValid      = $false
                ErrorMessage = $errorMessage
            }
        }
        else {
            if ($global:Variables.ContainsKey('validationPanel1')) {
                $global:Variables['validationPanel1'].Visibility = "Collapsed"
            }

            if ($ShowMessages) {
                [System.Windows.MessageBox]::Show("Alle Eingaben sind korrekt!", "Validierung erfolgreich", "OK", "Information")
            }

            return @{
                IsValid      = $true
                ErrorMessage = ""
            }
        }

    }
    catch {
        Write-Log -Message "Fehler bei der Validierung von Schritt 1: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Invoke-CreateUser {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Starte Benutzererstellung..." -Level "INFO"

        # Validiere Eingaben
        if (-not (Invoke-ValidateStep1 -ShowMessages:$false)) {
            [System.Windows.MessageBox]::Show("Bitte beheben Sie die Validierungsfehler in Schritt 1.", "Validierung fehlgeschlagen", "OK", "Warning")
            Switch-Tab -TargetPanel $global:Variables['step1Panel']
            return
        }

        # Sammle Benutzerdaten
        $userData = @{
            FirstName  = $global:Variables['txtFirstName'].Text.Trim()
            LastName   = $global:Variables['txtLastName'].Text.Trim()
            Username   = $global:Variables['txtUsername'].Text.Trim()
            Email      = $global:Variables['txtEmail'].Text.Trim()
            Department = $global:Variables['cmbDepartment'].Text.Trim()
            Position   = $global:Variables['txtPosition'].Text.Trim()
            Manager    = $global:SelectedManagerDN
            OUPath     = $global:Variables['cmbOUPath'].Text.Trim()
            Password   = $global:Variables['pwdPassword'].Password
            Groups     = @($global:Variables['lstSelectedGroups'].Items)
        }

        # Erstelle Benutzer
        $result = New-ADUserAccount -UserData $userData

        if ($result.Success) {
            $global:CreatedUserDN = $result.DistinguishedName
            $global:CreatedUserSAM = $result.SamAccountName

            # Aktualisiere Status
            if ($global:Variables.ContainsKey('userStatusText')) {
                $global:Variables['userStatusText'].Text = "Benutzer '$($userData.Username)' erfolgreich erstellt"
            }

            [System.Windows.MessageBox]::Show(
                "Benutzer '$($userData.Username)' wurde erfolgreich erstellt!",
                "Erfolg",
                "OK",
                "Information"
            )

            # Wechsle zu Schritt 3
            Switch-Tab -TargetPanel $global:Variables['step3Panel']

        }
        else {
            [System.Windows.MessageBox]::Show(
                "Fehler beim Erstellen des Benutzers: $($result.Message)",
                "Fehler",
                "OK",
                "Error"
            )
        }

    }
    catch {
        Write-Log -Message "Fehler bei der Benutzererstellung: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show(
            "Fehler bei der Benutzererstellung: $($_.Exception.Message)",
            "Fehler",
            "OK",
            "Error"
        )
    }
}

function Select-ADUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Title = "Benutzer auswählen",

        [Parameter(Mandatory = $false)]
        [string]$PrefilledSearchTerm = ""
    )

    try {
        # Bestimme den Suchbegriff aus dem txtManager Feld
        $txtManager = $Window.FindName("txtManager")
        $searchTerm = ""

        if ($txtManager -and -not [string]::IsNullOrWhiteSpace($txtManager.Text)) {
            $searchTerm = $txtManager.Text.Trim()
        } elseif (-not [string]::IsNullOrWhiteSpace($PrefilledSearchTerm)) {
            $searchTerm = $PrefilledSearchTerm
        }

        if ([string]::IsNullOrWhiteSpace($searchTerm)) {
            [System.Windows.MessageBox]::Show("Bitte geben Sie zuerst einen Suchbegriff im Manager-Feld ein.", "Kein Suchbegriff", "OK", "Information")
            return $null
        }

        if (-not (Get-ADConnectionStatus)) {
            [System.Windows.MessageBox]::Show("Keine Active Directory-Verbindung verfügbar.", "Fehler", "OK", "Warning")
            return $null
        }

        Write-Log -Message "Suche AD-Benutzer mit Suchbegriff: $searchTerm" -Level "DEBUG"

        # Suche nach Benutzern mit verschiedenen Kriterien
        $users = Get-ADUser -Filter "SamAccountName -like '*$searchTerm*' -or DisplayName -like '*$searchTerm*' -or GivenName -like '*$searchTerm*' -or Surname -like '*$searchTerm*'" -Properties DisplayName, Department, Title, GivenName, Surname -ErrorAction Stop

        if (-not $users) {
            [System.Windows.MessageBox]::Show("Keine Benutzer gefunden für Suchbegriff '$searchTerm'.", "Keine Ergebnisse", "OK", "Information")
            return $null
        }

        # Wenn nur ein Benutzer gefunden wurde, direkt zurückgeben und txtManager aktualisieren
        if ($users.Count -eq 1) {
            Write-Log -Message "Ein Benutzer gefunden: $($users.DisplayName)" -Level "DEBUG"

            # Aktualisiere das txtManager Feld mit Vor- und Nachname
            if ($txtManager) {
                $managerDisplayName = if ($users.GivenName -and $users.Surname) {
                    "$($users.GivenName) $($users.Surname)"
                } elseif ($users.DisplayName) {
                    $users.DisplayName
                } else {
                    $users.SamAccountName
                }
                $txtManager.Text = $managerDisplayName
                Write-Log -Message "Manager-Feld aktualisiert mit: $managerDisplayName" -Level "DEBUG"
            }

            return $users
        }

        # Mehrere Benutzer gefunden - Auswahldialog erstellen
        Write-Log -Message "Mehrere Benutzer gefunden ($($users.Count)). Zeige Auswahldialog." -Level "DEBUG"

        # XAML für Auswahldialog
        $xamlDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="400" Width="600"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Mehrere Benutzer gefunden. Bitte wählen Sie einen aus:"
                   FontWeight="Bold" Margin="0,0,0,10"/>

        <DataGrid Grid.Row="1" Name="dgUsers" AutoGenerateColumns="False"
                  IsReadOnly="True" SelectionMode="Single" GridLinesVisibility="Horizontal"
                  CanUserResizeColumns="True" CanUserSortColumns="True">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Anzeigename" Binding="{Binding DisplayName}" Width="*"/>
                <DataGridTextColumn Header="Benutzername" Binding="{Binding SamAccountName}" Width="120"/>
                <DataGridTextColumn Header="Abteilung" Binding="{Binding Department}" Width="120"/>
                <DataGridTextColumn Header="Position" Binding="{Binding Title}" Width="120"/>
            </DataGrid.Columns>
        </DataGrid>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="btnOK" Content="OK" Width="75" Height="25" Margin="0,0,10,0" IsDefault="True"/>
            <Button Name="btnCancel" Content="Abbrechen" Width="75" Height="25" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

        # Dialog erstellen
        $reader = [System.Xml.XmlNodeReader]::new([xml]$xamlDialog)
        $dialogWindow = [System.Windows.Markup.XamlReader]::Load($reader)

        # Steuerelemente abrufen
        $dgUsers = $dialogWindow.FindName("dgUsers")
        $btnOK = $dialogWindow.FindName("btnOK")
        $btnCancel = $dialogWindow.FindName("btnCancel")

        # DataGrid mit Benutzerdaten füllen
        $userList = @()
        foreach ($user in $users) {
            $userList += [PSCustomObject]@{
                DisplayName    = if ($user.DisplayName) { $user.DisplayName } else { "$($user.GivenName) $($user.Surname)" }
                SamAccountName = $user.SamAccountName
                Department     = if ($user.Department) { $user.Department } else { "Nicht angegeben" }
                Title          = if ($user.Title) { $user.Title } else { "Nicht angegeben" }
                ADUser         = $user  # Original AD-Objekt für Rückgabe
            }
        }

        $dgUsers.ItemsSource = $userList

        # Event-Handler für Buttons
        $selectedUser = $null

        $btnOK.add_Click({
            if ($dgUsers.SelectedItem) {
                $selectedUser = $dgUsers.SelectedItem.ADUser
                $dialogWindow.DialogResult = $true
                $dialogWindow.Close()
            } else {
                [System.Windows.MessageBox]::Show("Bitte wählen Sie einen Benutzer aus.", "Keine Auswahl", "OK", "Warning")
            }
        })

        $btnCancel.add_Click({
            $dialogWindow.DialogResult = $false
            $dialogWindow.Close()
        })

        # Doppelklick auf DataGrid-Zeile
        $dgUsers.add_MouseDoubleClick({
            if ($dgUsers.SelectedItem) {
                $selectedUser = $dgUsers.SelectedItem.ADUser
                $dialogWindow.DialogResult = $true
                $dialogWindow.Close()
            }
        })

        # Dialog anzeigen
        $result = $dialogWindow.ShowDialog()

        if ($result -eq $true -and $selectedUser) {
            Write-Log -Message "Benutzer ausgewählt: $($selectedUser.DisplayName) ($($selectedUser.SamAccountName))" -Level "INFO"

            # Aktualisiere das txtManager Feld mit Vor- und Nachname des ausgewählten Managers
            if ($txtManager) {
                $managerDisplayName = if ($selectedUser.GivenName -and $selectedUser.Surname) {
                    "$($selectedUser.GivenName) $($selectedUser.Surname)"
                } elseif ($selectedUser.DisplayName) {
                    $selectedUser.DisplayName
                } else {
                    $selectedUser.SamAccountName
                }
                $txtManager.Text = $managerDisplayName
                Write-Log -Message "Manager-Feld aktualisiert mit: $managerDisplayName" -Level "DEBUG"
            }

            return $selectedUser
        } else {
            Write-Log -Message "Benutzerauswahl abgebrochen" -Level "DEBUG"
            return $null
        }

    }
    catch {
        Write-Log -Message "Fehler bei der Benutzerauswahl: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show("Fehler bei der Benutzersuche: $($_.Exception.Message)", "Fehler", "OK", "Error")
        return $null
    }
}

function Select-ADOU {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Title = "OU auswählen"
    )

    try {
        $ouPath = [Microsoft.VisualBasic.Interaction]::InputBox("Bitte geben Sie den OU-Pfad ein:", $Title, "")

        if (-not [string]::IsNullOrWhiteSpace($ouPath)) {
            if (Get-ADConnectionStatus) {
                $ou = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouPath'" -ErrorAction SilentlyContinue
                if ($ou) {
                    return $ou
                }
                else {
                    [System.Windows.MessageBox]::Show("OU '$ouPath' nicht gefunden.", "Fehler", "OK", "Warning")
                }
            }
            else {
                [System.Windows.MessageBox]::Show("Keine Active Directory-Verbindung verfügbar.", "Fehler", "OK", "Warning")
            }
        }

        return $null

    }
    catch {
        Write-Log -Message "Fehler bei der OU-Auswahl: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-ADGroupsForSelection {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Lade AD-Gruppen für Auswahlliste..." -Level "DEBUG"

        if (-not (Get-ADConnectionStatus)) {
            Write-Log -Message "Keine AD-Verbindung verfügbar, verwende Fallback-Gruppen" -Level "WARN"
            return @(
                @{Name = "Domain Users"; Description = "Alle Benutzer der Domain" },
                @{Name = "IT-Team"; Description = "IT-Abteilung" },
                @{Name = "Vertrieb"; Description = "Vertriebsabteilung" },
                @{Name = "Marketing"; Description = "Marketing-Abteilung" },
                @{Name = "VPN-Benutzer"; Description = "VPN-Zugang" },
                @{Name = "Office365-Benutzer"; Description = "Office 365 Lizenz" }
            )
        }

        $groups = Get-ADGroup -Filter * | Sort-Object Name | Select-Object Name, Description

        $groupList = @()
        foreach ($group in $groups) {
            $groupList += @{
                Name        = $group.Name
                Description = $group.Description
            }
        }

        Write-Log -Message "AD-Gruppen erfolgreich geladen: $($groupList.Count)" -Level "DEBUG"
        return $groupList

    }
    catch {
        Write-Log -Message "Fehler beim Laden der AD-Gruppen: $($_.Exception.Message)" -Level "ERROR"
        # Fallback-Gruppen
        return @(
            @{Name = "Domain Users"; Description = "Alle Benutzer der Domain" }
        )
    }
}
#endregion

#region Group Management Functions
# Alle Group Management Funktionen sind bereits oben definiert
#endregion

function Apply-UserTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateName,

        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )

    try {
        Write-Log -Message "Wende Benutzervorlage '$TemplateName' an..." -Level "INFO"

        # Lade Template
        $template = Get-UserTemplate -TemplateName $TemplateName

        if (-not $template) {
            throw "Template '$TemplateName' nicht gefunden."
        }

        # Wende Template-Werte auf GUI-Elemente an

        # Tab 1 - Grunddaten
        $txtDescription = $Window.FindName("txtDescription")
        if ($txtDescription -and $template.DefaultRole) {
            $txtDescription.Text = $template.DefaultRole
        }

        # Tab 2 - AD-Einstellungen
        $cmbOUPath = $Window.FindName("cmbOUPath")
        if ($cmbOUPath -and $template.DefaultOU) {
            # Stelle sicher, dass DefaultOU ein String ist
            $defaultOUPath = $template.DefaultOU
            if ($defaultOUPath -is [Array] -and $defaultOUPath.Count -gt 0) {
                $defaultOUPath = $defaultOUPath[0]
            }
            if ($defaultOUPath -and $defaultOUPath.ToString()) {
                Update-OUDropdown -SelectedOUPath $defaultOUPath.ToString()
            }
        }

        # Passwort-Einstellungen
        $chkMustChangePassword = $Window.FindName("chkMustChangePassword")
        if ($chkMustChangePassword -and $template.ContainsKey("ChangePasswordAtNextLogon")) {
            $chkMustChangePassword.IsChecked = $template.ChangePasswordAtNextLogon
        }

        $chkPasswordNeverExpires = $Window.FindName("chkPasswordNeverExpires")
        if ($chkPasswordNeverExpires -and $template.ContainsKey("PasswordNeverExpires")) {
            $chkPasswordNeverExpires.IsChecked = $template.PasswordNeverExpires
        }

        $chkAccountDisabled = $Window.FindName("chkAccountDisabled")
        if ($chkAccountDisabled -and $template.ContainsKey("AccountDisabled")) {
            $chkAccountDisabled.IsChecked = $template.AccountDisabled
        }

        # Tab 3 - Gruppen
        # Hier würden die Gruppen basierend auf dem Template ausgewählt

        # Tab 4 - Exchange/M365
        $cmbLicenseSKU = $Window.FindName("cmbLicenseSKU")
        if ($cmbLicenseSKU -and $template.M365LicenseSKU) {
            # Setze die Lizenz-SKU falls vorhanden
            foreach ($item in $cmbLicenseSKU.Items) {
                if ($item.ToString() -eq $template.M365LicenseSKU) {
                    $cmbLicenseSKU.SelectedItem = $item
                    break
                }
            }
        }

        # Tab 5 - Services
        # Hier würden die Services basierend auf dem Template konfiguriert

        # Tab 6 - Weitere Services
        $chkEnableVpn = $Window.FindName("chkEnableVpn")
        if ($chkEnableVpn -and $template.ContainsKey("VPNAccess")) {
            $chkEnableVpn.IsChecked = $template.VPNAccess
        }

        $chkEnableTelephony = $Window.FindName("chkEnableTelephony")
        if ($chkEnableTelephony -and $template.ContainsKey("PhoneExtension")) {
            $chkEnableTelephony.IsChecked = $template.PhoneExtension
        }

        Write-Log -Message "Benutzervorlage '$TemplateName' erfolgreich angewendet" -Level "INFO"

        # Benachrichtigung anzeigen
        [System.Windows.MessageBox]::Show(
            "Die Vorlage '$($template.Name)' wurde erfolgreich angewendet.`n`nBeschreibung: $($template.Description)",
            "Vorlage angewendet",
            "OK",
            "Information"
        )

    }
    catch {
        $errorMessage = "Fehler beim Anwenden der Benutzervorlage '$TemplateName': $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        [System.Windows.MessageBox]::Show(
            $errorMessage,
            "Fehler beim Anwenden der Vorlage",
            "OK",
            "Error"
        )
    }
}

function Invoke-LoadTemplatesAndOverrideGlobals {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Window = $null
    )

    try {
        Write-Log -Message "Lade Benutzervorlagen neu und überschreibe globale Konfiguration..." -Level "INFO"

        # Lade Templates neu
        $global:UserTemplateData = Import-UserTemplates

        # Lade zusätzliche Konfiguration aus user_templates.ini für globale Überschreibungen
        $templateFile = Join-Path $ScriptRoot "assets\user_templates.ini"

        if (-not (Test-Path $templateFile)) {
            Write-Log -Message "Template-Datei nicht gefunden: $templateFile" -Level "WARN"
            return
        }

        $templateConfig = Get-IniContent -Path $templateFile

        # Prüfe auf GlobalOverrides Sektion
        if ($templateConfig.Contains("GlobalOverrides")) {
            Write-Log -Message "GlobalOverrides Sektion gefunden - überschreibe globale Konfigurationswerte..." -Level "INFO"

            $overrideSection = $templateConfig["GlobalOverrides"]
            $overriddenValues = @()

            # Überschreibe allgemeine Einstellungen
            if ($overrideSection.Contains("CompanyName")) {
                $oldValue = $global:CompanyName
                $global:CompanyName = $overrideSection["CompanyName"]
                $overriddenValues += "CompanyName: '$oldValue' -> '$($global:CompanyName)'"
            }

            if ($overrideSection.Contains("DomainName")) {
                $oldValue = $global:DomainName
                $global:DomainName = $overrideSection["DomainName"]
                $overriddenValues += "DomainName: '$oldValue' -> '$($global:DomainName)'"
            }

            if ($overrideSection.Contains("DomainMail")) {
                $oldValue = $global:DomainMail
                $global:DomainMail = $overrideSection["DomainMail"]
                $overriddenValues += "DomainMail: '$oldValue' -> '$($global:DomainMail)'"
            }

            if ($overrideSection.Contains("DefaultOU")) {
                $oldValue = $global:DefaultOU
                $global:DefaultOU = $overrideSection["DefaultOU"]
                $overriddenValues += "DefaultOU: '$oldValue' -> '$($global:DefaultOU)'"
            }

            # Überschreibe Benutzeranlage-Einstellungen
            if ($overrideSection.Contains("DefaultPassword")) {
                $oldValue = $global:DefaultPassword
                $global:DefaultPassword = $overrideSection["DefaultPassword"]
                $overriddenValues += "DefaultPassword: '********' -> '********'"
            }

            if ($overrideSection.Contains("ChangePasswordAtNextLogon")) {
                $oldValue = $global:ChangePasswordAtNextLogon
                $newValue = $overrideSection["ChangePasswordAtNextLogon"]
                # Konvertiere zu Boolean falls es ein String ist
                if ($newValue -is [string]) {
                    $global:ChangePasswordAtNextLogon = Convert-IniValue -Value $newValue
                }
                else {
                    $global:ChangePasswordAtNextLogon = $newValue
                }
                $overriddenValues += "ChangePasswordAtNextLogon: '$oldValue' -> '$($global:ChangePasswordAtNextLogon)'"
            }

            if ($overrideSection.Contains("UPNSuffix")) {
                $oldValue = $global:UPNSuffix
                $global:UPNSuffix = $overrideSection["UPNSuffix"]
                $overriddenValues += "UPNSuffix: '$oldValue' -> '$($global:UPNSuffix)'"
            }

            # Überschreibe Gruppen-Einstellungen
            if ($overrideSection.Contains("DefaultGroups")) {
                $oldValue = $global:DefaultGroups -join ", "
                $newValue = $overrideSection["DefaultGroups"]
                if ($newValue -is [string]) {
                    $global:DefaultGroups = Convert-IniValue -Value $newValue
                }
                else {
                    $global:DefaultGroups = $newValue
                }
                if ($global:DefaultGroups -is [string] -and $global:DefaultGroups.Contains(',')) {
                    $global:DefaultGroups = $global:DefaultGroups -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                }
                $overriddenValues += "DefaultGroups: '$oldValue' -> '$($global:DefaultGroups -join ", ")'"
            }

            # Überschreibe Exchange-Einstellungen
            if ($overrideSection.Contains("ExchangeEnvironment")) {
                $oldValue = $global:ExchangeEnvironment
                $global:ExchangeEnvironment = $overrideSection["ExchangeEnvironment"]
                $overriddenValues += "ExchangeEnvironment: '$oldValue' -> '$($global:ExchangeEnvironment)'"
            }

            if ($overrideSection.Contains("EmailAddressPolicy")) {
                $oldValue = $global:EmailAddressPolicy
                $global:EmailAddressPolicy = $overrideSection["EmailAddressPolicy"]
                $overriddenValues += "EmailAddressPolicy: '$oldValue' -> '$($global:EmailAddressPolicy)'"
            }

            if ($overrideSection.Contains("EnableOnPremMailbox")) {
                $oldValue = $global:EnableOnPremMailbox
                $newValue = $overrideSection["EnableOnPremMailbox"]
                if ($newValue -is [string]) {
                    $global:EnableOnPremMailbox = Convert-IniValue -Value $newValue
                }
                else {
                    $global:EnableOnPremMailbox = $newValue
                }
                $overriddenValues += "EnableOnPremMailbox: '$oldValue' -> '$($global:EnableOnPremMailbox)'"
            }

            if ($overrideSection.Contains("EnableRemoteMailbox")) {
                $oldValue = $global:EnableRemoteMailbox
                $newValue = $overrideSection["EnableRemoteMailbox"]
                if ($newValue -is [string]) {
                    $global:EnableRemoteMailbox = Convert-IniValue -Value $newValue
                }
                else {
                    $global:EnableRemoteMailbox = $newValue
                }
                $overriddenValues += "EnableRemoteMailbox: '$oldValue' -> '$($global:EnableRemoteMailbox)'"
            }

            # Überschreibe M365-Einstellungen
            if ($overrideSection.Contains("M365AssignLicense")) {
                $oldValue = $global:M365AssignLicense
                $newValue = $overrideSection["M365AssignLicense"]
                if ($newValue -is [string]) {
                    $global:M365AssignLicense = Convert-IniValue -Value $newValue
                }
                else {
                    $global:M365AssignLicense = $newValue
                }
                $overriddenValues += "M365AssignLicense: '$oldValue' -> '$($global:M365AssignLicense)'"
            }

            if ($overrideSection.Contains("M365LicenseSKU")) {
                $oldValue = $global:M365LicenseSKU
                $global:M365LicenseSKU = $overrideSection["M365LicenseSKU"]
                $overriddenValues += "M365LicenseSKU: '$oldValue' -> '$($global:M365LicenseSKU)'"
            }

            # Überschreibe GUI-Standardeinstellungen
            if ($overrideSection.Contains("DefaultTerminalAccess")) {
                $oldValue = $global:DefaultTerminalAccess
                $newValue = $overrideSection["DefaultTerminalAccess"]
                if ($newValue -is [string]) {
                    $global:DefaultTerminalAccess = Convert-IniValue -Value $newValue
                }
                else {
                    $global:DefaultTerminalAccess = $newValue
                }
                $overriddenValues += "DefaultTerminalAccess: '$oldValue' -> '$($global:DefaultTerminalAccess)'"
            }

            if ($overrideSection.Contains("DefaultVPNAccess")) {
                $oldValue = $global:DefaultVPNAccess
                $newValue = $overrideSection["DefaultVPNAccess"]
                if ($newValue -is [string]) {
                    $global:DefaultVPNAccess = Convert-IniValue -Value $newValue
                }
                else {
                    $global:DefaultVPNAccess = $newValue
                }
                $overriddenValues += "DefaultVPNAccess: '$oldValue' -> '$($global:DefaultVPNAccess)'"
            }

            if ($overrideSection.Contains("DefaultMS365Sync")) {
                $oldValue = $global:DefaultMS365Sync
                $newValue = $overrideSection["DefaultMS365Sync"]
                if ($newValue -is [string]) {
                    $global:DefaultMS365Sync = Convert-IniValue -Value $newValue
                }
                else {
                    $global:DefaultMS365Sync = $newValue
                }
                $overriddenValues += "DefaultMS365Sync: '$oldValue' -> '$($global:DefaultMS365Sync)'"
            }

            if ($overrideSection.Contains("DefaultJiraAccess")) {
                $oldValue = $global:DefaultJiraAccess
                $newValue = $overrideSection["DefaultJiraAccess"]
                if ($newValue -is [string]) {
                    $global:DefaultJiraAccess = Convert-IniValue -Value $newValue
                }
                else {
                    $global:DefaultJiraAccess = $newValue
                }
                $overriddenValues += "DefaultJiraAccess: '$oldValue' -> '$($global:DefaultJiraAccess)'"
            }

            # Überschreibe Telefonie-Einstellungen
            if ($overrideSection.Contains("StarfaceEnabled")) {
                $oldValue = $global:StarfaceEnabled
                $newValue = $overrideSection["StarfaceEnabled"]
                if ($newValue -is [string]) {
                    $global:StarfaceEnabled = Convert-IniValue -Value $newValue
                }
                else {
                    $global:StarfaceEnabled = $newValue
                }
                $overriddenValues += "StarfaceEnabled: '$oldValue' -> '$($global:StarfaceEnabled)'"
            }

            if ($overrideSection.Contains("TelephonyExtensionPrefix")) {
                $oldValue = $global:TelephonyExtensionPrefix
                $global:TelephonyExtensionPrefix = $overrideSection["TelephonyExtensionPrefix"]
                $overriddenValues += "TelephonyExtensionPrefix: '$oldValue' -> '$($global:TelephonyExtensionPrefix)'"
            }

            # Überschreibe Benachrichtigungs-Einstellungen
            if ($overrideSection.Contains("NotifyManager")) {
                $oldValue = $global:NotifyManager
                $newValue = $overrideSection["NotifyManager"]
                if ($newValue -is [string]) {
                    $global:NotifyManager = Convert-IniValue -Value $newValue
                }
                else {
                    $global:NotifyManager = $newValue
                }
                $overriddenValues += "NotifyManager: '$oldValue' -> '$($global:NotifyManager)'"
            }

            if ($overrideSection.Contains("NotifyITHelpdesk")) {
                $oldValue = $global:NotifyITHelpdesk
                $newValue = $overrideSection["NotifyITHelpdesk"]
                if ($newValue -is [string]) {
                    $global:NotifyITHelpdesk = Convert-IniValue -Value $newValue
                }
                else {
                    $global:NotifyITHelpdesk = $newValue
                }
                $overriddenValues += "NotifyITHelpdesk: '$oldValue' -> '$($global:NotifyITHelpdesk)'"
            }

            if ($overrideSection.Contains("SMTPServer")) {
                $oldValue = $global:SMTPServer
                $global:SMTPServer = $overrideSection["SMTPServer"]
                $overriddenValues += "SMTPServer: '$oldValue' -> '$($global:SMTPServer)'"
            }

            if ($overrideSection.Contains("SMTPPort")) {
                $oldValue = $global:SMTPPort
                $newValue = $overrideSection["SMTPPort"]
                if ($newValue -is [string]) {
                    $global:SMTPPort = Convert-IniValue -Value $newValue
                }
                else {
                    $global:SMTPPort = $newValue
                }
                $overriddenValues += "SMTPPort: '$oldValue' -> '$($global:SMTPPort)'"
            }

            if ($overrideSection.Contains("SMTPFrom")) {
                $oldValue = $global:SMTPFrom
                $global:SMTPFrom = $overrideSection["SMTPFrom"]
                $overriddenValues += "SMTPFrom: '$oldValue' -> '$($global:SMTPFrom)'"
            }

            if ($overrideSection.Contains("SMTPTo")) {
                $oldValue = $global:SMTPTo
                $global:SMTPTo = $overrideSection["SMTPTo"]
                $overriddenValues += "SMTPTo: '$oldValue' -> '$($global:SMTPTo)'"
            }

            # Zeige überschriebene Werte an wenn DebugMode aktiviert ist
            if ($global:DebugMode -and $overriddenValues.Count -gt 0) {
                Write-Host "======================================" -ForegroundColor Green
                Write-Host "GLOBALE KONFIGURATION ÜBERSCHRIEBEN:" -ForegroundColor Yellow
                Write-Host "======================================" -ForegroundColor Green

                foreach ($override in $overriddenValues) {
                    Write-Host "  $override" -ForegroundColor Cyan
                    Write-Log -Message "Überschrieben: $override" -Level "DEBUG"
                }

                Write-Host "======================================" -ForegroundColor Green
                Write-Host "Anzahl überschriebener Werte: $($overriddenValues.Count)" -ForegroundColor Yellow
                Write-Host "======================================" -ForegroundColor Green
            }

            Write-Log -Message "Globale Konfiguration erfolgreich überschrieben: $($overriddenValues.Count) Werte" -Level "INFO"
        }
        else {
            Write-Log -Message "Keine GlobalOverrides Sektion in user_templates.ini gefunden" -Level "WARN"
        }

        # Aktualisiere Template-Dropdown falls vorhanden
        if ($Window) {
            $cmbTemplate = $Window.FindName("cmbTemplate")
            if ($cmbTemplate) {
                try {
                    $cmbTemplate.Items.Clear()
                    $availableTemplates = Get-AvailableUserTemplates

                    foreach ($template in $availableTemplates) {
                        $cmbTemplate.Items.Add($template.Name)
                    }

                    if ($availableTemplates.Count -gt 0) {
                        $cmbTemplate.SelectedIndex = 0
                    }

                    Write-Log -Message "Template-Dropdown erfolgreich aktualisiert mit $($availableTemplates.Count) Templates" -Level "DEBUG"
                }
                catch {
                    Write-Log -Message "Fehler beim Aktualisieren des Template-Dropdowns: $($_.Exception.Message)" -Level "WARN"
                }
            }
        }

        # Erfolgsmeldung anzeigen
        $message = "Benutzervorlagen erfolgreich neu geladen!"
        if ($templateConfig.Contains("GlobalOverrides")) {
            $overrideCount = $templateConfig["GlobalOverrides"].Keys.Count
            $message += "`n`nGlobale Konfiguration überschrieben: $overrideCount Werte"
        }
        $message += "`n`nAnzahl verfügbarer Templates: $($global:UserTemplateData.Keys.Count)"

        Write-Host $message -ForegroundColor Green
        Write-Log -Message "Template-Neuladen erfolgreich abgeschlossen" -Level "INFO"

        # Zeige Bestätigungsdialog
        [System.Windows.MessageBox]::Show(
            $message,
            "Vorlagen erfolgreich geladen",
            "OK",
            "Information"
        )

    }
    catch {
        $errorMessage = "Fehler beim Laden der Vorlagen und Überschreiben der globalen Konfiguration: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        [System.Windows.MessageBox]::Show(
            $errorMessage,
            "Fehler beim Laden der Vorlagen",
            "OK",
            "Error"
        )
    }
}

#endregion
#endregion

#region Email Validation Function
function Test-EmailAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$EmailAddress
    )

    try {
        # Prüfe ob E-Mail-Adresse leer ist
        if ([string]::IsNullOrWhiteSpace($EmailAddress)) {
            Write-Log -Message "E-Mail-Adresse ist leer" -Level "DEBUG"
            return $false
        }

        # Erweiterte E-Mail-Regex für bessere Validierung
        $emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

        # Grundlegende Format-Prüfung
        if ($EmailAddress -notmatch $emailRegex) {
            Write-Log -Message "E-Mail-Adresse hat ungültiges Format: $EmailAddress" -Level "DEBUG"
            return $false
        }

        # Zusätzliche Validierungen

        # Prüfe auf doppelte Punkte
        if ($EmailAddress -match '\.\.') {
            Write-Log -Message "E-Mail-Adresse enthält aufeinanderfolgende Punkte: $EmailAddress" -Level "DEBUG"
            return $false
        }

        # Prüfe auf Punkt am Anfang oder Ende des lokalen Teils
        $localPart = $EmailAddress.Split('@')[0]
        if ($localPart.StartsWith('.') -or $localPart.EndsWith('.')) {
            Write-Log -Message "Lokaler Teil der E-Mail-Adresse beginnt oder endet mit Punkt: $EmailAddress" -Level "DEBUG"
            return $false
        }

        # Prüfe Domain-Teil
        $domainPart = $EmailAddress.Split('@')[1]
        if ($domainPart.StartsWith('.') -or $domainPart.EndsWith('.') -or $domainPart.StartsWith('-') -or $domainPart.EndsWith('-')) {
            Write-Log -Message "Domain-Teil der E-Mail-Adresse hat ungültiges Format: $EmailAddress" -Level "DEBUG"
            return $false
        }

        # Prüfe Länge der E-Mail-Adresse (RFC 5321 begrenzt auf 254 Zeichen)
        if ($EmailAddress.Length -gt 254) {
            Write-Log -Message "E-Mail-Adresse ist zu lang (max. 254 Zeichen): $EmailAddress" -Level "DEBUG"
            return $false
        }

        # Prüfe Länge des lokalen Teils (max. 64 Zeichen)
        if ($localPart.Length -gt 64) {
            Write-Log -Message "Lokaler Teil der E-Mail-Adresse ist zu lang (max. 64 Zeichen): $EmailAddress" -Level "DEBUG"
            return $false
        }

        # Erweiterte .NET MailAddress Validierung (falls verfügbar)
        try {
            $mailAddress = [System.Net.Mail.MailAddress]::new($EmailAddress)
            if ($mailAddress.Address -ne $EmailAddress) {
                Write-Log -Message "E-Mail-Adresse Format-Validierung fehlgeschlagen: $EmailAddress" -Level "DEBUG"
                return $false
            }
        }
        catch {
            Write-Log -Message "E-Mail-Adresse .NET Validierung fehlgeschlagen: $EmailAddress - $($_.Exception.Message)" -Level "DEBUG"
            return $false
        }

        Write-Log -Message "E-Mail-Adresse ist gültig: $EmailAddress" -Level "DEBUG"
        return $true
    }
    catch {
        Write-Log -Message "Fehler bei der E-Mail-Validierung: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-EmailAddressAvailability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EmailAddress
    )

    try {
        Write-Log -Message "Prüfe E-Mail-Adresse Verfügbarkeit in Active Directory: $EmailAddress" -Level "DEBUG"

        # Prüfe zuerst das Format
        if (-not (Test-EmailAddress -EmailAddress $EmailAddress)) {
            return @{
                Success   = $false
                Available = $false
                Message   = "E-Mail-Adresse hat ungültiges Format"
            }
        }

        # Prüfe Active Directory falls verfügbar
        if (Get-ADConnectionStatus) {
            try {
                # Prüft die Attribute 'mail' und 'proxyAddresses'
                $filter = "mail -eq '$EmailAddress' -or proxyAddresses -eq 'smtp:$EmailAddress'"
                $existingUser = Get-ADUser -Filter $filter -ErrorAction Stop

                if ($existingUser) {
                    Write-Log -Message "E-Mail-Adresse bereits in AD vergeben: $EmailAddress an $($existingUser.SamAccountName)" -Level "DEBUG"
                    return @{
                        Success      = $true
                        Available    = $false
                        Message      = "E-Mail-Adresse bereits im Active Directory vergeben"
                        ExistingUser = $existingUser.SamAccountName
                    }
                }
            }
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                # Benutzer wurde nicht gefunden, das ist gut
            }
            catch {
                Write-Log -Message "Fehler bei AD-E-Mail-Prüfung: $($_.Exception.Message)" -Level "WARN"
                # Bei einem Fehler wird die Verfügbarkeit als unbekannt/verfügbar angenommen, um den Prozess nicht zu blockieren
            }
        }
        else {
            Write-Log -Message "Keine AD-Verbindung, E-Mail-Verfügbarkeit kann nicht geprüft werden." -Level "WARN"
        }

        Write-Log -Message "E-Mail-Adresse ist in AD verfügbar: $EmailAddress" -Level "DEBUG"
        return @{
            Success   = $true
            Available = $true
            Message   = "E-Mail-Adresse ist im Active Directory verfügbar"
        }
    }
    catch {
        Write-Log -Message "Fehler bei der E-Mail-Verfügbarkeitsprüfung: $($_.Exception.Message)" -Level "ERROR"
        return @{
            Success   = $false
            Available = $false
            Message   = "Fehler bei der Verfügbarkeitsprüfung: $($_.Exception.Message)"
        }
    }
}

function Get-EmailSuggestions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstName,

        [Parameter(Mandatory = $true)]
        [string]$LastName,

        [Parameter(Mandatory = $false)]
        [string]$Domain,

        [Parameter(Mandatory = $false)]
        [int]$MaxSuggestions = 5
    )

    try {
        Write-Log -Message "Generiere E-Mail-Vorschläge für: $FirstName $LastName" -Level "DEBUG"

        # Domain aus Konfiguration laden falls nicht angegeben
        if ([string]::IsNullOrWhiteSpace($Domain)) {
            $Domain = Get-ConfigValue -Section "Exchange" -Key "DefaultDomain" -DefaultValue $null
            if ([string]::IsNullOrWhiteSpace($Domain)) {
                $Domain = Get-ConfigValue -Section "General" -Key "DomainName" -DefaultValue "domain.local"
            }
        }

        # Namen normalisieren
        $cleanFirstName = ($FirstName -replace '[^a-zA-Z]', '').ToLower()
        $cleanLastName = ($LastName -replace '[^a-zA-Z]', '').ToLower()

        # Verschiedene E-Mail-Formate generieren
        $suggestions = @()
        $emailFormats = @(
            "$cleanFirstName.$cleanLastName",
            "$cleanFirstName$cleanLastName",
            "$($cleanFirstName[0]).$cleanLastName",
            "$cleanFirstName.$($cleanLastName[0])",
            "$($cleanFirstName[0])$cleanLastName",
            "$cleanLastName.$cleanFirstName",
            "$cleanLastName$($cleanFirstName[0])"
        )

        foreach ($format in $emailFormats) {
            if ($suggestions.Count -ge $MaxSuggestions) { break }

            $emailAddress = "$format@$Domain"

            # Prüfe ob bereits in Vorschlägen enthalten
            if ($suggestions -notcontains $emailAddress) {
                # Prüfe Verfügbarkeit
                $availability = Test-EmailAddressAvailability -EmailAddress $emailAddress
                if ($availability.Available) {
                    $suggestions += $emailAddress
                }
            }
        }

        # Falls nicht genügend Vorschläge, füge nummerierte Varianten hinzu
        if ($suggestions.Count -lt $MaxSuggestions) {
            $baseFormat = "$cleanFirstName.$cleanLastName"
            $counter = 1

            while ($suggestions.Count -lt $MaxSuggestions -and $counter -le 99) {
                $emailAddress = "$baseFormat$counter@$Domain"
                $availability = Test-EmailAddressAvailability -EmailAddress $emailAddress
                if ($availability.Available) {
                    $suggestions += $emailAddress
                }
                $counter++
            }
        }

        Write-Log -Message "Generiert $($suggestions.Count) E-Mail-Vorschläge" -Level "DEBUG"
        return $suggestions
    }
    catch {
        Write-Log -Message "Fehler bei der E-Mail-Vorschlagsgenerierung: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}
#endregion

#region ProxyMailAdress Generierung
function Get-ProxyAddressesForUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrimaryEmail,

        [Parameter(Mandatory = $false)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $false)]
        [string]$SamAccountName,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$UserData,

        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config
    )

    Write-Log -Message "Generiere Proxy-Adressen für: $PrimaryEmail" -Level "DEBUG"

    try {
        $proxyAddresses = [System.Collections.Generic.List[string]]::new()

        # 1. Primäre E-Mail-Adresse hinzufügen
        if (-not (Test-EmailAddress -EmailAddress $PrimaryEmail)) {
            Write-Log -Message "Ungültige primäre E-Mail-Adresse angegeben: $PrimaryEmail. Breche Proxy-Generierung ab." -Level "WARN"
            return @()
        }
        $proxyAddresses.Add("SMTP:$PrimaryEmail")
        Write-Log -Message "Primäre Proxy-Adresse hinzugefügt: SMTP:$PrimaryEmail" -Level "DEBUG"

        # 2. Zusätzliche Adressen aus Konfiguration generieren
        $proxyTemplates = Get-ConfigValue -Section "Exchange" -Key "ProxyAddressTemplates" -DefaultValue @() -Config $Config
        if ($proxyTemplates -is [string]) {
            $proxyTemplates = $proxyTemplates -split ',' | ForEach-Object { $_.Trim() }
        }

        if ($proxyTemplates.Count -gt 0 -and $UserData) {
            $domainMail = Get-ConfigValue -Section "General" -Key "DomainMail" -DefaultValue "domain.com" -Config $Config

            foreach ($template in $proxyTemplates) {
                try {
                    $newAddress = $template -replace '%firstname%', $UserData.FirstName
                    $newAddress = $newAddress -replace '%lastname%', $UserData.LastName
                    $newAddress = $newAddress -replace '%samaccountname%', $SamAccountName
                    $newAddress = $newAddress -replace '%upn%', $UserPrincipalName
                    $newAddress = $newAddress -replace '%domainmail%', $domainMail

                    if (Test-EmailAddress -EmailAddress $newAddress) {
                        $proxyAddresses.Add("smtp:$newAddress")
                        Write-Log -Message "Generierte Proxy-Adresse aus Vorlage: smtp:$newAddress" -Level "DEBUG"
                    }
                    else {
                        Write-Log -Message "Generierte Adresse aus Vorlage '$template' ist ungültig: $newAddress" -Level "WARN"
                    }
                }
                catch {
                    Write-Log -Message "Fehler beim Verarbeiten der Proxy-Vorlage '$template': $($_.Exception.Message)" -Level "WARN"
                }
            }
        }

        # 3. UPN als Alias hinzufügen, falls abweichend
        if (-not [string]::IsNullOrWhiteSpace($UserPrincipalName) -and $UserPrincipalName -ne $PrimaryEmail) {
            if (Test-EmailAddress -EmailAddress $UserPrincipalName) {
                $proxyAddresses.Add("smtp:$UserPrincipalName")
                Write-Log -Message "UPN als Proxy-Adresse hinzugefügt: smtp:$UserPrincipalName" -Level "DEBUG"
            }
        }

        # 4. Duplikate entfernen (case-insensitive)
        $uniqueProxyAddresses = $proxyAddresses | Select-Object -Unique

        Write-Log -Message "Proxy-Adressen generiert: $($uniqueProxyAddresses.Count) eindeutige Adressen" -Level "INFO"
        return $uniqueProxyAddresses
    }
    catch {
        Write-Log -Message "Fehler bei der Generierung der Proxy-Adressen: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}
#endregion

#region MS365 and ADSync Integration Functions
function Initialize-MS365Integration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$UserData
    )

    try {
        Write-Log -Message "Initialisiere MS365-Integration für: $($UserData.FirstName) $($UserData.LastName)" -Level "INFO"

        # Prüfe MS365-Konfiguration
        $ms365Enabled = Get-ConfigValue -Section "Exchange" -Key "EnableOnlineMailbox" -DefaultValue $false

        if ($ms365Enabled) {
            Write-Log -Message "MS365-Integration aktiviert" -Level "DEBUG"

            # Lade das MS365-Modul
            $modulePath = Join-Path $ScriptRoot "modules\MOD-MS365Sync-V0.0.1.psm1"
            if (-not (Test-Path $modulePath)) {
                throw "MS365-Modul nicht gefunden unter: $modulePath"
            }
            Import-Module -Name $modulePath -Force
            Write-Log -Message "MS365-Modul erfolgreich geladen." -Level "DEBUG"

            # Rufe die Mailbox-Erstellungsfunktion aus dem Modul auf
            # Prüfe ob die Funktion im Modul verfügbar ist
            if (Get-Command -Name New-ExchangeMailboxGUI -ErrorAction SilentlyContinue) {
                $mailboxResult = New-ExchangeMailboxGUI -UserData $UserData
                return $mailboxResult
            }
            else {
                Write-Log -Message "Funktion New-ExchangeMailboxGUI nicht gefunden" -Level "WARN"
                return @{ Success = $false; Message = "Exchange-Mailbox-Funktion nicht verfügbar" }
            }
        }
        else {
            Write-Log -Message "MS365-Integration deaktiviert" -Level "INFO"
            return @{ Success = $true; Message = "MS365-Integration übersprungen (deaktiviert)" }
        }
    }
    catch {
        $errorMessage = "Fehler bei MS365-Integration: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        return @{ Success = $false; Message = $errorMessage }
    }
}
function Initialize-ADSyncIntegration {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Initialisiere ADSync-Integration..." -Level "INFO"

        # Prüfe ADSync-Konfiguration
        $adSyncEnabled = Get-ConfigValue -Section "ADSync" -Key "EnableAutoSync" -DefaultValue $false

        if ($adSyncEnabled) {
            Write-Log -Message "ADSync-Integration aktiviert" -Level "DEBUG"

            # Lade das ADSync-Modul
            $modulePath = Join-Path $ScriptRoot "modules\MOD-HybridADSync_V0.0.1.psm1"
            if (-not (Test-Path $modulePath)) {
                throw "ADSync-Modul nicht gefunden unter: $modulePath"
            }
            Import-Module -Name $modulePath -Force
            Write-Log -Message "ADSync-Modul erfolgreich geladen." -Level "DEBUG"

            # Rufe die Post-Creation-Sync-Funktion aus dem Modul auf
            # Prüfe ob die Funktion im Modul verfügbar ist
            if (Get-Command -Name Invoke-PostUserCreationADSync -ErrorAction SilentlyContinue) {
                $syncResult = Invoke-PostUserCreationADSync
                return $syncResult
            }
            else {
                Write-Log -Message "Funktion Invoke-PostUserCreationADSync nicht gefunden" -Level "WARN"
                return @{ Success = $false; Message = "ADSync-Funktion nicht verfügbar" }
            }
        }
        else {
            Write-Log -Message "ADSync-Integration deaktiviert" -Level "INFO"
            return @{ Success = $true; Message = "ADSync-Integration übersprungen (deaktiviert)" }
        }
    }
    catch {
        $errorMessage = "Fehler bei ADSync-Integration: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        return @{ Success = $false; Message = $errorMessage }
    }
}
#endregion

#region Telephony Integration Functions

function Initialize-TelephonyIntegration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$UserData
    )

    try {
        Write-Log -Message "Initialisiere Telefonie-Integration für: $($UserData.FirstName) $($UserData.LastName)" -Level "INFO"

        # Prüfe Telefonie-Konfiguration
        $telephonyEnabled = Get-ConfigValue -Section "Telephony" -Key "Enabled" -DefaultValue $false

        if ($telephonyEnabled) {
            $telephonySystem = Get-ConfigValue -Section "Telephony" -Key "System" -DefaultValue "Starface"

            switch ($telephonySystem.ToLower()) {
                "starface" {
                    return Initialize-StarfaceTelephony -UserData $UserData
                }
                "3cx" {
                    return Initialize-3CXTelephony -UserData $UserData
                }
                default {
                    Write-Log -Message "Unbekanntes Telefonie-System: $telephonySystem" -Level "WARN"
                    return @{ Success = $false; Message = "Unbekanntes Telefonie-System" }
                }
            }
        }
        else {
            Write-Log -Message "Telefonie-Integration deaktiviert" -Level "DEBUG"
            return @{ Success = $true; Message = "Telefonie deaktiviert" }
        }
    }
    catch {
        Write-Log -Message "Fehler bei Telefonie-Integration: $($_.Exception.Message)" -Level "ERROR"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function Initialize-StarfaceTelephony {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$UserData
    )

    try {
        # Lade das Starface-Modul
        $modulePath = Join-Path $ScriptRoot "modules\MOD-STARFACEPBX-V0.0.1.psm1"
        if (-not (Test-Path $modulePath)) {
            throw "Starface-Modul nicht gefunden unter: $modulePath"
        }
        Import-Module -Name $modulePath -Force
        Write-Log -Message "Starface-Modul erfolgreich geladen." -Level "DEBUG"

        # Starface-spezifische Telefonie-Initialisierung
        $starfaceConfig = @{
            BaseUrl  = Get-ConfigValue -Section "Starface" -Key "BaseURL" -DefaultValue ""
            Username = Get-ConfigValue -Section "Starface" -Key "Username" -DefaultValue ""
            Password = Get-ConfigValue -Section "Starface" -Key "Password" -DefaultValue ""
        }

        if ([string]::IsNullOrWhiteSpace($starfaceConfig.BaseUrl)) {
            throw "Starface BaseURL nicht konfiguriert"
        }

        # Teste Starface-Verbindung
        # Prüfe ob die Funktion im Modul verfügbar ist
        if (Get-Command -Name Test-StarfaceConnection -ErrorAction SilentlyContinue) {
            $connectionTest = Test-StarfaceConnection -BaseUrl $starfaceConfig.BaseUrl -Username $starfaceConfig.Username -Password $starfaceConfig.Password

            if (-not $connectionTest.Success) {
                throw "Starface-Verbindung fehlgeschlagen: $($connectionTest.Message)"
            }
        }
        else {
            Write-Log -Message "Funktion Test-StarfaceConnection nicht gefunden - überspringe Verbindungstest" -Level "WARN"
        }

        # Erstelle Starface-Benutzer
        # Prüfe ob die Funktion im Modul verfügbar ist
        if (Get-Command -Name Invoke-StarfacePBXUserCreation -ErrorAction SilentlyContinue) {
            $starfaceResult = Invoke-StarfacePBXUserCreation -UserData $UserData
            return $starfaceResult
        }
        else {
            Write-Log -Message "Funktion Invoke-StarfacePBXUserCreation nicht gefunden" -Level "WARN"
            return @{ Success = $false; Message = "Starface-PBX-Funktion nicht verfügbar" }
        }
    }
    catch {
        Write-Log -Message "Fehler bei Starface-Telefonie-Initialisierung: $($_.Exception.Message)" -Level "ERROR"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function Initialize-3CXTelephony {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$UserData
    )

    try {
        # Lade das 3CX-Modul
        $modulePath = Join-Path $ScriptRoot "modules\MOD-3CXPBX-V0.0.1.psm1"
        if (-not (Test-Path $modulePath)) {
            throw "3CX-Modul nicht gefunden unter: $modulePath"
        }
        Import-Module -Name $modulePath -Force
        Write-Log -Message "3CX-Modul erfolgreich geladen." -Level "DEBUG"

        Write-Log -Message "3CX-Integration noch nicht implementiert" -Level "WARN"
        # Hier würde die 3CX-spezifische Logik folgen, z.B. Invoke-3CXUserCreation
        return @{ Success = $true; Message = "3CX-Integration übersprungen (nicht implementiert)" }
    }
    catch {
        Write-Log -Message "Fehler bei 3CX-Telefonie-Integration: $($_.Exception.Message)" -Level "ERROR"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

#endregion
#region Menu System Functions

# Funktion zum Initialisieren des Menü-Systems
function Initialize-MenuSystem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )

    try {
        Write-Log -Message "Initialisiere Menü-System..." -Level "DEBUG"

        # Hauptmenü-Elemente suchen
        $menuFile = $Window.FindName("menuFile")
        $menuTools = $Window.FindName("menuTools")
        $menuHelp = $Window.FindName("menuHelp")

        # File-Menü Event-Handler
        if ($menuFile) {
            $menuItemNew = $Window.FindName("menuItemNew")
            $menuItemOpen = $Window.FindName("menuItemOpen")
            $menuItemSave = $Window.FindName("menuItemSave")
            $menuItemExit = $Window.FindName("menuItemExit")

            if ($menuItemNew) {
                $menuItemNew.add_Click({ Reset-GUI })
            }

            if ($menuItemOpen) {
                $menuItemOpen.add_Click({ Import-OnboardingConfiguration })
            }

            if ($menuItemSave) {
                $menuItemSave.add_Click({ Export-OnboardingConfiguration })
            }

            if ($menuItemExit) {
                $menuItemExit.add_Click({ $Window.Close() })
            }
        }

        # Tools-Menü Event-Handler
        if ($menuTools) {
            $menuItemValidate = $Window.FindName("menuItemValidate")
            $menuItemSettings = $Window.FindName("menuItemSettings")
            $menuItemLogs = $Window.FindName("menuItemLogs")

            if ($menuItemValidate) {
                $menuItemValidate.add_Click({ Test-AllValidations })
            }

            if ($menuItemSettings) {
                $menuItemSettings.add_Click({ Show-SettingsDialog })
            }

            if ($menuItemLogs) {
                $menuItemLogs.add_Click({ Show-LogViewer })
            }
        }

        # Help-Menü Event-Handler
        if ($menuHelp) {
            $menuItemAbout = $Window.FindName("menuItemAbout")
            $menuItemHelp = $Window.FindName("menuItemHelp")

            if ($menuItemAbout) {
                $menuItemAbout.add_Click({ Show-AboutDialog })
            }

            if ($menuItemHelp) {
                $menuItemHelp.add_Click({ Show-HelpDialog })
            }
        }

        Write-Log -Message "Menü-System erfolgreich initialisiert" -Level "DEBUG"
    }
    catch {
        Write-Log -Message "Fehler beim Initialisieren des Menü-Systems: $($_.Exception.Message)" -Level "WARN"
    }
}

function Show-SettingsDialog {
    try {
        Write-Log -Message "Öffne Einstellungen-Dialog..." -Level "INFO"

        # Einfacher Einstellungen-Dialog (kann erweitert werden)
        $settingsPath = Join-Path $ScriptRoot "assets\onbconfig.ini"

        if (Test-Path $settingsPath) {
            Start-Process notepad.exe -ArgumentList $settingsPath
        }
        else {
            [System.Windows.MessageBox]::Show("Konfigurationsdatei nicht gefunden: $settingsPath", "Einstellungen", "OK", "Warning")
        }
    }
    catch {
        Write-Log -Message "Fehler beim Öffnen der Einstellungen: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Show-LogViewer {
    try {
        Write-Log -Message "Öffne Log-Viewer..." -Level "INFO"

        # Log-Datei im Standard-Editor öffnen
        $logPath = Get-ConfigValue -Section "Logging" -Key "LogFilePath" -DefaultValue "easyONB.log"

        if (-not [System.IO.Path]::IsPathRooted($logPath)) {
            $logPath = Join-Path $ScriptRoot $logPath
        }

        if (Test-Path $logPath) {
            Start-Process notepad.exe -ArgumentList $logPath
        }
        else {
            [System.Windows.MessageBox]::Show("Log-Datei nicht gefunden: $logPath", "Log-Viewer", "OK", "Warning")
        }
    }
    catch {
        Write-Log -Message "Fehler beim Öffnen des Log-Viewers: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Show-AboutDialog {
    try {
        $aboutMessage = @"
easyONBOARDING v2.0.1

Ein GUI-basiertes Tool zur Erstellung neuer Benutzer in
Active Directory und Microsoft 365.

Entwickelt von: Phin-IT
Version: 2.0.1
Build-Datum: $(Get-Date -Format 'yyyy-MM-dd')

Funktionen:
• Active Directory Benutzer-Erstellung
• Microsoft 365 Integration
• Gruppen-Management
• Telefonie-Integration (Starface PBX)
• System-Integration (ERP/CRM)
• Automatisierte Workflows

© 2025 Phin-IT. Alle Rechte vorbehalten.
"@

        [System.Windows.MessageBox]::Show($aboutMessage, "Über easyONBOARDING", "OK", "Information")
    }
    catch {
        Write-Log -Message "Fehler beim Anzeigen des About-Dialogs: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Show-HelpDialog {
    try {
        $helpMessage = @"
easyONBOARDING - Hilfe

VERWENDUNG:
1. Benutzerdaten eingeben (Tab 1)
2. AD-Einstellungen konfigurieren (Tab 2)
3. Exchange/M365 einrichten (Tab 3)
4. Gruppen auswählen (Tab 4)
5. Systeme konfigurieren (Tab 5)
6. Zusatzdienste aktivieren (Tab 6)
7. Zusammenfassung prüfen und ausführen (Tab 7)

MENÜ-FUNKTIONEN:
• Datei > Neu: GUI zurücksetzen
• Datei > Öffnen: Konfiguration laden
• Datei > Speichern: Konfiguration exportieren
• Extras > Validierung: Alle Eingaben prüfen
• Extras > Einstellungen: Konfiguration bearbeiten
• Extras > Logs: Log-Dateien anzeigen

TASTENKÜRZEL:
• Strg+N: Neue Konfiguration
• Strg+O: Konfiguration öffnen
• Strg+S: Konfiguration speichern
• F1: Diese Hilfe anzeigen

Weitere Dokumentation finden Sie in der README.md Datei.
"@

        [System.Windows.MessageBox]::Show($helpMessage, "Hilfe - easyONBOARDING", "OK", "Information")
    }
    catch {
        Write-Log -Message "Fehler beim Anzeigen der Hilfe: $($_.Exception.Message)" -Level "ERROR"
    }
}
#endregion

#region GUI
# Funktion zum Erweitern der GUI-Steuerelemente-Bindung
function Expand-GuiControls {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )

    Write-Log -Message "Erweitere GUI-Steuerelemente-Bindung..." -Level "DEBUG"

    # Zusätzliche Steuerelemente für alle Tabs
    $additionalControls = @(
        # Tab 1 Controls
        "txtFirstName", "txtLastName", "txtDisplayName", "txtSamAccountName", "txtUPN", "txtEmail",
        "cmbDepartment", "dtpStartDate", "chkIsTemporary", "dtpEndDate",

        # Tab 2 Controls
        "lblADStatus", "btnTestADConnection", "cmbOUPath", "txtCustomOU",
        "chkCreateHomeDirectory", "txtHomeDirectoryPath", "chkCreateProfilePath", "txtProfilePath",

        # Tab 3 Controls
        "chkCreateMailbox", "txtEmailAddress", "cmbMailboxDatabase", "chkAssignLicense",
        "cmbLicenseType", "lblM365Status", "btnTestM365Connection",

        # Tab 4 Controls
        "dgADGroups", "dgSecurityGroups", "dgDistributionGroups", "btnAddGroup",
        "btnRemoveGroup", "btnLoadDepartmentGroups",

        # Tab 5 Controls
        "dgErpCrm", "dgDevTools", "dgOtherSystems",

        # Tab 6 Controls
        "dgTelephony", "dgAdditionalServices",

        # Tab 7 Controls
        "txtSummary", "btnExecuteOnboarding", "btnGenerateReport",
        "progressBarOnboarding", "lblProgress"
    )

    foreach ($controlName in $additionalControls) {
        if (-not $global:Variables.Contains($controlName)) {
            $control = $Window.FindName($controlName)
            if ($control) {
                $global:Variables[$controlName] = $control
                Write-Log -Message "Zusätzliches Steuerelement '$controlName' gefunden und gebunden." -Level "DEBUG"
            }
        }
    }

    Write-Log -Message "Erweiterte GUI-Steuerelemente-Bindung abgeschlossen." -Level "DEBUG"
}

# Funktion zum Validieren aller Eingaben vor dem Onboarding
function Test-AllInputs {
    [CmdletBinding()]
    param()

    $validationErrors = @()

    try {
        # Tab 1 Validierungen
        $txtFirstName = $Window.FindName("txtFirstName")
        $txtLastName = $Window.FindName("txtLastName")

        if (-not $txtFirstName -or [string]::IsNullOrWhiteSpace($txtFirstName.Text)) {
            $validationErrors += "Vorname ist erforderlich"
        }

        if (-not $txtLastName -or [string]::IsNullOrWhiteSpace($txtLastName.Text)) {
            $validationErrors += "Nachname ist erforderlich"
        }

        # Tab 2 Validierungen
        $cmbOUPath = $Window.FindName("cmbOUPath")
        if (-not $cmbOUPath -or -not $cmbOUPath.SelectedItem) {
            $validationErrors += "OU-Pfad muss ausgewählt werden"
        }

        # Tab 3 Validierungen (nur wenn Mailbox erstellt werden soll)
        $chkCreateMailbox = $Window.FindName("chkCreateMailbox")
        if ($chkCreateMailbox -and $chkCreateMailbox.IsChecked) {
            $txtEmailAddress = $Window.FindName("txtEmailAddress")
            if (-not $txtEmailAddress -or [string]::IsNullOrWhiteSpace($txtEmailAddress.Text)) {
                $validationErrors += "E-Mail-Adresse ist erforderlich wenn Mailbox erstellt wird"
            }
            elseif (-not (Validate-EmailAddress -EmailAddress $txtEmailAddress.Text)) {
                $validationErrors += "E-Mail-Adresse hat ungültiges Format"
            }
        }

        if ($validationErrors.Count -gt 0) {
            $errorMessage = "Bitte korrigieren Sie folgende Fehler:`n`n" + ($validationErrors -join "`n")
            [System.Windows.MessageBox]::Show($errorMessage, "Validierungsfehler", "OK", "Warning")
            return $false
        }

        return $true
    }
    catch {
        Write-Log -Message "Fehler bei der Eingabevalidierung: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}
#endregion

#region Global Exception Handling and Resource Management

# Globale Exception-Handler für WPF-Anwendung
function Add-GlobalExceptionHandlers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )

    try {
        Write-Log -Message "Registriere globale Exception-Handler..." -Level "DEBUG"

        # Application-Level Exception Handler
        if ($null -ne [System.Windows.Application]::Current) {
            [System.Windows.Application]::Current.add_DispatcherUnhandledException({
                    param($eventSender, $eventData)

                    $errorMessage = "Unbehandelte Ausnahme in der Anwendung: $($eventArgs.Exception.Message)"
                    Write-Log -Message $errorMessage -Level "ERROR"
                    Write-Log -Message "Exception-Typ: $($eventArgs.Exception.GetType().Name)" -Level "ERROR"
                    Write-Log -Message "StackTrace: $($eventArgs.Exception.StackTrace)" -Level "ERROR"

                    # Spezielle Behandlung für Win32Exception (Resource exhaustion)
                    if ($eventArgs.Exception -is [System.ComponentModel.Win32Exception]) {
                        $win32Error = [System.ComponentModel.Win32Exception]$e.Exception
                        Write-Log -Message "Win32-Fehlercode: $($win32Error.ErrorCode) (0x$($win32Error.ErrorCode.ToString('X')))" -Level "ERROR"

                        if ($win32Error.ErrorCode -eq 1816) {
                            # Resource exhaustion error
                            Write-Log -Message "Ressourcen-Erschöpfung erkannt. Starte Cleanup..." -Level "WARN"
                            Invoke-ResourceCleanup

                            [System.Windows.MessageBox]::Show(
                                "Ein Systemressourcen-Fehler ist aufgetreten. Die Anwendung wird beendet und bereinigt.`n`nFehler: $($e.Exception.Message)",
                                "Systemressourcen-Fehler",
                                "OK",
                                "Error"
                            )
                            $e.Handled = $true
                            $Window.Close()
                            return
                        }
                    }

                    # Allgemeine Fehlerbehandlung
                    $userMessage = "Ein unerwarteter Fehler ist aufgetreten.`n`nMöchten Sie die Anwendung beenden?"
                    $result = [System.Windows.MessageBox]::Show(
                        "$userMessage`n`nFehler: $($e.Exception.Message)",
                        "Anwendungsfehler",
                        "YesNo",
                        "Error"
                    )

                    if ($result -eq "Yes") {
                        $e.Handled = $true
                        Invoke-ResourceCleanup
                        $Window.Close()
                    }
                    else {
                        $e.Handled = $true
                    }
                })
        }

        # Window-Level Exception Handler
        $Window.add_Closed({
                Write-Log -Message "Fenster wird geschlossen. Starte Cleanup..." -Level "INFO"
                Invoke-ResourceCleanup
            })

        Write-Log -Message "Globale Exception-Handler erfolgreich registriert." -Level "DEBUG"
    }
    catch {
        Write-Log -Message "Fehler beim Registrieren der Exception-Handler: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Ressourcen-Cleanup-Funktion
function Invoke-ResourceCleanup {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Starte Ressourcen-Cleanup..." -Level "INFO"

        # Event-Handler entfernen
        if ($global:Variables -and $global:Variables.Count -gt 0) {
            Write-Log -Message "Entferne Event-Handler..." -Level "DEBUG"
            # Hier können spezifische Event-Handler entfernt werden
            # Das ist wichtig um Memory-Leaks zu vermeiden
        }

        # Explizite Garbage Collection
        Write-Log -Message "Führe Garbage Collection aus..." -Level "DEBUG"
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()

        # WPF-spezifische Cleanup-Operationen
        if ($null -ne [System.Windows.Application]::Current) {
            Write-Log -Message "Bereinige WPF-Ressourcen..." -Level "DEBUG"
            [System.Windows.Application]::Current.Dispatcher.InvokeShutdown()
        }

        Write-Log -Message "Ressourcen-Cleanup abgeschlossen." -Level "INFO"
    }
    catch {
        Write-Log -Message "Fehler beim Ressourcen-Cleanup: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Funktion zur Überwachung der Systemressourcen
function Test-SystemResources {
    [CmdletBinding()]
    param()

    try {
        $process = Get-Process -Id $PID
        $handles = $process.HandleCount
        $workingSet = [math]::Round($process.WorkingSet64 / 1MB, 2)

        Write-Log -Message "Systemressourcen - Handles: $handles, Arbeitsspeicher: $workingSet MB" -Level "DEBUG"

        # Warnung bei hoher Handle-Anzahl
        if ($handles -gt 2000) {
            Write-Log -Message "Warnung: Hohe Anzahl von Handles erkannt ($handles). Cleanup empfohlen." -Level "WARN"
            return $false
        }

        # Warnung bei hohem Speicherverbrauch
        if ($workingSet -gt 500) {
            Write-Log -Message "Warnung: Hoher Speicherverbrauch erkannt ($workingSet MB). Cleanup empfohlen." -Level "WARN"
            return $false
        }

        return $true
    }
    catch {
        Write-Log -Message "Fehler bei der Ressourcen-Überwachung: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Sichere UI-Update-Funktion
function Invoke-UIUpdateSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$UpdateAction,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$DelayMs = 100
    )

    $retryCount = 0

    while ($retryCount -lt $MaxRetries) {
        try {
            # Prüfe Ressourcen vor UI-Update
            if (-not (Test-SystemResources)) {
                Write-Log -Message "Ressourcen-Warnung vor UI-Update. Führe Cleanup aus..." -Level "WARN"
                [System.GC]::Collect()
                Start-Sleep -Milliseconds $DelayMs
            }

            # Führe UI-Update aus
            & $UpdateAction
            return $true
        }
        catch [System.ComponentModel.Win32Exception] {
            $retryCount++
            Write-Log -Message "Win32Exception bei UI-Update (Versuch $retryCount/$MaxRetries): $($_.Exception.Message)" -Level "WARN"

            if ($retryCount -lt $MaxRetries) {
                # Cleanup und Retry
                [System.GC]::Collect()
                Start-Sleep -Milliseconds ($DelayMs * $retryCount)
            }
            else {
                Write-Log -Message "UI-Update nach $MaxRetries Versuchen fehlgeschlagen." -Level "ERROR"
                throw
            }
        }
        catch {
            Write-Log -Message "Unerwarteter Fehler bei UI-Update: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }

    return $false
}

#endregion

#region User Field Generation Functions
function Update-GeneratedUserFields {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Aktualisiere automatisch generierte Benutzerfelder..." -Level "DEBUG"

        # Hole die aktuellen Eingaben aus den Feldern
        $txtFirstName = $Window.FindName("txtFirstName")
        $txtLastName = $Window.FindName("txtLastName")
        $txtDisplayName = $Window.FindName("txtDisplayName")
        $txtSamAccountName = $Window.FindName("txtSamAccountName")
        $txtUPN = $Window.FindName("txtUPN")
        $txtEmail = $Window.FindName("txtEmail")

        if (-not $txtFirstName -or -not $txtLastName) {
            Write-Log -Message "Vor- oder Nachname-Felder nicht gefunden" -Level "DEBUG"
            return
        }

        $firstName = $txtFirstName.Text.Trim()
        $lastName = $txtLastName.Text.Trim()

        # Nur aktualisieren wenn beide Felder Inhalt haben
        if ([string]::IsNullOrWhiteSpace($firstName) -or [string]::IsNullOrWhiteSpace($lastName)) {
            Write-Log -Message "Vor- oder Nachname ist leer - überspringe Feldgenerierung" -Level "DEBUG"
            return
        }

        Write-Log -Message "Generiere Felder für: $firstName $lastName" -Level "DEBUG"

        # DisplayName generieren
        if ($txtDisplayName -and [string]::IsNullOrWhiteSpace($txtDisplayName.Text)) {
            $displayName = "$firstName $lastName"
            $txtDisplayName.Text = $displayName
            Write-Log -Message "DisplayName generiert: $displayName" -Level "DEBUG"
        }

        # SAM Account Name generieren
        if ($txtSamAccountName -and [string]::IsNullOrWhiteSpace($txtSamAccountName.Text)) {
            try {
                $namingConvention = Get-ConfigValue -Section "UserCreation" -Key "NamingConvention" -DefaultValue 1
                $samAccountName = New-SamAccountName -FirstName $firstName -LastName $lastName -NamingConvention $namingConvention
                $txtSamAccountName.Text = $samAccountName
                Write-Log -Message "SAM Account Name generiert: $samAccountName" -Level "DEBUG"
            }
            catch {
                Write-Log -Message "Fehler bei SAM Account Name Generierung: $($_.Exception.Message)" -Level "WARN"
            }
        }

        # UPN generieren
        if ($txtUPN -and [string]::IsNullOrWhiteSpace($txtUPN.Text)) {
            try {
                $upnFormat = Get-ConfigValue -Section "UserCreation" -Key "UPNFormat" -DefaultValue 1
                $upnSuffix = Get-ConfigValue -Section "ActiveDirectory" -Key "DefaultUPNSuffix" -DefaultValue $null
                if ([string]::IsNullOrWhiteSpace($upnSuffix)) {
                    $upnSuffix = Get-ConfigValue -Section "General" -Key "DomainName" -DefaultValue "domain.local"
                }

                $userPrincipalName = New-UserPrincipalName -FirstName $firstName -LastName $lastName -Domain $upnSuffix -NamingConvention $upnFormat
                $txtUPN.Text = $userPrincipalName
                Write-Log -Message "UPN generiert: $userPrincipalName" -Level "DEBUG"
            }
            catch {
                Write-Log -Message "Fehler bei UPN Generierung: $($_.Exception.Message)" -Level "WARN"
            }
        }

        # E-Mail-Adresse generieren
        if ($txtEmail -and [string]::IsNullOrWhiteSpace($txtEmail.Text)) {
            try {
                $emailDomain = Get-ConfigValue -Section "Exchange" -Key "DefaultDomain" -DefaultValue $null
                if ([string]::IsNullOrWhiteSpace($emailDomain)) {
                    $emailDomain = Get-ConfigValue -Section "General" -Key "DomainName" -DefaultValue "domain.local"
                }

                # Verwende SAM Account Name als Basis für E-Mail wenn verfügbar
                $emailLocalPart = if ($txtSamAccountName -and -not [string]::IsNullOrWhiteSpace($txtSamAccountName.Text)) {
                    $txtSamAccountName.Text
                }
                else {
                    "$($firstName.ToLower()).$($lastName.ToLower())"
                }

                # Entferne ungültige Zeichen für E-Mail
                $emailLocalPart = $emailLocalPart -replace '[^a-zA-Z0-9\.\-_]', ''

                $emailAddress = "$emailLocalPart@$emailDomain"

                # Validiere E-Mail-Format
                if (Test-EmailAddress -EmailAddress $emailAddress) {
                    $txtEmail.Text = $emailAddress
                    Write-Log -Message "E-Mail-Adresse generiert: $emailAddress" -Level "DEBUG"
                }
                else {
                    Write-Log -Message "Generierte E-Mail-Adresse hat ungültiges Format: $emailAddress" -Level "WARN"
                }
            }
            catch {
                Write-Log -Message "Fehler bei E-Mail-Generierung: $($_.Exception.Message)" -Level "WARN"
            }
        }

        # Abteilung basierte Aktualisierungen
        $cmbDepartment = $Window.FindName("cmbDepartment")
        if ($cmbDepartment -and $cmbDepartment.SelectedItem) {
            $selectedDepartment = $cmbDepartment.SelectedItem.ToString()
            Write-Log -Message "Aktualisiere Felder basierend auf Abteilung: $selectedDepartment" -Level "DEBUG"

            # OU-Dropdown in Tab 2 aktualisieren falls sichtbar
            try {
                $cmbOUPath = $Window.FindName("cmbOUPath")
                if ($cmbOUPath) {
                    Update-OUDropdownFromDepartment -OUComboBox $cmbOUPath -DepartmentName $selectedDepartment
                }
            }
            catch {
                Write-Log -Message "Fehler bei OU-Dropdown-Aktualisierung: $($_.Exception.Message)" -Level "DEBUG"
            }
        }

        Write-Log -Message "Automatische Feldgenerierung abgeschlossen" -Level "DEBUG"

    }
    catch {
        Write-Log -Message "Fehler bei der automatischen Feldgenerierung: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Reset-UserFields {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Setze Benutzerfelder zurück..." -Level "DEBUG"

        # Liste der Felder die zurückgesetzt werden sollen
        $fieldsToReset = @(
            "txtFirstName", "txtLastName", "txtDisplayName", "txtSamAccountName",
            "txtUPN", "txtEmail", "txtDescription", "txtPosition", "txtPhone",
            "txtMobile", "txtOffice", "txtLocation"
        )

        foreach ($fieldName in $fieldsToReset) {
            $field = $Window.FindName($fieldName)
            if ($field -and $field.GetType().Name -eq "TextBox") {
                $field.Text = ""
            }
        }

        # ComboBoxes zurücksetzen
        $comboBoxesToReset = @("cmbDepartment")
        foreach ($comboName in $comboBoxesToReset) {
            $combo = $Window.FindName($comboName)
            if ($combo) {
                $combo.SelectedIndex = -1
            }
        }

        # DatePicker zurücksetzen
        $dtpStartDate = $Window.FindName("dtpStartDate")
        if ($dtpStartDate) {
            $dtpStartDate.SelectedDate = Get-Date
        }

        $dtpEndDate = $Window.FindName("dtpEndDate")
        if ($dtpEndDate) {
            $dtpEndDate.SelectedDate = $null
        }

        # Checkboxes zurücksetzen
        $checkBoxesToReset = @("chkIsTemporary", "chkMustChangePassword", "chkPasswordNeverExpires", "chkAccountDisabled")
        foreach ($checkName in $checkBoxesToReset) {
            $check = $Window.FindName($checkName)
            if ($check) {
                $check.IsChecked = $false
            }
        }

        Write-Log -Message "Benutzerfelder erfolgreich zurückgesetzt" -Level "INFO"

    }
    catch {
        Write-Log -Message "Fehler beim Zurücksetzen der Benutzerfelder: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Test-UserFieldsInput {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Validiere Benutzereingaben..." -Level "DEBUG"

        $validationErrors = @()

        # Vorname validieren
        $txtFirstName = $Window.FindName("txtFirstName")
        if (-not $txtFirstName -or [string]::IsNullOrWhiteSpace($txtFirstName.Text)) {
            $validationErrors += "Vorname ist erforderlich"
        }
        elseif ($txtFirstName.Text.Length -lt 2) {
            $validationErrors += "Vorname muss mindestens 2 Zeichen lang sein"
        }
        elseif ($txtFirstName.Text -notmatch '^[a-zA-ZäöüÄÖÜß\s\-\.]+$') {
            $validationErrors += "Vorname enthält ungültige Zeichen"
        }

        # Nachname validieren
        $txtLastName = $Window.FindName("txtLastName")
        if (-not $txtLastName -or [string]::IsNullOrWhiteSpace($txtLastName.Text)) {
            $validationErrors += "Nachname ist erforderlich"
        }
        elseif ($txtLastName.Text.Length -lt 2) {
            $validationErrors += "Nachname muss mindestens 2 Zeichen lang sein"
        }
        elseif ($txtLastName.Text -notmatch '^[a-zA-ZäöüÄÖÜß\s\-\.]+$') {
            $validationErrors += "Nachname enthält ungültige Zeichen"
        }

        # E-Mail validieren falls vorhanden
        $txtEmail = $Window.FindName("txtEmail")
        if ($txtEmail -and -not [string]::IsNullOrWhiteSpace($txtEmail.Text)) {
            if (-not (Test-EmailAddress -EmailAddress $txtEmail.Text)) {
                $validationErrors += "E-Mail-Adresse hat ungültiges Format"
            }
        }

        # SAM Account Name validieren
        $txtSamAccountName = $Window.FindName("txtSamAccountName")
        if ($txtSamAccountName -and -not [string]::IsNullOrWhiteSpace($txtSamAccountName.Text)) {
            if ($txtSamAccountName.Text.Length -gt 20) {
                $validationErrors += "SAM Account Name darf maximal 20 Zeichen lang sein"
            }
            if ($txtSamAccountName.Text -notmatch '^[a-zA-Z0-9\.\-_]+$') {
                $validationErrors += "SAM Account Name enthält ungültige Zeichen"
            }
        }

        # UPN validieren
        $txtUPN = $Window.FindName("txtUPN")
        if ($txtUPN -and -not [string]::IsNullOrWhiteSpace($txtUPN.Text)) {
            if (-not (Test-UPNFormat -UPN $txtUPN.Text)) {
                $validationErrors += "UPN hat ungültiges Format"
            }
        }

        # Telefonnummer validieren falls vorhanden
        $txtPhone = $Window.FindName("txtPhone")
        if ($txtPhone -and -not [string]::IsNullOrWhiteSpace($txtPhone.Text)) {
            if ($txtPhone.Text -notmatch '^[\+\d\s\-\(\)\/]+$') {
                $validationErrors += "Telefonnummer enthält ungültige Zeichen"
            }
        }

        # Mobile validieren falls vorhanden
        $txtMobile = $Window.FindName("txtMobile")
        if ($txtMobile -and -not [string]::IsNullOrWhiteSpace($txtMobile.Text)) {
            if ($txtMobile.Text -notmatch '^[\+\d\s\-\(\)\/]+$') {
                $validationErrors += "Mobilnummer enthält ungültige Zeichen"
            }
        }

        # Temporärer Benutzer Logik validieren
        $chkIsTemporary = $Window.FindName("chkIsTemporary")
        $dtpEndDate = $Window.FindName("dtpEndDate")
        if ($chkIsTemporary -and $chkIsTemporary.IsChecked -and $dtpEndDate) {
            if (-not $dtpEndDate.SelectedDate) {
                $validationErrors += "Enddatum ist erforderlich für temporäre Benutzer"
            }
            elseif ($dtpEndDate.SelectedDate -le (Get-Date)) {
                $validationErrors += "Enddatum muss in der Zukunft liegen"
            }
        }

        if ($validationErrors.Count -gt 0) {
            $errorMessage = "Validierungsfehler gefunden:`n`n" + ($validationErrors -join "`n")
            Write-Log -Message "Validierungsfehler: $($validationErrors -join '; ')" -Level "WARN"
            [System.Windows.MessageBox]::Show($errorMessage, "Eingabefehler", "OK", "Warning")
            return $false
        }

        Write-Log -Message "Benutzereingaben erfolgreich validiert" -Level "DEBUG"
        return $true

    }
    catch {
        Write-Log -Message "Fehler bei der Eingabevalidierung: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-UserDataFromGUI {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Sammle Benutzerdaten aus GUI..." -Level "DEBUG"

        # Hilfsfunktion für sicheren Zugriff auf GUI-Elemente
        function Get-SafeControlValue {
            param($ControlName, $Property = "Text", $Default = "")

            if ($global:Variables.ContainsKey($ControlName) -and $global:Variables[$ControlName]) {
                try {
                    $control = $global:Variables[$ControlName]
                    switch ($Property) {
                        "Text" {
                            if ($control.Text) { return $control.Text.Trim() } else { return $Default }
                        }
                        "SelectedItem" {
                            if ($control.SelectedItem) { return $control.SelectedItem.ToString() } else { return $Default }
                        }
                        "SelectedDate" {
                            if ($control.SelectedDate) { return $control.SelectedDate } else { return $null }
                        }
                        "IsChecked" {
                            if ($control.IsChecked -ne $null) { return $control.IsChecked } else { return $false }
                        }
                        "SelectedItemPath" {
                            if ($control.SelectedItem -and $control.SelectedItem.Path) { return $control.SelectedItem.Path } else { return $Default }
                        }
                        default { return $Default }
                    }
                }
                catch {
                    Write-Log -Message "Fehler beim Abrufen des Wertes für $ControlName : $($_.Exception.Message)" -Level "WARN"
                    return $Default
                }
            }
            else {
                return $Default
            }
        }

        # Erstelle UserData-Objekt mit allen GUI-Eingaben
        $userData = [PSCustomObject]@{
            FirstName            = Get-SafeControlValue -ControlName "txtFirstName"
            LastName             = Get-SafeControlValue -ControlName "txtLastName"
            DisplayName          = Get-SafeControlValue -ControlName "txtDisplayName"
            SamAccountName       = Get-SafeControlValue -ControlName "txtSamAccountName"
            UserPrincipalName    = Get-SafeControlValue -ControlName "txtUPN"
            EmailAddress         = Get-SafeControlValue -ControlName "txtEmail"
            Description          = Get-SafeControlValue -ControlName "txtDescription"
            Position             = Get-SafeControlValue -ControlName "txtPosition"
            Department           = Get-SafeControlValue -ControlName "cmbDepartment" -Property "SelectedItem"
            Phone                = Get-SafeControlValue -ControlName "txtPhone"
            Mobile               = Get-SafeControlValue -ControlName "txtMobile"
            Office               = Get-SafeControlValue -ControlName "txtOffice"
            Location             = Get-SafeControlValue -ControlName "txtLocation"
            StartDate            = Get-SafeControlValue -ControlName "dtpStartDate" -Property "SelectedDate"
            IsTemporary          = Get-SafeControlValue -ControlName "chkIsTemporary" -Property "IsChecked"
            EndDate              = Get-SafeControlValue -ControlName "dtpEndDate" -Property "SelectedDate"
            MustChangePassword   = Get-SafeControlValue -ControlName "chkMustChangePassword" -Property "IsChecked" -Default $true
            PasswordNeverExpires = Get-SafeControlValue -ControlName "chkPasswordNeverExpires" -Property "IsChecked"
            CannotChangePassword = Get-SafeControlValue -ControlName "chkCannotChangePassword" -Property "IsChecked"
            AccountDisabled      = Get-SafeControlValue -ControlName "chkAccountDisabled" -Property "IsChecked"
            OUPath               = Get-SafeControlValue -ControlName "cmbOUPath" -Property "SelectedItemPath"
            Manager              = Get-SafeControlValue -ControlName "txtManager"
            CreateHomeDirectory  = Get-SafeControlValue -ControlName "chkCreateHomeDirectory" -Property "IsChecked"
            HomeDirectoryPath    = Get-SafeControlValue -ControlName "txtHomeDirectoryPath"
            CreateProfilePath    = Get-SafeControlValue -ControlName "chkCreateProfilePath" -Property "IsChecked"
            ProfilePath          = Get-SafeControlValue -ControlName "txtProfilePath"
            CreateMailbox        = Get-SafeControlValue -ControlName "chkCreateMailbox" -Property "IsChecked"
            MailboxDatabase      = Get-SafeControlValue -ControlName "cmbMailboxDatabase" -Property "SelectedItem"
            AssignLicense        = Get-SafeControlValue -ControlName "chkAssignLicense" -Property "IsChecked"
            LicenseType          = Get-SafeControlValue -ControlName "cmbLicenseType" -Property "SelectedItem"
        }

        # Sammle ausgewählte Gruppen
        if ($global:Variables.ContainsKey('lstSelectedGroups') -and $global:Variables['lstSelectedGroups']) {
            $userData | Add-Member -NotePropertyName "SelectedGroups" -NotePropertyValue @($global:Variables['lstSelectedGroups'].Items)
        }
        else {
            $userData | Add-Member -NotePropertyName "SelectedGroups" -NotePropertyValue @()
        }

        # Entferne leere String-Werte und setze sie auf $null
        $properties = $userData.PSObject.Properties | Where-Object { $_.Value -is [string] -and [string]::IsNullOrWhiteSpace($_.Value) }
        foreach ($prop in $properties) {
            $userData.($prop.Name) = $null
        }

        Write-Log -Message "Benutzerdaten erfolgreich aus GUI gesammelt: $($userData.FirstName) $($userData.LastName)" -Level "DEBUG"
        Write-Log -Message "Ausgewählte Gruppen: $($userData.SelectedGroups.Count)" -Level "DEBUG"
        return $userData

    }
    catch {
        Write-Log -Message "Fehler beim Sammeln der Benutzerdaten aus GUI: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Set-UserDataToGUI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$UserData
    )

    try {
        Write-Log -Message "Setze Benutzerdaten in GUI für: $($UserData.FirstName) $($UserData.LastName)" -Level "DEBUG"

        # Text-Felder setzen
        $textFields = @{
            "txtFirstName"         = $UserData.FirstName
            "txtLastName"          = $UserData.LastName
            "txtDisplayName"       = $UserData.DisplayName
            "txtSamAccountName"    = $UserData.SamAccountName
            "txtUPN"               = $UserData.UserPrincipalName
            "txtEmail"             = $UserData.EmailAddress
            "txtDescription"       = $UserData.Description
            "txtPosition"          = $UserData.Position
            "txtPhone"             = $UserData.Phone
            "txtMobile"            = $UserData.Mobile
            "txtOffice"            = $UserData.Office
            "txtLocation"          = $UserData.Location
            "txtManager"           = $UserData.Manager
            "txtHomeDirectoryPath" = $UserData.HomeDirectoryPath
            "txtProfilePath"       = $UserData.ProfilePath
        }

        foreach ($fieldName in $textFields.Keys) {
            $field = $Window.FindName($fieldName)
            if ($field -and $textFields[$fieldName]) {
                $field.Text = $textFields[$fieldName]
            }
        }

        # ComboBox-Felder setzen
        $cmbDepartment = $Window.FindName("cmbDepartment")
        if ($cmbDepartment -and $UserData.Department) {
            $cmbDepartment.SelectedItem = $UserData.Department
        }

        # DatePicker setzen
        $dtpStartDate = $Window.FindName("dtpStartDate")
        if ($dtpStartDate -and $UserData.StartDate) {
            $dtpStartDate.SelectedDate = $UserData.StartDate
        }

        $dtpEndDate = $Window.FindName("dtpEndDate")
        if ($dtpEndDate -and $UserData.EndDate) {
            $dtpEndDate.SelectedDate = $UserData.EndDate
        }

        # CheckBoxes setzen
        $checkBoxes = @{
            "chkIsTemporary"          = $UserData.IsTemporary
            "chkMustChangePassword"   = $UserData.MustChangePassword
            "chkPasswordNeverExpires" = $UserData.PasswordNeverExpires
            "chkCannotChangePassword" = $UserData.CannotChangePassword
            "chkAccountDisabled"      = $UserData.AccountDisabled
            "chkCreateHomeDirectory"  = $UserData.CreateHomeDirectory
            "chkCreateProfilePath"    = $UserData.CreateProfilePath
            "chkCreateMailbox"        = $UserData.CreateMailbox
            "chkAssignLicense"        = $UserData.AssignLicense
        }

        foreach ($checkName in $checkBoxes.Keys) {
            $check = $Window.FindName($checkName)
            if ($check) {
                $check.IsChecked = $checkBoxes[$checkName]
            }
        }

        Write-Log -Message "Benutzerdaten erfolgreich in GUI gesetzt" -Level "DEBUG"

    }
    catch {
        Write-Log -Message "Fehler beim Setzen der Benutzerdaten in GUI: $($_.Exception.Message)" -Level "ERROR"
    }
}
#endregion

#region Add-ValidationEventHandlers Function
function Add-ValidationEventHandlers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Tab
    )

    try {
        Write-Log -Message "Füge Validierungs-Event-Handler für Tab $Tab hinzu..." -Level "DEBUG"

        switch ($Tab) {
            1 {
                # Tab 1: Benutzerdaten Validierung
                $txtFirstName = $Window.FindName("txtFirstName")
                $txtLastName = $Window.FindName("txtLastName")
                $txtEmail = $Window.FindName("txtEmail")
                $txtSamAccountName = $Window.FindName("txtSamAccountName")
                $txtUPN = $Window.FindName("txtUPN")
                $txtPhone = $Window.FindName("txtPhone")
                $txtMobile = $Window.FindName("txtMobile")

                # Vorname Validierung
                if ($txtFirstName) {
                    $txtFirstName.add_LostFocus({
                            $text = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($text)) {
                                if ($text -notmatch '^[a-zA-ZäöüÄÖÜß\s\-\.]+$') {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $this.ToolTip = "Vorname enthält ungültige Zeichen"
                                    Write-Log -Message "Ungültiger Vorname eingegeben: $text" -Level "DEBUG"
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                    $this.ToolTip = $null
                                }
                            }
                        })
                }

                # Nachname Validierung
                if ($txtLastName) {
                    $txtLastName.add_LostFocus({
                            $text = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($text)) {
                                if ($text -notmatch '^[a-zA-ZäöüÄÖÜß\s\-\.]+$') {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $this.ToolTip = "Nachname enthält ungültige Zeichen"
                                    Write-Log -Message "Ungültiger Nachname eingegeben: $text" -Level "DEBUG"
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                    $this.ToolTip = $null
                                }
                            }
                        })
                }

                # E-Mail Validierung
                if ($txtEmail) {
                    $txtEmail.add_LostFocus({
                            $email = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($email)) {
                                if (Test-EmailAddress -EmailAddress $email) {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                    $this.ToolTip = $null
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $this.ToolTip = "E-Mail-Adresse hat ungültiges Format"
                                    Write-Log -Message "Ungültige E-Mail-Adresse eingegeben: $email" -Level "DEBUG"
                                }
                            }
                        })
                }

                # SAM Account Name Validierung
                if ($txtSamAccountName) {
                    $txtSamAccountName.add_LostFocus({
                            $samName = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($samName)) {
                                if ($samName.Length -gt 20) {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $this.ToolTip = "SAM Account Name darf maximal 20 Zeichen lang sein"
                                }
                                elseif ($samName -notmatch '^[a-zA-Z0-9\.\-_]+$') {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $this.ToolTip = "SAM Account Name enthält ungültige Zeichen"
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                    $this.ToolTip = $null
                                }
                            }
                        })
                }

                # UPN Validierung
                if ($txtUPN) {
                    $txtUPN.add_LostFocus({
                            $upn = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($upn)) {
                                if (Test-UPNFormat -UPN $upn) {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                    $this.ToolTip = $null
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $this.ToolTip = "UPN hat ungültiges Format"
                                }
                            }
                        })
                }

                # Telefon Validierung
                if ($txtPhone) {
                    $txtPhone.add_LostFocus({
                            $phone = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($phone)) {
                                if ($phone -notmatch '^[\+\d\s\-\(\)\/]+$') {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $this.ToolTip = "Telefonnummer enthält ungültige Zeichen"
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                    $this.ToolTip = $null
                                }
                            }
                        })
                }

                # Mobile Validierung
                if ($txtMobile) {
                    $txtMobile.add_LostFocus({
                            $mobile = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($mobile)) {
                                if ($mobile -notmatch '^[\+\d\s\-\(\)\/]+$') {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $this.ToolTip = "Mobilnummer enthält ungültige Zeichen"
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                    $this.ToolTip = $null
                                }
                            }
                        })
                }
            }

            2 {
                # Tab 2: AD-Einstellungen Validierung
                $txtHomeDirectoryPath = $Window.FindName("txtHomeDirectoryPath")
                $txtProfilePath = $Window.FindName("txtProfilePath")
                $txtCustomOU = $Window.FindName("txtCustomOU")

                # Home Directory Pfad Validierung
                if ($txtHomeDirectoryPath) {
                    $txtHomeDirectoryPath.add_LostFocus({
                            $path = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($path)) {
                                # Grundlegende UNC-Pfad Validierung
                                if ($path -match '^\\\\[^\\]+\\[^\\]+') {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                    $this.ToolTip = $null
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Orange
                                    $this.ToolTip = "Empfohlenes Format: \\\\server\\freigabe\\pfad"
                                }
                            }
                        })
                }

                # Profile Pfad Validierung
                if ($txtProfilePath) {
                    $txtProfilePath.add_LostFocus({
                            $path = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($path)) {
                                # Grundlegende UNC-Pfad Validierung
                                if ($path -match '^\\\\[^\\]+\\[^\\]+') {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                    $this.ToolTip = $null
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Orange
                                    $this.ToolTip = "Empfohlenes Format: \\\\server\\freigabe\\pfad"
                                }
                            }
                        })
                }

                # Custom OU Validierung
                if ($txtCustomOU) {
                    $txtCustomOU.add_LostFocus({
                            $ou = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($ou)) {
                                # Grundlegende DN-Format Validierung
                                if ($ou -match '^(OU|CN)=.+,DC=.+') {
                                    # Teste ob OU existiert
                                    if (Test-OUPathValidity -OUPath $ou) {
                                        $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                        $this.ToolTip = "OU wurde erfolgreich validiert"
                                    }
                                    else {
                                        $this.BorderBrush = [System.Windows.Media.Brushes]::Orange
                                        $this.ToolTip = "OU konnte nicht validiert werden"
                                    }
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $this.ToolTip = "Ungültiges OU-Format. Erwartet: OU=Name,DC=domain,DC=com"
                                }
                            }
                        })
                }
            }

            3 {
                # Tab 3: Exchange/M365 Validierung
                $txtEmailAddress = $Window.FindName("txtEmailAddress")

                # E-Mail-Adresse Validierung für Exchange
                if ($txtEmailAddress) {
                    $txtEmailAddress.add_LostFocus({
                            $email = $this.Text.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($email)) {
                                if (Test-EmailAddress -EmailAddress $email) {
                                    # Prüfe Verfügbarkeit
                                    $availability = Test-EmailAddressAvailability -EmailAddress $email
                                    if ($availability.Available) {
                                        $this.BorderBrush = [System.Windows.Media.Brushes]::Green
                                        $this.ToolTip = "E-Mail-Adresse ist verfügbar"
                                    }
                                    else {
                                        $this.BorderBrush = [System.Windows.Media.Brushes]::Orange
                                        $this.ToolTip = "E-Mail-Adresse ist bereits vergeben"
                                    }
                                }
                                else {
                                    $this.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $this.ToolTip = "E-Mail-Adresse hat ungültiges Format"
                                }
                            }
                        })
                }
            }

            4 {
                # Tab 4: Gruppen Validierung
                Write-Log -Message "Gruppen-Validierung wird über DataGrid-Events verwaltet" -Level "DEBUG"
                # Gruppen-Validierung erfolgt hauptsächlich über DataGrid-Events
                # und wird in den entsprechenden DataGrid-Event-Handlern verwaltet
            }

            5 {
                # Tab 5: Systeme Validierung
                Write-Log -Message "System-Validierung wird über TabControl-Events verwaltet" -Level "DEBUG"
                # System-Validierung erfolgt hauptsächlich über TabControl-Events
                # und wird in den entsprechenden System-Event-Handlern verwaltet
            }

            6 {
                # Tab 6: Weitere Services Validierung
                Write-Log -Message "Services-Validierung wird über DataGrid-Events verwaltet" -Level "DEBUG"
                # Services-Validierung erfolgt hauptsächlich über DataGrid-Events
                # und wird in den entsprechenden Service-Event-Handlern verwaltet
            }

            7 {
                # Tab 7: Zusammenfassung - keine spezielle Validierung nötig
                Write-Log -Message "Tab 7 benötigt keine spezielle Validierung" -Level "DEBUG"
            }

            default {
                Write-Log -Message "Unbekannter Tab für Validierung: $Tab" -Level "WARN"
            }
        }

        Write-Log -Message "Validierungs-Event-Handler für Tab $Tab erfolgreich hinzugefügt" -Level "DEBUG"

    }
    catch {
        Write-Log -Message "Fehler beim Hinzufügen der Validierungs-Event-Handler für Tab $Tab : $($_.Exception.Message)" -Level "ERROR"
    }
}

function Reset-ValidationStyles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Tab = 0
    )

    try {
        Write-Log -Message "Setze Validierungs-Styles zurück..." -Level "DEBUG"

        # Alle TextBox-Felder zurücksetzen
        $textBoxFields = @(
            "txtFirstName", "txtLastName", "txtEmail", "txtSamAccountName", "txtUPN",
            "txtPhone", "txtMobile", "txtHomeDirectoryPath", "txtProfilePath",
            "txtCustomOU", "txtEmailAddress"
        )

        foreach ($fieldName in $textBoxFields) {
            $field = $Window.FindName($fieldName)
            if ($field -and $field.GetType().Name -eq "TextBox") {
                $field.BorderBrush = [System.Windows.Media.Brushes]::LightGray
                $field.ToolTip = $null
            }
        }

        Write-Log -Message "Validierungs-Styles erfolgreich zurückgesetzt" -Level "DEBUG"

    }
    catch {
        Write-Log -Message "Fehler beim Zurücksetzen der Validierungs-Styles: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Show-ValidationSummary {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Erstelle Validierungs-Zusammenfassung..." -Level "DEBUG"

        $validationErrors = @()
        $validationWarnings = @()

        # Sammle alle Felder mit Validierungsfehlern
        $textBoxFields = @(
            "txtFirstName", "txtLastName", "txtEmail", "txtSamAccountName", "txtUPN",
            "txtPhone", "txtMobile", "txtHomeDirectoryPath", "txtProfilePath",
            "txtCustomOU", "txtEmailAddress"
        )

        foreach ($fieldName in $textBoxFields) {
            $field = $Window.FindName($fieldName)
            if ($field -and $field.GetType().Name -eq "TextBox") {
                if ($field.BorderBrush -eq [System.Windows.Media.Brushes]::Red) {
                    $validationErrors += "$fieldName : $($field.ToolTip)"
                }
                elseif ($field.BorderBrush -eq [System.Windows.Media.Brushes]::Orange) {
                    $validationWarnings += "$fieldName : $($field.ToolTip)"
                }
            }
        }

        $summary = @"
Validierungs-Zusammenfassung:
=============================

Fehler ($($validationErrors.Count)):
$($validationErrors -join "`n")

Warnungen ($($validationWarnings.Count)):
$($validationWarnings -join "`n")

Status: $(if ($validationErrors.Count -eq 0) { "Bereit für Onboarding" } else { "Korrekturen erforderlich" })
"@

        Write-Log -Message "Validierungs-Zusammenfassung erstellt: $($validationErrors.Count) Fehler, $($validationWarnings.Count) Warnungen" -Level "INFO"
        return $summary

    }
    catch {
        Write-Log -Message "Fehler beim Erstellen der Validierungs-Zusammenfassung: $($_.Exception.Message)" -Level "ERROR"
        return "Fehler beim Erstellen der Validierungs-Zusammenfassung"
    }
}

#region Onboarding Workflow Execution
function Start-OnboardingWorkflow {
    [CmdletBinding()]
    param()

    Write-Log -Message "Starte den Onboarding-Workflow..." -Level "INFO"

    # GUI-Elemente für Fortschrittsanzeige holen
    $progressBar = $Window.FindName("progressBarOnboarding")
    $lblProgress = $Window.FindName("lblProgress")
    $btnExecute = $Window.FindName("btnExecuteOnboarding")

    try {
        # 1. GUI-Eingaben validieren
        if (-not (Validate-AllInputs)) {
            Write-Log -Message "Validierung fehlgeschlagen. Onboarding-Prozess abgebrochen." -Level "WARN"
            [System.Windows.MessageBox]::Show("Bitte korrigieren Sie die Fehler in den Eingabefeldern, bevor Sie fortfahren.", "Validierungsfehler", "OK", "Warning")
            return
        }

        # GUI für Ausführung vorbereiten
        $btnExecute.IsEnabled = $false
        $progressBar.Visibility = 'Visible'
        $progressBar.Value = 0
        $lblProgress.Content = "Sammle Benutzerdaten..."

        # UI-Update mit Resource-Management
        Invoke-UIUpdateSafe {
            $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
        }

        # Ressourcen-Check vor Start
        if (-not (Test-SystemResources)) {
            Write-Log -Message "Ressourcen-Warnung vor Onboarding-Start" -Level "WARN"
            [System.GC]::Collect()
        }


        # 2. Daten aus der GUI sammeln
        $userData = Get-UserDataFromGUI
        if (-not $userData) {
            throw "Fehler beim Sammeln der Benutzerdaten aus der GUI."
        }
        Write-Log -Message "Benutzerdaten für $($userData.FirstName) $($userData.LastName) gesammelt." -Level "INFO"
        $progressBar.Value = 10
        $lblProgress.Content = "Benutzerdaten gesammelt."
        Invoke-UIUpdateSafe {
            $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
        }

        # 3. Active Directory Benutzer erstellen
        $lblProgress.Content = "Erstelle Active Directory Benutzer..."
        Invoke-UIUpdateSafe {
            $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
        }
        $adResult = New-ADUserAccount -UserData $userData
        if (-not $adResult.Success) {
            throw "Fehler bei der AD-Benutzererstellung: $($adResult.Message)"
        }
        $progressBar.Value = 30
        $lblProgress.Content = "AD-Benutzer erfolgreich erstellt: $($adResult.SamAccountName)"
        Write-Log -Message "AD-Benutzer erfolgreich erstellt: $($adResult.SamAccountName)" -Level "INFO"
        Invoke-UIUpdateSafe {
            $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
        }

        # 4. ADSync auslösen (falls konfiguriert)
        $lblProgress.Content = "Starte AD-Synchronisation..."
        Invoke-UIUpdateSafe {
            $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
        }

        # Periodische Ressourcen-Überprüfung
        if (-not (Test-SystemResources)) {
            Write-Log -Message "Ressourcen-Cleanup während ADSync erforderlich" -Level "INFO"
            [System.GC]::Collect()
        }

        $syncResult = Initialize-ADSyncIntegration
        if (-not $syncResult.Success) {
            Write-Log -Message "ADSync fehlgeschlagen oder übersprungen: $($syncResult.Message)" -Level "WARN"
        }
        $progressBar.Value = 50
        $lblProgress.Content = "AD-Synchronisation abgeschlossen."
        Invoke-UIUpdateSafe {
            $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
        }

        # 5. M365-Aufgaben (Mailbox, Lizenz)
        if ($userData.CreateMailbox) {
            $lblProgress.Content = "Erstelle M365-Mailbox..."
            Invoke-UIUpdateSafe {
                $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
            }
            # Prüfe ob die Funktion verfügbar ist
            if (Get-Command -Name New-M365Mailbox -ErrorAction SilentlyContinue) {
                $mailboxResult = New-M365Mailbox -UserData @{ Email = $userData.EmailAddress; DisplayName = $userData.DisplayName }
                if (-not $mailboxResult.Success) {
                    Write-Log -Message "Fehler bei Mailbox-Erstellung: $($mailboxResult.Message)" -Level "WARN"
                }
            }
            else {
                Write-Log -Message "M365-Mailbox-Funktion nicht verfügbar" -Level "WARN"
            }
        }
        if ($userData.AssignLicense -and $userData.LicenseType) {
            $lblProgress.Content = "Weise M365-Lizenz zu..."
            Invoke-UIUpdateSafe {
                $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
            }
            # Prüfe ob die Funktion verfügbar ist
            if (Get-Command -Name Set-M365License -ErrorAction SilentlyContinue) {
                $licenseResult = Set-M365License -UserPrincipalName $adResult.UserPrincipalName -LicenseSku $userData.LicenseType
                if (-not $licenseResult.Success) {
                    Write-Log -Message "Fehler bei Lizenzzuweisung: $($licenseResult.Message)" -Level "WARN"
                }
            }
            else {
                Write-Log -Message "M365-Lizenz-Funktion nicht verfügbar" -Level "WARN"
            }
        }
        $progressBar.Value = 70
        $lblProgress.Content = "M365-Aufgaben abgeschlossen."
        Invoke-UIUpdateSafe {
            $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
        }

        # 6. Telefonie-Integration
        $lblProgress.Content = "Initialisiere Telefonie-Integration..."
        Invoke-UIUpdateSafe {
            $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
        }
        $telephonyResult = Initialize-TelephonyIntegration -UserData $userData
        if (-not $telephonyResult.Success) {
            Write-Log -Message "Fehler bei Telefonie-Integration: $($telephonyResult.Message)" -Level "WARN"
        }
        $progressBar.Value = 90
        $lblProgress.Content = "Telefonie-Integration abgeschlossen."
        Invoke-UIUpdateSafe {
            $Window.Dispatcher.Invoke([System.Action] {}, "Normal")
        }

        # 7. Workflow abschließen
        $progressBar.Value = 100
        $lblProgress.Content = "Onboarding-Prozess erfolgreich abgeschlossen!"
        $lblProgress.Foreground = [System.Windows.Media.Brushes]::Green
        Write-Log -Message "Onboarding-Workflow für $($userData.FirstName) $($userData.LastName) erfolgreich abgeschlossen." -Level "INFO"

        # Final resource cleanup
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        [System.Windows.MessageBox]::Show("Der Onboarding-Prozess wurde erfolgreich abgeschlossen.", "Erfolg", "OK", "Information")

    }
    catch {
        $errorMessage = "Ein Fehler ist im Onboarding-Workflow aufgetreten: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        $lblProgress.Content = "Fehler: $($_.Exception.Message)"
        $lblProgress.Foreground = [System.Windows.Media.Brushes]::Red
        [System.Windows.MessageBox]::Show($errorMessage, "Workflow-Fehler", "OK", "Error")
    }
    finally {
        # GUI-Steuerelemente zurücksetzen
        $btnExecute.IsEnabled = $true
        $progressBar.Visibility = 'Collapsed'
    }
}

#endregion
#region Onboarding Summary and Execution

function New-OnboardingSummary {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Generiere Onboarding-Zusammenfassung..." -Level "DEBUG"
        $userData = Get-UserDataFromGUI

        if (-not $userData) {
            return "Fehler: Benutzerdaten konnten nicht geladen werden."
        }

        $summary = @"
Onboarding-Zusammenfassung für: $($userData.FirstName) $($userData.LastName)
=======================================================

**1. Benutzerdaten:**
- Vorname: $($userData.FirstName)
- Nachname: $($userData.LastName)
- Anzeigename: $($userData.DisplayName)
- Abteilung: $($userData.Department)
- Position: $($userData.Position)
- Startdatum: $($userData.StartDate.ToString('dd.MM.yyyy'))
- Temporär: $(if ($userData.IsTemporary) { "Ja, bis $($userData.EndDate.ToString('dd.MM.yyyy'))" } else { "Nein" })

**2. Active Directory:**
- SAM Account Name: $($userData.SamAccountName)
- User Principal Name: $($userData.UserPrincipalName)
- Ziel-OU: $($userData.OUPath)
- Manager: $($userData.Manager)
- Passwort bei Anmeldung ändern: $($userData.MustChangePassword)
- Home-Verzeichnis erstellen: $(if ($userData.CreateHomeDirectory) { "Ja, unter $($userData.HomeDirectoryPath)" } else { "Nein" })
- Profilpfad erstellen: $(if ($userData.CreateProfilePath) { "Ja, unter $($userData.ProfilePath)" } else { "Nein" })

**3. Exchange / Microsoft 365:**
- Mailbox erstellen: $(if ($userData.CreateMailbox) { "Ja, für $($userData.EmailAddress)" } else { "Nein" })
- Lizenz zuweisen: $(if ($userData.AssignLicense) { "Ja, Lizenz: $($userData.LicenseType)" } else { "Nein" })

**4. Gruppen:**
- AD-Gruppen: (Hier Gruppen auflisten)
- M365-Gruppen: (Hier Gruppen auflisten)

**5. Telefonie (Starface):**
- Starface-Benutzer erstellen: $(if ((Get-ConfigValue -Section "Starface" -Key "Enabled") -eq $true) { "Ja" } else { "Nein" })

**6. Weitere Systeme:**
- ERP/CRM-Zugänge: (Hier Zugänge auflisten)
- Entwickler-Tools: (Hier Tools auflisten)

Bitte überprüfen Sie alle Angaben sorgfältig, bevor Sie den Onboarding-Prozess starten.
"@

        return $summary
    }
    catch {
        $errorMessage = "Fehler beim Generieren der Zusammenfassung: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        return $errorMessage
    }
}

function Start-OnboardingProcessGUI {
    [CmdletBinding()]
    param()

    try {
        $confirmResult = [System.Windows.MessageBox]::Show(
            "Möchten Sie den Onboarding-Prozess mit den angezeigten Daten jetzt starten?",
            "Onboarding bestätigen",
            "YesNo",
            "Question"
        )

        if ($confirmResult -eq "Yes") {
            # Starte den Workflow in einem neuen Runspace, um die GUI nicht zu blockieren
            $runspace = [runspacefactory]::CreateRunspace()
            $runspace.ApartmentState = "STA"
            $runspace.ThreadOptions = "ReuseThread"
            $runspace.Open()

            # Übergebe notwendige Variablen an den Runspace
            $runspace.SessionStateProxy.SetVariable("Window", $Window)
            $runspace.SessionStateProxy.SetVariable("global:Config", $global:Config)

            $powershell = [powershell]::Create()
            $powershell.Runspace = $runspace

            # Füge das Skript hinzu, das im Runspace ausgeführt werden soll
            $powershell.AddScript({
                    # Lade die Workflow-Funktion
                    ${function:Execute-OnboardingWorkflow}

                    # Führe den Workflow aus
                    Execute-OnboardingWorkflow
                })

            # Asynchron ausführen
            $powershell.BeginInvoke() | Out-Null
            Write-Log -Message "Onboarding-Workflow asynchron gestartet." -Level "INFO"
        }
    }
    catch {
        $errorMessage = "Fehler beim Starten des Onboarding-Prozesses: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        [System.Windows.MessageBox]::Show($errorMessage, "Fehler", "OK", "Error")
    }
}

function New-OnboardingReportGUI {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Generiere Onboarding-Bericht..." -Level "INFO"
        $summary = New-OnboardingSummary

        # Speicherort für den Bericht wählen
        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "Textdateien (*.txt)|*.txt|Alle Dateien (*.*)|*.*"
        $saveFileDialog.FileName = "Onboarding-Bericht-$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"

        if ($saveFileDialog.ShowDialog() -eq $true) {
            $filePath = $saveFileDialog.FileName
            $summary | Out-File -FilePath $filePath -Encoding UTF8
            Write-Log -Message "Onboarding-Bericht erfolgreich gespeichert unter: $filePath" -Level "INFO"
            [System.Windows.MessageBox]::Show("Bericht wurde erfolgreich gespeichert.", "Bericht generiert", "OK", "Information")
        }
    }
    catch {
        $errorMessage = "Fehler beim Generieren des Berichts: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        [System.Windows.MessageBox]::Show($errorMessage, "Fehler", "OK", "Error")
    }
}

#endregion
Write-Log -Message "Skript 'easyONBOARDING' gestartet."

function Initialize-TabControlGrids {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.Border]$Panel
    )

    Write-Log -Message "Initialisiere TabControlGrids für Panel '$($Panel.Name)'..." -Level "DEBUG"
    try {
        # Suche nach TabControl innerhalb des Panels
        $tabControl = $Panel.FindName("tabErpCrm")?.Parent

        if ($null -ne $tabControl) {
            Write-Log -Message "Initialisiere DataGrids in TabControl" -Level "INFO"

            # DataGrid für ERP/CRM Tab initialisieren
            $dgErpCrm = $Window.FindName("dgErpCrm")
            if ($null -ne $dgErpCrm -and $dgErpCrm.Columns.Count -eq 0) {
                Write-Log -Message "Initialisiere Spalten für dgErpCrm." -Level "DEBUG"
                $dgErpCrm.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                            Header = "Name"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path = "Name" })
                        }))
                $dgErpCrm.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                            Header = "Beschreibung"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path = "Description" })
                        }))
                $dgErpCrm.Columns.Add((New-Object System.Windows.Controls.DataGridCheckBoxColumn -Property @{
                            Header = "Aktivieren"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path = "IsEnabled" })
                        }))
            }

            # DataGrid für DevTools Tab initialisieren
            $dgDevTools = $Window.FindName("dgDevTools")
            if ($null -ne $dgDevTools -and $dgDevTools.Columns.Count -eq 0) {
                Write-Log -Message "Initialisiere Spalten für dgDevTools." -Level "DEBUG"
                $dgDevTools.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                            Header = "Name"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path = "Name" })
                        }))
                $dgDevTools.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                            Header = "Beschreibung"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path = "Description" })
                        }))
                $dgDevTools.Columns.Add((New-Object System.Windows.Controls.DataGridCheckBoxColumn -Property @{
                            Header = "Aktivieren"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path = "IsEnabled" })
                        }))
            }

            # DataGrid für OtherSystems Tab initialisieren
            $dgOtherSystems = $Window.FindName("dgOtherSystems")
            if ($null -ne $dgOtherSystems -and $dgOtherSystems.Columns.Count -eq 0) {
                Write-Log -Message "Initialisiere Spalten für dgOtherSystems." -Level "DEBUG"
                $dgOtherSystems.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                            Header = "Name"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path = "Name" })
                        }))
                $dgOtherSystems.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                            Header = "Beschreibung"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path = "Description" })
                        }))
                $dgOtherSystems.Columns.Add((New-Object System.Windows.Controls.DataGridCheckBoxColumn -Property @{
                            Header = "Aktivieren"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path = "IsEnabled" })
                        }))
            }
        }
        Write-Log -Message "TabControlGrids erfolgreich initialisiert." -Level "DEBUG"
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung der TabControl DataGrids: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Hilfsfunktionen für Tab 2

function Test-ADConnectionGUI {
    try {
        Write-Log -Message "Teste AD-Verbindung..." -Level "INFO"
        $adStatus = Test-ADConnectivity -ShowError

        $lblADStatus = $Window.FindName("lblADStatus")
        if ($lblADStatus) {
            if ($adStatus) {
                $lblADStatus.Content = "✓ AD-Verbindung erfolgreich"
                $lblADStatus.Foreground = [System.Windows.Media.Brushes]::Green
            }
            else {
                $lblADStatus.Content = "✗ AD-Verbindung fehlgeschlagen"
                $lblADStatus.Foreground = [System.Windows.Media.Brushes]::Red
            }
        }

        $message = if ($adStatus) { "Active Directory Verbindung erfolgreich!" } else { "Active Directory Verbindung fehlgeschlagen!" }
        $icon = if ($adStatus) { "Information" } else { "Warning" }
        [System.Windows.MessageBox]::Show($message, "AD-Verbindungstest", "OK", $icon)
    }
    catch {
        Write-Log -Message "Fehler beim AD-Verbindungstest: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Testen der AD-Verbindung: $($_.Exception.Message)", "Verbindungsfehler", "OK", "Error")
    }
}

function Update-ADConnectionStatus {
    try {
        $adStatus = Get-ADConnectionStatus
        $lblADStatus = $Window.FindName("lblADStatus")

        if ($lblADStatus) {
            if ($adStatus) {
                $lblADStatus.Content = "✓ AD verfügbar"
                $lblADStatus.Foreground = [System.Windows.Media.Brushes]::Green
            }
            else {
                $lblADStatus.Content = "⚠ AD nicht verfügbar"
                $lblADStatus.Foreground = [System.Windows.Media.Brushes]::Orange
            }
        }
    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren des AD-Status: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Show-OUSelectionDialog {
    try {
        # Einfacher Input-Dialog für OU-Auswahl
        # In einer vollständigen Implementierung würde hier ein TreeView-Dialog verwendet
        $inputOU = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Geben Sie den Distinguished Name der OU ein:`n`nBeispiel: OU=Users,DC=domain,DC=local",
            "OU-Auswahl",
            "OU=Users,DC=domain,DC=local"
        )

        if (-not [string]::IsNullOrWhiteSpace($inputOU)) {
            if (Test-OUPathValidity -OUPath $inputOU) {
                return @{ DistinguishedName = $inputOU; Name = ($inputOU -split ',')[0] -replace 'OU=' }
            }
            else {
                [System.Windows.MessageBox]::Show("Die angegebene OU konnte nicht gefunden werden.", "OU nicht gefunden", "OK", "Warning")
            }
        }

        return $null
    }
    catch {
        Write-Log -Message "Fehler beim OU-Auswahl-Dialog: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Show-ManagerSelectionDialog {
    try {
        # Einfacher Input-Dialog für Manager-Auswahl
        $inputManager = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Geben Sie den SAM Account Name oder Display Name des Managers ein:",
            "Manager-Auswahl",
            ""
        )

        if (-not [string]::IsNullOrWhiteSpace($inputManager)) {
            if (Get-ADConnectionStatus) {
                try {
                    $manager = Get-ADUser -Filter "SamAccountName -eq '$inputManager' -or DisplayName -like '*$inputManager*'" -ErrorAction Stop | Select-Object -First 1
                    if ($manager) {
                        return $manager
                    }
                    else {
                        [System.Windows.MessageBox]::Show("Manager '$inputManager' wurde nicht gefunden.", "Manager nicht gefunden", "OK", "Warning")
                    }
                }
                catch {
                    [System.Windows.MessageBox]::Show("Fehler beim Suchen des Managers: $($_.Exception.Message)", "Suchfehler", "OK", "Error")
                }
            }
            else {
                [System.Windows.MessageBox]::Show("Keine AD-Verbindung verfügbar für Manager-Suche.", "AD-Verbindung", "OK", "Warning")
            }
        }

        return $null
    }
    catch {
        Write-Log -Message "Fehler beim Manager-Auswahl-Dialog: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Funktion zum Aktualisieren der OU-Dropdown
function Update-OUDropdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$OUComboBox
    )

    try {
        Write-Log -Message "Aktualisiere OU-Dropdown..." -Level "DEBUG"

        if ($null -eq $OUComboBox) {
            Write-Log -Message "OUComboBox ist null. Breche Update-OUDropdown ab." -Level "ERROR"
            return
        }

        # Prüfe ob ItemsSource verwendet wird und setze es zurück
        if ($OUComboBox.ItemsSource) {
            $OUComboBox.ItemsSource = $null
        }

        # Leere aktuelle Items
        $OUComboBox.Items.Clear()

        # Lade OUs aus AD
        $ous = Get-ADOrganizationalUnitsForDropdown -IncludeUsersAndComputers

        if ($ous.Count -gt 0) {
            Write-Log -Message "Füge $($ous.Count) OUs zum Dropdown hinzu" -Level "DEBUG"

            foreach ($ou in $ous) {
                # Stelle sicher, dass das OU-Objekt die richtige DisplayName-Eigenschaft hat
                if (-not $ou.DisplayName) {
                    $ou | Add-Member -NotePropertyName "DisplayName" -NotePropertyValue "$($ou.Name) ($($ou.DistinguishedName))" -Force
                }
                $ou | Add-Member -NotePropertyName "IsConfigured" -NotePropertyValue $false -Force
                $OUComboBox.Items.Add($ou) | Out-Null
            }

            # Wähle erste OU als Standard
            $OUComboBox.SelectedIndex = 0

            Write-Log -Message "OU-Dropdown erfolgreich aktualisiert" -Level "DEBUG"
        }
        else {
            Write-Log -Message "Keine OUs gefunden für Dropdown" -Level "WARN"

            # Füge Fallback-Item hinzu
            $fallbackOU = [PSCustomObject]@{
                Name              = "Standard"
                DistinguishedName = "CN=Users,DC=domain,DC=local"
                Description       = "Fallback-OU"
                DisplayName       = "Standard (CN=Users,DC=domain,DC=local)"
                Path              = "CN=Users,DC=domain,DC=local"
                IsConfigured      = $false
            }
            $OUComboBox.Items.Add($fallbackOU) | Out-Null
            $OUComboBox.SelectedIndex = 0
        }
    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren der OU-Dropdown: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Funktion zum Aktualisieren der OU-Dropdown basierend auf Abteilung
function Update-OUDropdownFromDepartment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$OUComboBox,

        [Parameter(Mandatory = $true)]
        [string]$DepartmentName
    )

    try {
        Write-Log -Message "Aktualisiere OU-Dropdown für Abteilung: $DepartmentName" -Level "DEBUG"

        # Prüfe ob ItemsSource verwendet wird und setze es zurück
        if ($OUComboBox.ItemsSource) {
            $OUComboBox.ItemsSource = $null
        }

        # Leere aktuelle Items
        $OUComboBox.Items.Clear()

        # Priorität 1: Konfigurierte OU aus INI-Datei laden
        $departmentConfig = Get-ConfigValue -Section "Department_$DepartmentName" -Key "OU" -DefaultValue $null

        if ($departmentConfig) {
            Write-Log -Message "Konfigurierte OU für Abteilung $DepartmentName gefunden: $departmentConfig" -Level "DEBUG"

            # Erstelle OU-Objekt basierend auf der Konfiguration
            $configuredOU = [PSCustomObject]@{
                Name              = ($departmentConfig -split ',' | Select-Object -First 1) -replace 'OU=', ''
                DistinguishedName = $departmentConfig
                Description       = "Konfigurierte OU für $DepartmentName"
                DisplayName       = "$DepartmentName - Konfiguriert ($departmentConfig)"
                Path              = $departmentConfig
                IsConfigured      = $true
            }

            $OUComboBox.Items.Add($configuredOU) | Out-Null

            # Füge zusätzlich alle anderen verfügbaren OUs hinzu
            if (Get-ADConnectionStatus) {
                Write-Log -Message "Lade zusätzliche OUs aus Active Directory..." -Level "DEBUG"

                $allOUs = Get-ADOrganizationalUnitsForDropdown -IncludeUsersAndComputers
                if ($allOUs -and $allOUs.Count -gt 0) {
                    # Füge Trennlinie hinzu
                    $separator = [PSCustomObject]@{
                        Name              = "────────────────────────────"
                        DistinguishedName = ""
                        Description       = "Weitere verfügbare OUs"
                        DisplayName       = "─── Weitere verfügbare OUs ───"
                        Path              = ""
                        IsConfigured      = $false
                    }
                    $OUComboBox.Items.Add($separator) | Out-Null

                    # Füge alle OUs hinzu, außer der bereits konfigurierten
                    foreach ($ou in $allOUs) {
                        if ($ou.DistinguishedName -ne $departmentConfig) {
                            # Stelle sicher, dass das OU-Objekt die richtige DisplayName-Eigenschaft hat
                            if (-not $ou.DisplayName) {
                                $ou | Add-Member -NotePropertyName "DisplayName" -NotePropertyValue "$($ou.Name) ($($ou.DistinguishedName))" -Force
                            }
                            $ou | Add-Member -NotePropertyName "IsConfigured" -NotePropertyValue $false -Force
                            $OUComboBox.Items.Add($ou) | Out-Null
                        }
                    }

                    Write-Log -Message "Zusätzlich $($allOUs.Count) weitere OUs geladen" -Level "DEBUG"
                }
            }

            # Wähle die konfigurierte OU als Standard
            $OUComboBox.SelectedIndex = 0

            Write-Log -Message "Konfigurierte OU für Abteilung $DepartmentName erfolgreich geladen" -Level "DEBUG"
        }
        else {
            Write-Log -Message "Keine konfigurierte OU für Abteilung $DepartmentName gefunden. Lade alle verfügbaren OUs." -Level "INFO"

            # Priorität 2: Lade alle verfügbaren OUs
            if (Get-ADConnectionStatus) {
                $allOUs = Get-ADOrganizationalUnitsForDropdown -IncludeUsersAndComputers
                if ($allOUs -and $allOUs.Count -gt 0) {
                    foreach ($ou in $allOUs) {
                        # Stelle sicher, dass das OU-Objekt die richtige DisplayName-Eigenschaft hat
                        if (-not $ou.DisplayName) {
                            $ou | Add-Member -NotePropertyName "DisplayName" -NotePropertyValue "$($ou.Name) ($($ou.DistinguishedName))" -Force
                        }
                        $ou | Add-Member -NotePropertyName "IsConfigured" -NotePropertyValue $false -Force
                        $OUComboBox.Items.Add($ou) | Out-Null
                    }
                    $OUComboBox.SelectedIndex = 0
                    Write-Log -Message "Alle $($allOUs.Count) verfügbaren OUs geladen" -Level "DEBUG"
                }
                else {
                    Write-Log -Message "Keine OUs aus AD verfügbar. Lade Standard-Refresh." -Level "INFO"
                    Update-OUDropdown -OUComboBox $OUComboBox
                }
            }
            else {
                Write-Log -Message "Keine AD-Verbindung verfügbar. Lade Standard-Refresh." -Level "WARN"
                Update-OUDropdown -OUComboBox $OUComboBox
            }
        }
    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren der OU-Dropdown für Abteilung: $($_.Exception.Message)" -Level "ERROR"

        # Fallback: Standard-Refresh
        Update-OUDropdown -OUComboBox $OUComboBox
    }
}

# Funktion zum Laden verfügbarer Abteilungen
function Get-AvailableDepartments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config
    )

    try {
        Write-Log -Message "Lade verfügbare Abteilungen..." -Level "DEBUG"

        # Priorität 1: Aus Department-Sektionen der INI-Datei laden
        $departments = @()

        if ($Config -and $Config.Count -gt 0) {
            Write-Log -Message "Durchsuche Konfiguration nach Department-Sektionen..." -Level "DEBUG"

            # Suche nach allen [Department_*] Sektionen
            foreach ($sectionName in $Config.Keys) {
                if ($sectionName -match '^Department_(.+)$') {
                    $departmentName = $matches[1]
                    $departments += $departmentName
                    Write-Log -Message "Abteilung aus Konfiguration gefunden: $departmentName" -Level "DEBUG"
                }
            }

            if ($departments.Count -gt 0) {
                Write-Log -Message "Abteilungen aus INI-Konfiguration geladen: $($departments.Count)" -Level "DEBUG"
                return $departments | Sort-Object
            }
        }

        # Priorität 2: Fallback zu Standard-Abteilungen nur wenn keine Department-Sektionen gefunden
        Write-Log -Message "Keine Department-Sektionen in INI gefunden, verwende Fallback-Abteilungen" -Level "INFO"
        $fallbackDepartments = @(
            "IT",
            "Sales",
            "Marketing",
            "HR",
            "Finance",
            "Operations"
        )

        return $fallbackDepartments | Sort-Object
    }
    catch {
        Write-Log -Message "Fehler beim Laden der Abteilungen: $($_.Exception.Message)" -Level "ERROR"

        # Minimaler Fallback
        return @("IT", "Sales", "Marketing", "HR", "Finance", "Operations")
    }
}


# Hilfsfunktionen zum Befüllen der Dropdowns
function Update-TemplateDropdown {
    $cmbTemplate = $Window.FindName("cmbTemplate")
    if (-not $cmbTemplate) { return }

    $cmbTemplate.Items.Clear()
    $cmbTemplate.Items.Add([PSCustomObject]@{ Key = "None"; Name = "-- Keine Vorlage --" })
    $templates = Get-AvailableUserTemplates
    foreach ($template in $templates) {
        $cmbTemplate.Items.Add($template)
    }
    $cmbTemplate.SelectedIndex = 0
}

function Update-DepartmentDropdown {
    $cmbDepartment = $global:Window.FindName("cmbDepartment")
    if (-not $cmbDepartment) {
        Write-Log -Message "Department ComboBox 'cmbDepartment' nicht im Fenster gefunden." -Level "WARN"
        return
    }

    try {
        Write-Log -Message "Aktualisiere Department-Dropdown..." -Level "DEBUG"
        $cmbDepartment.Items.Clear()

        # Lade die verfügbaren Abteilungen
        $departments = Get-AvailableDepartments

        if ($departments.Count -gt 0) {
            # Füge jede Abteilung zur ComboBox hinzu
            foreach ($dept in $departments) {
                $cmbDepartment.Items.Add($dept)
            }
            Write-Log -Message "$($departments.Count) Abteilungen zum Dropdown hinzugefügt." -Level "DEBUG"
        }
        else {
            Write-Log -Message "Keine Abteilungen zum Laden gefunden." -Level "WARN"
            $cmbDepartment.Items.Add("Keine Abteilungen konfiguriert")
        }
    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren des Department-Dropdowns: $($_.Exception.Message)" -Level "ERROR"
        # Im Fehlerfall eine Meldung anzeigen
        if ($cmbDepartment) {
            $cmbDepartment.Items.Clear()
            $cmbDepartment.Items.Add("Fehler beim Laden")
        }
    }
}

# Funktion zur Validierung aller Eingaben
function Validate-AllInputs {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Starte vollständige Eingabevalidierung..." -Level "DEBUG"

        $validationErrors = @()
        $validationWarnings = @()

        # Tab 1: Benutzerdaten validieren
        Write-Log -Message "Validiere Tab 1: Benutzerdaten" -Level "DEBUG"

        # Vorname prüfen
        $txtFirstName = $Window.FindName("txtFirstName")
        if (-not $txtFirstName -or [string]::IsNullOrWhiteSpace($txtFirstName.Text)) {
            $validationErrors += "Vorname ist erforderlich"
        }

        # Nachname prüfen
        $txtLastName = $Window.FindName("txtLastName")
        if (-not $txtLastName -or [string]::IsNullOrWhiteSpace($txtLastName.Text)) {
            $validationErrors += "Nachname ist erforderlich"
        }

        # E-Mail prüfen
        $txtEmail = $Window.FindName("txtEmail")
        if ($txtEmail -and -not [string]::IsNullOrWhiteSpace($txtEmail.Text)) {
            if (-not (Test-EmailAddress -EmailAddress $txtEmail.Text)) {
                $validationErrors += "E-Mail-Adresse ist ungültig"
            }
        }

        # Abteilung prüfen
        $cmbDepartment = $Window.FindName("cmbDepartment")
        if (-not $cmbDepartment -or -not $cmbDepartment.SelectedItem) {
            $validationWarnings += "Keine Abteilung ausgewählt"
        }

        # Tab 2: AD-Einstellungen validieren
        Write-Log -Message "Validiere Tab 2: AD-Einstellungen" -Level "DEBUG"

        # OU-Pfad prüfen
        $cmbOUPath = $Window.FindName("cmbOUPath")
        if (-not $cmbOUPath -or -not $cmbOUPath.SelectedItem) {
            $validationErrors += "Organisationseinheit (OU) muss ausgewählt werden"
        }

        # SAM Account Name prüfen
        $txtSamAccountName = $Window.FindName("txtSamAccountName")
        if (-not $txtSamAccountName -or [string]::IsNullOrWhiteSpace($txtSamAccountName.Text)) {
            $validationErrors += "SAM Account Name ist erforderlich"
        }
        elseif ($txtSamAccountName.Text.Length -gt 20) {
            $validationErrors += "SAM Account Name darf nicht länger als 20 Zeichen sein"
        }

        # UPN prüfen
        $txtUPN = $Window.FindName("txtUPN")
        if (-not $txtUPN -or [string]::IsNullOrWhiteSpace($txtUPN.Text)) {
            $validationErrors += "User Principal Name (UPN) ist erforderlich"
        }

        # AD-Verbindung prüfen
        if (-not (Get-ADConnectionStatus)) {
            $validationErrors += "Keine Verbindung zum Active Directory"
        }

        # Tab 3: M365-Einstellungen validieren (falls aktiviert)
        Write-Log -Message "Validiere Tab 3: M365-Einstellungen" -Level "DEBUG"

        $chkCreateMailbox = $Window.FindName("chkCreateMailbox")
        if ($chkCreateMailbox -and $chkCreateMailbox.IsChecked) {
            $txtEmailAddress = $Window.FindName("txtEmailAddress")
            if (-not $txtEmailAddress -or [string]::IsNullOrWhiteSpace($txtEmailAddress.Text)) {
                $validationErrors += "E-Mail-Adresse ist erforderlich für Mailbox-Erstellung"
            }
        }

        # Zeige Validierungsergebnisse
        if ($validationErrors.Count -gt 0) {
            $errorMessage = "Folgende Fehler müssen behoben werden:`n`n" + ($validationErrors -join "`n")
            Write-Log -Message "Validierungsfehler gefunden: $($validationErrors -join '; ')" -Level "ERROR"
            [System.Windows.MessageBox]::Show($errorMessage, "Validierungsfehler", "OK", "Error")
            return $false
        }

        if ($validationWarnings.Count -gt 0) {
            $warningMessage = "Folgende Warnungen wurden festgestellt:`n`n" + ($validationWarnings -join "`n") + "`n`nMöchten Sie trotzdem fortfahren?"
            Write-Log -Message "Validierungswarnungen: $($validationWarnings -join '; ')" -Level "WARN"

            $result = [System.Windows.MessageBox]::Show($warningMessage, "Validierungswarnungen", "YesNo", "Warning")
            if ($result -eq "No") {
                return $false
            }
        }

        Write-Log -Message "Alle Eingaben erfolgreich validiert" -Level "INFO"
        return $true

    }
    catch {
        Write-Log -Message "Fehler bei der Eingabevalidierung: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show("Fehler bei der Validierung: $($_.Exception.Message)", "Validierungsfehler", "OK", "Error")
        return $false
    }
}

function Initialize-Step1 {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Initialisiere Step 1..." -Level "DEBUG"

        # Template Dropdown initialisieren
        Update-TemplateDropdown

        # Department Dropdown initialisieren
        Update-DepartmentDropdown

        # OU Dropdown initialisieren
        $cmbOUPath = $Window.FindName("cmbOUPath")
        if ($cmbOUPath -is [System.Windows.Controls.ComboBox]) {
            Update-OUDropdown -OUComboBox $cmbOUPath
        }
        else {
            Write-Log -Message "OU-Dropdown 'cmbOUPath' nicht gefunden oder ist kein gültiges Steuerelement, Initialisierung übersprungen." -Level "WARN"
        }

        Write-Log -Message "Step 1 erfolgreich initialisiert" -Level "DEBUG"

    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Step 1: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Initialize-Step2 {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Initialisiere Step 2..." -Level "DEBUG"

        # Gruppenlisten initialisieren
        Initialize-GroupLists

        Write-Log -Message "Step 2 erfolgreich initialisiert" -Level "DEBUG"

    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Step 2: $($_.Exception.Message)" -Level "ERROR"
    }
}

# --- GUI-STEUERELEMENTE ABRUFEN ---
function Get-GuiControls {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )

    Write-Log -Message "Binde GUI-Steuerelemente an Variablen..." -Level "DEBUG"
    $global:Variables = @{}

    # Erweiterte Liste aller GUI-Steuerelemente basierend auf der XAML-Datei
    $controlsToLoad = @(
        # Navigation & Panels
        "btnStep1", "btnStep2", "btnStep3", "btnStep7",
        "step1Panel", "step2Panel", "step3Panel", "step7Panel",

        # Header & Progress
        "stepIndicator1", "stepIndicator2", "stepIndicator6", "stepIndicator7",
        "btnHelp", "btnSettings",
        "mainProgressBar", "progressText", "infoText",

        # Step 1 - Benutzerdaten
        "cmbTemplate", "btnLoadTemplates",
        "txtFirstName", "txtLastName", "txtUsername", "txtEmail",
        "cmbDepartment", "txtPosition", "txtManager", "btnBrowseManager",
        "cmbOUPath", "btnBrowseOU", "pwdPassword", "btnGeneratePassword",
        "validationPanel1", "validationText1", "btnValidateStep1", "btnNextStep1",

        # Step 2 - Gruppen
        "txtGroupSearch", "lstAvailableGroups", "lstSelectedGroups",
        "btnAddGroup", "btnAddAllGroups", "btnRemoveGroup", "btnRemoveAllGroups",
        "groupCountText", "btnPrevStep2", "btnCreateUser",

        # Step 3 - Erweiterte Einstellungen
        "userStatusText", "txtPhone", "txtMobile", "txtOffice", "txtLocation", "txtDescription",
        "chkMustChangePassword", "chkPasswordNeverExpires", "chkCannotChangePassword", "chkAccountDisabled",
        "btnPrevStep3", "btnUpdateUser3", "btnNextStep3",

        # Step 7 - Zusammenfassung
        "summaryFullName", "summaryUsername", "summaryEmail", "summaryDepartment",
        "summaryPosition", "summaryOU", "summaryM365Status", "summaryM365License",
        "summaryMailboxStatus", "summaryGroupCount", "summaryGroupList",
        "chkSendWelcomeEmail", "chkNotifyManager", "chkSendPasswordToManager",
        "chkCreateDocumentation", "cmbDocFormat", "txtFinalLog",
        "btnPrevStep7", "btnStartNew", "btnFinalizeOnboarding",

        # Footer
        "statusTextFooter", "actionProgressBar", "versionTextFooter",

        # Weitere wichtige Steuerelemente
        "btnValidate", "btnUpdateUser", "txtSamAccountName", "txtUPN",
        "chkCreateMailbox", "lblADStatus"
    )
    # Auskommentierte Steuerelemente für zukünftige Verwendung
    <#
        "btnStep4", "btnStep5", "btnStep6",
        "step4PanelCloudOnly", "step4PanelHybrid",
        "step5Panel", "step6Panel"
    #>

    # Sammle alle existierenden Elemente
    $foundElements = 0
    $missingElements = @()
    $criticalMissing = @()

    # Kritische Elemente definieren (müssen vorhanden sein)
    $criticalElements = @("step1Panel", "step2Panel", "step3Panel", "step7Panel",
        "btnStep1", "btnStep2", "btnStep3", "btnStep7")

    foreach ($controlName in $controlsToLoad) {
        $control = $Window.FindName($controlName)
        if ($control) {
            $global:Variables[$controlName] = $control
            $foundElements++
            Write-Log -Message "Steuerelement '$controlName' erfolgreich gebunden." -Level "DEBUG"
        }
        else {
            $missingElements += $controlName
            if ($controlName -in $criticalElements) {
                $criticalMissing += $controlName
            }
            Write-Log -Message "Steuerelement '$controlName' konnte nicht in der XAML-Datei gefunden werden." -Level "WARN"
        }
    }

    # Sammlung aller Panels zur einfacheren Verwaltung
    $allPanels = @()
    $panelNames = @("step1Panel", "step2Panel", "step3Panel", "step7Panel")

    foreach ($panelName in $panelNames) {
        if ($global:Variables.ContainsKey($panelName) -and $global:Variables[$panelName]) {
            $allPanels += $global:Variables[$panelName]
        }
        else {
            Write-Log -Message "Panel '$panelName' nicht gefunden oder null und kann nicht zur Sammlung hinzugefügt werden." -Level "WARN"
        }
    }

    # Warnung ausgeben wenn kritische Elemente fehlen
    if ($criticalMissing.Count -gt 0) {
        Write-Log -Message "KRITISCHE ELEMENTE FEHLEN: $($criticalMissing -join ', ')" -Level "ERROR"
        Write-Log -Message "Die Anwendung kann möglicherweise nicht korrekt funktionieren!" -Level "ERROR"
    }

    # Informative Ausgabe
    Write-Log -Message "GUI-Steuerelemente erfolgreich gebunden: $foundElements von $($controlsToLoad.Count) Elementen gefunden." -Level "INFO"
    if ($missingElements.Count -gt 0) {
        Write-Log -Message "Fehlende Elemente ($($missingElements.Count)): $($missingElements -join ', ')" -Level "WARN"
    }
    Write-Log -Message "$($allPanels.Count) Panels verfügbar." -Level "DEBUG"

    # Initialisiere spezielle GUI-Funktionen
    try {
        # Gruppenlisten initialisieren (nur wenn Elemente vorhanden)
        if ($global:Variables.ContainsKey('lstAvailableGroups') -and $global:Variables.ContainsKey('lstSelectedGroups')) {
            Write-Log -Message "Initialisiere Gruppenlisten..." -Level "DEBUG"
            Initialize-GroupLists
        }
        else {
            Write-Log -Message "Gruppen-ListBoxes nicht gefunden - überspringe Gruppenlisten-Initialisierung" -Level "WARN"
        }

        # Event-Handler hinzufügen
        Add-NavigationEventHandlers

        # Template- und Abteilungs-Dropdowns befüllen
        Update-TemplateDropdown
        Update-DepartmentDropdown

    }
    catch {
        Write-Log -Message "Fehler bei der GUI-Initialisierung: $($_.Exception.Message)" -Level "ERROR"
    }

    # Rückgabe der Panels-Sammlung
    return $allPanels
}

# Funktion zum Abrufen aller Panels
function Get-AllPanels {
    [CmdletBinding()]
    param()

    try {
        $allPanels = @()

        # Sammle alle step*Panel Elemente
        for ($i = 1; $i -le 7; $i++) {
            $panelName = "step${i}Panel"
            $panel = $Window.FindName($panelName)
            if ($panel) {
                $allPanels += $panel
            }
        }

        <#
        # Spezielle Panels hinzufügen
        $step4CloudPanel = $Window.FindName("step4PanelCloudOnly")
        if ($step4CloudPanel) {
            $allPanels += $step4CloudPanel
        }

        $step4HybridPanel = $Window.FindName("step4PanelHybrid")
        if ($step4HybridPanel) {
            $allPanels += $step4HybridPanel
        }
        #>

        return $allPanels
    }
    catch {
        Write-Log -Message "Fehler beim Abrufen der Panels: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

# Funktion zum Hinzufügen der Navigation-Event-Handler
function Add-NavigationEventHandlers {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Füge Navigation-Event-Handler hinzu..." -Level "DEBUG"

        # Check if $global:Variables is properly initialized
        if (-not $global:Variables) {
            Write-Log -Message "FEHLER: Global Variables Hashtable ist nicht initialisiert!" -Level "ERROR"
            return
        }

        Write-Log -Message "Global Variables enthält: $($global:Variables.Count) Elemente" -Level "DEBUG"
        Write-Log -Message "Global Variables Keys: $($global:Variables.Keys -join ', ')" -Level "DEBUG"

        # Tab 1 Button
        if ($global:Variables.ContainsKey("btnStep1") -and $global:Variables["btnStep1"]) {
            $global:Variables["btnStep1"].add_Click({
                    Switch-Tab -TargetPanel $global:Variables["step1Panel"]
                })
            Write-Log -Message "Event-Handler für btnStep1 hinzugefügt" -Level "DEBUG"
        }
        else {
            Write-Log -Message "btnStep1 nicht in Global Variables gefunden" -Level "WARN"
        }

        # Tab 2 Button
        if ($global:Variables.ContainsKey("btnStep2") -and $global:Variables["btnStep2"]) {
            $global:Variables["btnStep2"].add_Click({
                    Switch-Tab -TargetPanel $global:Variables["step2Panel"]
                })
            Write-Log -Message "Event-Handler für btnStep2 hinzugefügt" -Level "DEBUG"
        }
        else {
            Write-Log -Message "btnStep2 nicht in Global Variables gefunden" -Level "WARN"
        }

        # Tab 3 Button
        if ($global:Variables.ContainsKey("btnStep3") -and $global:Variables["btnStep3"]) {
            $global:Variables["btnStep3"].add_Click({
                    Switch-Tab -TargetPanel $global:Variables["step3Panel"]
                })
            Write-Log -Message "Event-Handler für btnStep3 hinzugefügt" -Level "DEBUG"
        }
        else {
            Write-Log -Message "btnStep3 nicht in Global Variables gefunden" -Level "WARN"
        }
        <#
        # Optional: Tab 4 Button für Cloud-Only und Hybrid-Modus
        # Tab 4 Button
        $btnStep4 = $Window.FindName("btnStep4")
        if ($btnStep4) {
            $btnStep4.add_Click({
            # Bestimme den Modus aus der Konfiguration
            $isCloudOnly = Get-ConfigValue -Section "General" -Key "CloudOnly" -DefaultValue $false

            if ($isCloudOnly) {
                Write-Log -Message "Cloud-Only-Modus: Wechsle zu step4PanelCloudOnly" -Level "DEBUG"
                Switch-Tab -TargetPanel $global:Variables["step4PanelCloudOnly"]
            } else {
                Write-Log -Message "Hybrid-Modus: Wechsle zu step4PanelHybrid" -Level "DEBUG"
                Switch-Tab -TargetPanel $global:Variables["step4PanelHybrid"]
            }
            })
            Write-Log -Message "Event-Handler für btnStep4 hinzugefügt" -Level "DEBUG"
        }

        # Optional: Tab 5 Button für weitere Schritte
        # Tab 5 Button
        $btnStep5 = $Window.FindName("btnStep5")
        if ($btnStep5) {
            $btnStep5.add_Click({
                Switch-Tab -TargetPanel $global:Variables["step5Panel"]
            })
            Write-Log -Message "Event-Handler für btnStep5 hinzugefügt" -Level "DEBUG"
        }

        # Optional: Tab 6 Button für weitere Schritte
        # Tab 6 Button
        $btnStep6 = $Window.FindName("btnStep6")
        if ($btnStep6) {
            $btnStep6.add_Click({
                Switch-Tab -TargetPanel $global:Variables["step6Panel"]
            })
            Write-Log -Message "Event-Handler für btnStep6 hinzugefügt" -Level "DEBUG"
        }
        #>

        # Tab 7 Button
        if ($global:Variables.ContainsKey("btnStep7") -and $global:Variables["btnStep7"]) {
            $global:Variables["btnStep7"].add_Click({
                    Switch-Tab -TargetPanel $global:Variables["step7Panel"]
                })
            Write-Log -Message "Event-Handler für btnStep7 hinzugefügt" -Level "DEBUG"
        }
        else {
            Write-Log -Message "btnStep7 nicht in Global Variables gefunden" -Level "WARN"
        }

        # Validieren-Button (falls vorhanden)
        $btnValidate = $Window.FindName("btnValidate")
        if ($btnValidate) {
            $btnValidate.add_Click({
                    Test-AllValidations
                })
            Write-Log -Message "Event-Handler für btnValidate hinzugefügt" -Level "DEBUG"
        }

        # Benutzer erstellen-Button
        $btnCreateUser = $Window.FindName("btnCreateUser")
        if ($btnCreateUser) {
            $btnCreateUser.add_Click({
                    Start-UserCreation
                })
            Write-Log -Message "Event-Handler für btnCreateUser hinzugefügt" -Level "DEBUG"
        }

        # Benutzer aktualisieren-Button
        $btnUpdateUser = $Window.FindName("btnUpdateUser")
        if ($btnUpdateUser) {
            $btnUpdateUser.add_Click({
                    Start-UserUpdate
                })
            Write-Log -Message "Event-Handler für btnUpdateUser hinzugefügt" -Level "DEBUG"
        }

        # Abteilungen-Dropdown Event-Handler
        $cmbDepartment = $Window.FindName("cmbDepartment")
        if ($cmbDepartment) {
            $cmbDepartment.add_SelectionChanged({
                    Update-DepartmentSelection
                })
            Write-Log -Message "Event-Handler für cmbDepartment hinzugefügt" -Level "DEBUG"
        }

        # OU-Dropdown Event-Handler
        $cmbOU = $Window.FindName("cmbOU")
        if ($cmbOU) {
            $cmbOU.add_SelectionChanged({
                    Update-OUSelection
                })
            Write-Log -Message "Event-Handler für cmbOU hinzugefügt" -Level "DEBUG"
        }

        Write-Log -Message "Navigation-Event-Handler erfolgreich hinzugefügt" -Level "DEBUG"

    }
    catch {
        Write-Log -Message "Fehler beim Hinzufügen der Navigation-Event-Handler: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Funktion für alle Validierungen
function Test-AllValidations {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Starte Validierung aller Eingaben..." -Level "DEBUG"

        # Erst die Benutzerfelder aktualisieren
        Update-GeneratedUserFields

        # Dann die Validierung durchführen
        $validationResult = Test-ValidateAllInputs

        if ($validationResult) {
            [System.Windows.MessageBox]::Show("Alle Eingaben sind gültig!", "Validierung erfolgreich", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
        else {
            [System.Windows.MessageBox]::Show("Validierungsfehler gefunden! Bitte prüfen Sie die Eingaben.", "Validierung fehlgeschlagen", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }

    }
    catch {
        Write-Log -Message "Fehler bei der Validierung: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show("Fehler bei der Validierung: $($_.Exception.Message)", "Validierungsfehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

# Hilfsfunktion für die Validierung
function Test-ValidateAllInputs {
    [CmdletBinding()]
    param()

    try {
        $isValid = $true

        # Grundlegende Validierung
        $txtFirstName = $Window.FindName("txtFirstName")
        $txtLastName = $Window.FindName("txtLastName")

        if (-not $txtFirstName.Text.Trim()) {
            $isValid = $false
        }

        if (-not $txtLastName.Text.Trim()) {
            $isValid = $false
        }

        return $isValid

    }
    catch {
        Write-Log -Message "Fehler bei der Validierung: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Funktion zum Prüfen der Benutzerfelder-Eingaben
function Test-UserFieldsInput {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Validiere Benutzerfelder..." -Level "DEBUG"

        # Grundlegende Felder aus Tab 1 prüfen
        $txtFirstName = $Window.FindName("txtFirstName")
        $txtLastName = $Window.FindName("txtLastName")

        if (-not $txtFirstName.Text.Trim()) {
            [System.Windows.MessageBox]::Show("Bitte geben Sie einen Vornamen ein.", "Validierung fehlgeschlagen", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return $false
        }

        if (-not $txtLastName.Text.Trim()) {
            [System.Windows.MessageBox]::Show("Bitte geben Sie einen Nachnamen ein.", "Validierung fehlgeschlagen", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return $false
        }

        return $true

    }
    catch {
        Write-Log -Message "Fehler bei der Validierung der Benutzerfelder: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Diese Funktion wird bereits weiter oben im Script definiert
# Entferne doppelte Definition

# Funktion zum Starten der Benutzererstellung
function Start-UserCreation {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Starte Benutzererstellung..." -Level "INFO"

        # Sammle Benutzerdaten aus der GUI
        $userData = Get-UserDataFromGUI
        if (-not $userData) {
            Write-Log -Message "Fehler beim Sammeln der Benutzerdaten aus der GUI" -Level "ERROR"
            [System.Windows.MessageBox]::Show("Fehler beim Sammeln der Benutzerdaten aus der GUI.", "Datenfehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }

        # Validierung vor der Erstellung
        $validationResult = Test-ValidateAllInputs
        if (-not $validationResult) {
            [System.Windows.MessageBox]::Show("Validierungsfehler gefunden! Bitte prüfen Sie die Eingaben.", "Validierung fehlgeschlagen", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }

        # Überprüfe, ob mindestens Vor- und Nachname eingegeben wurden
        if ([string]::IsNullOrWhiteSpace($userData.FirstName) -or [string]::IsNullOrWhiteSpace($userData.LastName)) {
            Write-Log -Message "Vor- oder Nachname ist leer: FirstName='$($userData.FirstName)', LastName='$($userData.LastName)'" -Level "ERROR"
            [System.Windows.MessageBox]::Show("Bitte geben Sie mindestens Vor- und Nachname ein.", "Eingabefehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }

        # Bestätigung vom Benutzer einholen
        $confirmationMessage = @"
Benutzer erstellen:

Name: $($userData.FirstName) $($userData.LastName)
Abteilung: $($userData.Department)
Position: $($userData.Position)
Email: $($userData.EmailAddress)
OU: $($userData.OUPath)
Gruppen: $($userData.SelectedGroups.Count) ausgewählt

Möchten Sie fortfahren?
"@

        $result = [System.Windows.MessageBox]::Show($confirmationMessage, "Benutzer erstellen", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($result -ne [System.Windows.MessageBoxResult]::Yes) {
            Write-Log -Message "Benutzererstellung abgebrochen durch Benutzer" -Level "INFO"
            return
        }

        # Starte die eigentliche AD-Benutzer-Erstellung
        Write-Log -Message "Rufe New-ADUserAccount auf für: $($userData.FirstName) $($userData.LastName)" -Level "INFO"

        $result = New-ADUserAccount -UserData $userData

        if ($result -and $result.Success) {
            Write-Log -Message "Benutzer erfolgreich erstellt: $($userData.FirstName) $($userData.LastName)" -Level "INFO"
            [System.Windows.MessageBox]::Show("Benutzer '$($userData.FirstName) $($userData.LastName)' wurde erfolgreich erstellt!`n`nSAM Account: $($result.SamAccountName)`nUPN: $($result.UserPrincipalName)", "Erfolgreich erstellt", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
        else {
            $errorMessage = if ($result -and $result.Message) { $result.Message } else { "Unbekannter Fehler bei der Benutzer-Erstellung" }
            Write-Log -Message "Fehler bei der Benutzer-Erstellung für: $($userData.FirstName) $($userData.LastName) - $errorMessage" -Level "ERROR"
            [System.Windows.MessageBox]::Show("Fehler bei der Benutzer-Erstellung: $errorMessage", "Erstellungsfehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }

    }
    catch {
        Write-Log -Message "Fehler bei der Benutzererstellung: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show("Fehler bei der Benutzererstellung: $($_.Exception.Message)", "Erstellungsfehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

# Funktion zum Starten der Benutzeraktualisierung
function Start-UserUpdate {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Starte Benutzeraktualisierung..." -Level "INFO"

        # Hier würde die eigentliche Benutzeraktualisierung stattfinden
        [System.Windows.MessageBox]::Show("Benutzeraktualisierung gestartet. Diese Funktion wird implementiert...", "Benutzeraktualisierung", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)

    }
    catch {
        Write-Log -Message "Fehler bei der Benutzeraktualisierung: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show("Fehler bei der Benutzeraktualisierung: $($_.Exception.Message)", "Aktualisierungsfehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

# Funktion zum Aktualisieren der Abteilungsauswahl
function Update-DepartmentSelection {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Aktualisiere Abteilungsauswahl..." -Level "DEBUG"

        $cmbDepartment = $Window.FindName("cmbDepartment")
        if ($cmbDepartment.SelectedItem) {
            Write-Log -Message "Abteilung ausgewählt: $($cmbDepartment.SelectedItem)" -Level "DEBUG"
            # Hier könnten weitere Aktionen bei Abteilungsauswahl durchgeführt werden
        }

    }
    catch {
        Write-Log -Message "Fehler bei der Abteilungsauswahl: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Funktion zum Aktualisieren der OU-Auswahl
function Update-OUSelection {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Aktualisiere OU-Auswahl..." -Level "DEBUG"

        $cmbOU = $Window.FindName("cmbOU")
        if ($cmbOU.SelectedItem) {
            Write-Log -Message "OU ausgewählt: $($cmbOU.SelectedItem)" -Level "DEBUG"
            # Hier könnten weitere Aktionen bei OU-Auswahl durchgeführt werden
        }

    }
    catch {
        Write-Log -Message "Fehler bei der OU-Auswahl: $($_.Exception.Message)" -Level "ERROR"
    }
}

# --- EVENT-HANDLER FÜR DIE NAVIGATION ---

# Hilfsfunktion zum Wechseln der Tabs/Panels
function Switch-Tab {
    param(
        [Parameter(Mandatory = $true)]
        $TargetPanel,

        [Parameter(Mandatory = $false)]
        $TabItem = $null
    )

    try {
        if ($null -eq $TargetPanel) {
            Write-Log -Message "Ziel-Panel zum Umschalten ist null." -Level "WARN"
            return
        }

        Write-Log -Message "Wechsle zu Tab: $($TargetPanel.Name)" -Level "DEBUG"

        # Sammle alle verfügbaren Panels direkt aus den globalen Variablen
        $allAvailablePanels = @()
        $panelNames = @("step1Panel", "step2Panel", "step3Panel", "step7Panel")

        foreach ($panelName in $panelNames) {
            if ($global:Variables.ContainsKey($panelName) -and $global:Variables[$panelName]) {
                $allAvailablePanels += $global:Variables[$panelName]
            }
        }

        # Alle Panels ausblenden
        foreach ($panel in $allAvailablePanels) {
            if ($null -ne $panel) {
                $success = Set-PanelVisibility -Panel $panel -Visibility "Collapsed"
                if ($success) {
                    Write-Log -Message "Panel '$($panel.Name)' erfolgreich ausgeblendet." -Level "DEBUG"
                }
                else {
                    Write-Log -Message "Konnte Panel '$($panel.Name)' nicht ausblenden - verwende Fallback" -Level "WARN"
                    # Fallback: Versuche direkte Eigenschaft
                    try {
                        $panel.Visibility = [System.Windows.Visibility]::Collapsed
                    }
                    catch {
                        Write-Log -Message "Fallback für Panel '$($panel.Name)' fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
                    }
                }
            }
            else {
                Write-Log -Message "Null-Panel in allAvailablePanels gefunden" -Level "WARN"
            }
        }

        # Nur das Ziel-Panel einblenden
        $success = Set-PanelVisibility -Panel $TargetPanel -Visibility "Visible"
        if ($success) {
            Write-Log -Message "Panel '$($TargetPanel.Name)' erfolgreich sichtbar gemacht." -Level "DEBUG"
        }
        else {
            Write-Log -Message "Konnte Panel '$($TargetPanel.Name)' nicht anzeigen - verwende Fallback" -Level "WARN"
            # Fallback: Versuche direkte Eigenschaft
            try {
                $TargetPanel.Visibility = [System.Windows.Visibility]::Visible
                Write-Log -Message "Panel '$($TargetPanel.Name)' über Fallback sichtbar gemacht." -Level "DEBUG"
            }
            catch {
                Write-Log -Message "Fallback für Panel '$($TargetPanel.Name)' fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
                return
            }
        }

        # Initialisiere den aktuellen Tab
        try {
            Initialize-CurrentTab -Panel $TargetPanel
        }
        catch {
            Write-Log -Message "Fehler bei der Tab-Initialisierung: $($_.Exception.Message)" -Level "WARN"
        }

        # Falls ein TabItem übergeben wurde, zu diesem wechseln
        if ($null -ne $TabItem) {
            try {
                Write-Log -Message "Wechsle zu UnterTab: $($TabItem.Header)" -Level "INFO"
                $TabItem.IsSelected = $true
            }
            catch {
                Write-Log -Message "Fehler beim Wechseln zu TabItem: $($_.Exception.Message)" -Level "WARN"
            }
        }
    }
    catch {
        Write-Log -Message "Fehler beim Umschalten des Tabs: $($_.Exception.Message)" -Level "ERROR"
        Write-Log -Message "Stacktrace: $($_.Exception.StackTrace)" -Level "DEBUG"
    }
}

# Hilfsfunktion zum Befüllen der Zusammenfassungs-GUI in Tab 7
function Update-OnboardingSummaryGUI {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Aktualisiere GUI-Zusammenfassung in Tab 7..." -Level "DEBUG"

        # Sammle die aktuellen Daten aus den vorherigen Tabs
        # Annahme: Eine Funktion wie Get-UserDataFromGUI existiert und sammelt alle relevanten Daten
        $userData = Get-UserDataFromGUI
        if (-not $userData) {
            Write-Log -Message "Keine Benutzerdaten zum Anzeigen in der Zusammenfassung verfügbar." -Level "WARN"
            return
        }

        # Finde die GUI-Elemente für die Zusammenfassung
        $summaryControls = @{
            "summaryFullName"      = "$($userData.FirstName) $($userData.LastName)"
            "summaryUsername"      = $userData.SamAccountName
            "summaryEmail"         = $userData.EmailAddress
            "summaryDepartment"    = $userData.Department
            "summaryPosition"      = $userData.Position
            "summaryOU"            = $userData.OUPath
            "summaryM365Status"    = if ($userData.AssignLicense) { "Aktiviert" } else { "Deaktiviert" }
            "summaryM365License"   = if ($userData.AssignLicense) { $userData.LicenseType } else { "Keine" }
            "summaryMailboxStatus" = if ($userData.CreateMailbox) { "Wird erstellt" } else { "Nicht angefordert" }
        }

        # Aktualisiere die TextBlock-Elemente
        foreach ($controlName in $summaryControls.Keys) {
            $control = $Window.FindName($controlName)
            if ($control) {
                $control.Text = $summaryControls[$controlName]
            }
        }

        # Aktualisiere die Gruppenliste
        $summaryGroupList = $Window.FindName("summaryGroupList")
        $summaryGroupCount = $Window.FindName("summaryGroupCount")
        if ($summaryGroupList -and $summaryGroupCount) {
            $summaryGroupList.Items.Clear()
            $selectedGroups = @($global:Variables['lstSelectedGroups'].Items) # Annahme: Gruppen sind hier gespeichert
            foreach ($group in $selectedGroups) {
                $summaryGroupList.Items.Add($group)
            }
            $summaryGroupCount.Text = "$($selectedGroups.Count) Gruppen zugewiesen"
        }

        # Setze Standardwerte für die Abschluss-Aktionen basierend auf der Konfiguration
        $Window.FindName("chkSendWelcomeEmail").IsChecked = Get-ConfigValue -Section "Notifications" -Key "SendWelcomeEmail" -DefaultValue $true
        $Window.FindName("chkNotifyManager").IsChecked = Get-ConfigValue -Section "Notifications" -Key "NotifyManager" -DefaultValue $true
        $Window.FindName("chkSendPasswordToManager").IsChecked = Get-ConfigValue -Section "Notifications" -Key "SendPasswordToManager" -DefaultValue $true
        $Window.FindName("chkCreateDocumentation").IsChecked = Get-ConfigValue -Section "Reporting" -Key "CreateDocumentation" -DefaultValue $true

        Write-Log -Message "GUI-Zusammenfassung erfolgreich aktualisiert." -Level "INFO"
    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren der GUI-Zusammenfassung: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Initialisierungsfunktion für Tab 1
function Initialize-Tab1 {
    param([System.Windows.Controls.Border]$Panel)

    try {
        Write-Log -Message "Initialisiere Tab 1 (Benutzerdaten)" -Level "DEBUG"

        # Steuerelemente aus XAML laden
        $txtFirstName = $Window.FindName("txtFirstName")
        $txtLastName = $Window.FindName("txtLastName")
        $txtUsername = $Window.FindName("txtUsername")
        $txtEmail = $Window.FindName("txtEmail")
        $cmbDepartment = $Window.FindName("cmbDepartment")
        $txtPosition = $Window.FindName("txtPosition")
        $txtManager = $Window.FindName("txtManager")
        $btnBrowseManager = $Window.FindName("btnBrowseManager")
        $cmbOUPath = $Window.FindName("cmbOUPath")
        $btnBrowseOU = $Window.FindName("btnBrowseOU")
        $pwdPassword = $Window.FindName("pwdPassword")
        $btnGeneratePassword = $Window.FindName("btnGeneratePassword")
        $cmbTemplate = $Window.FindName("cmbTemplate")
        $btnLoadTemplates = $Window.FindName("btnLoadTemplates")
        $btnValidateStep1 = $Window.FindName("btnValidateStep1")
        $btnNextStep1 = $Window.FindName("btnNextStep1")

        # --- Event-Handler für automatische Feldgenerierung ---
        if ($txtFirstName -and $txtLastName) {
            $txtFirstName.add_TextChanged({ Update-GeneratedFields })
            $txtLastName.add_TextChanged({ Update-GeneratedFields })
        }

        # --- Benutzervorlagen ---
        if ($cmbTemplate) {
            $cmbTemplate.DisplayMemberPath = "Name"
            $cmbTemplate.SelectedValuePath = "Key"
            $cmbTemplate.add_SelectionChanged({
                    param($eventSender, $eventData)
                    $selectedTemplate = $eventSender.SelectedItem
                    if ($selectedTemplate -and $selectedTemplate.Key -ne "None") {
                        Apply-UserTemplate -TemplateName $selectedTemplate.Key -Window $Window
                    }
                })
        }

        if ($btnLoadTemplates) {
            $btnLoadTemplates.add_Click({
                    Invoke-LoadTemplatesAndOverrideGlobals -Window $Window
                    # Dropdown nach dem Neuladen aktualisieren
                    Update-TemplateDropdown
                })
        }
        Update-TemplateDropdown # Initiales Laden

        # --- Abteilungen ---
        if ($cmbDepartment) {
            $cmbDepartment.add_SelectionChanged({
                    $selectedDepartment = $this.SelectedItem
                    if ($selectedDepartment) {
                        # Stelle sicher, dass cmbOUPath innerhalb des Event-Handlers neu abgerufen wird
                        $cmbOUPathCtrl = $Window.FindName("cmbOUPath")
                        Update-OUDropdownFromDepartment -OUComboBox $cmbOUPathCtrl -DepartmentName $selectedDepartment
                    }
                })
            Update-DepartmentDropdown # Initiales Laden
        }

        # --- Active Directory & Passwort ---
        if ($btnBrowseManager) {
            $btnBrowseManager.add_Click({
                try {
                Write-Log -Message "Manager-Auswahl-Dialog wird geöffnet..." -Level "DEBUG"

                $manager = Select-ADUser -Title "Manager auswählen"
                if ($manager) {
                    Write-Log -Message "Manager ausgewählt: $($manager.DisplayName) ($($manager.SamAccountName))" -Level "INFO"

                    # Stelle sicher, dass txtManager verfügbar ist
                    if ($txtManager) {
                    # Verwende DisplayName oder falls nicht verfügbar, erstelle einen aus GivenName und Surname
                    $displayName = if ($manager.DisplayName) {
                        $manager.DisplayName
                    } elseif ($manager.GivenName -and $manager.Surname) {
                        "$($manager.GivenName) $($manager.Surname)"
                    } else {
                        $manager.SamAccountName
                    }

                    $txtManager.Text = $displayName
                    Write-Log -Message "Manager-Feld aktualisiert mit: $displayName" -Level "DEBUG"

                    # Speichere den Distinguished Name für spätere Verwendung
                    $global:SelectedManagerDN = $manager.DistinguishedName
                    Write-Log -Message "Manager DN gespeichert: $($manager.DistinguishedName)" -Level "DEBUG"
                    } else {
                    Write-Log -Message "txtManager-Feld nicht gefunden" -Level "WARN"
                    }
                } else {
                    Write-Log -Message "Kein Manager ausgewählt" -Level "DEBUG"
                }
                }
                catch {
                Write-Log -Message "Fehler bei Manager-Auswahl: $($_.Exception.Message)" -Level "ERROR"
                [System.Windows.MessageBox]::Show(
                    "Fehler bei der Manager-Auswahl: $($_.Exception.Message)",
                    "Fehler",
                    "OK",
                    "Error"
                )
                }
            })
        }

        # --- OU-Dropdown ---
        if ($btnBrowseOU) {
            $btnBrowseOU.add_Click({
                    try {
                        Write-Log -Message "OU-Dropdown wird aktualisiert..." -Level "INFO"

                        # Zuerst die OU-Liste aktualisieren
                        if ($cmbOUPath) {
                            Update-OUDropdown -ComboBox $cmbOUPath -IncludeUsersAndComputers
                            Write-Log -Message "OU-Dropdown erfolgreich aktualisiert" -Level "INFO"
                        }

                        # Optional: Dialog zum Auswählen einer speziellen OU öffnen
                        $result = [System.Windows.MessageBox]::Show(
                            "Die OU-Liste wurde aktualisiert.`n`nMöchten Sie eine spezielle OU aus dem Verzeichnis auswählen?",
                            "OU auswählen",
                            "YesNo",
                            "Question"
                        )

                        if ($result -eq "Yes") {
                            $ou = Select-ADOU -Title "OU auswählen"
                            if ($ou) {
                                $cmbOUPath.Text = $ou.DistinguishedName
                            }
                        }
                    }
                    catch {
                        Write-Log -Message "Fehler beim Aktualisieren der OU-Liste: $($_.Exception.Message)" -Level "ERROR"
                        [System.Windows.MessageBox]::Show(
                            "Fehler beim Aktualisieren der OU-Liste: $($_.Exception.Message)",
                            "Fehler",
                            "OK",
                            "Error"
                        )
                    }
                })
        }

        # --- Passwort-Generierung ---
        if ($btnGeneratePassword) {
            $btnGeneratePassword.add_Click({
                    $pwdPassword.Password = New-SecurePassword
                })
        }

        # --- Validierung und Navigation ---
        if ($btnValidateStep1) {
            $btnValidateStep1.add_Click({
                    Invoke-ValidateStep1 -ShowMessages $true
                })
        }

        if ($btnNextStep1) {
            $btnNextStep1.add_Click({
                    $validationResult = Invoke-ValidateStep1 -ShowMessages $true
                    if ($validationResult.IsValid) {
                        Switch-Tab -TargetPanel $global:Variables["step2Panel"]
                    }
                })
        }

        Write-Log -Message "Tab 1 (Benutzerdaten) erfolgreich initialisiert." -Level "DEBUG"
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Tab 1: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Initialisierungsfunktion für Tab 2
function Initialize-Tab2 {
    param([System.Windows.Controls.Border]$Panel)

    try {
        Write-Log -Message "Initialisiere Tab 2 (Gruppenzuweisung)" -Level "DEBUG"

        # Steuerelemente aus XAML laden
        $txtGroupSearch = $Window.FindName("txtGroupSearch")
        $lstAvailableGroups = $Window.FindName("lstAvailableGroups")
        $lstSelectedGroups = $Window.FindName("lstSelectedGroups")
        $btnAddGroup = $Window.FindName("btnAddGroup")
        $btnAddAllGroups = $Window.FindName("btnAddAllGroups")
        $btnRemoveGroup = $Window.FindName("btnRemoveGroup")
        $btnRemoveAllGroups = $Window.FindName("btnRemoveAllGroups")
        $groupCountText = $Window.FindName("groupCountText")
        $btnPrevStep2 = $Window.FindName("btnPrevStep2")
        $btnCreateUser = $Window.FindName("btnCreateUser")

        # Gruppenlisten initialisieren, sobald der Tab geöffnet wird
        Initialize-GroupLists

        # Event-Handler für Buttons
        if ($btnAddGroup) {
            $btnAddGroup.add_Click({
                    try {
                        $lstAvailable = $Window.FindName("lstAvailableGroups")
                        $lstSelected = $Window.FindName("lstSelectedGroups")
                        if ($lstAvailable -and $lstSelected) {
                            Move-SelectedGroups -FromList $lstAvailable -ToList $lstSelected
                            Update-GroupCount
                        } else {
                            Write-Log -Message "ListBox-Steuerelemente für Gruppenbewegung nicht gefunden" -Level "WARN"
                        }
                    } catch {
                        Write-Log -Message "Fehler beim Hinzufügen von Gruppen: $($_.Exception.Message)" -Level "ERROR"
                    }
                })
        }

        if ($btnAddAllGroups) {
            $btnAddAllGroups.add_Click({
                    try {
                        $lstAvailable = $Window.FindName("lstAvailableGroups")
                        $lstSelected = $Window.FindName("lstSelectedGroups")
                        if ($lstAvailable -and $lstSelected) {
                            Move-AllGroups -FromList $lstAvailable -ToList $lstSelected
                            Update-GroupCount
                        } else {
                            Write-Log -Message "ListBox-Steuerelemente für Gruppenbewegung nicht gefunden" -Level "WARN"
                        }
                    } catch {
                        Write-Log -Message "Fehler beim Hinzufügen aller Gruppen: $($_.Exception.Message)" -Level "ERROR"
                    }
                })
        }

        if ($btnRemoveGroup) {
            $btnRemoveGroup.add_Click({
                    try {
                        $lstAvailable = $Window.FindName("lstAvailableGroups")
                        $lstSelected = $Window.FindName("lstSelectedGroups")
                        if ($lstAvailable -and $lstSelected) {
                            Move-SelectedGroups -FromList $lstSelected -ToList $lstAvailable
                            Update-GroupCount
                        } else {
                            Write-Log -Message "ListBox-Steuerelemente für Gruppenbewegung nicht gefunden" -Level "WARN"
                        }
                    } catch {
                        Write-Log -Message "Fehler beim Entfernen von Gruppen: $($_.Exception.Message)" -Level "ERROR"
                    }
                })
        }

        if ($btnRemoveAllGroups) {
            $btnRemoveAllGroups.add_Click({
                    try {
                        $lstAvailable = $Window.FindName("lstAvailableGroups")
                        $lstSelected = $Window.FindName("lstSelectedGroups")
                        if ($lstAvailable -and $lstSelected) {
                            Move-AllGroups -FromList $lstSelected -ToList $lstAvailable
                            Update-GroupCount
                        } else {
                            Write-Log -Message "ListBox-Steuerelemente für Gruppenbewegung nicht gefunden" -Level "WARN"
                        }
                    } catch {
                        Write-Log -Message "Fehler beim Entfernen aller Gruppen: $($_.Exception.Message)" -Level "ERROR"
                    }
                })
        }

        # Event-Handler für Navigation
        if ($btnPrevStep2) {
            $btnPrevStep2.add_Click({
                    Switch-Tab -TargetPanel $global:Variables["step1Panel"]
                })
        }

        if ($btnCreateUser) {
            $btnCreateUser.add_Click({
                    Invoke-CreateUser
                })
        }

        # Event-Handler für die Gruppensuche
        if ($txtGroupSearch) {
            $txtGroupSearch.add_TextChanged({
                    param($eventSender, $eventData)
                    try {
                        $searchText = $eventSender.Text
                        Write-Log -Message "Filtere Gruppenliste mit: '$searchText'" -Level "DEBUG"

                        # Hole die aktuell ausgewählten Gruppen, damit sie nicht in der verfügbaren Liste erscheinen
                        $selectedGroups = @($lstSelectedGroups.Items)

                        # Lade die gefilterten Gruppen
                        $availableGroups = Get-FilteredAvailableGroups -CurrentlySelectedGroups $selectedGroups -SearchFilter $searchText

                        # Aktualisiere die ListBox der verfügbaren Gruppen
                        $lstAvailableGroups.Items.Clear()
                        foreach ($groupName in $availableGroups) {
                            if (-not [string]::IsNullOrWhiteSpace($groupName)) {
                                $lstAvailableGroups.Items.Add($groupName)
                            }
                        }
                    }
                    catch {
                        Write-Log -Message "Fehler beim Filtern der Gruppen: $($_.Exception.Message)" -Level "ERROR"
                    }
                })
        }

        Write-Log -Message "Tab 2 (Gruppenzuweisung) erfolgreich initialisiert." -Level "DEBUG"
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Tab 2: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Initialisierungsfunktion für Tab 3
function Initialize-Tab3 {
    param([System.Windows.Controls.Border]$Panel)

    try {
        Write-Log -Message "Initialisiere Tab 3 (Erweiterte Einstellungen)" -Level "DEBUG"

        # Steuerelemente für erweiterte Einstellungen aus XAML laden
        $txtPhone = $Window.FindName("txtPhone")
        $txtMobile = $Window.FindName("txtMobile")
        $txtOffice = $Window.FindName("txtOffice")
        $txtLocation = $Window.FindName("txtLocation")
        $txtDescription = $Window.FindName("txtDescription")
        $chkMustChangePassword = $Window.FindName("chkMustChangePassword")
        $chkPasswordNeverExpires = $Window.FindName("chkPasswordNeverExpires")
        $chkCannotChangePassword = $Window.FindName("chkCannotChangePassword")
        $chkAccountDisabled = $Window.FindName("chkAccountDisabled")
        $btnPrevStep3 = $Window.FindName("btnPrevStep3")
        $btnUpdateUser3 = $Window.FindName("btnUpdateUser3")
        $btnNextStep3 = $Window.FindName("btnNextStep3")

        # Hilfsfunktion zum Aktualisieren des Benutzers, um Code-Duplizierung zu vermeiden
        $updateUserAction = {
            param($ShowSuccessMessage)

            try {
                Write-Log -Message "Aktualisiere Benutzer mit erweiterten Einstellungen..." -Level "INFO"

                # Prüfen, ob ein Benutzer in Schritt 2 erstellt wurde
                if (-not $global:CreatedUserSAM) {
                    [System.Windows.MessageBox]::Show("Es wurde noch kein Benutzer erstellt, der aktualisiert werden kann. Bitte führen Sie zuerst Schritt 2 aus.", "Fehler", "OK", "Warning")
                    return $false
                }

                # Sammle Daten aus den Feldern
                $updateParams = @{
                    Identity = $global:CreatedUserSAM
                }
                if ($txtPhone.Text) { $updateParams.OfficePhone = $txtPhone.Text }
                if ($txtMobile.Text) { $updateParams.MobilePhone = $txtMobile.Text }
                if ($txtOffice.Text) { $updateParams.Office = $txtOffice.Text }
                if ($txtLocation.Text) { $updateParams.City = $txtLocation.Text } # Annahme: Standort = City
                if ($txtDescription.Text) { $updateParams.Description = $txtDescription.Text }

                # ProxyAddresses über eine dedizierte Funktion generieren und zum Update hinzufügen
                $proxyAddressesToAdd = Get-ProxyAddressesForUser -PrimaryEmail $global:CreatedUserEmail -UserPrincipalName $global:CreatedUserUPN -SamAccountName $global:CreatedUserSAM -UserData $global:CreatedUserData
                if ($proxyAddressesToAdd.Count -gt 0) {
                    # Hole bestehende Proxy-Adressen, um Duplikate zu vermeiden
                    $existingUser = Get-ADUser -Identity $global:CreatedUserSAM -Properties proxyAddresses
                    $existingProxies = $existingUser.proxyAddresses

                    # Filtere Adressen, die bereits vorhanden sind
                    $newProxyAddresses = $proxyAddressesToAdd | Where-Object { $existingProxies -notcontains $_ }

                    if ($newProxyAddresses.Count -gt 0) {
                        $updateParams.Add = @{ proxyAddresses = $newProxyAddresses }
                    }
                }

                # Wende Konto-Optionen an
                Set-ADUser @updateParams -ChangePasswordAtLogon $chkMustChangePassword.IsChecked -PasswordNeverExpires $chkPasswordNeverExpires.IsChecked -CannotChangePassword $chkCannotChangePassword.IsChecked -Enabled (-not $chkAccountDisabled.IsChecked)

                Write-Log -Message "Benutzer '$($global:CreatedUserSAM)' erfolgreich aktualisiert." -Level "INFO"
                if ($ShowSuccessMessage) {
                    [System.Windows.MessageBox]::Show("Benutzer erfolgreich mit den erweiterten Einstellungen aktualisiert.", "Erfolg", "OK", "Information")
                }
                return $true
            }
            catch {
                $errorMessage = "Fehler beim Aktualisieren des Benutzers: $($_.Exception.Message)"
                Write-Log -Message $errorMessage -Level "ERROR"
                [System.Windows.MessageBox]::Show($errorMessage, "Update-Fehler", "OK", "Error")
                return $false
            }
        }

        # Event-Handler für Navigation
        if ($btnPrevStep3) {
            $btnPrevStep3.add_Click({
                    Switch-Tab -TargetPanel $global:Variables["step2Panel"]
                })
        }

        if ($btnNextStep3) {
            $btnNextStep3.add_Click({
                    # Benutzer aktualisieren, bevor zum nächsten Schritt gewechselt wird
                    if (& $updateUserAction -ShowSuccessMessage $false) {
                        # In der aktuellen Logik ist der nächste Schritt die Zusammenfassung
                        Switch-Tab -TargetPanel $global:Variables["step7Panel"]
                    }
                })
        }

        # Event-Handler für "Benutzer aktualisieren"
        if ($btnUpdateUser3) {
            $btnUpdateUser3.add_Click({
                    & $updateUserAction -ShowSuccessMessage $true
                })
        }

        Write-Log -Message "Tab 3 (Erweiterte Einstellungen) erfolgreich initialisiert." -Level "DEBUG"
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Tab 3: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Initialisierungsfunktion für Tab 7
function Initialize-Tab7 {
    param([System.Windows.Controls.Border]$Panel)

    try {
        Write-Log -Message "Initialisiere Tab 7 (Zusammenfassung & Abschluss)" -Level "DEBUG"

        # Steuerelemente für die Zusammenfassung finden
        $btnPrevStep7 = $Window.FindName("btnPrevStep7")
        $btnStartNew = $Window.FindName("btnStartNew")
        $btnFinalizeOnboarding = $Window.FindName("btnFinalizeOnboarding")
        $txtFinalLog = $Window.FindName("txtFinalLog")

        # Zusammenfassung mit den aktuellen Daten befüllen
        Update-OnboardingSummaryGUI

        # Event-Handler für die Buttons
        if ($btnPrevStep7) {
            # Annahme: Schritt 6 ist der vorherige Schritt. Anpassen, falls nicht korrekt.
            $btnPrevStep7.add_Click({ Switch-Tab -TargetPanel $global:Variables["step3Panel"] })
        }

        if ($btnStartNew) {
            $btnStartNew.add_Click({
                    # Hier eine Funktion aufrufen, die die gesamte GUI zurücksetzt
                    # z.B. Reset-GUI
                    [System.Windows.MessageBox]::Show("Diese Funktion setzt die GUI zurück, um einen neuen Benutzer anzulegen.", "Info", "OK", "Information")
                    Switch-Tab -TargetPanel $global:Variables["step1Panel"]
                })
        }

        if ($btnFinalizeOnboarding) {
            $btnFinalizeOnboarding.add_Click({
                    # Hier den finalen Workflow-Prozess starten
                    # z.B. Start-OnboardingWorkflow -FinalLogBox $txtFinalLog
                    [System.Windows.MessageBox]::Show("Der Onboarding-Prozess wird jetzt abgeschlossen.", "Abschluss", "OK", "Information")
                    # $Window.Close() # Optional nach Abschluss
                })
        }

        # Initialisiere das Log-Textfeld
        if ($txtFinalLog) {
            $txtFinalLog.Text = "Bereit zum Abschluss des Onboarding-Prozesses..."
        }

        Write-Log -Message "Tab 7 (Zusammenfassung & Abschluss) erfolgreich initialisiert." -Level "DEBUG"
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Tab 7: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Master-Funktion zur Initialisierung des aktuellen Tabs
function Initialize-CurrentTab {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.Border]$Panel
    )

    try {
        Write-Log -Message "Initialisiere Tab für Panel: $($Panel.Name)" -Level "DEBUG"

        # Anhand des Panel-Namens die passende Initialize-Funktion aufrufen
        switch ($Panel.Name) {
            "step1Panel" { Initialize-Tab1 -Panel $Panel }
            "step2Panel" { Initialize-Tab2 -Panel $Panel }
            "step3Panel" { Initialize-Tab3 -Panel $Panel }
            "step7Panel" { Initialize-Tab7 -Panel $Panel }
            default { Write-Log -Message "Kein bekanntes Panel zum Initialisieren: $($Panel.Name)" -Level "WARN" }
        }
    }

    catch {
        Write-Log -Message "Fehler bei der Initialisierung des Tabs: $($_.Exception.Message)" -Level "ERROR"
    }
}

Write-Log -Message "Event-Handler für die Navigation werden registriert." -Level "DEBUG"

#region GUI Initialization
function Initialize-GUI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot
    )

    try {
        Write-Log -Message "Initialisiere GUI..." -Level "INFO"

        # XAML-Pfad bestimmen
        $xamlPath = Join-Path $ScriptRoot "assets\ONBGUI.XAML"

        if (-not (Test-Path $xamlPath)) {
            throw "XAML-Datei nicht gefunden: $xamlPath"
        }

        Write-Log -Message "Lade XAML von: $xamlPath" -Level "DEBUG"

        # XAML laden
        $xamlContent = Get-Content $xamlPath -Raw

        # Entferne problematische Blend-Namespace-Attribute falls noch vorhanden
        $xamlContent = $xamlContent -replace 'd:DesignHeight="[^"]*"', ''
        $xamlContent = $xamlContent -replace 'd:DesignWidth="[^"]*"', ''
        $xamlContent = $xamlContent -replace 'mc:Ignorable="[^"]*"', ''

        # XAML als XML parsen
        [xml]$xaml = $xamlContent

        # XAML-Reader erstellen
        $reader = New-Object System.Xml.XmlNodeReader $xaml

        # Window-Objekt erstellen
        $Window = [Windows.Markup.XamlReader]::Load($reader)

        # Global Variables Hash Table erstellen
        $global:Variables = @{}

        # Alle benannten Elemente finden und in globale Variablen speichern
        $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
            $name = $_.Name
            if ($name) {
                try {
                    $element = $Window.FindName($name)
                    if ($element) {
                        $global:Variables[$name] = $element
                        Write-Log -Message "Element '$name' erfolgreich gebunden" -Level "DEBUG"
                    }
                }
                catch {
                    Write-Log -Message "Fehler beim Binden von Element '$name': $($_.Exception.Message)" -Level "WARN"
                }
            }
        }

        Write-Log -Message "GUI erfolgreich initialisiert. $($global:Variables.Count) Elemente gebunden." -Level "INFO"

        # Globale Exception-Handler registrieren
        Add-GlobalExceptionHandlers -Window $Window

        return $Window

    }
    catch {
        $errorMessage = "Fehler bei der GUI-Initialisierung: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        [System.Windows.MessageBox]::Show($errorMessage, "Initialisierungsfehler", "OK", "Error")
        return $null
    }
}
#endregion

# Lade die benötigten Assemblies für die GUI
if (-not (Import-RequiredAssemblies)) {
    Write-Log -Message "Das Skript wird aufgrund von Fehlern beim Laden der Assemblies beendet." -Level "ERROR"
    exit 1
}

# Lade Benutzervorlagen und Abteilungsdaten nach dem die Funktionen definiert wurden
try {
    Write-Host "Lade Benutzervorlagen..." -ForegroundColor Green
    $global:UserTemplateData = Import-UserTemplates

    Write-Host "Lade Abteilungsdaten..." -ForegroundColor Green
    $global:DepartmentData = Import-Departments

    Write-Host "Benutzervorlagen und Abteilungsdaten erfolgreich geladen" -ForegroundColor Green
}
catch {
    $errorMessage = "Fehler beim Laden der Benutzervorlagen oder Abteilungsdaten: $($_.Exception.Message)"
    Write-Host $errorMessage -ForegroundColor Red
    Write-Log -Message $errorMessage -Level "ERROR"
    # Setze leere Standardwerte um das Skript nicht zu beenden
    $global:UserTemplateData = @{}
    $global:DepartmentData = @{}
}
try {
    # Die GUI initialisieren
    $result = Initialize-GUI -ScriptRoot $ScriptRoot

    # Prüfe ob ein Array zurückgegeben wurde
    if ($result -is [System.Array]) {
        Write-Log -Message "Initialize-GUI hat ein Array mit $($result.Count) Elementen zurückgegeben" -Level "WARN"
        if ($result.Count -gt 0) {
            $Window = $result[0]
            Write-Log -Message "Verwende erstes Element des Arrays als Window" -Level "INFO"
        }
        else {
            throw "Initialize-GUI hat ein leeres Array zurückgegeben"
        }
    }
    else {
        $Window = $result
    }

    if (-not $Window) {
        throw "GUI-Fenster konnte nicht initialisiert werden."
    }

    # Setze globale Window-Variable
    $global:Window = $Window

    Write-Log -Message "GUI-Fensterobjekt erfolgreich erstellt. Typ: $($Window.GetType().FullName)" -Level "DEBUG"

    # Aufruf der Funktion nach der GUI-Initialisierung
    Write-Log -Message "Rufe Get-GuiControls auf..." -Level "DEBUG"
    $global:allPanels = Get-GuiControls -Window $Window

    # Initialisiere Step 1 - damit werden die DropDowns befüllt
    Write-Log -Message "Initialisiere Step 1 mit DropDowns..." -Level "INFO"
    Initialize-Step1

    Write-Log -Message "Get-GuiControls Rückgabewert: $($null -ne $global:allPanels)" -Level "DEBUG"
    Write-Log -Message "Global:Variables Count: $($global:Variables.Count)" -Level "DEBUG"
    Write-Log -Message "Global:Variables Keys: $($global:Variables.Keys -join ', ')" -Level "DEBUG"

    if ($global:allPanels -and $global:allPanels.Count -gt 0) {
        Write-Log -Message "Anzahl gefundener Panels: $($global:allPanels.Count)" -Level "DEBUG"
        foreach ($panel in $global:allPanels) {
            if ($panel) {
                Write-Log -Message "Panel gefunden: $($panel.Name) (Typ: $($panel.GetType().Name))" -Level "DEBUG"
            }
            else {
                Write-Log -Message "Null-Panel in allPanels gefunden!" -Level "WARN"
            }
        }
    }
    else {
        Write-Log -Message "Keine Panels gefunden oder allPanels ist null/leer" -Level "WARN"
    }

    if (-not $global:allPanels -or $global:allPanels.Count -eq 0) {
        Write-Log -Message "GUI-Steuerelemente konnten nicht korrekt gebunden werden - verwende Fallback" -Level "WARN"
    }
    else {
        Write-Log -Message "GUI-Steuerelemente erfolgreich initialisiert." -Level "DEBUG"
    }

    # Event-Handler für die aktiven Navigations-Buttons hinzufügen
    Write-Log -Message "Füge Event-Handler für Navigation-Buttons hinzu..." -Level "DEBUG"
    $activeSteps = @(1, 2, 3, 7)
    foreach ($i in $activeSteps) {
        $buttonName = "btnStep$i"
        $panelName = "step${i}Panel"

        Write-Log -Message "Prüfe $buttonName und $panelName..." -Level "DEBUG"
        Write-Log -Message "$buttonName vorhanden: $($global:Variables.ContainsKey($buttonName))" -Level "DEBUG"
        Write-Log -Message "$panelName vorhanden: $($global:Variables.ContainsKey($panelName))" -Level "DEBUG"

        if ($global:Variables.ContainsKey($buttonName) -and $global:Variables.ContainsKey($panelName)) {
            Write-Log -Message "Füge Event-Handler für $buttonName hinzu..." -Level "DEBUG"
            $global:Variables[$buttonName].add_Click({
                    param($clickSender, $clickArgs)
                    $step = [regex]::Match($clickSender.Name, '\d+').Value
                    Write-Log -Message "Button '$($clickSender.Name)' geklickt. Wechsle zu Schritt $step." -Level "DEBUG"
                    Switch-Tab -TargetPanel $global:Variables["step${step}Panel"]
                })
            Write-Log -Message "Event-Handler für $buttonName erfolgreich hinzugefügt." -Level "DEBUG"
        }
        else {
            Write-Log -Message "Button $buttonName oder Panel $panelName nicht gefunden." -Level "WARN"
        }
    }

    # Erweiterte GUI-Steuerelemente binden
    Expand-GuiControls -Window $Window

    # Menü-System initialisieren
    Initialize-MenuSystem -Window $Window

    # Standard-Tab anzeigen (erster Tab)
    try {
        Write-Log -Message "Versuche initialen Tab anzuzeigen..." -Level "DEBUG"
        Safe-SwitchTab -PanelName "step1Panel"
    }
    catch {
        Write-Log -Message "Fehler beim Anzeigen des initialen Tabs: $($_.Exception.Message)" -Level "ERROR"

        # Letzter Fallback - versuche manuell
        try {
            $step1Panel = $Window.FindName("step1Panel")
            if ($step1Panel) {
                $step1Panel.Visibility = "Visible"
                Write-Log -Message "step1Panel als letzter Fallback direkt angezeigt." -Level "INFO"
            }
            else {
                Write-Log -Message "KRITISCHER FEHLER: step1Panel konnte nicht gefunden werden." -Level "ERROR"
            }
        }
        catch {
            Write-Log -Message "Auch der letzte Fallback ist fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
        }
    }

    # --- FENSTER ANZEIGEN ---
    Write-Log -Message "GUI wird gestartet. Warte auf Benutzereingaben."
    [void]$Window.ShowDialog()
}
catch {
    Write-Log -Message "Fehler beim Ausführen des Skripts: $($_.Exception.Message)" -Level "ERROR"
    [System.Windows.Forms.MessageBox]::Show("Ein Fehler ist aufgetreten: $($_.Exception.Message)", "Fehler", "OK", "Error")
}
finally {
    Write-Log -Message "Skript beendet."
}
#endregion
