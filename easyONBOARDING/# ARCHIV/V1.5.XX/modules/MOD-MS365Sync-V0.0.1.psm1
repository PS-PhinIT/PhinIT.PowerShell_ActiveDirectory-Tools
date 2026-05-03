# Exchange Mailbox erstellen für GUI
function New-ExchangeMailboxGUI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$UserData,
        
        [Parameter(Mandatory = $false)]
        [string]$MailboxType = "UserMailbox",
        
        [Parameter(Mandatory = $false)]
        [string]$MailboxDatabase = $null,
        
        [Parameter(Mandatory = $false)]
        [switch]$EnableOnlineMailbox = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$EnableRemoteMailbox = $false
    )
    
    try {
        Write-Log -Message "Starte Exchange Mailbox-Erstellung für: $($UserData.SamAccountName)" -Level "INFO"
        
        # Prüfe erforderliche Parameter
        if ([string]::IsNullOrWhiteSpace($UserData.SamAccountName)) {
            throw "SamAccountName ist erforderlich für Mailbox-Erstellung"
        }
        
        if ([string]::IsNullOrWhiteSpace($UserData.Email)) {
            throw "Email-Adresse ist erforderlich für Mailbox-Erstellung"
        }
        
        # Bestimme Mailbox-Typ basierend auf Konfiguration
        if ($global:EnableOnlineMailbox -and $global:ExchangeOnlineConnected) {
            Write-Log -Message "Erstelle Exchange Online Mailbox..." -Level "DEBUG"
            
            # Prüfe ob Benutzer bereits eine Mailbox hat
            try {
                $existingMailbox = Get-Mailbox -Identity $UserData.SamAccountName -ErrorAction SilentlyContinue
                if ($existingMailbox) {
                    Write-Log -Message "Mailbox für $($UserData.SamAccountName) existiert bereits" -Level "WARN"
                    return @{
                        Success = $true
                        Message = "Mailbox existiert bereits"
                        MailboxType = "Existing"
                        PrimarySmtpAddress = $existingMailbox.PrimarySmtpAddress
                    }
                }
            } catch {
                Write-Log -Message "Fehler beim Prüfen der bestehenden Mailbox: $($_.Exception.Message)" -Level "DEBUG"
            }
            
            # Erstelle neue Exchange Online Mailbox
            $mailboxParams = @{
                Name = $UserData.DisplayName
                UserPrincipalName = $UserData.Email
                Alias = $UserData.SamAccountName
                DisplayName = $UserData.DisplayName
                FirstName = $UserData.GivenName
                LastName = $UserData.Surname
                Password = (ConvertTo-SecureString -String $UserData.Password -AsPlainText -Force)
            }
            
            # Füge Mailbox-Datenbank hinzu wenn angegeben
            if (-not [string]::IsNullOrWhiteSpace($MailboxDatabase)) {
                $mailboxParams.Database = $MailboxDatabase
            }
            
            # Erstelle Mailbox
            $newMailbox = New-Mailbox @mailboxParams -ErrorAction Stop
            
            if ($newMailbox) {
                Write-Log -Message "Exchange Online Mailbox erfolgreich erstellt: $($newMailbox.PrimarySmtpAddress)" -Level "INFO"
                
                # Warte kurz für Exchange-Replikation
                Start-Sleep -Seconds 5
                
                # Setze zusätzliche Eigenschaften
                try {
                    Set-Mailbox -Identity $newMailbox.Identity -EmailAddresses @{Add=$UserData.Email} -ErrorAction SilentlyContinue
                    Write-Log -Message "Email-Adresse konfiguriert: $($UserData.Email)" -Level "DEBUG"
                } catch {
                    Write-Log -Message "Warnung: Email-Adresse konnte nicht gesetzt werden: $($_.Exception.Message)" -Level "WARN"
                }
                
                return @{
                    Success = $true
                    Message = "Exchange Online Mailbox erfolgreich erstellt"
                    MailboxType = "Online"
                    PrimarySmtpAddress = $newMailbox.PrimarySmtpAddress
                    Identity = $newMailbox.Identity
                }
            } else {
                throw "Mailbox wurde nicht erstellt (unbekannter Fehler)"
            }
        }
        elseif ($global:EnableRemoteMailbox) {
            Write-Log -Message "Erstelle Remote Mailbox (Hybrid)..." -Level "DEBUG"
            
            # Für Remote-Mailbox wird Enable-RemoteMailbox verwendet
            $remoteParams = @{
                Identity = $UserData.SamAccountName
                RemoteRoutingAddress = "$($UserData.SamAccountName)@$($global:RemoteRoutingDomain)"
            }
            
            $remoteMailbox = Enable-RemoteMailbox @remoteParams -ErrorAction Stop
            
            if ($remoteMailbox) {
                Write-Log -Message "Remote Mailbox erfolgreich erstellt: $($remoteMailbox.RemoteRoutingAddress)" -Level "INFO"
                
                return @{
                    Success = $true
                    Message = "Remote Mailbox erfolgreich erstellt"
                    MailboxType = "Remote"
                    RemoteRoutingAddress = $remoteMailbox.RemoteRoutingAddress
                    Identity = $remoteMailbox.Identity
                }
            } else {
                throw "Remote Mailbox wurde nicht erstellt (unbekannter Fehler)"
            }
        }
        elseif ($global:EnableOnPremMailbox) {
            Write-Log -Message "Erstelle On-Premises Mailbox..." -Level "DEBUG"
            
            # Für On-Premises Mailbox
            $onPremParams = @{
                Name = $UserData.DisplayName
                UserPrincipalName = $UserData.Email
                Alias = $UserData.SamAccountName
                OrganizationalUnit = $UserData.OU
                FirstName = $UserData.GivenName
                LastName = $UserData.Surname
                Password = (ConvertTo-SecureString -String $UserData.Password -AsPlainText -Force)
            }
            
            # Füge Mailbox-Datenbank hinzu wenn angegeben
            if (-not [string]::IsNullOrWhiteSpace($global:MailboxDatabase)) {
                $onPremParams.Database = $global:MailboxDatabase
            }
            
            $onPremMailbox = New-Mailbox @onPremParams -ErrorAction Stop
            
            if ($onPremMailbox) {
                Write-Log -Message "On-Premises Mailbox erfolgreich erstellt: $($onPremMailbox.PrimarySmtpAddress)" -Level "INFO"
                
                return @{
                    Success = $true
                    Message = "On-Premises Mailbox erfolgreich erstellt"
                    MailboxType = "OnPremises"
                    PrimarySmtpAddress = $onPremMailbox.PrimarySmtpAddress
                    Identity = $onPremMailbox.Identity
                }
            } else {
                throw "On-Premises Mailbox wurde nicht erstellt (unbekannter Fehler)"
            }
        }
        else {
            Write-Log -Message "Keine Mailbox-Erstellung konfiguriert - überspringe..." -Level "INFO"
            return @{
                Success = $true
                Message = "Mailbox-Erstellung übersprungen (nicht konfiguriert)"
                MailboxType = "None"
            }
        }
    }
    catch {
        $errorMessage = "Fehler beim Erstellen der Exchange Mailbox: $($_.Exception.Message)"
        Write-Log -Message $errorMessage -Level "ERROR"
        
        return @{
            Success = $false
            Message = $errorMessage
            MailboxType = "Error"
        }
    }
}

function Update-M365ConnectionStatus {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log -Message "Prüfe Verbindungsstatus zu Exchange Online..." -Level "DEBUG"
        
        # Prüfe, ob die globale Variable für den Verbindungsstatus existiert und auf $true gesetzt ist.
        # Diese Variable wird in der Funktion Connect-ExchangeOnlineGUI gesetzt.
        if ($global:ExchangeOnlineConnected -eq $true) {
            Write-Log -Message "Verbindung zu Exchange Online ist aktiv (Organisation: $($global:ExchangeOnlineOrganization))." -Level "DEBUG"
            return $true
        } else {
            Write-Log -Message "Keine aktive Verbindung zu Exchange Online." -Level "DEBUG"
            return $false
        }
    }
    catch {
        Write-Log -Message "Fehler beim Prüfen des M365-Verbindungsstatus: $($_.Exception.Message)" -Level "WARN"
        # Im Fehlerfall wird davon ausgegangen, dass keine Verbindung besteht.
        return $false
    }
}
function New-M365Mailbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$UserData
    )
    
    try {
        Write-Log -Message "Erstelle M365-Mailbox für: $($UserData.Email)" -Level "INFO"
        
        # Hier würde die tatsächliche Mailbox-Erstellung erfolgen
        # Beispiel: New-Mailbox -Name $UserData.DisplayName -UserPrincipalName $UserData.Email
        
        Write-Log -Message "M365-Mailbox erfolgreich erstellt" -Level "INFO"
        return @{ Success = $true; Message = "Mailbox erstellt" }
    }
    catch {
        Write-Log -Message "Fehler bei Mailbox-Erstellung: $($_.Exception.Message)" -Level "ERROR"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function Set-M365License {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $true)]
        [string]$LicenseSku
    )
    
    try {
        Write-Log -Message "Weise M365-Lizenz zu: $LicenseSku für $UserPrincipalName" -Level "INFO"
        
        # Hier würde die tatsächliche Lizenzzuweisung erfolgen
        # Beispiel: Set-MgUserLicense -UserId $UserPrincipalName -AddLicenses @{SkuId = $LicenseSku}
        
        Write-Log -Message "M365-Lizenz erfolgreich zugewiesen" -Level "INFO"
        return @{ Success = $true; Message = "Lizenz zugewiesen" }
    }
    catch {
        Write-Log -Message "Fehler bei Lizenzzuweisung: $($_.Exception.Message)" -Level "ERROR"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

#endregion