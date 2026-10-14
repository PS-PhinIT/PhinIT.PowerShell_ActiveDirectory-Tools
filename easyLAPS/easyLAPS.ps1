#Requires -Version 5.1
# easyLAPS - AD LAPS Passwort-Manager (GUI)
# Autor: Andreas Hepp | www.phinit.de
# Versionsangaben werden ausschließlich in diesem Skript, README.md und CHANGELOG.md gepflegt.

#region [0.0 | EXE-Kompabilität]
# Stellt sicher, dass das Skript als kompilierte EXE korrekt ausgeführt wird.

# GUI-spezifische Optimierungen für die EXE-Kompilierung
if ($PSVersionTable.PSEdition -ne 'Core' -and -not $ProgressPreference) {
    # Unterdrückt Fortschrittsanzeigen, die als störende Popup-Fenster erscheinen, wenn sie mit -noConsole kompiliert werden.
    $ProgressPreference = 'SilentlyContinue'
    
    # Aktiviert visuelle Stile für WinForms/WPF-Steuerelemente, um ein modernes Aussehen zu gewährleisten.
    # Dies muss vor der Erstellung von GUI-Objekten erfolgen.
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Application]::EnableVisualStyles()
    } catch {
        # Dieser Fehler kann ignoriert werden, wenn System.Windows.Forms nicht verfügbar ist.
    }
}

# Universelle Pfadermittlung für Skript- und EXE-Modus
# Die Variable $PSScriptRoot ist in einer kompilierten EXE-Datei leer.
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    # Modus: PowerShell-Skript (.ps1)
    # $PSScriptRoot ist im Skriptmodus zuverlässig.
    $script:ScriptPath = $PSScriptRoot
} else {
    # Modus: Kompilierte Anwendung (.exe)
    # Ermittelt den Pfad aus den Befehlszeilenargumenten der Anwendung.
    $script:ScriptPath = Split-Path -Parent -Path ([System.Environment]::GetCommandLineArgs()[0])
    # Fallback auf das aktuelle Verzeichnis, wenn der Pfad nicht ermittelt werden kann.
    if (-not $script:ScriptPath) { $script:ScriptPath = "." }
}
#endregion

#region [1.0 | Variablen und Konfiguration]
# Skriptinformationen
$script:ScriptInfo = @{
    AppName = "easyLAPS"
    ScriptVersion = "0.5.0"
    Author = "Andreas Hepp"
    ThemeColor = "#0078D7"
    LastUpdate = "2026-10-14"
    Company = "PhinIT"
    Website = "https://www.phinit.de"
    Description = "Local Admin Password Solution fuer Windows-Umgebungen"
    Copyright = "© 2026 PhinIT"
}

# Branding-GUI Einstellungen
$script:BrandingGUI = @{
    APPName = $script:ScriptInfo.AppName
    FontFamily = "Segoe UI"
    FooterWebseite = $script:ScriptInfo.Website
    ThemeColor = $script:ScriptInfo.ThemeColor
}

# Pfade und Einstellungen
$script:logPath = Join-Path $script:ScriptPath "Logs"
$script:logFile = "$($script:ScriptInfo.AppName)_$(Get-Date -Format 'yyyyMMdd').log"
$script:LogFilePath = Join-Path $script:logPath $script:logFile
$script:registryPath = "HKCU:\Software\easyIT\$($script:ScriptInfo.AppName)"

# Debug-Einstellungen
$script:debugMode = $false
$script:logLevel = "Info" # Mögliche Werte: Error, Warning, Info, Debug
$script:logRotationDays = 30 # Logs älter als X Tage werden gelöscht
$script:logRotationDone = $false # Log-Rotation nur einmal pro Programmstart

# Sicherheit: Zwischenablage nach X Sekunden automatisch leeren (0 = deaktiviert)
$script:ClipboardClearSeconds = 30

# Stellen Sie sicher, dass der Log-Ordner existiert
if (-not (Test-Path -Path $script:logPath)) {
    try {
        New-Item -Path $script:logPath -ItemType Directory -Force | Out-Null
        Write-Host "Log-Verzeichnis erstellt: $($script:logPath)" -ForegroundColor Green
    }
    catch {
        Write-Host "Fehler beim Erstellen des Log-Verzeichnisses: $_" -ForegroundColor Red
    }
}

# Initialisiere Registry-Einstellungen
try {
    if (-not (Test-Path -Path $script:registryPath)) {
        New-Item -Path $script:registryPath -Force | Out-Null
        New-ItemProperty -Path $script:registryPath -Name "Debug" -Value 0 -PropertyType DWORD -Force | Out-Null
        New-ItemProperty -Path $script:registryPath -Name "AppName" -Value $script:ScriptInfo.AppName -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $script:registryPath -Name "Version" -Value $script:ScriptInfo.ScriptVersion -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $script:registryPath -Name "ThemeColor" -Value $script:ScriptInfo.ThemeColor -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $script:registryPath -Name "LogPath" -Value $script:logPath -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $script:registryPath -Name "LogRotationDays" -Value $script:logRotationDays -PropertyType DWORD -Force | Out-Null
    }
    
    # Lade Debug-Einstellungen aus Registry
    $script:debugMode = (Get-ItemProperty -Path $script:registryPath -Name "Debug" -ErrorAction SilentlyContinue).Debug -eq 1
}
catch {
    Write-Host "Fehler beim Initialisieren der Registry-Einstellungen: $_" -ForegroundColor Red
}
#endregion


#region [2.0 | Debug und Logging]
function Write-DebugMessage {
    param (
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][ValidateSet("Info", "Warning", "Error", "Success")][string]$Level = "Info",
        [Parameter(Mandatory=$false)][switch]$NoNewLine
    )
    
    # Wenn Debug-Modus nicht aktiviert ist, nichts tun
    if (-not $script:DebugMode) { return }
    
    # Zeitstempel für die Ausgabe
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Farben je nach Meldungstyp
    $foregroundColor = switch ($Level) {
        "Error"   { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        "Info"    { "Cyan" }
        default   { "White" }
    }
    
    # Ausgabe formatieren
    $formattedMessage = "[$timestamp] [$Level] $Message"
    
    # Ausgabe in Konsole
    if ($NoNewLine) {
        Write-Host $formattedMessage -ForegroundColor $foregroundColor -NoNewline
    } else {
        Write-Host $formattedMessage -ForegroundColor $foregroundColor
    }
}
#endregion

#region [2.1 | Logging]
function Write-Log {
    param (
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][string]$Level = "Info",
        [Parameter(Mandatory=$false)][string]$LogFilePath = $script:LogFilePath
    )
    
    # Debug-Einträge nur im Debug-Modus schreiben
    if ($Level -eq "Debug" -and -not $script:debugMode) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        # Log-Rotation nur einmal pro Programmstart durchführen (nicht bei jedem Log-Eintrag)
        if (-not $script:logRotationDone) {
            $script:logRotationDone = $true
            Invoke-LogRotation
        }

        # Sicherstellen, dass der Log-Ordner existiert
        $logDir = Split-Path -Path $LogFilePath -Parent
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        # Log-Eintrag formatieren
        $logEntry = "[$timestamp] [$Level] $Message"
        
        # In Datei schreiben
        Add-Content -Path $LogFilePath -Value $logEntry -Encoding UTF8
    }
    catch {
        # Fallback wenn Logging fehlschlägt
        $errorMsg = $_.Exception.Message
        Write-Host "FEHLER BEIM LOGGING: $errorMsg" -ForegroundColor Red
        
        # Versuche in temporäre Datei zu schreiben
        try {
            $tempLogPath = Join-Path -Path $env:TEMP -ChildPath "easyLAPS_error.log"
            Add-Content -Path $tempLogPath -Value "[$timestamp] [ERROR] Logging-Fehler: $errorMsg" -Encoding UTF8
            Add-Content -Path $tempLogPath -Value "[$timestamp] [INFO] Originale Nachricht: $Message" -Encoding UTF8
        }
        catch {
            # Wenn auch das fehlschlägt, können wir nichts mehr tun
        }
    }
}

function Invoke-LogRotation {
    try {
        # Prüfe, ob Log-Rotation aktiv ist
        $rotationDays = Get-RegistryValue -Path $script:registryPath -Name "LogRotationDays" -DefaultValue $script:logRotationDays
        
        if ($rotationDays -le 0) { return }
        
        # Berechne Cutoff-Datum
        $cutoffDate = (Get-Date).AddDays(-$rotationDays)
        
        # Finde alle Log-Dateien älter als der Cutoff
        $oldLogs = Get-ChildItem -Path $script:logPath -Filter "*.log" -File -ErrorAction SilentlyContinue | 
                   Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        # Lösche alte Logs
        foreach ($log in $oldLogs) {
            Remove-Item -Path $log.FullName -Force
        }
    }
    catch {
        # Fehler beim Log-Rotation - nur in Konsole ausgeben, nicht ins Log schreiben (Vermeidung von Rekursion)
        Write-Host "Fehler bei Log-Rotation: $($_.Exception.Message)" -ForegroundColor Red
    }
}
#endregion

#region [2.2 | Fehlerbehandlung]
function Get-FormattedError {
    param (
        [Parameter(Mandatory=$true)][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [Parameter(Mandatory=$false)][string]$DefaultText = "Ein unbekannter Fehler ist aufgetreten."
    )
    
    if ($null -eq $ErrorRecord) { return $DefaultText }
    
    try {
        $errorMessage = $ErrorRecord.Exception.Message
        $errorPosition = $ErrorRecord.InvocationInfo.PositionMessage
        $errorType = $ErrorRecord.Exception.GetType().Name
        
        return "[$errorType] $errorMessage`n$errorPosition"
    }
    catch {
        return $DefaultText
    }
}

function Show-ErrorMessage {
    param (
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][string]$Title = "Fehler",
        [Parameter(Mandatory=$false)][System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    $detailedMessage = $Message
    
    if ($ErrorRecord) {
        $errorDetails = Get-FormattedError -ErrorRecord $ErrorRecord
        $detailedMessage += "`n`nDetails: $errorDetails"
    }
    
    # Fehler loggen
    Write-Log -Message $detailedMessage -Level "Error"
    
    # MessageBox anzeigen
    [System.Windows.MessageBox]::Show(
        $detailedMessage,
        $Title,
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    )
}
#endregion

#region [2.3 | Hilfsfunktionen]
function Clear-ClipboardSecret {
    # Leert die Zwischenablage nur, wenn sie noch das zuvor kopierte Passwort enthält.
    try {
        if (-not [string]::IsNullOrEmpty($script:ClipboardSecret) -and
            [System.Windows.Forms.Clipboard]::ContainsText() -and
            [System.Windows.Forms.Clipboard]::GetText() -eq $script:ClipboardSecret) {
            [System.Windows.Forms.Clipboard]::Clear()
            Write-Log -Message "Zwischenablage automatisch geleert." -Level "Info"
        }
    }
    catch {
        Write-Log -Message "Fehler beim Leeren der Zwischenablage: $($_.Exception.Message)" -Level "Warning"
    }
    finally {
        $script:ClipboardSecret = $null
        if ($null -ne $script:ClipboardTimer) { $script:ClipboardTimer.Stop() }
    }
}

function Set-ClipboardSecret {
    # Kopiert ein Geheimnis in die Zwischenablage und leert sie nach $script:ClipboardClearSeconds automatisch.
    param(
        [Parameter(Mandatory=$true)][string]$Text
    )

    [System.Windows.Forms.Clipboard]::SetText($Text)
    $script:ClipboardSecret = $Text

    if ($script:ClipboardClearSeconds -gt 0) {
        if ($null -eq $script:ClipboardTimer) {
            $script:ClipboardTimer = New-Object System.Windows.Threading.DispatcherTimer
            $script:ClipboardTimer.Add_Tick({ Clear-ClipboardSecret })
        }
        $script:ClipboardTimer.Stop()
        $script:ClipboardTimer.Interval = [TimeSpan]::FromSeconds($script:ClipboardClearSeconds)
        $script:ClipboardTimer.Start()
    }
}

function Get-LocalLapsStatus {
    # Ermittelt LAPS-Installation und aktive Policy-Root des lokalen Systems.
    # Policy-Roots in der von Windows LAPS ausgewerteten Reihenfolge (MS Learn: laps-management-policy-settings).
    $status = [ordered]@{
        SystemType    = "Unbekannt"
        LapsInstalled = $false
        LapsType      = ""
        PolicyActive  = $false
        PolicyRoot    = $null
        PolicySource  = $null
    }

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $status.SystemType = if ($os.ProductType -ne 1) { "Server" } else { "Client" }

    $windowsLapsDll = Join-Path -Path $env:SystemRoot -ChildPath "System32\laps.dll"
    $legacyLapsCse = Join-Path -Path $env:ProgramFiles -ChildPath "LAPS\CSE\AdmPwd.dll"
    if ((Test-Path -Path $windowsLapsDll) -or (Get-Module -Name LAPS -ListAvailable -ErrorAction SilentlyContinue)) {
        $status.LapsInstalled = $true
        $status.LapsType = "Windows LAPS"
    }
    elseif (Test-Path -Path $legacyLapsCse) {
        $status.LapsInstalled = $true
        $status.LapsType = "Legacy LAPS (AdmPwd.dll)"
    }

    $policyRoots = [ordered]@{
        "HKLM:\Software\Microsoft\Policies\LAPS"                          = "Windows LAPS (CSP/Intune)"
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\LAPS" = "Windows LAPS (Gruppenrichtlinie)"
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\LAPS\Config"   = "Windows LAPS (lokale Konfiguration)"
        "HKLM:\Software\Policies\Microsoft Services\AdmPwd"              = "Legacy LAPS (Gruppenrichtlinie)"
    }
    foreach ($root in $policyRoots.Keys) {
        $key = Get-Item -Path $root -ErrorAction SilentlyContinue
        if ($null -ne $key -and $key.ValueCount -gt 0) {
            $status.PolicyActive = $true
            $status.PolicyRoot = $root
            $status.PolicySource = $policyRoots[$root]
            break
        }
    }

    return [PSCustomObject]$status
}

function Update-GuiText {
    param (
        [Parameter(Mandatory=$true)][System.Windows.Controls.TextBlock]$TextElement,
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][System.Windows.Media.Brush]$Color = $null,
        [Parameter(Mandatory=$false)][int]$MaxLength = 10000
    )
    
    try {
        if ($null -eq $TextElement) { return }
        
        # Text kürzen, wenn zu lang
        if ($Message.Length -gt $MaxLength) {
            $Message = $Message.Substring(0, $MaxLength) + "... (gekürzt)"
        }
        
        # Dispatcher verwenden, um Thread-Sicherheit zu gewährleisten
        $TextElement.Dispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Normal,
            [System.Action]{
                $TextElement.Text = $Message
                if ($null -ne $Color) {
                    $TextElement.Foreground = $Color
                }
            }
        )
    }
    catch {
        Write-Log -Message "Fehler bei Update-GuiText: $($_.Exception.Message)" -Level "Error"
    }
}

function Show-MessageBox {
    param (
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][string]$Title = "Information",
        [Parameter(Mandatory=$false)][System.Windows.MessageBoxButton]$Button = [System.Windows.MessageBoxButton]::OK,
        [Parameter(Mandatory=$false)][System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
    )
    
    try {
        return [System.Windows.MessageBox]::Show($Message, $Title, $Button, $Icon)
    }
    catch {
        Write-Log -Message "Fehler beim Anzeigen der MessageBox: $($_.Exception.Message)" -Level "Error"
        return [System.Windows.MessageBoxResult]::None
    }
}
#endregion

#region [2.4 | Registry-Funktionen]
function Get-RegistryValue {
    param (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)]$DefaultValue = $null
    )
    
    try {
        if (Test-Path -Path $Path) {
            $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $value) {
                return $value.$Name
            }
        }
        return $DefaultValue
    }
    catch {
        Write-Log -Message "Fehler beim Lesen des Registry-Werts '$Name': $($_.Exception.Message)" -Level "Error"
        return $DefaultValue
    }
}

function Set-RegistryValue {
    param (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)]$Value,
        [Parameter(Mandatory=$false)][string]$Type = "String"
    )
    
    try {
        # Sicherstellen, dass der Registry-Pfad existiert
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        
        # Wert setzen
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        return $true
    }
    catch {
        Write-Log -Message "Fehler beim Setzen des Registry-Werts '$Name': $($_.Exception.Message)" -Level "Error"
        return $false
    }
}
#endregion

#region [2.6 | LAPS Helper Functions]
function Export-LapsPasswordToCsv {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [array]$ComputerList,
        [Parameter(Mandatory=$false)]
        [string]$Domain = $null
    )
    
    try {
        $exportData = New-Object System.Collections.Generic.List[object]
        $totalComputers = $ComputerList.Count
        $currentComputer = 0
        
        foreach ($computer in $ComputerList) {
            $currentComputer++
            Write-Log "Exportiere Computer $currentComputer von $totalComputers : $computer" -Level "Info"
            
            $lapsData = Get-LapsPasswordEx -ComputerName $computer -Domain $Domain
            
            if ($lapsData.Success) {
                $plainPassword = Convert-SecureStringToPlainText -SecureString $lapsData.Password
                
                $exportData.Add([PSCustomObject]@{
                    ComputerName = $lapsData.ComputerName
                    UserName = $lapsData.UserName
                    Password = $plainPassword
                    PasswordExpires = if ($lapsData.PasswordExpiresTimestamp) { $lapsData.PasswordExpiresTimestamp.ToString('yyyy-MM-dd HH:mm:ss') } else { "N/A" }
                    PasswordLastSet = if ($lapsData.PasswordLastSetTimestamp) { $lapsData.PasswordLastSetTimestamp.ToString('yyyy-MM-dd HH:mm:ss') } else { "N/A" }
                    LapsVersion = $lapsData.LapsVersion
                    ExportDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                })
            }
            else {
                Write-Log "Fehler beim Exportieren von $computer : $($lapsData.ErrorMessage)" -Level "Warning"
                $exportData.Add([PSCustomObject]@{
                    ComputerName = $computer
                    UserName = "ERROR"
                    Password = $lapsData.ErrorMessage
                    PasswordExpires = "N/A"
                    PasswordLastSet = "N/A"
                    LapsVersion = "N/A"
                    ExportDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                })
            }
        }
        
        # Export to CSV
        $exportData | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
        Write-Log "CSV-Export abgeschlossen: $FilePath ($($exportData.Count) Einträge)" -Level "Info"
        return @{ Success = $true; Count = $exportData.Count; FilePath = $FilePath }
    }
    catch {
        Write-Log "Fehler beim CSV-Export: $($_.Exception.Message)" -Level "Error"
        return @{ Success = $false; ErrorMessage = $_.Exception.Message }
    }
}

function Invoke-LapsPasswordRotation {
    param(
        [Parameter(Mandatory=$true)]
        [array]$ComputerList,
        [Parameter(Mandatory=$false)]
        [string]$Domain = $null
    )
    
    try {
        $results = New-Object System.Collections.Generic.List[object]
        $totalComputers = $ComputerList.Count
        $currentComputer = 0
        $successCount = 0
        $failCount = 0
        
        foreach ($computer in $ComputerList) {
            $currentComputer++
            Write-Log "Rotiere Passwort $currentComputer von $totalComputers : $computer" -Level "Info"
            
            $resetResult = Reset-LapsPasswordEx -ComputerName $computer -Domain $Domain
            
            if ($resetResult.Success) {
                $successCount++
                $results.Add([PSCustomObject]@{
                    ComputerName = $computer
                    Status = "Success"
                    Message = "Password rotation successful"
                    NewExpiration = if ($resetResult.NewExpirationTime) { $resetResult.NewExpirationTime.ToString('yyyy-MM-dd HH:mm:ss') } else { "N/A" }
                })
            }
            else {
                $failCount++
                Write-Log "Fehler beim Rotieren von $computer : $($resetResult.ErrorMessage)" -Level "Warning"
                $results.Add([PSCustomObject]@{
                    ComputerName = $computer
                    Status = "Failed"
                    Message = $resetResult.ErrorMessage
                    NewExpiration = "N/A"
                })
            }
        }
        
        Write-Log "Passwort-Rotation abgeschlossen: $successCount erfolgreich, $failCount fehlgeschlagen" -Level "Info"
        return @{ 
            Success = $true
            TotalCount = $totalComputers
            SuccessCount = $successCount
            FailCount = $failCount
            Results = $results
        }
    }
    catch {
        Write-Log "Fehler bei Passwort-Rotation: $($_.Exception.Message)" -Level "Error"
        return @{ Success = $false; ErrorMessage = $_.Exception.Message }
    }
}

# Ermittelt (gecacht pro Domain), welche LAPS-Attribute im AD-Schema vorhanden sind.
# Nicht vorhandene Attribute dürfen nicht bei Get-ADComputer -Properties angefragt werden.
function Get-LapsSchemaAttribute {
    param([string]$Domain = $null)

    if ($null -eq $script:LapsSchemaCache) { $script:LapsSchemaCache = @{} }
    $cacheKey = if ([string]::IsNullOrWhiteSpace($Domain)) { "." } else { $Domain.ToLowerInvariant() }
    if ($script:LapsSchemaCache.ContainsKey($cacheKey)) { return $script:LapsSchemaCache[$cacheKey] }

    $adParams = @{}
    if (-not [string]::IsNullOrWhiteSpace($Domain)) { $adParams.Server = $Domain }

    $wanted = @('msLAPS-Password', 'msLAPS-PasswordExpirationTime', 'msLAPS-EncryptedPassword', 'ms-Mcs-AdmPwd', 'ms-Mcs-AdmPwdExpirationTime')
    $ldapFilter = '(|' + (($wanted | ForEach-Object { "(lDAPDisplayName=$_)" }) -join '') + ')'
    $rootDse = Get-ADRootDSE @adParams -ErrorAction Stop
    $found = @(Get-ADObject -SearchBase $rootDse.schemaNamingContext -LDAPFilter $ldapFilter -Properties lDAPDisplayName @adParams -ErrorAction Stop |
               ForEach-Object { [string]$_.lDAPDisplayName })

    Write-Log "LAPS-Schemaattribute ($cacheKey): $(if ($found.Count) { $found -join ', ' } else { 'keine' })" -Level "Info"
    $script:LapsSchemaCache[$cacheKey] = $found
    return $found
}

# Wandelt einen AD-FILETIME-Wert (Integer8) in lokale Zeit um
function ConvertFrom-LapsFileTime {
    param($Value)
    try {
        if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
        $fileTime = [int64]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture)
        if ($fileTime -le 0) { return $null }
        return [DateTime]::FromFileTimeUtc($fileTime).ToLocalTime()
    }
    catch {
        return $null
    }
}

# Fallback ohne LAPS-Module: liest die LAPS-Attribute direkt über das ActiveDirectory-Modul.
# Unterstützt Windows LAPS (Klartext, msLAPS-Password) und Legacy LAPS (ms-Mcs-AdmPwd).
# Verschlüsselte Windows-LAPS-Passwörter können nur mit Get-LapsADPassword entschlüsselt werden.
function Get-LapsPasswordFromAdAttribute {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [Parameter(Mandatory=$false)][string]$Domain = $null
    )

    $result = @{
        Success = $false; Password = $null; UserName = $null
        PasswordExpiresTimestamp = $null; PasswordLastSetTimestamp = $null
        LapsVersion = "Unknown"; ErrorMessage = ""; ComputerName = $ComputerName
        IsEncrypted = $false; Source = "AD-Attribut"; DecryptionStatus = $null
    }

    try {
        $adParams = @{}
        if (-not [string]::IsNullOrWhiteSpace($Domain)) { $adParams.Server = $Domain }

        $attributes = @(Get-LapsSchemaAttribute -Domain $Domain)
        if ($attributes.Count -eq 0) {
            $result.ErrorMessage = "Das AD-Schema enthaelt keine LAPS-Attribute (weder Windows LAPS noch Legacy LAPS)."
            return $result
        }

        # Get-ADComputer erwartet Name/sAMAccountName - FQDN auf den Hostnamen kürzen
        $identity = ($ComputerName.Trim() -split '\.')[0]
        $computer = Get-ADComputer -Identity $identity -Properties $attributes @adParams -ErrorAction Stop
        $result.ComputerName = [string]$computer.Name

        $windowsJson = if ($attributes -contains 'msLAPS-Password') { [string]$computer.'msLAPS-Password' } else { "" }
        $windowsExpiry = if ($attributes -contains 'msLAPS-PasswordExpirationTime') { $computer.'msLAPS-PasswordExpirationTime' } else { $null }
        $encrypted = if ($attributes -contains 'msLAPS-EncryptedPassword') { $computer.'msLAPS-EncryptedPassword' } else { $null }
        $legacyPassword = if ($attributes -contains 'ms-Mcs-AdmPwd') { [string]$computer.'ms-Mcs-AdmPwd' } else { "" }
        $legacyExpiry = if ($attributes -contains 'ms-Mcs-AdmPwdExpirationTime') { $computer.'ms-Mcs-AdmPwdExpirationTime' } else { $null }

        if (-not [string]::IsNullOrWhiteSpace($windowsJson)) {
            # Format laut Microsoft: {"n":"<Konto>","t":"<UTC-FILETIME hex>","p":"<Passwort>"}
            $data = $windowsJson | ConvertFrom-Json
            if ([string]::IsNullOrEmpty([string]$data.p)) { throw "msLAPS-Password enthaelt kein Passwort." }
            $result.Password = ConvertTo-LapsSecureString ([string]$data.p)
            $result.UserName = if ($data.n) { [string]$data.n } else { "Administrator" }
            if ($data.t) {
                try { $result.PasswordLastSetTimestamp = [DateTime]::FromFileTimeUtc([Convert]::ToInt64([string]$data.t, 16)).ToLocalTime() } catch { $result.PasswordLastSetTimestamp = $null }
            }
            $result.PasswordExpiresTimestamp = ConvertFrom-LapsFileTime $windowsExpiry
            $result.LapsVersion = "Windows LAPS (AD-Attribut, unverschluesselt)"
            $result.Success = $true
        }
        elseif ($null -ne $encrypted -and @($encrypted).Count -gt 0) {
            $result.IsEncrypted = $true
            $result.PasswordExpiresTimestamp = ConvertFrom-LapsFileTime $windowsExpiry
            $result.LapsVersion = "Windows LAPS (verschluesselt)"
            $result.ErrorMessage = "Das Passwort ist verschluesselt gespeichert (msLAPS-EncryptedPassword). Entschluesselung nur mit dem Windows-LAPS-Modul (Get-LapsADPassword) und Berechtigung ueber 'ADPasswordEncryptionPrincipal'."
        }
        elseif (-not [string]::IsNullOrWhiteSpace($legacyPassword)) {
            $result.Password = ConvertTo-LapsSecureString $legacyPassword
            $result.UserName = "N/A (Legacy LAPS)"
            $result.PasswordExpiresTimestamp = ConvertFrom-LapsFileTime $legacyExpiry
            $result.LapsVersion = "Legacy LAPS (AD-Attribut)"
            $result.Success = $true
        }
        elseif ($null -ne $windowsExpiry -or $null -ne $legacyExpiry) {
            # Ablaufzeit lesbar, Passwort nicht -> vertrauliches Attribut ohne Leserecht
            $result.PasswordExpiresTimestamp = ConvertFrom-LapsFileTime $(if ($null -ne $windowsExpiry) { $windowsExpiry } else { $legacyExpiry })
            $result.ErrorMessage = "LAPS ist fuer $($result.ComputerName) aktiv, das Passwort ist fuer Ihr Konto aber nicht lesbar (fehlende Leseberechtigung, siehe Set-LapsADReadPasswordPermission)."
        }
        else {
            $result.ErrorMessage = "Fuer $($result.ComputerName) ist kein LAPS-Passwort im AD gespeichert (LAPS-Richtlinie nicht aktiv oder Geraet hat noch kein Passwort gemeldet)."
        }
    }
    catch {
        $result.ErrorMessage = "AD-Abfrage fehlgeschlagen: $($_.Exception.Message)"
    }

    return $result
}

function Get-LapsPasswordEx {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [Parameter(Mandatory=$false)][string]$Domain = $null
    )
    
    $result = @{
        Success = $false
        Password = $null
        UserName = $null
        PasswordExpiresTimestamp = $null
        PasswordLastSetTimestamp = $null
        LapsVersion = "Unknown"
        ErrorMessage = ""
        ComputerName = $ComputerName
        IsEncrypted = $false
        Source = $null
        DecryptionStatus = $null
    }
    $notes = New-Object System.Collections.Generic.List[string]

    # 1) Windows LAPS (liest auch Legacy-LAPS-Attribute und entschlüsselt, sofern berechtigt)
    if (Get-Command -Name Get-LapsADPassword -ErrorAction SilentlyContinue) {
        try {
            $lapsParams = @{ Identity = $ComputerName; AsPlainText = $true; ErrorAction = 'Stop'; WarningAction = 'SilentlyContinue' }
            if (-not [string]::IsNullOrWhiteSpace($Domain)) { $lapsParams.Domain = $Domain }
            # Ohne IncludeHistory, da hier nur der aktuelle Wert benötigt wird.
            $pwdInfo = Get-LapsADPassword @lapsParams | Select-Object -First 1

            if ($null -eq $pwdInfo) {
                $notes.Add("Windows LAPS: keine Passwortdaten.")
            }
            else {
                $source = if ($pwdInfo.PSObject.Properties['Source']) { [string]$pwdInfo.Source } else { "" }
                $decryptionStatus = if ($pwdInfo.PSObject.Properties['DecryptionStatus']) { [string]$pwdInfo.DecryptionStatus } else { "" }
                $result.Source = $source
                $result.DecryptionStatus = $decryptionStatus
                $hasPassword = $null -ne $pwdInfo.Password -and -not [string]::IsNullOrWhiteSpace([string]$pwdInfo.Password)

                if ($hasPassword) {
                    $result.Success = $true
                    $result.Password = if ($pwdInfo.Password -is [System.Security.SecureString]) { $pwdInfo.Password } else { ConvertTo-LapsSecureString ([string]$pwdInfo.Password) }
                    $result.ComputerName = if ($null -ne $pwdInfo.ComputerName) { $pwdInfo.ComputerName } else { $ComputerName }
                    $result.UserName = if (-not [string]::IsNullOrWhiteSpace([string]$pwdInfo.Account)) { $pwdInfo.Account } else { "Administrator" }
                    $result.PasswordExpiresTimestamp = if ($pwdInfo.PSObject.Properties['ExpirationTimestamp']) { $pwdInfo.ExpirationTimestamp } else { $null }
                    $result.PasswordLastSetTimestamp = if ($pwdInfo.PSObject.Properties['PasswordUpdateTime'] -and $pwdInfo.PasswordUpdateTime) { $pwdInfo.PasswordUpdateTime } else { $null }

                    if ($source -like "Legacy*") {
                        $result.LapsVersion = "Legacy LAPS (ueber Windows LAPS gelesen)"
                        if ([string]::IsNullOrWhiteSpace([string]$pwdInfo.Account)) { $result.UserName = "N/A (Legacy LAPS)" }
                    }
                    elseif ($source -like "Encrypted*") { $result.LapsVersion = "Windows LAPS (verschluesselt)" }
                    elseif ($source -like "Cleartext*") { $result.LapsVersion = "Windows LAPS (unverschluesselt)" }
                    else { $result.LapsVersion = "Windows LAPS" }

                    Write-Log "LAPS Passwort für $ComputerName erfolgreich abgerufen ($($result.LapsVersion))." -Level "Info"
                    return $result
                }

                if (-not [string]::IsNullOrWhiteSpace($decryptionStatus) -and $decryptionStatus -notin @("Success", "NotApplicable")) {
                    # Verschlüsseltes Passwort vorhanden, aber keine Entschlüsselungsberechtigung -> eindeutiges Ergebnis
                    $result.IsEncrypted = $true
                    $result.ErrorMessage = "Passwort kann nicht entschluesselt werden (DecryptionStatus: $decryptionStatus). Berechtigung ueber 'ADPasswordEncryptionPrincipal' erforderlich."
                    Write-Log "LAPS Passwort für $ComputerName kann nicht entschlüsselt werden (DecryptionStatus: $decryptionStatus)." -Level "Warning"
                    return $result
                }

                $notes.Add("Windows LAPS: kein Passwort gespeichert$(if ($source) { " (Source: $source)" }).")
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            if ($errorMsg -match "Deserialisieren|EncryptedPasswordAttributeRaw|Unerwartetes Zeichen|decrypt") {
                $result.IsEncrypted = $true
                $result.ErrorMessage = "Passwort ist verschluesselt. Sie haben keine Berechtigung zur Entschluesselung oder der Entschluesselungsschluessel fehlt."
                Write-Log "LAPS Passwort für $ComputerName ist verschlüsselt - fehlende Entschlüsselungsberechtigung." -Level "Warning"
                return $result
            }
            elseif ($errorMsg -match "computer in AD|find an object with identity|Objekt mit der Identit") {
                $result.ErrorMessage = "Computer '$ComputerName' wurde im Active Directory nicht gefunden."
                Write-Log "Computer $ComputerName nicht im AD gefunden." -Level "Warning"
                return $result
            }
            elseif ($errorMsg -match "Access is denied|Zugriff verweigert") {
                $notes.Add("Windows LAPS: Zugriff verweigert.")
            }
            else {
                $notes.Add("Windows LAPS: $errorMsg")
            }
        }
    }
    else {
        $notes.Add("Windows-LAPS-Modul nicht verfuegbar.")
    }

    # 2) Legacy LAPS Cmdlet (AdmPwd.PS, ohne Domain-Parameter)
    if ([string]::IsNullOrWhiteSpace($Domain) -and (Get-Command -Name Get-AdmPwdPassword -ErrorAction SilentlyContinue)) {
        try {
            $legacyPwd = Get-AdmPwdPassword -ComputerName $ComputerName -ErrorAction Stop | Select-Object -First 1
            if ($null -ne $legacyPwd -and -not [string]::IsNullOrWhiteSpace([string]$legacyPwd.Password)) {
                $result.Success = $true
                $result.Password = ConvertTo-LapsSecureString ([string]$legacyPwd.Password)
                $result.UserName = "N/A (Legacy LAPS)"
                $result.PasswordExpiresTimestamp = $legacyPwd.ExpirationTimestamp
                $result.PasswordLastSetTimestamp = $null
                $result.LapsVersion = "Legacy LAPS (AdmPwd)"
                Write-Log "Legacy LAPS Passwort für $ComputerName erfolgreich abgerufen." -Level "Info"
                return $result
            }
            $notes.Add("Legacy LAPS: kein Passwort lesbar.")
        }
        catch {
            $notes.Add("Legacy LAPS: $($_.Exception.Message)")
        }
    }

    # 3) Direktes Lesen der AD-Attribute (funktioniert auch ohne LAPS-Module, nur mit RSAT)
    if (Get-Command -Name Get-ADComputer -ErrorAction SilentlyContinue) {
        $adResult = Get-LapsPasswordFromAdAttribute -ComputerName $ComputerName -Domain $Domain
        if ($adResult.Success) {
            Write-Log "LAPS Passwort für $ComputerName über AD-Attribute abgerufen ($($adResult.LapsVersion))." -Level "Info"
            return $adResult
        }
        if ($adResult.IsEncrypted) {
            Write-Log "LAPS Passwort für $ComputerName ist verschlüsselt und kann ohne Windows-LAPS-Modul nicht entschlüsselt werden." -Level "Warning"
            return $adResult
        }
        # Die AD-Auswertung liefert die aussagekräftigste Ursache -> zuerst anzeigen
        $notes.Insert(0, $adResult.ErrorMessage)
    }
    else {
        $notes.Add("ActiveDirectory-Modul nicht verfuegbar.")
    }

    $result.ErrorMessage = (@($notes | Where-Object { $_ } | Select-Object -Unique)) -join " | "
    Write-Log "LAPS Passwort für $ComputerName nicht verfügbar: $($result.ErrorMessage)" -Level "Warning"
    return $result
}

function Reset-LapsPasswordEx {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [Parameter(Mandatory=$false)][string]$Domain = $null,
        [Parameter(Mandatory=$false)][switch]$Force
    )
    
    $result = @{
        Success = $false
        LapsVersion = "Unknown"
        ErrorMessage = ""
        NewExpirationTime = $null
    }
    
    try {
        $hasWindowsSetExpiryCmd = [bool](Get-Command -Name Set-LapsADPasswordExpirationTime -ErrorAction SilentlyContinue)
        $hasLegacyResetCmd = [bool](Get-Command -Name Reset-AdmPwdPassword -ErrorAction SilentlyContinue)
        $effectiveTime = Get-Date

        # 1) Bevorzugter Weg laut MS Learn für AD-Objekte: ExpirationTimestamp setzen
        if ($hasWindowsSetExpiryCmd) {
            try {
                if ([string]::IsNullOrWhiteSpace($Domain)) {
                    $setResult = Set-LapsADPasswordExpirationTime -Identity $ComputerName -WhenEffective $effectiveTime -ErrorAction Stop -WarningAction SilentlyContinue
                } else {
                    $setResult = Set-LapsADPasswordExpirationTime -Identity $ComputerName -Domain $Domain -WhenEffective $effectiveTime -ErrorAction Stop -WarningAction SilentlyContinue
                }

                if ($setResult) {
                    $firstResult = $setResult | Select-Object -First 1
                    if ($firstResult.PSObject.Properties['Status'] -and $firstResult.Status -ne 'PasswordReset') {
                        throw "Set-LapsADPasswordExpirationTime meldet unerwarteten Status: $($firstResult.Status)"
                    }
                }

                $result.Success = $true
                $result.NewExpirationTime = $effectiveTime
                $result.LapsVersion = "Windows LAPS"
                return $result
            }
            catch {
                $windowsResetError = $_.Exception.Message

                # Für Domain-Reset keine Legacy-Fallbacks versuchen, da AdmPwd kein -Domain unterstützt.
                if (-not [string]::IsNullOrWhiteSpace($Domain)) {
                    throw "Windows LAPS AD-Reset fehlgeschlagen: $windowsResetError"
                }

                # 2) Fallback auf Legacy LAPS (lokale Domain-Kontextausführung)
                if ($hasLegacyResetCmd) {
                    try {
                        Reset-AdmPwdPassword -ComputerName $ComputerName -ErrorAction Stop -WarningAction SilentlyContinue
                        $result.Success = $true
                        $result.LapsVersion = "Legacy LAPS (AdmPwd)"
                        return $result
                    }
                    catch {
                        throw "Windows LAPS AD-Reset fehlgeschlagen: $windowsResetError | Legacy-Fallback fehlgeschlagen: $($_.Exception.Message)"
                    }
                }

                throw "Windows LAPS AD-Reset fehlgeschlagen: $windowsResetError"
            }
        }

        # 3) Wenn Set-LapsADPasswordExpirationTime nicht verfügbar ist: Legacy direkt probieren
        if ($hasLegacyResetCmd -and [string]::IsNullOrWhiteSpace($Domain)) {
            Reset-AdmPwdPassword -ComputerName $ComputerName -ErrorAction Stop -WarningAction SilentlyContinue
            $result.Success = $true
            $result.LapsVersion = "Legacy LAPS (AdmPwd)"
            return $result
        }

        # 4) Ohne LAPS-Module: Ablaufzeit direkt am Computerobjekt setzen (benötigt Schreibrecht auf das
        #    Ablaufzeit-Attribut, entspricht der Reset-Berechtigung von Windows LAPS bzw. Legacy LAPS)
        if (Get-Command -Name Set-ADComputer -ErrorAction SilentlyContinue) {
            $adParams = @{}
            if (-not [string]::IsNullOrWhiteSpace($Domain)) { $adParams.Server = $Domain }
            $attributes = @(Get-LapsSchemaAttribute -Domain $Domain | Where-Object { $_ -in @('msLAPS-PasswordExpirationTime', 'ms-Mcs-AdmPwdExpirationTime') })
            if ($attributes.Count -eq 0) {
                throw "Das AD-Schema enthaelt keine LAPS-Attribute."
            }

            $identity = ($ComputerName.Trim() -split '\.')[0]
            $computer = Get-ADComputer -Identity $identity -Properties $attributes @adParams -ErrorAction Stop
            $replace = @{}
            foreach ($attribute in $attributes) {
                if ($null -ne $computer.$attribute -and -not [string]::IsNullOrWhiteSpace([string]$computer.$attribute)) {
                    $replace[$attribute] = [int64]$effectiveTime.ToFileTimeUtc()
                }
            }
            if ($replace.Count -eq 0) {
                throw "Fuer $($computer.Name) ist keine LAPS-Ablaufzeit im AD gespeichert (LAPS nicht aktiv oder keine Leseberechtigung)."
            }

            Set-ADComputer -Identity $computer.DistinguishedName -Replace $replace @adParams -ErrorAction Stop
            $result.Success = $true
            $result.NewExpirationTime = $effectiveTime
            $result.LapsVersion = if ($replace.ContainsKey('msLAPS-PasswordExpirationTime')) { "Windows LAPS (AD-Attribut)" } else { "Legacy LAPS (AD-Attribut)" }
            Write-Log "LAPS-Ablaufzeit für $($computer.Name) direkt im AD gesetzt ($($replace.Keys -join ', '))." -Level "Info"
            return $result
        }

        throw "Weder Set-LapsADPasswordExpirationTime, Reset-AdmPwdPassword noch das ActiveDirectory-Modul sind verfuegbar."
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-Log "Fehler beim Zurücksetzen des LAPS Passworts für $ComputerName : $($_.Exception.Message)" -Level "Error"
    }
    
    return $result
}

# Baut aus dem abgerufenen Klartext-Passwort einen SecureString (nur für die interne Weitergabe)
function ConvertTo-LapsSecureString {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$PlainText)
    $secure = New-Object System.Security.SecureString
    foreach ($char in $PlainText.ToCharArray()) { $secure.AppendChar($char) }
    $secure.MakeReadOnly()
    return $secure
}

function Convert-SecureStringToPlainText {
    param(
        [Parameter(Mandatory=$true)][System.Security.SecureString]$SecureString
    )
    
    try {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        return $plainText
    }
    catch {
        Write-Log "Fehler beim Konvertieren des SecureString: $($_.Exception.Message)" -Level "Error"
        return ""
    }
}
#endregion

#region [2.5 | Main GUI Function - Haupt-GUI-Funktion]
function Show-LAPSForm {
    param(
        $ModuleStatus
    )

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms # Für MessageBox
    Add-Type -AssemblyName System.Drawing # Für Farben in MessageBox (optional)

    # DPI-Awareness aktivieren für bessere Darstellung auf High-DPI Bildschirmen
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class ProcessDPI {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetProcessDPIAware();
    
    [DllImport("user32.dll", SetLastError=true)]
    public static extern uint GetDpiForWindow(IntPtr hWnd); 
}
'@ -ErrorAction SilentlyContinue
    $null = [ProcessDPI]::SetProcessDPIAware()

    # (1) Werte aus globalen Hashtables (statt INI)
    $appName        = $script:BrandingGUI.APPName
    if (-not $appName) { $appName = "easyLAPS" }
    $fontFamily     = $script:BrandingGUI.FontFamily
    if (-not $fontFamily) { $fontFamily = "Segoe UI" }

    $scriptVersion = $script:ScriptInfo.ScriptVersion
    $lastUpdate    = $script:ScriptInfo.LastUpdate
    $author = $script:ScriptInfo.Author
    $footerText = "$appName v$scriptVersion ($lastUpdate) by $author"
    if ($script:BrandingGUI.FooterWebseite) { 
        $webseiteInfo = $script:BrandingGUI.FooterWebseite
        $footerText += " | $webseiteInfo" 
    }

    # Werte für die XAML-Einbettung XML-sicher maskieren
    $appName    = [System.Security.SecurityElement]::Escape($appName)
    $fontFamily = [System.Security.SecurityElement]::Escape($fontFamily)
    $footerText = [System.Security.SecurityElement]::Escape($footerText)

    # (2) XAML Definition für die GUI
    $XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="$appName" Height="860" Width="1200" MinHeight="700" MinWidth="1000"
        WindowStartupLocation="CenterScreen" Background="#FFFFFF" FontFamily="$fontFamily" FontSize="12">
    <Window.Resources>
        <!-- Modern Button Style -->
        <Style x:Key="ModernButton" TargetType="Button">
            <Setter Property="Background" Value="#0078D4" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="BorderThickness" Value="0" />
            <Setter Property="Padding" Value="10,5" />
            <Setter Property="Margin" Value="5" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="MinWidth" Value="80" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border
                            x:Name="border"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="4">
                            <ContentPresenter
                                Margin="{TemplateBinding Padding}"
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#106EBE" />
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#005A9E" />
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.5" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Card Style -->
        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background" Value="White" />
            <Setter Property="BorderBrush" Value="#E0E0E0" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="CornerRadius" Value="8" />
            <Setter Property="Padding" Value="15" />
            <Setter Property="Margin" Value="5" />
        </Style>

        <!-- TextBox Style -->
        <Style x:Key="ModernTextBox" TargetType="TextBox">
            <Setter Property="BorderBrush" Value="#BFBFBF" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Padding" Value="8,5" />
            <Setter Property="Margin" Value="4" />
            <Setter Property="Background" Value="White" />
            <Setter Property="FontSize" Value="12" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="4">
                            <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter Property="BorderBrush" Value="#0078D4" />
                                <Setter Property="BorderThickness" Value="2" />
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.5" />
                                <Setter Property="Background" Value="#F0F0F0" />
                            </Trigger>
                            <Trigger Property="IsReadOnly" Value="True">
                                <Setter Property="Background" Value="#F5F5F5" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <!-- Header -->
            <RowDefinition Height="*"/>
            <!-- Content -->
            <RowDefinition Height="Auto"/>
            <!-- Footer -->
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#FF1C323C" Padding="10" CornerRadius="5,5,0,0" BorderBrush="#E0E0E0" BorderThickness="0,0,0,1">
            <DockPanel>
                <TextBlock Text="$appName" FontSize="20" FontWeight="SemiBold" VerticalAlignment="Center" DockPanel.Dock="Left" Foreground="#e2e2e2"/>
                <TextBlock Name="lblVersion" Text="v$scriptVersion" FontSize="12" Margin="10,0,0,0" VerticalAlignment="Center" DockPanel.Dock="Left" Foreground="#d0e8ff"/>
                <TextBlock Name="lblModuleStatus" Text="" FontSize="12" Margin="10,0,0,0" VerticalAlignment="Center" DockPanel.Dock="Left" Foreground="#d0e8ff"/>
            </DockPanel>
        </Border>

        <!-- Content -->
        <Grid Grid.Row="1" Margin="0,10,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="2*"/>
                <ColumnDefinition Width="3*"/>
            </Grid.ColumnDefinitions>

            <!-- AD Computer and Actions -->
            <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,5,0">
                <DockPanel LastChildFill="True">
                    <StackPanel DockPanel.Dock="Top" Orientation="Vertical" Margin="0,0,0,10">
                        <DockPanel Margin="0,0,0,5">
                            <TextBlock Text="Computer name:" Width="95" VerticalAlignment="Center" DockPanel.Dock="Left" Foreground="#1C1C1C"/>
                            <Button Name="btnRefreshAdList" Content="Load AD List" Margin="10,0,0,0" Padding="10,5" Height="30" DockPanel.Dock="Right" ToolTip="Loads all computer objects from AD (F5)" Style="{StaticResource ModernButton}"/>
                            <TextBox Name="txtComputerName" Height="30" VerticalContentAlignment="Center" ToolTip="Computer name (Enter = show password)"/>
                        </DockPanel>
                        <DockPanel Margin="0,0,0,5">
                            <TextBlock Text="Filter (Name):" Width="95" VerticalAlignment="Center" DockPanel.Dock="Left" Foreground="#1C1C1C"/>
                            <TextBox Name="txtFilter" Height="30" VerticalContentAlignment="Center" ToolTip="Filtert die AD-Liste (Ctrl+F)"/>
                        </DockPanel>
                    </StackPanel>

                    <StackPanel DockPanel.Dock="Bottom" Orientation="Vertical" Margin="0,10,0,0">
                        <WrapPanel Orientation="Horizontal" Margin="0,0,0,5">
                            <Button Name="btnGetLapsPassword" Content="Show Password" Width="130" Height="30" Margin="0,0,10,5" ToolTip="Shows the LAPS password (Ctrl+G, Enter, double-click)" Style="{StaticResource ModernButton}"/>
                            <Button Name="btnResetLapsPassword" Content="Reset Password" Width="130" Height="30" Margin="0,0,10,5" ToolTip="Resets the LAPS password (Ctrl+R)" Style="{StaticResource ModernButton}"/>
                            <Button Name="btnCopyPassword" Content="Copy to Clipboard" Width="130" Height="30" Margin="0,0,0,5" ToolTip="Copies the password to clipboard, cleared automatically (Ctrl+C)" Style="{StaticResource ModernButton}"/>
                        </WrapPanel>
                        <WrapPanel Orientation="Horizontal">
                            <Button Name="btnExportSelected" Content="Export Selected" Width="130" Height="30" Margin="0,0,10,5" ToolTip="Export selected computer to CSV" Style="{StaticResource ModernButton}"/>
                            <Button Name="btnExportAll" Content="Export All" Width="130" Height="30" Margin="0,0,10,5" ToolTip="Export all listed computers to CSV" Style="{StaticResource ModernButton}"/>
                            <Button Name="btnRotateAll" Content="Rotate All" Width="130" Height="30" Margin="0,0,0,5" ToolTip="Rotate passwords for all listed computers" Style="{StaticResource ModernButton}"/>
                        </WrapPanel>
                    </StackPanel>

                    <Grid DockPanel.Dock="Bottom">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <TextBlock Grid.Row="0" Grid.Column="0" Text="Username:" Margin="0,0,5,5" VerticalAlignment="Center" Foreground="#505050"/>
                        <TextBox Name="txtLapsUser" Grid.Row="0" Grid.Column="1" IsReadOnly="True" Height="30" VerticalContentAlignment="Center" Margin="0,0,0,5"/>
                        <TextBlock Grid.Row="1" Grid.Column="0" Text="Password:" Margin="0,0,5,5" VerticalAlignment="Center" Foreground="#505050"/>
                        <TextBox Name="txtLapsPasswordDisplay" Grid.Row="1" Grid.Column="1" IsReadOnly="True" Height="30" VerticalContentAlignment="Center" Margin="0,0,0,5" FontFamily="Consolas"/>
                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Expiration date:" Margin="0,0,5,5" VerticalAlignment="Center" Foreground="#505050"/>
                        <TextBox Name="txtPasswordExpiry" Grid.Row="2" Grid.Column="1" IsReadOnly="True" Height="30" VerticalContentAlignment="Center" Margin="0,0,0,5"/>
                        <TextBlock Grid.Row="3" Grid.Column="0" Text="Last change:" Margin="0,0,5,5" VerticalAlignment="Center" Foreground="#505050"/>
                        <TextBox Name="txtPasswordLastSet" Grid.Row="3" Grid.Column="1" IsReadOnly="True" Height="30" VerticalContentAlignment="Center" Margin="0,0,0,5"/>
                        <TextBlock Grid.Row="4" Grid.Column="0" Text="LAPS Version:" Margin="0,0,5,5" VerticalAlignment="Center" Foreground="#505050"/>
                        <TextBox Name="txtLapsVersion" Grid.Row="4" Grid.Column="1" IsReadOnly="True" Height="30" VerticalContentAlignment="Center" Margin="0,0,0,5"/>
                    </Grid>

                    <TextBlock Text="LAPS Password Details:" FontWeight="SemiBold" Margin="0,10,0,5" DockPanel.Dock="Bottom" Foreground="#1C1C1C"/>

                    <ListBox Name="lstAdComputers" SelectionMode="Single" BorderBrush="#BFBFBF" BorderThickness="1" ToolTip="Auswahl übernimmt den Namen, Doppelklick zeigt das Passwort"/>
                </DockPanel>
            </Border>

            <!-- LAPS Details and Status -->
            <Border Grid.Column="1" Style="{StaticResource Card}" Margin="5,0,0,0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="160"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row="0" Text="LAPS Client Status and Policies (local system)" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10" Foreground="#1C1C1C"/>

                    <WrapPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,10">
                        <Button Name="btnCheckLapsStatus" Content="Check Status" Width="130" Height="30" Margin="0,0,10,5" ToolTip="Checks the local LAPS status (Ctrl+P)" Style="{StaticResource ModernButton}"/>
                        <Button Name="btnRunPolicyProcessing" Content="Run Policy (local)" Width="150" Height="30" Margin="0,0,10,5" ToolTip="Startet Invoke-LapsPolicyProcessing auf dem lokalen System (Ctrl+I)" Style="{StaticResource ModernButton}"/>
                        <Button Name="btnRunDiagnostics" Content="Diagnose" Width="130" Height="30" Margin="0,0,0,5" ToolTip="Sammelt LAPS-Diagnosedaten und öffnet die ZIP-Datei" Style="{StaticResource ModernButton}"/>
                    </WrapPanel>

                    <WrapPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,10">
                        <TextBlock Text="LAPS installed:" VerticalAlignment="Center" Margin="0,0,8,0" Foreground="#505050"/>
                        <Ellipse Name="ellipseLapsInstalled" Width="16" Height="16" Fill="Gray" Stroke="Black" StrokeThickness="0.5" VerticalAlignment="Center" Margin="0,0,8,0"/>
                        <TextBlock Name="lblLapsInstalledStatus" Text="Not checked" VerticalAlignment="Center" Margin="0,0,30,0" Foreground="#1C1C1C"/>
                        <TextBlock Text="LAPS policy active:" VerticalAlignment="Center" Margin="0,0,8,0" Foreground="#505050"/>
                        <Ellipse Name="ellipseGpoStatus" Width="16" Height="16" Fill="Gray" Stroke="Black" StrokeThickness="0.5" VerticalAlignment="Center" Margin="0,0,8,0"/>
                        <TextBlock Name="lblGpoStatus" Text="Not checked" VerticalAlignment="Center" Foreground="#1C1C1C"/>
                    </WrapPanel>

                    <TextBlock Grid.Row="3" Text="Policy details:" Margin="0,0,0,5" Foreground="#505050"/>
                    <TextBox Name="txtPolicyDetails" Grid.Row="4" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" IsReadOnly="True" Margin="0,0,0,10" FontFamily="Consolas" FontSize="11" Style="{StaticResource ModernTextBox}"/>

                    <TextBlock Grid.Row="5" Text="Status:" Margin="0,0,0,5" Foreground="#505050"/>
                    <TextBox Name="txtStatus" Grid.Row="6" Text="Ready." FontStyle="Italic" FontSize="10" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" Style="{StaticResource ModernTextBox}" Background="#F8F8F8"/>
                </Grid>
            </Border>
        </Grid>

        <!-- Footer -->
        <Border Grid.Row="2" Background="#FF1C323C" Padding="10" CornerRadius="0,0,5,5" Margin="0,10,0,0" BorderBrush="#E0E0E0" BorderThickness="0,1,0,0">
            <TextBlock Name="lblFooter" Text="$footerText" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#e2e2e2"/>
        </Border>
    </Grid>
</Window>
"@

    # (3) XAML laden und GUI-Elemente referenzieren
    try {
        # XAML-Text in XML-Objekt konvertieren
        [xml]$xamlObject = $XAML
        # Namespace-Manager für XPath-Abfragen erstellen
        $namespace = New-Object System.Xml.XmlNamespaceManager($xamlObject.NameTable)
        $namespace.AddNamespace("x", "http://schemas.microsoft.com/winfx/2006/xaml")
        
        # XAML in Objekt umwandeln
        $reader = New-Object System.Xml.XmlNodeReader($xamlObject)
        $window = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch {
        $errorMsg = "Fehler beim Laden der Benutzeroberfläche: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            $errorMsg += "`nInner Exception: $($_.Exception.InnerException.Message)"
        }
        [System.Windows.MessageBox]::Show($errorMsg, "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return $null
    }

    # GUI-Elemente (Variablen für einfacheren Zugriff)
    $controls = @{}
    @("txtComputerName", "btnRefreshAdList", "lstAdComputers", "txtFilter", "txtLapsUser", "txtLapsPasswordDisplay", "txtPasswordExpiry",
            "txtPasswordLastSet", "txtLapsVersion", "btnGetLapsPassword", "btnResetLapsPassword", "btnCopyPassword", "btnCheckLapsStatus", "btnRunPolicyProcessing", "btnRunDiagnostics",
      "btnExportSelected", "btnExportAll", "btnRotateAll",
      "ellipseLapsInstalled", "lblLapsInstalledStatus", "ellipseGpoStatus", "lblGpoStatus", "txtPolicyDetails", 
      "txtStatus", "lblFooter", "lblVersion", "lblModuleStatus") | ForEach-Object {
        $controls[$_] = $window.FindName($_)
    }

    # (4) Event Handler und Logik

    # Tastenkombinationen definieren
    $window.Add_KeyDown({
        param($source, $e)
        
        # Strg+P für Status & Richtlinien prüfen
        if ($e.Key -eq 'P' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
            $controls.btnCheckLapsStatus.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            $e.Handled = $true
        }        
        # Strg+I für lokale Policy-Verarbeitung
        if ($e.Key -eq 'I' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
            $controls.btnRunPolicyProcessing.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            $e.Handled = $true
        }
        # Strg+F für Fokus auf Filter
        if ($e.Key -eq 'F' -and $e.KeyboardDevice.Modifiers -eq 'Control' -and $controls.txtFilter) {
            $controls.txtFilter.Focus()
            $controls.txtFilter.SelectAll()
            $e.Handled = $true
        }
        
        # F5 für AD-Liste aktualisieren
        if ($e.Key -eq 'F5') {
            $controls.btnRefreshAdList.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            $e.Handled = $true
        }
        
        # Enter im Computer-Textfeld löst Passwortanzeige aus
        if ($e.Key -eq 'Return' -and $e.Source -eq $controls.txtComputerName) {
            $controls.btnGetLapsPassword.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            $e.Handled = $true
        }
        
        # Strg+G für Passwort anzeigen
        if ($e.Key -eq 'G' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
            $controls.btnGetLapsPassword.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            $e.Handled = $true
        }
        
        # Strg+R für Passwort zurücksetzen
        if ($e.Key -eq 'R' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
            $controls.btnResetLapsPassword.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            $e.Handled = $true
        }
        
        # Strg+C für Passwort kopieren (nur wenn in einem Textfeld kein Text markiert ist)
        if ($e.Key -eq 'C' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
            $focusedElement = [System.Windows.Input.Keyboard]::FocusedElement
            $hasTextSelection = ($focusedElement -is [System.Windows.Controls.TextBox]) -and ($focusedElement.SelectionLength -gt 0)
            if (-not $hasTextSelection) {
                $controls.btnCopyPassword.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                $e.Handled = $true
            }
        }
    })
    

    #region [4.0 | Statusanzeige und Hilfsfunktionen]

# Globale Funktion für Status-Updates (Session-Historie)
$global:UpdateStatus = {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [switch]$IsLapsCheck
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    $hostname = $env:COMPUTERNAME
    $prefix = "[$timestamp]"
    if ($IsLapsCheck) {
        $prefix += " [LAPS-Check $hostname]"
    }
    $entry = "$prefix [$Level] $Message"
    if ($controls -and $controls.txtStatus) {
        if ([string]::IsNullOrWhiteSpace($controls.txtStatus.Text)) {
            $controls.txtStatus.Text = $entry
        } else {
            $controls.txtStatus.Text += "`r`n$entry"
        }
        $controls.txtStatus.ScrollToEnd()
        # Farblogik
        switch ($Level.ToLower()) {
            "pruefung" { $controls.txtStatus.Foreground = [System.Windows.Media.Brushes]::DarkBlue }
            "check"    { $controls.txtStatus.Foreground = [System.Windows.Media.Brushes]::DarkBlue }
            "ok"       { $controls.txtStatus.Foreground = [System.Windows.Media.Brushes]::DarkGreen }
            "success"  { $controls.txtStatus.Foreground = [System.Windows.Media.Brushes]::DarkGreen }
            "debug"    { $controls.txtStatus.Foreground = [System.Windows.Media.Brushes]::LightBlue }
            "fehler"   { $controls.txtStatus.Foreground = [System.Windows.Media.Brushes]::DarkRed }
            "error"    { $controls.txtStatus.Foreground = [System.Windows.Media.Brushes]::DarkRed }
            default     { $controls.txtStatus.Foreground = [System.Windows.Media.Brushes]::Black }
        }
    }
}
#endregion

    # Global variables for computer filtering
    $script:allComputers = @()
    
    # Function to filter computers based on search text
    $FilterComputers = {
        param($filterText)
        
        if ([string]::IsNullOrWhiteSpace($filterText)) {
            return $script:allComputers
        }
        
        $filterPattern = "*$([System.Management.Automation.WildcardPattern]::Escape($filterText))*"
        return $script:allComputers | Where-Object { $_ -like $filterPattern }
    }

    # Passwortfelder leeren und zwischengespeichertes Passwort verwerfen
    $ClearLapsDetails = {
        param([string]$Placeholder = "")
        $script:CurrentLapsPassword = $null
        $controls.txtLapsUser.Text = $Placeholder
        $controls.txtLapsPasswordDisplay.Text = $Placeholder
        $controls.txtPasswordExpiry.Text = $Placeholder
        $controls.txtPasswordLastSet.Text = $Placeholder
        $controls.txtLapsVersion.Text = $Placeholder
    }

    $LoadLapsPasswordForComputer = {
        param(
            [string]$ComputerName
        )

        if ([string]::IsNullOrWhiteSpace($ComputerName)) {
            & $global:UpdateStatus -IsLapsCheck "Bitte einen Computernamen eingeben oder auswaehlen." "Warning"
            return
        }

        $controls.txtComputerName.Text = $ComputerName
        & $ClearLapsDetails "Lade..."

        try {
            & $global:UpdateStatus -IsLapsCheck "Lese LAPS Passwort fuer $ComputerName..."
            $passwordInfo = Get-LapsPasswordEx -ComputerName $ComputerName

            if ($passwordInfo.Success) {
                $plainPassword = Convert-SecureStringToPlainText -SecureString $passwordInfo.Password
                $script:CurrentLapsPassword = $plainPassword
                $controls.txtLapsUser.Text = $passwordInfo.UserName
                $controls.txtLapsPasswordDisplay.Text = $plainPassword
                $controls.txtPasswordExpiry.Text = if ($passwordInfo.PasswordExpiresTimestamp) { $passwordInfo.PasswordExpiresTimestamp.ToString("g") } else { "N/A" }
                $controls.txtPasswordLastSet.Text = if ($passwordInfo.PasswordLastSetTimestamp) { $passwordInfo.PasswordLastSetTimestamp.ToString("g") } else { "N/A" }
                $controls.txtLapsVersion.Text = $passwordInfo.LapsVersion
                & $global:UpdateStatus -IsLapsCheck "LAPS Passwort fuer $ComputerName erfolgreich gelesen." "OK"
            }
            else {
                & $ClearLapsDetails "N/A"
                $controls.txtLapsPasswordDisplay.Text = "Passwort nicht verfuegbar."
                & $global:UpdateStatus -IsLapsCheck "LAPS-Passwort fuer $ComputerName nicht verfuegbar: $($passwordInfo.ErrorMessage)" "Warning"
            }
        }
        catch {
            & $ClearLapsDetails "N/A"
            $controls.txtLapsPasswordDisplay.Text = "LAPS Passwort konnte nicht gelesen werden."
            & $global:UpdateStatus -IsLapsCheck "Fehler beim Laden der LAPS-Passwort Informationen: $($_.Exception.Message)" "Error"
        }
    }
    
    # AD Computerliste laden
    $controls.btnRefreshAdList.Add_Click({
        & $global:UpdateStatus -IsLapsCheck "Lade AD Computerliste..."
        [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
        try {
            $script:allComputers = @(Get-ADComputer -Filter * | Select-Object -ExpandProperty Name | Sort-Object)
            if ($script:allComputers.Count -gt 0) {
                & $global:UpdateStatus -IsLapsCheck "AD Computerliste geladen ($($script:allComputers.Count) Eintraege)."
            } else {
                & $global:UpdateStatus -IsLapsCheck "Keine Computer in AD gefunden."
            }
        }
        catch {
            & $global:UpdateStatus -IsLapsCheck "Fehler beim Laden der AD Computerliste: $($_.Exception.Message)" "Error"
        }
        finally {
            [System.Windows.Input.Mouse]::OverrideCursor = $null
        }
        
        $filterText = if ($controls.txtFilter) { $controls.txtFilter.Text } else { "" }
        $filteredComputers = @(& $FilterComputers $filterText)
        $controls.lstAdComputers.ItemsSource = $filteredComputers
        
        if ([string]::IsNullOrWhiteSpace($filterText)) {
            & $global:UpdateStatus -IsLapsCheck "Filter zurueckgesetzt. Zeige alle $($script:allComputers.Count) Computer."
        } else {
            & $global:UpdateStatus -IsLapsCheck "Filter angewendet - '$filterText'. $($filteredComputers.Count) von $($script:allComputers.Count) Computern werden angezeigt."
        }
    })

    if ($controls.txtFilter) {
        $controls.txtFilter.Add_TextChanged({
            $filterText = $controls.txtFilter.Text
            $controls.lstAdComputers.ItemsSource = @(& $FilterComputers $filterText)
        })
    }

    # Listenauswahl übernimmt nur den Computernamen. Das Passwort wird bewusst erst auf
    # explizite Aktion (Show Password / Enter / Doppelklick) gelesen, damit nicht jede
    # Navigation in der Liste einen (auditierten) Passwortabruf im AD auslöst.
    $controls.lstAdComputers.Add_SelectionChanged({
        $selectedComputer = $controls.lstAdComputers.SelectedItem
        if (-not $selectedComputer) { return }

        if ($controls.txtComputerName.Text -ne [string]$selectedComputer) {
            $controls.txtComputerName.Text = [string]$selectedComputer
            & $ClearLapsDetails ""
        }
    })

    $controls.lstAdComputers.Add_MouseDoubleClick({
        $selectedComputer = $controls.lstAdComputers.SelectedItem
        if (-not $selectedComputer) { return }

        & $LoadLapsPasswordForComputer ([string]$selectedComputer)
    })

    # LAPS Passwort anzeigen
    $controls.btnGetLapsPassword.Add_Click({
        $computer = $controls.txtComputerName.Text

        if ([string]::IsNullOrWhiteSpace($computer)) {
            & $global:UpdateStatus -IsLapsCheck "Bitte einen Computernamen eingeben oder auswaehlen." "Warning"
            [System.Windows.MessageBox]::Show("Bitte einen Computernamen eingeben oder auswaehlen.", "Hinweis", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }

        & $LoadLapsPasswordForComputer $computer
    })

    # LAPS Passwort zuruecksetzen
    $controls.btnResetLapsPassword.Add_Click({
        $computer = $controls.txtComputerName.Text
        if ([string]::IsNullOrWhiteSpace($computer)) {
            & $global:UpdateStatus -IsLapsCheck "Bitte einen Computernamen eingeben oder auswaehlen, um den Status zu pruefen." "Error"
            [System.Windows.MessageBox]::Show("Bitte einen Computernamen eingeben oder auswaehlen.", "Hinweis", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }
        $confirm = [System.Windows.MessageBox]::Show(
            "Moechten Sie das LAPS Passwort fuer '$computer' wirklich jetzt zuruecksetzen?", 
            "Bestaetigung", 
            [System.Windows.MessageBoxButton]::YesNo, 
            [System.Windows.MessageBoxImage]::Question
        )
        
        if ($confirm -eq 'Yes') {
            & $global:UpdateStatus -IsLapsCheck "Setze LAPS Passwort fuer $computer zurueck..."
            try {
                # Use the improved function for resetting LAPS passwords
                $resetResult = Reset-LapsPasswordEx -ComputerName $computer -Force
                
                if ($resetResult.Success) {
                    & $global:UpdateStatus -IsLapsCheck "LAPS Passwort fuer $computer erfolgreich zurueckgesetzt. Es kann einige Zeit dauern, bis es aktiv wird."
                    [System.Windows.MessageBox]::Show(
                        "LAPS Passwort fuer '$computer' erfolgreich zurueckgesetzt. LAPS Version: $($resetResult.LapsVersion)", 
                        "Erfolg", 
                        [System.Windows.MessageBoxButton]::OK, 
                        [System.Windows.MessageBoxImage]::Information
                    )
                    # Passwortfelder leeren: Das Passwort wurde als abgelaufen markiert, die Rotation
                    # erfolgt erst beim nächsten LAPS-Policy-Processing auf dem Zielgerät.
                    & $ClearLapsDetails ""
                    $controls.txtLapsPasswordDisplay.Text = "(Passwort als abgelaufen markiert - Rotation beim naechsten Policy-Processing)"
                    $controls.txtPasswordExpiry.Text = if ($resetResult.NewExpirationTime) { $resetResult.NewExpirationTime.ToString("g") } else { "Sofort (abgelaufen)" }
                    $controls.txtLapsVersion.Text = $resetResult.LapsVersion
                } else {
                    & $global:UpdateStatus -IsLapsCheck "Fehler beim Zuruecksetzen des LAPS-Passworts: $($resetResult.ErrorMessage)" "Error"
                    [System.Windows.MessageBox]::Show("Fehler beim Zuruecksetzen des LAPS-Passworts: $($resetResult.ErrorMessage)", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
            catch {
                & $global:UpdateStatus -IsLapsCheck "Fehler beim Zuruecksetzen des LAPS-Passworts: $($_.Exception.Message)" "Error"
                [System.Windows.MessageBox]::Show("Fehler beim Zuruecksetzen des LAPS-Passworts: $($_.Exception.Message)", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        }
    })

    # Passwort kopieren
    $controls.btnCopyPassword.Add_Click({
        # Nur ein tatsächlich abgerufenes Passwort kopieren (keine Status-/Platzhaltertexte)
        $password = $script:CurrentLapsPassword
        if (-not [string]::IsNullOrEmpty($password)) {
            try {
                Set-ClipboardSecret -Text $password
                $clearHint = if ($script:ClipboardClearSeconds -gt 0) { " Wird in $($script:ClipboardClearSeconds) Sekunden automatisch geleert." } else { "" }
                & $global:UpdateStatus -IsLapsCheck "Passwort in die Zwischenablage kopiert.$clearHint" "OK"
            }
            catch {
                & $global:UpdateStatus -IsLapsCheck "Fehler beim Kopieren in die Zwischenablage: $($_.Exception.Message)" "Error"
            }
        } else {
            & $global:UpdateStatus -IsLapsCheck "Kein Passwort zum Kopieren vorhanden." "Warning"
        }
    })

    # Export Selected Computer
    $controls.btnExportSelected.Add_Click({
        $selectedComputer = $controls.lstAdComputers.SelectedItem
        if ($null -eq $selectedComputer -and -not [string]::IsNullOrWhiteSpace($controls.txtComputerName.Text)) {
            $selectedComputer = $controls.txtComputerName.Text.Trim()
        }
        if ($null -eq $selectedComputer) {
            & $global:UpdateStatus -IsLapsCheck "Kein Computer ausgewählt." "Warning"
            [System.Windows.MessageBox]::Show("Bitte wählen Sie einen Computer aus der Liste aus oder geben Sie einen Namen ein.", "Warnung", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }

        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "CSV Dateien (*.csv)|*.csv"
        $saveDialog.Title = "LAPS Passwort exportieren"
        $saveDialog.FileName = "LAPS_Export_$($selectedComputer)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        
        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            & $global:UpdateStatus -IsLapsCheck "Exportiere Computer: $selectedComputer"
            
            try {
                $result = Export-LapsPasswordToCsv -FilePath $saveDialog.FileName -ComputerList @($selectedComputer)
                
                if ($result.Success) {
                    & $global:UpdateStatus -IsLapsCheck "Export erfolgreich: $($result.FilePath)" "OK"
                    [System.Windows.MessageBox]::Show("Export erfolgreich abgeschlossen.`n`nDatei: $($result.FilePath)", "Export erfolgreich", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                } else {
                    & $global:UpdateStatus -IsLapsCheck "Export fehlgeschlagen: $($result.ErrorMessage)" "Error"
                    [System.Windows.MessageBox]::Show("Export fehlgeschlagen:`n$($result.ErrorMessage)", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
            catch {
                & $global:UpdateStatus -IsLapsCheck "Export-Fehler: $($_.Exception.Message)" "Error"
                [System.Windows.MessageBox]::Show("Fehler beim Export:`n$($_.Exception.Message)", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        }
    })

    # Export All Computers
    $controls.btnExportAll.Add_Click({
        if ($controls.lstAdComputers.Items.Count -eq 0) {
            & $global:UpdateStatus -IsLapsCheck "Keine Computer zum Exportieren vorhanden." "Warning"
            [System.Windows.MessageBox]::Show("Bitte laden Sie zuerst die AD-Computerliste.", "Warnung", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }

        $confirmResult = [System.Windows.MessageBox]::Show("Möchten Sie wirklich alle $($controls.lstAdComputers.Items.Count) Computer exportieren?`n`nDies kann einige Zeit in Anspruch nehmen.", "Bestätigung", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        
        if ($confirmResult -eq [System.Windows.MessageBoxResult]::Yes) {
            $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
            $saveDialog.Filter = "CSV Dateien (*.csv)|*.csv"
            $saveDialog.Title = "LAPS Passwörter exportieren"
            $saveDialog.FileName = "LAPS_Export_ALL_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            
            if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                & $global:UpdateStatus -IsLapsCheck "Exportiere $($controls.lstAdComputers.Items.Count) Computer..."
                
                [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                try {
                    $allComputers = @($controls.lstAdComputers.Items)
                    $result = Export-LapsPasswordToCsv -FilePath $saveDialog.FileName -ComputerList $allComputers
                    [System.Windows.Input.Mouse]::OverrideCursor = $null
                    
                    if ($result.Success) {
                        & $global:UpdateStatus -IsLapsCheck "Export erfolgreich: $($result.Count) Computer exportiert" "OK"
                        [System.Windows.MessageBox]::Show("Export erfolgreich abgeschlossen.`n`nDatei: $($result.FilePath)`nAnzahl: $($result.Count) Computer", "Export erfolgreich", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                    } else {
                        & $global:UpdateStatus -IsLapsCheck "Export fehlgeschlagen: $($result.ErrorMessage)" "Error"
                        [System.Windows.MessageBox]::Show("Export fehlgeschlagen:`n$($result.ErrorMessage)", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                    }
                }
                catch {
                    & $global:UpdateStatus -IsLapsCheck "Export-Fehler: $($_.Exception.Message)" "Error"
                    [System.Windows.MessageBox]::Show("Fehler beim Export:`n$($_.Exception.Message)", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
                finally {
                    [System.Windows.Input.Mouse]::OverrideCursor = $null
                }
            }
        }
    })

    # Rotate All Passwords
    $controls.btnRotateAll.Add_Click({
        if ($controls.lstAdComputers.Items.Count -eq 0) {
            & $global:UpdateStatus -IsLapsCheck "Keine Computer zum Rotieren vorhanden." "Warning"
            [System.Windows.MessageBox]::Show("Bitte laden Sie zuerst die AD-Computerliste.", "Warnung", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }

        $confirmResult = [System.Windows.MessageBox]::Show("WARNUNG: Diese Aktion wird die LAPS-Passwörter für alle $($controls.lstAdComputers.Items.Count) Computer zurücksetzen!`n`nMöchten Sie wirklich fortfahren?`n`nDies kann einige Zeit in Anspruch nehmen.", "Bestätigung erforderlich", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        
        if ($confirmResult -eq [System.Windows.MessageBoxResult]::Yes) {
            & $global:UpdateStatus -IsLapsCheck "Rotiere Passwörter für $($controls.lstAdComputers.Items.Count) Computer..."
            
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            try {
                $allComputers = @($controls.lstAdComputers.Items)
                $result = Invoke-LapsPasswordRotation -ComputerList $allComputers
                [System.Windows.Input.Mouse]::OverrideCursor = $null
                
                if ($result.Success) {
                    & $global:UpdateStatus -IsLapsCheck "Rotation abgeschlossen: $($result.SuccessCount) erfolgreich, $($result.FailCount) fehlgeschlagen" "OK"
                    
                    $resultMessage = "Passwort-Rotation abgeschlossen:`n`n"
                    $resultMessage += "Gesamt: $($result.TotalCount) Computer`n"
                    $resultMessage += "Erfolgreich: $($result.SuccessCount)`n"
                    $resultMessage += "Fehlgeschlagen: $($result.FailCount)`n`n"
                    
                    if ($result.FailCount -gt 0) {
                        $resultMessage += "Fehlerhafte Computer:`n"
                        $result.Results | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
                            $resultMessage += "- $($_.ComputerName): $($_.Message)`n"
                        }
                    }
                    
                    [System.Windows.MessageBox]::Show($resultMessage, "Rotation abgeschlossen", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                } else {
                    & $global:UpdateStatus -IsLapsCheck "Rotation fehlgeschlagen: $($result.ErrorMessage)" "Error"
                    [System.Windows.MessageBox]::Show("Rotation fehlgeschlagen:`n$($result.ErrorMessage)", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
            catch {
                & $global:UpdateStatus -IsLapsCheck "Rotations-Fehler: $($_.Exception.Message)" "Error"
                [System.Windows.MessageBox]::Show("Fehler bei der Rotation:`n$($_.Exception.Message)", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
            finally {
                [System.Windows.Input.Mouse]::OverrideCursor = $null
            }
        }
    })

    # LAPS-Status des lokalen Systems ermitteln und anzeigen (gemeinsam für Button und Programmstart)
    $UpdateLapsStatusDisplay = {
        $computer = $env:COMPUTERNAME
        & $global:UpdateStatus -IsLapsCheck "Pruefe LAPS-Status fuer $computer..." "Pruefung"

        try {
            $lapsStatus = Get-LocalLapsStatus
            $details = New-Object System.Collections.Generic.List[string]
            $details.Add("Systemtyp erkannt: $($lapsStatus.SystemType)")

            if ($lapsStatus.LapsInstalled) {
                $controls.lblLapsInstalledStatus.Text = "$($lapsStatus.LapsType) installiert"
                $controls.ellipseLapsInstalled.Fill = [System.Windows.Media.Brushes]::Green
                $details.Add("$($lapsStatus.LapsType) ist installiert.")
                & $global:UpdateStatus -IsLapsCheck "$($lapsStatus.LapsType) auf diesem System gefunden. Pruefe Richtlinien..." "Pruefung"
            } else {
                $controls.lblLapsInstalledStatus.Text = "Nicht installiert"
                $controls.ellipseLapsInstalled.Fill = [System.Windows.Media.Brushes]::Red
                $details.Add("LAPS ist auf diesem System nicht installiert.")
                & $global:UpdateStatus -IsLapsCheck "LAPS ist auf diesem System nicht installiert." "Warning"
            }

            if ($lapsStatus.PolicyActive) {
                $controls.lblGpoStatus.Text = "Aktiv ($($lapsStatus.PolicySource))"
                $controls.ellipseGpoStatus.Fill = [System.Windows.Media.Brushes]::Green
                $details.Add("Aktive Policy: $($lapsStatus.PolicySource)")
                $details.Add("Registry: $($lapsStatus.PolicyRoot)")
                & $global:UpdateStatus -IsLapsCheck "LAPS-Richtlinie aktiv: $($lapsStatus.PolicySource)." "OK"
            } else {
                $controls.lblGpoStatus.Text = "Keine LAPS-Richtlinie gefunden"
                $controls.ellipseGpoStatus.Fill = if ($lapsStatus.LapsInstalled) { [System.Windows.Media.Brushes]::Red } else { [System.Windows.Media.Brushes]::Gray }
                $details.Add("Keine aktive LAPS-Richtlinie gefunden (CSP, GPO, lokale Konfiguration, Legacy).")
                $details.Add("Hinweis: https://learn.microsoft.com/windows-server/identity/laps/laps-management-policy-settings")
                & $global:UpdateStatus -IsLapsCheck "Keine aktive LAPS-Richtlinie gefunden. Bitte LAPS-Richtlinie konfigurieren." "Warning"
            }

            $controls.txtPolicyDetails.Text = $details -join "`r`n"
        } catch {
            $controls.lblLapsInstalledStatus.Text = "Fehler"
            $controls.ellipseLapsInstalled.Fill = [System.Windows.Media.Brushes]::Red
            $controls.lblGpoStatus.Text = "Fehler"
            $controls.ellipseGpoStatus.Fill = [System.Windows.Media.Brushes]::Red
            $controls.txtPolicyDetails.Text = "Fehler beim Überprüfen des LAPS-Status: $($_.Exception.Message)"
            & $global:UpdateStatus -IsLapsCheck "Fehler beim Überprüfen des LAPS-Status: $($_.Exception.Message)" "Error"
        }
    }

    # LAPS Client Status & Richtlinien pruefen
    $controls.btnCheckLapsStatus.Add_Click({
        & $UpdateLapsStatusDisplay
    })

    # Lokale LAPS-Policy-Verarbeitung anstoßen
    $controls.btnRunPolicyProcessing.Add_Click({
        & $global:UpdateStatus -IsLapsCheck "Starte lokale LAPS-Policy-Verarbeitung..." "Pruefung"

        try {
            if (-not (Get-Command -Name Invoke-LapsPolicyProcessing -ErrorAction SilentlyContinue)) {
                $msg = "Invoke-LapsPolicyProcessing ist nicht verfügbar. Bitte Windows LAPS PowerShell-Modul prüfen."
                & $global:UpdateStatus -IsLapsCheck $msg "Warning"
                [System.Windows.MessageBox]::Show($msg, "Policy-Trigger nicht verfügbar", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return
            }

            Invoke-LapsPolicyProcessing -ErrorAction Stop
            & $global:UpdateStatus -IsLapsCheck "Lokale LAPS-Policy-Verarbeitung wurde gestartet. Ergebnis über Eventlog prüfen (10003/10004/10005)." "OK"
            [System.Windows.MessageBox]::Show(
                "Die lokale LAPS-Policy-Verarbeitung wurde gestartet.`n`nHinweis: Dieser Vorgang wirkt nur auf das lokale System.`nPrüfen Sie den Eventlog-Kanal 'Microsoft-Windows-LAPS/Operational' (z. B. 10003, 10004, 10005).",
                "Policy-Verarbeitung gestartet",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
        catch {
            & $global:UpdateStatus -IsLapsCheck "Fehler beim Starten der lokalen LAPS-Policy-Verarbeitung: $($_.Exception.Message)" "Error"
            [System.Windows.MessageBox]::Show("Fehler beim Starten der lokalen LAPS-Policy-Verarbeitung:`n$($_.Exception.Message)", "Policy-Trigger Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })

    # LAPS Diagnose ausführen und ZIP öffnen
    $controls.btnRunDiagnostics.Add_Click({
        & $global:UpdateStatus -IsLapsCheck "Starte LAPS-Diagnose..." "Pruefung"

        try {
            if (-not (Get-Command -Name Get-LapsDiagnostics -ErrorAction SilentlyContinue)) {
                $msg = "Get-LapsDiagnostics ist nicht verfügbar. Bitte Windows LAPS PowerShell-Modul prüfen."
                & $global:UpdateStatus -IsLapsCheck $msg "Warning"
                [System.Windows.MessageBox]::Show($msg, "Diagnose nicht verfügbar", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return
            }

            $diagFolder = Join-Path -Path $script:logPath -ChildPath "Diagnostics"
            if (-not (Test-Path -Path $diagFolder)) {
                New-Item -Path $diagFolder -ItemType Directory -Force | Out-Null
            }

            $diagOutput = (Get-LapsDiagnostics -OutputFolder $diagFolder -ErrorAction Stop 2>&1 | Out-String)
            $zipPath = $null

            $zipRegexMatch = [regex]::Match($diagOutput, '([A-Za-z]:\\[^\r\n]+?\.zip)')
            if ($zipRegexMatch.Success) {
                $zipPath = $zipRegexMatch.Groups[1].Value.Trim()
            }

            if (-not $zipPath) {
                $latestZip = Get-ChildItem -Path $diagFolder -Filter "*.zip" -File -ErrorAction SilentlyContinue |
                             Sort-Object LastWriteTime -Descending |
                             Select-Object -First 1
                if ($latestZip) {
                    $zipPath = $latestZip.FullName
                }
            }

            if ($zipPath -and (Test-Path -Path $zipPath)) {
                Start-Process -FilePath $zipPath
                & $global:UpdateStatus -IsLapsCheck "Diagnose abgeschlossen. ZIP geöffnet: $zipPath" "OK"
                [System.Windows.MessageBox]::Show("Diagnose erfolgreich abgeschlossen.`n`nZIP: $zipPath", "Diagnose abgeschlossen", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            }
            else {
                & $global:UpdateStatus -IsLapsCheck "Diagnose ausgeführt, aber keine ZIP-Datei gefunden. Öffne Diagnosenordner..." "Warning"
                if (Test-Path -Path $diagFolder) {
                    Start-Process -FilePath $diagFolder
                }
                [System.Windows.MessageBox]::Show("Diagnose wurde ausgeführt, aber die ZIP-Datei konnte nicht automatisch ermittelt werden.`n`nOrdner: $diagFolder", "Diagnosehinweis", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            }
        }
        catch {
            & $global:UpdateStatus -IsLapsCheck "Diagnose-Fehler: $($_.Exception.Message)" "Error"
            [System.Windows.MessageBox]::Show("Fehler bei der LAPS-Diagnose:`n$($_.Exception.Message)", "Diagnosefehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })

    # Initiale Prüfung beim Programmstart ausführen (ohne automatisches Öffnen externer Webseiten)
    & $UpdateLapsStatusDisplay

    # Zwischenablage beim Schließen leeren, falls noch ein kopiertes Passwort enthalten ist
    $window.Add_Closed({
        Clear-ClipboardSecret
        $script:CurrentLapsPassword = $null
    })

    # Update module status label
    if ($ModuleStatus) {
        $moduleStatusText = "Module: Windows LAPS=$($ModuleStatus.NewModuleAvailable) | Legacy LAPS=$($ModuleStatus.LegacyModuleAvailable) | ActiveDirectory=$($ModuleStatus.ADModuleAvailable)"
        $controls.lblModuleStatus.Text = $moduleStatusText
    }

    # Fenster anzeigen
    [VOID]$window.ShowDialog()
}

#region Main Script Execution - Hauptskriptausführung
# Set error action preference for the main script block
$ErrorActionPreference = "Stop"

try {
    # Unter PowerShell 7 (Core) automatisch in Windows PowerShell 5.1 neu starten (WPF/RSAT/LAPS-Module)
    if ($PSVersionTable.PSEdition -eq 'Core' -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $winPS = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
        if (Test-Path -Path $winPS) {
            Write-Log "PowerShell $($PSVersionTable.PSVersion) erkannt - Neustart in Windows PowerShell 5.1." -Level "INFO"
            Start-Process -FilePath $winPS -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-STA", "-File", "`"$PSCommandPath`"")
            exit 0
        }
    }

    # Erforderliche Assemblies früh laden (MessageBox wird bereits bei den Startprüfungen benötigt)
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms


    # Prüfe auf korrekte PowerShell Version (5.1 erforderlich)
    if (-Not $PSVersionTable.PSVersion.ToString().StartsWith("5.1")) {
        $errorMsg = "Windows PowerShell Version 5.1 ist erforderlich!`nAktuelle Version: $($PSVersionTable.PSVersion)"
        Write-Log $errorMsg -Level "ERROR"
        [System.Windows.MessageBox]::Show($errorMsg, "Fehler - Falsche PowerShell Version", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        exit 501
    }
    
    # Prüfe, ob mindestens ein unterstützter LAPS-Pfad verfügbar ist
    $newModuleAvailable = [bool](Get-Module -Name Laps -ListAvailable)
    $legacyGetAvailable = [bool](Get-Command -Name Get-AdmPwdPassword -ErrorAction SilentlyContinue)
    $legacyResetAvailable = [bool](Get-Command -Name Reset-AdmPwdPassword -ErrorAction SilentlyContinue)
    $legacyModuleAvailable = $legacyGetAvailable -and $legacyResetAvailable
    $adModuleAvailable = [bool](Get-Module -Name ActiveDirectory -ListAvailable)

    if (-Not ($newModuleAvailable -or $legacyModuleAvailable -or $adModuleAvailable)) {
        $errorMsg = "Keine Moeglichkeit zum Lesen von LAPS-Passwoertern gefunden!`n`nErforderlich ist mindestens eines von:`n- Windows LAPS (Modul 'LAPS', ab Windows 10/11 bzw. Server 2019 mit Update April 2023)`n- Legacy LAPS Cmdlets (AdmPwd.PS)`n- ActiveDirectory-Modul (RSAT) fuer das direkte Lesen der LAPS-Attribute"
        Write-Log $errorMsg -Level "ERROR"
        [System.Windows.MessageBox]::Show($errorMsg, "Fehler - Module fehlen", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        exit 502
    }
    if (-not $adModuleAvailable) {
        Write-Log "ActiveDirectory-Modul (RSAT) nicht gefunden - AD-Computerliste nicht verfuegbar." -Level "WARNING"
    }
    
    Write-Log "easyLAPS Script gestartet. Logging in: $script:LogFilePath" -Level "INFO"
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "INFO"
    Write-Log "Modulstatus: Windows LAPS=$newModuleAvailable, Legacy LAPS=$legacyModuleAvailable, ActiveDirectory=$adModuleAvailable" -Level "INFO"
    Write-Log "easyLAPS GUI wird gestartet..." -Level "INFO"

    # Hauptformular anzeigen
    Show-LAPSForm -ModuleStatus @{
        NewModuleAvailable = $newModuleAvailable
        LegacyModuleAvailable = $legacyModuleAvailable
        ADModuleAvailable = $adModuleAvailable
    }

    Write-Log "easyLAPS GUI wurde vom Benutzer oder einem internen Prozess geschlossen." -Level "INFO"
}
catch {
    $criticalErrorMsg = "Ein kritischer Fehler ist im Hauptskriptblock aufgetreten: $($_.Exception.Message)"
    Write-Log $criticalErrorMsg -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    try { 
        # Versuche, die erforderlichen Assemblies zu laden, falls noch nicht geschehen
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        [System.Windows.MessageBox]::Show("$criticalErrorMsg`n`nDetails:`n$($_.ScriptStackTrace)", "Kritischer Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    } 
    catch {
        # Fallback auf einfache Konsolenausgabe, wenn MessageBox nicht verfuegbar ist
        Write-Host "KRITISCHER FEHLER: $criticalErrorMsg`n`nDetails:`n$($_.ScriptStackTrace)" -ForegroundColor Red
    }
    Write-Log "easyLAPS Script wegen kritischem Fehler beendet." -Level "ERROR"
    exit 1
}
finally {
    Write-Log "easyLAPS Script-Ausfuehrung beendet." -Level "INFO"
}