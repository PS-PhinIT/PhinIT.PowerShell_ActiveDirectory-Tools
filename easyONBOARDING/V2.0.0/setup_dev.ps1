param(
    [switch]$WithDevDependencies,
    [switch]$CheckOnly,
    [switch]$PrepareOfflineCache,
    [switch]$OfflineOnly,
    [bool]$InstallMissingRequiredComponents = $true,
    [bool]$InstallOptionalComponents = $false,
    [switch]$AllowUnsupportedPythonVersion,
    [string]$InstallerCacheDir = "$env:TEMP\easyonb-v2-setup",
    [string]$OfflineCacheRoot = '',
    [string]$ComponentLogRoot = '',
    [string]$SetupStatePath = '',
    [string[]]$PythonVersionCandidates = @('3.13.5', '3.13.4', '3.13.3', '3.13.2', '3.13.1', '3.13.0'),
    [string]$PythonInstallerUrl = '',
    [string]$PythonInstallerPath = '',
    [string]$UrlRewriteInstallerUrl = 'https://download.microsoft.com/download/D/D/9/DD9A82C0-1D98-4C6E-A283-AB3A21A9EF57/rewrite_amd64_en-US.msi',
    [string]$UrlRewriteInstallerPath = '',
    [string]$ArrInstallerUrl = '',
    [string]$ArrInstallerPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
try { [Console]::InputEncoding = $utf8NoBom } catch {}
try { [Console]::OutputEncoding = $utf8NoBom } catch {}
try { $OutputEncoding = $utf8NoBom } catch {}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($OfflineCacheRoot)) {
    $OfflineCacheRoot = Join-Path $projectRoot 'setup-cache'
}
if ([string]::IsNullOrWhiteSpace($ComponentLogRoot)) {
    $ComponentLogRoot = Join-Path $projectRoot 'logs\setup'
}
if ([string]::IsNullOrWhiteSpace($SetupStatePath)) {
    $SetupStatePath = Join-Path $ComponentLogRoot 'setup-state.json'
}

Push-Location $projectRoot

try {
    $script:SetupState = $null
    $script:ResumeDetected = $false
    $script:CurrentLogSessionDir = $null

    function Write-Section {
        param([string]$Message)

        Write-Host ""
        Write-Host "==> $Message" -ForegroundColor Cyan
    }

    function Write-Detail {
        param(
            [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')]
            [string]$Level,
            [string]$Message
        )

        $color = switch ($Level) {
            'OK' { 'Green' }
            'WARN' { 'Yellow' }
            'ERROR' { 'Red' }
            default { 'Gray' }
        }

        Write-Host "[$Level] $Message" -ForegroundColor $color
    }

    function Test-IsAdministrator {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Test-CommandAvailable {
        param([string]$CommandName)

        return [bool](Get-Command -Name $CommandName -ErrorAction SilentlyContinue)
    }

    function New-ComponentStatus {
        param(
            [ValidateSet('OK', 'WARN', 'MISSING', 'INFO', 'OPTIONAL')]
            [string]$Status,
            [string]$Component,
            [string]$Purpose,
            [string]$Detail,
            [bool]$Required,
            [bool]$Present,
            [bool]$AutoInstallable = $false,
            [string]$InstallName = ''
        )

        [pscustomobject]@{
            Scope           = if ($Required) { 'Pflicht' } else { 'Optional' }
            Status          = $Status
            Component       = $Component
            Purpose         = $Purpose
            Detail          = $Detail
            Present         = $Present
            AutoInstallable = $AutoInstallable
            InstallName     = $InstallName
        }
    }

    function Show-StatusTable {
        param([object[]]$Statuses)

        $Statuses |
            Select-Object Scope, Status, Component, Detail |
            Format-Table -Wrap -AutoSize |
            Out-Host
    }

    function Show-RequiredStatusSummary {
        param([object[]]$Statuses)

        $missingRequired = $Statuses | Where-Object { $_.Scope -eq 'Pflicht' -and $_.Status -eq 'MISSING' }
        $warningRequired = $Statuses | Where-Object { $_.Scope -eq 'Pflicht' -and $_.Status -eq 'WARN' }

        if ($missingRequired) {
            Write-Detail -Level 'WARN' -Message ('Pflichtkomponenten mit Luecken: ' + (($missingRequired | Select-Object -ExpandProperty Component) -join ', '))
        }

        if ($warningRequired) {
            Write-Detail -Level 'WARN' -Message ('Pflichtkomponenten mit Hinweisen: ' + (($warningRequired | Select-Object -ExpandProperty Component) -join ', '))
        }
    }

    function New-DirectoryIfMissing {
        param([string]$Path)

        if (-not (Test-Path -Path $Path)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
    }

    function ConvertTo-SafeFileName {
        param([string]$Value)

        if ([string]::IsNullOrWhiteSpace($Value)) {
            return 'unnamed'
        }

        $safeValue = $Value
        foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
            $safeValue = $safeValue.Replace($invalidChar, '-')
        }

        $safeValue = $safeValue -replace '\s+', '-'
        $safeValue = $safeValue -replace '-{2,}', '-'
        $safeValue = $safeValue.Trim('-')
        if ([string]::IsNullOrWhiteSpace($safeValue)) {
            return 'unnamed'
        }

        return $safeValue
    }

    function Get-UtcTimestamp {
        return (Get-Date).ToUniversalTime().ToString('o')
    }

    function New-SetupStateObject {
        [pscustomobject]@{
            SchemaVersion        = 1
            RunId                = 'setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
            CreatedUtc           = Get-UtcTimestamp
            UpdatedUtc           = Get-UtcTimestamp
            LastPhase            = 'initial'
            PendingReboot        = $false
            PendingRebootReasons = @()
            ResumeRecommended    = $false
            CompletedActions     = @()
            Notes                = @()
            ComponentLogs        = @()
        }
    }

    function Set-StatePropertyDefault {
        param(
            [psobject]$Object,
            [string]$PropertyName,
            $DefaultValue
        )

        $property = $Object.PSObject.Properties[$PropertyName]
        if ($null -eq $property) {
            Add-Member -InputObject $Object -MemberType NoteProperty -Name $PropertyName -Value $DefaultValue
            return
        }

        if ($null -eq $property.Value) {
            $Object.$PropertyName = $DefaultValue
        }
    }

    function Set-SetupStateDefaults {
        param([psobject]$State)

        Set-StatePropertyDefault -Object $State -PropertyName 'SchemaVersion' -DefaultValue 1
        Set-StatePropertyDefault -Object $State -PropertyName 'RunId' -DefaultValue ('setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Set-StatePropertyDefault -Object $State -PropertyName 'CreatedUtc' -DefaultValue (Get-UtcTimestamp)
        Set-StatePropertyDefault -Object $State -PropertyName 'UpdatedUtc' -DefaultValue (Get-UtcTimestamp)
        Set-StatePropertyDefault -Object $State -PropertyName 'LastPhase' -DefaultValue 'initial'
        Set-StatePropertyDefault -Object $State -PropertyName 'PendingReboot' -DefaultValue $false
        Set-StatePropertyDefault -Object $State -PropertyName 'PendingRebootReasons' -DefaultValue @()
        Set-StatePropertyDefault -Object $State -PropertyName 'ResumeRecommended' -DefaultValue $false
        Set-StatePropertyDefault -Object $State -PropertyName 'CompletedActions' -DefaultValue @()
        Set-StatePropertyDefault -Object $State -PropertyName 'Notes' -DefaultValue @()
        Set-StatePropertyDefault -Object $State -PropertyName 'ComponentLogs' -DefaultValue @()

        $State.PendingRebootReasons = @($State.PendingRebootReasons)
        $State.CompletedActions = @($State.CompletedActions)
        $State.Notes = @($State.Notes)
        $State.ComponentLogs = @($State.ComponentLogs)
        return $State
    }

    function Get-SetupStateObject {
        if (Test-Path -Path $SetupStatePath) {
            try {
                $loadedState = Get-Content -Path $SetupStatePath -Raw | ConvertFrom-Json
                $script:ResumeDetected = $true
                return Set-SetupStateDefaults -State $loadedState
            }
            catch {
                Write-Detail -Level 'WARN' -Message "Bestehende Setup-State-Datei ist unlesbar und wird neu aufgebaut: $($_.Exception.Message)"
            }
        }

        $script:ResumeDetected = $false
        return New-SetupStateObject
    }

    function Save-SetupState {
        param([psobject]$State)

        $State.UpdatedUtc = Get-UtcTimestamp
        $stateDirectory = Split-Path -Parent $SetupStatePath
        if (-not [string]::IsNullOrWhiteSpace($stateDirectory)) {
            New-DirectoryIfMissing -Path $stateDirectory
        }

        $State | ConvertTo-Json -Depth 12 | Set-Content -Path $SetupStatePath -Encoding UTF8
    }

    function Add-SetupCompletedAction {
        param([string]$Action)

        if ([string]::IsNullOrWhiteSpace($Action)) {
            return
        }

        $completedActions = @($script:SetupState.CompletedActions)
        if ($completedActions -notcontains $Action) {
            $script:SetupState.CompletedActions = $completedActions + $Action
            Save-SetupState -State $script:SetupState
        }
    }

    function Add-SetupNote {
        param([string]$Note)

        if ([string]::IsNullOrWhiteSpace($Note)) {
            return
        }

        $notes = @($script:SetupState.Notes)
        $script:SetupState.Notes = $notes + $Note
        Save-SetupState -State $script:SetupState
    }

    function Add-SetupComponentLog {
        param([psobject]$Entry)

        $componentLogs = @($script:SetupState.ComponentLogs)
        $script:SetupState.ComponentLogs = $componentLogs + $Entry
        Save-SetupState -State $script:SetupState
    }

    function Set-SetupPhase {
        param([string]$Phase)

        $script:SetupState.LastPhase = $Phase
        Save-SetupState -State $script:SetupState
    }

    function Set-SetupRebootPending {
        param([string[]]$Reasons)

        $script:SetupState.PendingReboot = $true
        $script:SetupState.ResumeRecommended = $true
        $script:SetupState.PendingRebootReasons = @($Reasons | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
        Save-SetupState -State $script:SetupState
    }

    function Clear-SetupRebootPending {
        $script:SetupState.PendingReboot = $false
        $script:SetupState.ResumeRecommended = $false
        $script:SetupState.PendingRebootReasons = @()
        Save-SetupState -State $script:SetupState
    }

    function Clear-SetupStateFile {
        if (Test-Path -Path $SetupStatePath) {
            Remove-Item -Path $SetupStatePath -Force
        }
    }

    function Start-SetupSession {
        if ($null -ne $script:SetupState) {
            return
        }

        New-DirectoryIfMissing -Path $ComponentLogRoot
        New-DirectoryIfMissing -Path $OfflineCacheRoot

        $script:SetupState = Get-SetupStateObject
        $script:CurrentLogSessionDir = Join-Path $ComponentLogRoot $script:SetupState.RunId
        New-DirectoryIfMissing -Path $script:CurrentLogSessionDir
        Save-SetupState -State $script:SetupState

        if ($script:ResumeDetected) {
            Write-Detail -Level 'INFO' -Message "Fortsetzung erkannt. Vorhandene State-Datei: $SetupStatePath"
            Write-Detail -Level 'INFO' -Message "Letzte Phase laut State-Datei: $($script:SetupState.LastPhase)"
        }
    }

    function New-ComponentLogContext {
        param(
            [string]$Component,
            [string]$Action
        )

        Start-SetupSession

        $componentDirectory = Join-Path $script:CurrentLogSessionDir (ConvertTo-SafeFileName -Value $Component)
        New-DirectoryIfMissing -Path $componentDirectory

        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $actionFileName = ConvertTo-SafeFileName -Value $Action
        $basePath = Join-Path $componentDirectory "$timestamp-$actionFileName"

        $context = [pscustomobject]@{
            Component    = $Component
            Action       = $Action
            LogPath      = "$basePath.log"
            MetadataPath = "$basePath.json"
            StartedUtc   = Get-UtcTimestamp
        }

        "[$($context.StartedUtc)][INFO] Start $Component :: $Action" | Set-Content -Path $context.LogPath -Encoding UTF8
        return $context
    }

    function Write-ComponentLogEntry {
        param(
            [psobject]$Context,
            [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')]
            [string]$Level,
            [string]$Message
        )

        if ($null -eq $Context) {
            return
        }

        $line = "[$(Get-UtcTimestamp)][$Level] $Message"
        Add-Content -Path $Context.LogPath -Value $line -Encoding UTF8
    }

    function Complete-ComponentLog {
        param(
            [psobject]$Context,
            [ValidateSet('success', 'warning', 'error', 'skipped')]
            [string]$Outcome,
            [int]$ExitCode = 0,
            [string[]]$AdditionalFiles = @(),
            [string[]]$Notes = @()
        )

        if ($null -eq $Context) {
            return
        }

        $metadata = [pscustomobject]@{
            Component       = $Context.Component
            Action          = $Context.Action
            Outcome         = $Outcome
            ExitCode        = $ExitCode
            StartedUtc      = $Context.StartedUtc
            FinishedUtc     = Get-UtcTimestamp
            LogPath         = $Context.LogPath
            MetadataPath    = $Context.MetadataPath
            AdditionalFiles = @($AdditionalFiles)
            Notes           = @($Notes)
        }

        $metadata | ConvertTo-Json -Depth 8 | Set-Content -Path $Context.MetadataPath -Encoding UTF8
        Add-SetupComponentLog -Entry $metadata
    }

    function Get-PendingRebootState {
        $reasons = @()

        if (Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
            $reasons += 'ComponentBasedServicing:RebootPending'
        }

        if (Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
            $reasons += 'WindowsUpdate:RebootRequired'
        }

        try {
            $sessionManager = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction Stop
            if ($null -ne $sessionManager.PendingFileRenameOperations) {
                $reasons += 'SessionManager:PendingFileRenameOperations'
            }
        }
        catch {
        }

        [pscustomobject]@{
            IsPending = ($reasons.Count -gt 0)
            Reasons   = $reasons
        }
    }

    function Stop-ForPendingReboot {
        param(
            [string]$Phase,
            [string[]]$Reasons
        )

        Start-SetupSession
        Set-SetupPhase -Phase $Phase
        Set-SetupRebootPending -Reasons $Reasons
        Write-Detail -Level 'WARN' -Message ('Neustart erforderlich oder ausstehend: ' + (($Reasons | Sort-Object -Unique) -join ', '))
        Write-Detail -Level 'WARN' -Message "Nach dem Reboot dieses Skript erneut aufrufen. Die Fortsetzung erfolgt automatisch ueber $SetupStatePath."
        return $true
    }

    function Get-InstalledPrograms {
        $existingCache = Get-Variable -Name InstalledProgramsCache -Scope Script -ErrorAction SilentlyContinue
        if ($existingCache) {
            return $script:InstalledProgramsCache
        }

        $registryPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )

        $script:InstalledProgramsCache = foreach ($path in $registryPaths) {
            Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
                Where-Object {
                    $null -ne $_.PSObject.Properties['DisplayName'] -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.DisplayName)
                }
        }

        return $script:InstalledProgramsCache
    }

    function Find-InstalledProgram {
        param([string[]]$Patterns)

        $programs = Get-InstalledPrograms
        foreach ($pattern in $Patterns) {
            $match = $programs | Where-Object { $_.DisplayName -like $pattern } | Select-Object -First 1
            if ($match) {
                return $match
            }
        }

        return $null
    }

    function Get-WindowsServerBaselineStatus {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $buildNumber = [int]$os.BuildNumber
        $isServer = $os.ProductType -eq 3

        $serverProfile = switch ($buildNumber) {
            14393 { 'Windows Server 2016' }
            17763 { 'Windows Server 2019' }
            20348 { 'Windows Server 2022' }
            default { $null }
        }

        if ($isServer -and $serverProfile) {
            $preferredNote = if ($buildNumber -in 17763, 20348) {
                'Bevorzugtes Standardprofil erkannt.'
            }
            else {
                'Unterstuetzt, aber 2019/2022 sind als Standardprofil bevorzugt.'
            }

            return New-ComponentStatus -Status 'OK' -Component 'Windows Server Basisprofil' -Purpose 'Betrieb der V2-Management-Server-Rolle auf Windows Server 2016/2019/2022.' -Detail "$($os.Caption) (Build $buildNumber). $preferredNote" -Required $true -Present $true
        }

        return New-ComponentStatus -Status 'WARN' -Component 'Windows Server Basisprofil' -Purpose 'Betrieb der V2-Management-Server-Rolle auf Windows Server 2016/2019/2022.' -Detail "Erkannt: $($os.Caption) (Build $buildNumber). Fuer den Management Server sind Windows Server 2016/2019/2022 vorgesehen; 2019 oder 2022 werden bevorzugt." -Required $true -Present $false
    }

    function Get-WindowsFeatureStatus {
        param(
            [string]$FeatureName,
            [string]$Component,
            [string]$Purpose,
            [bool]$Required
        )

        if (-not (Test-CommandAvailable -CommandName 'Get-WindowsFeature')) {
            return New-ComponentStatus -Status 'INFO' -Component $Component -Purpose $Purpose -Detail 'Featurestatus konnte nicht automatisch geprueft werden, da Get-WindowsFeature nicht verfuegbar ist.' -Required $Required -Present $false -AutoInstallable $true -InstallName $FeatureName
        }

        try {
            $feature = Get-WindowsFeature -Name $FeatureName -ErrorAction Stop
        }
        catch {
            return New-ComponentStatus -Status 'INFO' -Component $Component -Purpose $Purpose -Detail "Featurestatus konnte auf diesem Host nicht automatisch ausgewertet werden: $($_.Exception.Message)" -Required $Required -Present $false -AutoInstallable $true -InstallName $FeatureName
        }

        if (-not $feature) {
            return New-ComponentStatus -Status 'INFO' -Component $Component -Purpose $Purpose -Detail "Das Feature '$FeatureName' wurde auf diesem System nicht gefunden oder kann hier nicht ausgewertet werden." -Required $Required -Present $false -AutoInstallable $true -InstallName $FeatureName
        }

        if ($feature.Installed) {
            return New-ComponentStatus -Status 'OK' -Component $Component -Purpose $Purpose -Detail "Windows-Feature '$FeatureName' ist installiert." -Required $Required -Present $true -AutoInstallable $true -InstallName $FeatureName
        }

        $status = if ($Required) { 'MISSING' } else { 'OPTIONAL' }
        return New-ComponentStatus -Status $status -Component $Component -Purpose $Purpose -Detail "Windows-Feature '$FeatureName' ist aktuell nicht installiert." -Required $Required -Present $false -AutoInstallable $true -InstallName $FeatureName
    }

    function Get-IisAddOnStatus {
        param(
            [string]$Component,
            [string]$Purpose,
            [bool]$Required,
            [string[]]$DisplayNamePatterns,
            [string[]]$ProbePaths
        )

        $program = Find-InstalledProgram -Patterns $DisplayNamePatterns
        if ($program) {
            return New-ComponentStatus -Status 'OK' -Component $Component -Purpose $Purpose -Detail "$($program.DisplayName) erkannt." -Required $Required -Present $true
        }

        foreach ($path in $ProbePaths) {
            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }

            if (Test-Path -Path $path) {
                return New-ComponentStatus -Status 'OK' -Component $Component -Purpose $Purpose -Detail "Komponente ueber Dateipfad erkannt: $path" -Required $Required -Present $true
            }
        }

        $status = if ($Required) { 'MISSING' } else { 'OPTIONAL' }
        return New-ComponentStatus -Status $status -Component $Component -Purpose $Purpose -Detail 'Nicht automatisch erkannt. Installation bzw. Pruefung ueber Setup/Installer empfohlen.' -Required $Required -Present $false
    }

    function Invoke-PythonProbe {
        param([hashtable]$Candidate)

        if ($Candidate.Type -eq 'Command' -and (-not (Test-CommandAvailable -CommandName $Candidate.FilePath))) {
            return $null
        }

        if ($Candidate.Type -eq 'Path' -and (-not (Test-Path -Path $Candidate.FilePath))) {
            return $null
        }

        try {
            $pythonProbeArgs = @()
            $pythonProbeArgs += $Candidate.Arguments
            $pythonProbeArgs += '-c'
            $pythonProbeArgs += 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}|{sys.executable}")'
            $versionInfo = & $Candidate.FilePath @pythonProbeArgs 2>$null
            if (-not $versionInfo) {
                return $null
            }

            $parts = $versionInfo -split '\|', 2
            $version = [version]$parts[0]
            $executable = if ($parts.Count -gt 1) { $parts[1] } else { '' }
            return [pscustomobject]@{
                FilePath       = $Candidate.FilePath
                Arguments      = $Candidate.Arguments
                Label          = $Candidate.Label
                Version        = $version
                Executable     = $executable
                IsTargetPython = ($version.Major -eq 3 -and $version.Minor -eq 13)
            }
        }
        catch {
            return $null
        }
    }

    function Get-PythonRuntimeStatus {
        $candidateList = @(
            @{ Type = 'Command'; FilePath = 'py'; Arguments = @('-3.13'); Label = 'py -3.13' },
            @{ Type = 'Command'; FilePath = 'python'; Arguments = @(); Label = 'python' },
            @{ Type = 'Command'; FilePath = 'python3.13'; Arguments = @(); Label = 'python3.13' },
            @{ Type = 'Path'; FilePath = (Join-Path $env:ProgramFiles 'Python313\python.exe'); Arguments = @(); Label = 'ProgramFiles Python313' },
            @{ Type = 'Path'; FilePath = (Join-Path $env:LocalAppData 'Programs\Python\Python313\python.exe'); Arguments = @(); Label = 'LocalAppData Python313' },
            @{ Type = 'Path'; FilePath = 'C:\Python313\python.exe'; Arguments = @(); Label = 'C:\Python313\python.exe' }
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_.FilePath) }

        $discovered = foreach ($candidate in $candidateList) {
            $probe = Invoke-PythonProbe -Candidate $candidate
            if ($probe) {
                $probe
            }
        }

        $selected = $discovered | Where-Object { $_.IsTargetPython } | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $selected) {
            $selected = $discovered | Sort-Object Version -Descending | Select-Object -First 1
        }

        if (-not $selected) {
            return [pscustomobject]@{
                Status = (New-ComponentStatus -Status 'MISSING' -Component 'Python 3.13.x' -Purpose 'Laufzeit fuer FastAPI, API, Jobs und Orchestrierung.' -Detail 'Kein nutzbarer Python-Interpreter gefunden. Fuer V2 ist Python 3.13.x als Pflicht vorgesehen.' -Required $true -Present $false)
                SelectedRuntime = $null
            }
        }

        $detail = "Erkannt ueber '$($selected.Label)' mit Version $($selected.Version) ($($selected.Executable))."
        $status = if ($selected.IsTargetPython) { 'OK' } else { 'WARN' }
        if (-not $selected.IsTargetPython) {
            $detail += ' Projektziel ist Python 3.13.x.'
        }

        return [pscustomobject]@{
            Status = (New-ComponentStatus -Status $status -Component 'Python 3.13.x' -Purpose 'Laufzeit fuer FastAPI, API, Jobs und Orchestrierung.' -Detail $detail -Required $true -Present $selected.IsTargetPython)
            SelectedRuntime = $selected
        }
    }

    function Get-PowerShell51Status {
        $powershellPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -Path $powershellPath)) {
            return New-ComponentStatus -Status 'MISSING' -Component 'Windows PowerShell 5.1' -Purpose 'Kernautomation, Windows-Administration und AD-nahe PowerShell-Aktionen.' -Detail 'powershell.exe wurde nicht unter dem Standardpfad gefunden.' -Required $true -Present $false
        }

        $version = & $powershellPath -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
        $is51 = $version -like '5.1*'
        $status = if ($is51) { 'OK' } else { 'WARN' }
        return New-ComponentStatus -Status $status -Component 'Windows PowerShell 5.1' -Purpose 'Kernautomation, Windows-Administration und AD-nahe PowerShell-Aktionen.' -Detail "Erkannt: Version $version unter $powershellPath." -Required $true -Present $is51
    }

    function Get-DotNetFrameworkStatus {
        $release = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue
        if ($null -eq $release) {
            return New-ComponentStatus -Status 'WARN' -Component '.NET Framework' -Purpose 'Windows-Komponenten laut Serverstandard und relevante Abhaengigkeiten.' -Detail 'Kein .NET Framework Full Release-Wert gefunden.' -Required $true -Present $false -AutoInstallable $true -InstallName 'NET-Framework-45-Core'
        }

        return New-ComponentStatus -Status 'OK' -Component '.NET Framework' -Purpose 'Windows-Komponenten laut Serverstandard und relevante Abhaengigkeiten.' -Detail "Erkannter Release-Wert: $release." -Required $true -Present $true -AutoInstallable $true -InstallName 'NET-Framework-45-Core'
    }

    function Get-ModulePresenceStatus {
        param(
            [string]$Component,
            [string]$Purpose,
            [bool]$Required,
            [string[]]$ModuleNames
        )

        $foundModules = foreach ($moduleName in $ModuleNames) {
            if (Get-Module -ListAvailable -Name $moduleName) {
                $moduleName
            }
        }

        if ($foundModules) {
            $detailText = 'Erkannt: ' + (($foundModules | Sort-Object -Unique) -join ', ')
            return New-ComponentStatus -Status 'OK' -Component $Component -Purpose $Purpose -Detail $detailText -Required $Required -Present $true
        }

        $status = if ($Required) { 'MISSING' } else { 'OPTIONAL' }
        return New-ComponentStatus -Status $status -Component $Component -Purpose $Purpose -Detail 'Aktuell nicht erkannt.' -Required $Required -Present $false
    }

    function Get-CommandPresenceStatus {
        param(
            [string]$Component,
            [string]$Purpose,
            [bool]$Required,
            [string[]]$CommandNames
        )

        $foundCommands = foreach ($commandName in $CommandNames) {
            if (Test-CommandAvailable -CommandName $commandName) {
                $commandName
            }
        }

        if ($foundCommands) {
            $detailText = 'Erkannt: ' + (($foundCommands | Sort-Object -Unique) -join ', ')
            return New-ComponentStatus -Status 'OK' -Component $Component -Purpose $Purpose -Detail $detailText -Required $Required -Present $true
        }

        $status = if ($Required) { 'MISSING' } else { 'OPTIONAL' }
        return New-ComponentStatus -Status $status -Component $Component -Purpose $Purpose -Detail 'Aktuell nicht erkannt.' -Required $Required -Present $false
    }

    function Get-SqlServerStatus {
        $services = Get-Service -Name 'MSSQL*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        if ($services) {
            return New-ComponentStatus -Status 'OK' -Component 'SQL Server Express oder Standard' -Purpose 'Persistenz fuer produktionsnahe Betriebsmodelle; SQLite reicht fuer Pilot und Test.' -Detail ('Erkannte SQL-Dienste: ' + ($services -join ', ')) -Required $false -Present $true
        }

        return New-ComponentStatus -Status 'OPTIONAL' -Component 'SQL Server Express oder Standard' -Purpose 'Persistenz fuer produktionsnahe Betriebsmodelle; SQLite reicht fuer Pilot und Test.' -Detail 'Nicht erkannt. Fuer reine Test- oder Pilotlaeufe ist SQLite weiterhin ausreichend.' -Required $false -Present $false
    }

    function Get-ExchangeManagementToolsStatus {
        $exchangeProgram = Find-InstalledProgram -Patterns @('*Exchange*Management*Tools*', '*Microsoft Exchange Server*')
        $exchangePath = 'C:\Program Files\Microsoft\Exchange Server\V15\Bin\RemoteExchange.ps1'

        if ($exchangeProgram) {
            return New-ComponentStatus -Status 'OK' -Component 'Exchange Management Tools' -Purpose 'Verwaltung von Exchange On-Premises oder Hybrid-Szenarien.' -Detail "$($exchangeProgram.DisplayName) erkannt." -Required $false -Present $true
        }

        if (Test-Path -Path $exchangePath) {
            return New-ComponentStatus -Status 'OK' -Component 'Exchange Management Tools' -Purpose 'Verwaltung von Exchange On-Premises oder Hybrid-Szenarien.' -Detail "Exchange Management Shell-Dateipfad erkannt: $exchangePath" -Required $false -Present $true
        }

        return New-ComponentStatus -Status 'OPTIONAL' -Component 'Exchange Management Tools' -Purpose 'Verwaltung von Exchange On-Premises oder Hybrid-Szenarien.' -Detail 'Nicht erkannt. Nur erforderlich, wenn Exchange On-Premises oder Hybrid administriert werden soll.' -Required $false -Present $false
    }

    function Get-CloudModulesStatus {
        $moduleNames = @('Microsoft.Graph.Authentication', 'MicrosoftTeams', 'PnP.PowerShell')
        $available = foreach ($moduleName in $moduleNames) {
            if (Get-Module -ListAvailable -Name $moduleName) {
                $moduleName
            }
        }
        $missing = $moduleNames | Where-Object { $_ -notin $available }

        if ($available) {
            $detail = 'Vorhanden: ' + ($available -join ', ')
            if ($missing) {
                $detail += '; fehlend: ' + ($missing -join ', ')
            }

            return New-ComponentStatus -Status 'OK' -Component 'Microsoft Cloud-Module' -Purpose 'Graph-, Teams- und SharePoint-/PnP-Erweiterungen abhaengig von den aktivierten M365-Features.' -Detail $detail -Required $false -Present $true
        }

        return New-ComponentStatus -Status 'OPTIONAL' -Component 'Microsoft Cloud-Module' -Purpose 'Graph-, Teams- und SharePoint-/PnP-Erweiterungen abhaengig von den aktivierten M365-Features.' -Detail 'Noch keine typischen Cloud-Module erkannt.' -Required $false -Present $false
    }

    function Get-PdfRenderingToolsStatus {
        $commandNames = @('wkhtmltopdf', 'weasyprint', 'playwright')
        $foundTools = foreach ($commandName in $commandNames) {
            if (Test-CommandAvailable -CommandName $commandName) {
                $commandName
            }
        }

        if ($foundTools) {
            return New-ComponentStatus -Status 'OK' -Component 'PDF-Rendering-Tools' -Purpose 'Serverseitige PDF-Generierung fuer Reports und Dokumente.' -Detail ('Erkannt: ' + ($foundTools -join ', ')) -Required $false -Present $true
        }

        return New-ComponentStatus -Status 'OPTIONAL' -Component 'PDF-Rendering-Tools' -Purpose 'Serverseitige PDF-Generierung fuer Reports und Dokumente.' -Detail 'Noch kein typisches Tool wie wkhtmltopdf, WeasyPrint oder Playwright erkannt.' -Required $false -Present $false
    }

    function Get-SetupStatus {
        $pythonRuntime = Get-PythonRuntimeStatus
        $statuses = @(
            (Get-WindowsServerBaselineStatus)
            (Get-WindowsFeatureStatus -FeatureName 'Web-Server' -Component 'IIS Web Server' -Purpose 'Front Door und TLS-Terminierung.' -Required $true)
            (Get-WindowsFeatureStatus -FeatureName 'Web-Windows-Auth' -Component 'IIS Windows Authentication' -Purpose 'Rollenbasierter Login der Administratoren.' -Required $true)
            (Get-IisAddOnStatus -Component 'IIS URL Rewrite' -Purpose 'Routing und Weiterleitung an die Python-Applikation.' -Required $true -DisplayNamePatterns @('*IIS URL Rewrite*') -ProbePaths @("$env:ProgramFiles\IIS\URL Rewrite\rewrite.dll", "${env:ProgramFiles(x86)}\IIS\URL Rewrite\rewrite.dll"))
            $pythonRuntime.Status
            (Get-PowerShell51Status)
            (Get-WindowsFeatureStatus -FeatureName 'RSAT-AD-Tools' -Component 'RSAT Active Directory Tools' -Purpose 'PowerShell-basierte Active Directory-Funktionen.' -Required $true)
            (Get-ModulePresenceStatus -Component 'ActiveDirectory PowerShell-Modul' -Purpose 'Direkter Nachweis fuer AD-nahe Skriptausfuehrung.' -Required $true -ModuleNames @('ActiveDirectory'))
            (Get-DotNetFrameworkStatus)
            (Get-IisAddOnStatus -Component 'IIS Application Request Routing (ARR)' -Purpose 'Empfohlene Reverse-Proxy-Konfiguration auf den lokalen Python-Port.' -Required $false -DisplayNamePatterns @('*Application Request Routing*', '*ARR*') -ProbePaths @("$env:ProgramFiles\IIS\Microsoft Application Request Routing", "${env:ProgramFiles(x86)}\IIS\Microsoft Application Request Routing"))
            (Get-SqlServerStatus)
            (Get-CommandPresenceStatus -Component 'PowerShell 7.x' -Purpose 'Zusatzpfad fuer moderne API-Connectoren und REST-Aufrufe.' -Required $false -CommandNames @('pwsh'))
            (Get-ExchangeManagementToolsStatus)
            (Get-CloudModulesStatus)
            (Get-PdfRenderingToolsStatus)
        )

        [pscustomobject]@{
            Statuses      = $statuses
            PythonRuntime = $pythonRuntime.SelectedRuntime
        }
    }

    function Get-PythonInstallerUrls {
        $pythonUrls = @()
        if (-not [string]::IsNullOrWhiteSpace($PythonInstallerUrl)) {
            $pythonUrls += $PythonInstallerUrl
        }
        else {
            foreach ($version in $PythonVersionCandidates) {
                $pythonUrls += "https://www.python.org/ftp/python/$version/python-$version-amd64.exe"
            }
        }

        return $pythonUrls
    }

    function Save-WebFile {
        param(
            [string[]]$Urls,
            [string]$DestinationPath,
            [psobject]$LogContext = $null
        )

        $destinationDirectory = Split-Path -Parent $DestinationPath
        if (-not [string]::IsNullOrWhiteSpace($destinationDirectory)) {
            New-DirectoryIfMissing -Path $destinationDirectory
        }

        foreach ($url in $Urls) {
            if ([string]::IsNullOrWhiteSpace($url)) {
                continue
            }

            try {
                Write-Detail -Level 'INFO' -Message "Lade Installer herunter: $url"
                Write-ComponentLogEntry -Context $LogContext -Level 'INFO' -Message "Download gestartet: $url"
                Invoke-WebRequest -Uri $url -OutFile $DestinationPath -UseBasicParsing
                if ((Test-Path -Path $DestinationPath) -and ((Get-Item -Path $DestinationPath).Length -gt 0)) {
                    Write-Detail -Level 'OK' -Message "Download erfolgreich: $DestinationPath"
                    Write-ComponentLogEntry -Context $LogContext -Level 'OK' -Message "Download erfolgreich: $url -> $DestinationPath"
                    return $DestinationPath
                }
            }
            catch {
                if (Test-Path -Path $DestinationPath) {
                    Remove-Item -Path $DestinationPath -Force -ErrorAction SilentlyContinue
                }

                Write-Detail -Level 'WARN' -Message "Download fehlgeschlagen: $url ($($_.Exception.Message))"
                Write-ComponentLogEntry -Context $LogContext -Level 'WARN' -Message "Download fehlgeschlagen: $url ($($_.Exception.Message))"
            }
        }

        throw "Keiner der konfigurierten Download-Links konnte erfolgreich geladen werden: $($Urls -join ', ')"
    }

    function Get-InstallerSource {
        param(
            [string]$ComponentName,
            [string]$CacheSubPath,
            [string]$PreferredFileName,
            [string[]]$SearchPatterns,
            [string]$ExplicitPath,
            [string[]]$Urls,
            [psobject]$LogContext = $null
        )

        $cacheDirectory = Join-Path $OfflineCacheRoot $CacheSubPath
        New-DirectoryIfMissing -Path $cacheDirectory
        $preferredCachePath = Join-Path $cacheDirectory $PreferredFileName

        if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
            if (-not (Test-Path -Path $ExplicitPath)) {
                throw "Explizit angegebener Installer fuer $ComponentName wurde nicht gefunden: $ExplicitPath"
            }

            if ((Resolve-Path -Path $ExplicitPath).Path -ne $preferredCachePath) {
                Copy-Item -Path $ExplicitPath -Destination $preferredCachePath -Force
                Write-ComponentLogEntry -Context $LogContext -Level 'INFO' -Message "Expliziter Installer wurde in den Offline-Cache kopiert: $preferredCachePath"
                return [pscustomobject]@{
                    Path      = $preferredCachePath
                    Source    = 'explicit-path-cached'
                    CachePath = $preferredCachePath
                }
            }

            return [pscustomobject]@{
                Path      = $preferredCachePath
                Source    = 'explicit-path'
                CachePath = $preferredCachePath
            }
        }

        if (Test-Path -Path $preferredCachePath) {
            Write-ComponentLogEntry -Context $LogContext -Level 'INFO' -Message "Installer aus Offline-Cache verwendet: $preferredCachePath"
            return [pscustomobject]@{
                Path      = $preferredCachePath
                Source    = 'offline-cache'
                CachePath = $preferredCachePath
            }
        }

        foreach ($pattern in $SearchPatterns) {
            $match = Get-ChildItem -Path $cacheDirectory -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($match) {
                Copy-Item -Path $match.FullName -Destination $preferredCachePath -Force
                Write-ComponentLogEntry -Context $LogContext -Level 'INFO' -Message "Cache-Treffer fuer $ComponentName gefunden und auf Standardnamen vereinheitlicht: $preferredCachePath"
                return [pscustomobject]@{
                    Path      = $preferredCachePath
                    Source    = 'offline-cache-pattern'
                    CachePath = $preferredCachePath
                }
            }
        }

        if ($OfflineOnly) {
            throw "OfflineOnly ist aktiv. Bitte den Installer fuer $ComponentName unter '$preferredCachePath' ablegen."
        }

        if (-not $Urls -or $Urls.Count -eq 0) {
            throw "Fuer $ComponentName ist kein Download-Link konfiguriert. Bitte den Installer unter '$preferredCachePath' ablegen oder einen URL-/Pfad-Parameter setzen."
        }

        $downloadedPath = Save-WebFile -Urls $Urls -DestinationPath $preferredCachePath -LogContext $LogContext
        return [pscustomobject]@{
            Path      = $downloadedPath
            Source    = 'downloaded-and-cached'
            CachePath = $preferredCachePath
        }
    }

    function Install-MsiPackage {
        param(
            [string]$MsiPath,
            [string]$DisplayName
        )

        $logContext = New-ComponentLogContext -Component $DisplayName -Action 'install-msi'
        $msiLogPath = [System.IO.Path]::ChangeExtension($logContext.LogPath, '.msi.log')

        try {
            if (-not (Test-IsAdministrator)) {
                throw "Fuer die Installation von $DisplayName werden Administratorrechte benoetigt."
            }

            Write-Section -Message "Installiere $DisplayName"
            Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message "MSI-Quelle: $MsiPath"
            Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message "MSI-Detail-Log: $msiLogPath"

            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', $MsiPath, '/qn', '/norestart', '/log', $msiLogPath) -Wait -PassThru
            if ($process.ExitCode -notin 0, 3010) {
                throw "$DisplayName konnte nicht installiert werden. Exitcode: $($process.ExitCode)"
            }

            if ($process.ExitCode -eq 3010) {
                Write-Detail -Level 'WARN' -Message "$DisplayName meldet einen Reboot-Hinweis (3010)."
                Write-ComponentLogEntry -Context $logContext -Level 'WARN' -Message 'Installer meldet Reboot-Hinweis (3010).'
                Complete-ComponentLog -Context $logContext -Outcome 'warning' -ExitCode $process.ExitCode -AdditionalFiles @($msiLogPath) -Notes @('RebootRequired')
            }
            else {
                Write-Detail -Level 'OK' -Message "$DisplayName wurde installiert."
                Write-ComponentLogEntry -Context $logContext -Level 'OK' -Message 'Installation erfolgreich.'
                Complete-ComponentLog -Context $logContext -Outcome 'success' -ExitCode $process.ExitCode -AdditionalFiles @($msiLogPath)
            }

            return [pscustomobject]@{
                RebootRequired = ($process.ExitCode -eq 3010)
                ExitCode       = $process.ExitCode
                LogPath        = $logContext.LogPath
                ExtraLogPath   = $msiLogPath
            }
        }
        catch {
            Write-ComponentLogEntry -Context $logContext -Level 'ERROR' -Message $_.Exception.Message
            Complete-ComponentLog -Context $logContext -Outcome 'error' -ExitCode 1 -AdditionalFiles @($msiLogPath) -Notes @($_.Exception.Message)
            throw
        }
    }

    function Install-PythonRuntime {
        $logContext = New-ComponentLogContext -Component 'Python 3.13.x' -Action 'install-exe'
        try {
            $installerSource = Get-InstallerSource -ComponentName 'Python 3.13.x' -CacheSubPath 'python' -PreferredFileName 'python-3.13-amd64.exe' -SearchPatterns @('python-3.13*.exe', 'python*.exe') -ExplicitPath $PythonInstallerPath -Urls (Get-PythonInstallerUrls) -LogContext $logContext
            Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message "Installerquelle: $($installerSource.Source)"
            Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message "Installerpfad: $($installerSource.Path)"

            $argumentList = @('/quiet', 'PrependPath=1', 'Include_pip=1', 'Include_launcher=1', 'Shortcuts=0', 'CompileAll=0')
            if (Test-IsAdministrator) {
                $argumentList += 'InstallAllUsers=1'
            }
            else {
                Write-Detail -Level 'WARN' -Message 'Keine Administratorrechte erkannt. Python wird fuer den aktuellen Benutzer installiert.'
                Write-ComponentLogEntry -Context $logContext -Level 'WARN' -Message 'Keine Administratorrechte erkannt. Installation erfolgt benutzerbezogen.'
                $argumentList += 'InstallAllUsers=0'
            }

            Write-Section -Message 'Installiere Python 3.13.x'
            $process = Start-Process -FilePath $installerSource.Path -ArgumentList $argumentList -Wait -PassThru
            if ($process.ExitCode -notin 0, 3010) {
                throw "Python 3.13.x konnte nicht installiert werden. Exitcode: $($process.ExitCode)"
            }

            Add-SetupCompletedAction -Action 'installer:python-runtime'

            if ($process.ExitCode -eq 3010) {
                Write-Detail -Level 'WARN' -Message 'Python-Installer meldet einen Reboot-Hinweis (3010).'
                Write-ComponentLogEntry -Context $logContext -Level 'WARN' -Message 'Installer meldet Reboot-Hinweis (3010).'
                Complete-ComponentLog -Context $logContext -Outcome 'warning' -ExitCode $process.ExitCode -Notes @('RebootRequired')
            }
            else {
                Write-Detail -Level 'OK' -Message 'Python 3.13.x wurde installiert.'
                Write-ComponentLogEntry -Context $logContext -Level 'OK' -Message 'Installation erfolgreich.'
                Complete-ComponentLog -Context $logContext -Outcome 'success' -ExitCode $process.ExitCode
            }

            return [pscustomobject]@{
                RebootRequired = ($process.ExitCode -eq 3010)
                RebootReasons  = if ($process.ExitCode -eq 3010) { @('PythonInstaller:3010') } else { @() }
            }
        }
        catch {
            Write-ComponentLogEntry -Context $logContext -Level 'ERROR' -Message $_.Exception.Message
            Complete-ComponentLog -Context $logContext -Outcome 'error' -ExitCode 1 -Notes @($_.Exception.Message)
            throw
        }
    }

    function Install-RequiredWindowsFeatures {
        param([object[]]$Statuses)

        $result = [pscustomobject]@{
            RebootRequired = $false
            RebootReasons  = @()
        }

        if (-not $InstallMissingRequiredComponents) {
            return $result
        }

        if (-not (Test-CommandAvailable -CommandName 'Install-WindowsFeature')) {
            Write-Detail -Level 'WARN' -Message 'Install-WindowsFeature ist auf diesem Host nicht verfuegbar. Windows-Features konnten nicht automatisch installiert werden.'
            return $result
        }

        if (-not (Test-IsAdministrator)) {
            throw 'Fuer die automatische Installation von Windows-Features werden Administratorrechte benoetigt.'
        }

        $featureTargets = $Statuses |
            Where-Object {
                $_.Scope -eq 'Pflicht' -and
                $_.AutoInstallable -and
                -not $_.Present -and
                -not [string]::IsNullOrWhiteSpace($_.InstallName)
            } |
            Sort-Object InstallName -Unique

        foreach ($feature in $featureTargets) {
            $logContext = New-ComponentLogContext -Component $feature.Component -Action 'install-windows-feature'
            try {
                Write-Section -Message "Installiere Windows-Feature: $($feature.Component) ($($feature.InstallName))"
                Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message "Install-WindowsFeature Name=$($feature.InstallName)"
                $installResult = Install-WindowsFeature -Name $feature.InstallName -IncludeManagementTools -ErrorAction Stop
                Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message (($installResult | Format-List * | Out-String).Trim())

                $restartNeeded = $false
                if ($null -ne $installResult.RestartNeeded) {
                    $restartNeeded = [string]$installResult.RestartNeeded -ne 'No'
                }

                Add-SetupCompletedAction -Action ("feature:{0}" -f $feature.InstallName)

                if ($restartNeeded) {
                    $result.RebootRequired = $true
                    $result.RebootReasons += "WindowsFeature:$($feature.InstallName)"
                    Write-Detail -Level 'WARN' -Message "Windows-Feature $($feature.InstallName) meldet einen Reboot-Hinweis."
                    Complete-ComponentLog -Context $logContext -Outcome 'warning' -ExitCode 3010 -Notes @('RebootRequired')
                }
                else {
                    Write-Detail -Level 'OK' -Message "Windows-Feature $($feature.InstallName) wurde verarbeitet."
                    Complete-ComponentLog -Context $logContext -Outcome 'success' -ExitCode 0
                }
            }
            catch {
                Write-Detail -Level 'WARN' -Message "Windows-Feature $($feature.InstallName) konnte nicht automatisch installiert werden: $($_.Exception.Message)"
                Write-ComponentLogEntry -Context $logContext -Level 'ERROR' -Message $_.Exception.Message
                Complete-ComponentLog -Context $logContext -Outcome 'error' -ExitCode 1 -Notes @($_.Exception.Message)
            }
        }

        $result.RebootReasons = @($result.RebootReasons | Sort-Object -Unique)
        return $result
    }

    function Install-ExternalPrerequisitesIfNeeded {
        param([object[]]$Statuses)

        $result = [pscustomobject]@{
            RebootRequired = $false
            RebootReasons  = @()
        }

        if (-not $InstallMissingRequiredComponents) {
            return $result
        }

        $pythonStatus = $Statuses | Where-Object { $_.Component -eq 'Python 3.13.x' } | Select-Object -First 1
        if ($pythonStatus -and (-not $pythonStatus.Present)) {
            $pythonInstallResult = Install-PythonRuntime
            if ($pythonInstallResult.RebootRequired) {
                $result.RebootRequired = $true
                $result.RebootReasons += @($pythonInstallResult.RebootReasons)
            }
        }

        $urlRewriteStatus = $Statuses | Where-Object { $_.Component -eq 'IIS URL Rewrite' } | Select-Object -First 1
        if ($urlRewriteStatus -and (-not $urlRewriteStatus.Present)) {
            try {
                $rewriteSourceContext = New-ComponentLogContext -Component 'IIS URL Rewrite' -Action 'resolve-installer'
                $rewriteInstaller = Get-InstallerSource -ComponentName 'IIS URL Rewrite' -CacheSubPath 'iis\url-rewrite' -PreferredFileName 'rewrite_amd64_en-US.msi' -SearchPatterns @('rewrite*.msi', '*url*rewrite*.msi') -ExplicitPath $UrlRewriteInstallerPath -Urls @($UrlRewriteInstallerUrl) -LogContext $rewriteSourceContext
                Write-ComponentLogEntry -Context $rewriteSourceContext -Level 'OK' -Message "Installerquelle: $($rewriteInstaller.Source) / $($rewriteInstaller.Path)"
                Complete-ComponentLog -Context $rewriteSourceContext -Outcome 'success' -ExitCode 0

                $rewriteInstallResult = Install-MsiPackage -MsiPath $rewriteInstaller.Path -DisplayName 'IIS URL Rewrite'
                Add-SetupCompletedAction -Action 'installer:iis-url-rewrite'
                if ($rewriteInstallResult.RebootRequired) {
                    $result.RebootRequired = $true
                    $result.RebootReasons += 'IISUrlRewrite:3010'
                }
            }
            catch {
                Write-Detail -Level 'WARN' -Message "IIS URL Rewrite konnte nicht automatisch installiert werden: $($_.Exception.Message)"
            }
        }

        if ($InstallOptionalComponents) {
            $arrStatus = $Statuses | Where-Object { $_.Component -eq 'IIS Application Request Routing (ARR)' } | Select-Object -First 1
            if ($arrStatus -and (-not $arrStatus.Present)) {
                try {
                    $arrSourceContext = New-ComponentLogContext -Component 'IIS Application Request Routing (ARR)' -Action 'resolve-installer'
                    $arrInstaller = Get-InstallerSource -ComponentName 'IIS Application Request Routing (ARR)' -CacheSubPath 'iis\arr' -PreferredFileName 'arr-x64.msi' -SearchPatterns @('*application*request*routing*.msi', '*arr*.msi') -ExplicitPath $ArrInstallerPath -Urls @($ArrInstallerUrl) -LogContext $arrSourceContext
                    Write-ComponentLogEntry -Context $arrSourceContext -Level 'OK' -Message "Installerquelle: $($arrInstaller.Source) / $($arrInstaller.Path)"
                    Complete-ComponentLog -Context $arrSourceContext -Outcome 'success' -ExitCode 0

                    $arrInstallResult = Install-MsiPackage -MsiPath $arrInstaller.Path -DisplayName 'IIS Application Request Routing (ARR)'
                    Add-SetupCompletedAction -Action 'installer:iis-arr'
                    if ($arrInstallResult.RebootRequired) {
                        $result.RebootRequired = $true
                        $result.RebootReasons += 'ARR:3010'
                    }
                }
                catch {
                    Write-Detail -Level 'WARN' -Message "ARR konnte nicht automatisch installiert werden: $($_.Exception.Message)"
                }
            }
        }

        $result.RebootReasons = @($result.RebootReasons | Sort-Object -Unique)
        return $result
    }

    function Install-PythonDependencies {
        param(
            [object]$PythonRuntime,
            [bool]$WithDevDependencySet,
            [bool]$AllowUnsupportedVersion
        )

        if (-not $PythonRuntime) {
            throw 'Es konnte kein Python-Interpreter gefunden werden. Bitte Python 3.13.x installieren.'
        }

        if ((-not $PythonRuntime.IsTargetPython) -and (-not $AllowUnsupportedVersion)) {
            throw "Gefunden wurde Python $($PythonRuntime.Version). Fuer den vorgesehenen V2-Betrieb ist Python 3.13.x Pflicht. Mit -AllowUnsupportedPythonVersion kann der Schritt fuer lokale Sonderfaelle trotzdem erzwungen werden."
        }

        $logContext = New-ComponentLogContext -Component 'Python Dependencies' -Action 'pip-install-editable'
        try {
            $packageSpec = if ($WithDevDependencySet) { '.[dev]' } else { '.' }
            $pipArgs = @()
            $pipArgs += $PythonRuntime.Arguments
            $pipArgs += '-m'
            $pipArgs += 'pip'
            $pipArgs += 'install'
            $pipArgs += '-e'
            $pipArgs += $packageSpec

            Write-Section -Message "Installiere Python-Abhaengigkeiten ueber $($PythonRuntime.Label)"
            Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message ("Befehl: {0} {1}" -f $PythonRuntime.FilePath, ($pipArgs -join ' '))
            & $PythonRuntime.FilePath @pipArgs 2>&1 | Tee-Object -FilePath $logContext.LogPath -Append | Out-Host
            if ($LASTEXITCODE -ne 0) {
                throw "pip install ist mit Exitcode $LASTEXITCODE fehlgeschlagen."
            }

            Add-SetupCompletedAction -Action 'python-dependencies'
            Complete-ComponentLog -Context $logContext -Outcome 'success' -ExitCode 0
        }
        catch {
            Write-ComponentLogEntry -Context $logContext -Level 'ERROR' -Message $_.Exception.Message
            Complete-ComponentLog -Context $logContext -Outcome 'error' -ExitCode 1 -Notes @($_.Exception.Message)
            throw
        }
    }

    function Invoke-OfflineCachePreparation {
        Start-SetupSession
        Set-SetupPhase -Phase 'prepare-offline-cache'
        Write-Section -Message 'Bereite Offline-Cache fuer produktive Server vor'

        try {
            $pythonCacheContext = New-ComponentLogContext -Component 'Python 3.13.x' -Action 'prepare-offline-cache'
            $pythonInstaller = Get-InstallerSource -ComponentName 'Python 3.13.x' -CacheSubPath 'python' -PreferredFileName 'python-3.13-amd64.exe' -SearchPatterns @('python-3.13*.exe', 'python*.exe') -ExplicitPath $PythonInstallerPath -Urls (Get-PythonInstallerUrls) -LogContext $pythonCacheContext
            Write-ComponentLogEntry -Context $pythonCacheContext -Level 'OK' -Message "Offline-Cache bereit: $($pythonInstaller.Path)"
            Complete-ComponentLog -Context $pythonCacheContext -Outcome 'success' -ExitCode 0
            Add-SetupCompletedAction -Action 'cache:python-runtime'
        }
        catch {
            Write-Detail -Level 'WARN' -Message "Python-Installer konnte nicht fuer den Offline-Cache vorbereitet werden: $($_.Exception.Message)"
        }

        try {
            $rewriteCacheContext = New-ComponentLogContext -Component 'IIS URL Rewrite' -Action 'prepare-offline-cache'
            $rewriteInstaller = Get-InstallerSource -ComponentName 'IIS URL Rewrite' -CacheSubPath 'iis\url-rewrite' -PreferredFileName 'rewrite_amd64_en-US.msi' -SearchPatterns @('rewrite*.msi', '*url*rewrite*.msi') -ExplicitPath $UrlRewriteInstallerPath -Urls @($UrlRewriteInstallerUrl) -LogContext $rewriteCacheContext
            Write-ComponentLogEntry -Context $rewriteCacheContext -Level 'OK' -Message "Offline-Cache bereit: $($rewriteInstaller.Path)"
            Complete-ComponentLog -Context $rewriteCacheContext -Outcome 'success' -ExitCode 0
            Add-SetupCompletedAction -Action 'cache:iis-url-rewrite'
        }
        catch {
            Write-Detail -Level 'WARN' -Message "URL-Rewrite-Installer konnte nicht fuer den Offline-Cache vorbereitet werden: $($_.Exception.Message)"
        }

        try {
            $arrCacheContext = New-ComponentLogContext -Component 'IIS Application Request Routing (ARR)' -Action 'prepare-offline-cache'
            $arrInstaller = Get-InstallerSource -ComponentName 'IIS Application Request Routing (ARR)' -CacheSubPath 'iis\arr' -PreferredFileName 'arr-x64.msi' -SearchPatterns @('*application*request*routing*.msi', '*arr*.msi') -ExplicitPath $ArrInstallerPath -Urls @($ArrInstallerUrl) -LogContext $arrCacheContext
            Write-ComponentLogEntry -Context $arrCacheContext -Level 'OK' -Message "Offline-Cache bereit: $($arrInstaller.Path)"
            Complete-ComponentLog -Context $arrCacheContext -Outcome 'success' -ExitCode 0
            Add-SetupCompletedAction -Action 'cache:iis-arr'
        }
        catch {
            $expectedArrPath = Join-Path (Join-Path $OfflineCacheRoot 'iis\arr') 'arr-x64.msi'
            Write-Detail -Level 'WARN' -Message "ARR konnte nicht automatisch vorbereitet werden. Lege den MSI-Installer manuell unter '$expectedArrPath' ab oder nutze -ArrInstallerPath / -ArrInstallerUrl."
        }

        Write-Detail -Level 'OK' -Message "Offline-Cache vorbereitet unter: $OfflineCacheRoot"
        Set-SetupPhase -Phase 'prepare-offline-cache-complete'
        Clear-SetupRebootPending
        Clear-SetupStateFile
    }

    if ($CheckOnly -and $PrepareOfflineCache) {
        throw 'Die Kombination aus -CheckOnly und -PrepareOfflineCache ist nicht sinnvoll. Bitte nur einen der beiden Modi verwenden.'
    }

    if ($PrepareOfflineCache) {
        Invoke-OfflineCachePreparation
        return
    }

    Write-Section -Message 'Pruefe Management-Server-Basis und V2-Abhaengigkeiten'
    $setupStatus = Get-SetupStatus
    Show-StatusTable -Statuses $setupStatus.Statuses
    Show-RequiredStatusSummary -Statuses $setupStatus.Statuses

    $pendingRebootState = Get-PendingRebootState
    if ($pendingRebootState.IsPending) {
        Write-Detail -Level 'WARN' -Message ('Es ist bereits ein ausstehender Neustart erkannt worden: ' + ($pendingRebootState.Reasons -join ', '))
    }

    if ($CheckOnly) {
        Write-Detail -Level 'INFO' -Message 'CheckOnly aktiv: Es wurden keine Komponenten und keine Python-Abhaengigkeiten installiert.'
        return
    }

    Start-SetupSession
    Set-SetupPhase -Phase 'audit-complete'

    if ($script:SetupState.PendingReboot) {
        $currentPendingReboot = Get-PendingRebootState
        if ($currentPendingReboot.IsPending) {
            Stop-ForPendingReboot -Phase 'awaiting-reboot' -Reasons @($script:SetupState.PendingRebootReasons + $currentPendingReboot.Reasons)
            return
        }

        Write-Detail -Level 'OK' -Message 'Vorher ausstehender Neustart ist nicht mehr erkannt. Das Setup wird automatisch fortgesetzt.'
        Clear-SetupRebootPending
    }
    elseif ($pendingRebootState.IsPending) {
        Stop-ForPendingReboot -Phase 'awaiting-preexisting-reboot' -Reasons $pendingRebootState.Reasons
        return
    }

    if ($InstallMissingRequiredComponents) {
        Set-SetupPhase -Phase 'install-required-windows-features'
        $featureInstallResult = Install-RequiredWindowsFeatures -Statuses $setupStatus.Statuses
        $pendingAfterFeatures = Get-PendingRebootState
        if ($featureInstallResult.RebootRequired -or $pendingAfterFeatures.IsPending) {
            $reasons = @($featureInstallResult.RebootReasons + $pendingAfterFeatures.Reasons)
            Stop-ForPendingReboot -Phase 'post-feature-install' -Reasons $reasons
            return
        }

        Set-SetupPhase -Phase 'install-external-prerequisites'
        $externalInstallResult = Install-ExternalPrerequisitesIfNeeded -Statuses $setupStatus.Statuses
        $pendingAfterExternal = Get-PendingRebootState
        if ($externalInstallResult.RebootRequired -or $pendingAfterExternal.IsPending) {
            $reasons = @($externalInstallResult.RebootReasons + $pendingAfterExternal.Reasons)
            Stop-ForPendingReboot -Phase 'post-external-prerequisites' -Reasons $reasons
            return
        }

        Write-Section -Message 'Pruefe Status nach Installationsversuchen erneut'
        $setupStatus = Get-SetupStatus
        Show-StatusTable -Statuses $setupStatus.Statuses
        Show-RequiredStatusSummary -Statuses $setupStatus.Statuses
    }

    Set-SetupPhase -Phase 'install-python-dependencies'
    Install-PythonDependencies -PythonRuntime $setupStatus.PythonRuntime -WithDevDependencySet $WithDevDependencies.IsPresent -AllowUnsupportedVersion $AllowUnsupportedPythonVersion.IsPresent

    Set-SetupPhase -Phase 'completed'
    Clear-SetupRebootPending
    Clear-SetupStateFile
    Write-Detail -Level 'OK' -Message "Setup abgeschlossen. Komponenten-Logs liegen unter: $script:CurrentLogSessionDir"
}
finally {
    Pop-Location
}
