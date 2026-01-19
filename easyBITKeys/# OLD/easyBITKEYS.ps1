# ---------------------------------------------------------------------
# PhinIT-easyBITKEYS (Version 0.3.5 - PowerShell 5.1)
# Autor: ANDREAS HEPP
# Letztes Update: 02.03.2025
#
# Dieses Skript liest aus dem AD alle BitLocker Keys (msFVE-RecoveryInformation)
# aus und zeigt diese in einer farbcodierten GUI an.
# Je nach Zustand:
#   - Kein Schlüssel vorhanden: LightGray
#   - Schlüssel älter als 3 Monate: LightGreen
#   - Schlüssel älter als 6 Monate: Orange
#   - Schlüssel älter als 12 Monate: LightCoral
#
# Außerdem gibt es Buttons zum Export als CSV, zum Löschen des markierten Eintrags 
# (nach Bestätigung) und zum Schließen der Anwendung.
#
# Die DataGridView zeigt 4 Spalten an:
#   "Nr" (nur so breit wie der Inhalt),
#   "ComputerName" (füllt den übrigen Platz),
#   "BitLockerKey" (füllt den übrigen Platz),
#   "Datum" (nur so breit wie der Inhalt).
#
# Der Footer (mit URL) wird als Panel unter den Buttons angezeigt und
# erhält dieselbe Hintergrundfarbe wie der Header (laut INI).
# ---------------------------------------------------------------------

# Sicherstellen, dass das Skript in PowerShell 5.1 läuft
if ($PSVersionTable.PSVersion.Major -ne 5) {
    Write-Host "Wechsle zu PowerShell 5.1..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Erforderliche Assemblies laden
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Funktion zum Einlesen einer INI-Datei
function Get-IniContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    if (-not (Test-Path $Path)) {
        Write-Error "INI-Datei '$Path' wurde nicht gefunden."
        exit
    }
    $ini = @{}
    $section = ""
    foreach ($line in Get-Content $Path) {
        $line = $line.Trim()
        if ($line -match '^\s*\[([^\]]+)\]') {
            $section = $matches[1]
            $ini[$section] = @{}
        }
        elseif ($line -match '^\s*([^;].*?)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ($section) {
                $ini[$section][$key] = $value
            }
        }
    }
    return $ini
}

# INI-Datei einlesen (Pfad zur INI-Datei anpassen)
$iniFile = "easyBITkeys.ini"
$iniContent = Get-IniContent -Path $iniFile
$cfg = $iniContent["easyBITKEYSGeneral"]

# Konfigurationswerte aus der INI
$ScriptVersion   = $cfg["easyBITKEYSVersion"]
$LastUpdate      = $cfg["easyBITKEYSLastUpdate"]
$Author          = $cfg["easyBITKEYSAuthor"]
$APPName         = $cfg["easyBITKEYSAPPName"]
$ThemeColor      = $cfg["easyBITKEYSThemeColor"]
$FontFamily      = $cfg["easyBITKEYSFontFamily"]
$FontSize        = [float]$cfg["easyBITKEYSFontSize"]
$HeaderLogoPath  = $cfg["easyBITKEYSHeaderLogo"]
$HeaderLogoURL   = $cfg["easyBITSSHeaderLogoURL"]
$GUI_HeaderRaw   = $cfg["easyBITSGUI_Header"]
$FooterText      = $cfg["easyBITSFooterText"]
$TableFormat     = $cfg["easyBITSTable"]  # (Nur als Spaltenüberschrift)

# Schriftart definieren
$guiFont = New-Object System.Drawing.Font($FontFamily, $FontSize)

# Platzhalter im GUI-Header ersetzen
$GUI_Header = $GUI_HeaderRaw -replace "\{ScriptVersion\}", $ScriptVersion `
                              -replace "\{LastUpdate\}", $LastUpdate `
                              -replace "\{Author\}", $Author

# GUI erstellen
$form = New-Object System.Windows.Forms.Form
$form.Text = $APPName
$form.Size = New-Object System.Drawing.Size(915,720)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

# HEADER Panel (Hintergrundfarbe gemäß ThemeColor aus INI)
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(900, 65)
$headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($ThemeColor)
$headerPanel.Location = New-Object System.Drawing.Point(0,0)
$form.Controls.Add($headerPanel)

# Links: Panel für den Header-Text
$headerTextPanel = New-Object System.Windows.Forms.Panel
$headerTextPanel.Size = New-Object System.Drawing.Size(630, 60)
$headerTextPanel.Location = New-Object System.Drawing.Point(10, 0)
$headerPanel.Controls.Add($headerTextPanel)

# Header-Label
$headerLabel = New-Object System.Windows.Forms.Label
$headerLabel.AutoSize = $true
$headerLabel.Location = New-Object System.Drawing.Point(10,20)
$headerTextPanel.Controls.Add($headerLabel)

# Rechts: Panel für das Logo
$headerLogoPanel = New-Object System.Windows.Forms.Panel
$headerLogoPanel.Size = New-Object System.Drawing.Size(250, 60)
$headerLogoPanel.Location = New-Object System.Drawing.Point(640, 0)
$headerPanel.Controls.Add($headerLogoPanel)

# Logo PictureBox
$logo = New-Object System.Windows.Forms.PictureBox
$logo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
$logo.Size = New-Object System.Drawing.Size(250,60)
$logo.Location = New-Object System.Drawing.Point(0,0)
if (Test-Path $HeaderLogoPath) {
    $logo.Image = [System.Drawing.Image]::FromFile($HeaderLogoPath)
}
else {
    $bmp = New-Object System.Drawing.Bitmap(250,60)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.Clear([System.Drawing.Color]::LightGray)
    $graphics.DrawString("Logo nicht gefunden", $guiFont, [System.Drawing.Brushes]::Black, 10, 20)
    $logo.Image = $bmp
}
$headerLogoPanel.Controls.Add($logo)

# Klick-Event für Logo (öffnet URL)
$logo.Add_Click({
    Start-Process $HeaderLogoURL
})

# DataGridView zur Darstellung der Tabelle
$dataGrid = New-Object System.Windows.Forms.DataGridView
$dataGrid.Size = New-Object System.Drawing.Size(880, 480)
$dataGrid.Location = New-Object System.Drawing.Point(10, 100)
# Es werden 4 Spalten definiert:
#   Spalte 0: "Nr"
#   Spalte 1: "ComputerName"
#   Spalte 2: "BitLockerKey"
#   Spalte 3: "Datum"
$dataGrid.ColumnCount = 4
$dataGrid.Columns[0].Name = "Nr"
$dataGrid.Columns[1].Name = "ComputerName"
$dataGrid.Columns[2].Name = "BitLockerKey"
$dataGrid.Columns[3].Name = "Datum"

$dataGrid.ReadOnly = $true
$dataGrid.AllowUserToAddRows = $false
$dataGrid.SelectionMode = 'FullRowSelect'

# Spalten-AutoSize Einstellungen:
# Spalte "Nr": nur so breit wie der Inhalt (AllCells)
$dataGrid.Columns[0].AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::AllCells
# Spalte "ComputerName": füllt den übrigen Platz
$dataGrid.Columns[1].AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
# Spalte "BitLockerKey": füllt den übrigen Platz
$dataGrid.Columns[2].AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
# Spalte "Datum": nur so breit wie der Inhalt (AllCells)
$dataGrid.Columns[3].AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::AllCells

$form.Controls.Add($dataGrid)

# Button Panel
$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Size = New-Object System.Drawing.Size(880, 40)
$buttonPanel.Location = New-Object System.Drawing.Point(10, 600)
$form.Controls.Add($buttonPanel)

# Export Button
$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Text = "EXPORT als CSV"
$exportButton.Size = New-Object System.Drawing.Size(150,30)
$exportButton.Location = New-Object System.Drawing.Point(200,5)
# Farbe: Hellgrün
$exportButton.BackColor = [System.Drawing.Color]::LightGreen
$buttonPanel.Controls.Add($exportButton)

# LÖSCHEN Button (löscht den markierten Eintrag nach Bestätigung)
$deleteButton = New-Object System.Windows.Forms.Button
$deleteButton.Text = "ENTFERNEN"
$deleteButton.Size = New-Object System.Drawing.Size(150,30)
$deleteButton.Location = New-Object System.Drawing.Point(380,5)
# Farbe: Hellorange (LightSalmon)
$deleteButton.BackColor = [System.Drawing.Color]::LightSalmon
$buttonPanel.Controls.Add($deleteButton)

$deleteButton.Add_Click({
    $selectedRows = $dataGrid.SelectedRows
    if ($selectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Bitte einen Eintrag aus der Liste markieren!", "Hinweis", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    $selectedRow = $selectedRows[0]
    $confirm = [System.Windows.Forms.MessageBox]::Show("Den markierten Eintrag wirklich entfernen?", "Entfernen", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        $dn = $selectedRow.Tag
        try {
            Remove-ADObject -Identity $dn -Confirm:$false
            $dataGrid.Rows.Remove($selectedRow)
            [System.Windows.Forms.MessageBox]::Show("Eintrag wurde entfernt.", "Erfolg", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Fehler beim entfernen des Eintrags: $_", "Fehler", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

# CLOSE Button
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "CLOSE"
$closeButton.Size = New-Object System.Drawing.Size(150,30)
$closeButton.Location = New-Object System.Drawing.Point(560,5)
# Farbe: Hellrot
$closeButton.BackColor = [System.Drawing.Color]::LightCoral
$buttonPanel.Controls.Add($closeButton)

$closeButton.Add_Click({
    $form.Close()
})

# Footer Panel (unter den Buttons, mit derselben Theme-Farbe wie der Header)
$footerPanel = New-Object System.Windows.Forms.Panel
$footerPanel.Size = New-Object System.Drawing.Size(900, 35)
$footerPanel.Location = New-Object System.Drawing.Point(0, 660)
$footerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($ThemeColor)
$form.Controls.Add($footerPanel)

# Footer Label im Footer Panel
$footerLabel = New-Object System.Windows.Forms.Label
# Kombiniert FooterText und Header-Informationen:
$footerLabel.Text = "$FooterText  =  $GUI_Header"
$footerLabel.Font = $guiFont
$footerLabel.AutoSize = $true
$footerLabel.Location = New-Object System.Drawing.Point(10, 3)
$footerLabel.Cursor = [System.Windows.Forms.Cursors]::Hand
$footerLabel.Add_Click({
    Start-Process $HeaderLogoURL
})
$footerPanel.Controls.Add($footerLabel)

# CSV-Export Funktion
$exportButton.Add_Click({
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV files (*.csv)|*.csv"
    $saveFileDialog.Title = "Als CSV speichern"
    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $csvContent = @()
        foreach ($row in $dataGrid.Rows) {
            if ($row.IsNewRow) { continue }
            $csvContent += "{0},{1},{2},{3}" -f $row.Cells[0].Value, $row.Cells[1].Value, $row.Cells[2].Value, $row.Cells[3].Value
        }
        $csvContent | Out-File -FilePath $saveFileDialog.FileName -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Export abgeschlossen!", "Export", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

# ActiveDirectory Modul importieren
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
if (-not (Get-Module -Name ActiveDirectory)) {
    [System.Windows.Forms.MessageBox]::Show("ActiveDirectory Modul ist nicht verfügbar. Bitte RSAT-Tools installieren.", "Fehler", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# AD-Abfrage: Alle BitLocker Keys (msFVE-RecoveryInformation)
try {
    $BitLockerKeys = Get-ADObject -Filter 'objectClass -eq "msFVE-RecoveryInformation"' -Properties msFVE-RecoveryPassword, whenCreated, distinguishedName
} catch {
    [System.Windows.Forms.MessageBox]::Show("Fehler bei der AD-Abfrage: $_", "Fehler", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Daten in DataGridView einfügen mit farblicher Kennzeichnung
$counter = 1
foreach ($key in $BitLockerKeys) {
    # Extrahiere den tatsächlichen ComputerName aus dem DistinguishedName:
    # Annahme: DN: CN={RecoveryGUID},CN={ComputerName},...
    $dnParts = $key.distinguishedName.Split(',')
    if ($dnParts.Length -ge 2) {
        $computerName = $dnParts[1] -replace "^CN=", ""
    }
    else {
        $computerName = "Unbekannt"
    }
    # Korrekte Referenzierung der AD-Eigenschaft mit Bindestrich
    $bitLockerKey = $key.'msFVE-RecoveryPassword'
    $date = $key.whenCreated
    $rowIndex = $dataGrid.Rows.Add()
    $dataGrid.Rows[$rowIndex].Cells[0].Value = $counter
    $dataGrid.Rows[$rowIndex].Cells[1].Value = $computerName
    $dataGrid.Rows[$rowIndex].Cells[2].Value = $bitLockerKey
    $dataGrid.Rows[$rowIndex].Cells[3].Value = $date.ToString("dd.MM.yyyy")
    # Speichere den DistinguishedName in der Zeile (Tag-Eigenschaft) für spätere Löschaktionen
    $dataGrid.Rows[$rowIndex].Tag = $key.distinguishedName
    
    # Farbliche Kennzeichnung der gesamten Zeile
    if ([string]::IsNullOrEmpty($bitLockerKey)) {
        $dataGrid.Rows[$rowIndex].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGray
    }
    else {
        $ageDays = (Get-Date) - $date
        $ageMonths = $ageDays.Days / 30
        if ($ageMonths -ge 12) {
            $dataGrid.Rows[$rowIndex].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightCoral
        }
        elseif ($ageMonths -ge 6) {
            $dataGrid.Rows[$rowIndex].DefaultCellStyle.BackColor = [System.Drawing.Color]::Orange
        }
        elseif ($ageMonths -ge 3) {
            $dataGrid.Rows[$rowIndex].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGreen
        }
    }
    $counter++
}

# Formular anzeigen
[void]$form.ShowDialog()

# SIG # Begin signature block
# MIIcCAYJKoZIhvcNAQcCoIIb+TCCG/UCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCwRzzBJLUVMqtt
# yLRL1gG2negM5p0tLM+nqpc3E9SgCaCCFk4wggMQMIIB+KADAgECAhB3jzsyX9Cg
# jEi+sBC2rBMTMA0GCSqGSIb3DQEBCwUAMCAxHjAcBgNVBAMMFVBoaW5JVC1QU3Nj
# cmlwdHNfU2lnbjAeFw0yNTA3MDUwODI4MTZaFw0yNzA3MDUwODM4MTZaMCAxHjAc
# BgNVBAMMFVBoaW5JVC1QU3NjcmlwdHNfU2lnbjCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBALmz3o//iDA5MvAndTjGX7/AvzTSACClfuUR9WYK0f6Ut2dI
# mPxn+Y9pZlLjXIpZT0H2Lvxq5aSI+aYeFtuJ8/0lULYNCVT31Bf+HxervRBKsUyi
# W9+4PH6STxo3Pl4l56UNQMcWLPNjDORWRPWHn0f99iNtjI+L4tUC/LoWSs3obzxN
# 3uTypzlaPBxis2qFSTR5SWqFdZdRkcuI5LNsJjyc/QWdTYRrfmVqp0QrvcxzCv8u
# EiVuni6jkXfiE6wz+oeI3L2iR+ywmU6CUX4tPWoS9VTtmm7AhEpasRTmrrnSg20Q
# jiBa1eH5TyLAH3TcYMxhfMbN9a2xDX5pzM65EJUCAwEAAaNGMEQwDgYDVR0PAQH/
# BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQO7XOqiE/EYi+n
# IaR6YO5M2MUuVTANBgkqhkiG9w0BAQsFAAOCAQEAjYOKIwBu1pfbdvEFFaR/uY88
# peKPk0NnvNEc3dpGdOv+Fsgbz27JPvItITFd6AKMoN1W48YjQLaU22M2jdhjGN5i
# FSobznP5KgQCDkRsuoDKiIOTiKAAknjhoBaCCEZGw8SZgKJtWzbST36Thsdd/won
# ihLsuoLxfcFnmBfrXh3rTIvTwvfujob68s0Sf5derHP/F+nphTymlg+y4VTEAijk
# g2dhy8RAsbS2JYZT7K5aEJpPXMiOLBqd7oTGfM7y5sLk2LIM4cT8hzgz3v5yPMkF
# H2MdR//K403e1EKH9MsGuGAJZddVN8ppaiESoPLoXrgnw2SY5KCmhYw1xRFdjTCC
# BY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290
# IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE9
# 8orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9S
# H8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g
# 1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RY
# jgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgD
# EI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNA
# vwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDg
# ohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQA
# zH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOk
# GLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHF
# ynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gd
# LfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
# FOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNy
# dDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkq
# hkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7
# IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/5
# 9PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0
# POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISf
# b8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhU
# LSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDCCBrQwggScoAMCAQICEA3H
# rFcF/yGZLkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEh
# MB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1MDUwNzAwMDAw
# MFoXDTM4MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFt
# cGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2tjQ2UtZmWgyxU
# 7UNqEY81FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWCWgzbNfiR
# +2fkHUiljNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vtLa4+gKPsYfwE
# u7EEbkC9+0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0XaF9DPfNBKS7Za
# zch8NF5vp7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhxKTVVgtmUPAW3
# 5xUUFREmDrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXKFifinT7zL2gd
# FpBP9qh8SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x5HHKS+rq
# BvKWxdCyQEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F20HHfIY4/6vH
# espYMQmUiote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQyogxG9QE
# PHrPV6/7umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u70EwgWbVRSX1
# Wd4+zoFpp4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczsG7ZrIGNTAgMB
# AAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTvb1NK6eQG
# fHrK4pBW9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAO
# BgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEE
# azBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYB
# BQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0
# ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYG
# Z4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAF877FoAc/gc9
# EXZxML2+C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI9NAzaoQk
# 97frPBtIj+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ3essBS3q8nL2
# UwM+NMvEuBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qKtntujB71
# WPYAgwPyWLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I+ZI2rVQf
# jXQA1WSjjf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q17r0z0noD
# js6+BFo+z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9M+MtucVGyOxi
# Df06VXxyKkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSmE+9JGYxOGLS/
# D284NHNboDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlHqhpB/8Ml
# uDezooIs8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7GELH3IdvG
# 2XlM9q7WP/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKdvlarEvf8EA+8
# hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAKgO8YS43xBYLR
# xHanlXRoMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5E
# aWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1l
# U3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAwMDAw
# WhcNMzYwOTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNl
# cnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRpbWVz
# dGFtcCBSZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEA0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfMGUIwYzKomd8U1nH7C8Dr
# 0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFPJIDZHhAqlUPt281mHrBb
# ZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMUNg7MOLxI6E9RaUueHTQK
# WXymOtRwJXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjKs3SKO1QNUdFd2adw44wD
# cKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8odbkqoK+lJ25LCHBSai25
# CFyD23DZgPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK40uhktzUd/Yk0xUvhDU6l
# vJukx7jphx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk12hE5FVs9HVVWcO5J4dV
# mVzix4A77p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2hSgctaepZTd0ILIUbWuh
# KuAeNIeWrzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6CtjuuVHJOVoIJ/DtpJRE7C
# e7vMRHoRon4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT3pXWETTJkhd76CIDBbTR
# ofOsNyEhzZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A9/z7eacCAwEAAaOCAZUw
# ggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx7f391/ORcWMZUEPPYYzo
# MB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIH
# gDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZR
# aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGlt
# ZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBS
# oFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRp
# bWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgG
# BmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAGUqrfEcJwS5
# rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP2AGr181o2YWPoSHz9iZE
# N/FPsLSTwVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7YXwB
# D9R0oU62PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75ZSpbh1oipOhcUT8lD8QA
# GB9lctZTTOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihsQyfFg5fxUFEp7W42fNBV
# N4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQJmmrJTV3Qhtfparz+BW6
# 0OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz0BZwhB9WOfOu/CIJnzkQ
# TwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8MmB10nfldPF9SVD7weCC
# 3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjFBtXVLcKtapnMG3VH3EmA
# p/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJVxwC+UpX2MSey2ueIu9T
# HFVkT+um1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFlTxq25+T4QwX9xa6ILs84
# ZPvmpovq90K8eWyG2N01c4IhSOxqt81nMYIFEDCCBQwCAQEwNDAgMR4wHAYDVQQD
# DBVQaGluSVQtUFNzY3JpcHRzX1NpZ24CEHePOzJf0KCMSL6wELasExMwDQYJYIZI
# AWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0B
# CQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAv
# BgkqhkiG9w0BCQQxIgQgoZ1h2thYCow+vw4eIwnGGmLTtjd9qT1QjHvLQz/Yeg0w
# DQYJKoZIhvcNAQEBBQAEggEAZdAwu2pzXoZspfPGROhYBeOsyak4M+1YyVj/Enkn
# b6R1yctFaELow6WCblq/HtQSBe98iEVIKFD5jHrwz90LR2952zWI6eVNz+VGtd2D
# p/UP3t9nwUzJAvJgdxtKHDbYGxxKcE3qCSZHVVPJjQn8uRg1m3i1pgZw+WeXvfRI
# lb0w+HSjXLBnLAT2sJ8h2lu/Ih30WTF2lS8KzL896Xz8fmrOskzBHE0XoOnjs/T3
# W5vuvdWb7CdlUlbukszBKetEqToeqnf/grBNjlKw5r7M+ok8V0i8L2zrcCmdAi3f
# ZVVB7a8UWLyoeE/bdUdKnr/lTWrS8o+36wfS7dFB5MIoqaGCAyYwggMiBgkqhkiG
# 9w0BCQYxggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdp
# Q2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3Rh
# bXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgw
# DQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqG
# SIb3DQEJBTEPFw0yNTA3MTIwODAwMTdaMC8GCSqGSIb3DQEJBDEiBCD9fIYCQWd+
# JPsQ2CI0Ks4YNxQklHU72RJN2Wa68Ob3BjANBgkqhkiG9w0BAQEFAASCAgCQhdrQ
# kacRsfUhKRe3Izb9YeQRFoILe0rR+AiHVcoFnCYMFpzNLMv96pfIA3i148v1NULt
# Ab43h/kK2zHOxx8K7wSdh3HdP8PMZ4Vl3j+VDmMKkqQNGkNXTYlVvi2nBoNaLcRo
# TRFwCl83ZnIWkZiBHnrtlqoDHgjdrfiXMRq9fyh/LHOnjy5R1KbaJk3U1d3UOu9h
# vyc7TxOsJ0qk6ZpJNrCEnNt4OnO65QfN0Gwa4i285AHai+AbgzEJkxSoKXG+CRkK
# Se9ej3hrpytFROjZrJwrx/SkUIRtHeEUdCw6/G4PolEweXjw6NeodYBGnWXhs8yN
# mufDaC7m1vnaXzaFxTEwln3ixydKjzoN3fsghtL6yKnY9sqMNPXyllOoJ+N9KUeQ
# 7EdF/XDTcZXgtwcKHLdRHFUOWKp/EMRSviS4QDzy6EGzAg2vFbtviKCaKcStmt/5
# Kx7iu4CDOhW9qg9RYiZFhUMWW5k3vlkS93weJT5UtEfFn2duI3v0LnQ0QWHGnIoj
# Xh4s1n48HWABN1J7zO+QGVfWk32hjIyGE+2pj6tsErFgkkSLmMupdlg2Q5QW5rgH
# mjwCqsW2SaBXpijDrREfsB5qPzBzTXDqloulk74k8q4wGyQp0dEQFYgDYX4763Sp
# unSaqwBy9FvktgnYEDAIZ9YA4USnyJQGP0JvhQ==
# SIG # End signature block
