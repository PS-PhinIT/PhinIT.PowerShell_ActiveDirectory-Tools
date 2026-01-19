# Parameter block - all required parameters are declared here
param(
    [string]$wkhtmltopdfPath = "",
    # URL to PowerShell 7 setup package (adjust if needed)
    [string]$PS7SetupURL = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.0/PowerShell-7.5.0-win-x64.msi",
    # URL to wkhtmltopdf setup package
    [string]$wkhtmltopdfURL = "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox-0.12.6-1.msvc2015-win64.exe"
)

# Add required .NET assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -----------------------------------
# Function: Display Installation Wizard (GUI)
# -----------------------------------
function Show-InstallerForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Installation Wizard"
    $form.Size = New-Object System.Drawing.Size(500,400)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false

    # Status Label (all messages are displayed here)
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Location = New-Object System.Drawing.Point(20,20)
    $lblStatus.Size = New-Object System.Drawing.Size(440,60)
    $lblStatus.Text = "Ready..."
    $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI",10)
    $form.Controls.Add($lblStatus)

    # ProgressBar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20,90)
    $progressBar.Size = New-Object System.Drawing.Size(440,25)
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Style = "Continuous"
    $form.Controls.Add($progressBar)

    # Checkbox: Automatically set execution policy to RemoteSigned
    $chkSetPolicy = New-Object System.Windows.Forms.CheckBox
    $chkSetPolicy.Location = New-Object System.Drawing.Point(20,130)
    $chkSetPolicy.Size = New-Object System.Drawing.Size(300,20)
    $chkSetPolicy.Text = "Automatically set to RemoteSigned"
    $chkSetPolicy.Checked = $true
    $form.Controls.Add($chkSetPolicy)
    
    # Status label for Execution Policy
    $lblPolicyStatus = New-Object System.Windows.Forms.Label
    $lblPolicyStatus.Location = New-Object System.Drawing.Point(330,130)
    $lblPolicyStatus.Size = New-Object System.Drawing.Size(150,20)
    $lblPolicyStatus.Text = "CHECKING..."
    $lblPolicyStatus.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblPolicyStatus)

    # Checkbox: Install PowerShell 7
    $chkInstallPS7 = New-Object System.Windows.Forms.CheckBox
    $chkInstallPS7.Location = New-Object System.Drawing.Point(20,160)
    $chkInstallPS7.Size = New-Object System.Drawing.Size(300,20)
    $chkInstallPS7.Text = "Install PowerShell 7"
    $chkInstallPS7.Checked = $true
    $form.Controls.Add($chkInstallPS7)
    
    # Status label for PowerShell 7
    $lblPS7Status = New-Object System.Windows.Forms.Label
    $lblPS7Status.Location = New-Object System.Drawing.Point(330,160)
    $lblPS7Status.Size = New-Object System.Drawing.Size(150,20)
    $lblPS7Status.Text = "CHECKING..."
    $lblPS7Status.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblPS7Status)

    # Checkbox: Install ActiveDirectory module
    $chkInstallADModule = New-Object System.Windows.Forms.CheckBox
    $chkInstallADModule.Location = New-Object System.Drawing.Point(20,190)
    $chkInstallADModule.Size = New-Object System.Drawing.Size(300,20)
    $chkInstallADModule.Text = "Install ActiveDirectory module"
    $chkInstallADModule.Checked = $true
    $form.Controls.Add($chkInstallADModule)
    
    # Status label for ActiveDirectory module
    $lblADStatus = New-Object System.Windows.Forms.Label
    $lblADStatus.Location = New-Object System.Drawing.Point(330,190)
    $lblADStatus.Size = New-Object System.Drawing.Size(150,20)
    $lblADStatus.Text = "CHECKING..."
    $lblADStatus.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblADStatus)

    # Checkbox: Install wkhtmltopdf
    $chkInstallwkhtmltopdf = New-Object System.Windows.Forms.CheckBox
    $chkInstallwkhtmltopdf.Location = New-Object System.Drawing.Point(20,220)
    $chkInstallwkhtmltopdf.Size = New-Object System.Drawing.Size(300,20)
    $chkInstallwkhtmltopdf.Text = "Install wkhtmltopdf"
    $chkInstallwkhtmltopdf.Checked = $true
    $form.Controls.Add($chkInstallwkhtmltopdf)
    
    # Status label for wkhtmltopdf
    $lblWkStatus = New-Object System.Windows.Forms.Label
    $lblWkStatus.Location = New-Object System.Drawing.Point(330,220)
    $lblWkStatus.Size = New-Object System.Drawing.Size(150,20)
    $lblWkStatus.Text = "CHECKING..."
    $lblWkStatus.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblWkStatus)

    # Button "Install" (light green)
    $btnInstall = New-Object System.Windows.Forms.Button
    $btnInstall.Text = "Install"
    $btnInstall.Size = New-Object System.Drawing.Size(100,30)
    $btnInstall.Location = New-Object System.Drawing.Point(100,300)
    $btnInstall.BackColor = [System.Drawing.Color]::LightGreen
    $form.Controls.Add($btnInstall)

    # Button "Close" (light red)
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close"
    $btnClose.Size = New-Object System.Drawing.Size(100,30)
    $btnClose.Location = New-Object System.Drawing.Point(300,300)
    $btnClose.BackColor = [System.Drawing.Color]::LightCoral
    $form.Controls.Add($btnClose)
    
    # Load Form event to immediately check installations
    # Use script: prefix to access these variables in the scriptblock
    $script:lblStatus = $lblStatus
    $script:lblPolicyStatus = $lblPolicyStatus
    $script:lblPS7Status = $lblPS7Status
    $script:lblADStatus = $lblADStatus
    $script:lblWkStatus = $lblWkStatus
    
    $form.Add_Load({
        $script:lblStatus.Text = "Checking installation status..."
        [System.Windows.Forms.Application]::DoEvents()
        
        # Check execution policy status
        $currentPolicy = Get-ExecutionPolicy
        if ($currentPolicy -eq "RemoteSigned" -or $currentPolicy -eq "Unrestricted") {
            $script:lblPolicyStatus.Text = "CONFIGURED"
            $script:lblPolicyStatus.ForeColor = [System.Drawing.Color]::Green
        } else {
            $script:lblPolicyStatus.Text = "NOT CONFIGURED"
            $script:lblPolicyStatus.ForeColor = [System.Drawing.Color]::Red
        }
        
        # Check PowerShell 7 status
        $ps7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        if ($ps7) {
            $script:lblPS7Status.Text = "INSTALLED"
            $script:lblPS7Status.ForeColor = [System.Drawing.Color]::Green
        } else {
            $script:lblPS7Status.Text = "NOT INSTALLED"
            $script:lblPS7Status.ForeColor = [System.Drawing.Color]::Red
        }
        
        # Check ActiveDirectory module status
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            $script:lblADStatus.Text = "INSTALLED"
            $script:lblADStatus.ForeColor = [System.Drawing.Color]::Green
        } else {
            $script:lblADStatus.Text = "NOT INSTALLED"
            $script:lblADStatus.ForeColor = [System.Drawing.Color]::Red
        }
        
        # Check wkhtmltopdf status
        $wkhtmltopdfInstalled = $false
        $possiblePaths = @(
            "${env:ProgramFiles}\wkhtmltopdf\bin\wkhtmltopdf.exe",
            "${env:ProgramFiles(x86)}\wkhtmltopdf\bin\wkhtmltopdf.exe",
            "C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe",
            "C:\Program Files (x86)\wkhtmltopdf\bin\wkhtmltopdf.exe"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $wkhtmltopdfInstalled = $true
                $script:wkhtmltopdfPath = $path
                break
            }
        }
        
        if ($wkhtmltopdfInstalled) {
            $script:lblWkStatus.Text = "INSTALLED"
            $script:lblWkStatus.ForeColor = [System.Drawing.Color]::Green
        } else {
            $script:lblWkStatus.Text = "NOT INSTALLED"
            $script:lblWkStatus.ForeColor = [System.Drawing.Color]::Red
        }
        
        $script:lblStatus.Text = "Ready..."
    })

    return @{
        Form = $form;
        Label = $lblStatus;
        ProgressBar = $progressBar;
        SetPolicyCheckBox = $chkSetPolicy;
        InstallPS7CheckBox = $chkInstallPS7;
        InstallADModuleCheckBox = $chkInstallADModule;
        InstallwkhtmltopdfCheckBox = $chkInstallwkhtmltopdf;
        InstallButton = $btnInstall;
        CloseButton = $btnClose;
        PolicyStatusLabel = $lblPolicyStatus;
        PS7StatusLabel = $lblPS7Status;
        ADStatusLabel = $lblADStatus;
        WkStatusLabel = $lblWkStatus
    }
}

# -----------------------------------
# Function: Check installation status of components
# -----------------------------------
function Update-InstallationStatus {
    param(
        $guiElements
    )
    
    # Check execution policy status
    $currentPolicy = Get-ExecutionPolicy
    if ($currentPolicy -eq "RemoteSigned" -or $currentPolicy -eq "Unrestricted") {
        $guiElements.PolicyStatusLabel.Text = "CONFIGURED"
        $guiElements.PolicyStatusLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        $guiElements.PolicyStatusLabel.Text = "NOT CONFIGURED"
        $guiElements.PolicyStatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
    
    # Check PowerShell 7 status
    $ps7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($ps7) {
        $guiElements.PS7StatusLabel.Text = "INSTALLED"
        $guiElements.PS7StatusLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        $guiElements.PS7StatusLabel.Text = "NOT INSTALLED"
        $guiElements.PS7StatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
    
    # Check ActiveDirectory module status
    if (Get-Module -ListAvailable -Name ActiveDirectory) {
        $guiElements.ADStatusLabel.Text = "INSTALLED"
        $guiElements.ADStatusLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        $guiElements.ADStatusLabel.Text = "NOT INSTALLED"
        $guiElements.ADStatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
    
    # Check wkhtmltopdf status
    $wkhtmltopdfInstalled = $false
    $possiblePaths = @(
        "${env:ProgramFiles}\wkhtmltopdf\bin\wkhtmltopdf.exe",
        "${env:ProgramFiles(x86)}\wkhtmltopdf\bin\wkhtmltopdf.exe",
        "C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe",
        "C:\Program Files (x86)\wkhtmltopdf\bin\wkhtmltopdf.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $wkhtmltopdfInstalled = $true
            $global:wkhtmltopdfPath = $path
            break
        }
    }
    
    if ($wkhtmltopdfInstalled) {
        $guiElements.WkStatusLabel.Text = "INSTALLED"
        $guiElements.WkStatusLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        $guiElements.WkStatusLabel.Text = "NOT INSTALLED"
        $guiElements.WkStatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
}

# -----------------------------------
# Function: Execute Installation (all steps)
# -----------------------------------
function Run-Installation {
    param(
        $guiElements
    )
    $lbl = $guiElements.Label
    $pb = $guiElements.ProgressBar
    $chkSetPolicy = $guiElements.SetPolicyCheckBox
    $chkInstallPS7 = $guiElements.InstallPS7CheckBox
    $chkInstallAD = $guiElements.InstallADModuleCheckBox
    $chkInstallwkhtmltopdf = $guiElements.InstallwkhtmltopdfCheckBox

    try {
        # Step 1: Check execution policy
        $lbl.Text = "Checking execution policy..."
        [System.Windows.Forms.Application]::DoEvents()
        $currentPolicy = Get-ExecutionPolicy
        if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "AllSigned") {
            if ($chkSetPolicy.Checked) {
                Set-ExecutionPolicy RemoteSigned -Scope Process -Force
                $lbl.Text = "Execution policy set to RemoteSigned."
                $guiElements.PolicyStatusLabel.Text = "CONFIGURED"
                $guiElements.PolicyStatusLabel.ForeColor = [System.Drawing.Color]::Green
            }
            else {
                $lbl.Text = "Execution policy ($currentPolicy) is too restrictive."
                $guiElements.PolicyStatusLabel.Text = "NOT CONFIGURED"
                $guiElements.PolicyStatusLabel.ForeColor = [System.Drawing.Color]::Red
            }
        }
        else {
            $lbl.Text = "Execution policy ($currentPolicy) is acceptable."
            $guiElements.PolicyStatusLabel.Text = "CONFIGURED"
            $guiElements.PolicyStatusLabel.ForeColor = [System.Drawing.Color]::Green
        }
        Start-Sleep -Seconds 1
        $pb.Value = 20
        [System.Windows.Forms.Application]::DoEvents()

        # Step 2: Remove msstore source to avoid manual confirmations
        try {
            winget source remove msstore -ErrorAction Stop | Out-Null
            $lbl.Text = "msstore source removed."
        }
        catch {
            $lbl.Text = "msstore source could not be removed or is already removed."
        }
        Start-Sleep -Seconds 1
        $pb.Value = 30
        [System.Windows.Forms.Application]::DoEvents()

        # Step 3: Check PowerShell 7 and install if needed
        if ($chkInstallPS7.Checked) {
            $lbl.Text = "Checking PowerShell 7..."
            [System.Windows.Forms.Application]::DoEvents()
            $ps7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
            if ($ps7) {
                $lbl.Text = "PowerShell 7 is already installed."
                $guiElements.PS7StatusLabel.Text = "INSTALLED"
                $guiElements.PS7StatusLabel.ForeColor = [System.Drawing.Color]::Green
            }
            else {
                $lbl.Text = "PowerShell 7 not found. Checking installation options..."
                [System.Windows.Forms.Application]::DoEvents()
                
                # Check if WinGet is available
                $winget = Get-Command winget -ErrorAction SilentlyContinue
                $installSuccess = $false
                
                if ($winget) {
                    $lbl.Text = "Installing PowerShell 7 using WinGet..."
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    try {
                        # Install PowerShell 7 using WinGet
                        Start-Process -FilePath "winget" -ArgumentList "install --id Microsoft.PowerShell -e" -Wait -NoNewWindow
                        
                        # Check if WinGet installation was successful
                        $ps7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
                        if ($ps7) {
                            $lbl.Text = "PowerShell 7 successfully installed using WinGet."
                            $guiElements.PS7StatusLabel.Text = "INSTALLED"
                            $guiElements.PS7StatusLabel.ForeColor = [System.Drawing.Color]::Green
                            $installSuccess = $true
                        }
                        else {
                            $lbl.Text = "WinGet installation completed but PowerShell 7 not detected. Falling back to MSI..."
                            [System.Windows.Forms.Application]::DoEvents()
                        }
                    }
                    catch {
                        $lbl.Text = "Error using WinGet: $($_.Exception.Message). Falling back to MSI installation..."
                        [System.Windows.Forms.Application]::DoEvents()
                    }
                }
                
                # If WinGet is not available or failed, use MSI installation
                if (-not $installSuccess) {
                    $lbl.Text = "Using MSI installation method..."
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    # Download PS7 MSI
                    $setupPath = Join-Path $env:TEMP "PowerShell-7.5.0-win-x64.msi"
                    try {
                        $lbl.Text = "Downloading PowerShell 7 MSI..."
                        [System.Windows.Forms.Application]::DoEvents()
                        Invoke-WebRequest -Uri $PS7SetupURL -OutFile $setupPath -ErrorAction Stop
                        $lbl.Text = "PowerShell 7 downloaded. Starting installation..."
                        [System.Windows.Forms.Application]::DoEvents()
                        
                        # Install PS7
                        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $setupPath, "/quiet", "/norestart" -Wait -NoNewWindow
                        
                        # Check if installed
                        $ps7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
                        if ($ps7) {
                            $lbl.Text = "PowerShell 7 successfully installed using MSI."
                            $guiElements.PS7StatusLabel.Text = "INSTALLED"
                            $guiElements.PS7StatusLabel.ForeColor = [System.Drawing.Color]::Green
                        }
                        else {
                            $lbl.Text = "PowerShell 7 installation failed. Please try manually."
                            $guiElements.PS7StatusLabel.Text = "NOT INSTALLED"
                            $guiElements.PS7StatusLabel.ForeColor = [System.Drawing.Color]::Red
                        }
                        
                        # Clean up
                        if (Test-Path $setupPath) {
                            Remove-Item $setupPath -Force
                        }
                    }
                    catch {
                        $lbl.Text = "Failed to install PowerShell 7: $($_.Exception.Message)"
                        $guiElements.PS7StatusLabel.Text = "NOT INSTALLED"
                        $guiElements.PS7StatusLabel.ForeColor = [System.Drawing.Color]::Red
                    }
                }
            }
            Start-Sleep -Seconds 1
            $pb.Value = 50
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Step 4: Check and install ActiveDirectory module
        if ($chkInstallAD.Checked) {
            $lbl.Text = "Checking ActiveDirectory module..."
            [System.Windows.Forms.Application]::DoEvents()
            if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
                $lbl.Text = "ActiveDirectory module not found. Attempting installation..."
                [System.Windows.Forms.Application]::DoEvents()
                try {
                    Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ErrorAction Stop
                    $lbl.Text = "ActiveDirectory module successfully installed."
                    $guiElements.ADStatusLabel.Text = "INSTALLED"
                    $guiElements.ADStatusLabel.ForeColor = [System.Drawing.Color]::Green
                }
                catch {
                    $lbl.Text = "RSAT installation failed. Please install manually."
                    $guiElements.ADStatusLabel.Text = "NOT INSTALLED"
                    $guiElements.ADStatusLabel.ForeColor = [System.Drawing.Color]::Red
                }
            }
            else {
                $lbl.Text = "ActiveDirectory module is available."
                $guiElements.ADStatusLabel.Text = "INSTALLED"
                $guiElements.ADStatusLabel.ForeColor = [System.Drawing.Color]::Green
            }
            Start-Sleep -Seconds 1
            $pb.Value = 70
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Step 5: Check and install wkhtmltopdf
        if ($chkInstallwkhtmltopdf.Checked) {
            $lbl.Text = "Checking wkhtmltopdf installation..."
            [System.Windows.Forms.Application]::DoEvents()
            
            # Check if wkhtmltopdf is already installed
            $wkhtmltopdfInstalled = $false
            $possiblePaths = @(
                "${env:ProgramFiles}\wkhtmltopdf\bin\wkhtmltopdf.exe",
                "${env:ProgramFiles(x86)}\wkhtmltopdf\bin\wkhtmltopdf.exe",
                "C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe",
                "C:\Program Files (x86)\wkhtmltopdf\bin\wkhtmltopdf.exe"
            )
            
            foreach ($path in $possiblePaths) {
                if (Test-Path $path) {
                    $wkhtmltopdfInstalled = $true
                    $global:wkhtmltopdfPath = $path
                    break
                }
            }
            
            if ($wkhtmltopdfInstalled) {
                $lbl.Text = "wkhtmltopdf is already installed at: $global:wkhtmltopdfPath"
                $guiElements.WkStatusLabel.Text = "INSTALLED"
                $guiElements.WkStatusLabel.ForeColor = [System.Drawing.Color]::Green
            } else {
                $lbl.Text = "wkhtmltopdf not found. Starting installation..."
                [System.Windows.Forms.Application]::DoEvents()
                
                try {
                    # Download wkhtmltopdf installer
                    $setupPath = Join-Path $env:TEMP "wkhtmltox-setup.exe"
                    $lbl.Text = "Downloading wkhtmltopdf installer..."
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    Invoke-WebRequest -Uri $wkhtmltopdfURL -OutFile $setupPath -ErrorAction Stop
                    
                    $lbl.Text = "Installing wkhtmltopdf..."
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    # Install wkhtmltopdf (silent installation)
                    Start-Process -FilePath $setupPath -ArgumentList "/S" -Wait -NoNewWindow
                    
                    # Check if installation was successful
                    Start-Sleep -Seconds 2
                    foreach ($path in $possiblePaths) {
                        if (Test-Path $path) {
                            $wkhtmltopdfInstalled = $true
                            $global:wkhtmltopdfPath = $path
                            break
                        }
                    }
                    
                    if ($wkhtmltopdfInstalled) {
                        $lbl.Text = "wkhtmltopdf successfully installed at: $global:wkhtmltopdfPath"
                        $guiElements.WkStatusLabel.Text = "INSTALLED"
                        $guiElements.WkStatusLabel.ForeColor = [System.Drawing.Color]::Green
                    } else {
                        $lbl.Text = "wkhtmltopdf installation completed but executable not found."
                        $guiElements.WkStatusLabel.Text = "NOT INSTALLED"
                        $guiElements.WkStatusLabel.ForeColor = [System.Drawing.Color]::Red
                    }
                    
                    # Clean up
                    if (Test-Path $setupPath) {
                        Remove-Item $setupPath -Force
                    }
                }
                catch {
                    $lbl.Text = "Error installing wkhtmltopdf: $($_.Exception.Message)"
                    $guiElements.WkStatusLabel.Text = "NOT INSTALLED"
                    $guiElements.WkStatusLabel.ForeColor = [System.Drawing.Color]::Red
                }
            }
            
            Start-Sleep -Seconds 1
            $pb.Value = 90
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Completion
        $lbl.Text = "Installation completed. All selected tools have been checked."
        $pb.Value = 100
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Seconds 2

        # Neue Funktion: Inhalte des aktuellen Ordners kopieren
        $sourceDir = Get-Location
        $destDir = "C:\easyIT\easyONBOARDING"
        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        Copy-Item -Path "$($sourceDir.Path)\*" -Destination $destDir -Recurse -Force

        # Create shortcut on the desktop
        $WScriptShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WScriptShell.CreateShortcut("$([Environment]::GetFolderPath("Desktop"))\easyONBOARDING.lnk")
        $Shortcut.TargetPath = $destDir
        $Shortcut.Save()

    }
    catch {
        $lbl.Text = "Error: $($_.Exception.Message)"
    }
}

# -----------------------------------
# Main: Display GUI and process button events
# -----------------------------------
$gui = Show-InstallerForm
$gui.InstallButton.Add_Click({ Run-Installation -guiElements $gui })
$gui.CloseButton.Add_Click({ $gui.Form.Close() })

# No need to call Update-InstallationStatus here as it's now handled in the Form's Load event
[System.Windows.Forms.Application]::Run($gui.Form)

# SIG # Begin signature block
# MIIoiQYJKoZIhvcNAQcCoIIoejCCKHYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAPawz1mnItD1eC
# oqRLvdrUziQSCFdG+z0lRfLS1fwWc6CCILswggXJMIIEsaADAgECAhAbtY8lKt8j
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
# BCBY7LsSAQuGitazznw/vQjQwwYN6L9mnwLf4rqoGbq+ojANBgkqhkiG9w0BAQEF
# AASCAgBarlacvScKKEsZiBk5sm6SzWjXK+Un3Jgr7br86qUpG2MOEFs9INYgBhKe
# RiuQqgpwzMhZtj7U4l195SeTfyACLNir5k/uZ9mW/3sh73YHpOCX6C8z1IlItcSn
# bGOMogDwe+zg+2noq8vaKWZUDLdP2OVVZQe8LVRZh3x7bpe6QxDwYZi/Ci+E/6b+
# WxDO3qCd5S2W4Ff+bsP5tfSr8SxkdEYcSZcX/ffFBaCTY6lrn7NYW47MxGErmYxJ
# hSSjcF1q3P4xmyk9z9ovSXXUb6aIUAeyx/EOqcV2bfTm5KtG2ZiMMB8T1m8Y4GUA
# 6QbOGIapGSoJVtN5RgXmrDxWN4XnKxSnetcf68xQv3hjjSrSdfldH1ywdISoJubC
# S1kRaCdAVX2jbj+zMNc9D05d8MHdQOGBdXSgYgCmICeMHkEQEzPKniwf1pTKV3bm
# FIjAHwFKhv+uVxb9VHybDC8YEsFCbQGXdLHDiSyaXBVPEeJ62zJAYQMuATBps/4n
# Jl4H+yG/KNozEl57JrmyUJ2zfU0bzHPBhG+i+Vq160nc76IzspLn7qCVh2Nen558
# XdGG1XHV87+DPAtuOGNxtDXK27kaQBz3a8oe9a8GxN7MW+0NZNvy96P1NMMDvIb/
# DC2JV/PK7e3T3P+jgqBrzXbo1oYCOIE+EijJBTIrIs1kHjItm6GCBAQwggQABgkq
# hkiG9w0BCQYxggPxMIID7QIBATBrMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3Rh
# bXBpbmcgMjAyMSBDQQIRAJ6cBPZVqLSnAm1JjGx4jaowDQYJYIZIAWUDBAICBQCg
# ggFXMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcN
# MjUwOTExMTAwMTU1WjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDPodw1ne0rw8uJ
# D6Iw5dr3e1QPGm4rI93PF1ThjPqg1TA/BgkqhkiG9w0BCQQxMgQw1LV9Ct+529OJ
# I/J1bwuMd/zP5iBmCJ/44NAtHqFPVy+vqNGWh/KvWrk31l7Aos78MIGgBgsqhkiG
# 9w0BCRACDDGBkDCBjTCBijCBhwQUwyW4mxf8xQJgYc4rcXtFB92camowbzBapFgw
# VjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhEAnpwE9lWo
# tKcCbUmMbHiNqjANBgkqhkiG9w0BAQEFAASCAgAdk4MUHsrBs2Gxkju1Qoj5ZHGd
# GwKeNRI+xNOKo3+Fya1Z6KqU8qHHp3DCelOERwsmxXWWE4n+HiL2F6YtAHYj3Ru7
# iZEZ9gZ9Ozhbkt80vAiM1Vv0xEG0FKNWi5N08am/+nLhF1Ku6AM1TWEMeKZzE8X0
# pEepCr9Xo1fLZk3SnEv9c3+40CizJHsJ1zWblUIWv+t80d0abfSb28im4BWojHN3
# dUv8wk21XXvghtHVE4DzGFuMPU0wuX87/zt/gT0+qQY+d+JU+6D1IoSIyGFF7UUz
# 8KyJRk6WjiRYqx/kWc4WYZstZFt54EQplEzxndBdCM1mH9YG8vgKYc+K3MP7nIVn
# +7EPdMjHA2q99WuptZ0VHYIgyTo0HotSZ6Rs8GIkLnTlefFhMVy3X4KcMZcNFOAg
# HDaiQtM8/khrVVRTfOHORo8AQmIgcEhtDlTVC6RHRm2hBw8HIg4ZFp9ytScLjxpz
# ozlYb94HhluWzlu4OTq99d3ADDmcGJWxH7iByHgJkc0y44m+F7qFZ4H72sQ/GIJ4
# /6fn7R9nuQ9GEZzWBWc19XvpK5QQqtXi7zNmuwpwPjZkIJE13FlxYns+x6SCHBNc
# 9nO5KzVg4k1KMuFdaxuzBQGmJGEkYKhBkr063zm/BiIBTpTMJxY63WlcQG4Nb74T
# 6KZfQ0iArNDS/f5r2w==
# SIG # End signature block
