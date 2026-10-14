#Requires -Version 5.1
# Author: ANDREAS HEPP | www.phinit.de
#
# easyBITKEYS reads all BitLocker recovery keys (msFVE-RecoveryInformation) from
# Active Directory and displays them in a color-coded WPF GUI.
# Status colors:
#   - No key available:            LightGray
#   - Key younger than 7 months:   LightGreen
#   - Key 7 to under 12 months:    Orange
#   - Key 12 months or older:      LightCoral
#
# Features: search, age filter, column sorting, CSV export, copy key to clipboard
# (clipboard is cleared automatically after a timeout) and removal of the selected
# AD entry (after confirmation, AD mode only).
#
# Version information is maintained in this script, README.md and CHANGELOG.md.
#
# NOTE: The application also runs in client mode without the AD module or without
# sufficient permissions, displaying sample data for demonstration purposes.
# ---------------------------------------------------------------------

#region Script Configuration
# Diese Konfigurationswerte sollten am Anfang des Skripts stehen.

# Allgemeine Skriptinformationen
$ScriptVersion   = "0.6.0"
$LastUpdate      = "2026-10-14" # Datum der letzten Aktualisierung
$Author          = "ANDREAS HEPP | www.phinit.de"
$APPName         = "easyBITKEYS"
$APPDescription  = "easyBITKEYS displays BitLocker keys from Active Directory in a color-coded manner."

# GUI-Konfiguration
$ThemeColor      = "#164360" # Hauptfarbe für Header/Footer (Hex-Code)
$FontFamily      = "Segoe UI" # Standard-Schriftart für die GUI
$FontSize        = [float]12   # Standard-Schriftgröße für die GUI
# GUI läuft vollständig ohne externe Assets (Logo/Icons/URLs)

# Debug-Modus (0 = Aus, 1 = An) - Stellen Sie sicher, dass die Write-DebugMessage Funktion existiert
$global:DebugMode = 0 # Standardmäßig deaktiviert
$script:Debug = $global:DebugMode # Debug-Modus für das Skript setzen
$script:ClientMode = $false
$script:LastLoadFailed = $false

# Sicherheit: Zwischenablage nach X Sekunden automatisch leeren (0 = deaktiviert)
$ClipboardClearSeconds = 30

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
# Ensure script runs in Windows PowerShell 5.1 (WPF/RSAT). PowerShell 7+ (Core) restarts in 5.1
# without elevation - reading BitLocker keys from AD does not require local admin rights.
if ($PSVersionTable.PSEdition -eq 'Core') {
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        Write-Host "Switching to Windows PowerShell 5.1..." -ForegroundColor Yellow
        Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    }
    else {
        Write-Host "Please start easyBITKEYS with Windows PowerShell 5.1 (powershell.exe)." -ForegroundColor Red
    }
    exit
}

# Self-Diagnostic at startup
function Test-Requirements {
    try {
        # Keine Asset-Prüfung notwendig: GUI verwendet keine externen Logo-/Icon-Dateien
        
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
    ResizeMode="CanResize"
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
                                            Text="Key 7 - 12 months" />
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
                                            Text="Key &gt;= 12 months" />
                                    </StackPanel>
                                    <StackPanel Margin="0,2" Orientation="Horizontal">
                                        <Rectangle
                                            Width="15"
                                            Height="15"
                                            Margin="0,0,8,0"
                                            VerticalAlignment="Center"
                                            Fill="LightGray" />
                                        <TextBlock
                                            VerticalAlignment="Center"
                                            FontSize="11"
                                            Foreground="#E0E0E0"
                                            Text="No key available" />
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
                            ToolTip="Information"
                            Content="i" />
                        <Button
                            x:Name="btnExit"
                            Style="{StaticResource SmallIconButton}"
                            ToolTip="Close Application"
                            Content="X" />
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
                                    <ComboBoxItem Content="Critical (&gt;= 12 months)" />
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
                        CanUserSortColumns="True"
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
                                SortMemberPath="DatumSort"
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
# Replace the known placeholders in the XAML string (XML-escaped, no dynamic code evaluation)
$xamlPlaceholders = [ordered]@{
    '$APPName'       = $APPName
    '$FontFamily'    = $FontFamily
    '$FontSize'      = $FontSize
    '$ScriptVersion' = $ScriptVersion
    '$LastUpdate'    = $LastUpdate
    '$Author'        = $Author
}
$expandedXaml = $xamlString
foreach ($placeholder in $xamlPlaceholders.Keys) {
    $escapedValue = [System.Security.SecurityElement]::Escape([System.Convert]::ToString($xamlPlaceholders[$placeholder], [System.Globalization.CultureInfo]::InvariantCulture))
    $expandedXaml = $expandedXaml.Replace($placeholder, $escapedValue)
}

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
$footerBorder = $window.FindName("footerBorder")
$versionText = $window.FindName("versionText")
$dataGrid = $window.FindName("dataGrid")
$btnRefresh = $window.FindName("btnRefresh")
$btnCopyKey = $window.FindName("btnCopyKey")
$btnExport = $window.FindName("btnExport")
$btnDelete = $window.FindName("btnDelete")
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

    if ($null -ne $btnInfo) {
        $btnInfo.Content = "i"
        $btnInfo.FontWeight = [System.Windows.FontWeights]::Bold
    }

    if ($null -ne $btnExit) {
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
# Keine externen URL-/Asset-Handler notwendig.
#endregion

#region ActiveDirectory Integration
# Run self-diagnostic BEFORE importing the AD module (decides between AD mode and client mode)
if (-not (Test-Requirements)) {
    [System.Windows.MessageBox]::Show("The requirements for execution are not met. See log file for details.", "Self-Diagnostic Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit
}

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
        
        $script:LastLoadFailed = $false
        $tableData = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
        $now = Get-Date
        
        $counter = 1
        foreach ($key in $bitLockerKeys) {
            # Extract the computer name from the DistinguishedName (parent object of the recovery info).
            # Split only on unescaped commas so that escaped characters in RDNs are handled correctly.
            $dnParts = [regex]::Split([string]$key.distinguishedName, '(?<!\\),')
            if ($dnParts.Length -ge 2) {
                $computerName = ($dnParts[1] -replace '^CN=', '') -replace '\\(.)', '$1'
            }
            else {
                $computerName = "Unknown"
            }
            
            # Extract BitLocker key and date
            $bitLockerKey = [string]$key.'msFVE-RecoveryPassword'
            $date = $key.whenCreated
            
            # Create object for table data
            $rowObj = [PSCustomObject]@{
                Nr = $counter
                ComputerName = $computerName
                BitLockerKey = $bitLockerKey
                Datum = if ($null -ne $date) { $date.ToString("dd.MM.yyyy") } else { "" }
                DatumSort = if ($null -ne $date) { [DateTime]$date } else { [DateTime]::MinValue }
                DistinguishedName = $key.distinguishedName  # Store for later delete operations
                RowBackground = $null  # Will be set shortly
            }
            
            # Background color based on date
            if ([string]::IsNullOrEmpty($bitLockerKey) -or $null -eq $date) {
                $rowObj.RowBackground = "#D3D3D3"  # LightGray
                Write-DebugMessage -Message "Empty key for $computerName, setting gray background"
            }
            else {
                $ageMonths = ($now - $date).Days / 30
                
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
        $script:LastLoadFailed = $true
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
        @{ Nr = 1; ComputerName = "ClientPC01"; BitLockerKey = "1234-5678-9012-3456"; DatumSort = (Get-Date).AddMonths(-2); RowBackground = "#90EE90" },
        @{ Nr = 2; ComputerName = "ClientPC02"; BitLockerKey = "2345-6789-0123-4567"; DatumSort = (Get-Date).AddMonths(-8); RowBackground = "#FFA500" },
        @{ Nr = 3; ComputerName = "ClientPC03"; BitLockerKey = "3456-7890-1234-5678"; DatumSort = (Get-Date).AddMonths(-13); RowBackground = "#F08080" },
        @{ Nr = 4; ComputerName = "ClientPC04"; BitLockerKey = ""; DatumSort = (Get-Date).AddMonths(-1); RowBackground = "#D3D3D3" }
    )
    
    foreach ($item in $sampleData) {
        $item.Datum = $item.DatumSort.ToString("dd.MM.yyyy")
        $rowObj = [PSCustomObject]$item
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

#region Clipboard Handling
# Copies a secret to the clipboard and clears it again after $ClipboardClearSeconds
# (only if the clipboard still contains the copied secret).
function Clear-ClipboardSecret {
    try {
        if (-not [string]::IsNullOrEmpty($script:ClipboardSecret) -and
            [System.Windows.Forms.Clipboard]::ContainsText() -and
            [System.Windows.Forms.Clipboard]::GetText() -eq $script:ClipboardSecret) {
            [System.Windows.Forms.Clipboard]::Clear()
            Write-Log -Message "Clipboard cleared automatically" -Level INFO
        }
    }
    catch {
        Write-Log -Message "Error clearing clipboard: $_" -Level WARN
    }
    finally {
        $script:ClipboardSecret = $null
        if ($null -ne $script:ClipboardTimer) { $script:ClipboardTimer.Stop() }
    }
}

function Set-ClipboardSecret {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text
    )

    [System.Windows.Forms.Clipboard]::SetText($Text)
    $script:ClipboardSecret = $Text

    if ($ClipboardClearSeconds -gt 0) {
        if ($null -eq $script:ClipboardTimer) {
            $script:ClipboardTimer = New-Object System.Windows.Threading.DispatcherTimer
            $script:ClipboardTimer.Add_Tick({ Clear-ClipboardSecret })
        }
        $script:ClipboardTimer.Stop()
        $script:ClipboardTimer.Interval = [TimeSpan]::FromSeconds($ClipboardClearSeconds)
        $script:ClipboardTimer.Start()
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
                
                # Export exactly the entries currently displayed (respects search/filter)
                $csvData = @($dataGrid.ItemsSource | Select-Object Nr, ComputerName, BitLockerKey, Datum)
                
                $csvData | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
                Write-Log -Message "CSV export to $filePath completed ($($csvData.Count) records)" -Level INFO
                [System.Windows.MessageBox]::Show("Export completed ($($csvData.Count) entries).`n`nNote: The file contains BitLocker recovery keys in plain text. Store it in a protected location only.", "Export", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
- Orange: Key 7 to under 12 months old
- Red: Key 12 months or older
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
            if (-not $script:LastLoadFailed) {
                [System.Windows.MessageBox]::Show("Data has been refreshed successfully.", "Refresh", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            }
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
            
            Set-ClipboardSecret -Text $key
            Write-Log -Message "BitLocker key for computer $($selectedItem.ComputerName) copied to clipboard" -Level INFO
            $clearHint = if ($ClipboardClearSeconds -gt 0) { "`n`nThe clipboard will be cleared automatically in $ClipboardClearSeconds seconds." } else { "" }
            [System.Windows.MessageBox]::Show("The BitLocker key has been copied to the clipboard.$clearHint", "Copied", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
            $searchPattern = "*$([System.Management.Automation.WildcardPattern]::Escape($searchText))*"
            Write-DebugMessage -Message "Searching for '$searchText' in field '$searchField'"
            
            # Create new filtered collection
            $filteredData = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
            
            foreach ($item in $global:originalData) {
                $match = $false
                
                switch ($searchField) {
                    "ComputerName" {
                        if ($item.ComputerName -like $searchPattern) { $match = $true }
                    }
                    "BitLockerKey" {
                        if ($item.BitLockerKey -like $searchPattern) { $match = $true }
                    }
                    "All Fields" {
                        if (
                            ($item.ComputerName -like $searchPattern) -or
                            ($item.BitLockerKey -like $searchPattern) -or
                            ($item.Datum -like $searchPattern)
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
                    # Use the stored DateTime value (no string parsing required)
                    $datum = if ($item.DatumSort -is [DateTime]) { $item.DatumSort } else { [DateTime]::MinValue }
                    
                    $ageInMonths = (New-TimeSpan -Start $datum -End (Get-Date)).Days / 30
                    
                    $match = $false
                    
                    switch ($filterOption) {
                        "Current (< 7 months)" {
                            if ($ageInMonths -lt 7) { $match = $true }
                        }
                        "Older (7-12 months)" {
                            if ($ageInMonths -ge 7 -and $ageInMonths -lt 12) { $match = $true }
                        }
                        "Critical (>= 12 months)" {
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
# Column sorting uses the built-in DataGrid sorting (ascending/descending toggle).
# The Date column sorts via the DateTime property "DatumSort" (SortMemberPath).
#endregion

#region Application Initialization and Cleanup
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
        # Do not leave a copied recovery key in the clipboard after closing the tool
        Clear-ClipboardSecret
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