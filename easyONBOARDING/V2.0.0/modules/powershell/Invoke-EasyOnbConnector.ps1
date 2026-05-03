param(
    [Parameter(Mandatory = $true)]
    [string]$InputJsonPath,

    [Parameter(Mandatory = $false)]
    [string]$ConnectorName = "core.placeholder"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$startedAt = Get-Date
$inputPayload = Get-Content -Path $InputJsonPath -Raw | ConvertFrom-Json

$response = [ordered]@{
    success         = $true
    message         = "PowerShell connector stub executed successfully."
    connector       = $ConnectorName
    warnings        = @("Stub connector only – no productive backend action executed yet.")
    errors          = @()
    data            = @{
        receivedModule = $inputPayload.module
        receivedAction = $inputPayload.action
        dryRun         = $inputPayload.dry_run
    }
    audit_delta     = @()
    follow_up_tasks = @()
    duration_ms     = [int]((Get-Date) - $startedAt).TotalMilliseconds
}

$response | ConvertTo-Json -Depth 8
