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
    ScriptVersion = "0.3.4"
    Author = "Andreas Hepp"
    ThemeColor = "#0078D7"
    LastUpdate = (Get-Date -Format "yyyy-MM-dd")
    Company = "PhinIT"
    Website = "https://www.phinit.de"
    Description = "Local Admin Password Solution fuer Windows-Umgebungen"
    Copyright = "© $(Get-Date -Format 'yyyy') PhinIT"
}

# Branding-GUI Einstellungen
$script:BrandingGUI = @{
    APPName = $script:ScriptInfo.AppName
    FontFamily = "Segoe UI"
    HeaderLogo = Join-Path $script:ScriptPath "resources\logo.png"
    HeaderLogoURL = $script:ScriptInfo.Website
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
    
    try {
        # Log-Rotation durchführen
        Invoke-LogRotation

        # Sicherstellen, dass der Log-Ordner existiert
        $logDir = Split-Path -Path $LogFilePath -Parent
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        # Zeitstempel für Log-Eintrag
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
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
        $oldLogs = Get-ChildItem -Path $script:logPath -Filter "*.log" | 
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
    Write-Log -Message $detailedMessage -Type "Error"
    
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
        Write-Log -Message "Fehler bei Update-GuiText: $($_.Exception.Message)" -Type "Error"
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
        Write-Log -Message "Fehler beim Anzeigen der MessageBox: $($_.Exception.Message)" -Type "Error"
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
        Write-Log -Message "Fehler beim Lesen des Registry-Werts '$Name': $($_.Exception.Message)" -Type "Error"
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
        Write-Log -Message "Fehler beim Setzen des Registry-Werts '$Name': $($_.Exception.Message)" -Type "Error"
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
        $exportData = @()
        $totalComputers = $ComputerList.Count
        $currentComputer = 0
        
        foreach ($computer in $ComputerList) {
            $currentComputer++
            Write-Log "Exportiere Computer $currentComputer von $totalComputers : $computer" -Level "Info"
            
            $lapsData = Get-LapsPasswordEx -ComputerName $computer -Domain $Domain
            
            if ($lapsData.Success) {
                $plainPassword = Convert-SecureStringToPlainText -SecureString $lapsData.Password
                
                $exportData += [PSCustomObject]@{
                    ComputerName = $lapsData.ComputerName
                    UserName = $lapsData.UserName
                    Password = $plainPassword
                    PasswordExpires = if ($lapsData.PasswordExpiresTimestamp) { $lapsData.PasswordExpiresTimestamp.ToString('yyyy-MM-dd HH:mm:ss') } else { "N/A" }
                    PasswordLastSet = if ($lapsData.PasswordLastSetTimestamp) { $lapsData.PasswordLastSetTimestamp.ToString('yyyy-MM-dd HH:mm:ss') } else { "N/A" }
                    LapsVersion = $lapsData.LapsVersion
                    ExportDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
            else {
                Write-Log "Fehler beim Exportieren von $computer : $($lapsData.ErrorMessage)" -Level "Warning"
                $exportData += [PSCustomObject]@{
                    ComputerName = $computer
                    UserName = "ERROR"
                    Password = $lapsData.ErrorMessage
                    PasswordExpires = "N/A"
                    PasswordLastSet = "N/A"
                    LapsVersion = "N/A"
                    ExportDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                }
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
        $results = @()
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
                $results += [PSCustomObject]@{
                    ComputerName = $computer
                    Status = "Success"
                    Message = "Password rotation successful"
                    NewExpiration = if ($resetResult.NewExpirationTime) { $resetResult.NewExpirationTime.ToString('yyyy-MM-dd HH:mm:ss') } else { "N/A" }
                }
            }
            else {
                $failCount++
                Write-Log "Fehler beim Rotieren von $computer : $($resetResult.ErrorMessage)" -Level "Warning"
                $results += [PSCustomObject]@{
                    ComputerName = $computer
                    Status = "Failed"
                    Message = $resetResult.ErrorMessage
                    NewExpiration = "N/A"
                }
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
    }
    
    try {
        # Versuche Windows LAPS mit AsPlainText (entschlüsselt automatisch wenn Berechtigung vorhanden)
        if ([string]::IsNullOrWhiteSpace($Domain)) {
            $pwdInfo = Get-LapsADPassword -Identity $ComputerName -AsPlainText -IncludeHistory -ErrorAction Stop -WarningAction SilentlyContinue | Select-Object -First 1
        } else {
            $pwdInfo = Get-LapsADPassword -Identity $ComputerName -Domain $Domain -AsPlainText -IncludeHistory -ErrorAction Stop -WarningAction SilentlyContinue | Select-Object -First 1
        }
        
        # Prüfe ob Passwort-Daten vorhanden sind
        if ($null -eq $pwdInfo) {
            $result.ErrorMessage = "Keine Passwort-Daten verfügbar."
            Write-Log "Keine LAPS Passwort-Daten für $ComputerName gefunden." -Level "Warning"
            return $result
        }
        
        # Validiere die Passwort-Daten
        if ($null -eq $pwdInfo.Password -or $null -eq $pwdInfo.ComputerName -or $null -eq $pwdInfo.ExpirationTimestamp) {
            $result.ErrorMessage = "Unvollständige Passwort-Daten."
            Write-Log "LAPS Passwort-Daten für $ComputerName sind unvollständig." -Level "Warning"
            return $result
        }
        
        # Erfolgreicher Abruf
        $result.Success = $true
        $result.Password = ConvertTo-SecureString $pwdInfo.Password -AsPlainText -Force
        $result.UserName = if ($null -ne $pwdInfo.Account) { $pwdInfo.Account } else { "Administrator" }
        $result.PasswordExpiresTimestamp = $pwdInfo.ExpirationTimestamp
        $result.PasswordLastSetTimestamp = $pwdInfo.PasswordUpdateTime
        $result.LapsVersion = if ($null -ne $pwdInfo.PasswordUpdateTime) { "Windows LAPS" } else { "Legacy LAPS" }
        Write-Log "LAPS Passwort für $ComputerName erfolgreich abgerufen." -Level "Info"
    }
    catch {
        $errorMsg = $_.Exception.Message
        
        # Prüfe auf Verschlüsselungsfehler (fehlende Berechtigungen zur Entschlüsselung)
        if ($errorMsg -match "Deserialisieren|EncryptedPasswordAttributeRaw|Unerwartetes Zeichen") {
            $result.IsEncrypted = $true
            $result.ErrorMessage = "Passwort ist verschlüsselt. Sie haben keine Berechtigung zur Entschlüsselung oder der Entschlüsselungsschlüssel fehlt."
            Write-Log "LAPS Passwort für $ComputerName ist verschlüsselt - fehlende Entschlüsselungsberechtigung." -Level "Warning"
            return $result
        }
        # Prüfe auf spezifische Fehler
        elseif ($errorMsg -match "computer in AD") {
            $result.ErrorMessage = "Computer nicht im Active Directory gefunden."
            Write-Log "Computer $ComputerName nicht im AD gefunden." -Level "Warning"
        }
        elseif ($errorMsg -match "run on a AD domain-joined machine") {
            $result.ErrorMessage = "Dieses Programm muss auf einem AD-verbundenen Computer ausgeführt werden."
            Write-Log "Programm muss auf AD-verbundenem Computer laufen." -Level "Error"
        }
        elseif ($errorMsg -match "Access is denied|Zugriff verweigert") {
            $result.ErrorMessage = "Zugriff verweigert. Überprüfen Sie Ihre Berechtigungen."
            Write-Log "Zugriff auf LAPS Passwort für $ComputerName verweigert." -Level "Warning"
        }
        else {
            # Generischer Fehler - versuche Legacy LAPS als Fallback (nur ohne Domain)
            if ([string]::IsNullOrWhiteSpace($Domain)) {
                try {
                    # Prüfe ob Legacy LAPS Cmdlet verfügbar ist
                    if (Get-Command -Name Get-AdmPwdPassword -ErrorAction SilentlyContinue) {
                        $legacyPwd = Get-AdmPwdPassword -ComputerName $ComputerName -ErrorAction Stop
                        if ($null -ne $legacyPwd -and $null -ne $legacyPwd.Password) {
                            $result.Success = $true
                            $result.Password = ConvertTo-SecureString $legacyPwd.Password -AsPlainText -Force
                            $result.UserName = "Administrator"
                            $result.PasswordExpiresTimestamp = $legacyPwd.ExpirationTimestamp
                            $result.PasswordLastSetTimestamp = $null
                            $result.LapsVersion = "Legacy LAPS (AdmPwd)"
                            Write-Log "Legacy LAPS Passwort für $ComputerName erfolgreich abgerufen." -Level "Info"
                            return $result
                        }
                    }
                }
                catch {
                    Write-Log "Legacy LAPS Fallback fehlgeschlagen für $ComputerName : $($_.Exception.Message)" -Level "Debug"
                }
            }
            
            $result.ErrorMessage = $errorMsg
            Write-Log "Fehler beim Abrufen des LAPS Passworts für $ComputerName : $errorMsg" -Level "Error"
        }
    }
    
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
    }
    
    try {
        # Prüfe welche LAPS Version aktiv ist
        $pwdInfo = if ([string]::IsNullOrWhiteSpace($Domain)) {
            Get-LapsADPassword -Identity $ComputerName -ErrorAction Stop -WarningAction SilentlyContinue
        } else {
            Get-LapsADPassword -Identity $ComputerName -Domain $Domain -ErrorAction Stop -WarningAction SilentlyContinue
        }
        
        $isWinLaps = $null -ne $pwdInfo.PasswordUpdateTime
        $result.LapsVersion = if ($isWinLaps) { "Windows LAPS" } else { "Legacy LAPS" }
        
        if ($isWinLaps) {
            # Windows LAPS
            if ([string]::IsNullOrWhiteSpace($Domain)) {
                Reset-LapsPassword -Identity $ComputerName -ErrorAction Stop -WarningAction SilentlyContinue
            } else {
                Reset-LapsPassword -Identity $ComputerName -Domain $Domain -ErrorAction Stop -WarningAction SilentlyContinue
            }
        } else {
            # Legacy LAPS - nur ohne custom domain unterstützt
            if ([string]::IsNullOrWhiteSpace($Domain)) {
                Reset-AdmPwdPassword -ComputerName $ComputerName -ErrorAction Stop -WarningAction SilentlyContinue
            } else {
                throw "Legacy LAPS unterstützt keine custom Domain beim Reset."
            }
        }
        
        $result.Success = $true
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-Log "Fehler beim Zurücksetzen des LAPS Passworts für $ComputerName : $($_.Exception.Message)" -Level "Error"
    }
    
    return $result
}

function Convert-SecureStringToPlainText {
    param(
        [Parameter(Mandatory=$true)][System.Security.SecureString]$SecureString
    )
    
    try {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
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
    $headerLogoPath = $script:BrandingGUI.HeaderLogo
    $clickURL       = $script:BrandingGUI.HeaderLogoURL

    $scriptVersion = $script:ScriptInfo.ScriptVersion
    $lastUpdate    = $script:ScriptInfo.LastUpdate
    $author = $script:ScriptInfo.Author
    $footerText = "$appName v$scriptVersion ($lastUpdate) by $author"
    if ($script:BrandingGUI.FooterWebseite) { 
        $webseiteInfo = $script:BrandingGUI.FooterWebseite
        $footerText += " | $webseiteInfo" 
    }

    # (2) XAML Definition für die GUI
    $XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$appName" Height="940" Width="1200" MinHeight="600" MinWidth="800"
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
                <Image Name="imgLogo" Source="$headerLogoPath" MaxHeight="35" MaxWidth="140" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="10,0,0,0" Cursor="Hand" DockPanel.Dock="Right"/>
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
                <DockPanel>
                    <StackPanel DockPanel.Dock="Top" Orientation="Vertical" Margin="0,0,0,10">
                        <DockPanel Margin="0,0,0,5">
                            <TextBlock Text="Computer name:" VerticalAlignment="Center" Margin="0,0,5,0" Foreground="#1C1C1C"/>
                            <TextBox Name="txtComputerName" Width="200" Height="30" VerticalContentAlignment="Center"/>
                            <Button Name="btnRefreshAdList" Content="Load AD List" Margin="10,0,0,0" Padding="10,5" Height="30" DockPanel.Dock="Right" Style="{StaticResource ModernButton}"/>
                        </DockPanel>
                    </StackPanel>

                    <ListBox Name="lstAdComputers" Margin="0,0,0,10" DockPanel.Dock="Top" Height="427" SelectionMode="Single" BorderBrush="#BFBFBF" BorderThickness="1"/>

                    <TextBlock Text="LAPS Password Details:" FontWeight="SemiBold" Margin="0,10,0,5" DockPanel.Dock="Top" Foreground="#1C1C1C"/>
                    <Grid DockPanel.Dock="Top">
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
                        <TextBox Name="txtLapsPasswordDisplay" Grid.Row="1" Grid.Column="1" IsReadOnly="True" Height="30" VerticalContentAlignment="Center" Margin="0,0,0,5"/>
                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Expiration date:" Margin="0,0,5,5" VerticalAlignment="Center" Foreground="#505050"/>
                        <TextBox Name="txtPasswordExpiry" Grid.Row="2" Grid.Column="1" IsReadOnly="True" Height="30" VerticalContentAlignment="Center" Margin="0,0,0,5"/>
                        <TextBlock Grid.Row="3" Grid.Column="0" Text="Last change:" Margin="0,0,5,5" VerticalAlignment="Center" Foreground="#505050"/>
                        <TextBox Name="txtPasswordLastSet" Grid.Row="3" Grid.Column="1" IsReadOnly="True" Height="30" VerticalContentAlignment="Center" Margin="0,0,0,5"/>
                        <TextBlock Grid.Row="4" Grid.Column="0" Text="LAPS Version:" Margin="0,0,5,5" VerticalAlignment="Center" Foreground="#505050"/>
                        <TextBox Name="txtLapsVersion" Grid.Row="4" Grid.Column="1" IsReadOnly="True" Height="30" VerticalContentAlignment="Center" Margin="0,0,0,5"/>
                    </Grid>

                    <StackPanel DockPanel.Dock="Bottom" Orientation="Vertical" Margin="0,10,0,0">
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,5" Height="35">
                            <Button Name="btnGetLapsPassword" Content="Show Password" Width="130" Height="30" Margin="0,0,10,0" ToolTip="Shows the LAPS password (Ctrl+G)" Style="{StaticResource ModernButton}"/>
                            <Button Name="btnResetLapsPassword" Content="Reset Password" Width="130" Height="30" Margin="0,0,10,0" ToolTip="Resets the LAPS password (Ctrl+R)" Style="{StaticResource ModernButton}"/>
                            <Button Name="btnCopyPassword" Content="Copy to Clipboard" Width="130" Height="30" ToolTip="Copies the password to clipboard (Ctrl+C)" Style="{StaticResource ModernButton}"/>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,0" Height="35">
                            <Button Name="btnExportSelected" Content="Export Selected" Width="130" Height="30" Margin="0,0,10,0" ToolTip="Export selected computer to CSV" Style="{StaticResource ModernButton}"/>
                            <Button Name="btnExportAll" Content="Export All" Width="130" Height="30" Margin="0,0,10,0" ToolTip="Export all computers to CSV" Style="{StaticResource ModernButton}"/>
                            <Button Name="btnRotateAll" Content="Rotate All" Width="130" Height="30" ToolTip="Rotate passwords for all computers" Style="{StaticResource ModernButton}"/>
                        </StackPanel>
                    </StackPanel>
                </DockPanel>
            </Border>

            <!-- LAPS Details and Status -->
            <Border Grid.Column="1" Style="{StaticResource Card}" Margin="5,0,0,0">
                <DockPanel>
                    <TextBlock Text="LAPS Client Status and Policies" DockPanel.Dock="Top" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,10" Foreground="#1C1C1C"/>
                    <Button Name="btnCheckLapsStatus" Content="Check Status" Width="130" Height="30" DockPanel.Dock="Top" HorizontalAlignment="Left" Margin="75,0,0,10" ToolTip="Checks the LAPS status (Ctrl+P)" Style="{StaticResource ModernButton}"/>

                    <Grid DockPanel.Dock="Top">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <TextBlock Grid.Row="0" Grid.Column="1" Text="LAPS installed:" VerticalAlignment="Top" Margin="1,1,511,0" Foreground="#505050" Grid.ColumnSpan="2"/>
                        <Ellipse Name="ellipseLapsInstalled" Grid.Column="2" Width="16" Height="16" Fill="Gray" Stroke="Black" StrokeThickness="0.5" VerticalAlignment="Center" Margin="84,0,495,0"/>
                        <TextBlock Name="lblLapsInstalledStatus" Grid.Column="2" Text="Not checked" VerticalAlignment="Center" Margin="117,0,307,0" Foreground="#1C1C1C"/>

                        <TextBlock Grid.Column="2" Text="LAPS GPO active:" VerticalAlignment="Center" Margin="297,0,200,0" Foreground="#505050"/>
                        <Ellipse Name="ellipseGpoStatus" Grid.Column="2" Width="16" Height="16" Fill="Gray" Stroke="Black" StrokeThickness="0.5" VerticalAlignment="Center" Margin="395,0,184,0" RenderTransformOrigin="29.087,-0.851"/>
                        <TextBlock Name="lblGpoStatus" Grid.Column="2" Text="Not checked" VerticalAlignment="Center" Margin="429,0,0,0" Foreground="#1C1C1C"/>

                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Policy details:" VerticalAlignment="Top" Margin="0,10,5,0" Foreground="#505050"/>
                        <TextBox Name="txtPolicyDetails" Grid.Row="2" Grid.Column="1" Grid.ColumnSpan="2" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" IsReadOnly="True" Margin="0,10,0,-236" FontFamily="Consolas" FontSize="11" Style="{StaticResource ModernTextBox}"/>
                    </Grid>
                    <TextBox Name="txtStatus" Text="Ready." DockPanel.Dock="Bottom" Margin="0,240,0,0" FontStyle="Italic" FontSize="10" IsReadOnly="True" Height="390" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" Style="{StaticResource ModernTextBox}" Background="#F8F8F8"/>
                </DockPanel>
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
      "txtPasswordLastSet", "txtLapsVersion", "btnGetLapsPassword", "btnResetLapsPassword", "btnCopyPassword", "btnCheckLapsStatus", 
      "btnExportSelected", "btnExportAll", "btnRotateAll",
      "ellipseLapsInstalled", "lblLapsInstalledStatus", "ellipseGpoStatus", "lblGpoStatus", "txtPolicyDetails", 
      "txtStatus", "imgLogo", "lblFooter", "lblVersion", "lblModuleStatus") | ForEach-Object {
        $controls[$_] = $window.FindName($_)
    }

    # (4) Event Handler und Logik

    # Tastenkombinationen definieren
    $window.Add_KeyDown({
        param($sender, $e)
        
        # Strg+P für Status & Richtlinien prüfen
        if ($e.Key -eq 'P' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
            $controls.btnCheckLapsStatus.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            $e.Handled = $true
        }        
        # Strg+F für Fokus auf Filter
        if ($e.Key -eq 'F' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
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
        
        # Strg+C für Passwort kopieren (nur wenn kein Text markiert ist)
        if ($e.Key -eq 'C' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
            $controls.btnCopyPassword.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            $e.Handled = $true
        }
    })
    
    # Logo Klick (falls URL in INI definiert)
    if ($controls.imgLogo -and $clickURL) {
        $controls.imgLogo.Add_MouseUp({
            param($sender, $e)
            if ($e.ChangedButton -eq 'Left') { Open-URLInBrowser $clickURL }
        })
    }
    if (-not (Test-Path $headerLogoPath)) {
        $controls.imgLogo.Visibility = 'Collapsed'
    }

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
        
        return $script:allComputers | Where-Object { $_ -like "*$filterText*" }
    }
    
    # AD Computerliste laden
    $controls.btnRefreshAdList.Add_Click({
        & $global:UpdateStatus -IsLapsCheck "Lade AD Computerliste..."
        try {
            $script:allComputers = Get-ADComputer -Filter * -Properties Name | Select-Object -ExpandProperty Name | Sort-Object
            $controls.lstAdComputers.ItemsSource = $script:allComputers
            if ($script:allComputers) {
                & $global:UpdateStatus -IsLapsCheck "AD Computerliste geladen ($($script:allComputers.Count) Eintraege)."
            } else {
                & $global:UpdateStatus -IsLapsCheck "Keine Computer in AD gefunden."
            }
        }
        catch {
            & $global:UpdateStatus -IsLapsCheck "Fehler beim Laden der AD Computerliste: $($_.Exception.Message)" "Error"
        }
        
        $filterText = $controls.txtFilter.Text
        # Fix syntax error by explicitly passing the parameter
        $filteredComputers = Invoke-Command -ScriptBlock $FilterComputers -ArgumentList $filterText
        $controls.lstAdComputers.ItemsSource = $filteredComputers
        
        if ([string]::IsNullOrWhiteSpace($filterText)) {
            & $global:UpdateStatus -IsLapsCheck "Filter zurueckgesetzt. Zeige alle $($script:allComputers.Count) Computer."
        } else {
            & $global:UpdateStatus -IsLapsCheck "Filter angewendet - '$filterText'. $($filteredComputers.Count) von $($script:allComputers.Count) Computern werden angezeigt."
        }
    })

    # Register event handler for list selection
    $controls.lstAdComputers.Add_SelectionChanged({
        param($sender, $e)
        
        $selectedComputer = $controls.lstAdComputers.SelectedItem
        if (-not $selectedComputer) { return }
        
        $controls.txtComputerName.Text = $selectedComputer
        
        # Clear previous values
        $controls.txtLapsUser.Text = "Lade..."
        $controls.txtLapsPasswordDisplay.Text = "Lade..."
        $controls.txtPasswordExpiry.Text = "Lade..."
        $controls.txtPasswordLastSet.Text = "Lade..."
        $controls.txtLapsVersion.Text = "Lade..."
        
        try {
            & $global:UpdateStatus -IsLapsCheck "Lese LAPS Passwort fuer $selectedComputer..."
            
            # Use the improved function for LAPS password
            $passwordInfo = Get-LapsPasswordEx -ComputerName $selectedComputer
            
            if ($passwordInfo.Success) {
                $plainPassword = Convert-SecureStringToPlainText -SecureString $passwordInfo.Password
                $controls.txtLapsUser.Text = $passwordInfo.UserName
                $controls.txtLapsPasswordDisplay.Text = $plainPassword
                $controls.txtPasswordExpiry.Text = if ($passwordInfo.PasswordExpiresTimestamp) { $passwordInfo.PasswordExpiresTimestamp.ToString("g") } else { "N/A" }
                $controls.txtPasswordLastSet.Text = if ($passwordInfo.PasswordLastSetTimestamp) { $passwordInfo.PasswordLastSetTimestamp.ToString("g") } else { "N/A" }
                $controls.txtLapsVersion.Text = $passwordInfo.LapsVersion
                & $global:UpdateStatus -IsLapsCheck "LAPS Passwort fuer $selectedComputer erfolgreich gelesen."
            } else {
                $controls.txtLapsUser.Text = "N/A"
                $controls.txtLapsPasswordDisplay.Text = "Passwort nicht verfuegbar."
                $controls.txtPasswordExpiry.Text = "N/A"
                $controls.txtPasswordLastSet.Text = "N/A"
                $controls.txtLapsVersion.Text = "N/A"
                & $global:UpdateStatus -IsLapsCheck "LAPS-Passwort fuer $selectedComputer nicht verfuegbar: $($passwordInfo.ErrorMessage)" "Warning"
            }
        } catch {
            $controls.txtLapsUser.Text = "N/A"
            $controls.txtLapsPasswordDisplay.Text = "LAPS Passwort konnte nicht gelesen werden."
            $controls.txtPasswordExpiry.Text = "N/A"
            $controls.txtPasswordLastSet.Text = "N/A"
            $controls.txtLapsVersion.Text = "N/A"
            & $global:UpdateStatus -IsLapsCheck "Fehler beim Laden der LAPS-Passwort Informationen: $($_.Exception.Message)" "Error"
        }
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
                    # Clear password fields since the new password cannot be read immediately
                    $controls.txtLapsUser.Text = ""
                    $controls.txtLapsPasswordDisplay.Text = "(Passwort wurde zurueckgesetzt)"
                    $controls.txtPasswordExpiry.Text = ""
                    $controls.txtPasswordLastSet.Text = $(Get-Date -Format "g")
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
        $password = $controls.txtLapsPasswordDisplay.Text
        if (-not [string]::IsNullOrWhiteSpace($password) -and $password -notmatch "Fehler|gefunden|zurueckgesetzt") {
            Set-Clipboard -Text $password
            & $global:UpdateStatus -IsLapsCheck "Passwort in die Zwischenablage kopiert."
        } else {
            & $global:UpdateStatus -IsLapsCheck "Kein Passwort zum Kopieren vorhanden." "Warning"
        }
    })

    # Export Selected Computer
    $controls.btnExportSelected.Add_Click({
        $selectedComputer = $controls.lstAdComputers.SelectedItem
        if ($null -eq $selectedComputer) {
            & $global:UpdateStatus -IsLapsCheck "Kein Computer ausgewählt." "Warning"
            [System.Windows.MessageBox]::Show("Bitte wählen Sie einen Computer aus der Liste aus.", "Warnung", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
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
                
                try {
                    $allComputers = $controls.lstAdComputers.Items | ForEach-Object { $_ }
                    $result = Export-LapsPasswordToCsv -FilePath $saveDialog.FileName -ComputerList $allComputers
                    
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
            
            try {
                $allComputers = $controls.lstAdComputers.Items | ForEach-Object { $_ }
                $result = Invoke-LapsPasswordRotation -ComputerList $allComputers
                
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
        }
    })

    # LAPS Client Status & Richtlinien pruefen
    $controls.btnCheckLapsStatus.Add_Click({
        $computer = $env:COMPUTERNAME
        & $global:UpdateStatus -IsLapsCheck "Pruefe LAPS-Status fuer $computer..." "Pruefung"
        
        try {
            # Pruefe, ob LAPS installiert ist
            $lapsInstalled = $false
            $lapsType = ""
            $winLaps = Get-WmiObject -Class Win32_OptionalFeature -Filter "Name='LAPS.Windows' AND InstallState=1" -ErrorAction SilentlyContinue
            if ($winLaps) {
                $lapsInstalled = $true
                $lapsType = "Windows LAPS"
            } elseif (Test-Path "C:\Program Files\LAPS\CSE\Admpwd.dll") {
                $lapsInstalled = $true
                $lapsType = "Legacy LAPS (Admpwd.dll)"
            }
            
            # Aktualisiere die UI basierend auf dem LAPS-Status
            if ($lapsInstalled) {
                $controls.lblLapsInstalledStatus.Text = "$lapsType installiert"
                $controls.ellipseLapsInstalled.Fill = [System.Windows.Media.Brushes]::Green
                & $global:UpdateStatus -IsLapsCheck "$lapsType auf diesem System gefunden. Pruefe GPO..." "Pruefung"
                
                # Pruefe GPO-Einstellungen
                $os = Get-CimInstance -ClassName Win32_OperatingSystem
                $isServer = $os.ProductType -ne 1
                $gpoKey = if ($isServer) { "HKLM:\SOFTWARE\Policies\Microsoft Services\AdmPwd" } else { "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdmPwd" }
                $gpoActive = Test-Path $gpoKey
                
                if ($gpoActive) {
                    $controls.lblGpoStatus.Text = "LAPS GPO aktiv"
                    $controls.ellipseGpoStatus.Fill = [System.Windows.Media.Brushes]::Green
                    $controls.txtPolicyDetails.Text = "LAPS ist korrekt konfiguriert.`nGPO-Pfad: $gpoKey"
                    & $global:UpdateStatus -IsLapsCheck "LAPS GPO auf diesem System gefunden und aktiv." "OK"
                } else {
                    $controls.lblGpoStatus.Text = "Keine LAPS GPO gefunden"
                    $controls.ellipseGpoStatus.Fill = [System.Windows.Media.Brushes]::Red
                    $controls.txtPolicyDetails.Text = "Keine passende LAPS GPO gefunden.`nBitte konfigurieren Sie die LAPS-Gruppenrichtlinie."
                    & $global:UpdateStatus -IsLapsCheck "Keine passende LAPS GPO gefunden. Bitte konfigurieren Sie die LAPS-Gruppenrichtlinie." "Warning"
                }
            } else {
                $controls.lblLapsInstalledStatus.Text = "Nicht installiert"
                $controls.ellipseLapsInstalled.Fill = [System.Windows.Media.Brushes]::Red
                $controls.lblGpoStatus.Text = "Nicht verfügbar"
                $controls.ellipseGpoStatus.Fill = [System.Windows.Media.Brushes]::Gray
                $controls.txtPolicyDetails.Text = "LAPS ist auf diesem System nicht installiert.`nBitte installieren Sie LAPS, um fortzufahren."
                & $global:UpdateStatus -IsLapsCheck "LAPS ist auf diesem System nicht installiert." "Warning"
            }
        } catch {
            $controls.lblLapsInstalledStatus.Text = "Fehler"
            $controls.ellipseLapsInstalled.Fill = [System.Windows.Media.Brushes]::Red
            $controls.lblGpoStatus.Text = "Fehler"
            $controls.ellipseGpoStatus.Fill = [System.Windows.Media.Brushes]::Red
            $controls.txtPolicyDetails.Text = "Fehler beim Überprüfen des LAPS-Status: $($_.Exception.Message)"
            & $global:UpdateStatus -IsLapsCheck "Fehler beim Überprüfen des LAPS-Status: $($_.Exception.Message)" "Error"
        }
    })

    # LAPS Status Check Handler
    $controls.btnCheckLapsStatus.Add_Click({
        & $global:UpdateStatus -IsLapsCheck "Pruefe LAPS-Status des lokalen Systems..." "Pruefung"
    })
    
    # Initiale Prüfung beim Programmstart ausführen
    & $global:UpdateStatus -IsLapsCheck "Pruefe LAPS-Status des lokalen Systems..." "Pruefung"
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $isServer = $os.ProductType -ne 1
        $systemType = if ($isServer) { "Server" } else { "Client" }
        $controls.txtPolicyDetails.Text = "Systemtyp erkannt: $systemType"
        
        # Initialisierung der Variablen
        $lapsInstalled = $false
        $lapsType = ""
        $winLaps = Get-WmiObject -Class Win32_OptionalFeature -Filter "Name='LAPS.Windows' AND InstallState=1" -ErrorAction SilentlyContinue
        if ($winLaps) {
            $lapsInstalled = $true
            $lapsType = "Windows LAPS"
        } elseif (Test-Path "C:\Program Files\LAPS\CSE\Admpwd.dll") {
            $lapsInstalled = $true
            $lapsType = "Legacy LAPS (Admpwd.dll)"
        }
        if ($lapsInstalled) {
            $controls.lblLapsInstalledStatus.Text = "$lapsType installiert"
            $controls.ellipseLapsInstalled.Fill = [System.Windows.Media.Brushes]::Green
            & $global:UpdateStatus -IsLapsCheck "$lapsType auf diesem System gefunden. Pruefe GPO..." "Pruefung"
            $gpoKey = if ($isServer) { "HKLM:\SOFTWARE\Policies\Microsoft Services\AdmPwd" } else { "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdmPwd" }
            $gpoActive = Test-Path $gpoKey
            if ($gpoActive) {
                $controls.lblGpoStatus.Text = "LAPS GPO aktiv"
                $controls.ellipseGpoStatus.Fill = [System.Windows.Media.Brushes]::Green
                $controls.txtPolicyDetails.Text += "`nLAPS GPO wurde gefunden und ist aktiv ($gpoKey)."
                & $global:UpdateStatus -IsLapsCheck "LAPS GPO auf diesem System gefunden." "OK"
            } else {
                $controls.lblGpoStatus.Text = "Keine LAPS GPO gefunden"
                $controls.ellipseGpoStatus.Fill = [System.Windows.Media.Brushes]::Red
                $controls.txtPolicyDetails.Text += "`nKeine passende LAPS GPO gefunden. Weitere Infos auf der Microsoft-Webseite."
                & $global:UpdateStatus -IsLapsCheck "Keine passende LAPS GPO gefunden. Oeffne Microsoft-Webseite..." "Fehler"
                Start-Process "https://learn.microsoft.com/de-de/windows-server/identity/laps/laps-overview"
            }
        } else {
            $controls.lblLapsInstalledStatus.Text = "Nicht installiert"
            $controls.ellipseLapsInstalled.Fill = [System.Windows.Media.Brushes]::Red
            $controls.lblGpoStatus.Text = "Unbekannt"
            $controls.ellipseGpoStatus.Fill = [System.Windows.Media.Brushes]::Gray
            $controls.txtPolicyDetails.Text += "`nLAPS ist auf diesem Computer nicht installiert."
            & $global:UpdateStatus -IsLapsCheck "LAPS ist auf diesem System nicht installiert." "Fehler"
        }
    }
    catch {
        $controls.lblLapsInstalledStatus.Text = "Fehler"
        $controls.ellipseLapsInstalled.Fill = [System.Windows.Media.Brushes]::Red
        $controls.lblGpoStatus.Text = "Fehler"
        $controls.ellipseGpoStatus.Fill = [System.Windows.Media.Brushes]::Red
        $controls.txtPolicyDetails.Text = "Fehler"
        & $global:UpdateStatus -IsLapsCheck "Ausnahme beim Pruefen des LAPS-Status: $($_.Exception.Message)" "Fehler"
    }

    # Update module status label
    if ($ModuleStatus) {
        $moduleStatusText = "Module Status: $($ModuleStatus.LegacyModuleAvailable), $($ModuleStatus.NewModuleAvailable)"
        $controls.lblModuleStatus.Text = $moduleStatusText
    }

    # Fenster anzeigen
    [VOID]$window.ShowDialog()
}

#region Main Script Execution - Hauptskriptausführung
# Set error action preference for the main script block
$ErrorActionPreference = "Stop"

# Initialize Global Log File Path
$global:easyLAPSLogFile = Join-Path -Path $script:ScriptPath -ChildPath "easyLAPS_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

try {
    # Prüfe auf korrekte PowerShell Version (5.1 erforderlich)
    if (-Not $PSVersionTable.PSVersion.ToString().StartsWith("5.1")) {
        $errorMsg = "Windows PowerShell Version 5.1 ist erforderlich!`nAktuelle Version: $($PSVersionTable.PSVersion)"
        Write-Log $errorMsg -Level "ERROR"
        [System.Windows.MessageBox]::Show($errorMsg, "Fehler - Falsche PowerShell Version", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        exit 501
    }
    
    # Prüfe, ob Windows LAPS PowerShell Module verfügbar ist
    if (-Not (Get-Module -Name Laps -ListAvailable)) {
        $errorMsg = "Windows LAPS PowerShell Module nicht gefunden!`n`nBitte installieren Sie das Windows LAPS Feature."
        Write-Log $errorMsg -Level "ERROR"
        [System.Windows.MessageBox]::Show($errorMsg, "Fehler - LAPS Module fehlt", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        exit 502
    }
    
    # Lade erforderliche Assemblies für WPF-Komponenten
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    
    Write-Log "easyLAPS Script gestartet. Logging in: $global:easyLAPSLogFile" -Level "INFO"
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "INFO"
    Write-Log "easyLAPS GUI wird gestartet..." -Level "INFO"

    # Hauptformular anzeigen
    Show-LAPSForm

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