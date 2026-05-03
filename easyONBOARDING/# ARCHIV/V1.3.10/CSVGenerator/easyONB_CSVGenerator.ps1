[CmdletBinding()]
param(
    [switch]$DebugOutput,
    [bool]$AccountDisabled = $true
)

# General settings
$DebugPreference = 'SilentlyContinue' # or 'Continue' if you want to see non-terminating errors
$Debug = $PSBoundParameters.ContainsKey('DebugOutput') # Use the switch to control debugging

#############################################
# Helper functions for debugging and logging
#############################################
function Write-DebugMessage {
    param(
        [string]$Message
    )
    if ($DebugOutput -or $Debug) {
        Write-Host "[DEBUG] $Message" -ForegroundColor Cyan
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output based on level
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

Write-DebugMessage "Starting script with AccountDisabled=$AccountDisabled"

#############################################
# Parameters - Set all settings here
#############################################
# CSV settings
$csvFolder = "C:\easyIT\DATA\easyONBOARDING\CSVData"
$csvFileName = "HROnboardingData.csv"

# GUI settings
$fontSize = 10
# Using named color from System.Windows.Media.Colors instead of hex code
# See: https://learn.microsoft.com/de-de/dotnet/api/system.windows.media.colors
$formBackColor = "Silver"

# Logo settings
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$headerLogo = Join-Path -Path $scriptPath -ChildPath "APPICON1.PNG" # Path to logo

Write-DebugMessage "Parameters set: CSV path=$csvFolder, File=$csvFileName, Logo=$headerLogo"

# Load required assemblies
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Write-DebugMessage "Windows.Forms, Drawing, PresentationFramework, PresentationCore and WindowsBase assemblies loaded"
}
catch {
    Write-Log "Error loading assemblies: $_" -Level "ERROR"
    [System.Windows.Forms.MessageBox]::Show("Error loading assemblies: $_", "Error", 
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Check if CSV folder exists, create it if needed
try {
    if (-not (Test-Path $csvFolder)) {
        Write-DebugMessage "CSV folder not found. Creating folder: $csvFolder"
        New-Item -ItemType Directory -Path $csvFolder -Force | Out-Null
        Write-Log "CSV folder created: $csvFolder" -Level "INFO"
    } else {
        Write-DebugMessage "CSV folder already exists: $csvFolder"
    }
    $csvFile = Join-Path -Path $csvFolder -ChildPath $csvFileName
    Write-DebugMessage "Full CSV path: $csvFile"
} catch {
    Write-Log "Error creating CSV folder ($csvFolder): $_" -Level "ERROR"
    [System.Windows.Forms.MessageBox]::Show("Error creating CSV folder ($csvFolder): $_", "Error", 
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit
}

#############################################
# Load GUI from XAML file
#############################################
Write-DebugMessage "Loading GUI from MainGUI.xaml"
$useXamlGUI = $true
try {
    # Get the XAML file path
    $xamlPath = Join-Path -Path $scriptPath -ChildPath "MainGUI.xaml"
    
    if (-not (Test-Path $xamlPath)) {
        throw "XAML file not found at: $xamlPath"
    }
    
    # Load the XAML content
    [xml]$xaml = Get-Content -Path $xamlPath -Raw -ErrorAction Stop
    
    # Check for potential ResourceDictionary issues
    $resourceDicts = $xaml.SelectNodes("//*[local-name()='ResourceDictionary']")
    if ($resourceDicts.Count -gt 0) {
        Write-DebugMessage "Found $($resourceDicts.Count) ResourceDictionary elements - checking for duplicate keys"
        foreach ($dict in $resourceDicts) {
            $keys = @{} 
            $duplicates = @()
            foreach ($resource in $dict.ChildNodes) {
                if ($resource.Key -and $keys.ContainsKey($resource.Key)) {
                    $duplicates += $resource.Key
                } else {
                    $keys[$resource.Key] = $true
                }
            }
            if ($duplicates.Count -gt 0) {
                Write-Log "Warning: Found duplicate keys in ResourceDictionary: $($duplicates -join ', ')" -Level "WARNING"
            }
        }
    }
    
    # Create the XAML reader
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    
    try {
        # Load the window
        $window = [Windows.Markup.XamlReader]::Load($reader)
        Write-DebugMessage "GUI loaded successfully"
    }
    catch [System.Exception] {
        Write-Log "Error loading XAML: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Inner exception: $($_.Exception.InnerException.Message)" -Level "ERROR"
        $useXamlGUI = $false
        throw
    }
    
    # Access controls
    $controls = @{
        "txtFirstName" = $window.FindName("txtFirstName")
        "txtLastName" = $window.FindName("txtLastName")
        "chkExternal" = $window.FindName("chkExternal")
        "txtExtCompany" = $window.FindName("txtExtCompany")
        "txtDescription" = $window.FindName("txtDescription")
        "cmbOffice" = $window.FindName("cmbOffice")
        "txtPhone" = $window.FindName("txtPhone")
        "txtMobile" = $window.FindName("txtMobile")
        "txtMail" = $window.FindName("txtMail")
        "txtPosition" = $window.FindName("txtPosition")
        "cmbBusinessUnit" = $window.FindName("cmbBusinessUnit")
        "txtPersonalNumber" = $window.FindName("txtPersonalNumber")
        "dtpTermination" = $window.FindName("dtpTermination")
        "dtpStartWorkDate" = $window.FindName("dtpStartWorkDate")  # Add StartWorkDate control
        "chkTL" = $window.FindName("chkTL")
        "chkAL" = $window.FindName("chkAL")
        "btnSave" = $window.FindName("btnSave")
        "btnClose" = $window.FindName("btnClose")
        "picLogo" = $window.FindName("picLogo")
        # New status controls
        "cmbStatus" = $window.FindName("cmbStatus")
        "chkProcessed" = $window.FindName("chkProcessed")
        "txtProcessedBy" = $window.FindName("txtProcessedBy")
        "txtNotes" = $window.FindName("txtNotes")
    }
    
    # Define required vs optional controls
    $requiredControls = @(
        "txtFirstName", "txtLastName", "chkExternal", "txtExtCompany", "txtDescription",
        "cmbOffice", "txtPhone", "txtMobile", "txtMail", "txtPosition", "cmbBusinessUnit",
        "txtPersonalNumber", "dtpTermination", "dtpStartWorkDate", "chkTL", "chkAL", 
        "btnSave", "btnClose", "picLogo", "chkProcessed", "txtNotes"
    )
    
    $optionalControls = @("cmbStatus", "txtProcessedBy")
    
    # Validate required controls were found
    $missingRequiredControls = $requiredControls | Where-Object { $controls[$_] -eq $null } 
    if ($missingRequiredControls) {
        throw "Could not find the following required controls in XAML: $($missingRequiredControls -join ', ')"
    }
    
    # Log warnings for missing optional controls but continue execution
    $missingOptionalControls = $optionalControls | Where-Object { $controls[$_] -eq $null }
    if ($missingOptionalControls) {
        Write-Log "Some optional controls were not found in XAML: $($missingOptionalControls -join ', ')" -Level "WARNING"
        # Initialize missing controls to null so the rest of the code can check for their existence
        foreach ($controlName in $missingOptionalControls) {
            Write-DebugMessage "Setting $controlName to null (optional control)"
            $controls[$controlName] = $null
        }
    }
    
    # Optional: Set default values for DatePickers
    if ($controls.dtpTermination) {
        $controls.dtpTermination.SelectedDate = [DateTime]::Now.AddYears(1)
    }
    if ($controls.dtpStartWorkDate) {
        $controls.dtpStartWorkDate.SelectedDate = [DateTime]::Now.AddDays(14)
    }
    
    # Load logo if exists
    if (Test-Path $headerLogo) {
        try {
            $imageSource = New-Object System.Windows.Media.Imaging.BitmapImage
            $imageSource.BeginInit()
            $imageSource.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $imageSource.UriSource = New-Object System.Uri($headerLogo, [System.UriKind]::Absolute)
            $imageSource.EndInit()
            $controls.picLogo.Source = $imageSource
            Write-DebugMessage "Logo loaded successfully from $headerLogo"
        }
        catch {
            Write-Log "Error loading logo: $_" -Level "WARNING"
        }
    } else {
        Write-Log "Logo file not found at $headerLogo. Skipping logo loading." -Level "WARNING"
    }
} 
catch [System.Xml.XmlException] {
    Write-Log "XML parsing error in XAML file: $($_.Exception.Message)" -Level "ERROR"
    $useXamlGUI = $false
}
catch {
    Write-Log "Error loading or accessing GUI elements: $_" -Level "ERROR"
    Write-Log "Exception type: $($_.Exception.GetType().FullName)" -Level "ERROR"
    
    if ($_.Exception.InnerException) {
        Write-Log "Inner exception: $($_.Exception.InnerException.Message)" -Level "ERROR"
    }
    
    $useXamlGUI = $false
}

# Create fallback UI if XAML loading failed
if (-not $useXamlGUI) {
    Write-Log "Creating fallback UI due to XAML loading failure" -Level "WARNING"
    try {
        # Create a basic Windows Forms UI instead
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Easy Onboarding CSV Generator v1.3 (Fallback UI)"
        $form.Size = New-Object System.Drawing.Size(500, 650)
        $form.StartPosition = "CenterScreen"
        $form.BackColor = [System.Drawing.Color]::$formBackColor
        $form.Font = New-Object System.Drawing.Font("Segoe UI", $fontSize)

        # Create panel for scrolling
        $panel = New-Object System.Windows.Forms.Panel
        $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
        $panel.AutoScroll = $true
        $form.Controls.Add($panel)

        $currentY = 20
        $labelWidth = 120
        $controlWidth = 250
        $spacing = 30
        $controlHeight = 23

        # Helper function to add a labeled control
        function Add-LabeledControl {
            param(
                [string]$LabelText,
                [System.Windows.Forms.Control]$Control,
                [int]$Y,
                [switch]$FullWidth
            )
            
            $label = New-Object System.Windows.Forms.Label
            $label.Location = New-Object System.Drawing.Point(20, $Y)
            $label.Size = New-Object System.Drawing.Size($labelWidth, $controlHeight)
            $label.Text = $LabelText
            $panel.Controls.Add($label)
            
            $controlX = 20 + $labelWidth + 10
            $actualWidth = if ($FullWidth) { 390 } else { $controlWidth }
            $Control.Location = New-Object System.Drawing.Point($controlX, $Y)
            $Control.Size = New-Object System.Drawing.Size($actualWidth, $controlHeight)
            $panel.Controls.Add($Control)
            
            return $Y + $spacing
        }

        # Create form controls
        $txtFirstName = New-Object System.Windows.Forms.TextBox
        $currentY = Add-LabeledControl -LabelText "First Name:" -Control $txtFirstName -Y $currentY
        
        $txtLastName = New-Object System.Windows.Forms.TextBox
        $currentY = Add-LabeledControl -LabelText "Last Name:" -Control $txtLastName -Y $currentY
        
        $chkExternal = New-Object System.Windows.Forms.CheckBox
        $chkExternal.Text = ""
        $currentY = Add-LabeledControl -LabelText "External:" -Control $chkExternal -Y $currentY
        
        $txtExtCompany = New-Object System.Windows.Forms.TextBox
        $currentY = Add-LabeledControl -LabelText "External Company:" -Control $txtExtCompany -Y $currentY
        
        $txtDescription = New-Object System.Windows.Forms.TextBox
        $currentY = Add-LabeledControl -LabelText "Description:" -Control $txtDescription -Y $currentY
        
        $cmbOffice = New-Object System.Windows.Forms.ComboBox
        $cmbOffice.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
        $currentY = Add-LabeledControl -LabelText "Office:" -Control $cmbOffice -Y $currentY
        
        $txtPhone = New-Object System.Windows.Forms.TextBox
        $currentY = Add-LabeledControl -LabelText "Phone:" -Control $txtPhone -Y $currentY
        
        $txtMobile = New-Object System.Windows.Forms.TextBox
        $currentY = Add-LabeledControl -LabelText "Mobile:" -Control $txtMobile -Y $currentY
        
        $txtMail = New-Object System.Windows.Forms.TextBox
        $currentY = Add-LabeledControl -LabelText "Email:" -Control $txtMail -Y $currentY
        
        $txtPosition = New-Object System.Windows.Forms.TextBox
        $currentY = Add-LabeledControl -LabelText "Position:" -Control $txtPosition -Y $currentY
        
        $cmbBusinessUnit = New-Object System.Windows.Forms.ComboBox
        $cmbBusinessUnit.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
        $currentY = Add-LabeledControl -LabelText "Business Unit:" -Control $cmbBusinessUnit -Y $currentY
        
        $txtPersonalNumber = New-Object System.Windows.Forms.TextBox
        $currentY = Add-LabeledControl -LabelText "Personal Number:" -Control $txtPersonalNumber -Y $currentY
        
        $dtpTermination = New-Object System.Windows.Forms.DateTimePicker
        $dtpTermination.Value = [DateTime]::Now.AddYears(1)
        $currentY = Add-LabeledControl -LabelText "Termination Date:" -Control $dtpTermination -Y $currentY
        
        $chkTL = New-Object System.Windows.Forms.CheckBox
        $chkTL.Text = ""
        $currentY = Add-LabeledControl -LabelText "Team Leader:" -Control $chkTL -Y $currentY
        
        $chkAL = New-Object System.Windows.Forms.CheckBox
        $chkAL.Text = ""
        $currentY = Add-LabeledControl -LabelText "Department Head:" -Control $chkAL -Y $currentY
        
        # Add Status fields to fallback UI
        $cmbStatus = New-Object System.Windows.Forms.ComboBox
        $cmbStatus.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
        $cmbStatus.Items.AddRange(@("Neu", "In Bearbeitung", "Abgeschlossen", "Storniert"))
        $cmbStatus.SelectedIndex = 0
        $currentY = Add-LabeledControl -LabelText "Status:" -Control $cmbStatus -Y $currentY
        
        $chkProcessed = New-Object System.Windows.Forms.CheckBox
        $chkProcessed.Text = ""
        $currentY = Add-LabeledControl -LabelText "Bearbeitet:" -Control $chkProcessed -Y $currentY
        
        $txtProcessedBy = New-Object System.Windows.Forms.TextBox
        $currentY = Add-LabeledControl -LabelText "Bearbeitet von:" -Control $txtProcessedBy -Y $currentY
        
        $txtNotes = New-Object System.Windows.Forms.TextBox
        $txtNotes.Multiline = $true
        $txtNotes.Height = 40
        $currentY = Add-LabeledControl -LabelText "Notizen:" -Control $txtNotes -Y $currentY
        
        # Add to controls dictionary
        $controls["cmbStatus"] = $cmbStatus
        $controls["chkProcessed"] = $chkProcessed
        $controls["txtProcessedBy"] = $txtProcessedBy
        $controls["txtNotes"] = $txtNotes
        
        # Add buttons
        $currentY += 20
        $btnSave = New-Object System.Windows.Forms.Button
        $btnSave.Location = New-Object System.Drawing.Point(120, $currentY)
        $btnSave.Size = New-Object System.Drawing.Size(100, 30)
        $btnSave.Text = "Save to CSV"
        $panel.Controls.Add($btnSave)
        
        $btnClose = New-Object System.Windows.Forms.Button
        $btnClose.Location = New-Object System.Drawing.Point(240, $currentY)
        $btnClose.Size = New-Object System.Drawing.Size(100, 30)
        $btnClose.Text = "Close"
        $panel.Controls.Add($btnClose)
        
        # Create a controls dictionary to match the XAML structure
        $controls = @{
            "txtFirstName" = $txtFirstName
            "txtLastName" = $txtLastName
            "chkExternal" = $chkExternal
            "txtExtCompany" = $txtExtCompany
            "txtDescription" = $txtDescription
            "cmbOffice" = $cmbOffice
            "txtPhone" = $txtPhone
            "txtMobile" = $txtMobile
            "txtMail" = $txtMail
            "txtPosition" = $txtPosition
            "cmbBusinessUnit" = $cmbBusinessUnit
            "txtPersonalNumber" = $txtPersonalNumber
            "dtpTermination" = $dtpTermination
            "chkTL" = $chkTL
            "chkAL" = $chkAL
            "btnSave" = $btnSave
            "btnClose" = $btnClose
            "picLogo" = $null # No logo in fallback UI
            "cmbStatus" = $cmbStatus
            "chkProcessed" = $chkProcessed
            "txtProcessedBy" = $txtProcessedBy
            "txtNotes" = $txtNotes
        }

        # Attach event handlers (we'll define these later)
        $btnSave.Add_Click({
            # The Save button handler will be attached below - content will be the same
        })
        
        $btnClose.Add_Click({
            $form.Close()
        })
        
        # Set the form as our "window" variable to keep the rest of the code working
        $window = $form
        
        Write-Log "Fallback UI created successfully" -Level "INFO"
    }
    catch {
        Write-Log "Error creating fallback UI: $_" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Critical error: Could not create UI interface. $_", "Fatal Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit
    }
}

#############################################
# Event Handlers
#############################################
# Function to validate input fields
function Validate-InputFields {
    $isValid = $true
    $errorMessage = @()
    
    # Check required fields
    if ([string]::IsNullOrWhiteSpace($controls.txtFirstName.Text)) {
        $isValid = $false
        $errorMessage += "- First Name is required"
    }
    if ([string]::IsNullOrWhiteSpace($controls.txtLastName.Text)) {
        $isValid = $false
        $errorMessage += "- Last Name is required"
    }
    
    # Validate phone numbers (if provided)
    if (-not [string]::IsNullOrWhiteSpace($controls.txtPhone.Text) -and 
        ($controls.txtPhone.Text -notmatch "^[\d\+\-\(\) \.]+$")) {
        $isValid = $false
        $errorMessage += "- Phone number contains invalid characters"
    }
    if (-not [string]::IsNullOrWhiteSpace($controls.txtMobile.Text) -and 
        ($controls.txtMobile.Text -notmatch "^[\d\+\-\(\) \.]+$")) {
        $isValid = $false
        $errorMessage += "- Mobile number contains invalid characters"
    }
    
    # Email validation - allowing partial addresses (just username part is fine)
    if (-not [string]::IsNullOrWhiteSpace($controls.txtMail.Text) -and 
        ($controls.txtMail.Text -notmatch "^[\w\-\.]+(@[\w\-\.]+)?$")) {
        $isValid = $false
        $errorMessage += "- Email username contains invalid characters"
    }
    
    return @{
        IsValid = $isValid
        ErrorMessage = ($errorMessage -join "`n")
    }
}

# Save button click handler
$controls.btnSave.Add_Click({
    Write-DebugMessage "Button 'Save to CSV' was clicked"
    try {
        # Validate required fields
        Write-DebugMessage "Validating required fields..."
        $validation = Validate-InputFields
        if (-not $validation.IsValid) {
            Write-Log "Validation error: $($validation.ErrorMessage)" -Level "ERROR"
            [System.Windows.Forms.MessageBox]::Show(
                "Please correct the following errors:`n$($validation.ErrorMessage)", 
                "Validation Error", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Format dates
        $terminationDate = $null
        if ($controls.dtpTermination -and $controls.dtpTermination.SelectedDate) {
            $terminationDate = $controls.dtpTermination.SelectedDate.ToString("yyyy-MM-dd")
            Write-DebugMessage "Termination Date: $terminationDate"
        }
        
        $startWorkDate = $null
        if ($controls.dtpStartWorkDate -and $controls.dtpStartWorkDate.SelectedDate) {
            $startWorkDate = $controls.dtpStartWorkDate.SelectedDate.ToString("yyyy-MM-dd")
            Write-DebugMessage "Start Work Date: $startWorkDate"
        }
        
        # Create CSV header if file doesn't exist
        $headerExists = Test-Path $csvFile
        
        # Create data object with fields in the specific order
        Write-DebugMessage "Creating data object for CSV export..."
        $data = [PSCustomObject]@{
            'FirstName'      = $controls.txtFirstName.Text.Trim()
            'LastName'       = $controls.txtLastName.Text.Trim()
            'Description'    = $controls.txtDescription.Text.Trim()
            'OfficeRoom'     = $controls.cmbOffice.Text.Trim()
            'PhoneNumber'    = $controls.txtPhone.Text.Trim()
            'MobileNumber'   = $controls.txtMobile.Text.Trim()
            'Position'       = $controls.txtPosition.Text.Trim()
            'DepartmentField'= $controls.cmbBusinessUnit.Text.Trim()
            'EmailAddress'   = $controls.txtMail.Text.Trim()
            'Ablaufdatum'    = $terminationDate
            'StartWorkDate'  = $startWorkDate
            'PersonalNumber' = $controls.txtPersonalNumber.Text.Trim()
            'External'       = $controls.chkExternal.IsChecked
            'ExternalCompany'= if ($controls.chkExternal.IsChecked) { $controls.txtExtCompany.Text.Trim() } else { "" }
            'TL'             = $controls.chkTL.IsChecked
            'AL'             = $controls.chkAL.IsChecked
            'AccountDisabled'= $AccountDisabled
            'ADGroup'        = $controls.cmbBusinessUnit.Text.Trim() 
            'AdminAccount'   = $controls.chkProcessed.IsChecked 
            'Notes'          = $controls.txtNotes.Text.Trim()
        }
        
        # Write to CSV file with correct encoding
        if (-not $headerExists) {
            # Create a new file with headers
            $data | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
            Write-DebugMessage "Created new CSV file with headers"
        } else {
            # Append to existing file
            $data | Export-Csv -Path $csvFile -NoTypeInformation -Append -Encoding UTF8
            Write-DebugMessage "Appended data to existing CSV file"
        }
        
        Write-Log "Data was successfully saved to CSV file: $csvFile" -Level "INFO"
        [System.Windows.Forms.MessageBox]::Show(
            "Data has been saved to:`n$csvFile", 
            "Success", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information)
        
        # Clear input fields after successful save
        $controls.txtFirstName.Text = ""
        $controls.txtLastName.Text = ""
        $controls.chkExternal.IsChecked = $false
        $controls.txtExtCompany.Text = ""
        $controls.txtDescription.Text = ""
        $controls.cmbOffice.Text = ""
        $controls.txtPhone.Text = ""
        $controls.txtMobile.Text = ""
        $controls.txtMail.Text = ""
        $controls.txtPosition.Text = ""
        $controls.cmbBusinessUnit.Text = ""
        $controls.txtPersonalNumber.Text = ""
        if ($controls.dtpTermination) {
            $controls.dtpTermination.SelectedDate = [DateTime]::Now.AddYears(1)
        }
        if ($controls.dtpStartWorkDate) {
            $controls.dtpStartWorkDate.SelectedDate = [DateTime]::Now.AddDays(14)
        }
        $controls.chkTL.IsChecked = $false
        $controls.chkAL.IsChecked = $false
        # Reset admin account checkbox and notes
        $controls.chkProcessed.IsChecked = $false
        $controls.txtNotes.Text = ""
    } catch {
        Write-Log "Error saving data: $_" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error saving data: $_", 
            "Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Close button click handler
$controls.btnClose.Add_Click({
    Write-DebugMessage "Button 'Close' was clicked. Closing application."
    $window.Close()
})

# Set focus to the form - conditional for WPF vs WinForms
if ($useXamlGUI -and $window.Dispatcher) {
    Write-DebugMessage "Setting focus using WPF Dispatcher"
    $window.Dispatcher.Invoke([Action]{
        $window.Activate()
        $controls.txtFirstName.Focus()
    }, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle)
} else {
    Write-DebugMessage "Setting focus using Windows Forms"
    $window.Activate()
    $controls.txtFirstName.Focus()
}

# Show the form
Write-DebugMessage "Showing form..."
# Apply background color to window - conditional for WPF vs WinForms
if ($useXamlGUI -and $window.PSObject.Properties.Name -contains "Background") {
    Write-DebugMessage "Setting background for WPF window"
    $window.Background = [System.Windows.Media.Brushes]::$formBackColor
} elseif (-not $useXamlGUI) {
    Write-DebugMessage "Setting background for Windows Forms"
    $window.BackColor = [System.Drawing.Color]::$formBackColor
}

[void] $window.ShowDialog()

Write-DebugMessage "Script finished."

# SIG # Begin signature block
# MIIoiQYJKoZIhvcNAQcCoIIoejCCKHYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDcBYCFaHMJVlcK
# /OWpDsKiy0vCsOvAOFwAWQazTRhMX6CCILswggXJMIIEsaADAgECAhAbtY8lKt8j
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
# BCB/Q3DIAa19WlunkMxLuoj3VJg57b5TXaGbXs+4huD9HjANBgkqhkiG9w0BAQEF
# AASCAgAKDFWSH6Gv9S4TWZ7wkXh3uR1uCOkwBe8wIgKri99+JR8RM6Xa/bqHYhzZ
# JJjuKzOMBkCMP2Dobtn+GRA2S01emIqT7BU3Wl26EU2sCw3hQHHth6vZTH9NWZjA
# QhriaSnabOvR4YKWju4reVjWNVjpoNVezGWqERCSJ+hs+g4lehgr5Tfs2D180bnB
# Ufo5L4dP4WHg0xeLZnH6vr+iJby8my46onrOYwLliBM/6GqcEIgNTEMjiPoiIiLY
# jyxi+LwIMMygplKnCGBs0LXlWK7SKe03HQbMjTo+xx+6Is2GYjWPnygI37vNceDC
# VgfTr5jA3NTsMPWC4X9nlgz0oF3hG3+gC3pT/hLKximilhqq2sDkuFk9eusDV+9D
# WAUn06ny5Ht43O5pybwDkptz3+ItnRukcoU2YLTiJObEcFuguAhvHMU/X+QR/HwH
# j2i+4LZYYNmoQhh0iPjtFcG9Ajdkceqwrk6foSgq8S6nydzGzbYfNGVVfwgMQ80I
# 6HaHw26g8gpBcqqGMGYpQisX78iu/YYtqQPvcvMhVahXe7/DOOuOEGztHsXsNnqw
# e8YyD/AyZrPnZj9gVw3gNSk8wiwtTTosb5MWXJISce+KxpULsVhxyK8m5FzmnZhC
# tmq7/XPcfbACG5Jo8gWitu2X04i4DY922O3Rm7ioLUS3G9D0wKGCBAQwggQABgkq
# hkiG9w0BCQYxggPxMIID7QIBATBrMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3Rh
# bXBpbmcgMjAyMSBDQQIRAJ6cBPZVqLSnAm1JjGx4jaowDQYJYIZIAWUDBAICBQCg
# ggFXMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcN
# MjUwOTExMTAwMjQ2WjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDPodw1ne0rw8uJ
# D6Iw5dr3e1QPGm4rI93PF1ThjPqg1TA/BgkqhkiG9w0BCQQxMgQwMKLxYtLqP7fI
# +RtkFUpF3I9uETSmiscoHX/hxY0u2I+3FeGIGbR2comdeGdOVMZmMIGgBgsqhkiG
# 9w0BCRACDDGBkDCBjTCBijCBhwQUwyW4mxf8xQJgYc4rcXtFB92camowbzBapFgw
# VjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhEAnpwE9lWo
# tKcCbUmMbHiNqjANBgkqhkiG9w0BAQEFAASCAgDBHNfTD7S1JQiND0Z4BPJebCfu
# /yCRG/wy5hO5f+QAvNmFGNmnZ16wHIr9KLT17PSGd9Wje9imjHVEgRfec4oSiKPP
# hSq8KQNJ1P7LTQ1/WdDi/4ZXFUHuNfInJQf8IMNUkajBh4iHyEzRE3tZo2VJCmY7
# oqoTVhE5hQpjeeKDyoekQEY+G/2cpK+e4xe4NMILlEuampfboHOQnT9dsmayiq+2
# 0nowRZLAeN+CAMLfCKB09CTcgL9mo4K8WA8eUrLzMcgiKBZY3Qc6JenXm54Rpy6Q
# 8RK3rnCnJeMMtbfvvT9Xd4zGQCT6xQ4ZHePotZXC4U7a3LCUX+5ceHO0atGMDhaT
# 1KHP/1URlxXVvdRD57gJCTc4JvVRvrAqMOwpPjI0R/HwI6GKGTzYrw/zS9uptYKf
# omALpze75+vUdXCUZA8K7+JHtdRvxZDDLNR6UIHAxsX8RxQrQwscdP/tqyE0Nmm3
# /vkpl1/18fnrCQ7SW1CITUvw4bk5C3yWtNKuZ03OoQh7WS0+npj8PnB0u2DwkYY7
# EmjnSfXYVre/N25QmywAoTGgy6ELSKE1PmL0Y9nwcV5siqX5mPrBX1Vi+k6/7034
# Umzz9v1kIaMr6H4c0STfP7nCmFpY0DWCklb+JlIvxytwjmW+XAKwPA7Gsp380y1h
# Wyqzw3nmvYWYBYqCFQ==
# SIG # End signature block
