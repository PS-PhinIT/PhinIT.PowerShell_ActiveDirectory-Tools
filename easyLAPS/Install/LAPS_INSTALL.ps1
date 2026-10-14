#Requires -Version 5.1
<#
.SYNOPSIS
    LAPS_INSTALL - Einrichtung von Windows LAPS im Active Directory (GUI).

.DESCRIPTION
    Kleine Windows-Forms-GUI zur Einrichtung von Windows LAPS:
      1. AD-Schema prüfen und bei Bedarf erweitern (Update-LapsADSchema, nach Bestätigung)
      2. Computer-Selbstrechte auf einer OU setzen (Set-LapsADComputerSelfPermission)
      3. Leserechte für eine Gruppe delegieren (Set-LapsADReadPasswordPermission)
      4. Reset-Rechte für eine Gruppe delegieren (Set-LapsADResetPasswordPermission)
      - Berechtigungen einer OU anzeigen (Find-LapsADExtendedRights)
      - LAPS-Test für einen Computer (Get-LapsADPassword) - das Passwort wird NICHT angezeigt

    Voraussetzungen:
      - Windows PowerShell 5.1
      - Windows LAPS PowerShell-Modul (LAPS) - Windows 10/11 bzw. Server 2019+ mit Update ab April 2023
      - RSAT ActiveDirectory-Modul
      - Schema-Erweiterung: Mitglied der Gruppe "Schema-Admins"
      - Rechtevergabe: Schreibrechte auf die Ziel-OU

    Autor: Andreas Hepp | www.phinit.de
    Versionsangaben werden in easyLAPS/README.md und easyLAPS/CHANGELOG.md gepflegt.
#>

# Unter PowerShell 7 (Core) in Windows PowerShell 5.1 neu starten (Windows Forms / LAPS-Modul)
if ($PSVersionTable.PSEdition -eq 'Core' -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $winPS = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path -Path $winPS) {
        Start-Process -FilePath $winPS -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-STA", "-File", "`"$PSCommandPath`"")
        exit 0
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Für die Schemaprüfung relevante Windows-LAPS-Attribute
$script:WindowsLapsSchemaAttributes = @(
    'msLAPS-PasswordExpirationTime', 'msLAPS-Password', 'msLAPS-EncryptedPassword',
    'msLAPS-EncryptedPasswordHistory', 'msLAPS-EncryptedDSRMPassword', 'msLAPS-EncryptedDSRMPasswordHistory'
)

#region Hilfsfunktionen
function Write-UiLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message
    $txtLog.AppendText($line + [Environment]::NewLine)
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
}

function Show-Info {
    param([string]$Text, [string]$Title = "Information")
    [void][System.Windows.Forms.MessageBox]::Show($Text, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

function Show-ErrorMessage {
    param([string]$Text, [string]$Title = "Fehler")
    [void][System.Windows.Forms.MessageBox]::Show($Text, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

function Confirm-Action {
    param([string]$Text, [string]$Title = "Bestätigung")
    $answer = [System.Windows.Forms.MessageBox]::Show($Text, $Title, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning, [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
    return ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Test-RequiredModule {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (Get-Module -Name $Name) { return $true }
    try {
        Import-Module $Name -ErrorAction Stop
        return $true
    }
    catch {
        Write-UiLog "Modul '$Name' nicht verfügbar: $($_.Exception.Message)"
        Show-ErrorMessage "Das PowerShell-Modul '$Name' ist nicht verfügbar.`n`n$($_.Exception.Message)"
        return $false
    }
}

# Ermittelt die OU (bzw. den Container) des lokalen Computers
function Get-LocalComputerOU {
    $computer = Get-ADComputer -Identity $env:COMPUTERNAME -ErrorAction Stop
    $parts = [regex]::Split([string]$computer.DistinguishedName, '(?<!\\),')
    if ($parts.Length -lt 2) { throw "DistinguishedName von $env:COMPUTERNAME konnte nicht ausgewertet werden." }
    return $computer.DistinguishedName.Substring($parts[0].Length + 1)
}

# Prüft die Eingabe der OU und ob das Objekt im AD existiert
function Get-ValidatedOU {
    $ou = $txtOU.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($ou)) {
        Show-ErrorMessage "Bitte den DistinguishedName der Ziel-OU eingeben (z. B. OU=Clients,DC=contoso,DC=local)."
        return $null
    }
    if (-not (Test-RequiredModule -Name ActiveDirectory)) { return $null }
    try {
        [void](Get-ADObject -Identity $ou -ErrorAction Stop)
        return $ou
    }
    catch {
        Show-ErrorMessage "Die OU '$ou' wurde im AD nicht gefunden:`n$($_.Exception.Message)"
        return $null
    }
}

function Get-ValidatedGroup {
    $group = $txtGroup.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($group)) {
        Show-ErrorMessage "Bitte eine Gruppe angeben (z. B. CONTOSO\LAPS-Admins)."
        return $null
    }
    return $group
}

function Get-MissingLapsSchemaAttribute {
    $rootDse = Get-ADRootDSE -ErrorAction Stop
    $ldapFilter = '(|' + (($script:WindowsLapsSchemaAttributes | ForEach-Object { "(lDAPDisplayName=$_)" }) -join '') + ')'
    $present = @(Get-ADObject -SearchBase $rootDse.schemaNamingContext -LDAPFilter $ldapFilter -Properties lDAPDisplayName -ErrorAction Stop |
                 ForEach-Object { [string]$_.lDAPDisplayName })
    return @($script:WindowsLapsSchemaAttributes | Where-Object { $present -notcontains $_ })
}

function Invoke-WithWaitCursor {
    param([Parameter(Mandatory = $true)][scriptblock]$ScriptBlock)
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try { & $ScriptBlock }
    finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
}
#endregion

#region Aktionen
function Update-LapsSchemaWithConfirmation {
    if (-not (Test-RequiredModule -Name ActiveDirectory) -or -not (Test-RequiredModule -Name LAPS)) { return }
    try {
        $missing = @(Get-MissingLapsSchemaAttribute)
        if ($missing.Count -eq 0) {
            Write-UiLog "Schema: Alle Windows-LAPS-Attribute sind bereits vorhanden - keine Erweiterung notwendig."
            Show-Info "Das AD-Schema enthält bereits alle Windows-LAPS-Attribute.`nEine Erweiterung ist nicht notwendig."
            return
        }
        Write-UiLog "Schema: Fehlende Attribute: $($missing -join ', ')"

        $question = "Das AD-Schema wird jetzt für Windows LAPS erweitert.`n`n" +
                    "Fehlende Attribute:`n - $($missing -join "`n - ")`n`n" +
                    "ACHTUNG: Die Schema-Erweiterung gilt für die gesamte Gesamtstruktur und kann NICHT rückgängig gemacht werden.`n" +
                    "Erforderlich: Mitgliedschaft in 'Schema-Admins'.`n`nFortfahren?"
        if (-not (Confirm-Action -Text $question -Title "Schema-Erweiterung bestätigen")) {
            Write-UiLog "Schema: Erweiterung vom Benutzer abgebrochen."
            return
        }

        Invoke-WithWaitCursor {
            $output = Update-LapsADSchema -Confirm:$false -Verbose -ErrorAction Stop 4>&1 | Out-String
            if (-not [string]::IsNullOrWhiteSpace($output)) { Write-UiLog $output.Trim() }
        }
        Write-UiLog "Schema: Erweiterung erfolgreich abgeschlossen."
        Show-Info "Die Windows-LAPS-Schema-Erweiterung wurde erfolgreich durchgeführt." "Erfolg"
    }
    catch {
        Write-UiLog "Schema: FEHLER - $($_.Exception.Message)"
        Show-ErrorMessage "Fehler bei der Schema-Erweiterung:`n$($_.Exception.Message)"
    }
}

function Set-LapsComputerSelfPermissionOnOU {
    $ou = Get-ValidatedOU
    if (-not $ou -or -not (Test-RequiredModule -Name LAPS)) { return }
    if (-not (Confirm-Action -Text "Computer-Selbstrechte (Passwort im AD speichern) setzen für:`n$ou`n`nFortfahren?")) { return }
    try {
        Invoke-WithWaitCursor { $output = Set-LapsADComputerSelfPermission -Identity $ou -ErrorAction Stop | Out-String; if ($output.Trim()) { Write-UiLog $output.Trim() } }
        Write-UiLog "Selbstrechte gesetzt: $ou"
        Show-Info "Computer-Selbstrechte wurden gesetzt für:`n$ou" "Erfolg"
    }
    catch {
        Write-UiLog "Selbstrechte: FEHLER - $($_.Exception.Message)"
        Show-ErrorMessage "Fehler beim Setzen der Computer-Selbstrechte:`n$($_.Exception.Message)"
    }
}

function Set-LapsGroupPermissionOnOU {
    param([ValidateSet('Read', 'Reset')][string]$Type)
    $ou = Get-ValidatedOU
    if (-not $ou) { return }
    $group = Get-ValidatedGroup
    if (-not $group -or -not (Test-RequiredModule -Name LAPS)) { return }
    $label = if ($Type -eq 'Read') { "Leserechte (Passwort lesen)" } else { "Reset-Rechte (Ablaufzeit setzen)" }
    if (-not (Confirm-Action -Text "$label für '$group' delegieren auf:`n$ou`n`nFortfahren?")) { return }
    try {
        Invoke-WithWaitCursor {
            if ($Type -eq 'Read') {
                $output = Set-LapsADReadPasswordPermission -Identity $ou -AllowedPrincipals $group -ErrorAction Stop | Out-String
            }
            else {
                $output = Set-LapsADResetPasswordPermission -Identity $ou -AllowedPrincipals $group -ErrorAction Stop | Out-String
            }
            if ($output.Trim()) { Write-UiLog $output.Trim() }
        }
        Write-UiLog "$label für '$group' delegiert: $ou"
        Show-Info "$label für '$group' wurden delegiert auf:`n$ou" "Erfolg"
    }
    catch {
        Write-UiLog "$label`: FEHLER - $($_.Exception.Message)"
        Show-ErrorMessage "Fehler beim Delegieren ($label):`n$($_.Exception.Message)"
    }
}

function Show-LapsPermissionOnOU {
    $ou = Get-ValidatedOU
    if (-not $ou -or -not (Test-RequiredModule -Name LAPS)) { return }
    try {
        Invoke-WithWaitCursor {
            $rights = Find-LapsADExtendedRights -Identity $ou -ErrorAction Stop | Format-List | Out-String
            Write-UiLog ("Berechtigungen für $ou`:" + [Environment]::NewLine + $rights.Trim())
        }
    }
    catch {
        Write-UiLog "Berechtigungen: FEHLER - $($_.Exception.Message)"
        Show-ErrorMessage "Fehler beim Lesen der Berechtigungen:`n$($_.Exception.Message)"
    }
}

# Testet den Abruf, ohne das Passwort anzuzeigen
function Test-LapsForComputer {
    $computerName = $txtComputer.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($computerName)) {
        Show-ErrorMessage "Bitte einen Computernamen eingeben."
        return
    }
    if (-not (Test-RequiredModule -Name LAPS)) { return }
    try {
        $info = $null
        Invoke-WithWaitCursor { $script:LapsTestResult = Get-LapsADPassword -Identity $computerName -AsPlainText -ErrorAction Stop -WarningAction SilentlyContinue | Select-Object -First 1 }
        $info = $script:LapsTestResult
        $script:LapsTestResult = $null

        if ($null -eq $info) {
            Write-UiLog "Test $computerName`: Keine LAPS-Daten im AD gefunden."
            Show-Info "Für '$computerName' wurden keine LAPS-Daten im AD gefunden.`nIst die LAPS-Richtlinie auf dem Gerät aktiv?" "LAPS-Test"
            return
        }

        $hasPassword = -not [string]::IsNullOrEmpty([string]$info.Password)
        $lines = @(
            "Computer: $($info.ComputerName)",
            "Konto: $($info.Account)",
            "Quelle: $($info.Source)",
            "Entschlüsselung: $($info.DecryptionStatus)",
            "Passwort lesbar: $(if ($hasPassword) { "Ja ($(([string]$info.Password).Length) Zeichen)" } else { 'Nein' })",
            "Zuletzt gesetzt: $($info.PasswordUpdateTime)",
            "Läuft ab: $($info.ExpirationTimestamp)"
        )
        $info = $null
        Write-UiLog ("Test:" + [Environment]::NewLine + ($lines -join [Environment]::NewLine))
        Show-Info (($lines -join "`n") + "`n`nDas Passwort selbst wird hier nicht angezeigt (easyLAPS verwenden).") "LAPS-Test"
    }
    catch {
        Write-UiLog "Test $computerName`: FEHLER - $($_.Exception.Message)"
        Show-ErrorMessage "Fehler beim LAPS-Test für '$computerName':`n$($_.Exception.Message)"
    }
}
#endregion

#region GUI
$buttonBackColor = [System.Drawing.ColorTranslator]::FromHtml("#0055AA")
$buttonForeColor = [System.Drawing.Color]::White
$buttonFont = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$labelFont = New-Object System.Drawing.Font("Segoe UI", 9)

function New-ActionButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width = 520)
    $button = New-Object System.Windows.Forms.Button
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, 34)
    $button.Text = $Text
    $button.BackColor = $buttonBackColor
    $button.ForeColor = $buttonForeColor
    $button.Font = $buttonFont
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.Anchor = [System.Windows.Forms.AnchorStyles]'Top,Left,Right'
    return $button
}

function New-Label {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width = 520)
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, 18)
    $label.Text = $Text
    $label.Font = $labelFont
    return $label
}

function New-InputBox {
    param([int]$X, [int]$Y, [int]$Width = 520)
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point($X, $Y)
    $textBox.Size = New-Object System.Drawing.Size($Width, 24)
    $textBox.Font = $labelFont
    $textBox.Anchor = [System.Windows.Forms.AnchorStyles]'Top,Left,Right'
    return $textBox
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows LAPS – Einrichtung (Schema, Rechte, Test)"
$form.Size = New-Object System.Drawing.Size(580, 720)
$form.MinimumSize = New-Object System.Drawing.Size(580, 720)
$form.StartPosition = "CenterScreen"

$form.Controls.Add((New-Label -Text "Ziel-OU (DistinguishedName):" -X 20 -Y 15))
$txtOU = New-InputBox -X 20 -Y 35 -Width 380
$form.Controls.Add($txtOU)
$btnLocalOU = New-ActionButton -Text "Lokale OU ermitteln" -X 410 -Y 31 -Width 130
$btnLocalOU.Anchor = [System.Windows.Forms.AnchorStyles]'Top,Right'
$form.Controls.Add($btnLocalOU)

$form.Controls.Add((New-Label -Text "Gruppe für Lese-/Reset-Rechte (z. B. CONTOSO\LAPS-Admins):" -X 20 -Y 70))
$txtGroup = New-InputBox -X 20 -Y 90
$form.Controls.Add($txtGroup)

$btnSchema = New-ActionButton -Text "1. Schema prüfen / erweitern" -X 20 -Y 130
$btnSelf = New-ActionButton -Text "2. Computer-Selbstrechte auf OU setzen" -X 20 -Y 170
$btnRead = New-ActionButton -Text "3. Leserechte für Gruppe delegieren" -X 20 -Y 210
$btnReset = New-ActionButton -Text "4. Reset-Rechte für Gruppe delegieren" -X 20 -Y 250
$btnShowRights = New-ActionButton -Text "Berechtigungen der OU anzeigen" -X 20 -Y 290
$form.Controls.AddRange(@($btnSchema, $btnSelf, $btnRead, $btnReset, $btnShowRights))

$form.Controls.Add((New-Label -Text "Computername für LAPS-Test:" -X 20 -Y 335))
$txtComputer = New-InputBox -X 20 -Y 355 -Width 380
$txtComputer.Text = $env:COMPUTERNAME
$form.Controls.Add($txtComputer)
$btnTest = New-ActionButton -Text "LAPS testen" -X 410 -Y 351 -Width 130
$btnTest.Anchor = [System.Windows.Forms.AnchorStyles]'Top,Right'
$form.Controls.Add($btnTest)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 395)
$txtLog.Size = New-Object System.Drawing.Size(520, 220)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLog.Anchor = [System.Windows.Forms.AnchorStyles]'Top,Bottom,Left,Right'
$form.Controls.Add($txtLog)

$btnExit = New-ActionButton -Text "Beenden" -X 20 -Y 625
$btnExit.Anchor = [System.Windows.Forms.AnchorStyles]'Bottom,Left,Right'
$form.Controls.Add($btnExit)

$btnLocalOU.Add_Click({
    if (-not (Test-RequiredModule -Name ActiveDirectory)) { return }
    try {
        $txtOU.Text = Get-LocalComputerOU
        Write-UiLog "Lokale OU: $($txtOU.Text)"
    }
    catch {
        Write-UiLog "Lokale OU: FEHLER - $($_.Exception.Message)"
        Show-ErrorMessage "Die OU des lokalen Computers konnte nicht ermittelt werden:`n$($_.Exception.Message)"
    }
})
$btnSchema.Add_Click({ Update-LapsSchemaWithConfirmation })
$btnSelf.Add_Click({ Set-LapsComputerSelfPermissionOnOU })
$btnRead.Add_Click({ Set-LapsGroupPermissionOnOU -Type Read })
$btnReset.Add_Click({ Set-LapsGroupPermissionOnOU -Type Reset })
$btnShowRights.Add_Click({ Show-LapsPermissionOnOU })
$btnTest.Add_Click({ Test-LapsForComputer })
$btnExit.Add_Click({ $form.Close() })

$form.Add_Shown({
    $form.Activate()
    $lapsAvailable = [bool](Get-Module -Name LAPS -ListAvailable)
    $adAvailable = [bool](Get-Module -Name ActiveDirectory -ListAvailable)
    Write-UiLog "Windows-LAPS-Modul: $(if ($lapsAvailable) { 'verfügbar' } else { 'NICHT verfügbar' })"
    Write-UiLog "ActiveDirectory-Modul: $(if ($adAvailable) { 'verfügbar' } else { 'NICHT verfügbar (RSAT installieren)' })"
    if ($adAvailable) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            $txtOU.Text = Get-LocalComputerOU
            Write-UiLog "Vorbelegt mit OU des lokalen Computers: $($txtOU.Text)"
        }
        catch {
            Write-UiLog "OU des lokalen Computers nicht ermittelbar: $($_.Exception.Message)"
        }
    }
})

[void]$form.ShowDialog()
$form.Dispose()
#endregion
