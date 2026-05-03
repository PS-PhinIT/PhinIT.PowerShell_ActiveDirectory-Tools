#region Telephony Functions - Starface PBX
function Get-StarfaceAuthToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$Password
    )
    
    try {
        Write-Log -Message "Authentifiziere bei Starface-Server: $BaseUrl" -Level "DEBUG"
        
        # SSL-Zertifikat-Validierung konfigurieren
        $verifySSL = Get-ConfigValue -Section "Starface" -Key "VerifySSLCertificate" -DefaultValue $false
        if (-not $verifySSL) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
        
        # Login-Daten vorbereiten
        $loginData = @{
            username = $Username
            password = $Password
        } | ConvertTo-Json
        
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        # Login-API-Aufruf
        $loginUrl = Get-ConfigValue -Section "Starface" -Key "LoginURL" -DefaultValue "/rest/login"
        $fullLoginUrl = "$BaseUrl$loginUrl"
        
        $response = Invoke-RestMethod -Uri $fullLoginUrl -Method POST -Headers $headers -Body $loginData -TimeoutSec 30 -ErrorAction Stop
        
        if ($response.token) {
            Write-Log -Message "Starface-Authentifizierung erfolgreich" -Level "DEBUG"
            return @{
                Success = $true
                Token = $response.token
                Message = "Login erfolgreich"
            }
        } else {
            throw "Kein Token in der Antwort erhalten"
        }
        
    }
    catch {
        Write-Log -Message "Starface-Authentifizierung fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}

function Disconnect-StarfaceSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$Token
    )
    
    try {
        Write-Log -Message "Beende Starface-Session" -Level "DEBUG"
        
        $headers = @{
            "X-AUTH-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        $logoutUrl = Get-ConfigValue -Section "Starface" -Key "LogoutURL" -DefaultValue "/rest/logout"
        $fullLogoutUrl = "$BaseUrl$logoutUrl"
        
        Invoke-RestMethod -Uri $fullLogoutUrl -Method POST -Headers $headers -TimeoutSec 10 -ErrorAction SilentlyContinue
        Write-Log -Message "Starface-Session beendet" -Level "DEBUG"
        
    }
    catch {
        Write-Log -Message "Warnung beim Beenden der Starface-Session: $($_.Exception.Message)" -Level "WARN"
    }
}

function Invoke-StarfacePBXUserCreation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$UserData,
        
        [Parameter(Mandatory = $false)]
        [string]$Department = $null,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config
    )
    
    Write-Log -Message "Starte Starface PBX Benutzeranlage für: $($UserData.FirstName) $($UserData.LastName)" -Level "INFO"
    
    $token = $null
    try {
        # Prüfe ob Starface-Integration aktiviert ist
        $starfaceEnabled = Get-ConfigValue -Section "Starface" -Key "Enabled" -DefaultValue $false -Config $Config
        if (-not $starfaceEnabled) {
            Write-Log -Message "Starface-Integration ist deaktiviert" -Level "INFO"
            return @{
                Success = $true
                Message = "Starface-Integration übersprungen (deaktiviert)"
            }
        }
        
        # Lade Starface-Konfiguration
        $baseUrl = Get-ConfigValue -Section "Starface" -Key "BaseURL" -DefaultValue $null -Config $Config
        $username = Get-ConfigValue -Section "Starface" -Key "Username" -DefaultValue $null -Config $Config
        $password = Get-ConfigValue -Section "Starface" -Key "Password" -DefaultValue $null -Config $Config
        
        if ([string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password)) {
            throw "Starface-Konfiguration unvollständig. BaseURL, Username und Password sind erforderlich."
        }
        
        # Authentifizierung bei Starface
        $authResult = Get-StarfaceAuthToken -BaseUrl $baseUrl -Username $username -Password $password
        if (-not $authResult.Success) {
            throw "Starface-Authentifizierung fehlgeschlagen: $($authResult.Message)"
        }
        $token = $authResult.Token
        
        # Bestimme Department
        if ([string]::IsNullOrWhiteSpace($Department)) {
            $Department = $UserData.Department
        }
        
        # Hole verfügbare Rufnummern für das Department
        $availableExtensions = Get-StarfaceAvailableExtensions -Department $Department -Token $token -BaseUrl $baseUrl -Config $Config
        if ($availableExtensions.Count -eq 0) {
            throw "Keine verfügbaren Rufnummern für Department '$Department' gefunden"
        }
        
        Write-Log -Message "Verfügbare Rufnummern für Department '$Department': $($availableExtensions -join ', ')" -Level "INFO"
        
        # Wähle automatisch die erste verfügbare Rufnummer oder lasse Benutzer wählen
        $autoAssign = Get-ConfigValue -Section "Starface" -Key "AutoAssignExtension" -DefaultValue $true -Config $Config
        
        $selectedExtension = $null
        if ($autoAssign) {
            $selectedExtension = $availableExtensions[0]
            Write-Log -Message "Automatisch zugewiesene Rufnummer: $selectedExtension" -Level "INFO"
        } else {
            # Hier könnte eine GUI-Auswahl implementiert werden
            $selectedExtension = Show-ExtensionSelectionDialog -AvailableExtensions $availableExtensions -Department $Department
            if ([string]::IsNullOrWhiteSpace($selectedExtension)) {
                $selectedExtension = $availableExtensions[0]  # Fallback zur ersten Nummer
            }
            Write-Log -Message "Ausgewählte Rufnummer: $selectedExtension" -Level "INFO"
        }
        
        # Generiere Benutzername für Starface (kompatibel mit Starface-Anforderungen)
        $starfaceUsername = Generate-StarfaceUsername -FirstName $UserData.FirstName -LastName $UserData.LastName
        
        # Erstelle Benutzer in Starface
        $starfaceUser = @{
            login = $starfaceUsername
            firstname = $UserData.FirstName
            lastname = $UserData.LastName
            email = if ($UserData.EmailAddress) { $UserData.EmailAddress } else { "$starfaceUsername@$((Get-ConfigValue -Section 'General' -Key 'DomainName' -DefaultValue 'domain.local' -Config $Config))" }
            extension = $selectedExtension
            department = $Department
            language = Get-ConfigValue -Section "Starface" -Key "DefaultLanguage" -DefaultValue "de" -Config $Config
            enableVoicemail = Get-ConfigValue -Section "Starface" -Key "EnableVoicemail" -DefaultValue $true -Config $Config
            voicemailPassword = Get-ConfigValue -Section "Starface" -Key "DefaultVoicemailPassword" -DefaultValue "1234" -Config $Config
            isActive = $true
        }
        
        # API-Aufruf zur Benutzererstellung
        $createResult = New-StarfaceUser -UserData $starfaceUser -BaseUrl $baseUrl -Token $token
        
        if (-not $createResult.Success) {
            throw "Fehler beim Erstellen des Starface-Benutzers: $($createResult.Message)"
        }
        
        Write-Log -Message "Starface-Benutzer '$starfaceUsername' erfolgreich erstellt mit Rufnummer: $selectedExtension" -Level "INFO"
        
        # Synchronisation mit AD (falls aktiviert)
        $syncWithAD = Get-ConfigValue -Section "Starface" -Key "SyncWithAD" -DefaultValue $true -Config $Config
        if ($syncWithAD) {
            Write-Log -Message "Starte AD-Synchronisation für Starface..." -Level "INFO"
            $syncResult = Start-StarfaceADSync -BaseUrl $baseUrl -Token $token
            if ($syncResult.Success) {
                Write-Log -Message "AD-Synchronisation erfolgreich" -Level "INFO"
            } else {
                Write-Log -Message "AD-Synchronisation fehlgeschlagen: $($syncResult.Message)" -Level "WARN"
            }
        }
        
        return @{
            Success = $true
            Message = "Starface-Benutzer erfolgreich erstellt"
            Username = $starfaceUsername
            Extension = $selectedExtension
            StarfaceUserId = $createResult.UserId
        }
        
    }
    catch {
        $errorMessage = "Fehler bei der Starface PBX Benutzeranlage: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        return @{
            Success = $false
            Message = $errorMessage
        }
    }
    finally {
        # Session beenden
        if ($token) {
            Disconnect-StarfaceSession -BaseUrl $baseUrl -Token $token
        }
    }
}

function New-StarfaceUsername {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstName,
        
        [Parameter(Mandatory = $true)]
        [string]$LastName
    )
    
    # Normalisiere Namen (entferne Sonderzeichen, Umlaute ersetzen, kleinschreibung)
    $cleanFirstName = $FirstName.ToLower() -replace '[äöüß]', { 
        param($match)
        switch ($match.Value) {
            'ä' { 'ae' }
            'ö' { 'oe' }
            'ü' { 'ue' }
            'ß' { 'ss' }
            default { $match.Value }
        }
    } -replace '[^a-z0-9]', ''
    
    $cleanLastName = $LastName.ToLower() -replace '[äöüß]', { 
        param($match)
        switch ($match.Value) {
            'ä' { 'ae' }
            'ö' { 'oe' }
            'ü' { 'ue' }
            'ß' { 'ss' }
            default { $match.Value }
        }
    } -replace '[^a-z0-9]', ''
    
    $username = "$cleanFirstName.$cleanLastName"
    
    # Begrenze auf maximale Länge (Starface unterstützt bis zu 64 Zeichen)
    if ($username.Length -gt 60) {
        $username = $username.Substring(0, 60)
    }
    
    return $username
}

function Test-StarfaceConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$Password
    )
    
    try {
        Write-Log -Message "Teste Starface-Verbindung zu: $BaseUrl" -Level "DEBUG"
        
        # Versuche Authentifizierung
        $authResult = Get-StarfaceAuthToken -BaseUrl $BaseUrl -Username $Username -Password $Password
        if ($authResult.Success) {
            # Session wieder beenden
            Disconnect-StarfaceSession -BaseUrl $BaseUrl -Token $authResult.Token
            
            Write-Log -Message "Starface-Verbindung erfolgreich getestet" -Level "DEBUG"
            return @{
                Success = $true
                Message = "Verbindung erfolgreich"
            }
        } else {
            return $authResult
        }
        
    }
    catch {
        Write-Log -Message "Starface-Verbindungstest fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}

function Get-StarfaceAvailableExtensions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Department,
        
        [Parameter(Mandatory = $true)]
        [string]$Token,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $global:Config
    )
    
    try {
        Write-Log -Message "Hole verfügbare Rufnummern für Department: $Department" -Level "DEBUG"
        
        # Lade Department-Nummernkreise aus Konfiguration
        $departmentRanges = Get-ConfigValue -Section "Starface" -Key "DepartmentNumberRanges" -DefaultValue "" -Config $Config
        
        if ([string]::IsNullOrWhiteSpace($departmentRanges)) {
            throw "Keine Department-Nummernkreise in der Konfiguration definiert"
        }
        
        # Parse Department-Ranges (Format: "IT:1000-1099,Sales:2000-2099")
        $ranges = @{}
        foreach ($range in ($departmentRanges -split ',')) {
            if ($range -match '^([^:]+):(\d+)-(\d+)$') {
                $deptName = $matches[1].Trim()
                $startNum = [int]$matches[2]
                $endNum = [int]$matches[3]
                $ranges[$deptName] = @{ Start = $startNum; End = $endNum }
            }
        }
        
        if (-not $ranges.Contains($Department)) {
            # Fallback: Verwende den ersten verfügbaren Bereich
            if ($ranges.Count -gt 0) {
                $firstDept = $ranges.Keys | Select-Object -First 1
                Write-Log -Message "Department '$Department' nicht konfiguriert, verwende Bereich von '$firstDept'" -Level "WARN"
                $deptRange = $ranges[$firstDept]
            } else {
                throw "Kein Nummernkreis für Department '$Department' konfiguriert und keine Fallback-Bereiche verfügbar"
            }
        } else {
            $deptRange = $ranges[$Department]
        }
        
        Write-Log -Message "Nummernkreis für '$Department': $($deptRange.Start) - $($deptRange.End)" -Level "DEBUG"
        
        # Hole bereits verwendete Rufnummern von Starface
        $usedExtensions = Get-StarfaceUsedExtensions -Token $Token -BaseUrl $BaseUrl
        
        # Erstelle Liste verfügbarer Rufnummern
        $availableExtensions = @()
        for ($i = $deptRange.Start; $i -le $deptRange.End; $i++) {
            $extString = $i.ToString()
            if ($usedExtensions -notcontains $extString) {
                $availableExtensions += $extString
            }
        }
        
        Write-Log -Message "Verfügbare Rufnummern für '$Department': $($availableExtensions.Count) von $(($deptRange.End - $deptRange.Start) + 1)" -Level "INFO"
        
        return $availableExtensions
        
    }
    catch {
        Write-Log -Message "Fehler beim Abrufen verfügbarer Rufnummern: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-StarfaceUsedExtensions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl
    )
    
    try {
        Write-Log -Message "Hole verwendete Rufnummern von Starface" -Level "DEBUG"
        
        $headers = @{
            "X-AUTH-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        # API-Aufruf um alle Benutzer zu holen
        $usersUrl = Get-ConfigValue -Section "Starface" -Key "UsersURL" -DefaultValue "/rest/users"
        $fullUsersUrl = "$BaseUrl$usersUrl"
        
        $response = Invoke-RestMethod -Uri $fullUsersUrl -Method GET -Headers $headers -ErrorAction Stop
        
        # Extrahiere verwendete Rufnummern
        $usedExtensions = @()
        
        # Response kann ein Array oder ein Object mit users-Property sein
        $users = if ($response.users) { $response.users } elseif ($response -is [array]) { $response } else { @($response) }
        
        foreach ($user in $users) {
            if ($user.extension -and $user.extension -ne "" -and $null -ne $user.extension) {
                $usedExtensions += $user.extension.ToString()
            }
            # Prüfe auch alternative Felder
            if ($user.phoneNumber -and $user.phoneNumber -ne "" -and $null -ne $user.phoneNumber) {
                $usedExtensions += $user.phoneNumber.ToString()
            }
            if ($user.number -and $user.number -ne "" -and $null -ne $user.number) {
                $usedExtensions += $user.number.ToString()
            }
        }
        
        # Entferne Duplikate
        $usedExtensions = $usedExtensions | Sort-Object -Unique
        
        Write-Log -Message "Verwendete Rufnummern abgerufen: $($usedExtensions.Count)" -Level "DEBUG"
        return $usedExtensions
        
    }
    catch {
        Write-Log -Message "Fehler beim Abrufen verwendeter Rufnummern: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function New-StarfaceUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$UserData,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$Token
    )
    
    try {
        Write-Log -Message "Erstelle Starface-Benutzer: $($UserData.login)" -Level "INFO"
        
        $headers = @{
            "X-AUTH-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        # User-Daten für Starface API vorbereiten (basierend auf Starface REST API Dokumentation)
        $starfaceUserData = @{
            login = $UserData.login
            firstname = $UserData.firstname
            lastname = $UserData.lastname
            email = $UserData.email
            extension = $UserData.extension
            isActive = if ($null -ne $UserData.isActive) { $UserData.isActive } else { $true }
            language = $UserData.language
        }
        
        # Füge optionale Felder hinzu wenn verfügbar
        if ($UserData.department) {
            $starfaceUserData.department = $UserData.department
        }
        
        if ($UserData.enableVoicemail) {
            $starfaceUserData.voicemail = @{
                enabled = $UserData.enableVoicemail
                password = $UserData.voicemailPassword
            }
        }
        
        # JSON-Body erstellen
        $jsonBody = $starfaceUserData | ConvertTo-Json -Depth 3
        Write-Log -Message "Starface User JSON: $jsonBody" -Level "DEBUG"
        
        # API-Aufruf zur Benutzererstellung
        $createUrl = Get-ConfigValue -Section "Starface" -Key "UsersURL" -DefaultValue "/rest/users"
        $fullCreateUrl = "$BaseUrl$createUrl"
        
        $response = Invoke-RestMethod -Uri $fullCreateUrl -Method POST -Headers $headers -Body $jsonBody -ErrorAction Stop
        
        Write-Log -Message "Starface-Benutzer erfolgreich erstellt. Response: $($response | ConvertTo-Json -Compress)" -Level "INFO"
        
        # Extrahiere User-ID aus Response
        $userId = if ($response.id) { $response.id } elseif ($response.userId) { $response.userId } else { $UserData.login }
        
        return @{
            Success = $true
            Message = "Benutzer erfolgreich erstellt"
            UserId = $userId
            Response = $response
        }
        
    }
    catch {
        $errorDetails = if ($_.Exception.Response) {
            try {
                $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $errorBody = $streamReader.ReadToEnd()
                $streamReader.Close()
                "HTTP $($_.Exception.Response.StatusCode): $errorBody"
            } catch {
                $_.Exception.Message
            }
        } else {
            $_.Exception.Message
        }
        
        Write-Log -Message "Fehler beim Erstellen des Starface-Benutzers: $errorDetails" -Level "ERROR"
        
        return @{
            Success = $false
            Message = $errorDetails
        }
    }
}

function Start-StarfaceADSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$Token
    )
    
    try {
        Write-Log -Message "Starte Starface AD-Synchronisation" -Level "INFO"
        
        $headers = @{
            "X-AUTH-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        # API-Aufruf für AD-Sync (angepasst an Starface API)
        $syncUrl = "$BaseUrl/rest/sync/activedirectory/start"
        
        try {
            $response = Invoke-RestMethod -Uri $syncUrl -Method POST -Headers $headers -ErrorAction Stop
            Write-Log -Message "AD-Synchronisation erfolgreich gestartet" -Level "INFO"
            
            return @{
                Success = $true
                Message = "AD-Synchronisation gestartet"
                Response = $response
            }
        }
        catch {
            # Fallback: Versuche alternative Sync-Endpoints
            $alternativeUrls = @(
                "$BaseUrl/rest/ldap/sync",
                "$BaseUrl/rest/directory/sync",
                "$BaseUrl/rest/sync"
            )
            
            foreach ($altUrl in $alternativeUrls) {
                try {
                    Write-Log -Message "Versuche alternativen Sync-Endpoint: $altUrl" -Level "DEBUG"
                    $response = Invoke-RestMethod -Uri $altUrl -Method POST -Headers $headers -ErrorAction Stop
                    Write-Log -Message "AD-Synchronisation über alternativen Endpoint erfolgreich" -Level "INFO"
                    
                    return @{
                        Success = $true
                        Message = "AD-Synchronisation gestartet (alternativer Endpoint)"
                        Response = $response
                    }
                }
                catch {
                    # Nächsten Endpoint versuchen
                    continue
                }
            }
            
            # Wenn alle Endpoints fehlschlagen
            throw "Alle Sync-Endpoints fehlgeschlagen"
        }
        
    }
    catch {
        Write-Log -Message "Fehler bei der AD-Synchronisation: $($_.Exception.Message)" -Level "ERROR"
        
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}

function Show-ExtensionSelectionDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$AvailableExtensions,
        
        [Parameter(Mandatory = $true)]
        [string]$Department
    )
    
    try {
        # Einfache Konsolen-basierte Auswahl (kann später durch WPF-Dialog ersetzt werden)
        Write-Host "`nVerfügbare Rufnummern für Department '$Department':" -ForegroundColor Cyan
        for ($i = 0; $i -lt $AvailableExtensions.Count -and $i -lt 10; $i++) {
            Write-Host "  $($i + 1). $($AvailableExtensions[$i])"
        }
        
        if ($AvailableExtensions.Count -gt 10) {
            Write-Host "  ... und $($AvailableExtensions.Count - 10) weitere"
        }
        
        do {
            $selection = Read-Host "`nBitte wählen Sie eine Rufnummer (1-$([Math]::Min($AvailableExtensions.Count, 10))) oder drücken Sie Enter für die erste"
            
            if ([string]::IsNullOrWhiteSpace($selection)) {
                return $AvailableExtensions[0]
            }
            
            if ([int]::TryParse($selection, [ref]$null) -and [int]$selection -ge 1 -and [int]$selection -le [Math]::Min($AvailableExtensions.Count, 10)) {
                return $AvailableExtensions[[int]$selection - 1]
            }
            
            Write-Host "Ungültige Auswahl. Bitte versuchen Sie es erneut." -ForegroundColor Red
            
        } while ($true)
        
    }
    catch {
        Write-Log -Message "Fehler bei der Rufnummern-Auswahl: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-StarfaceExtensionInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Extension,
        
        [Parameter(Mandatory = $true)]
        [string]$Token,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl
    )
    
    try {
        $headers = @{
            "X-AUTH-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        # API-Aufruf um Rufnummer-Informationen zu holen
        $extensionUrl = "$BaseUrl/rest/extensions/$Extension"
        $extensionInfo = Invoke-RestMethod -Uri $extensionUrl -Method GET -Headers $headers -ErrorAction Stop
        
        return @{
            Success = $true
            ExtensionInfo = $extensionInfo
        }
        
    }
    catch {
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}

function Get-StarfaceUserGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl
    )
    
    try {
        $headers = @{
            "X-AUTH-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        $groupsUrl = Get-ConfigValue -Section "Starface" -Key "UserGroupsURL" -DefaultValue "/rest/usergroups"
        $fullGroupsUrl = "$BaseUrl$groupsUrl"
        
        $response = Invoke-RestMethod -Uri $fullGroupsUrl -Method GET -Headers $headers -ErrorAction Stop
        
        return @{
            Success = $true
            Groups = $response
        }
        
    }
    catch {
        Write-Log -Message "Fehler beim Abrufen der Starface-Benutzergruppen: $($_.Exception.Message)" -Level "ERROR"
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}
# Funktion zum Laden der erforderlichen .NET-Assemblies für die GUI
function Import-RequiredAssemblies {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Lade erforderliche .NET-Assemblies für die GUI..." -Level "DEBUG"
    try {
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Xml
        Add-Type -AssemblyName System.Drawing
        Add-Type -AssemblyName Microsoft.VisualBasic
        Write-Log -Message "GUI-Assemblies erfolgreich geladen."
        return $true
    }
    catch {
        Write-Log -Message "Fehler beim Laden der GUI-Assemblies: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

#region Microsoft 365 Functions
# Diese Funktionen sollten die tatsächliche M365-Integration handhaben

function Connect-ExchangeOnlineGUI {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log -Message "Starte Verbindung zu Exchange Online..." -Level "INFO"
        
        # Prüfe ob Exchange Online PowerShell Modul verfügbar ist
        if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
            Write-Log -Message "Exchange Online PowerShell Modul nicht installiert" -Level "ERROR"
            return @{
                Success = $false
                Message = "Exchange Online PowerShell Modul ist nicht installiert. Bitte installieren Sie es mit: Install-Module -Name ExchangeOnlineManagement"
            }
        }
        
        # Importiere das Exchange Online Modul
        Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
        Write-Log -Message "Exchange Online Modul erfolgreich importiert" -Level "DEBUG"
        
        # Hole Tenant-ID aus Konfiguration
        $tenantId = Get-ConfigValue -Section "Exchange" -Key "TenantId" -DefaultValue $null
        
        # Verbindungsparameter vorbereiten
        $connectParams = @{
            ShowProgress = $true
            ShowBanner = $false
        }
        
        # Füge Tenant-ID hinzu wenn konfiguriert
        if (-not [string]::IsNullOrWhiteSpace($tenantId)) {
            $connectParams.DomainName = $tenantId
            Write-Log -Message "Verwende Tenant-ID: $tenantId" -Level "DEBUG"
        }
        
        # Verbindung zu Exchange Online herstellen
        Connect-ExchangeOnline @connectParams -ErrorAction Stop
        
        # Teste die Verbindung durch Abrufen der Organisation
        $orgConfig = Get-OrganizationConfig -ErrorAction Stop
        if ($orgConfig) {
            Write-Log -Message "Erfolgreich mit Exchange Online verbunden: $($orgConfig.DisplayName)" -Level "INFO"
            
            # Speichere Verbindungsstatus global
            $global:ExchangeOnlineConnected = $true
            $global:ExchangeOnlineOrganization = $orgConfig.DisplayName
            $global:ExchangeOnlineConnectionTime = Get-Date
            
            return @{
                Success = $true
                Message = "Erfolgreich mit Exchange Online verbunden"
                Organization = $orgConfig.DisplayName
                ConnectionTime = $global:ExchangeOnlineConnectionTime
            }
        } else {
            throw "Verbindung hergestellt, aber Organisation konnte nicht abgerufen werden"
        }
    }
    catch {
        $errorMessage = "Fehler beim Verbinden mit Exchange Online: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        
        # Setze Verbindungsstatus auf false
        $global:ExchangeOnlineConnected = $false
        
        return @{
            Success = $false
            Message = $errorMessage
        }
    }
}

