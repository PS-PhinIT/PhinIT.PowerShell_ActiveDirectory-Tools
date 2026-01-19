# Erweiterter INI Editor mit festen GUI-Einstellungen und Änderungsprotokollierung
# (ohne dynamische Buttons zum Hinzufügen/Löschen von Abschnitten und Schlüsseln)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#############################################
# Zusätzliche Funktion: Loggen
#############################################
function Log-Change {
    param(
        [string]$Message,
        [string]$LogPath = "LOG_easyINIEditor-Changes.log"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    Add-Content -Path $LogPath -Value $logEntry
}

#############################################
# INI einlesen (mit Kommentarunterstützung)
#############################################
function Read-IniFile {
    param([string]$Path)
    $ini = [ordered]@{}
    $currentSection = ""
    $pendingComment = ""

    foreach ($line in Get-Content $Path) {
        $trimmed = $line.Trim()

        # Kommentarzeile?
        if ($trimmed -match "^\s*;") {
            # Kommentartext ohne führendes ";"
            $commentText = $trimmed.Substring(1).Trim()
            if ($pendingComment -eq "") {
                $pendingComment = $commentText
            }
            else {
                $pendingComment += "`n" + $commentText
            }
            continue
        }

        # Abschnittszeile [Abschnitt]?
        if ($trimmed -match "^\[(.+?)\]") {
            $currentSection = $matches[1]

            # Falls Abschnitt noch nicht existiert => anlegen
            if (-not ($ini.Keys -contains $currentSection)) {
                $ini[$currentSection] = [ordered]@{}
            }
            # Kommentar gilt nicht mehr für nächsten Abschnitt
            $pendingComment = ""
        }

        # key = value ? (abgesehen von reinen Leer-/Kommentarzeilen)
        elseif ($trimmed -match "^(.*?)\s*=\s*(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            if ($currentSection -ne "") {
                if (-not ($ini.Keys -contains $currentSection)) {
                    $ini[$currentSection] = [ordered]@{}
                }
                $ini[$currentSection][$key] = [PSCustomObject]@{
                    Value   = $value
                    Comment = $pendingComment
                }
            }
            $pendingComment = ""
        }
        else {
            # Unbekannte Zeile -> Kommentar zurücksetzen
            $pendingComment = ""
        }
    }
    return $ini
}

#############################################
# INI schreiben (Kommentare wieder einfügen)
#############################################
function Write-IniFile {
    param(
        [hashtable]$IniData,
        [string]$Path,
        [System.Collections.ArrayList]$DesiredOrder
    )
    # Abschnitte sortieren: zuerst DesiredOrder, dann Rest
    $remaining = [ordered]@{}
    foreach ($section in $IniData.Keys) {
        $remaining[$section] = $IniData[$section]
    }
    $orderedIni = [ordered]@{}

    foreach ($section in $DesiredOrder) {
        if ($remaining.Keys -contains $section) {
            $orderedIni[$section] = $remaining[$section]
            $remaining.Remove($section) | Out-Null
        }
    }
    foreach ($left in $remaining.Keys) {
        $orderedIni[$left] = $remaining[$left]
    }
    
    $lines = @()
    foreach ($sec in $orderedIni.Keys) {
        $lines += "[$sec]"
        if ($orderedIni[$sec].Count -gt 0) {
            foreach ($key in $orderedIni[$sec].Keys) {
                $entry = $orderedIni[$sec][$key]
                if (-not [string]::IsNullOrEmpty($entry.Comment)) {
                    foreach ($cl in $entry.Comment -split "`n") {
                        $lines += "; " + $cl
                    }
                }
                $lines += "$key=$($entry.Value)"
            }
        }
        $lines += ""  # Leere Zeile als Trenner
    }
    $lines | Set-Content -Path $Path -Encoding UTF8
}

#############################################
# Gewünschte Reihenfolge festlegen
#############################################
$desiredOrder = New-Object System.Collections.ArrayList
[void]$desiredOrder.AddRange(@(
    "ScriptInfo",
    "General",
    "Branding-GUI",
    "Branding-Report",
    "Websites",
    "ADUserDefaults",
    "DisplayNameTemplates",
    "UserCreationDefaults",
    "PasswordFixGenerate",
    "ADGroups",
    "LicensesGroups",
    "ActivateUserMS365ADSync",
    "SignaturGruppe_Optional",
    "STANDORTE",
    "MailEndungen",
    "Company1",
    "Company2",
    "Company3",
    "Company4",
    "Company5",
    "CONFIGEDITOR"
))

#############################################
# Pfad zur INI-Datei (alle Dateien mit .ini laden)
#############################################
$iniPath = "*.ini"

#############################################
# Alle INI-Dateien einlesen und in $AllIniData speichern
#############################################
$AllIniData = @{}
$files = Get-ChildItem -Path $iniPath -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Host "Keine INI-Dateien gefunden im aktuellen Verzeichnis."
    return
}

foreach ($f in $files) {
    $AllIniData[$f.FullName] = Read-IniFile -Path $f.FullName
}

#############################################
# Editor-Einstellungen aus [CONFIGEDITOR] aus der ersten INI-Datei laden (falls vorhanden)
#############################################
$editorSettings = @{
    FormBackColor     = "#F0F0F0"
    ListViewBackColor = "#FFFFFF"
    DataGridBackColor = "#FAFAFA"
    FontName          = "Segoe UI"
    FontSize          = 10
    LogFilePath       = "ini_changes.log"
}
$firstFile = $files[0].FullName
if ($AllIniData[$firstFile].Keys -contains "CONFIGEDITOR") {
    foreach ($key in $AllIniData[$firstFile]["CONFIGEDITOR"].Keys) {
        $valObj = $AllIniData[$firstFile]["CONFIGEDITOR"][$key]
        if ($valObj -and $editorSettings.ContainsKey($key)) {
            $editorSettings[$key] = $valObj.Value
        }
    }
}
$logFilePath = $editorSettings["LogFilePath"]

#############################################
# GUI erstellen: Formular, ListView und DataGridView
#############################################
$form = New-Object System.Windows.Forms.Form
$form.Text = "INI Editor - Feste Reihenfolge"
$form.Size = New-Object System.Drawing.Size(1250,900)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml($editorSettings.FormBackColor)

# ListView (Abschnitte)
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(20,20)
$listView.Size = New-Object System.Drawing.Size(300,750)
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.Sorting = 'None'
$listView.ShowGroups = $false
$listView.Columns.Add("Abschnitt", 280) | Out-Null
$listView.BackColor = [System.Drawing.ColorTranslator]::FromHtml($editorSettings.ListViewBackColor)
$form.Controls.Add($listView)

# DataGridView (Schlüssel, Werte, Kommentare)
$dataGrid = New-Object System.Windows.Forms.DataGridView
$dataGrid.Location = New-Object System.Drawing.Point(340,20)
$dataGrid.Size = New-Object System.Drawing.Size(880,750)
$dataGrid.ColumnCount = 3
$dataGrid.Columns[0].Name = "Key"
$dataGrid.Columns[1].Name = "Value"
$dataGrid.Columns[2].Name = "Comment"
$dataGrid.Columns[2].ReadOnly = $true
$dataGrid.AutoSizeColumnsMode = 'None'
$dataGrid.Columns[0].Width = 150
$dataGrid.Columns[1].Width = 400
$dataGrid.Columns[2].Width = 285
$dataGrid.AllowUserToAddRows = $false
$dataGrid.EditMode = 'EditOnKeystrokeOrF2'
$dataGrid.BackColor = [System.Drawing.ColorTranslator]::FromHtml($editorSettings.DataGridBackColor)
$form.Controls.Add($dataGrid)

#############################################
# Linke Ansicht befüllen
# Für jede INI-Datei: ein fetter Header ("INI File: ..."), dann direkt die Sections in finaler Reihenfolge
#############################################
function Populate-ListView {
    $listView.Items.Clear()

    foreach ($filePath in $AllIniData.Keys) {
        # Fetter Balken als Header mit Dateiname
        $fileItem = New-Object System.Windows.Forms.ListViewItem("INI File: " + (Split-Path $filePath -Leaf))
        $fileItem.Font = New-Object System.Drawing.Font($listView.Font.FontFamily, $listView.Font.Size, [System.Drawing.FontStyle]::Bold)
        $fileItem.Tag = [PSCustomObject]@{
            Type    = "FileHeader"
            File    = $filePath
            Section = $null
        }
        [void]$listView.Items.Add($fileItem)

        # Erstelle für diese Datei die gewünschte Reihenfolge der Sections
        $currentIni = $AllIniData[$filePath]
        $allSections = $currentIni.Keys
        $finalOrder = New-Object System.Collections.ArrayList

        foreach ($sec in $desiredOrder) {
            if ($allSections -contains $sec) {
                [void]$finalOrder.Add($sec)
            }
        }
        foreach ($s in $allSections) {
            if (-not $finalOrder.Contains($s)) {
                [void]$finalOrder.Add($s)
            }
        }

        # Sections einfügen (OHNE Separatoren)
        foreach ($sec in $finalOrder) {
            $item = New-Object System.Windows.Forms.ListViewItem($sec)
            $item.Tag = [PSCustomObject]@{
                Type    = "Section"
                File    = $filePath
                Section = $sec
            }
            [void]$listView.Items.Add($item)
        }
    }
}

Populate-ListView

#############################################
# ListView-Auswahl-Event: Beim Klick werden Datei und Section aus dem Tag-Feld ermittelt
#############################################
$currentFile = $null
$currentSection = $null

$listView.Add_SelectedIndexChanged({
    if ($listView.SelectedItems.Count -gt 0) {
        $selTag = $listView.SelectedItems[0].Tag
        if ($selTag -and $selTag.Type -eq "Section") {
            $currentFile = $selTag.File
            $currentSection = $selTag.Section

            $dataGrid.Rows.Clear()
            $thisIniData = $AllIniData[$currentFile]
            if ($thisIniData.Keys -contains $currentSection) {
                foreach ($key in $thisIniData[$currentSection].Keys) {
                    $entry = $thisIniData[$currentSection][$key]
                    $row = @($key, $entry.Value, $entry.Comment)
                    [void]$dataGrid.Rows.Add($row)
                }
            }
        }
        else {
            $currentFile = $null
            $currentSection = $null
            $dataGrid.Rows.Clear()
        }
    }
})

#############################################
# Buttons: Save, Info, Close
#############################################

# Save Changes
$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = "Save Changes"
$saveButton.Size = New-Object System.Drawing.Size(120,40)
$saveButton.Location = New-Object System.Drawing.Point(20,780)
$saveButton.BackColor = [System.Drawing.Color]::LightGreen
$saveButton.Add_Click({
    if (-not $currentFile -or -not $currentSection) {
        [System.Windows.Forms.MessageBox]::Show("Bitte wählen Sie einen Abschnitt aus.", "Hinweis")
        return
    }

    # Neue Section-Daten aufbauen
    $sectionData = [ordered]@{}
    foreach ($row in $dataGrid.Rows) {
        $key = $row.Cells[0].Value
        $value = $row.Cells[1].Value
        $comment = $row.Cells[2].Value

        if (-not [string]::IsNullOrEmpty($key)) {
            $sectionData[$key] = [PSCustomObject]@{
                Value   = $value
                Comment = $comment
            }
        }
    }

    # Abschnitt ersetzen
    $AllIniData[$currentFile][$currentSection] = $sectionData

    # INI-Datei schreiben (mit der originalen Reihenfolge)
    Write-IniFile -IniData $AllIniData[$currentFile] -Path $currentFile -DesiredOrder $desiredOrder

    [System.Windows.Forms.MessageBox]::Show("INI-Datei erfolgreich gespeichert.", "Gespeichert")

    Log-Change -Message "Abschnitt '$currentSection' in Datei '$currentFile' wurde gespeichert." -LogPath $logFilePath
})
$form.Controls.Add($saveButton)

# Info Button – öffnet info_editor.txt
$infoButton = New-Object System.Windows.Forms.Button
$infoButton.Text = "Info"
$infoButton.Size = New-Object System.Drawing.Size(80,40)
$infoButton.Location = New-Object System.Drawing.Point(160,780)
$infoButton.BackColor = [System.Drawing.Color]::LightBlue
$infoButton.Add_Click({
    if (Test-Path "info_editor.txt") {
        Invoke-Item "info_editor.txt"
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("Die Datei 'info_editor.txt' wurde nicht gefunden.", "Info")
    }
})
$form.Controls.Add($infoButton)

# Close Button
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close"
$closeButton.Size = New-Object System.Drawing.Size(80,40)
$closeButton.Location = New-Object System.Drawing.Point(260,780)
$closeButton.BackColor = [System.Drawing.Color]::LightCoral
$closeButton.Add_Click({
    $form.Close()
})
$form.Controls.Add($closeButton)

#############################################
# Formular anzeigen
#############################################
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

# SIG # Begin signature block
# MIIoiQYJKoZIhvcNAQcCoIIoejCCKHYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCATs1RDgd20Pn9j
# 5QqWPEhrKFYixtv6GFkV2ul8DlsUjqCCILswggXJMIIEsaADAgECAhAbtY8lKt8j
# AEkoya49fu0nMA0GCSqGSIb3DQEBDAUAMH4xCzAJBgNVBAYTAlBMMSIwIAYDVQQK
# ExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVzdGVkIE5l
# dHdvcmsgQ0EwHhcNMjEwNTMxMDY0MzA2WhcNMjkwOTE3MDY0MzA2WjCBgDELMAkG
# A1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAl
# BgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMb
# Q2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAvfl4+ObVgAxknYYblmRnPyI6HnUBfe/7XGeMycxca6mR5rlC
# 5SBLm9qbe7mZXdmbgEvXhEArJ9PoujC7Pgkap0mV7ytAJMKXx6fumyXvqAoAl4Va
# qp3cKcniNQfrcE1K1sGzVrihQTib0fsxf4/gX+GxPw+OFklg1waNGPmqJhCrKtPQ
# 0WeNG0a+RzDVLnLRxWPa52N5RH5LYySJhi40PylMUosqp8DikSiJucBb+R3Z5yet
# /5oCl8HGUJKbAiy9qbk0WQq/hEr/3/6zn+vZnuCYI+yma3cWKtvMrTscpIfcRnNe
# GWJoRVfkkIJCu0LW8GHgwaM9ZqNd9BjuiMmNF0UpmTJ1AjHuKSbIawLmtWJFfzcV
# WiNoidQ+3k4nsPBADLxNF8tNorMe0AZa3faTz1d1mfX6hhpneLO/lv403L3nUlbl
# s+V1e9dBkQXcXWnjlQ1DufyDljmVe2yAWk8TcsbXfSl6RLpSpCrVQUYJIP4ioLZb
# MI28iQzV13D4h1L92u+sUS4Hs07+0AnacO+Y+lbmbdu1V0vc5SwlFcieLnhO+Nqc
# noYsylfzGuXIkosagpZ6w7xQEmnYDlpGizrrJvojybawgb5CAKT41v4wLsfSRvbl
# jnX98sy50IdbzAYQYLuDNbdeZ95H7JlI8aShFf6tjGKOOVVPORa5sWOd/7cCAwEA
# AaOCAT4wggE6MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLahVDkCw6A/joq8
# +tT4HKbROg79MB8GA1UdIwQYMBaAFAh2zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1Ud
# DwEB/wQEAwIBBjAvBgNVHR8EKDAmMCSgIqAghh5odHRwOi8vY3JsLmNlcnR1bS5w
# bC9jdG5jYS5jcmwwawYIKwYBBQUHAQEEXzBdMCgGCCsGAQUFBzABhhxodHRwOi8v
# c3ViY2Eub2NzcC1jZXJ0dW0uY29tMDEGCCsGAQUFBzAChiVodHRwOi8vcmVwb3Np
# dG9yeS5jZXJ0dW0ucGwvY3RuY2EuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQG
# CCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEM
# BQADggEBAFHCoVgWIhCL/IYx1MIy01z4S6Ivaj5N+KsIHu3V6PrnCA3st8YeDrJ1
# BXqxC/rXdGoABh+kzqrya33YEcARCNQOTWHFOqj6seHjmOriY/1B9ZN9DbxdkjuR
# mmW60F9MvkyNaAMQFtXx0ASKhTP5N+dbLiZpQjy6zbzUeulNndrnQ/tjUoCFBMQl
# lVXwfqefAcVbKPjgzoZwpic7Ofs4LphTZSJ1Ldf23SIikZbr3WjtP6MZl9M7JYjs
# NhI9qX7OAo0FmpKnJ25FspxihjcNpDOO16hO0EoXQ0zF8ads0h5YbBRRfopUofbv
# n3l6XYGaFpAP4bvxSgD5+d2+7arszgowggaDMIIEa6ADAgECAhEAnpwE9lWotKcC
# bUmMbHiNqjANBgkqhkiG9w0BAQwFADBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMY
# QXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0
# YW1waW5nIDIwMjEgQ0EwHhcNMjUwMTA5MDg0MDQzWhcNMzYwMTA3MDg0MDQzWjBQ
# MQswCQYDVQQGEwJQTDEhMB8GA1UECgwYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEu
# MR4wHAYDVQQDDBVDZXJ0dW0gVGltZXN0YW1wIDIwMjUwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDHKV9n+Kwr3ZBF5UCLWOQ/NdbblAvQeGMjfCi/bibT
# 71hPkwKV4UvQt1MuOwoaUCYtsLhw8jrmOmoz2HoHKKzEpiS3A1rA3ssXUZMnSrbi
# iVpDj+5MtnbXSVEJKbccuHbmwcjl39N4W72zccoC/neKAuwO1DJ+9SO+YkHncRiV
# 95idWhxRAcDYv47hc9GEFZtTFxQXLbrL4N7N90BqLle3ayznzccEPQ+E6H6p00zE
# 9HUp++3bZTF4PfyPRnKCLc5ezAzEqqbbU5F/nujx69T1mm02jltlFXnTMF1vlake
# QXWYpGIjtrR7WP7tIMZnk78nrYSfeAp8le+/W/5+qr7tqQZufW9invsRTcfk7P+m
# nKjJLuSbwqgxelvCBryz9r51bT0561aR2c+joFygqW7n4FPCnMLOj40X4ot7wP2u
# 8kLRDVHbhsHq5SGLqr8DbFq14ws2ALS3tYa2GGiA7wX79rS5oDMnSY/xmJO5cupu
# SvqpylzO7jzcLOwWiqCrq05AXp51SRrj9xRt8KdZWpDdWhWmE8MFiFtmQ0AqODLJ
# Bn1hQAx3FvD/pte6pE1Bil0BOVC2Snbeq/3NylDwvDdAg/0CZRJsQIaydHswJwyY
# BlYUDyaQK2yUS57hobnYx/vStMvTB96ii4jGV3UkZh3GvwdDCsZkbJXaU8ATF/z6
# DwIDAQABo4IBUDCCAUwwdQYIKwYBBQUHAQEEaTBnMDsGCCsGAQUFBzAChi9odHRw
# Oi8vc3ViY2EucmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3RzY2EyMDIxLmNlcjAoBggr
# BgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTAfBgNVHSMEGDAW
# gBS+VAIvv0Bsc0POrAklTp5DRBru4DAMBgNVHRMBAf8EAjAAMDkGA1UdHwQyMDAw
# LqAsoCqGKGh0dHA6Ly9zdWJjYS5jcmwuY2VydHVtLnBsL2N0c2NhMjAyMS5jcmww
# FgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMCIGA1UdIAQb
# MBkwCAYGZ4EMAQQCMA0GCyqEaAGG9ncCBQELMB0GA1UdDgQWBBSBjAagKFP8AD/b
# fp5KwR8i7LISiTANBgkqhkiG9w0BAQwFAAOCAgEAmQ8ZDBvrBUPnaL87AYc4Jlmf
# H1ZP5yt65MtzYu8fbmsL3d3cvYs+Enbtfu9f2wMehzSyved3Rc59a04O8NN7plw4
# PXg71wfSE4MRFM1EuqL63zq9uTjm/9tA73r1aCdWmkprKp0aLoZolUN0qGcvr9+Q
# G8VIJVMcuSqFeEvRrLEKK2xVkMSdTTbDhseUjI4vN+BrXm5z45EA3aDpSiZQuoNd
# 4RFnDzddbgfcCQPaY2UyXqzNBjnuz6AyHnFzKtNlCevkMBgh4dIDt/0DGGDOaTEA
# WZtUEqK5AlHd0PBnd40Lnog4UATU3Bt6GHfeDmWEHFTjHKsmn9Q8wiGj906bVgL8
# 35tfEH9EgYDklqrOUxWxDf1cOA7ds/r8pIc2vjLQ9tOSkm9WXVbnTeLG3Q57frTg
# CvTObd/qf3UzE97nTNOU7vOMZEo41AgmhuEbGsyQIDM/V6fJQX1RnzzJNoqfTTkU
# zUoP2tlNHnNsjFo2YV+5yZcoaawmNWmR7TywUXG2/vFgJaG0bfEoodeeXp7A4I4H
# aDDpfRa7ypgJEPeTwHuBRJpj9N+1xtri+6BzHPwsAAvUJm58PGoVsteHAXwvpg4N
# VgvUk3BKbl7xFulWU1KHqH/sk7T0CFBQ5ohuKPmFf1oqAP4AO9a3Yg2wBMwEg1zP
# Oh6xbUXskzs9iSa9yGwwgga5MIIEoaADAgECAhEAmaOACiZVO2Wr3G6EprPqOTAN
# BgkqhkiG9w0BAQwFADCBgDELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8g
# VGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9u
# IEF1dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAy
# MB4XDTIxMDUxOTA1MzIxOFoXDTM2MDUxODA1MzIxOFowVjELMAkGA1UEBhMCUEwx
# ITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2Vy
# dHVtIENvZGUgU2lnbmluZyAyMDIxIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAnSPPBDAjO8FGLOczcz5jXXp1ur5cTbq96y34vuTmflN4mSAfgLKT
# vggv24/rWiVGzGxT9YEASVMw1Aj8ewTS4IndU8s7VS5+djSoMcbvIKck6+hI1shs
# ylP4JyLvmxwLHtSworV9wmjhNd627h27a8RdrT1PH9ud0IF+njvMk2xqbNTIPsnW
# tw3E7DmDoUmDQiYi/ucJ42fcHqBkbbxYDB7SYOouu9Tj1yHIohzuC8KNqfcYf7Z4
# /iZgkBJ+UFNDcc6zokZ2uJIxWgPWXMEmhu1gMXgv8aGUsRdaCtVD2bSlbfsq7Biq
# ljjaCun+RJgTgFRCtsuAEw0pG9+FA+yQN9n/kZtMLK+Wo837Q4QOZgYqVWQ4x6cM
# 7/G0yswg1ElLlJj6NYKLw9EcBXE7TF3HybZtYvj9lDV2nT8mFSkcSkAExzd4prHw
# YjUXTeZIlVXqj+eaYqoMTpMrfh5MCAOIG5knN4Q/JHuurfTI5XDYO962WZayx7AC
# Ff5ydJpoEowSP07YaBiQ8nXpDkNrUA9g7qf/rCkKbWpQ5boufUnq1UiYPIAHlezf
# 4muJqxqIns/kqld6JVX8cixbd6PzkDpwZo4SlADaCi2JSplKShBSND36E/ENVv8u
# rPS0yOnpG4tIoBGxVCARPCg1BnyMJ4rBJAcOSnAWd18Jx5n858JSqPECAwEAAaOC
# AVUwggFRMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFN10XUwA23ufoHTKsW73
# PMAywHDNMB8GA1UdIwQYMBaAFLahVDkCw6A/joq8+tT4HKbROg79MA4GA1UdDwEB
# /wQEAwIBBjATBgNVHSUEDDAKBggrBgEFBQcDAzAwBgNVHR8EKTAnMCWgI6Ahhh9o
# dHRwOi8vY3JsLmNlcnR1bS5wbC9jdG5jYTIuY3JsMGwGCCsGAQUFBwEBBGAwXjAo
# BggrBgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTAyBggrBgEF
# BQcwAoYmaHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBsL2N0bmNhMi5jZXIwOQYD
# VR0gBDIwMDAuBgRVHSAAMCYwJAYIKwYBBQUHAgEWGGh0dHA6Ly93d3cuY2VydHVt
# LnBsL0NQUzANBgkqhkiG9w0BAQwFAAOCAgEAdYhYD+WPUCiaU58Q7EP89DttyZqG
# Yn2XRDhJkL6P+/T0IPZyxfxiXumYlARMgwRzLRUStJl490L94C9LGF3vjzzH8Jq3
# iR74BRlkO18J3zIdmCKQa5LyZ48IfICJTZVJeChDUyuQy6rGDxLUUAsO0eqeLNhL
# Vsgw6/zOfImNlARKn1FP7o0fTbj8ipNGxHBIutiRsWrhWM2f8pXdd3x2mbJCKKtl
# 2s42g9KUJHEIiLni9ByoqIUul4GblLQigO0ugh7bWRLDm0CdY9rNLqyA3ahe8Wlx
# VWkxyrQLjH8ItI17RdySaYayX3PhRSC4Am1/7mATwZWwSD+B7eMcZNhpn8zJ+6MT
# yE6YoEBSRVrs0zFFIHUR08Wk0ikSf+lIe5Iv6RY3/bFAEloMU+vUBfSouCReZwSL
# o8WdrDlPXtR0gicDnytO7eZ5827NS2x7gCBibESYkOh1/w1tVxTpV2Na3PR7nxYV
# lPu1JPoRZCbH86gc96UTvuWiOruWmyOEMLOGGniR+x+zPF/2DaGgK2W1eEJfo2qy
# rBNPvF7wuAyQfiFXLwvWHamoYtPZo0LHuH8X3n9C+xN4YaNjt2ywzOr+tKyEVAot
# nyU9vyEVOaIYMk3IeBrmFnn0gbKeTTyYeEEUz/Qwt4HOUBCrW602NCmvO1nm+/80
# nLy5r0AZvCQxaQ4wgga5MIIEoaADAgECAhEA5/9pxzs1zkuRJth0fGilhzANBgkq
# hkiG9w0BAQwFADCBgDELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVj
# aG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1
# dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMB4X
# DTIxMDUxOTA1MzIwN1oXDTM2MDUxODA1MzIwN1owVjELMAkGA1UEBhMCUEwxITAf
# BgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2VydHVt
# IFRpbWVzdGFtcGluZyAyMDIxIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEA6RIfBDXtuV16xaaVQb6KZX9Od9FtJXXTZo7b+GEof3+3g0ChWiKnO7R4
# +6MfrvLyLCWZa6GpFHjEt4t0/GiUQvnkLOBRdBqr5DOvlmTvJJs2X8ZmWgWJjC7P
# BZLYBWAs8sJl3kNXxBMX5XntjqWx1ZOuuXl0R4x+zGGSMzZ45dpvB8vLpQfZkfMC
# /1tL9KYyjU+htLH68dZJPtzhqLBVG+8ljZ1ZFilOKksS79epCeqFSeAUm2eMTGpO
# iS3gfLM6yvb8Bg6bxg5yglDGC9zbr4sB9ceIGRtCQF1N8dqTgM/dSViiUgJkcv5d
# LNJeWxGCqJYPgzKlYZTgDXfGIeZpEFmjBLwURP5ABsyKoFocMzdjrCiFbTvJn+bD
# 1kq78qZUgAQGGtd6zGJ88H4NPJ5Y2R4IargiWAmv8RyvWnHr/VA+2PrrK9eXe5q7
# M88YRdSTq9TKbqdnITUgZcjjm4ZUjteq8K331a4P0s2in0p3UubMEYa/G5w6jSWP
# UzchGLwWKYBfeSu6dIOC4LkeAPvmdZxSB1lWOb9HzVWZoM8Q/blaP4LWt6JxjkI9
# yQsYGMdCqwl7uMnPUIlcExS1mzXRxUowQref/EPaS7kYVaHHQrp4XB7nTEtQhkP0
# Z9Puz/n8zIFnUSnxDof4Yy650PAXSYmK2TcbyDoTNmmt8xAxzcMCAwEAAaOCAVUw
# ggFRMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFL5UAi+/QGxzQ86sCSVOnkNE
# Gu7gMB8GA1UdIwQYMBaAFLahVDkCw6A/joq8+tT4HKbROg79MA4GA1UdDwEB/wQE
# AwIBBjATBgNVHSUEDDAKBggrBgEFBQcDCDAwBgNVHR8EKTAnMCWgI6Ahhh9odHRw
# Oi8vY3JsLmNlcnR1bS5wbC9jdG5jYTIuY3JsMGwGCCsGAQUFBwEBBGAwXjAoBggr
# BgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTAyBggrBgEFBQcw
# AoYmaHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBsL2N0bmNhMi5jZXIwOQYDVR0g
# BDIwMDAuBgRVHSAAMCYwJAYIKwYBBQUHAgEWGGh0dHA6Ly93d3cuY2VydHVtLnBs
# L0NQUzANBgkqhkiG9w0BAQwFAAOCAgEAuJNZd8lMFf2UBwigp3qgLPBBk58BFCS3
# Q6aJDf3TISoytK0eal/JyCB88aUEd0wMNiEcNVMbK9j5Yht2whaknUE1G32k6uld
# 7wcxHmw67vUBY6pSp8QhdodY4SzRRaZWzyYlviUpyU4dXyhKhHSncYJfa1U75cXx
# Ce3sTp9uTBm3f8Bj8LkpjMUSVTtMJ6oEu5JqCYzRfc6nnoRUgwz/GVZFoOBGdrSE
# tDN7mZgcka/tS5MI47fALVvN5lZ2U8k7Dm/hTX8CWOw0uBZloZEW4HB0Xra3qE4q
# zzq/6M8gyoU/DE0k3+i7bYOrOk/7tPJg1sOhytOGUQ30PbG++0FfJioDuOFhj99b
# 151SqFlSaRQYz74y/P2XJP+cF19oqozmi0rRTkfyEJIvhIZ+M5XIFZttmVQgTxfp
# fJwMFFEoQrSrklOxpmSygppsUDJEoliC05vBLVQ+gMZyYaKvBJ4YxBMlKH5ZHkRd
# loRYlUDplk8GUa+OCMVhpDSQurU6K1ua5dmZftnvSSz2H96UrQDzA6DyiI1V3ejV
# tvn2azVAXg6NnjmuRZ+wa7Pxy0H3+V4K4rOTHlG3VYA6xfLsTunCz72T6Ot4+tkr
# DYOeaU1pPX1CBfYj6EW2+ELq46GP8KCNUQDirWLU4nOmgCat7vN0SD6RlwUiSsMe
# CiQDmZwgwrUwggbpMIIE0aADAgECAhBiOsZKIV2oSfsf25d4iu6HMA0GCSqGSIb3
# DQEBCwUAMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0
# ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNpZ25pbmcgMjAyMSBDQTAe
# Fw0yNTA3MzExMTM4MDhaFw0yNjA3MzExMTM4MDdaMIGOMQswCQYDVQQGEwJERTEb
# MBkGA1UECAwSQmFkZW4tV8O8cnR0ZW1iZXJnMRQwEgYDVQQHDAtCYWllcnNicm9u
# bjEeMBwGA1UECgwVT3BlbiBTb3VyY2UgRGV2ZWxvcGVyMSwwKgYDVQQDDCNPcGVu
# IFNvdXJjZSBEZXZlbG9wZXIsIEhlcHAgQW5kcmVhczCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAOt2txKXx2UtfBNIw2kVihIAcgPkK3lp7np/qE0evLq2
# J/L5kx8m6dUY4WrrcXPSn1+W2/PVs/XBFV4fDfwczZnQ/hYzc8Ot5YxPKLx6hZxK
# C5v8LjNIZ3SRJvMbOpjzWoQH7MLIIj64n8mou+V0CMk8UElmU2d0nxBQyau1njQP
# CLvlfInu4tDndyp3P87V5bIdWw6MkZFhWDkILTYInYicYEkut5dN9hT02t/3rXu2
# 30DEZ6S1OQtm9loo8wzvwjRoVX3IxnfpCHGW8Z9ie9I9naMAOG2YpvpoUbLG3fL/
# B6JVNNR1mm/AYaqVMtAXJpRlqvbIZyepcG0YGB+kOQLdoQCWlIp3a14Z4kg6bU9C
# U1KNR4ueA+SqLNu0QGtgBAdTfqoWvyiaeyEogstBHglrZ39y/RW8OOa50pSleSRx
# SXiGW+yH+Ps5yrOopTQpKHy0kRincuJpYXgxGdGxxKHwuVJHKXL0nWScEku0C38p
# M9sYanIKncuF0Ed7RvyNqmPP5pt+p/0ZG+zLNu/Rce0LE5FjAIRtW2hFxmYMyohk
# afzyjCCCG0p2KFFT23CoUfXx59nCU+lyWx/iyDMV4sqrcvmZdPZF7lkaIb5B4PYP
# vFFE7enApz4Niycj1gPUFlx4qTcXHIbFLJDp0ry6MYelX+SiMHV7yDH/rnWXm5d3
# AgMBAAGjggF4MIIBdDAMBgNVHRMBAf8EAjAAMD0GA1UdHwQ2MDQwMqAwoC6GLGh0
# dHA6Ly9jY3NjYTIwMjEuY3JsLmNlcnR1bS5wbC9jY3NjYTIwMjEuY3JsMHMGCCsG
# AQUFBwEBBGcwZTAsBggrBgEFBQcwAYYgaHR0cDovL2Njc2NhMjAyMS5vY3NwLWNl
# cnR1bS5jb20wNQYIKwYBBQUHMAKGKWh0dHA6Ly9yZXBvc2l0b3J5LmNlcnR1bS5w
# bC9jY3NjYTIwMjEuY2VyMB8GA1UdIwQYMBaAFN10XUwA23ufoHTKsW73PMAywHDN
# MB0GA1UdDgQWBBQYl6R41hwxInb9JVvqbCTp9ILCcTBLBgNVHSAERDBCMAgGBmeB
# DAEEATA2BgsqhGgBhvZ3AgUBBDAnMCUGCCsGAQUFBwIBFhlodHRwczovL3d3dy5j
# ZXJ0dW0ucGwvQ1BTMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIH
# gDANBgkqhkiG9w0BAQsFAAOCAgEAQ4guyo7zysB7MHMBOVKKY72rdY5hrlxPci8u
# 1RgBZ9ZDGFzhnUM7iIivieAeAYLVxP922V3ag9sDVNR+mzCmu1pWCgZyBbNXykue
# KJwOfE8VdpmC/F7637i8a7Pyq6qPbcfvLSqiXtVrT4NX4NIvODW3kIqf4nGwd0h3
# 1tuJVHLkdpGmT0q4TW0gAxnNoQ+lO8uNzCrtOBk+4e1/3CZXSDnjR8SUsHrHdhnm
# qkAnYb40vf69dfDR148tToUj872yYeBUEGUsQUDgJ6HSkMVpLQz/Nb3xy9qkY33M
# 7CBWKuBVwEcbGig/yj7CABhIrY1XwRddYQhEyozUS4mXNqXydAD6Ylt143qrECD2
# s3MDQBgP2sbRHdhVgzr9+n1iztXkPHpIlnnXPkZrt89E5iGL+1PtjETrhTkr7nxj
# yMFjrbmJ8W/XglwopUTCGfopDFPlzaoFf5rH/v3uzS24yb6+dwQrvCwFA9Y9ZHy2
# ITJx7/Ll6AxWt7Lz9JCJ5xRyYeRUHs6ycB8EuMPAKyGpzdGtjWv2rkTXbkIYUjkl
# FTpquXJBc/kO5L+Quu0a0uKn4ea16SkABy052XHQqd87cSJg3rGxsagi0IAfxGM6
# 08oupufSS/q9mpQPgkDuMJ8/zdre0st8OduAoG131W+XJ7mm0gIuh2zNmSIet5RD
# oa8THmwxggckMIIHIAIBATBqMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3Nl
# Y28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNpZ25p
# bmcgMjAyMSBDQQIQYjrGSiFdqEn7H9uXeIruhzANBglghkgBZQMEAgEFAKCBhDAY
# BgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3
# AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEi
# BCDi1NLHQkdA1cVaEnC8F16lSfLeVGNtIVAi1JI9EzeslzANBgkqhkiG9w0BAQEF
# AASCAgBbTJkqYpOkpQB22Py9poxCBUVUjFiv4GAUiq4zghA7Muoyy/8JQufcGQkt
# yiysL8gL7ApDw0uW46TANFvg7kEY74pGMd9yyipvycCU3eHZz8V4C5tLhcGwLMDg
# n8gp/p5JwfIMvfEW57Cuvg7iz0IndZhJlldZ2xqpv04Hr6UvKGtcb8PXzH6IhkAG
# vBHnVrIuKXgJc4M2V0tuoOWzK5zmEvw/h9VJjxgc3c20YuQbSKY5VofCF6pmocx9
# AyDFJv15owCN9k0zm5O6HmHIBqMs5edRDRXuDliTsQpJyRjPsPf96LNPOGu3rQoa
# 5Ho5b02OfFa53HwAEEtr/b/nJ8SjkfLN6A984RiCaOZpJ+Tb1mCwIJNzssmBsiNF
# W6aDIJiWomJikNhX/MX+0x0ymoYXxID8zqLGi4Kkzm6hmo0rLL5tyxS4tVOAb6Bo
# AhRhOo5SuHfeRZMqVvFast/pMKu7Cb3PFWkfkdOfl6viQWtBm1kG22yid3vr/DYC
# 0sr60oFUlVo7SyGa7fCiMRa5VmDBTlAYxURehROCv6vh8/kjbxcZ7gSta4/qcF/M
# iaHnay+XZP/xmen8SoQqKI1HqxyJpjJv6/U1G2SD3BdcS4OUG/QMqB/wN/fjg7++
# Tpgoanu0Il6h+hDYq4nJvKN/7tL6m9Qn1+v8X7WGxkmt6lEvjaGCBAQwggQABgkq
# hkiG9w0BCQYxggPxMIID7QIBATBrMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3Rh
# bXBpbmcgMjAyMSBDQQIRAJ6cBPZVqLSnAm1JjGx4jaowDQYJYIZIAWUDBAICBQCg
# ggFXMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcN
# MjUxMDI1MTc1OTIzWjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDPodw1ne0rw8uJ
# D6Iw5dr3e1QPGm4rI93PF1ThjPqg1TA/BgkqhkiG9w0BCQQxMgQwYYoOGHHSxXwJ
# Pac1hbQHgKZR5IbYjKGxNOLsHyj/KF7za+l+YsHPS/hSS/VVAcDXMIGgBgsqhkiG
# 9w0BCRACDDGBkDCBjTCBijCBhwQUwyW4mxf8xQJgYc4rcXtFB92camowbzBapFgw
# VjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhEAnpwE9lWo
# tKcCbUmMbHiNqjANBgkqhkiG9w0BAQEFAASCAgAoSNleUuDSyc3rEBc4hftwFawR
# rvJImgHPSYz1ptMFf9xQxXoH43ZBturDWliKlLZDrrYpcex590Af6nkSE5w959Qg
# yp5ZKJfG0FXqLH7TbzMH2pwbPNxoomXEBUNtBt6SsqhphEd4f5fycAs2TnDgjr7o
# YBHqQ4UGU31lHezLv5S8fnLaL48IYlioFPLktU/uQpFiLHztu708jcivXW7IpR/H
# VeZQeLFesWrxivGYRtEw3czkwmLajUOyj1cs+UbY/3k+Wbs8LhM4/rNKnEagmpqU
# 8HkLRV4i5ksN2YZfkVrPNkmUGmLLpiVBFGZn66HRHou8mkkaRor8pT07Fd4uoBFp
# tMsq5KqojDIurdVJNeoOeeiM38JElovtalDrUtopG5b9BRYYKqIZt20QAaRzX9+U
# RJv2UYKtHDLPzSvjkG6gE0duVb/SzILEtIEcj5aN/JevDlLMpcUZzkbE09Mm9Upx
# umBOBOUtxAQy13bxxIcstM1IfVnynPRLoioEL1V/jPwNdith9iEFGxq9TKifwWcb
# 6mfsO1s0OFO8VuV+I+BomVOjDHSvNiH6GJ8m0qZ2n8KvXYNoxVmz1GbsEhABNC4I
# 1PSf2PyoTkE9H5gDRMNb7DKTkRO/wPF8PWDBAfypncYFfu+5EaOuc7ar5OdtbA+F
# cZJOuf1lgjaSDaBMNA==
# SIG # End signature block
