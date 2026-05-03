param(
    [int]$Port = 8010
)

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $projectRoot

try {
    $env:PYTHONPATH = $projectRoot
    python -m uvicorn app.main:app --host 127.0.0.1 --port $Port --reload
}
finally {
    Pop-Location
}
