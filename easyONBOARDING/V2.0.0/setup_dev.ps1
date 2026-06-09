param(
    [switch]$WithDevDependencies,
    [switch]$CheckOnly,
    [switch]$PrepareOfflineCache,
    [switch]$OfflineOnly,
    [bool]$InstallMissingRequiredComponents = $true,
    [bool]$InstallOptionalComponents = $false,
    [bool]$OfferOptionalComponents = $true,
    [bool]$EnableAutoResumeScheduledTask = $true,
    [bool]$OfferRestartAtEnd = $true,
    [bool]$RestartAutomaticallyIfNeeded = $false,
    [switch]$AllowUnsupportedPythonVersion,
    [switch]$ConfigureIis,
    [switch]$CopyProjectData,
    [string]$InstallerCacheDir = "$env:TEMP\easyonb-v2-setup",
    [string]$OfflineCacheRoot = '',
    [string]$InstallerManifestPath = '',
    [string]$ComponentLogRoot = '',
    [string]$SetupStatePath = '',
    [string]$DeploymentRoot = '',
    [string]$ProjectDataRoot = '',
    [string]$ResumeScheduledTaskName = 'easyONBOARDING-V2-Setup-Resume',
    [string]$IisSiteName = 'easyONBOARDING-V2',
    [string]$IisAppPoolName = 'easyONBOARDING-V2',
    [string]$IisPhysicalPath = '',
    [int]$IisPort = 80,
    [string]$IisHostHeader = '',
    [int]$PythonBackendPort = 8010,
    [string[]]$PythonVersionCandidates = @('3.13.5', '3.13.4', '3.13.3', '3.13.2', '3.13.1', '3.13.0'),
    [string]$PythonInstallerUrl = '',
    [string]$PythonInstallerPath = '',
    [string]$UrlRewriteInstallerUrl = '',
    [string]$UrlRewriteInstallerPath = '',
    [string]$ArrInstallerUrl = 'https://go.microsoft.com/fwlink/?LinkID=615136',
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
$script:SetupScriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($OfflineCacheRoot)) {
    $OfflineCacheRoot = Join-Path $projectRoot 'setup-cache'
}
if ([string]::IsNullOrWhiteSpace($InstallerManifestPath)) {
    $InstallerManifestPath = Join-Path $OfflineCacheRoot 'installer-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($ComponentLogRoot)) {
    $ComponentLogRoot = Join-Path $projectRoot 'logs\setup'
}
if ([string]::IsNullOrWhiteSpace($SetupStatePath)) {
    $SetupStatePath = Join-Path $ComponentLogRoot 'setup-state.json'
}
if ($PrepareOfflineCache -and (-not $PSBoundParameters.ContainsKey('SetupStatePath'))) {
    $SetupStatePath = Join-Path $ComponentLogRoot 'setup-cacheprep-state.json'
}
if ([string]::IsNullOrWhiteSpace($DeploymentRoot)) {
    $DeploymentRoot = Join-Path $projectRoot 'deploy'
}
if ([string]::IsNullOrWhiteSpace($ProjectDataRoot)) {
    $ProjectDataRoot = Join-Path $DeploymentRoot 'project-data'
}
if ([string]::IsNullOrWhiteSpace($IisPhysicalPath)) {
    $IisPhysicalPath = Join-Path $DeploymentRoot 'iis-site'
}
if ($ConfigureIis -and (-not $PSBoundParameters.ContainsKey('CopyProjectData'))) {
    $CopyProjectData = $true
}

Push-Location $projectRoot

try {
    $script:SetupState = $null
    $script:ResumeDetected = $false
    $script:CurrentLogSessionDir = $null
    $script:ManifestCache = $null

    function Write-Section {
        param([string]$Message)

        Write-Host ''
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

    function Test-InteractiveSession {
        try {
            if (-not [Environment]::UserInteractive) {
                return $false
            }

            if ($null -eq $Host -or $null -eq $Host.UI) {
                return $false
            }

            if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
                return $false
            }

            return $true
        }
        catch {
            return $false
        }
    }

    function Read-YesNoDecision {
        param(
            [string]$Caption,
            [string]$Question,
            [bool]$DefaultYes = $false
        )

        if (-not (Test-InteractiveSession)) {
            return $false
        }

        try {
            $choices = @(
                [System.Management.Automation.Host.ChoiceDescription]::new('&Ja', 'Aktion jetzt ausfuehren.'),
                [System.Management.Automation.Host.ChoiceDescription]::new('&Nein', 'Aktion spaeter manuell ausfuehren.')
            )
            $defaultIndex = if ($DefaultYes) { 0 } else { 1 }
            $selection = $Host.UI.PromptForChoice($Caption, $Question, $choices, $defaultIndex)
            return ($selection -eq 0)
        }
        catch {
            $defaultPrompt = if ($DefaultYes) { 'J/n' } else { 'j/N' }
            $answer = Read-Host "$Question [$defaultPrompt]"
            if ([string]::IsNullOrWhiteSpace($answer)) {
                return $DefaultYes
            }

            return $answer.Trim() -match '^(j|ja|y|yes)$'
        }
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

    function Format-CommandArgument {
        param([string]$Value)

        if ($null -eq $Value) {
            return '""'
        }

        $escapedValue = $Value.Replace('"', '\"')
        if ($escapedValue -match '[\s"]') {
            return '"' + $escapedValue + '"'
        }

        return $escapedValue
    }

    function Get-ResolvedPathString {
        param([string]$Path)

        return (Resolve-Path -Path $Path).Path
    }

    function Get-RelativePathFromRoot {
        param(
            [string]$RootPath,
            [string]$ChildPath
        )

        $resolvedRoot = Get-ResolvedPathString -Path $RootPath
        $resolvedChild = Get-ResolvedPathString -Path $ChildPath
        $rootUri = [System.Uri]::new(($resolvedRoot.TrimEnd('\') + '\'))
        $childUri = [System.Uri]::new($resolvedChild)
        return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($childUri).ToString()) -replace '/', '\'
    }

    function Get-FileSha256Hash {
        param([string]$Path)

        return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
    }

    function Test-UsableFileSystemPath {
        param([string]$Path)

        if ([string]::IsNullOrWhiteSpace($Path)) {
            return $false
        }

        $root = [System.IO.Path]::GetPathRoot($Path)
        if ([string]::IsNullOrWhiteSpace($root)) {
            return $true
        }

        if ($root -match '^[A-Za-z]:\\$') {
            return Test-Path -Path $root
        }

        return $true
    }

    function Get-ResumePathOrDefault {
        param(
            [string]$ResumeValue,
            [string]$CurrentValue,
            [string]$Label
        )

        if ([string]::IsNullOrWhiteSpace($ResumeValue)) {
            return $CurrentValue
        }

        if (Test-UsableFileSystemPath -Path $ResumeValue) {
            return $ResumeValue
        }

        Write-Detail -Level 'WARN' -Message "Resume-Konfiguration fuer $Label verweist auf ein nicht verfuegbares Laufwerk. Es wird der aktuelle Wert verwendet: $CurrentValue"
        return $CurrentValue
    }

    function Import-ServerManagerModuleIfAvailable {
        if (Get-Module -Name 'ServerManager') {
            return
        }

        if (Get-Module -ListAvailable -Name 'ServerManager') {
            Import-Module -Name 'ServerManager' -ErrorAction SilentlyContinue
        }
    }

    function Get-WindowsFeatureInstallCommandName {
        Import-ServerManagerModuleIfAvailable

        if (Test-CommandAvailable -CommandName 'Install-WindowsFeature') {
            return 'Install-WindowsFeature'
        }

        if (Test-CommandAvailable -CommandName 'Add-WindowsFeature') {
            return 'Add-WindowsFeature'
        }

        return $null
    }

    function Get-RegistryDefaultValue {
        param([string]$RegistryPath)

        try {
            $item = Get-ItemProperty -Path $RegistryPath -ErrorAction Stop
            $defaultProperty = $item.PSObject.Properties['(default)']
            if ($null -ne $defaultProperty -and -not [string]::IsNullOrWhiteSpace([string]$defaultProperty.Value)) {
                return [string]$defaultProperty.Value
            }
        }
        catch {
        }

        return ''
    }

    function Get-PythonInstallPathCandidates {
        $candidatePaths = @()
        $registryPaths = @(
            'HKLM:\SOFTWARE\Python\PythonCore\3.13\InstallPath',
            'HKCU:\SOFTWARE\Python\PythonCore\3.13\InstallPath',
            'HKLM:\SOFTWARE\WOW6432Node\Python\PythonCore\3.13\InstallPath',
            'HKCU:\SOFTWARE\WOW6432Node\Python\PythonCore\3.13\InstallPath',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\python.exe',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\python.exe',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\python3.exe',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\python3.exe'
        )

        foreach ($registryPath in $registryPaths) {
            $defaultValue = Get-RegistryDefaultValue -RegistryPath $registryPath
            if ([string]::IsNullOrWhiteSpace($defaultValue)) {
                continue
            }

            if ($defaultValue -match '\.exe$') {
                $candidatePaths += $defaultValue
            }
            else {
                $candidatePaths += (Join-Path $defaultValue 'python.exe')
                $candidatePaths += (Join-Path $defaultValue 'python3.exe')
            }
        }

        return @($candidatePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    }

    function Get-PythonLauncherPathCandidates {
        $candidatePaths = @()
        if (-not (Test-CommandAvailable -CommandName 'py')) {
            return $candidatePaths
        }

        try {
            $launcherOutput = & py -0p 2>$null
            foreach ($line in @($launcherOutput)) {
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }

                if ($line -match '^-V:3\.13(?:\S*)?\s+\*?\s*(.+)$') {
                    $candidatePaths += $Matches[1].Trim()
                }
            }
        }
        catch {
        }

        return @($candidatePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    }

    function Get-PythonKnownPathCandidates {
        $candidatePaths = @(
            (Join-Path $env:ProgramFiles 'Python313\python.exe'),
            (Join-Path $env:ProgramFiles 'Python313\python3.exe'),
            (Join-Path $env:LocalAppData 'Programs\Python\Python313\python.exe'),
            (Join-Path $env:LocalAppData 'Programs\Python\Python313\python3.exe'),
            'C:\Python313\python.exe',
            'C:\Python313\python3.exe'
        )

        return @($candidatePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    }

    function Find-PythonRuntime {
        param([string[]]$PreferredPaths = @())

        $candidateList = @(
            @{ Type = 'Command'; FilePath = 'py'; Arguments = @('-3.13'); Label = 'py -3.13' },
            @{ Type = 'Command'; FilePath = 'python'; Arguments = @(); Label = 'python' },
            @{ Type = 'Command'; FilePath = 'python3.13'; Arguments = @(); Label = 'python3.13' }
        )

        $pathCandidates = @($PreferredPaths) + @(Get-PythonInstallPathCandidates) + @(Get-PythonLauncherPathCandidates) + @(Get-PythonKnownPathCandidates)
        foreach ($pathCandidate in @($pathCandidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
            $candidateList += @{ Type = 'Path'; FilePath = $pathCandidate; Arguments = @(); Label = $pathCandidate }
        }

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

        return $selected
    }

    function Get-UrlRewriteInstallerUrls {
        if (-not [string]::IsNullOrWhiteSpace($UrlRewriteInstallerUrl)) {
            return @($UrlRewriteInstallerUrl)
        }

        return @(
            'https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi',
            'https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_de-DE.msi'
        )
    }

    function Get-ArrInstallerUrls {
        if (-not [string]::IsNullOrWhiteSpace($ArrInstallerUrl)) {
            return @($ArrInstallerUrl)
        }

        return @(
            'https://go.microsoft.com/fwlink/?LinkID=615136'
        )
    }

    function Set-DetectedPythonRuntime {
        param(
            [pscustomobject]$SetupStatus,
            [psobject]$PythonRuntime
        )

        if ($null -eq $SetupStatus -or $null -eq $PythonRuntime) {
            return $SetupStatus
        }

        $updatedStatuses = foreach ($status in $SetupStatus.Statuses) {
            if ($status.Component -eq 'Python 3.13.x') {
                $detail = "Erkannt ueber '$($PythonRuntime.Label)' mit Version $($PythonRuntime.Version) ($($PythonRuntime.Executable))."
                $statusCode = if ($PythonRuntime.IsTargetPython) { 'OK' } else { 'WARN' }
                New-ComponentStatus -Status $statusCode -Component 'Python 3.13.x' -Purpose $status.Purpose -Detail $detail -Required $true -Present $PythonRuntime.IsTargetPython
            }
            else {
                $status
            }
        }

        return [pscustomobject]@{
            Statuses      = @($updatedStatuses)
            PythonRuntime = $PythonRuntime
        }
    }

    function New-SetupStateObject {
        [pscustomobject]@{
            SchemaVersion        = 3
            RunId                = 'setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
            CreatedUtc           = Get-UtcTimestamp
            UpdatedUtc           = Get-UtcTimestamp
            LastPhase            = 'initial'
            PendingReboot        = $false
            PendingRebootReasons = @()
            ResumeRecommended    = $false
            ResumeConfiguration  = $null
            ResumeTaskName       = ''
            ResumeTaskRegistered = $false
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

        Set-StatePropertyDefault -Object $State -PropertyName 'SchemaVersion' -DefaultValue 3
        Set-StatePropertyDefault -Object $State -PropertyName 'RunId' -DefaultValue ('setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Set-StatePropertyDefault -Object $State -PropertyName 'CreatedUtc' -DefaultValue (Get-UtcTimestamp)
        Set-StatePropertyDefault -Object $State -PropertyName 'UpdatedUtc' -DefaultValue (Get-UtcTimestamp)
        Set-StatePropertyDefault -Object $State -PropertyName 'LastPhase' -DefaultValue 'initial'
        Set-StatePropertyDefault -Object $State -PropertyName 'PendingReboot' -DefaultValue $false
        Set-StatePropertyDefault -Object $State -PropertyName 'PendingRebootReasons' -DefaultValue @()
        Set-StatePropertyDefault -Object $State -PropertyName 'ResumeRecommended' -DefaultValue $false
        Set-StatePropertyDefault -Object $State -PropertyName 'ResumeConfiguration' -DefaultValue $null
        Set-StatePropertyDefault -Object $State -PropertyName 'ResumeTaskName' -DefaultValue ''
        Set-StatePropertyDefault -Object $State -PropertyName 'ResumeTaskRegistered' -DefaultValue $false
        Set-StatePropertyDefault -Object $State -PropertyName 'CompletedActions' -DefaultValue @()
        Set-StatePropertyDefault -Object $State -PropertyName 'Notes' -DefaultValue @()
        Set-StatePropertyDefault -Object $State -PropertyName 'ComponentLogs' -DefaultValue @()

        $State.PendingRebootReasons = @($State.PendingRebootReasons)
        $State.CompletedActions = @($State.CompletedActions)
        $State.Notes = @($State.Notes)
        $State.ComponentLogs = @($State.ComponentLogs)
        return $State
    }

    function Get-CurrentResumeConfiguration {
        return [pscustomobject]@{
            WithDevDependencies              = [bool]$WithDevDependencies
            InstallMissingRequiredComponents = [bool]$InstallMissingRequiredComponents
            InstallOptionalComponents        = [bool]$InstallOptionalComponents
            OfferOptionalComponents          = [bool]$OfferOptionalComponents
            EnableAutoResumeScheduledTask    = [bool]$EnableAutoResumeScheduledTask
            OfferRestartAtEnd                = [bool]$OfferRestartAtEnd
            RestartAutomaticallyIfNeeded     = [bool]$RestartAutomaticallyIfNeeded
            AllowUnsupportedPythonVersion    = [bool]$AllowUnsupportedPythonVersion
            OfflineOnly                      = [bool]$OfflineOnly
            ConfigureIis                     = [bool]$ConfigureIis
            CopyProjectData                  = [bool]$CopyProjectData
            InstallerCacheDir                = $InstallerCacheDir
            OfflineCacheRoot                 = $OfflineCacheRoot
            InstallerManifestPath            = $InstallerManifestPath
            ComponentLogRoot                 = $ComponentLogRoot
            SetupStatePath                   = $SetupStatePath
            DeploymentRoot                   = $DeploymentRoot
            ProjectDataRoot                  = $ProjectDataRoot
            ResumeScheduledTaskName          = $ResumeScheduledTaskName
            IisSiteName                      = $IisSiteName
            IisAppPoolName                   = $IisAppPoolName
            IisPhysicalPath                  = $IisPhysicalPath
            IisPort                          = $IisPort
            IisHostHeader                    = $IisHostHeader
            PythonBackendPort                = $PythonBackendPort
            PythonVersionCandidates          = @($PythonVersionCandidates)
            PythonInstallerUrl               = $PythonInstallerUrl
            PythonInstallerPath              = $PythonInstallerPath
            UrlRewriteInstallerUrl           = $UrlRewriteInstallerUrl
            UrlRewriteInstallerPath          = $UrlRewriteInstallerPath
            ArrInstallerUrl                  = $ArrInstallerUrl
            ArrInstallerPath                 = $ArrInstallerPath
        }
    }

    #pragma warning disable PSUseApprovedVerbs
    #pragma warning disable PSUseDeclaredVarsMoreThanAssignments
    function Import-ResumeConfigurationFromState {
        param([psobject]$State)

        if ($null -eq $State.ResumeConfiguration) {
            return
        }

        $config = $State.ResumeConfiguration
        $script:WithDevDependencies = [bool]$config.WithDevDependencies
        $script:InstallMissingRequiredComponents = [bool]$config.InstallMissingRequiredComponents
        $script:InstallOptionalComponents = [bool]$config.InstallOptionalComponents
        $script:OfferOptionalComponents = if ($null -ne $config.PSObject.Properties['OfferOptionalComponents']) { [bool]$config.OfferOptionalComponents } else { $OfferOptionalComponents }
        $script:EnableAutoResumeScheduledTask = [bool]$config.EnableAutoResumeScheduledTask
        $script:OfferRestartAtEnd = if ($null -ne $config.PSObject.Properties['OfferRestartAtEnd']) { [bool]$config.OfferRestartAtEnd } else { $OfferRestartAtEnd }
        $script:RestartAutomaticallyIfNeeded = if ($null -ne $config.PSObject.Properties['RestartAutomaticallyIfNeeded']) { [bool]$config.RestartAutomaticallyIfNeeded } else { $RestartAutomaticallyIfNeeded }
        $script:AllowUnsupportedPythonVersion = [bool]$config.AllowUnsupportedPythonVersion
        $script:OfflineOnly = [bool]$config.OfflineOnly
        $script:ConfigureIis = if ($null -ne $config.PSObject.Properties['ConfigureIis']) { [bool]$config.ConfigureIis } else { $ConfigureIis }
        $script:CopyProjectData = if ($null -ne $config.PSObject.Properties['CopyProjectData']) { [bool]$config.CopyProjectData } else { $CopyProjectData }
        $script:InstallerCacheDir = Get-ResumePathOrDefault -ResumeValue ([string]$config.InstallerCacheDir) -CurrentValue $InstallerCacheDir -Label 'InstallerCacheDir'
        $script:OfflineCacheRoot = Get-ResumePathOrDefault -ResumeValue ([string]$config.OfflineCacheRoot) -CurrentValue $OfflineCacheRoot -Label 'OfflineCacheRoot'
        $script:InstallerManifestPath = Get-ResumePathOrDefault -ResumeValue ([string]$config.InstallerManifestPath) -CurrentValue $InstallerManifestPath -Label 'InstallerManifestPath'
        $script:ComponentLogRoot = Get-ResumePathOrDefault -ResumeValue ([string]$config.ComponentLogRoot) -CurrentValue $ComponentLogRoot -Label 'ComponentLogRoot'
        $script:SetupStatePath = Get-ResumePathOrDefault -ResumeValue ([string]$config.SetupStatePath) -CurrentValue $SetupStatePath -Label 'SetupStatePath'
        $script:DeploymentRoot = if ($null -ne $config.PSObject.Properties['DeploymentRoot']) { Get-ResumePathOrDefault -ResumeValue ([string]$config.DeploymentRoot) -CurrentValue $DeploymentRoot -Label 'DeploymentRoot' } else { $DeploymentRoot }
        $script:ProjectDataRoot = if ($null -ne $config.PSObject.Properties['ProjectDataRoot']) { Get-ResumePathOrDefault -ResumeValue ([string]$config.ProjectDataRoot) -CurrentValue $ProjectDataRoot -Label 'ProjectDataRoot' } else { $ProjectDataRoot }
        $script:ResumeScheduledTaskName = [string]$config.ResumeScheduledTaskName
        $script:IisSiteName = if ($null -ne $config.PSObject.Properties['IisSiteName']) { [string]$config.IisSiteName } else { $IisSiteName }
        $script:IisAppPoolName = if ($null -ne $config.PSObject.Properties['IisAppPoolName']) { [string]$config.IisAppPoolName } else { $IisAppPoolName }
        $script:IisPhysicalPath = if ($null -ne $config.PSObject.Properties['IisPhysicalPath']) { Get-ResumePathOrDefault -ResumeValue ([string]$config.IisPhysicalPath) -CurrentValue $IisPhysicalPath -Label 'IisPhysicalPath' } else { $IisPhysicalPath }
        $script:IisPort = if ($null -ne $config.PSObject.Properties['IisPort']) { [int]$config.IisPort } else { $IisPort }
        $script:IisHostHeader = if ($null -ne $config.PSObject.Properties['IisHostHeader']) { [string]$config.IisHostHeader } else { $IisHostHeader }
        $script:PythonBackendPort = if ($null -ne $config.PSObject.Properties['PythonBackendPort']) { [int]$config.PythonBackendPort } else { $PythonBackendPort }
        $script:PythonVersionCandidates = @($config.PythonVersionCandidates)
        $script:PythonInstallerUrl = [string]$config.PythonInstallerUrl
        $script:PythonInstallerPath = [string]$config.PythonInstallerPath
        $script:UrlRewriteInstallerUrl = [string]$config.UrlRewriteInstallerUrl
        $script:UrlRewriteInstallerPath = [string]$config.UrlRewriteInstallerPath
        $script:ArrInstallerUrl = [string]$config.ArrInstallerUrl
        $script:ArrInstallerPath = [string]$config.ArrInstallerPath
    }
    #pragma warning restore PSUseDeclaredVarsMoreThanAssignments
    #pragma warning restore PSUseApprovedVerbs

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

    function Update-SetupResumeConfiguration {
        $script:SetupState.ResumeConfiguration = Get-CurrentResumeConfiguration
        $script:SetupState.ResumeTaskName = $ResumeScheduledTaskName
        Save-SetupState -State $script:SetupState
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
        if ($script:ResumeDetected) {
            Import-ResumeConfigurationFromState -State $script:SetupState
        }

        New-DirectoryIfMissing -Path $ComponentLogRoot
        New-DirectoryIfMissing -Path $OfflineCacheRoot
        $script:CurrentLogSessionDir = Join-Path $ComponentLogRoot $script:SetupState.RunId
        New-DirectoryIfMissing -Path $script:CurrentLogSessionDir
        Update-SetupResumeConfiguration

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

        Add-Content -Path $Context.LogPath -Value "[$(Get-UtcTimestamp)][$Level] $Message" -Encoding UTF8
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

    function New-InstallerManifestObject {
        [pscustomobject]@{
            SchemaVersion = 1
            UpdatedUtc    = Get-UtcTimestamp
            Installers    = @()
        }
    }

    function Set-InstallerManifestDefaults {
        param([psobject]$Manifest)

        Set-StatePropertyDefault -Object $Manifest -PropertyName 'SchemaVersion' -DefaultValue 1
        Set-StatePropertyDefault -Object $Manifest -PropertyName 'UpdatedUtc' -DefaultValue (Get-UtcTimestamp)
        Set-StatePropertyDefault -Object $Manifest -PropertyName 'Installers' -DefaultValue @()
        $Manifest.Installers = @($Manifest.Installers)
        return $Manifest
    }

    function Get-InstallerManifestObject {
        if ($null -ne $script:ManifestCache) {
            return $script:ManifestCache
        }

        $manifestDirectory = Split-Path -Parent $InstallerManifestPath
        if (-not [string]::IsNullOrWhiteSpace($manifestDirectory)) {
            New-DirectoryIfMissing -Path $manifestDirectory
        }

        if (Test-Path -Path $InstallerManifestPath) {
            try {
                $loadedManifest = Get-Content -Path $InstallerManifestPath -Raw | ConvertFrom-Json
                $script:ManifestCache = Set-InstallerManifestDefaults -Manifest $loadedManifest
                return $script:ManifestCache
            }
            catch {
                Write-Detail -Level 'WARN' -Message "Installer-Manifest ist unlesbar und wird neu aufgebaut: $($_.Exception.Message)"
            }
        }

        $script:ManifestCache = New-InstallerManifestObject
        return $script:ManifestCache
    }

    function Save-InstallerManifest {
        param([psobject]$Manifest)

        $Manifest.UpdatedUtc = Get-UtcTimestamp
        $manifestDirectory = Split-Path -Parent $InstallerManifestPath
        if (-not [string]::IsNullOrWhiteSpace($manifestDirectory)) {
            New-DirectoryIfMissing -Path $manifestDirectory
        }

        $Manifest | ConvertTo-Json -Depth 12 | Set-Content -Path $InstallerManifestPath -Encoding UTF8
        $script:ManifestCache = $Manifest
    }

    function Get-InstallerManifestEntry {
        param([string]$RelativePath)

        $manifest = Get-InstallerManifestObject
        return $manifest.Installers | Where-Object { $_.RelativePath -eq $RelativePath } | Select-Object -First 1
    }

    function Update-InstallerManifestEntry {
        param(
            [string]$ComponentName,
            [string]$InstallerPath,
            [string]$Source,
            [string]$SourceReference
        )

        $manifest = Get-InstallerManifestObject
        $relativePath = Get-RelativePathFromRoot -RootPath $OfflineCacheRoot -ChildPath $InstallerPath
        $hash = Get-FileSha256Hash -Path $InstallerPath
        $fileItem = Get-Item -Path $InstallerPath
        $entries = @($manifest.Installers)
        $existingEntry = $entries | Where-Object { $_.RelativePath -eq $relativePath } | Select-Object -First 1

        if ($existingEntry) {
            $existingEntry.ComponentName = $ComponentName
            $existingEntry.FileName = $fileItem.Name
            $existingEntry.SizeBytes = [int64]$fileItem.Length
            $existingEntry.Sha256 = $hash
            $existingEntry.Source = $Source
            $existingEntry.SourceReference = $SourceReference
            $existingEntry.UpdatedUtc = Get-UtcTimestamp
        }
        else {
            $entries += [pscustomobject]@{
                ComponentName   = $ComponentName
                RelativePath    = $relativePath
                FileName        = $fileItem.Name
                SizeBytes       = [int64]$fileItem.Length
                Sha256          = $hash
                Source          = $Source
                SourceReference = $SourceReference
                UpdatedUtc      = Get-UtcTimestamp
            }
            $manifest.Installers = $entries
        }

        Save-InstallerManifest -Manifest $manifest
        return Get-InstallerManifestEntry -RelativePath $relativePath
    }

    function Test-InstallerManifestHash {
        param(
            [string]$ComponentName,
            [string]$InstallerPath,
            [psobject]$LogContext = $null
        )

        $relativePath = Get-RelativePathFromRoot -RootPath $OfflineCacheRoot -ChildPath $InstallerPath
        $entry = Get-InstallerManifestEntry -RelativePath $relativePath
        if ($null -eq $entry) {
            Write-Detail -Level 'WARN' -Message "Kein Manifest-Eintrag fuer $ComponentName gefunden. Die Datei wird jetzt in das Manifest aufgenommen."
            Write-ComponentLogEntry -Context $LogContext -Level 'WARN' -Message 'Kein Manifest-Eintrag gefunden. Datei wird nun in das Manifest aufgenommen.'
            Update-InstallerManifestEntry -ComponentName $ComponentName -InstallerPath $InstallerPath -Source 'cache-untracked' -SourceReference '' | Out-Null
            return
        }

        $currentHash = Get-FileSha256Hash -Path $InstallerPath
        if ($currentHash -ne $entry.Sha256) {
            throw "Hash-Pruefung fuer $ComponentName fehlgeschlagen. Erwartet: $($entry.Sha256), gefunden: $currentHash. Bitte den Offline-Cache neu vorbereiten."
        }

        Write-ComponentLogEntry -Context $LogContext -Level 'OK' -Message "SHA256 validiert: $currentHash"
    }

    function Get-ResumeTaskCommandLine {
        $powershellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $argumentList = @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            (Format-CommandArgument -Value $script:SetupScriptPath),
            '-SetupStatePath',
            (Format-CommandArgument -Value $SetupStatePath),
            '-EnableAutoResumeScheduledTask:$true',
            '-ResumeScheduledTaskName',
            (Format-CommandArgument -Value $ResumeScheduledTaskName)
        )

        return [pscustomobject]@{
            Execute   = $powershellPath
            Arguments = ($argumentList -join ' ')
        }
    }

    function Register-ResumeScheduledTaskIfPossible {
        param([string[]]$Reasons)

        $logContext = New-ComponentLogContext -Component 'Setup Auto Resume' -Action 'register-scheduled-task'
        try {
            if (-not $EnableAutoResumeScheduledTask) {
                Write-Detail -Level 'WARN' -Message 'Automatische Fortsetzung per Scheduled Task ist deaktiviert.'
                Write-ComponentLogEntry -Context $logContext -Level 'WARN' -Message 'Auto-Resume deaktiviert.'
                Complete-ComponentLog -Context $logContext -Outcome 'skipped' -ExitCode 0 -Notes @('AutoResumeDisabled')
                return $false
            }

            if (-not (Test-IsAdministrator)) {
                Write-Detail -Level 'WARN' -Message 'Kein Administrator-Kontext. Scheduled Task fuer Auto-Resume kann nicht registriert werden.'
                Write-ComponentLogEntry -Context $logContext -Level 'WARN' -Message 'Administratorrechte fehlen.'
                Complete-ComponentLog -Context $logContext -Outcome 'skipped' -ExitCode 0 -Notes @('NotAdministrator')
                return $false
            }

            $requiredCommands = @('Register-ScheduledTask', 'New-ScheduledTaskAction', 'New-ScheduledTaskTrigger', 'New-ScheduledTaskSettingsSet', 'New-ScheduledTaskPrincipal')
            foreach ($commandName in $requiredCommands) {
                if (-not (Test-CommandAvailable -CommandName $commandName)) {
                    Write-Detail -Level 'WARN' -Message "Cmdlet $commandName ist nicht verfuegbar. Scheduled Task fuer Auto-Resume kann nicht registriert werden."
                    Write-ComponentLogEntry -Context $logContext -Level 'WARN' -Message "Cmdlet fehlt: $commandName"
                    Complete-ComponentLog -Context $logContext -Outcome 'skipped' -ExitCode 0 -Notes @("MissingCommand:$commandName")
                    return $false
                }
            }

            $taskCommandLine = Get-ResumeTaskCommandLine
            Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message "Execute: $($taskCommandLine.Execute)"
            Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message "Arguments: $($taskCommandLine.Arguments)"

            if (Test-CommandAvailable -CommandName 'Get-ScheduledTask') {
                $existingTask = Get-ScheduledTask -TaskName $ResumeScheduledTaskName -ErrorAction SilentlyContinue
                if ($existingTask) {
                    Unregister-ScheduledTask -TaskName $ResumeScheduledTaskName -Confirm:$false -ErrorAction SilentlyContinue
                }
            }

            $taskAction = New-ScheduledTaskAction -Execute $taskCommandLine.Execute -Argument $taskCommandLine.Arguments
            $taskTrigger = New-ScheduledTaskTrigger -AtStartup
            $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
            $taskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

            Register-ScheduledTask -TaskName $ResumeScheduledTaskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Principal $taskPrincipal -Force | Out-Null

            $script:SetupState.ResumeTaskRegistered = $true
            $script:SetupState.ResumeTaskName = $ResumeScheduledTaskName
            Add-SetupCompletedAction -Action 'scheduled-task:registered'
            Add-SetupNote -Note ('Auto-Resume Scheduled Task registriert: ' + $ResumeScheduledTaskName)
            Write-Detail -Level 'OK' -Message "Scheduled Task fuer automatische Fortsetzung registriert: $ResumeScheduledTaskName"
            Write-ComponentLogEntry -Context $logContext -Level 'OK' -Message ('Gruende: ' + ($Reasons -join ', '))
            Complete-ComponentLog -Context $logContext -Outcome 'success' -ExitCode 0
            return $true
        }
        catch {
            Write-Detail -Level 'WARN' -Message "Scheduled Task fuer Auto-Resume konnte nicht registriert werden: $($_.Exception.Message)"
            Write-ComponentLogEntry -Context $logContext -Level 'ERROR' -Message $_.Exception.Message
            Complete-ComponentLog -Context $logContext -Outcome 'error' -ExitCode 1 -Notes @($_.Exception.Message)
            return $false
        }
    }

    function Unregister-ResumeScheduledTaskIfPresent {
        $logContext = New-ComponentLogContext -Component 'Setup Auto Resume' -Action 'remove-scheduled-task'
        try {
            if (-not (Test-CommandAvailable -CommandName 'Unregister-ScheduledTask')) {
                Complete-ComponentLog -Context $logContext -Outcome 'skipped' -ExitCode 0 -Notes @('Unregister-ScheduledTaskNotAvailable')
                return
            }

            $removed = $false
            if (Test-CommandAvailable -CommandName 'Get-ScheduledTask') {
                $existingTask = Get-ScheduledTask -TaskName $ResumeScheduledTaskName -ErrorAction SilentlyContinue
                if ($existingTask) {
                    Unregister-ScheduledTask -TaskName $ResumeScheduledTaskName -Confirm:$false -ErrorAction SilentlyContinue
                    $removed = $true
                }
            }
            else {
                Unregister-ScheduledTask -TaskName $ResumeScheduledTaskName -Confirm:$false -ErrorAction SilentlyContinue
                $removed = $true
            }

            if ($removed) {
                Write-Detail -Level 'OK' -Message "Scheduled Task fuer Auto-Resume entfernt: $ResumeScheduledTaskName"
                Write-ComponentLogEntry -Context $logContext -Level 'OK' -Message 'Scheduled Task entfernt.'
                Add-SetupCompletedAction -Action 'scheduled-task:removed'
                $script:SetupState.ResumeTaskRegistered = $false
                Save-SetupState -State $script:SetupState
                Complete-ComponentLog -Context $logContext -Outcome 'success' -ExitCode 0
            }
            else {
                Complete-ComponentLog -Context $logContext -Outcome 'skipped' -ExitCode 0 -Notes @('TaskNotFound')
            }
        }
        catch {
            Write-ComponentLogEntry -Context $logContext -Level 'ERROR' -Message $_.Exception.Message
            Complete-ComponentLog -Context $logContext -Outcome 'error' -ExitCode 1 -Notes @($_.Exception.Message)
        }
    }

    function Write-SetupRunSummary {
        param(
            [ValidateSet('success', 'pending-reboot', 'failed', 'prepared-cache')]
            [string]$FinalStatus,
            [string]$Message = ''
        )

        if ($null -eq $script:SetupState -or [string]::IsNullOrWhiteSpace($script:CurrentLogSessionDir)) {
            return
        }

        $summaryJsonPath = Join-Path $script:CurrentLogSessionDir 'run-summary.json'
        $summaryMarkdownPath = Join-Path $script:CurrentLogSessionDir 'run-summary.md'

        $summary = [pscustomobject]@{
            RunId                 = $script:SetupState.RunId
            FinalStatus           = $FinalStatus
            Message               = $Message
            LastPhase             = $script:SetupState.LastPhase
            PendingReboot         = $script:SetupState.PendingReboot
            PendingRebootReasons  = @($script:SetupState.PendingRebootReasons)
            ResumeTaskName        = $script:SetupState.ResumeTaskName
            ResumeTaskRegistered  = $script:SetupState.ResumeTaskRegistered
            CompletedActions      = @($script:SetupState.CompletedActions)
            Notes                 = @($script:SetupState.Notes)
            ComponentLogs         = @($script:SetupState.ComponentLogs)
            InstallerManifestPath = $InstallerManifestPath
            GeneratedUtc          = Get-UtcTimestamp
        }

        $summary | ConvertTo-Json -Depth 12 | Set-Content -Path $summaryJsonPath -Encoding UTF8

        $markdownLines = @(
            '# Setup Run Summary',
            '',
            ('- RunId: `{0}`' -f $summary.RunId),
            ('- FinalStatus: `{0}`' -f $summary.FinalStatus),
            ('- LastPhase: `{0}`' -f $summary.LastPhase),
            ('- PendingReboot: `{0}`' -f $summary.PendingReboot),
            ('- ResumeTaskRegistered: `{0}`' -f $summary.ResumeTaskRegistered),
            ('- InstallerManifestPath: `{0}`' -f $summary.InstallerManifestPath)
        )

        if (-not [string]::IsNullOrWhiteSpace($Message)) {
            $markdownLines += ''
            $markdownLines += '## Message'
            $markdownLines += ''
            $markdownLines += $Message
        }

        if ($summary.PendingRebootReasons.Count -gt 0) {
            $markdownLines += ''
            $markdownLines += '## Pending Reboot Reasons'
            $markdownLines += ''
            foreach ($reason in $summary.PendingRebootReasons) {
                $markdownLines += ('- {0}' -f $reason)
            }
        }

        if ($summary.CompletedActions.Count -gt 0) {
            $markdownLines += ''
            $markdownLines += '## Completed Actions'
            $markdownLines += ''
            foreach ($action in $summary.CompletedActions) {
                $markdownLines += ('- {0}' -f $action)
            }
        }

        if ($summary.Notes.Count -gt 0) {
            $markdownLines += ''
            $markdownLines += '## Notes'
            $markdownLines += ''
            foreach ($note in $summary.Notes) {
                $markdownLines += ('- {0}' -f $note)
            }
        }

        if ($summary.ComponentLogs.Count -gt 0) {
            $markdownLines += ''
            $markdownLines += '## Component Logs'
            $markdownLines += ''
            foreach ($componentLog in $summary.ComponentLogs) {
                $markdownLines += ('- {0} / {1}: {2} (ExitCode: {3})' -f $componentLog.Component, $componentLog.Action, $componentLog.Outcome, $componentLog.ExitCode)
            }
        }

        $markdownLines | Set-Content -Path $summaryMarkdownPath -Encoding UTF8
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
        $registered = Register-ResumeScheduledTaskIfPossible -Reasons $Reasons
        if ($registered) {
            Write-Detail -Level 'INFO' -Message 'Auto-Resume wurde registriert. Das Setup setzt sich nach dem Reboot automatisch fort.'
        }
        else {
            Write-Detail -Level 'WARN' -Message 'Auto-Resume wurde nicht registriert. Bitte nach dem Reboot das Skript erneut starten.'
        }

        Write-Detail -Level 'WARN' -Message ('Neustart erforderlich oder ausstehend: ' + (($Reasons | Sort-Object -Unique) -join ', '))
        Write-Detail -Level 'WARN' -Message "Nach dem Reboot dieses Skript erneut aufrufen. State-Datei: $SetupStatePath"
        Write-SetupRunSummary -FinalStatus 'pending-reboot' -Message 'Setup wurde kontrolliert pausiert und wartet auf einen Neustart.'

        if ($OfferRestartAtEnd) {
            $uniqueReasons = @($Reasons | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
            if ($RestartAutomaticallyIfNeeded) {
                try {
                    Write-Detail -Level 'WARN' -Message 'Automatischer Neustart ist aktiviert. Der Server wird jetzt neu gestartet.'
                    Restart-Computer -Force
                }
                catch {
                    Write-Detail -Level 'WARN' -Message "Automatischer Neustart konnte nicht gestartet werden: $($_.Exception.Message)"
                }
            }
            elseif (Test-InteractiveSession) {
                $shouldRestartNow = Read-YesNoDecision -Caption 'Neustart empfohlen' -Question ("Das Setup kann jetzt neu starten und danach fortsetzen. Neustart jetzt ausfuehren? Gruende: " + ($uniqueReasons -join ', ')) -DefaultYes $true
                if ($shouldRestartNow) {
                    try {
                        Restart-Computer -Force
                    }
                    catch {
                        Write-Detail -Level 'WARN' -Message "Neustart konnte nicht gestartet werden: $($_.Exception.Message)"
                    }
                }
                else {
                    Write-Detail -Level 'INFO' -Message 'Neustart wurde nicht automatisch ausgelost. Bitte den Server zeitnah manuell neu starten.'
                }
            }
            else {
                Write-Detail -Level 'INFO' -Message 'Nicht-interaktive Sitzung erkannt. Ein sofortiger Neustart wird daher nicht abgefragt.'
            }
        }

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
        $isServer = ($os.ProductType -eq 3) -or ($os.Caption -match 'Windows Server')

        $serverProfile = switch ($buildNumber) {
            9600 { 'Windows Server 2012 R2' }
            14393 { 'Windows Server 2016' }
            17763 { 'Windows Server 2019' }
            20348 { 'Windows Server 2022' }
            26100 { 'Windows Server 2025' }
            default { $null }
        }

        if ($isServer -and ($serverProfile -or $buildNumber -ge 9600)) {
            if (-not $serverProfile) {
                $serverProfile = $os.Caption
            }

            $preferredNote = if ($buildNumber -in 17763, 20348, 26100) {
                'Bevorzugtes Standardprofil erkannt.'
            }
            elseif ($buildNumber -eq 9600) {
                'Aelteres Serverprofil erkannt. Installation wird toleriert; Python-/IIS-Kompatibilitaet sollte auf dem Host zusaetzlich validiert werden.'
            }
            else {
                'Unterstuetzt, aber 2019/2022/2025 sind als Standardprofil bevorzugt.'
            }

            return New-ComponentStatus -Status 'OK' -Component 'Windows Server Basisprofil' -Purpose 'Betrieb der V2-Management-Server-Rolle auf Windows Server ab Build 9600; bevorzugt 2019/2022/2025.' -Detail "$serverProfile (Build $buildNumber). $preferredNote" -Required $true -Present $true
        }

        return New-ComponentStatus -Status 'WARN' -Component 'Windows Server Basisprofil' -Purpose 'Betrieb der V2-Management-Server-Rolle auf Windows Server ab Build 9600; bevorzugt 2019/2022/2025.' -Detail "Erkannt: $($os.Caption) (Build $buildNumber). Fuer den Management Server werden Windows-Server-Profile ab Build 9600 erwartet; 2019, 2022 oder 2025 werden bevorzugt." -Required $true -Present $false
    }

    function Get-WindowsFeatureStatus {
        param(
            [string]$FeatureName,
            [string]$Component,
            [string]$Purpose,
            [bool]$Required
        )

        Import-ServerManagerModuleIfAvailable

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
        $selected = Find-PythonRuntime

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

            if ((Get-ResolvedPathString -Path $ExplicitPath) -ne $preferredCachePath) {
                Copy-Item -Path $ExplicitPath -Destination $preferredCachePath -Force
                Write-ComponentLogEntry -Context $LogContext -Level 'INFO' -Message "Expliziter Installer wurde in den Offline-Cache kopiert: $preferredCachePath"
            }

            $manifestEntry = Update-InstallerManifestEntry -ComponentName $ComponentName -InstallerPath $preferredCachePath -Source 'explicit-path' -SourceReference $ExplicitPath
            Write-ComponentLogEntry -Context $LogContext -Level 'OK' -Message "Manifest aktualisiert: $($manifestEntry.RelativePath) ($($manifestEntry.Sha256))"
            return [pscustomobject]@{
                Path      = $preferredCachePath
                Source    = 'explicit-path'
                CachePath = $preferredCachePath
            }
        }

        if (Test-Path -Path $preferredCachePath) {
            Test-InstallerManifestHash -ComponentName $ComponentName -InstallerPath $preferredCachePath -LogContext $LogContext
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
                Write-ComponentLogEntry -Context $LogContext -Level 'INFO' -Message "Cache-Treffer gefunden und auf Standardnamen vereinheitlicht: $preferredCachePath"
                Update-InstallerManifestEntry -ComponentName $ComponentName -InstallerPath $preferredCachePath -Source 'offline-cache-pattern' -SourceReference $match.FullName | Out-Null
                Test-InstallerManifestHash -ComponentName $ComponentName -InstallerPath $preferredCachePath -LogContext $LogContext
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
        $manifestEntry = Update-InstallerManifestEntry -ComponentName $ComponentName -InstallerPath $downloadedPath -Source 'downloaded-and-cached' -SourceReference ($Urls -join ', ')
        Write-ComponentLogEntry -Context $LogContext -Level 'OK' -Message "Manifest aktualisiert: $($manifestEntry.RelativePath) ($($manifestEntry.Sha256))"
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
            $targetDir = ''
            if (Test-IsAdministrator) {
                $argumentList += 'InstallAllUsers=1'
                $targetDir = Join-Path $env:ProgramFiles 'Python313'
            }
            else {
                Write-Detail -Level 'WARN' -Message 'Keine Administratorrechte erkannt. Python wird fuer den aktuellen Benutzer installiert.'
                Write-ComponentLogEntry -Context $logContext -Level 'WARN' -Message 'Keine Administratorrechte erkannt. Installation erfolgt benutzerbezogen.'
                $argumentList += 'InstallAllUsers=0'
                $targetDir = Join-Path $env:LocalAppData 'Programs\Python\Python313'
            }

            $argumentList += ('TargetDir={0}' -f $targetDir)
            Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message "Python-Zielverzeichnis: $targetDir"

            Write-Section -Message 'Installiere Python 3.13.x'
            $process = Start-Process -FilePath $installerSource.Path -ArgumentList $argumentList -Wait -PassThru
            if ($process.ExitCode -notin 0, 3010) {
                throw "Python 3.13.x konnte nicht installiert werden. Exitcode: $($process.ExitCode)"
            }

            $detectedPythonRuntime = Find-PythonRuntime -PreferredPaths @(
                (Join-Path $targetDir 'python.exe'),
                (Join-Path $targetDir 'python3.exe')
            )

            if ($null -ne $detectedPythonRuntime) {
                Write-ComponentLogEntry -Context $logContext -Level 'OK' -Message "Python nach Installation erkannt: $($detectedPythonRuntime.Executable)"
            }
            else {
                Write-ComponentLogEntry -Context $logContext -Level 'WARN' -Message 'Python wurde nach der Installation im selben Lauf noch nicht erneut erkannt.'
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
                PythonRuntime  = $detectedPythonRuntime
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
            PythonRuntime  = $null
        }

        if (-not $InstallMissingRequiredComponents) {
            return $result
        }

        $installWindowsFeatureCommand = Get-WindowsFeatureInstallCommandName
        if ([string]::IsNullOrWhiteSpace($installWindowsFeatureCommand)) {
            Write-Detail -Level 'WARN' -Message 'Weder Install-WindowsFeature noch Add-WindowsFeature sind auf diesem Host verfuegbar. Windows-Features konnten nicht automatisch installiert werden.'
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
                Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message "$installWindowsFeatureCommand Name=$($feature.InstallName)"
                $installCommand = Get-Command -Name $installWindowsFeatureCommand -ErrorAction Stop
                $featureArguments = @{
                    Name        = $feature.InstallName
                    ErrorAction = 'Stop'
                }
                if ($installWindowsFeatureCommand -eq 'Install-WindowsFeature') {
                    $featureArguments.IncludeManagementTools = $true
                }

                $installResult = & $installCommand @featureArguments
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

        if ((-not $InstallMissingRequiredComponents) -and (-not $InstallOptionalComponents)) {
            return $result
        }

        $pythonStatus = $Statuses | Where-Object { $_.Component -eq 'Python 3.13.x' } | Select-Object -First 1
        if ($InstallMissingRequiredComponents -and $pythonStatus -and (-not $pythonStatus.Present)) {
            $pythonInstallResult = Install-PythonRuntime
            if ($null -ne $pythonInstallResult.PythonRuntime) {
                $result.PythonRuntime = $pythonInstallResult.PythonRuntime
            }
            if ($pythonInstallResult.RebootRequired) {
                $result.RebootRequired = $true
                $result.RebootReasons += @($pythonInstallResult.RebootReasons)
            }
        }

        $urlRewriteStatus = $Statuses | Where-Object { $_.Component -eq 'IIS URL Rewrite' } | Select-Object -First 1
        if ($InstallMissingRequiredComponents -and $urlRewriteStatus -and (-not $urlRewriteStatus.Present)) {
            try {
                $rewriteSourceContext = New-ComponentLogContext -Component 'IIS URL Rewrite' -Action 'resolve-installer'
                $rewriteInstaller = Get-InstallerSource -ComponentName 'IIS URL Rewrite' -CacheSubPath 'iis\url-rewrite' -PreferredFileName 'rewrite_amd64_en-US.msi' -SearchPatterns @('rewrite*.msi', '*url*rewrite*.msi') -ExplicitPath $UrlRewriteInstallerPath -Urls (Get-UrlRewriteInstallerUrls) -LogContext $rewriteSourceContext
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
                    $arrInstaller = Get-InstallerSource -ComponentName 'IIS Application Request Routing (ARR)' -CacheSubPath 'iis\arr' -PreferredFileName 'arr-x64.msi' -SearchPatterns @('*application*request*routing*.msi', '*arr*.msi') -ExplicitPath $ArrInstallerPath -Urls (Get-ArrInstallerUrls) -LogContext $arrSourceContext
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

    function Resolve-OptionalComponentSelection {
        param([object[]]$Statuses)

        if ($InstallOptionalComponents) {
            return $true
        }

        $supportedOptionals = @(
            $Statuses | Where-Object { $_.Component -eq 'IIS Application Request Routing (ARR)' -and -not $_.Present }
        ) | Where-Object { $null -ne $_ }

        if (-not $supportedOptionals) {
            return $false
        }

        $supportedNames = ($supportedOptionals | Select-Object -ExpandProperty Component | Sort-Object -Unique)
        if (-not $OfferOptionalComponents) {
            Write-Detail -Level 'INFO' -Message ('Optionale Komponenten verfuegbar, aber Nachfrage ist deaktiviert: ' + ($supportedNames -join ', '))
            return $false
        }

        if (-not (Test-InteractiveSession)) {
            Write-Detail -Level 'INFO' -Message ('Optionale Komponenten verfuegbar. In nicht-interaktiver Sitzung bitte bei Bedarf explizit mit -InstallOptionalComponents:$true starten: ' + ($supportedNames -join ', '))
            return $false
        }

        Write-Section -Message 'Optionale Komponenten erkannt'
        Write-Detail -Level 'INFO' -Message ('Optional installierbar in diesem Lauf: ' + ($supportedNames -join ', '))
        $shouldInstallOptionals = Read-YesNoDecision -Caption 'Optionale Komponenten' -Question ('Sollen die aktuell unterstuetzten optionalen Komponenten jetzt mit installiert werden? ' + ($supportedNames -join ', ')) -DefaultYes $false
        if ($shouldInstallOptionals) {
            $script:InstallOptionalComponents = $true
            Update-SetupResumeConfiguration
            Add-SetupNote -Note ('Optionale Komponenten fuer diesen Lauf aktiviert: ' + ($supportedNames -join ', '))
            return $true
        }

        Add-SetupNote -Note ('Optionale Komponenten wurden angeboten, aber nicht automatisch installiert: ' + ($supportedNames -join ', '))
        return $false
    }

    function Copy-DirectoryTree {
        param(
            [string]$SourcePath,
            [string]$DestinationPath,
            [psobject]$LogContext,
            [string]$Label
        )

        if (-not (Test-Path -Path $SourcePath)) {
            Write-ComponentLogEntry -Context $LogContext -Level 'WARN' -Message "Quelle uebersprungen (nicht gefunden): $SourcePath"
            return
        }

        New-DirectoryIfMissing -Path $DestinationPath
        $sourceItems = Get-ChildItem -Path $SourcePath -Force -ErrorAction SilentlyContinue
        if (-not $sourceItems) {
            Write-ComponentLogEntry -Context $LogContext -Level 'INFO' -Message "$Label ist leer. Zielordner wurde dennoch vorbereitet: $DestinationPath"
            return
        }

        Copy-Item -Path (Join-Path $SourcePath '*') -Destination $DestinationPath -Recurse -Force
        Write-ComponentLogEntry -Context $LogContext -Level 'OK' -Message "$Label kopiert: $SourcePath -> $DestinationPath"
    }

    function Copy-ProjectDataDirectories {
        $logContext = New-ComponentLogContext -Component 'Project Data Copy' -Action 'copy-runtime-directories'
        try {
            Write-Section -Message 'Kopiere Projektdaten in definierte Betriebsordner'
            New-DirectoryIfMissing -Path $ProjectDataRoot

            $copyMap = @(
                @{ Source = (Join-Path $projectRoot 'config'); Destination = (Join-Path $ProjectDataRoot 'config'); Label = 'config' },
                @{ Source = (Join-Path $projectRoot 'data'); Destination = (Join-Path $ProjectDataRoot 'data'); Label = 'data' },
                @{ Source = (Join-Path $projectRoot 'DOC'); Destination = (Join-Path $ProjectDataRoot 'DOC'); Label = 'DOC' },
                @{ Source = (Join-Path $projectRoot 'modules'); Destination = (Join-Path $ProjectDataRoot 'modules'); Label = 'modules' }
            )

            foreach ($item in $copyMap) {
                Copy-DirectoryTree -SourcePath $item.Source -DestinationPath $item.Destination -LogContext $logContext -Label $item.Label
            }

            Add-SetupCompletedAction -Action 'copy:project-data'
            Add-SetupNote -Note ('Projektdaten wurden nach ' + $ProjectDataRoot + ' kopiert.')
            Complete-ComponentLog -Context $logContext -Outcome 'success' -ExitCode 0
        }
        catch {
            Write-ComponentLogEntry -Context $logContext -Level 'ERROR' -Message $_.Exception.Message
            Complete-ComponentLog -Context $logContext -Outcome 'error' -ExitCode 1 -Notes @($_.Exception.Message)
            throw
        }
    }

    function Write-IisReverseProxyWebConfig {
        param([string]$TargetPath)

        $webConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <rewrite>
      <rules>
        <rule name="easyONBOARDING-V2-ReverseProxy" stopProcessing="true">
          <match url="(.*)" />
          <action type="Rewrite" url="http://127.0.0.1:$PythonBackendPort/{R:1}" appendQueryString="true" logRewrittenUrl="true" />
        </rule>
      </rules>
    </rewrite>
    <security>
      <authentication>
        <anonymousAuthentication enabled="false" />
        <windowsAuthentication enabled="true" />
      </authentication>
    </security>
    <httpProtocol>
      <customHeaders>
        <add name="X-Forwarded-Proto" value="http" />
      </customHeaders>
    </httpProtocol>
  </system.webServer>
</configuration>
"@

        Set-Content -Path $TargetPath -Value $webConfigContent -Encoding UTF8
    }

    function Import-WebAdministrationModule {
        if (Get-Module -Name 'WebAdministration') {
            return $true
        }

        if (Get-Module -ListAvailable -Name 'WebAdministration') {
            Import-Module -Name 'WebAdministration' -ErrorAction Stop
            return $true
        }

        $installWindowsFeatureCommand = Get-WindowsFeatureInstallCommandName
        if (-not [string]::IsNullOrWhiteSpace($installWindowsFeatureCommand) -and $InstallMissingRequiredComponents -and (Test-IsAdministrator)) {
            $installCommand = Get-Command -Name $installWindowsFeatureCommand -ErrorAction Stop
            $featureArguments = @{
                Name        = 'Web-Scripting-Tools'
                ErrorAction = 'Stop'
            }
            if ($installWindowsFeatureCommand -eq 'Install-WindowsFeature') {
                $featureArguments.IncludeManagementTools = $true
            }

            & $installCommand @featureArguments | Out-Null
            if (Get-Module -ListAvailable -Name 'WebAdministration') {
                Import-Module -Name 'WebAdministration' -ErrorAction Stop
                return $true
            }
        }

        return $false
    }

    function Configure-IisHosting {
        $logContext = New-ComponentLogContext -Component 'IIS Configuration' -Action 'configure-site-and-proxy'
        $appCmdPath = Join-Path $env:SystemRoot 'System32\inetsrv\appcmd.exe'

        try {
            if (-not (Test-IsAdministrator)) {
                throw 'Fuer die IIS-Konfiguration werden Administratorrechte benoetigt.'
            }

            if (-not (Import-WebAdministrationModule)) {
                throw 'Das Modul WebAdministration ist nicht verfuegbar. Bitte IIS Management Scripts and Tools installieren.'
            }

            Write-Section -Message 'Konfiguriere optionales IIS-Betriebsprofil'
            New-DirectoryIfMissing -Path $DeploymentRoot
            New-DirectoryIfMissing -Path $IisPhysicalPath

            if (-not (Test-Path -Path "IIS:\AppPools\$IisAppPoolName")) {
                New-Item -Path "IIS:\AppPools\$IisAppPoolName" | Out-Null
            }

            Set-ItemProperty -Path "IIS:\AppPools\$IisAppPoolName" -Name managedRuntimeVersion -Value ''
            Set-ItemProperty -Path "IIS:\AppPools\$IisAppPoolName" -Name managedPipelineMode -Value 'Integrated'
            Set-ItemProperty -Path "IIS:\AppPools\$IisAppPoolName" -Name autoStart -Value $true

            $site = Get-Website -Name $IisSiteName -ErrorAction SilentlyContinue
            if ($site) {
                Set-ItemProperty -Path "IIS:\Sites\$IisSiteName" -Name physicalPath -Value $IisPhysicalPath
                Set-ItemProperty -Path "IIS:\Sites\$IisSiteName" -Name applicationPool -Value $IisAppPoolName
            }
            else {
                $newWebsiteParameters = @{
                    Name            = $IisSiteName
                    Port            = $IisPort
                    PhysicalPath    = $IisPhysicalPath
                    ApplicationPool = $IisAppPoolName
                    Force           = $true
                }
                if (-not [string]::IsNullOrWhiteSpace($IisHostHeader)) {
                    $newWebsiteParameters.HostHeader = $IisHostHeader
                }

                New-Website @newWebsiteParameters | Out-Null
            }

            $expectedBindingInformation = '*:{0}:{1}' -f $IisPort, $IisHostHeader
            $binding = Get-WebBinding -Name $IisSiteName -Protocol 'http' -ErrorAction SilentlyContinue | Where-Object { $_.bindingInformation -eq $expectedBindingInformation } | Select-Object -First 1
            if (-not $binding) {
                New-WebBinding -Name $IisSiteName -Protocol 'http' -Port $IisPort -IPAddress '*' -HostHeader $IisHostHeader | Out-Null
            }

            $webConfigPath = Join-Path $IisPhysicalPath 'web.config'
            Write-IisReverseProxyWebConfig -TargetPath $webConfigPath
            Write-ComponentLogEntry -Context $logContext -Level 'OK' -Message "web.config geschrieben: $webConfigPath"

            Set-WebConfigurationProperty -PSPath 'IIS:\' -Location $IisSiteName -Filter 'system.webServer/security/authentication/anonymousAuthentication' -Name enabled -Value $false
            Set-WebConfigurationProperty -PSPath 'IIS:\' -Location $IisSiteName -Filter 'system.webServer/security/authentication/windowsAuthentication' -Name enabled -Value $true

            if (Test-Path -Path $appCmdPath) {
                $proxyArgs = @('set', 'config', '-section:system.webServer/proxy', '/enabled:"True"', '/preserveHostHeader:"True"', '/reverseRewriteHostInResponseHeaders:"False"', '/commit:apphost')
                $null = & $appCmdPath @proxyArgs 2>&1
                Write-ComponentLogEntry -Context $logContext -Level 'INFO' -Message 'ARR-Proxy-Option auf Serverebene wurde verarbeitet (sofern verfuegbar).'
            }

            Start-Website -Name $IisSiteName | Out-Null
            Add-SetupCompletedAction -Action 'iis:configured'
            Add-SetupNote -Note ('IIS-Site konfiguriert: ' + $IisSiteName + ' -> http://127.0.0.1:' + $PythonBackendPort)
            Complete-ComponentLog -Context $logContext -Outcome 'success' -ExitCode 0 -AdditionalFiles @($webConfigPath)
        }
        catch {
            Write-ComponentLogEntry -Context $logContext -Level 'ERROR' -Message $_.Exception.Message
            Complete-ComponentLog -Context $logContext -Outcome 'error' -ExitCode 1 -Notes @($_.Exception.Message)
            throw
        }
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
        Save-InstallerManifest -Manifest (Get-InstallerManifestObject)

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
            $rewriteInstaller = Get-InstallerSource -ComponentName 'IIS URL Rewrite' -CacheSubPath 'iis\url-rewrite' -PreferredFileName 'rewrite_amd64_en-US.msi' -SearchPatterns @('rewrite*.msi', '*url*rewrite*.msi') -ExplicitPath $UrlRewriteInstallerPath -Urls (Get-UrlRewriteInstallerUrls) -LogContext $rewriteCacheContext
            Write-ComponentLogEntry -Context $rewriteCacheContext -Level 'OK' -Message "Offline-Cache bereit: $($rewriteInstaller.Path)"
            Complete-ComponentLog -Context $rewriteCacheContext -Outcome 'success' -ExitCode 0
            Add-SetupCompletedAction -Action 'cache:iis-url-rewrite'
        }
        catch {
            Write-Detail -Level 'WARN' -Message "URL-Rewrite-Installer konnte nicht fuer den Offline-Cache vorbereitet werden: $($_.Exception.Message)"
        }

        try {
            $arrCacheContext = New-ComponentLogContext -Component 'IIS Application Request Routing (ARR)' -Action 'prepare-offline-cache'
            $arrInstaller = Get-InstallerSource -ComponentName 'IIS Application Request Routing (ARR)' -CacheSubPath 'iis\arr' -PreferredFileName 'arr-x64.msi' -SearchPatterns @('*application*request*routing*.msi', '*arr*.msi') -ExplicitPath $ArrInstallerPath -Urls (Get-ArrInstallerUrls) -LogContext $arrCacheContext
            Write-ComponentLogEntry -Context $arrCacheContext -Level 'OK' -Message "Offline-Cache bereit: $($arrInstaller.Path)"
            Complete-ComponentLog -Context $arrCacheContext -Outcome 'success' -ExitCode 0
            Add-SetupCompletedAction -Action 'cache:iis-arr'
        }
        catch {
            $expectedArrPath = Join-Path (Join-Path $OfflineCacheRoot 'iis\arr') 'arr-x64.msi'
            Write-Detail -Level 'WARN' -Message "ARR konnte nicht automatisch vorbereitet werden. Lege den MSI-Installer manuell unter '$expectedArrPath' ab oder nutze -ArrInstallerPath / -ArrInstallerUrl."
        }

        Write-Detail -Level 'OK' -Message "Offline-Cache vorbereitet unter: $OfflineCacheRoot"
        Write-Detail -Level 'OK' -Message "Installer-Manifest liegt unter: $InstallerManifestPath"
        Set-SetupPhase -Phase 'prepare-offline-cache-complete'
        Clear-SetupRebootPending
        Write-SetupRunSummary -FinalStatus 'prepared-cache' -Message 'Offline-Cache wurde vorbereitet.'
        Unregister-ResumeScheduledTaskIfPresent
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
    }

    Resolve-OptionalComponentSelection -Statuses $setupStatus.Statuses | Out-Null

    $pythonRuntimeForDependencies = $setupStatus.PythonRuntime

    if ($InstallMissingRequiredComponents -or $InstallOptionalComponents) {
        Set-SetupPhase -Phase 'install-external-prerequisites'
        $externalInstallResult = Install-ExternalPrerequisitesIfNeeded -Statuses $setupStatus.Statuses
        $pendingAfterExternal = Get-PendingRebootState
        if ($externalInstallResult.RebootRequired -or $pendingAfterExternal.IsPending) {
            $reasons = @($externalInstallResult.RebootReasons + $pendingAfterExternal.Reasons)
            Stop-ForPendingReboot -Phase 'post-external-prerequisites' -Reasons $reasons
            return
        }

        if ($null -ne $externalInstallResult.PythonRuntime) {
            $pythonRuntimeForDependencies = $externalInstallResult.PythonRuntime
        }

        Write-Section -Message 'Pruefe Status nach Installationsversuchen erneut'
        $setupStatus = Get-SetupStatus
        if ($null -eq $setupStatus.PythonRuntime -and $null -ne $pythonRuntimeForDependencies) {
            $setupStatus = Set-DetectedPythonRuntime -SetupStatus $setupStatus -PythonRuntime $pythonRuntimeForDependencies
        }
        Show-StatusTable -Statuses $setupStatus.Statuses
        Show-RequiredStatusSummary -Statuses $setupStatus.Statuses
    }
    elseif ($null -eq $pythonRuntimeForDependencies) {
        $pythonRuntimeForDependencies = $setupStatus.PythonRuntime
    }

    Set-SetupPhase -Phase 'install-python-dependencies'
    if ($null -eq $pythonRuntimeForDependencies) {
        $pythonRuntimeForDependencies = $setupStatus.PythonRuntime
    }

    Install-PythonDependencies -PythonRuntime $pythonRuntimeForDependencies -WithDevDependencySet $WithDevDependencies.IsPresent -AllowUnsupportedVersion $AllowUnsupportedPythonVersion.IsPresent

    if ($CopyProjectData) {
        Set-SetupPhase -Phase 'copy-project-data'
        Copy-ProjectDataDirectories
    }

    if ($ConfigureIis) {
        Set-SetupPhase -Phase 'configure-iis'
        Configure-IisHosting
    }

    Set-SetupPhase -Phase 'completed'
    Clear-SetupRebootPending
    Write-SetupRunSummary -FinalStatus 'success' -Message 'Setup wurde erfolgreich abgeschlossen.'
    Unregister-ResumeScheduledTaskIfPresent
    Clear-SetupStateFile
    Write-Detail -Level 'OK' -Message "Setup abgeschlossen. Komponenten-Logs liegen unter: $script:CurrentLogSessionDir"
}
catch {
    if ($null -ne $script:SetupState) {
        Add-SetupNote -Note ('Fehler: ' + $_.Exception.Message)
        Write-SetupRunSummary -FinalStatus 'failed' -Message $_.Exception.Message
    }

    throw
}
finally {
    Pop-Location
}
