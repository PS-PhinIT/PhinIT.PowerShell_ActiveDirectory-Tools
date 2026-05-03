param(
    [Parameter(Mandatory = $true)]
    [string]$InputJsonPath,

    [Parameter(Mandatory = $false)]
    [string]$ConnectorName = "ad.user.search"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$startedAt = Get-Date

function Write-StructuredResult {
    param(
        [bool]$Success,
        [string]$Message,
        [hashtable]$Data,
        [string[]]$Warnings = @(),
        [string[]]$Errors = @(),
        [int]$ExitCode = 0
    )

    $response = [ordered]@{
        success         = $Success
        message         = $Message
        connector       = $ConnectorName
        warnings        = @($Warnings)
        errors          = @($Errors)
        data            = $Data
        audit_delta     = @()
        follow_up_tasks = @()
        duration_ms     = [int]((Get-Date) - $startedAt).TotalMilliseconds
    }

    $response | ConvertTo-Json -Depth 8
    exit $ExitCode
}

try {
    $inputPayload = Get-Content -Path $InputJsonPath -Raw | ConvertFrom-Json -Depth 8
    $payload = $inputPayload.payload
    $searchTerm = [string]$payload.search_term
    $maxResults = if ($payload.max_results) { [int]$payload.max_results } else { 25 }

    if ([string]::IsNullOrWhiteSpace($searchTerm)) {
        Write-StructuredResult -Success $false -Message 'Search term is required.' -Data @{} -Errors @('missing_search_term') -ExitCode 1
    }

    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-StructuredResult -Success $false -Message 'ActiveDirectory PowerShell module is not available on this host.' -Data @{} -Warnings @('Install RSAT Active Directory Tools on the management server.') -Errors @('missing_active_directory_module') -ExitCode 1
    }

    Import-Module ActiveDirectory -ErrorAction Stop

    $searchWildcard = "*$searchTerm*"
    $users = Get-ADUser -Filter {
        Name -like $searchWildcard -or
        SamAccountName -like $searchWildcard -or
        UserPrincipalName -like $searchWildcard -or
        mail -like $searchWildcard
    } -Properties mail, department, office, Enabled, UserPrincipalName, SamAccountName, GivenName, Surname -ResultSetSize $maxResults |
        Sort-Object Name |
        Select-Object `
            @{ Name = 'display_name'; Expression = { $_.Name } },
            @{ Name = 'given_name'; Expression = { $_.GivenName } },
            @{ Name = 'family_name'; Expression = { $_.Surname } },
            @{ Name = 'sam_account_name'; Expression = { $_.SamAccountName } },
            @{ Name = 'user_principal_name'; Expression = { $_.UserPrincipalName } },
            @{ Name = 'primary_mail'; Expression = { $_.mail } },
            @{ Name = 'department'; Expression = { $_.department } },
            @{ Name = 'location'; Expression = { $_.office } },
            @{ Name = 'enabled'; Expression = { [bool]$_.Enabled } }

    $message = if (($users | Measure-Object).Count -gt 0) {
        "$(($users | Measure-Object).Count) Benutzer gefunden."
    }
    else {
        'Keine Benutzer gefunden.'
    }

    Write-StructuredResult -Success $true -Message $message -Data @{
        search_term = $searchTerm
        max_results = $maxResults
        users       = @($users)
    }
}
catch {
    Write-StructuredResult -Success $false -Message 'AD-Benutzersuche fehlgeschlagen.' -Data @{} -Errors @($_.Exception.Message) -ExitCode 1
}