#region ADSync Functions WinRM or PowerShell Remoting
function Start-ADSyncOnRemoteServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ServerName = $null,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceFullSync,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config
    )
    
    Write-Log -Message "Starte AD-Synchronisation..." -Level "INFO"
    
    try {
        # Server aus Konfiguration laden falls nicht angegeben
        if ([string]::IsNullOrWhiteSpace($ServerName)) {
            $ServerName = Get-ConfigValue -Section "ADSync" -Key "ADSyncServer" -DefaultValue $null -Config $Config
            
            if ([string]::IsNullOrWhiteSpace($ServerName)) {
                Write-Log -Message "Kein ADSync-Server in der Konfiguration definiert. Überspringe Synchronisation." -Level "WARN"
                return @{
                    Success = $false
                    Message = "Kein ADSync-Server konfiguriert"
                }
            }
        }
        
        Write-Log -Message "Verbinde mit ADSync-Server: $ServerName" -Level "INFO"
        
        # Test der WinRM-Verbindung
        if (-not (Test-WSMan -ComputerName $ServerName -ErrorAction SilentlyContinue)) {
            Write-Log -Message "WinRM-Verbindung zu $ServerName fehlgeschlagen" -Level "ERROR"
            return @{
                Success = $false
                Message = "Keine WinRM-Verbindung zu $ServerName möglich"
            }
        }
        
        # Bestimme Sync-Typ
        $syncType = if ($ForceFullSync) { "Initial" } else { "Delta" }
        
        # PowerShell-Befehl für ADSync vorbereiten
        $syncCommand = {
            param($SyncType)
            
            try {
                # Importiere ADSync-Modul
                Import-Module ADSync -ErrorAction Stop
                
                # Starte Synchronisation
                if ($SyncType -eq "Initial") {
                    Start-ADSyncSyncCycle -PolicyType Initial
                    $result = "Full synchronization started successfully"
                } else {
                    Start-ADSyncSyncCycle -PolicyType Delta
                    $result = "Delta synchronization started successfully"
                }
                
                return @{
                    Success = $true
                    Message = $result
                    SyncType = $SyncType
                    Timestamp = Get-Date
                }
            }
            catch {
                return @{
                    Success = $false
                    Message = "ADSync-Fehler: $($_.Exception.Message)"
                    SyncType = $SyncType
                    Timestamp = Get-Date
                }
            }
        }
        
        Write-Log -Message "Führe $syncType-Synchronisation auf $ServerName aus..." -Level "INFO"
        
        # Remote-Befehl ausführen
        $result = Invoke-Command -ComputerName $ServerName -ScriptBlock $syncCommand -ArgumentList $syncType -ErrorAction Stop
        
        if ($result.Success) {
            Write-Log -Message "ADSync erfolgreich: $($result.Message)" -Level "INFO"
        } else {
            Write-Log -Message "ADSync fehlgeschlagen: $($result.Message)" -Level "ERROR"
        }
        
        return $result
        
    }
    catch {
        $errorMessage = "Fehler bei der Remote-ADSync-Ausführung: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        return @{
            Success = $false
            Message = $errorMessage
        }
    }
}

function Get-ADSyncStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ServerName = $null,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config
    )
    
    Write-Log -Message "Prüfe ADSync-Status..." -Level "DEBUG"
    
    try {
        # Server aus Konfiguration laden falls nicht angegeben
        if ([string]::IsNullOrWhiteSpace($ServerName)) {
            $ServerName = Get-ConfigValue -Section "ADSync" -Key "ADSyncServer" -DefaultValue $null -Config $Config
            
            if ([string]::IsNullOrWhiteSpace($ServerName)) {
                Write-Log -Message "Kein ADSync-Server konfiguriert" -Level "WARN"
                return $null
            }
        }
        
        # PowerShell-Befehl für Status-Abfrage
        $statusCommand = {
            try {
                Import-Module ADSync -ErrorAction Stop
                
                # Hole aktuelle Sync-Informationen
                $syncStatus = Get-ADSyncScheduler
                $lastSync = Get-ADSyncConnectorRunStatus | Sort-Object StartDate -Descending | Select-Object -First 1
                
                return @{
                    Success = $true
                    SchedulerEnabled = $syncStatus.SyncCycleEnabled
                    NextSyncCycle = $syncStatus.NextSyncCyclePolicyType
                    AllowedSyncCycleInterval = $syncStatus.CustomizedSyncCycleInterval
                    LastSyncResult = $lastSync.Result
                    LastSyncStart = $lastSync.StartDate
                    LastSyncEnd = $lastSync.EndDate
                }
            }
            catch {
                return @{
                    Success = $false
                    Message = "Fehler beim Abrufen des ADSync-Status: $($_.Exception.Message)"
                }
            }
        }
        
        $status = Invoke-Command -ComputerName $ServerName -ScriptBlock $statusCommand -ErrorAction Stop
        
        if ($status.Success) {
            Write-Log -Message "ADSync-Status erfolgreich abgerufen von $ServerName" -Level "DEBUG"
        } else {
            Write-Log -Message "Fehler beim Abrufen des ADSync-Status: $($status.Message)" -Level "WARN"
        }
        
        return $status
        
    }
    catch {
        Write-Log -Message "Fehler bei der Remote-Status-Abfrage: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Test-ADSyncServerConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ServerName = $null,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config
    )
    
    try {
        # Server aus Konfiguration laden falls nicht angegeben
        if ([string]::IsNullOrWhiteSpace($ServerName)) {
            $ServerName = Get-ConfigValue -Section "ADSync" -Key "ADSyncServer" -DefaultValue $null -Config $Config
            
            if ([string]::IsNullOrWhiteSpace($ServerName)) {
                Write-Log -Message "Kein ADSync-Server konfiguriert" -Level "DEBUG"
                return $false
            }
        }
        
        Write-Log -Message "Teste Verbindung zu ADSync-Server: $ServerName" -Level "DEBUG"
        
        # Test WinRM-Verbindung
        $winrmTest = Test-WSMan -ComputerName $ServerName -ErrorAction SilentlyContinue
        if (-not $winrmTest) {
            Write-Log -Message "WinRM-Verbindung zu $ServerName fehlgeschlagen" -Level "WARN"
            return $false
        }
        
        # Test ADSync-Modul Verfügbarkeit
        $moduleTest = Invoke-Command -ComputerName $ServerName -ScriptBlock {
            Get-Module -ListAvailable -Name ADSync
        } -ErrorAction SilentlyContinue
        
        if (-not $moduleTest) {
            Write-Log -Message "ADSync-Modul auf $ServerName nicht verfügbar" -Level "WARN"
            return $false
        }
        
        Write-Log -Message "ADSync-Server-Verbindung erfolgreich getestet" -Level "DEBUG"
        return $true
        
    }
    catch {
        Write-Log -Message "Fehler beim Testen der ADSync-Server-Verbindung: $($_.Exception.Message)" -Level "WARN"
        return $false
    }
}

function Invoke-PostUserCreationADSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$WaitForCompletion,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutMinutes = 10
    )
    
    Write-Log -Message "Starte Post-User-Creation ADSync..." -Level "INFO"
    
    try {
        # Prüfe ob ADSync aktiviert ist
        $adSyncEnabled = Get-ConfigValue -Section "ADSync" -Key "EnableAutoSync" -DefaultValue $false
        
        if (-not $adSyncEnabled) {
            Write-Log -Message "Automatische ADSync ist deaktiviert" -Level "INFO"
            return @{
                Success = $true
                Message = "ADSync übersprungen (deaktiviert)"
            }
        }
        
        # Teste Verbindung zum ADSync-Server
        if (-not (Test-ADSyncServerConnection)) {
            Write-Log -Message "ADSync-Server nicht erreichbar - überspringe Synchronisation" -Level "WARN"
            return @{
                Success = $false
                Message = "ADSync-Server nicht erreichbar"
            }
        }
        
        # Starte Delta-Synchronisation
        $syncResult = Start-ADSyncOnRemoteServer -ForceFullSync:$false
        
        if (-not $syncResult.Success) {
            return $syncResult
        }
        
        # Warte auf Completion wenn gewünscht
        if ($WaitForCompletion) {
            Write-Log -Message "Warte auf Abschluss der ADSync (max. $TimeoutMinutes Minuten)..." -Level "INFO"
            
            $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
            $completed = $false
            
            while ((Get-Date) -lt $timeout -and -not $completed) {
                Start-Sleep -Seconds 30
                
                $status = Get-ADSyncStatus
                if ($status -and $status.Success) {
                    # Prüfe ob Sync abgeschlossen ist (vereinfachte Logik)
                    if ($status.LastSyncEnd -gt $status.LastSyncStart) {
                        $completed = $true
                        Write-Log -Message "ADSync erfolgreich abgeschlossen" -Level "INFO"
                    }
                }
            }
            
            if (-not $completed) {
                Write-Log -Message "Timeout beim Warten auf ADSync-Abschluss" -Level "WARN"
            }
        }
        
        return $syncResult
        
    }
    catch {
        $errorMessage = "Fehler bei Post-User-Creation ADSync: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        return @{
            Success = $false
            Message = $errorMessage
        }
    }
}

#endregion