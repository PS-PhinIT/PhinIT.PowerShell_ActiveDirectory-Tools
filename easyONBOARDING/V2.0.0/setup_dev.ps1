param(
    [switch]$WithDevDependencies,
    [switch]$CheckOnly,
    [bool]$InstallMissingRequiredComponents = $true,
    [bool]$InstallOptionalComponents = $false,
    [switch]$AllowUnsupportedPythonVersion,
    [string]$InstallerCacheDir = "$env:TEMP\easyonb-v2-setup",
    [string[]]$PythonVersionCandidates = @('3.13.5', '3.13.4', '3.13.3', '3.13.2', '3.13.1', '3.13.0'),
    [string]$PythonInstallerUrl = '',
    [string]$UrlRewriteInstallerUrl = 'https://download.microsoft.com/download/D/D/9/DD9A82C0-1D98-4C6E-A283-AB3A21A9EF57/rewrite_amd64_en-US.msi',
    [string]$ArrInstallerUrl = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
try { [Console]::InputEncoding = $utf8NoBom } catch {}
try { [Console]::OutputEncoding = $utf8NoBom } catch {}
try { $OutputEncoding = $utf8NoBom } catch {}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $projectRoot

try {
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

    function Save-WebFile {
        param(
            [string[]]$Urls,
            [string]$DestinationFileName
        )

        New-DirectoryIfMissing -Path $InstallerCacheDir
        $targetPath = Join-Path $InstallerCacheDir $DestinationFileName

        foreach ($url in $Urls) {
            if ([string]::IsNullOrWhiteSpace($url)) {
                continue
            }

            try {
                Write-Detail -Level 'INFO' -Message "Lade Installer herunter: $url"
                Invoke-WebRequest -Uri $url -OutFile $targetPath -UseBasicParsing
                if ((Test-Path -Path $targetPath) -and ((Get-Item -Path $targetPath).Length -gt 0)) {
                    Write-Detail -Level 'OK' -Message "Download erfolgreich: $targetPath"
                    return $targetPath
                }
            }
            catch {
                Write-Detail -Level 'WARN' -Message "Download fehlgeschlagen: $url ($($_.Exception.Message))"
            }
        }

        throw "Keiner der konfigurierten Download-Links konnte erfolgreich geladen werden: $($Urls -join ', ')"
    }

    function Install-MsiPackage {
        param(
            [string]$MsiPath,
            [string]$DisplayName
        )

        if (-not (Test-IsAdministrator)) {
            throw "Fuer die Installation von $DisplayName werden Administratorrechte benoetigt."
        }

        Write-Section -Message "Installiere $DisplayName"
        $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', $MsiPath, '/qn', '/norestart') -Wait -PassThru
        if ($process.ExitCode -notin 0, 3010) {
            throw "$DisplayName konnte nicht installiert werden. Exitcode: $($process.ExitCode)"
        }

        if ($process.ExitCode -eq 3010) {
            Write-Detail -Level 'WARN' -Message "$DisplayName meldet einen Reboot-Hinweis (3010)."
        }
        else {
            Write-Detail -Level 'OK' -Message "$DisplayName wurde installiert."
        }
    }

    function Install-PythonRuntime {
        $pythonUrls = @()
        if (-not [string]::IsNullOrWhiteSpace($PythonInstallerUrl)) {
            $pythonUrls += $PythonInstallerUrl
        }
        else {
            foreach ($version in $PythonVersionCandidates) {
                $pythonUrls += "https://www.python.org/ftp/python/$version/python-$version-amd64.exe"
            }
        }

        $installerPath = Save-WebFile -Urls $pythonUrls -DestinationFileName 'python-3.13-amd64.exe'
        $argumentList = @('/quiet', 'PrependPath=1', 'Include_pip=1', 'Include_launcher=1', 'Shortcuts=0', 'CompileAll=0')
        if (Test-IsAdministrator) {
            $argumentList += 'InstallAllUsers=1'
        }
        else {
            Write-Detail -Level 'WARN' -Message 'Keine Administratorrechte erkannt. Python wird fuer den aktuellen Benutzer installiert.'
            $argumentList += 'InstallAllUsers=0'
        }

        Write-Section -Message 'Installiere Python 3.13.x'
        $process = Start-Process -FilePath $installerPath -ArgumentList $argumentList -Wait -PassThru
        if ($process.ExitCode -notin 0, 3010) {
            throw "Python 3.13.x konnte nicht installiert werden. Exitcode: $($process.ExitCode)"
        }

        if ($process.ExitCode -eq 3010) {
            Write-Detail -Level 'WARN' -Message 'Python-Installer meldet einen Reboot-Hinweis (3010).'
        }
        else {
            Write-Detail -Level 'OK' -Message 'Python 3.13.x wurde installiert.'
        }
    }

    function Install-RequiredWindowsFeatures {
        param([object[]]$Statuses)

        if (-not $InstallMissingRequiredComponents) {
            return
        }

        if (-not (Test-CommandAvailable -CommandName 'Install-WindowsFeature')) {
            Write-Detail -Level 'WARN' -Message 'Install-WindowsFeature ist auf diesem Host nicht verfuegbar. Windows-Features konnten nicht automatisch installiert werden.'
            return
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
            Write-Section -Message "Installiere Windows-Feature: $($feature.Component) ($($feature.InstallName))"
            try {
                Install-WindowsFeature -Name $feature.InstallName -IncludeManagementTools -ErrorAction Stop | Out-Host
            }
            catch {
                Write-Detail -Level 'WARN' -Message "Windows-Feature $($feature.InstallName) konnte nicht automatisch installiert werden: $($_.Exception.Message)"
            }
        }
    }

    function Install-ExternalPrerequisitesIfNeeded {
        param([object[]]$Statuses)

        if (-not $InstallMissingRequiredComponents) {
            return
        }

        $pythonStatus = $Statuses | Where-Object { $_.Component -eq 'Python 3.13.x' } | Select-Object -First 1
        if ($pythonStatus -and (-not $pythonStatus.Present)) {
            Install-PythonRuntime
        }

        $urlRewriteStatus = $Statuses | Where-Object { $_.Component -eq 'IIS URL Rewrite' } | Select-Object -First 1
        if ($urlRewriteStatus -and (-not $urlRewriteStatus.Present)) {
            try {
                $rewriteInstaller = Save-WebFile -Urls @($UrlRewriteInstallerUrl) -DestinationFileName 'iis-url-rewrite.msi'
                Install-MsiPackage -MsiPath $rewriteInstaller -DisplayName 'IIS URL Rewrite'
            }
            catch {
                Write-Detail -Level 'WARN' -Message "IIS URL Rewrite konnte nicht automatisch installiert werden: $($_.Exception.Message)"
            }
        }

        if ($InstallOptionalComponents) {
            $arrStatus = $Statuses | Where-Object { $_.Component -eq 'IIS Application Request Routing (ARR)' } | Select-Object -First 1
            if ($arrStatus -and (-not $arrStatus.Present) -and (-not [string]::IsNullOrWhiteSpace($ArrInstallerUrl))) {
                try {
                    $arrInstaller = Save-WebFile -Urls @($ArrInstallerUrl) -DestinationFileName 'iis-arr.msi'
                    Install-MsiPackage -MsiPath $arrInstaller -DisplayName 'IIS Application Request Routing (ARR)'
                }
                catch {
                    Write-Detail -Level 'WARN' -Message "ARR konnte nicht automatisch installiert werden: $($_.Exception.Message)"
                }
            }
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

        $packageSpec = if ($WithDevDependencySet) { '.[dev]' } else { '.' }
        $pipArgs = @()
        $pipArgs += $PythonRuntime.Arguments
        $pipArgs += '-m'
        $pipArgs += 'pip'
        $pipArgs += 'install'
        $pipArgs += '-e'
        $pipArgs += $packageSpec

        Write-Section -Message "Installiere Python-Abhaengigkeiten ueber $($PythonRuntime.Label)"
        & $PythonRuntime.FilePath @pipArgs
    }

    Write-Section -Message 'Pruefe Management-Server-Basis und V2-Abhaengigkeiten'
    $setupState = Get-SetupStatus
    Show-StatusTable -Statuses $setupState.Statuses
    Show-RequiredStatusSummary -Statuses $setupState.Statuses

    if ($CheckOnly) {
        Write-Detail -Level 'INFO' -Message 'CheckOnly aktiv: Es wurden keine Komponenten und keine Python-Abhaengigkeiten installiert.'
        return
    }

    if ($InstallMissingRequiredComponents) {
        Install-RequiredWindowsFeatures -Statuses $setupState.Statuses
        Install-ExternalPrerequisitesIfNeeded -Statuses $setupState.Statuses

        Write-Section -Message 'Pruefe Status nach Installationsversuchen erneut'
        $setupState = Get-SetupStatus
        Show-StatusTable -Statuses $setupState.Statuses
        Show-RequiredStatusSummary -Statuses $setupState.Statuses
    }

    Install-PythonDependencies -PythonRuntime $setupState.PythonRuntime -WithDevDependencySet $WithDevDependencies.IsPresent -AllowUnsupportedVersion $AllowUnsupportedPythonVersion.IsPresent
}
finally {
    Pop-Location
}
