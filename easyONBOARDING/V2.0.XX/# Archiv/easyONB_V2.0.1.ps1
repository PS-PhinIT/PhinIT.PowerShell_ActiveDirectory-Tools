#Requires -Version 5.1

<#
.SYNOPSIS
    easyONBOARDING - GUI-basiertes Tool zur Erstellung neuer Benutzer in Active Directory und Microsoft 365.
.DESCRIPTION
    Dieses Skript bietet eine grafische Benutzeroberfläche zur Vereinfachung und Standardisierung des Onboarding-Prozesses.
    Es führt durch verschiedene Schritte, von der Erfassung der Benutzerdaten bis zur Zuweisung von Lizenzen und Gruppen.
.AUTHOR
    Phin-IT
.VERSION
    2.0.1
.NOTES
    Stellen Sie sicher, dass die PowerShell-Ausführungsrichtlinie das Ausführen von Skripten erlaubt.
    Das Skript muss in einem Kontext mit den erforderlichen AD- und MS365-Berechtigungen ausgeführt werden.
#>

# --- KONFIGURATION ---
# Diese Werte können nach Bedarf angepasst werden

$Config = @{
    # Allgemeine Einstellungen
    Debug = $false                # Debug-Modus: $true für erweiterte Protokollierung, $false für Standardprotokollierung
    LogPath = "$PSScriptRoot\logs" # Pfad zum Logverzeichnis
    XamlPath = "$PSScriptRoot\assets\ONBGUI.XAML" # Pfad zur XAML-Datei
    
    # AD-Einstellungen
    Domain = @{
        Name = "company.local"    # Name der lokalen Domäne
        EmailDomain = "company.com" # E-Mail-Domäne
        DefaultOU = "OU=Users,DC=company,DC=local" # Standard-OU für neue Benutzer
        SearchBase = "DC=company,DC=local" # Suchbasis für AD-Abfragen
        DomainController = ""     # Spezifischer Domänencontroller (leer = automatisch)
    }

    # Standard-Werte für Benutzerkonten
    UserDefaults = @{
        PasswordNeverExpires = $false       # Passwort läuft niemals ab
        ChangePasswordAtLogon = $true       # Benutzer muss Passwort bei der ersten Anmeldung ändern
        PasswordLength = 12                 # Standardlänge für generierte Passwörter
        EnableAccount = $true               # Konto nach der Erstellung aktivieren
        ProfilePath = "\\fileserver\profiles\%username%" # Pfad zum Benutzerprofil
        HomeDriveLetter = "H"               # Laufwerksbuchstabe für das Home-Verzeichnis
        HomeDirectory = "\\fileserver\homes\%username%" # Pfad zum Home-Verzeichnis
        ScriptPath = "logon.vbs"            # Anmeldeskript
        AccountExpirationDays = 0           # 0 = kein Ablauf, sonst Anzahl der Tage bis zum Ablauf
    }

    # Passwort-Richtlinien
    PasswordPolicy = @{
        ComplexPassword = $true             # Komplexes Passwort erforderlich
        MinLength = 10                      # Minimale Passwortlänge
        UseSpecialChars = $true             # Sonderzeichen verwenden
        UseUpperCase = $true                # Großbuchstaben verwenden
        UseNumbers = $true                  # Zahlen verwenden
        ExcludeAmbiguousChars = $true       # Mehrdeutige Zeichen ausschließen (0,O,1,l,I usw.)
        GenerateRandomPassword = $true      # Zufälliges Passwort generieren
    }

    # Namensformat-Einstellungen
    NamingConvention = @{
        UserPrincipalNameFormat = "{firstname}.{lastname}@{domain}"  # Format für UPN
        SamAccountNameFormat = "{firstname}.{lastname}"              # Format für SAM-Account-Name
        DisplayNameFormat = "{firstname} {lastname}"                 # Format für Anzeigename
        EmailAddressFormat = "{firstname}.{lastname}@{emaildomain}"   # Format für E-Mail-Adresse
        FallbackSamFormat = "{firstinitial}{lastname}"               # Ausweichformat, wenn SAM bereits existiert
        MaxSamAccountLength = 20            # Maximale Länge für SAM-Account-Namen
    }

    # Gruppen-Mapping nach Abteilungen
    # Format: "Abteilung" = @("Gruppe1", "Gruppe2", ...)
    DepartmentGroups = @{
        "IT" = @(
            "Domain Users",
            "IT-Team",
            "VPN-Users",
            "RemoteDesktop-Users"
        )
        "Vertrieb" = @(
            "Domain Users",
            "Vertrieb",
            "VPN-Users",
            "CRM-Users"
        )
        "Marketing" = @(
            "Domain Users",
            "Marketing",
            "VPN-Users"
        )
        "Finanzen" = @(
            "Domain Users",
            "Finanzen",
            "Buchhaltung"
        )
        "Geschäftsführung" = @(
            "Domain Users",
            "VPN-Users",
            "Management"
        )
        "Personalwesen" = @(
            "Domain Users",
            "HR",
            "Payroll-Access"
        )
        "Produktion" = @(
            "Domain Users",
            "Produktion",
            "Schichtplan-Zugriff"
        )
    }

    # Position-zu-Gruppen-Mapping
    # Format: "Position" = @("Gruppe1", "Gruppe2", ...)
    PositionGroups = @{
        "Administrator" = @("IT-Admin", "Server-Admin")
        "Entwickler" = @("Developer", "Git-Access")
        "Support" = @("Help-Desk", "Remote-Support")
        "Teamleiter" = @("Team-Leaders", "Reports-Access")
        "Manager" = @("Management", "Budget-Access", "Reports-Access")
        "Sachbearbeiter" = @("Office-Standard", "Documents-Access")
        "Praktikant" = @("Trainees", "Limited-Access")
        "Geschäftsführer" = @("Executive", "All-Access", "Board-Documents")
    }

    # Standort-zu-Drucker-Mapping
    # Format: "Standort" = @("DruckerUNC1", "DruckerUNC2", ...)
    LocationPrinters = @{
        "Berlin" = @("\\printserver\BER-Floor1", "\\printserver\BER-Floor2")
        "München" = @("\\printserver\MUC-Office", "\\printserver\MUC-Color")
        "Hamburg" = @("\\printserver\HAM-Main", "\\printserver\HAM-Executive")
    }

    # Microsoft 365 Konfiguration
    M365 = @{
        AutoConnect = $true                 # Automatische Verbindung mit M365 herstellen
        DefaultLicense = "Microsoft 365 Business Standard" # Standardlizenz
        LicenseMapping = @{                 # Lizenz-Mapping nach Abteilung
            "IT" = "Microsoft 365 Business Premium"
            "Vertrieb" = "Microsoft 365 Business Standard"
            "Marketing" = "Microsoft 365 Business Standard"
            "Finanzen" = "Microsoft 365 Business Basic"
            "Geschäftsführung" = "Microsoft 365 Business Premium"
            "Personalwesen" = "Microsoft 365 Business Standard"
            "Produktion" = "Microsoft 365 Business Basic"
        }
        DefaultUsageLocation = "DE"         # Standardmäßiger Nutzungsstandort
        UseModernAuthentication = $true     # Moderne Authentifizierung verwenden
        EnableMFA = $true                   # Multi-Faktor-Authentifizierung aktivieren
        AutoCreateMailbox = $true           # Automatisch Exchange-Postfach erstellen
    }

    # Exchange/E-Mail-Einstellungen
    Exchange = @{
        CreateMailbox = $true               # Postfach erstellen
        MailboxDatabase = "MailboxDB01"     # Exchange-Datenbank
        MailboxPlan = "StandardPlan"        # Postfachplan
        MailboxQuota = 2048                 # Postfachgröße in MB
        EnableArchive = $false              # Archiv-Postfach aktivieren
        HideFromGAL = $false                # Aus globalem Adressbuch ausblenden
        AutomaticReplies = $false           # Automatische Antworten aktivieren
        ForwardingAddress = ""              # Weiterleitungsadresse (leer = keine Weiterleitung)
    }

    # Services und Applikationen
    Services = @{
        # ERP/CRM Systeme
        ErpCrm = @(
            @{ Name = "SAP"; Description = "SAP ERP System"; IsEnabled = $false },
            @{ Name = "Dynamics CRM"; Description = "Microsoft Dynamics CRM"; IsEnabled = $false },
            @{ Name = "DATEV"; Description = "DATEV Buchhaltungssoftware"; IsEnabled = $false },
            @{ Name = "Salesforce"; Description = "Salesforce CRM"; IsEnabled = $false },
            @{ Name = "Lexware"; Description = "Lexware Finanzsoftware"; IsEnabled = $false }
        )
        # Entwickler-Tools
        DevTools = @(
            @{ Name = "Visual Studio"; Description = "IDE für Entwickler"; IsEnabled = $false },
            @{ Name = "GitLab"; Description = "Git Repository Manager"; IsEnabled = $false },
            @{ Name = "Azure DevOps"; Description = "Microsoft Azure DevOps"; IsEnabled = $false },
            @{ Name = "JetBrains"; Description = "JetBrains Entwicklungsumgebungen"; IsEnabled = $false },
            @{ Name = "Docker"; Description = "Container-Plattform"; IsEnabled = $false },
            @{ Name = "Visual Studio Code"; Description = "Code Editor"; IsEnabled = $false }
        )
        # Weitere Systeme
        OtherSystems = @(
            @{ Name = "Intranet"; Description = "Unternehmens-Intranet"; IsEnabled = $true },
            @{ Name = "Zeiterfassung"; Description = "Zeiterfassungssystem"; IsEnabled = $true },
            @{ Name = "Ticketsystem"; Description = "Help-Desk Ticketsystem"; IsEnabled = $false },
            @{ Name = "Confluence"; Description = "Dokumentations-Wiki"; IsEnabled = $false },
            @{ Name = "Jira"; Description = "Aufgabenmanagement"; IsEnabled = $false },
            @{ Name = "SharePoint"; Description = "Dokumentenmanagementsystem"; IsEnabled = $true }
        )
    }

    # E-Mail-Konfiguration für Benachrichtigungen
    Email = @{
        SendWelcomeMail = $true             # Willkommens-E-Mail an neuen Benutzer senden
        NotifyManager = $true               # Manager über neuen Benutzer informieren
        NotifyIT = $true                    # IT-Abteilung informieren
        SMTPServer = "smtp.company.com"     # SMTP-Server für E-Mail-Versand
        SMTPPort = 587                      # SMTP-Port
        UseSSL = $true                      # SSL für SMTP verwenden
        Credentials = @{                    # Anmeldedaten für SMTP
            Username = "noreply@company.com"
            Password = "" # In produktiven Umgebungen besser SecureString verwenden!
        }
        FromAddress = "noreply@company.com" # Absender-Adresse
        ITNotificationAddress = "it@company.com" # IT-Benachrichtigungsadresse
        WelcomeMailSubject = "Willkommen bei Company"
        WelcomeMailTemplate = "$PSScriptRoot\templates\welcome_mail.html"
        ManagerNotificationTemplate = "$PSScriptRoot\templates\manager_notification.html"
        ITNotificationTemplate = "$PSScriptRoot\templates\it_notification.html"
    }

    # Genehmigungsworkflow
    Approval = @{
        RequireApproval = $false           # Genehmigungsprozess aktivieren
        ApprovalManagerEmail = ""          # E-Mail des Genehmigenden
        AutoApproveAfterHours = 48         # Automatische Genehmigung nach X Stunden
        SendReminders = $true              # Erinnerungen senden
        ReminderIntervalHours = 24         # Erinnerungsintervall in Stunden
    }

    # Dokumentations-Einstellungen
    Documentation = @{
        CreateDocumentation = $true         # Dokumentation erstellen
        OutputPath = "$PSScriptRoot\documentation" # Ausgabepfad für Dokumentationen
        Templates = @{
            PDF = "$PSScriptRoot\templates\documentation_template.docx"
            HTML = "$PSScriptRoot\templates\documentation_template.html"
        }
        IncludePasswordInDoc = $false       # Passwort in die Dokumentation aufnehmen
        CreateUserSheet = $true             # Benutzerblatt erstellen
        UserSheetTemplate = "$PSScriptRoot\templates\user_sheet.docx"
    }

    # Skript-Verhalten und Fehlerbehandlung
    Behavior = @{
        ContinueOnError = $false            # Bei Fehlern fortfahren
        MaxRetryAttempts = 3                # Maximale Anzahl von Wiederholungsversuchen
        RetryDelaySeconds = 5               # Verzögerung zwischen Wiederholungsversuchen
        AutoFindReplacements = $true        # Automatisch Ersatz für doppelte Namen finden
        ValidateDataBeforeProcessing = $true # Daten vor der Verarbeitung validieren
        UseVerboseLogging = $false          # Ausführliche Protokollierung
    }

    # Backup-Einstellungen
    Backup = @{
        BackupUserData = $false             # Benutzerdaten sichern
        BackupLocation = "\\backupserver\users" # Speicherort für Backups
        BackupRetentionDays = 30            # Aufbewahrungsdauer in Tagen
    }

    # Benutzerdefinierte Attribute
    CustomAttributes = @{
        # Format: "AttributName" = "StandardWert"
        "employeeType" = ""                 # Mitarbeitertyp (fest/befristet)
        "employeeID" = ""                   # Personalnummer
        "extensionAttribute1" = ""          # Kostenstelle
        "extensionAttribute2" = ""          # Projektzuordnung
        "extensionAttribute3" = ""          # Kfz-Kennzeichen
        "extensionAttribute4" = ""          # Raumnummer
        "extensionAttribute5" = ""          # Skill-Level
    }
}

# --- LOGGING-FUNKTION ---
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )
    
    # Skip DEBUG messages if debug mode is disabled
    if ($Level -eq "DEBUG" -and -not $Config.Debug) {
        return
    }
    
    # Ensure the log directory exists
    try {
        $logDirectory = $Config.LogPath
        if (-not (Test-Path -Path $logDirectory)) {
            New-Item -Path $logDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created log directory: $logDirectory"
        }
    }
    catch {
        Write-Error "Failed to create log directory '$logDirectory': $($_.Exception.Message)"
        return
    }
    
    # Use daily log files for better log management
    $logDate = Get-Date -Format 'yyyy-MM-dd'
    $LogFile = Join-Path -Path $logDirectory -ChildPath "easyONB_$logDate.log"
    
    # Format the log entry
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Add caller information for non-INFO messages if verbose logging is enabled
    if ($Config.Behavior.UseVerboseLogging -and $Level -ne "INFO") {
        $callStack = Get-PSCallStack | Select-Object -Skip 1 | Select-Object -First 1
        $caller = if ($callStack) { "$($callStack.Command) [$($callStack.ScriptLineNumber)]" } else { "Unknown" }
        $logEntry = "$logEntry [Called from: $caller]"
    }
    
    # Write to console with color coding based on level
    if (-not $NoConsole) {
        switch ($Level) {
            "INFO"  { Write-Host $logEntry -ForegroundColor White }
            "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "DEBUG" { Write-Host $logEntry -ForegroundColor Cyan }
        }
    }
    
    # Write to log file
    try {
        Add-Content -Path $LogFile -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to write to log file '$LogFile': $($_.Exception.Message)"
    }
    
    # Log rotation - check file size and archive if needed
    try {
        $logFileInfo = Get-Item $LogFile -ErrorAction SilentlyContinue
        $maxSizeMB = 10 # 10MB max file size
        if ($logFileInfo -and $logFileInfo.Length -gt ($maxSizeMB * 1MB)) {
            $archiveFile = Join-Path -Path $logDirectory -ChildPath "easyONB_$logDate`_$((Get-Date).ToString('HHmmss')).log"
            Rename-Item -Path $LogFile -NewName $archiveFile -Force
            Write-Verbose "Log file rotated to: $archiveFile"
        }
    }
    catch {
        Write-Error "Failed to check or rotate log file: $($_.Exception.Message)"
    }
}

# Funktion zum Laden der erforderlichen .NET-Assemblies für die GUI
function Load-RequiredAssemblies {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Lade erforderliche .NET-Assemblies für die GUI..."
    try {
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Xml
        Add-Type -AssemblyName System.Drawing
        Write-Log -Message "GUI-Assemblies erfolgreich geladen."
        return $true
    }
    catch {
        Write-Log -Message "Fehler beim Laden der GUI-Assemblies: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

Write-Log -Message "Skript 'easyONB_V2.0.1.ps1' gestartet."

function Initialize-TabControlGrids {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.Border]$Panel
    )
    
    try {
        # Suche nach TabControl innerhalb des Panels
        $tabControl = $Panel.FindName("tabErpCrm")?.Parent
        
        if ($null -ne $tabControl) {
            Write-Log -Message "Initialisiere DataGrids in TabControl" -Level "INFO"
            
            # DataGrid für ERP/CRM Tab initialisieren
            $dgErpCrm = $Window.FindName("dgErpCrm")
            if ($null -ne $dgErpCrm -and $dgErpCrm.Columns.Count -eq 0) {
                $dgErpCrm.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                    Header = "Name"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path="Name"})
                }))
                $dgErpCrm.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                    Header = "Beschreibung"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path="Description"})
                }))
                $dgErpCrm.Columns.Add((New-Object System.Windows.Controls.DataGridCheckBoxColumn -Property @{
                    Header = "Aktivieren"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path="IsEnabled"})
                }))
            }
            
            # DataGrid für DevTools Tab initialisieren
            $dgDevTools = $Window.FindName("dgDevTools")
            if ($null -ne $dgDevTools -and $dgDevTools.Columns.Count -eq 0) {
                $dgDevTools.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                    Header = "Name"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path="Name"})
                }))
                $dgDevTools.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                    Header = "Beschreibung"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path="Description"})
                }))
                $dgDevTools.Columns.Add((New-Object System.Windows.Controls.DataGridCheckBoxColumn -Property @{
                    Header = "Aktivieren"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path="IsEnabled"})
                }))
            }
            
            # DataGrid für OtherSystems Tab initialisieren
            $dgOtherSystems = $Window.FindName("dgOtherSystems")
            if ($null -ne $dgOtherSystems -and $dgOtherSystems.Columns.Count -eq 0) {
                $dgOtherSystems.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                    Header = "Name"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path="Name"})
                }))
                $dgOtherSystems.Columns.Add((New-Object System.Windows.Controls.DataGridTextColumn -Property @{
                    Header = "Beschreibung"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path="Description"})
                }))
                $dgOtherSystems.Columns.Add((New-Object System.Windows.Controls.DataGridCheckBoxColumn -Property @{
                    Header = "Aktivieren"; Binding = (New-Object System.Windows.Data.Binding -Property @{Path="IsEnabled"})
                }))
            }
        }
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung der TabControl DataGrids: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Initialize-GUI {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot,
        
        [Parameter(Mandatory = $false)]
        [string]$XamlFileName = "assets\ONBGUI.XAML"
    )

    Write-Log -Message "Lade XAML-GUI-Definition..."
    
    try {
        # Pfad zur XAML-Datei
        $xamlPath = Join-Path -Path $ScriptRoot -ChildPath $XamlFileName
        if (-not (Test-Path -Path $xamlPath)) {
            throw "Die XAML-Datei wurde nicht unter '$xamlPath' gefunden."
        }

        # XAML-Datei lesen und in ein WPF-Fensterobjekt umwandeln
        $inputStream = [System.IO.File]::OpenRead($xamlPath)
        $reader = [System.Windows.Markup.XamlReader]::Load($inputStream)
        $Window = [System.Windows.Window]$reader
        $inputStream.Close()

        Write-Log -Message "XAML-Datei erfolgreich geladen und geparst."
        return $Window
    }
    catch {
        $errorMessage = "Ein schwerwiegender Fehler ist bei der Initialisierung der GUI aufgetreten: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Initialisierungsfehler", "OK", "Error")
        exit 1
    }
}

# --- GUI-STEUERELEMENTE ABRUFEN ---
function Get-GuiControls {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )
    
    Write-Log -Message "Binde GUI-Steuerelemente an Variablen..."
    $global:Variables = @{}
    $controlsToLoad = @(
        "btnStep1", "btnStep2", "btnStep3", "btnStep4", "btnStep5", "btnStep6",
        "step1Panel", "step2Panel", "step3Panel", "step4Panel", "step5Panel", "step6Panel"
    )

    foreach ($controlName in $controlsToLoad) {
        $control = $Window.FindName($controlName)
        if ($control) {
            $global:Variables[$controlName] = $control
        }
        else {
            Write-Log -Message "Steuerelement '$controlName' konnte nicht in der XAML-Datei gefunden werden." -Level "WARN"
        }
    }

    # Sammlung aller Panels zur einfacheren Verwaltung
    $allPanels = @(
        $global:Variables["step1Panel"], $global:Variables["step2Panel"], $global:Variables["step3Panel"],
        $global:Variables["step4Panel"], $global:Variables["step5Panel"], $global:Variables["step6Panel"]
    )
    
    # Rückgabe der Panels-Sammlung
    return $allPanels
}

# --- EVENT-HANDLER FÜR DIE NAVIGATION ---

# Hilfsfunktion zum Wechseln der Tabs/Panels
function Switch-Tab {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.Border]$TargetPanel,
        
        [Parameter(Mandatory = $false)]
        [System.Windows.Controls.TabItem]$TabItem = $null
    )
    
    try {
        if ($null -eq $TargetPanel) {
            Write-Log -Message "Ziel-Panel zum Umschalten ist null." -Level "WARN"
            return
        }
        
        Write-Log -Message "Wechsle zu Tab: $($TargetPanel.Name)" -Level "INFO"
        
        # Alle Panels ausblenden
        foreach ($panel in $global:allPanels) {
            if ($null -ne $panel) {
                $panel.Visibility = 'Collapsed'
            }
        }
        
        # Nur das Ziel-Panel einblenden
        $TargetPanel.Visibility = 'Visible'
        
        # Initialisiere den aktuellen Tab
        Initialize-CurrentTab -Panel $TargetPanel
        
        # Falls ein TabItem übergeben wurde, zu diesem wechseln
        if ($null -ne $TabItem) {
            Write-Log -Message "Wechsle zu UnterTab: $($TabItem.Header)" -Level "INFO"
            $TabItem.IsSelected = $true
        }
    }
    catch {
        Write-Log -Message "Fehler beim Umschalten des Tabs: $($_.Exception.Message)" -Level "ERROR"
        Write-Log -Message "Stacktrace: $($_.Exception.StackTrace)" -Level "DEBUG"
    }
}

# Initialisierungsfunktion für Tab 1
function Initialize-Tab1 {
    param([System.Windows.Controls.Border]$Panel)
    
    try {
        Write-Log -Message "Initialisiere Tab 1 (Benutzerdaten)" -Level "INFO"
        # Hier Code für die Initialisierung von Tab 1
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Tab 1: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Initialisierungsfunktion für Tab 2
function Initialize-Tab2 {
    param([System.Windows.Controls.Border]$Panel)
    
    try {
        Write-Log -Message "Initialisiere Tab 2 (AD-Einstellungen)" -Level "INFO"
        # Hier Code für die Initialisierung von Tab 2
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Tab 2: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Initialisierungsfunktion für Tab 3
function Initialize-Tab3 {
    param([System.Windows.Controls.Border]$Panel)
    
    try {
        Write-Log -Message "Initialisiere Tab 3 (Exchange/M365)" -Level "INFO"
        # Hier Code für die Initialisierung von Tab 3
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Tab 3: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Initialisierungsfunktion für Tab 4
function Initialize-Tab4 {
    param([System.Windows.Controls.Border]$Panel)
    
    try {
        Write-Log -Message "Initialisiere Tab 4 (Gruppen)" -Level "INFO"
        # Hier Code für die Initialisierung von Tab 4
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Tab 4: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Initialisierungsfunktion für Tab 5
function Initialize-Tab5 {
    param([System.Windows.Controls.Border]$Panel)
    
    try {
        Write-Log -Message "Initialisiere Tab 5 (Systeme)" -Level "INFO"
        # Rufe die bestehende TabControl-Initialisierung auf
        Initialize-TabControlGrids -Panel $Panel
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Tab 5: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Initialisierungsfunktion für Tab 6
function Initialize-Tab6 {
    param([System.Windows.Controls.Border]$Panel)
    
    try {
        Write-Log -Message "Initialisiere Tab 6 (Zusammenfassung)" -Level "INFO"
        # Hier Code für die Initialisierung von Tab 6
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung von Tab 6: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Master-Funktion zur Initialisierung des aktuellen Tabs
function Initialize-CurrentTab {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.Border]$Panel
    )
    
    try {
        Write-Log -Message "Initialisiere Tab: $($Panel.Name)" -Level "INFO"
        
        # Anhand des Panel-Namens die passende Initialize-Funktion aufrufen
        switch ($Panel.Name) {
            "step1Panel" { Initialize-Tab1 -Panel $Panel }
            "step2Panel" { Initialize-Tab2 -Panel $Panel }
            "step3Panel" { Initialize-Tab3 -Panel $Panel }
            "step4Panel" { Initialize-Tab4 -Panel $Panel }
            "step5Panel" { Initialize-Tab5 -Panel $Panel }
            "step6Panel" { Initialize-Tab6 -Panel $Panel }
            default { Write-Log -Message "Kein bekanntes Panel zum Initialisieren: $($Panel.Name)" -Level "WARN" }
        }
    }
    catch {
        Write-Log -Message "Fehler bei der Initialisierung des Tabs: $($_.Exception.Message)" -Level "ERROR"
    }
}

Write-Log -Message "Event-Handler für die Navigation wurden registriert."


# Lade die benötigten Assemblies für die GUI
if (-not (Load-RequiredAssemblies)) {
    Write-Log -Message "Das Skript wird aufgrund von Fehlern beim Laden der Assemblies beendet." -Level "ERROR"
    exit 1
}

try {
    # Die GUI initialisieren
    $Window = Initialize-GUI -ScriptRoot $ScriptRoot
    if (-not $Window) {
        throw "GUI-Fenster konnte nicht initialisiert werden."
    }

    # Aufruf der Funktion nach der GUI-Initialisierung
    $global:allPanels = Get-GuiControls -Window $Window
    if (-not $global:allPanels) {
        throw "GUI-Steuerelemente konnten nicht korrekt gebunden werden."
    }

    # Event-Handler für die Navigations-Buttons hinzufügen
    for ($i = 1; $i -le 6; $i++) {
        $buttonName = "btnStep$i"
        $panelName = "step$i" + "Panel"
        
        if ($global:Variables.ContainsKey($buttonName) -and $global:Variables.ContainsKey($panelName)) {
            $global:Variables[$buttonName].add_Click({ 
                param($sender, $e)
                $step = [regex]::Match($sender.Name, '\d+').Value
                Switch-Tab -TargetPanel $global:Variables["step$($step)Panel"]
            })
        } else {
            Write-Log -Message "Button $buttonName oder Panel $panelName nicht gefunden." -Level "WARN"
        }
    }

    # Standard-Tab anzeigen (erster Tab)
    if ($global:Variables.ContainsKey("step1Panel")) {
        Switch-Tab -TargetPanel $global:Variables["step1Panel"]
    }

    # --- FENSTER ANZEIGEN ---
    Write-Log -Message "GUI wird gestartet. Warte auf Benutzereingaben."
    [void]$Window.ShowDialog()
}
catch {
    Write-Log -Message "Fehler beim Ausführen des Skripts: $($_.Exception.Message)" -Level "ERROR"
    [System.Windows.Forms.MessageBox]::Show("Ein Fehler ist aufgetreten: $($_.Exception.Message)", "Fehler", "OK", "Error")
}
finally {
    Write-Log -Message "Skript beendet."
}
