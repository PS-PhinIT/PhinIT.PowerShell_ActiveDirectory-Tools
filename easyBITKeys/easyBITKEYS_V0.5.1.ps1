# filepath: c:\Users\PhinITAndreasHepp\OneDrive - PhinIT\05-Administratives\10-Scripte\PowerShell\# EASYit\easyBITkeys\easyBITKEYS_V0.1.0.ps1
# ---------------------------------------------------------------------
# Author: ANDREAS HEPP
# 
# This script reads all BitLocker Keys (msFVE-RecoveryInformation) from Active Directory
# and displays them in a color-coded GUI.
# Status colors:
#   - No key available: LightGray
#   - Key current up to 6 months: LightGreen
#   - Key older than 7 months: Orange
#   - Key older than 12 months: LightCoral
# 
# The application provides buttons to export as CSV, delete the selected entry
# (after confirmation), and close the application.
#
# The DataGrid displays 4 columns:
#   "Nr" (only as wide as the content),
#   "ComputerName" (fills the remaining space),
#   "BitLockerKey" (fills the remaining space),
#   "Datum" (only as wide as the content).
#
# The footer (with URL) is displayed as a panel below the buttons and
# has the same background color as the header (as defined in the INI file).
#
# NOTE: The application can also run in client mode without the AD module,
# displaying sample data for demonstration purposes.
# ---------------------------------------------------------------------

#region Script Configuration
# Diese Konfigurationswerte sollten am Anfang des Skripts stehen.

# Allgemeine Skriptinformationen
$ScriptVersion   = "0.5.2"
$LastUpdate      = "2026-06-09" # Datum der letzten Aktualisierung
$Author          = "ANDREAS HEPP"
$APPName         = "easyBITKEYS"
$APPDescription  = "easyBITKEYS displays BitLocker keys from Active Directory in a color-coded manner."

# GUI-Konfiguration
$ThemeColor      = "#164360" # Hauptfarbe für Header/Footer (Hex-Code)
$FontFamily      = "Segoe UI" # Standard-Schriftart für die GUI
$FontSize        = [float]12   # Standard-Schriftgröße für die GUI
$ConfigHeaderLogoFileName = "APPICON.png"  # Dateiname für das Logo im Header. Muss sich im selben Verzeichnis wie das Skript befinden oder einen relativen/absoluten Pfad haben. Wenn leer, wird kein Logo angezeigt.
$HeaderLogoURL   = "" # Optional: Wenn leer, wird keine externe URL geöffnet.

# Debug-Modus (0 = Aus, 1 = An) - Stellen Sie sicher, dass die Write-DebugMessage Funktion existiert
$global:DebugMode = 0 # Standardmäßig deaktiviert
$script:Debug = $global:DebugMode # Debug-Modus für das Skript setzen
$script:ClientMode = $false

# Log-Datei Konfiguration
$LogFileName = "easyBITKEYS.log"
$LogFile = $null

#endregion Script Configuration

###############################################################################
# PS2EXE OPTIMIERUNGEN
###############################################################################
# PS2EXE: Progress Bars deaktivieren für -NoConsole Kompilierung
$ProgressPreference = 'SilentlyContinue'

# PS2EXE: Visual Styles aktivieren BEVOR GUI-Objekte erstellt werden
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
[System.Windows.Forms.Application]::EnableVisualStyles()

# Universeller Pfad-Code für Script UND EXE-Kompatibilität
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    # Script-Modus
    $script:ScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    # Executable-Modus (PS2EXE)
    $script:ScriptRoot = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    if ([string]::IsNullOrWhiteSpace($script:ScriptRoot)) { 
        $script:ScriptRoot = "."
    }
}
if (-not $script:ScriptRoot) { 
    $script:ScriptRoot = "."
}

$LogFile = Join-Path -Path $script:ScriptRoot -ChildPath $LogFileName

#region Logging Functions
# Module for logging
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    # Zeitstempel außerhalb des try-Blocks definieren, damit er im catch-Block zuverlässig verfügbar ist.
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # $logMessage wird später im try-Block initialisiert.
    # Für den Fall, dass ein Fehler vor der Initialisierung von $logMessage auftritt,
    # wird eine Basis-Nachricht für das Fallback-Logging vorbereitet.
    $baseFallbackMessage = "[$timestamp] [$Level] $Message" 

    try {
        # Debug-Meldungen überspringen, wenn der Debug-Modus deaktiviert ist
        if ($Level -eq "DEBUG" -and -not $script:Debug) {
            return
        }
        
        $logMessage = "[$timestamp] [$Level] $Message"
        
        # Sicherstellen, dass das Logs-Verzeichnis existiert
        $logDir = Join-Path $script:ScriptRoot "Logs"
        if (-not (Test-Path $logDir)) {
            # -ErrorAction Stop verwenden, um sicherzustellen, dass Fehler beim Erstellen des Verzeichnisses
            # den catch-Block auslösen.
            New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        
        # Log-Datei mit Datum
        $logFile = Join-Path $logDir "easyBITKEYS_$(Get-Date -Format 'yyyy-MM-dd').log"
        
        # In Datei schreiben, -ErrorAction Stop verwenden, um Fehler abzufangen
        Add-Content -Path $logFile -Value $logMessage -Encoding UTF8 -ErrorAction Stop
        
        # Auch auf der Konsole ausgeben für Debug-Level und Fehler
        if ($Level -eq "DEBUG" -or $Level -eq "ERROR") {
            Write-Host $logMessage -ForegroundColor $(
                switch ($Level) {
                    "DEBUG" { "Cyan" }
                    "INFO"  { "White" } # Standard-Farbe, kann je nach Host variieren
                    "WARN"  { "Yellow" }
                    "ERROR" { "Red" }
                }
            )
        }
    }
    catch {
        # Fallback-Logging bei Fehlern
        $fallbackLog = Join-Path $env:TEMP "easyBITKEYS_fallback.log"
        
        # Verwende $logMessage, falls es bereits konstruiert wurde, ansonsten die Basis-Nachricht.
        $messageForFallback = if ($logMessage) { $logMessage } else { $baseFallbackMessage }
        
        $errorDetails = "Error during logging operation: $($_.Exception.ToString()). Original log content attempt: $messageForFallback"
        $fallbackEntry = "[$timestamp] [FALLBACK_ERROR] $errorDetails"
        
        try {
            # Versuche, die detaillierte Fehlermeldung in die Fallback-Logdatei zu schreiben.
            # -ErrorAction SilentlyContinue, um zu verhindern, dass ein Fehler im Fallback-Logging das Skript abbricht.
            Add-Content -Path $fallbackLog -Value $fallbackEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            # Wenn selbst das Schreiben in die Fallback-Logdatei fehlschlägt, eine Warnung ausgeben.
            Write-Warning "Primary logging failed, and fallback logging to '$fallbackLog' also failed. Error: $($_.Exception.Message)"
        }
    }
}

# Function for debug messages that respects debug setting
function Write-DebugMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    try {
        if ($script:Debug) {
            Write-Log -Message $Message -Level DEBUG
        }
    }
    catch {
        # Silently fail if debug output fails
    }
}
#endregion

#region Initialization and Requirements Check
# Ensure script runs in PowerShell 5.1
if ($PSVersionTable.PSVersion.Major -ne 5) {
    Write-Host "Switching to PowerShell 5.1..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Self-Diagnostic at startup
function Test-Requirements {
    try {
        # Check if all icons in assets folder exist
        $assetsPath = Join-Path $script:ScriptRoot "assets"
        $requiredIcons = @("info.png", "close.png")
        
        if (-not (Test-Path $assetsPath)) {
            Write-Log -Message "Assets folder not found: $assetsPath. Fallback icons will be used." -Level WARN
        }
        else {
            foreach ($icon in $requiredIcons) {
                $iconPath = Join-Path $assetsPath $icon
                if (-not (Test-Path $iconPath)) {
                    Write-Log -Message "Icon not found: $iconPath. Fallback icon will be used." -Level WARN
                }
            }
        }
        
        # Check if ActiveDirectory module is available
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
            Write-Log -Message "ActiveDirectory module not available. Switching to client mode with sample data." -Level WARN
            $script:ClientMode = $true
            return $true
        }
        
        # Check permissions (simplified)
        try {
            # Try to read AD objects as permission test
            Get-ADObject -Filter {objectClass -eq "computer"} -ResultSetSize 1 | Out-Null
        }
        catch {
            Write-Log -Message "Insufficient AD permissions: $_. Switching to client mode with sample data." -Level WARN
            $script:ClientMode = $true
            return $true
        }
        
        Write-Log -Message "Self-Diagnostic completed successfully" -Level INFO
        return $true
    }
    catch {
        Write-Log -Message "Error in Self-Diagnostic: $_. Switching to client mode with sample data." -Level WARN
        $script:ClientMode = $true
        return $true
    }
}

# Load required assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
#endregion

#region Configuration Management
# Die INI-Datei-Verwaltung wurde entfernt. Die Konfiguration erfolgt nun direkt am Anfang des Skripts.
#endregion

#region XAML Definition
# Define XAML markup for the GUI as a plain string first
$xamlString = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="$APPName"
    Width="1200"
    Height="800"
    MinWidth="1024" 
    MinHeight="768"
    Background="#FFFFFF"
    FontFamily="$FontFamily"
    FontSize="$FontSize"
    ResizeMode="CanMinimize"
    WindowStartupLocation="CenterScreen">

    <Window.Resources>
        <!--  Modern Button Style  -->
        <Style x:Key="ModernButton" TargetType="Button">
            <Setter Property="Background" Value="#0078D4" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="BorderThickness" Value="0" />
            <Setter Property="Padding" Value="18,8" />
            <Setter Property="Margin" Value="6" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="MinWidth" Value="80" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border
                            x:Name="border"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="4">
                            <ContentPresenter
                                Margin="{TemplateBinding Padding}"
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#106EBE" />
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#005A9E" />
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.5" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!--  Navigation Button Style  -->
        <Style x:Key="NavButton" TargetType="Button">
            <Setter Property="Background" Value="#4A90E2" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="BorderThickness" Value="0,0,0,1" />
            <Setter Property="BorderBrush" Value="#357ABD" />
            <Setter Property="Padding" Value="15,10" />
            <Setter Property="Margin" Value="8,3,8,3" />
            <Setter Property="HorizontalAlignment" Value="Stretch" />
            <Setter Property="HorizontalContentAlignment" Value="Left" />
            <Setter Property="FontSize" Value="14" />
            <Setter Property="FontWeight" Value="Normal" />
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border
                            x:Name="border"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="4">
                            <ContentPresenter
                                Margin="{TemplateBinding Padding}"
                                HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                VerticalAlignment="Center" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#60A0F0" />
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#0078D4" />
                                <Setter Property="Foreground" Value="White" />
                                <Setter TargetName="border" Property="BorderBrush" Value="#0078D4" />
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.5" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!--  Card Style  -->
        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background" Value="White" />
            <Setter Property="BorderBrush" Value="#E0E0E0" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="CornerRadius" Value="8" />
            <Setter Property="Padding" Value="16" />
            <Setter Property="Margin" Value="8" />
        </Style>

        <!--  TextBox Style  -->
        <Style x:Key="ModernTextBox" TargetType="TextBox">
            <Setter Property="BorderBrush" Value="#BFBFBF" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Padding" Value="8,5" />
            <Setter Property="Margin" Value="4" />
            <Setter Property="Background" Value="White" />
            <Setter Property="FontSize" Value="12" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="4">
                            <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter Property="BorderBrush" Value="#0078D4" />
                                <Setter Property="BorderThickness" Value="2" />
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.5" />
                                <Setter Property="Background" Value="#F0F0F0" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <Style x:Key="SmallIconButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Padding" Value="5" />
            <Setter Property="MinWidth" Value="32" />
            <Setter Property="MinHeight" Value="32" />
            <Setter Property="Width" Value="32" />
            <Setter Property="Height" Value="32" />
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>

    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="60" />
            <RowDefinition Height="*" />
            <RowDefinition Height="40" />
        </Grid.RowDefinitions>

        <!--  Header area  -->
        <Border
            x:Name="headerBorder"
            Grid.Row="0"
            Background="#FF1C323C"
            BorderBrush="#E0E0E0"
            BorderThickness="0,0,0,1">
            <Grid Margin="20,0">
                 <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto" />
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="Auto" />
                </Grid.ColumnDefinitions>
                <StackPanel
                    Grid.Column="0"
                    Margin="0,0,0,0"
                    VerticalAlignment="Center"
                    Orientation="Horizontal">
                    <StackPanel>
                        <TextBlock
                            x:Name="headerTitle"
                            FontSize="20"
                            FontWeight="SemiBold"
                            Foreground="#e2e2e2"
                            Text="$APPName" />
                        <TextBlock
                            x:Name="headerSubtitle"
                            Margin="0,2,0,0"
                            FontSize="10"
                            Foreground="#e2e2e2"
                            Text="Version $ScriptVersion" />
                    </StackPanel>
                </StackPanel>

                <Border
                    Grid.Column="2"
                    Width="150"
                    Height="50"
                    Margin="0,0,0,0"
                    HorizontalAlignment="Right"
                    VerticalAlignment="Center">
                    <Image
                        x:Name="headerLogo"
                        Cursor="Hand"
                        Stretch="Uniform" />
                </Border>
            </Grid>
        </Border>

        <!--  Main area with navigation and content  -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="200" />
                <ColumnDefinition Width="*" />
            </Grid.ColumnDefinitions>

            <!--  Navigation area  -->
            <Border Grid.Column="0" Background="#FF334556" BorderBrush="#1E2A38" BorderThickness="0,0,1,0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="*" />
                        <RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Grid.Row="0" Margin="5,10,5,10">
                            <!--  Obere Gruppe: Allgemeine Aktionen  -->
                            <GroupBox Header="Actions" Margin="5,8,5,8" Padding="8" BorderBrush="#4A5C6E" BorderThickness="1" Foreground="#E0E0E0">
                                <StackPanel>
                                    <Button
                                        x:Name="btnRefresh"
                                        Content="Refresh List"
                                        Style="{StaticResource NavButton}" />

                                    <Button
                                        x:Name="btnExport"
                                        Content="Export CSV"
                                        Style="{StaticResource NavButton}" />
                                </StackPanel>
                            </GroupBox>
                            
                            <!--  Untere Gruppe: Aktionen für ausgewählten Schlüssel  -->
                             <GroupBox Header="For Selected Key" Margin="5,10,5,10" Padding="8" BorderBrush="#4A5C6E" BorderThickness="1" Foreground="#E0E0E0">
                                <StackPanel>
                                    <Button
                                        x:Name="btnCopyKey"
                                        Content="Copy Key"
                                        Style="{StaticResource NavButton}" />

                                    <Button
                                        x:Name="btnDelete"
                                        Content="Remove Key"
                                        Style="{StaticResource NavButton}" />
                                </StackPanel>
                            </GroupBox>

                            <!--  Farblegende  -->
                            <GroupBox Header="Color Legend" Margin="5,10,5,10" Padding="8" BorderBrush="#4A5C6E" BorderThickness="1" Foreground="#E0E0E0">
                                <StackPanel Margin="5,0,5,0">
                                    <StackPanel Margin="0,2" Orientation="Horizontal">
                                        <Rectangle
                                            Width="15"
                                            Height="15"
                                            Margin="0,0,8,0"
                                            VerticalAlignment="Center"
                                            Fill="LightGreen" />
                                        <TextBlock
                                            VerticalAlignment="Center"
                                            FontSize="11"
                                            Foreground="#E0E0E0"
                                            Text="Key &lt; 7 months" />
                                    </StackPanel>
                                    <StackPanel Margin="0,2" Orientation="Horizontal">
                                        <Rectangle
                                            Width="15"
                                            Height="15"
                                            Margin="0,0,8,0"
                                            VerticalAlignment="Center"
                                            Fill="Orange" />
                                        <TextBlock
                                            VerticalAlignment="Center"
                                            FontSize="11"
                                            Foreground="#E0E0E0"
                                            Text="Key &gt; 6 months" />
                                    </StackPanel>
                                    <StackPanel Margin="0,2" Orientation="Horizontal">
                                        <Rectangle
                                            Width="15"
                                            Height="15"
                                            Margin="0,0,8,0"
                                            VerticalAlignment="Center"
                                            Fill="LightCoral" />
                                        <TextBlock
                                            VerticalAlignment="Center"
                                            FontSize="11"
                                            Foreground="#E0E0E0"
                                            Text="Key &gt; 12 months" />
                                    </StackPanel>
                                </StackPanel>
                            </GroupBox>
                        </StackPanel>
                    </ScrollViewer>
                    <!--  Navigation icons at the bottom  -->
                    <StackPanel
                        Grid.Row="1"
                        Margin="0,10,0,10"
                        HorizontalAlignment="Center"
                        Orientation="Horizontal">
                        <Button
                            x:Name="btnInfo"
                            Style="{StaticResource SmallIconButton}"
                            ToolTip="Information">
                            <Image
                                x:Name="infoIcon"
                                Width="20"
                                Height="20" />
                        </Button>
                        <Button
                            x:Name="btnExit"
                            Style="{StaticResource SmallIconButton}"
                            ToolTip="Close Application">
                            <Image
                                x:Name="closeIcon"
                                Width="20"
                                Height="20" />
                        </Button>
                    </StackPanel>
                </Grid>
            </Border>

            <!--  Main content  -->
            <Border
                Grid.Column="1"
                Margin="5,5,5,5"
                Background="White"
                Style="{StaticResource Card}">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="*" />
                    </Grid.RowDefinitions>

                    <!--  Search bar and filter  -->
                    <Border
                        Grid.Row="0"
                        Padding="10"
                        Background="#F5F5F5"
                        BorderBrush="#E0E0E0"
                        BorderThickness="0,0,0,1"
                        CornerRadius="4,4,0,0">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*" />
                                <ColumnDefinition Width="Auto" />
                            </Grid.ColumnDefinitions>

                            <!--  Search field  -->
                            <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                                <TextBlock
                                    Margin="0,0,10,0"
                                    VerticalAlignment="Center"
                                    Text="Search:" />
                                <TextBox
                                    x:Name="txtSearch"
                                    Width="200"
                                    Margin="0,0,5,0"
                                    VerticalContentAlignment="Center" 
                                    Style="{StaticResource ModernTextBox}"/>
                                <ComboBox
                                    x:Name="cmbSearchField"
                                    Width="120"
                                    Margin="0,0,10,0"
                                    VerticalContentAlignment="Center"
                                    Padding="8,5"
                                    SelectedIndex="0">
                                    <ComboBoxItem
                                        AutomationProperties.Name="Search by computer name"
                                        Content="ComputerName"
                                        TabIndex="2"
                                        ToolTip="Search by computer name" />
                                    <ComboBoxItem
                                        AutomationProperties.Name="Search by BitLocker key"
                                        Content="BitLockerKey"
                                        TabIndex="3"
                                        ToolTip="Search by BitLocker key" />
                                    <ComboBoxItem
                                        AutomationProperties.Name="Search all fields"
                                        Content="All Fields"
                                        TabIndex="4"
                                        ToolTip="Search all fields" />
                                </ComboBox>
                                <Button
                                    x:Name="btnSearch"
                                    Margin="5,0,0,0"
                                    Padding="10,5"
                                    Content="Search" 
                                    Style="{StaticResource ModernButton}"/>
                                <Button
                                    x:Name="btnClearSearch"
                                    Margin="5,0,0,0"
                                    Padding="8,5"
                                    Content="X"
                                    ToolTip="Reset search" 
                                    Style="{StaticResource ModernButton}"/>
                            </StackPanel>

                            <!--  Filter by age  -->
                            <StackPanel
                                Grid.Column="1"
                                Margin="10,0,0,0"
                                Orientation="Horizontal" VerticalAlignment="Center">
                                <TextBlock
                                    Margin="0,0,10,0"
                                    VerticalAlignment="Center"
                                    Text="Filter:" />
                                <ComboBox
                                    x:Name="cmbFilter"
                                    Width="150"
                                    VerticalContentAlignment="Center"
                                    Padding="8,5"
                                    SelectedIndex="0">
                                    <ComboBoxItem Content="Show all" />
                                    <ComboBoxItem Content="Current (&lt; 7 months)" />
                                    <ComboBoxItem Content="Older (7-12 months)" />
                                    <ComboBoxItem Content="Critical (&gt; 12 months)" />
                                </ComboBox>
                                <Button
                                    x:Name="btnApplyFilter"
                                    Margin="10,0,0,0"
                                    Padding="10,5"
                                    Content="Apply" 
                                    Style="{StaticResource ModernButton}"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <!--  DataGrid for BitLocker Keys  -->
                    <DataGrid
                        x:Name="dataGrid"
                        Grid.Row="1"
                        Margin="0,10,0,0"
                        AlternatingRowBackground="#F9F9F9"
                        AutoGenerateColumns="False"
                        Background="White"
                        BorderBrush="#E0E0E0"
                        BorderThickness="1"
                        CanUserResizeRows="False"
                        GridLinesVisibility="Horizontal"
                        HeadersVisibility="Column"
                        HorizontalScrollBarVisibility="Auto"
                        IsReadOnly="True"
                        RowHeaderWidth="0"
                        SelectionMode="Single"
                        SelectionUnit="FullRow"
                        VerticalScrollBarVisibility="Auto">
                        <DataGrid.Resources>
                            <Style TargetType="{x:Type DataGridColumnHeader}">
                                <Setter Property="Background" Value="#F0F0F0" />
                                <Setter Property="Padding" Value="8,10" />
                                <Setter Property="FontWeight" Value="SemiBold" />
                                <Setter Property="BorderThickness" Value="0,0,1,1" />
                                <Setter Property="BorderBrush" Value="#D0D0D0" />
                            </Style>
                            <Style TargetType="{x:Type DataGridCell}">
                                <Setter Property="Padding" Value="8,5"/>
                                <Setter Property="BorderThickness" Value="0"/>
                            </Style>
                        </DataGrid.Resources>

                        <DataGrid.Columns>
                            <DataGridTextColumn
                                Width="60"
                                Binding="{Binding Nr}"
                                Header="Nr">
                                <DataGridTextColumn.HeaderStyle>
                                    <Style BasedOn="{StaticResource {x:Type DataGridColumnHeader}}" TargetType="DataGridColumnHeader">
                                        <Setter Property="Tag" Value="Nr" />
                                    </Style>
                                </DataGridTextColumn.HeaderStyle>
                            </DataGridTextColumn>
                            <DataGridTextColumn
                                Width="*"
                                Binding="{Binding ComputerName}"
                                Header="ComputerName">
                                <DataGridTextColumn.HeaderStyle>
                                    <Style BasedOn="{StaticResource {x:Type DataGridColumnHeader}}" TargetType="DataGridColumnHeader">
                                        <Setter Property="Tag" Value="ComputerName" />
                                    </Style>
                                </DataGridTextColumn.HeaderStyle>
                            </DataGridTextColumn>
                            <DataGridTextColumn
                                Width="2*"
                                Binding="{Binding BitLockerKey}"
                                Header="BitLockerKey">
                                <DataGridTextColumn.HeaderStyle>
                                    <Style BasedOn="{StaticResource {x:Type DataGridColumnHeader}}" TargetType="DataGridColumnHeader">
                                        <Setter Property="Tag" Value="BitLockerKey" />
                                    </Style>
                                </DataGridTextColumn.HeaderStyle>
                            </DataGridTextColumn>
                            <DataGridTextColumn
                                Width="120"
                                Binding="{Binding Datum}"
                                Header="Date">
                                <DataGridTextColumn.HeaderStyle>
                                    <Style BasedOn="{StaticResource {x:Type DataGridColumnHeader}}" TargetType="DataGridColumnHeader">
                                        <Setter Property="Tag" Value="Date" />
                                    </Style>
                                </DataGridTextColumn.HeaderStyle>
                            </DataGridTextColumn>
                        </DataGrid.Columns>
                    </DataGrid>
                </Grid>
            </Border>
        </Grid>

        <!--  Footer area  -->
        <Border
            x:Name="footerBorder"
            Grid.Row="2"
            Background="#FF1C323C"
            BorderBrush="#E0E0E0"
            BorderThickness="0,1,0,0">
            <Grid Margin="20,0">
                 <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="Auto" />
                    <ColumnDefinition Width="*" />
                </Grid.ColumnDefinitions>
                <TextBlock
                    x:Name="versionText"
                    Grid.Column="1"
                    HorizontalAlignment="Center"
                    VerticalAlignment="Center"
                    FontSize="11"
                    Foreground="#e2e2e2"
                    Text="$APPName - Version $ScriptVersion  |  Last Update: $LastUpdate  |  Author: $Author" />
            </Grid>
        </Border>
    </Grid>
</Window>
'@
#endregion

#region Initialize GUI Elements
# Expand PowerShell variables in the XAML string
$expandedXaml = $ExecutionContext.InvokeCommand.ExpandString($xamlString)

# Create XAML reader from the expanded string
try {
    [xml]$xmlDoc = $expandedXaml # Convert to XML object to ensure it's well-formed
} catch {
    Write-Log -Message "Error parsing expanded XAML string. It might not be well-formed XML. Error: $($_.Exception.Message)" -Level ERROR
    Write-Log -Message "Problematic XAML string (first 500 chars): $($expandedXaml.Substring(0, [System.Math]::Min($expandedXaml.Length, 500)))" -Level DEBUG
    # Further error handling or exit might be needed here
    exit 1
}

$reader = New-Object System.Xml.XmlNodeReader $xmlDoc
$window = [Windows.Markup.XamlReader]::Load($reader)

# Reference elements from XAML
$headerBorder = $window.FindName("headerBorder")
$headerTitle = $window.FindName("headerTitle")
$headerSubtitle = $window.FindName("headerSubtitle")
$headerLogo = $window.FindName("headerLogo")
$footerBorder = $window.FindName("footerBorder")
$versionText = $window.FindName("versionText")
$dataGrid = $window.FindName("dataGrid")
$btnRefresh = $window.FindName("btnRefresh")
$btnCopyKey = $window.FindName("btnCopyKey")
$btnExport = $window.FindName("btnExport")
$btnDelete = $window.FindName("btnDelete")
$infoIcon = $window.FindName("infoIcon")
$closeIcon = $window.FindName("closeIcon")
$btnInfo = $window.FindName("btnInfo")
$btnExit = $window.FindName("btnExit")


# Update GUI elements
try {
    Write-DebugMessage -Message "Updating UI elements with configuration values"

    # Set global font family and size for the window from configuration
    if ($null -ne $window) {
        if (-not ([string]::IsNullOrEmpty($FontFamily))) {
            $window.FontFamily = New-Object System.Windows.Media.FontFamily($FontFamily)
            Write-DebugMessage -Message "Set window FontFamily to '$FontFamily'"
        }
        # Ensure FontSize is a valid double for WPF
        if ($FontSize -is [double] -or $FontSize -is [int] -or $FontSize -is [float]) {
            $window.FontSize = [double]$FontSize
            Write-DebugMessage -Message "Set window FontSize to '$FontSize'"
        } else {
            Write-Log -Message "Invalid FontSize value: '$FontSize'. Must be a number." -Level WARN
        }
    }

    # Set theme color
    $themeBrushConverter = New-Object System.Windows.Media.BrushConverter
    $themeColorBrush = $themeBrushConverter.ConvertFromString($ThemeColor)
    
    if ($null -ne $headerBorder) { 
        $headerBorder.Background = $themeColorBrush
        Write-DebugMessage -Message "Set header background to '$ThemeColor'"
    }
    if ($null -ne $footerBorder) { 
        $footerBorder.Background = $themeColorBrush 
        Write-DebugMessage -Message "Set footer background to '$ThemeColor'"
    }
    
    # Set text content
    if ($null -ne $headerTitle) { 
        $headerTitle.Text = $APPName 
        Write-DebugMessage -Message "Set header title to '$APPName'"
    }
    if ($null -ne $headerSubtitle) { 
        $headerSubtitle.Text = $APPDescription 
        Write-DebugMessage -Message "Set header subtitle to '$APPDescription'"
    }
    # The following block for $footerText was removed as $footerText was not initialized
    # and $FooterText variable was not defined. The version information is handled by $versionText.
    
    # GUI footer text with replacements (version, update date, author)
    $versionString = "Version: $ScriptVersion  -  last updated: $LastUpdate  |  Author: $Author"
    if ($null -ne $versionText) { 
        $versionText.Text = $versionString 
        Write-DebugMessage -Message "Set version text to '$versionString'"
    }
    
    # Load logo
    if ($null -ne $headerLogo) {
        if (-not ([string]::IsNullOrEmpty($ConfigHeaderLogoFileName))) { 
            $logoFileOrPathFromConfig = $ConfigHeaderLogoFileName 
            
            $resolvedLogoPath = $logoFileOrPathFromConfig
            # If the configured path isn't absolute, assume it's relative to the script's root directory
            if (-not ([System.IO.Path]::IsPathRooted($logoFileOrPathFromConfig))) {
                $resolvedLogoPath = Join-Path $script:ScriptRoot $logoFileOrPathFromConfig
            }

            if (Test-Path $resolvedLogoPath) {
                try {
                    $headerImage = New-Object System.Windows.Media.Imaging.BitmapImage
                    $headerImage.BeginInit()
                    # BitmapImage requires an absolute URI. $resolvedLogoPath should be absolute here.
                    $uri = New-Object System.Uri($resolvedLogoPath, [System.UriKind]::Absolute)
                    $headerImage.UriSource = $uri
                    $headerImage.EndInit()
                    $headerLogo.Source = $headerImage # Set the source of the XAML Image control
                    Write-DebugMessage -Message "Loaded header logo from '$resolvedLogoPath'"
                } catch {
                    Write-Log -Message "Error creating image object for logo. Configured: '$logoFileOrPathFromConfig', Resolved: '$resolvedLogoPath'. Error: $($_.Exception.Message)" -Level ERROR
                }
            }
            else {
                Write-Log -Message "Logo file (configured as '$logoFileOrPathFromConfig') not found. Attempted to load from '$resolvedLogoPath'." -Level WARN
                $headerLogo.Visibility = [System.Windows.Visibility]::Collapsed
            }
        }
        else {
            Write-DebugMessage -Message "Configuration for header logo file/path ('$ConfigHeaderLogoFileName') is empty. Skipping logo load."
            $headerLogo.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
    else {
        # This case means $window.FindName("headerLogo") returned null.
        Write-Log -Message "XAML Image element for the header logo (expected name 'headerLogo') was not found in the window." -Level WARN
    }
    # Load icons
    $iconsPath = Join-Path $script:ScriptRoot "assets"
    $infoIconLoaded = $false
    $closeIconLoaded = $false
    
    # Load info icon
    if ($null -ne $infoIcon) {
        $infoIconPath = Join-Path $iconsPath "info.png"
        if (Test-Path $infoIconPath) {
            $infoImage = New-Object System.Windows.Media.Imaging.BitmapImage
            $infoImage.BeginInit()
            $infoImage.UriSource = New-Object System.Uri($infoIconPath)
            $infoImage.EndInit()
            $infoIcon.Source = $infoImage
            $infoIconLoaded = $true
            Write-DebugMessage -Message "Loaded info icon from $infoIconPath"
        }
        else {
            Write-Log -Message "Info icon not found: $infoIconPath. Using text fallback." -Level WARN
        }
    }
    
    # Load close icon
    if ($null -ne $closeIcon) {
        $closeIconPath = Join-Path $iconsPath "close.png"
        if (Test-Path $closeIconPath) {
            $closeImage = New-Object System.Windows.Media.Imaging.BitmapImage
            $closeImage.BeginInit()
            $closeImage.UriSource = New-Object System.Uri($closeIconPath)
            $closeImage.EndInit()
            $closeIcon.Source = $closeImage
            $closeIconLoaded = $true
            Write-DebugMessage -Message "Loaded close icon from $closeIconPath"
        }
        else {
            Write-Log -Message "Close icon not found: $closeIconPath. Using text fallback." -Level WARN
        }
    }

    if (-not $infoIconLoaded -and $null -ne $btnInfo) {
        $btnInfo.Content = "i"
        $btnInfo.FontWeight = [System.Windows.FontWeights]::Bold
    }

    if (-not $closeIconLoaded -and $null -ne $btnExit) {
        $btnExit.Content = "X"
        $btnExit.FontWeight = [System.Windows.FontWeights]::Bold
    }
}
catch {
    Write-Log -Message "Error customizing the GUI: $_" -Level ERROR
    [System.Windows.MessageBox]::Show("An unexpected error occurred. Please contact support.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
}
#endregion

#region Event Handlers for Navigation
# Event handler for logo click
if ($null -ne $headerLogo -and -not [string]::IsNullOrWhiteSpace($HeaderLogoURL)) {
    $headerLogo.AddHandler([System.Windows.Controls.Image]::MouseLeftButtonDownEvent, [System.Windows.Input.MouseButtonEventHandler]{
        try {
            Write-DebugMessage -Message "Header logo clicked, opening URL: $HeaderLogoURL"
            Start-Process $HeaderLogoURL
        }
        catch {
            Write-Log -Message "Error opening URL $HeaderLogoURL : $_" -Level ERROR
        }
    })
}

# Event handler for footer click
# if ($null -ne $footerText) {
#    $footerText.Add_MouseLeftButtonDown({
#        try {
#            Write-DebugMessage -Message "Footer text clicked, opening URL: $HeaderLogoURL"
#            Start-Process $HeaderLogoURL
#        }
#        catch {
#            Write-Log -Message "Error opening URL $HeaderLogoURL - $_" -Level ERROR
#        }
#    })
#    # Set cursor style to indicate clickable text
#    $footerText.Cursor = [System.Windows.Input.Cursors]::Hand
# }
#endregion

#region ActiveDirectory Integration
# Import ActiveDirectory module
if (-not $script:ClientMode) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Log -Message "ActiveDirectory module loaded successfully" -Level INFO
    }
    catch {
        Write-Log -Message "Error loading ActiveDirectory module: $_. Switching to client mode with sample data." -Level WARN
        $script:ClientMode = $true
    }
}
else {
    Write-Log -Message "Client mode active. Skipping ActiveDirectory module import." -Level INFO
}

# Function to load BitLocker keys
function Get-BitLockerKeys {
    try {
        Write-Log -Message "Starting AD query for BitLocker keys..." -Level INFO
        Write-DebugMessage -Message "Executing AD query for msFVE-RecoveryInformation objects"
        
        # AD query: All BitLocker keys (msFVE-RecoveryInformation)
        $bitLockerKeys = Get-ADObject -Filter 'objectClass -eq "msFVE-RecoveryInformation"' -Properties msFVE-RecoveryPassword, whenCreated, distinguishedName
        
        # Clear and refill DataGrid
        $tableData = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
        
        $counter = 1
        foreach ($key in $bitLockerKeys) {
            # Extract the actual computer name from the DistinguishedName
            $dnParts = $key.distinguishedName.Split(',')
            if ($dnParts.Length -ge 2) {
                $computerName = $dnParts[1] -replace "^CN=", ""
            }
            else {
                $computerName = "Unknown"
            }
            
            # Extract BitLocker key and date
            $bitLockerKey = $key.'msFVE-RecoveryPassword'
            $date = $key.whenCreated
            
            # Create object for table data
            $rowObj = New-Object PSObject -Property @{
                Nr = $counter
                ComputerName = $computerName
                BitLockerKey = $bitLockerKey
                Datum = $date.ToString("dd.MM.yyyy")
                DistinguishedName = $key.distinguishedName  # Store for later delete operations
                RowBackground = $null  # Will be set shortly
            }
            
            # Background color based on date
            if ([string]::IsNullOrEmpty($bitLockerKey)) {
                $rowObj.RowBackground = "#D3D3D3"  # LightGray
                Write-DebugMessage -Message "Empty key for $computerName, setting gray background"
            }
            else {
                $ageDays = (Get-Date) - $date
                $ageMonths = $ageDays.Days / 30
                
                if ($ageMonths -ge 12) {
                    $rowObj.RowBackground = "#F08080"  # LightCoral
                    Write-DebugMessage -Message "Key for $computerName is $ageMonths months old (critical)"
                }
                elseif ($ageMonths -ge 7) {
                    $rowObj.RowBackground = "#FFA500"  # Orange
                    Write-DebugMessage -Message "Key for $computerName is $ageMonths months old (warning)"
                }
                else {
                    $rowObj.RowBackground = "#90EE90"  # LightGreen
                    Write-DebugMessage -Message "Key for $computerName is $ageMonths months old (current)"
                }
            }
            
            $tableData.Add($rowObj)
            $counter++
        }
        
        Write-Log -Message "AD query completed: $($tableData.Count) entries found" -Level INFO
        return $tableData
    }
    catch {
        Write-Log -Message "Error in AD query: $_" -Level ERROR
        [System.Windows.MessageBox]::Show("Error in AD query: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return New-Object System.Collections.ObjectModel.ObservableCollection[Object]
    }
}

# Function to load sample BitLocker keys for client mode
function Get-SampleBitLockerKeys {
    Write-Log -Message "Loading sample BitLocker keys for client mode..." -Level INFO
    $tableData = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
    
    $sampleData = @(
        @{ Nr = 1; ComputerName = "ClientPC01"; BitLockerKey = "1234-5678-9012-3456"; Datum = (Get-Date).AddMonths(-2).ToString("dd.MM.yyyy"); RowBackground = "#90EE90" },
        @{ Nr = 2; ComputerName = "ClientPC02"; BitLockerKey = "2345-6789-0123-4567"; Datum = (Get-Date).AddMonths(-8).ToString("dd.MM.yyyy"); RowBackground = "#FFA500" },
        @{ Nr = 3; ComputerName = "ClientPC03"; BitLockerKey = "3456-7890-1234-5678"; Datum = (Get-Date).AddMonths(-13).ToString("dd.MM.yyyy"); RowBackground = "#F08080" },
        @{ Nr = 4; ComputerName = "ClientPC04"; BitLockerKey = ""; Datum = (Get-Date).AddMonths(-1).ToString("dd.MM.yyyy"); RowBackground = "#D3D3D3" }
    )
    
    foreach ($item in $sampleData) {
        $rowObj = New-Object PSObject -Property $item
        $tableData.Add($rowObj)
    }
    
    Write-Log -Message "Sample data loaded: $($tableData.Count) entries" -Level INFO
    return $tableData
}

# Fill DataGrid with BitLocker keys
function Update-BitLockerKeyTable {
    try {
        Write-DebugMessage -Message "Updating BitLocker key table"
        $tableData = if ($script:ClientMode) { Get-SampleBitLockerKeys } else { Get-BitLockerKeys }
        
        # Convert the collection to a proper ObservableCollection
        $observableCollection = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
        
        foreach ($item in $tableData) {
            $observableCollection.Add($item)
        }
        
        # Dispatcher for thread-safe UI updates
        $window.Dispatcher.Invoke([action]{
            $dataGrid.ItemsSource = $observableCollection

            $global:originalData = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
            foreach ($row in $observableCollection) {
                $global:originalData.Add($row)
            }
            
            # Style adjustment for rows based on RowBackground value
            Update-RowStyling -DataGrid $dataGrid
            
            Write-DebugMessage -Message "DataGrid updated with $($observableCollection.Count) rows"
        })
    }
    catch {
        Write-Log -Message "Error updating table: $_" -Level ERROR
    }
}

function Update-RowStyling {
    param (
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.DataGrid]$DataGrid
    )
    
    try {
        Write-DebugMessage -Message "Updating row styling for DataGrid"
        
        # Sicherstellen, dass der Handler nur einmal registriert wird
        if (-not $script:RowStylingHandlerRegistered) {
            $DataGrid.add_LoadingRow({ 
                param($rowSender, $rowEventArgs)
                
                $row = $rowEventArgs.Row
                $item = $row.DataContext
                
                # Überprüfe, ob das Item eine RowBackground-Eigenschaft hat
                if ($null -ne $item -and $null -ne $item.PSObject.Properties['RowBackground']) {
                    $colorCode = $item.RowBackground
                    if (-not [string]::IsNullOrEmpty($colorCode)) {
                        try {
                            $brushConverter = New-Object System.Windows.Media.BrushConverter
                            $brush = $brushConverter.ConvertFromString($colorCode)
                            $row.Background = $brush
                        }
                        catch {
                            Write-Log -Message "Fehler beim Konvertieren der Farbe: $_" -Level WARN
                        }
                    }
                }
            })
            $script:RowStylingHandlerRegistered = $true
            Write-DebugMessage -Message "Row styling event handler wurde registriert"
        }
    }
    catch {
        Write-Log -Message "Fehler beim Aktualisieren des Row-Stylings: $_" -Level ERROR
    }
}
#endregion

#region Button Event Handlers
# Button events
if ($null -ne $btnExport) {
    $btnExport.Add_Click({
        try {
            Write-DebugMessage -Message "Export button clicked"
            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.DefaultExt = ".csv"
            $dialog.Filter = "CSV files (*.csv)|*.csv"
            $dialog.Title = "Save BitLocker keys as CSV"
            
            $result = $dialog.ShowDialog()
            
            if ($result -eq $true) {
                $filePath = $dialog.FileName
                
                $csvData = @()
                foreach ($item in $dataGrid.ItemsSource) {
                    $csvData += [PSCustomObject]@{
                        Nr = $item.Nr
                        ComputerName = $item.ComputerName
                        BitLockerKey = $item.BitLockerKey
                        Datum = $item.Datum
                    }
                }
                
                $csvData | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
                Write-Log -Message "CSV export to $filePath completed" -Level INFO
                Write-DebugMessage -Message "Exported $($csvData.Count) records to $filePath"
                [System.Windows.MessageBox]::Show("Export completed!", "Export", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            }
        }
        catch {
            Write-Log -Message "Error during CSV export: $_" -Level ERROR
            [System.Windows.MessageBox]::Show("Error during export: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
} else {
    Write-Log -Message "GUI Element 'btnExport' (Export Button) not found or initialized. Export functionality will be unavailable." -Level WARN
}

if ($null -ne $btnDelete) {
    $btnDelete.Add_Click({
        try {
            Write-DebugMessage -Message "Delete button clicked"

            if ($script:ClientMode) {
                [System.Windows.MessageBox]::Show("Delete is disabled in client mode.", "Information", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                return
            }

            $selectedItem = $dataGrid.SelectedItem
            
            if ($null -eq $selectedItem) {
                [System.Windows.MessageBox]::Show("Please select an entry from the list!", "Note", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                return
            }
            
            $confirm = [System.Windows.MessageBox]::Show("Really remove the selected entry?", "Remove", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
            
            if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                $dn = $selectedItem.DistinguishedName
                if ([string]::IsNullOrWhiteSpace($dn)) {
                    [System.Windows.MessageBox]::Show("No DistinguishedName found for selected entry.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                    return
                }

                try {
                    # Delete AD object
                    Write-DebugMessage -Message "Removing AD object: $dn"
                    Remove-ADObject -Identity $dn -Confirm:$false
                    Write-Log -Message "AD object removed: $dn" -Level INFO
                    
                    # Update table
                    Update-BitLockerKeyTable
                    
                    [System.Windows.MessageBox]::Show("Entry has been removed.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                }
                catch {
                    Write-Log -Message "Error removing entry $dn : $_" -Level ERROR
                    [System.Windows.MessageBox]::Show("Error removing entry: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
        }
        catch {
            Write-Log -Message "Error in delete function: $_" -Level ERROR
        }
    })
} else {
    Write-Log -Message "GUI Element 'btnDelete' (Delete Button) not found or initialized. Delete functionality will be unavailable." -Level WARN
}

if ($null -ne $btnExit) {
    $btnExit.Add_Click({
        Write-DebugMessage -Message "Exit button clicked, closing application"
        $window.Close()
    })
} else {
    Write-Log -Message "GUI Element 'btnExit' (Exit Button) not found or initialized. Exit functionality will be unavailable." -Level WARN
}

if ($null -ne $btnInfo) {
    $btnInfo.Add_Click({
        try {
            Write-DebugMessage -Message "Info button clicked, showing application information"
            $infoText = @"
$APPName - $ScriptVersion
Last update: $LastUpdate
Author: $Author

This tool displays all BitLocker keys from Active Directory.
Color coding:
- Green: Current key (< 7 months)
- Orange: Key older than 7 months
- Red: Key older than 12 months
- Gray: No key available
"@
            [System.Windows.MessageBox]::Show($infoText, "Info", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
        catch {
            Write-Log -Message "Error displaying info: $_" -Level ERROR
        }
    })
} else {
    Write-Log -Message "GUI Element 'btnInfo' (Info Button) not found or initialized. Info functionality will be unavailable." -Level WARN
}

# Refresh function to update AD query
if ($null -ne $btnRefresh) {
    $btnRefresh.Add_Click({
        try {
            Write-DebugMessage -Message "Refresh button clicked"
            Write-Log -Message "Manual refresh of BitLocker keys requested" -Level INFO
            Update-BitLockerKeyTable
            [System.Windows.MessageBox]::Show("Data has been refreshed successfully.", "Refresh", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
        catch {
            Write-Log -Message "Error during manual refresh: $_" -Level ERROR
            [System.Windows.MessageBox]::Show("Error during refresh: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
} else {
    Write-Log -Message "GUI Element 'btnRefresh' (Refresh Button) not found or initialized. Refresh functionality will be unavailable." -Level WARN
}

# Function to copy selected BitLocker key to clipboard
if ($null -ne $btnCopyKey) {
    $btnCopyKey.Add_Click({
        try {
            Write-DebugMessage -Message "Copy key button clicked"
            $selectedItem = $dataGrid.SelectedItem
            
            if ($null -eq $selectedItem) {
                [System.Windows.MessageBox]::Show("Please select an entry from the list!", "Note", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                return
            }
            
            # Copy BitLocker key to clipboard
            $key = $selectedItem.BitLockerKey
            if ([string]::IsNullOrEmpty($key)) {
                [System.Windows.MessageBox]::Show("The selected entry does not contain a BitLocker key.", "Note", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return
            }
            
            [System.Windows.Forms.Clipboard]::SetText($key)
            Write-Log -Message "BitLocker key for computer $($selectedItem.ComputerName) copied to clipboard" -Level INFO
            Write-DebugMessage -Message "Copied BitLocker key for $($selectedItem.ComputerName) to clipboard"
            [System.Windows.MessageBox]::Show("The BitLocker key has been copied to the clipboard.", "Copied", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
        catch {
            Write-Log -Message "Error copying BitLocker key: $_" -Level ERROR
            [System.Windows.MessageBox]::Show("Error copying key: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
} else {
    Write-Log -Message "GUI Element 'btnCopyKey' (Copy Key Button) not found or initialized. Copy key functionality will be unavailable." -Level WARN
}
#endregion

#region Search and Filter Functions
# References for search and filter components
$txtSearch = $window.FindName("txtSearch")
$cmbSearchField = $window.FindName("cmbSearchField")
$btnSearch = $window.FindName("btnSearch")
$btnClearSearch = $window.FindName("btnClearSearch")
$cmbFilter = $window.FindName("cmbFilter")
$btnApplyFilter = $window.FindName("btnApplyFilter")

# Store original data for search
$global:originalData = $null

# Event handler for search
if ($null -ne $btnSearch) {
    $btnSearch.Add_Click({
        try {
            Write-DebugMessage -Message "Search button clicked"
            # Ensure original data is saved
            if ($null -eq $global:originalData) {
                $global:originalData = $dataGrid.ItemsSource
            }
            
            $searchText = $txtSearch.Text.Trim()
            if ([string]::IsNullOrEmpty($searchText)) {
                [System.Windows.MessageBox]::Show("Please enter a search term.", "Search", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                return
            }
            
            $searchField = ($cmbSearchField.SelectedItem).Content.ToString()
            Write-DebugMessage -Message "Searching for '$searchText' in field '$searchField'"
            
            # Create new filtered collection
            $filteredData = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
            
            foreach ($item in $global:originalData) {
                $match = $false
                
                switch ($searchField) {
                    "ComputerName" {
                        if ($item.ComputerName -like "*$searchText*") { $match = $true }
                    }
                    "BitLockerKey" {
                        if ($item.BitLockerKey -like "*$searchText*") { $match = $true }
                    }
                    "All Fields" {
                        if (
                            ($item.ComputerName -like "*$searchText*") -or
                            ($item.BitLockerKey -like "*$searchText*") -or
                            ($item.Datum -like "*$searchText*")
                        ) { $match = $true }
                    }
                }
                
                if ($match) {
                    $filteredData.Add($item)
                }
            }
            
            $dataGrid.ItemsSource = $filteredData
            
            Write-Log -Message "Search performed: $($filteredData.Count) matches for '$searchText' in field '$searchField'" -Level INFO
            
            if ($filteredData.Count -eq 0) {
                [System.Windows.MessageBox]::Show("No entries found.", "Search", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            }
        }
        catch {
            Write-Log -Message "Error during search: $_" -Level ERROR
            [System.Windows.MessageBox]::Show("Error during search: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
} else {
    Write-Log -Message "GUI Element 'btnSearch' (Search Button) not found in XAML. Search functionality will be unavailable." -Level WARN
}

# Event handler for clearing search
if ($null -ne $btnClearSearch) {
    $btnClearSearch.Add_Click({
        try {
            Write-DebugMessage -Message "Clear search button clicked"
            $txtSearch.Text = ""
            
            if ($null -ne $global:originalData) {
                $dataGrid.ItemsSource = $global:originalData
                Write-Log -Message "Search reset" -Level INFO
            }
            else {
                # If no original data stored, reload
                Update-BitLockerKeyTable
            }
        }
        catch {
            Write-Log -Message "Error resetting search: $_" -Level ERROR
        }
    })
} else {
    Write-Log -Message "GUI Element 'btnClearSearch' (Clear Search Button) not found in XAML. Clear search functionality will be unavailable." -Level WARN
}

# Event handler for applying filter
if ($null -ne $btnApplyFilter) {
    $btnApplyFilter.Add_Click({
        try {
            Write-DebugMessage -Message "Apply filter button clicked"
            # Ensure original data is saved
            if ($null -eq $global:originalData) {
                $global:originalData = $dataGrid.ItemsSource
            }
            
            $filterOption = ($cmbFilter.SelectedItem).Content.ToString()
            Write-DebugMessage -Message "Applying filter: $filterOption"
            
            # If "Show all" is selected, show original data
            if ($filterOption -eq "Show all") {
                $dataGrid.ItemsSource = $global:originalData
                Write-Log -Message "Filter reset: Showing all entries" -Level INFO
                return
            }
            
            # Create filtered collection
            $filteredData = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
            
            foreach ($item in $global:originalData) {
                try {
                    # Safely parse date with various formats
                    $datum = $null
                    $dateFormats = @("dd.MM.yyyy", "yyyy-MM-dd", "MM/dd/yyyy")
                    
                    foreach ($format in $dateFormats) {
                        try {
                            $datum = [DateTime]::ParseExact($item.Datum, $format, [System.Globalization.CultureInfo]::InvariantCulture)
                            break # Stop once a format works
                        } catch {
                            # Continue to next format
                        }
                    }
                    
                    # If no format worked, try general parsing
                    if ($null -eq $datum) {
                        if ([DateTime]::TryParse($item.Datum, [ref]$datum)) {
                            # Successfully parsed
                        } else {
                            # Set to minimum date if unparseable
                            $datum = [DateTime]::MinValue
                            Write-DebugMessage -Message "Could not parse date: $($item.Datum) for computer $($item.ComputerName)"
                        }
                    }
                    
                    $ageInMonths = (New-TimeSpan -Start $datum -End (Get-Date)).Days / 30
                    
                    $match = $false
                    
                    switch ($filterOption) {
                        "Current (< 7 months)" {
                            if ($ageInMonths -lt 7) { $match = $true }
                        }
                        "Older (7-12 months)" {
                            if ($ageInMonths -ge 7 -and $ageInMonths -lt 12) { $match = $true }
                        }
                        "Critical (> 12 months)" {
                            if ($ageInMonths -ge 12) { $match = $true }
                        }
                    }
                    
                    if ($match) {
                        $filteredData.Add($item)
                    }
                }
                catch {
                    Write-Log -Message "Error filtering an entry: $_" -Level WARN
                }
            }
            
            $dataGrid.ItemsSource = $filteredData
            
            Write-Log -Message "Filter applied: $($filteredData.Count) entries for option '$filterOption'" -Level INFO
            
            if ($filteredData.Count -eq 0) {
                [System.Windows.MessageBox]::Show("No entries found for the selected filter.", "Filter", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            }
        }
        catch {
            Write-Log -Message "Error applying filter: $_" -Level ERROR
            [System.Windows.MessageBox]::Show("Error filtering: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
} else {
    Write-Log -Message "GUI Element 'btnApplyFilter' (Apply Filter Button) not found in XAML. Filter functionality will be unavailable." -Level WARN
}
#endregion

#region DataGrid Interactions
# Implement column sorting
function SortColumn_Click {
    param(
        [Parameter(Mandatory=$true)]
        [System.Object]$HeaderSender,
        [Parameter(Mandatory=$true)]
        [System.Windows.RoutedEventArgs]$RoutedEventArgs
    )
    
    try {
        if ($null -eq $HeaderSender -or $null -eq $HeaderSender.Column) {
            Write-Log -Message "Invalid column header clicked" -Level WARN
            return
        }
        
        $headerClicked = $HeaderSender
        $columnName = $headerClicked.Column.Header.ToString()
        
        Write-Log -Message "Sorting by column: $columnName" -Level INFO
        Write-DebugMessage -Message "Sorting table by column: $columnName"
        
        # Get current data
        $data = $dataGrid.ItemsSource
        
        # Sorting logic based on column
        $sortedData = $null
        
        switch ($columnName) {
            "Nr" {
                $sortedData = [System.Linq.Enumerable]::OrderBy($data, [Func[Object, int]] { param($x) $x.Nr })
            }
            "ComputerName" {
                $sortedData = [System.Linq.Enumerable]::OrderBy($data, [Func[Object, string]] { param($x) $x.ComputerName })
            }
            "BitLockerKey" {
                $sortedData = [System.Linq.Enumerable]::OrderBy($data, [Func[Object, string]] { param($x) $x.BitLockerKey })
            }
            "Date" {
                # Sort date as string in correct format (dd.MM.yyyy)
                $sortedData = [System.Linq.Enumerable]::OrderBy($data, [Func[Object, DateTime]] { 
                    param($x) 
                    try {
                        [DateTime]::ParseExact($x.Datum, "dd.MM.yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
                    } 
                    catch {
                        [DateTime]::MinValue
                    }
                })
            }
        }
        
        if ($null -ne $sortedData) {
            # Convert to ObservableCollection
            $sortedCollection = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
            foreach ($item in $sortedData) {
                $sortedCollection.Add($item)
            }
            
            $dataGrid.ItemsSource = $sortedCollection
            Write-DebugMessage -Message "Table sorted by $columnName"
        }
    }
    catch {
        Write-Log -Message "Error sorting column $columnName : $_" -Level ERROR
    }
}

# Add column sorting event handlers
try {
    # Ensure Windows.Controls namespace is properly loaded
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    # Add handler using correct namespace
    $dataGrid.AddHandler([System.Windows.Controls.Primitives.DataGridColumnHeader]::MouseLeftButtonUpEvent, 
        [System.Windows.Input.MouseButtonEventHandler]{
        param($columnHeaderSender, $columnHeaderEventArgs)
        
        try {
            $header = [System.Windows.Media.VisualTreeHelper]::HitTest($dataGrid, $columnHeaderEventArgs.GetPosition($dataGrid)).VisualHit
            
            # Navigate up the tree to find the column header
            while ($null -ne $header -and -not ($header -is [System.Windows.Controls.Primitives.DataGridColumnHeader])) {
                $header = [System.Windows.Media.VisualTreeHelper]::GetParent($header)
            }
            
            if ($null -ne $header -and $header -is [System.Windows.Controls.Primitives.DataGridColumnHeader]) {
                $columnName = $header.Column.Header.ToString()
                Write-DebugMessage -Message "Column header clicked: $columnName"
                
                # Call the sort function
                SortColumn_Click -HeaderSender $header -RoutedEventArgs $columnHeaderEventArgs
            }
        }
        catch {
            Write-Log -Message "Error in column header click handler: $_" -Level ERROR
        }
    })
}
catch {
    Write-Log -Message "Error setting up column sorting: $_" -Level ERROR
}
#endregion

#region Application Initialization and Cleanup
# Run self-diagnostic
if (-not (Test-Requirements)) {
    [System.Windows.MessageBox]::Show("The requirements for execution are not met. See log file for details.", "Self-Diagnostic Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit
}

if ($script:ClientMode) {
    Write-Log -Message "Running in client mode. AD actions are limited and sample data is used." -Level WARN
    if ($null -ne $btnDelete) {
        $btnDelete.IsEnabled = $false
        $btnDelete.ToolTip = "Disabled in client mode"
    }
}

# Initialize
Update-BitLockerKeyTable

# Search functionality enhancement
# Add key press event to search textbox before GUI is shown
if ($null -ne $txtSearch) {
    $txtSearch.Add_KeyDown({
        param($searchSender, $searchEventArgs)
        
        try {
            # If Enter key is pressed, trigger search
            if ($searchEventArgs.Key -eq 'Enter') {
                $btnSearch.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
            }
        }
        catch {
            Write-Log -Message "Error in search textbox key handler: $_" -Level ERROR
        }
    })
}

# Ensure DataGrid row style is correctly applied on initial load
if ($null -ne $dataGrid) {
    $dataGrid.Add_Loaded({
        try {
            Write-DebugMessage -Message "DataGrid loaded, applying row styling"
            if ($null -ne $dataGrid.ItemsSource) {
                Update-RowStyling -DataGrid $dataGrid
            }
        }
        catch {
            Write-Log -Message "Error applying row styling after DataGrid load: $_" -Level ERROR
        }
    })
}

# Event for cleanup when closing window
$window.Add_Closed({
    try {
        # Stop INI monitoring
        # if ($null -ne $global:IniWatcherEvent) {
        #     Unregister-Event -SourceIdentifier $global:IniWatcherEvent.Name
        # }
        Write-Log -Message "Application is shutting down" -Level INFO
    }
    catch {
        Write-Log -Message "Error shutting down application: $_" -Level ERROR
    }
})

# Display GUI
$window.Title = $APPName
Write-DebugMessage -Message "Starting GUI display"
[void]$window.ShowDialog()
#endregion

# SIG # Begin signature block
# MIIoiQYJKoZIhvcNAQcCoIIoejCCKHYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAw1LQou/0y7QYU
# DXzLRe3cG6ngWy3GJ2VMOLfFgyKIoqCCILswggXJMIIEsaADAgECAhAbtY8lKt8j
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
# BCB7G+fF6F2CusDGSs23aPLNcSAbifyglOBa8XexAWYNDzANBgkqhkiG9w0BAQEF
# AASCAgABOYN/JEgP+jBKlPidk91JGSferV4L+UlHay9eEpq/qmjtapTf+MSeP4wd
# jzX7deFFp7PXDjhqxaxAei7OlhxlIgTiisR/Y4Hwy02YQ9GKTZIAKlo9XR1xToH6
# eeELAHZEtp7+0C9EMCiKGPqBq2l7JZ+PL0HIdsKlDBHNVtvkYnx0/NwnBvD73g6B
# qxjUoTgKfEsZc6mBii+tjtpmOQYU3xO5XHpAbNkyKQCk2bd/9U0PwoxKy9N1mxIH
# 6v7RLboyfyfCm6Z9yKklPDxgNimJGU79D2TDU24+mNykWDkAhWxzdUX8Hew5yF11
# w4j/EnyE8zGBvrWDWuqAN+t3Lya9AE0+ZyYhmKRAkEFeCqexs1MUGxNL3j0WHKch
# VuwyBuH9uMZooxxfYUjjrvcrgvVCmwXxzNj2cWib3+kVaCJeoPIFGexUO0gGL9hW
# ZOksMkgtyX1ip58FX5rT7Mt+xkf8L1ROhxOLXfDSFTHkL/3ElPKaqQ2sz57U7B1Z
# WIVqn/W0SUMjO4XtoAeHAw2RSzuKyr4n1+AjXmuLW52rPkDi/6TYw3evH1Dy6zgA
# INSPtu2lqfwkY27mnq8Ut+24XhiH+ux3Ubj8LAdl11aqp1oAu1sbk5J/MnrvZi+K
# GKrg+j209CkGNLrcskGLlkcrbAVIS8impS6ymBlng5SvYn42m6GCBAQwggQABgkq
# hkiG9w0BCQYxggPxMIID7QIBATBrMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3Rh
# bXBpbmcgMjAyMSBDQQIRAJ6cBPZVqLSnAm1JjGx4jaowDQYJYIZIAWUDBAICBQCg
# ggFXMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcN
# MjUxMDI1MTc1NzU0WjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDPodw1ne0rw8uJ
# D6Iw5dr3e1QPGm4rI93PF1ThjPqg1TA/BgkqhkiG9w0BCQQxMgQw/efbJNVEI4cB
# HcrzHq2jeNamyizVp9zv3C94K6qAo2bGksadiCD7ex9997+hEFZOMIGgBgsqhkiG
# 9w0BCRACDDGBkDCBjTCBijCBhwQUwyW4mxf8xQJgYc4rcXtFB92camowbzBapFgw
# VjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhEAnpwE9lWo
# tKcCbUmMbHiNqjANBgkqhkiG9w0BAQEFAASCAgCtnuw7J7tRMNeBAjrE9W6BRhhZ
# aOhiD6SIvlYt0hRk4RqTypeId9nxcfc8He8YiwQo9WDzMhYXu8rABr7p4AYxVDsY
# 59dma50JhTkVfEr4Ij/okjyIm/1cGpufyD4UrZaPTQayK0frONa84rhSiXnmI+Ha
# qdYxp0mWNyEeazXRnB4LRVpAzHMVXD3r9RWcqHWrIrRKU/XamFv0RD4WcJEbFXl2
# y2KGRSGDk+MWFlCwVUiN+7F/nAuT8iQ2Gx/po/48D+fWneg+DwRwnVocoI+VaK/2
# 3VjGDpF9zdEBgoe4nOrwnN7WHXUXMfnach+zd8uWvaMiA3rvHD+LT64c/EETZdQH
# 5scw0oncheraUOmdkQB1K8ssm3JxvinEegSLz37R9uPY+KkevAjRXLCtd08p6JFG
# TEhOy8wq4xXkdDUpT52k2iRFyEH4rigL9ouWfEw87Jl/w/pUJbzJyAOGCZnlAKUb
# 10/hg1jcvBzlbo6yXcLOsARTLmEbk/e4yPwMVctW0vhy5NU/Z2cY2GxoyTBCEEVz
# yIjlXRY72ZuPwr9MQM5scmAHxo4DKeLOB1TJuLpjhJ8mVp8J2hRcTlVOcESkIi3d
# VsdvTHd5TbB6MLBc4gaABtPhCQ4tWHclIhmIa36GMa318dNcFQj/wh0AcoN26P9D
# Jx5AhwGD44zvOV7LWg==
# SIG # End signature block
