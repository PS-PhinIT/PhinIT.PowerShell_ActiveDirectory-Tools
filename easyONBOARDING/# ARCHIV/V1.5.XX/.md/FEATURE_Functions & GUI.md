# Diese Tabs werden nach und nach dem Script hinzugefügt

## Hauptfunktionen der jeweiligen Tabs

function Get-GuiControls {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )
    
    try {
        Write-Log -Message "Sammle GUI-Steuerelemente..." -Level "DEBUG"
        
        # Globale Variable für alle GUI-Elemente
        $global:Variables = @{}
        
        # Finde alle benannten Elemente
        $namedElements = @(
            # Navigation
            'btnStep1', 'btnStep2', 'btnStep3', 'btnStep4', 'btnStep5', 'btnStep6', 'btnStep7',
            'step1Panel', 'step2Panel', 'step3Panel', 'step4Panel', 'step4PanelCloudOnly', 'step4PanelHybrid', 'step5Panel', 'step6Panel', 'step7Panel',
            # Step 1 - Benutzerdaten
            'cmbTemplate', 'btnLoadTemplates',
            'txtFirstName', 'txtLastName', 'txtUsername', 'txtEmail',
            'cmbDepartment', 'txtPosition', 'txtManager', 'btnBrowseManager',
            'cmbOUPath', 'btnBrowseOU', 'pwdPassword', 'btnGeneratePassword',
            'validationPanel1', 'validationText1', 'btnValidateStep1', 'btnNextStep1',
            
            # Step 2 - Gruppen
            'txtGroupSearch', 'lstAvailableGroups', 'lstSelectedGroups',
            'btnAddGroup', 'btnAddAllGroups', 'btnRemoveGroup', 'btnRemoveAllGroups',
            'groupCountText', 'btnPrevStep2', 'btnCreateUser',
            
            # Step 3 - Erweiterte Einstellungen
            'userStatusText', 'txtPhone', 'txtMobile', 'txtOffice', 'txtLocation', 'txtDescription',
            'chkMustChangePassword', 'chkPasswordNeverExpires', 'chkCannotChangePassword', 'chkAccountDisabled',
            'btnPrevStep3', 'btnUpdateUser3', 'btnNextStep3',
            
            # Progress
            'mainProgressBar', 'progressText', 'infoText',
            
            # Header
            'stepIndicator1', 'stepIndicator2', 'stepIndicator6', 'stepIndicator7',
            'btnHelp', 'btnSettings'
        )
        
        foreach ($elementName in $namedElements) {
            $element = $Window.FindName($elementName)
            if ($element) {
                $global:Variables[$elementName] = $element
                Write-Log -Message "Element '$elementName' gefunden" -Level "DEBUG"
            } else {
                Write-Log -Message "Element '$elementName' nicht gefunden" -Level "WARN"
            }
        }
        
        Write-Log -Message "GUI-Steuerelemente erfolgreich gesammelt: $($global:Variables.Count) Elemente" -Level "INFO"
        return $global:Variables
        
    }
    catch {
        Write-Log -Message "Fehler beim Sammeln der GUI-Steuerelemente: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Switch-Tab {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.FrameworkElement]$TargetPanel
    )
    
    try {
        # Prüfe, ob TargetPanel nicht null ist
        if (-not $TargetPanel) {
            Write-Log -Message "FEHLER: TargetPanel ist null" -Level "ERROR"
            throw "TargetPanel Parameter ist null"
        }
        
        Write-Log -Message "Wechsle zu Tab: $($TargetPanel.Name)" -Level "DEBUG"
        
        # Verstecke alle Panels
        $panels = @('step1Panel', 'step2Panel', 'step3Panel', 'step4Panel', 'step4PanelCloudOnly', 'step4PanelHybrid', 'step5Panel', 'step6Panel', 'step7Panel')
        
        foreach ($panelName in $panels) {
            if ($global:Variables.ContainsKey($panelName)) {
                $global:Variables[$panelName].Visibility = "Collapsed"
            }
        }
        
        # Zeige das Ziel-Panel
        $TargetPanel.Visibility = "Visible"
        
        # Aktualisiere Navigation
        $stepNumber = [regex]::Match($TargetPanel.Name, '\d+').Value
        if ($stepNumber) {
            Update-NavigationIndicators -CurrentStep ([int]$stepNumber)
        }
        
        Write-Log -Message "Tab-Wechsel erfolgreich" -Level "DEBUG"
        
    }
    catch {
        Write-Log -Message "Fehler beim Tab-Wechsel: $($_.Exception.Message)" -Level "ERROR"
    }
}


# Master-Funktion zur Initialisierung des aktuellen Tabs
function Initialize-CurrentTab {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.Border]$Panel
    )
    
    try {
        Write-Log -Message "Initialisiere Tab für Panel: $($Panel.Name)" -Level "DEBUG"
        
        # Anhand des Panel-Namens die passende Initialize-Funktion aufrufen
        switch ($Panel.Name) {
            "step1Panel" { Initialize-Tab1 -Panel $Panel }
            "step2Panel" { Initialize-Tab2 -Panel $Panel }
            "step3Panel" { Initialize-Tab3 -Panel $Panel }
            "step7Panel" { Initialize-Tab7 -Panel $Panel }
            default { Write-Log -Message "Kein bekanntes Panel zum Initialisieren: $($Panel.Name)" -Level "WARN" }
        }
    }

            # "step4PanelCloudOnly" { Initialize-Tab4CloudOnly -Panel $Panel }    
            # "step4PanelHybrid" { Initialize-Tab4Hybrid -Panel $Panel }
            # "step5Panel" { Initialize-Tab5 -Panel $Panel }
            # "step6Panel" { Initialize-Tab6 -Panel $Panel }

    catch {
        Write-Log -Message "Fehler bei der Initialisierung des Tabs: $($_.Exception.Message)" -Level "ERROR"
    }
}

## Initialisierungs Funktionen für die Tabs

        # Initialisierungsfunktion für Tab 4, die je nach Modus verzweigt
        function Initialize-Tab4 {
            param([System.Windows.Controls.Border]$Panel)
            
            try {
                Write-Log -Message "Initialisiere Tab 4 (M365 / Hybrid)" -Level "DEBUG"
                
                # Bestimme den Modus aus der Konfiguration. Annahme: [General] CloudOnly = true/false
                $isCloudOnly = Get-ConfigValue -Section "General" -Key "CloudOnly" -DefaultValue $false
                
                $panelCloudOnly = $Window.FindName("step4PanelCloudOnly")
                $panelHybrid = $Window.FindName("step4PanelHybrid")

                if ($isCloudOnly) {
                    Write-Log -Message "Cloud-Only-Modus aktiv. Initialisiere Cloud-Only-Panel." -Level "INFO"
                    $panelCloudOnly.Visibility = 'Visible'
                    $panelHybrid.Visibility = 'Collapsed'
                    Initialize-Tab4CloudOnly -Panel $panelCloudOnly
                } else {
                    Write-Log -Message "Hybrid-Modus aktiv. Initialisiere Hybrid-Panel." -Level "INFO"
                    $panelHybrid.Visibility = 'Visible'
                    $panelCloudOnly.Visibility = 'Collapsed'
                    Initialize-Tab4Hybrid -Panel $panelHybrid
                }
            }
            catch {
                Write-Log -Message "Fehler bei der Initialisierung von Tab 4: $($_.Exception.Message)" -Level "ERROR"
            }
        }

        # Initialisierungsfunktion für den Cloud-Only-Tab
        function Initialize-Tab4CloudOnly {
            param([System.Windows.Controls.Border]$Panel)
            
            try {
                Write-Log -Message "Initialisiere Tab 4 (Cloud-Only)" -Level "DEBUG"
                
                # M365 Steuerelemente initialisieren
                $chkEnableO365 = $Window.FindName("chkEnableO365")
                $cmbO365License = $Window.FindName("cmbO365License")
                $cmbUsageLocation = $Window.FindName("cmbUsageLocation")
                $chkCreateMailbox = $Window.FindName("chkCreateMailbox")
                $chkForwardingAddress = $Window.FindName("chkForwardingAddress")
                $txtForwardingAddress = $Window.FindName("txtForwardingAddress")
                $btnPrevStep4 = $Window.FindName("btnPrevStep4")
                $btnUpdateUser4 = $Window.FindName("btnUpdateUser4")
                $btnNextStep4 = $Window.FindName("btnNextStep4")

                # Lade verfügbare Lizenzen (Beispielfunktion)
                if ($cmbO365License -and $cmbO365License.Items.Count -eq 0) {
                    # Hier sollten die Lizenzen aus der M365-Umgebung geladen werden
                    $cmbO365License.ItemsSource = @(
                        "Microsoft 365 Business Basic", "Microsoft 365 Business Standard",
                        "Microsoft 365 Business Premium", "Office 365 E3", "Office 365 E5"
                    )
                }

                # Lade Nutzungsstandorte (Beispielfunktion)
                if ($cmbUsageLocation -and $cmbUsageLocation.Items.Count -eq 0) {
                    # Hier sollten die Standorte aus der M365-Umgebung geladen werden
                    $cmbUsageLocation.DisplayMemberPath = "Value"
                    $cmbUsageLocation.SelectedValuePath = "Key"
                    $cmbUsageLocation.ItemsSource = @(
                        [PSCustomObject]@{ Key = "DE"; Value = "DE - Deutschland" },
                        [PSCustomObject]@{ Key = "AT"; Value = "AT - Österreich" },
                        [PSCustomObject]@{ Key = "CH"; Value = "CH - Schweiz" }
                    )
                    $cmbUsageLocation.SelectedValue = "DE"
                }

                # Event-Handler für Navigationsbuttons
                if ($btnPrevStep4) {
                    $btnPrevStep4.add_Click({ Switch-Tab -TargetPanel $global:Variables["step3Panel"] })
                }
                if ($btnNextStep4) {
                    $btnNextStep4.add_Click({ Switch-Tab -TargetPanel $global:Variables["step5Panel"] })
                }
                if ($btnUpdateUser4) {
                    $btnUpdateUser4.add_Click({
                        Write-Log -Message "M365-Einstellungen werden aktualisiert..." -Level "INFO"
                        [System.Windows.MessageBox]::Show("M365-Einstellungen für den Benutzer werden aktualisiert.", "M365 Update", "OK", "Information")
                    })
                }
                
                Write-Log -Message "Tab 4 (Cloud-Only) erfolgreich initialisiert." -Level "DEBUG"
            }
            catch {
                Write-Log -Message "Fehler bei der Initialisierung von Tab 4 (Cloud-Only): $($_.Exception.Message)" -Level "ERROR"
            }
        }

        # Initialisierungsfunktion für den Hybrid-Tab (AD Sync)
        function Initialize-Tab4Hybrid {
            param([System.Windows.Controls.Border]$Panel)
            
            try {
                Write-Log -Message "Initialisiere Tab 4 (Hybrid - AD Sync)" -Level "DEBUG"
                
                # Hybrid-Steuerelemente initialisieren
                $btnStartADSync = $Window.FindName("btnStartADSync")
                $txtADSyncStatus = $Window.FindName("txtADSyncStatus")
                $btnPrevStep4Hybrid = $Window.FindName("btnPrevStep4Hybrid")
                $btnNextStep4Hybrid = $Window.FindName("btnNextStep4Hybrid")

                # Event-Handler für AD-Sync-Button
                if ($btnStartADSync) {
                    $btnStartADSync.add_Click({
                        try {
                            $txtADSyncStatus.Text = "Starte AD-Synchronisation...`n"
                            $syncResult = Start-ADSyncOnRemoteServer
                            
                            if ($syncResult.Success) {
                                $txtADSyncStatus.AppendText("Synchronisation erfolgreich gestartet.`n")
                                $txtADSyncStatus.AppendText("Typ: $($syncResult.SyncType)`n")
                                $txtADSyncStatus.AppendText("Zeitstempel: $($syncResult.Timestamp)`n")
                                Write-Log -Message "AD-Sync erfolgreich gestartet." -Level "INFO"
                            } else {
                                $txtADSyncStatus.AppendText("FEHLER: $($syncResult.Message)`n")
                                Write-Log -Message "Fehler beim Starten des AD-Sync: $($syncResult.Message)" -Level "ERROR"
                            }
                        } catch {
                            $errorMessage = "Fehler bei der Ausführung des AD-Sync: $($_.Exception.Message)"
                            $txtADSyncStatus.AppendText("FATALER FEHLER: $errorMessage`n")
                            Write-Log -Message $errorMessage -Level "ERROR"
                        }
                    })
                }

                # Event-Handler für Navigationsbuttons
                if ($btnPrevStep4Hybrid) {
                    $btnPrevStep4Hybrid.add_Click({ Switch-Tab -TargetPanel $global:Variables["step3Panel"] })
                }
                if ($btnNextStep4Hybrid) {
                    $btnNextStep4Hybrid.add_Click({ Switch-Tab -TargetPanel $global:Variables["step5Panel"] })
                }
                
                Write-Log -Message "Tab 4 (Hybrid - AD Sync) erfolgreich initialisiert." -Level "DEBUG"
            }
            catch {
                Write-Log -Message "Fehler bei der Initialisierung von Tab 4 (Hybrid): $($_.Exception.Message)" -Level "ERROR"
            }
        }
        function Initialize-Tab5 {
            param([System.Windows.Controls.Border]$Panel)
            
            try {
                Write-Log -Message "Initialisiere Tab 5 (Services & Applikationen)" -Level "DEBUG"
                
                # Steuerelemente für Tab 5 holen
                $btnLoadErpCrm = $Window.FindName("btnLoadErpCrm")
                $dgErpCrm = $Window.FindName("dgErpCrm")
                $btnLoadDevTools = $Window.FindName("btnLoadDevTools")
                $dgDevTools = $Window.FindName("dgDevTools")
                $btnLoadOtherSystems = $Window.FindName("btnLoadOtherSystems")
                $dgOtherSystems = $Window.FindName("dgOtherSystems")
                $btnPrevStep5 = $Window.FindName("btnPrevStep5")
                $btnUpdateUser5 = $Window.FindName("btnUpdateUser5")
                $btnNextStep5 = $Window.FindName("btnNextStep5")

                # DataGrids initialisieren (Spalten hinzufügen)
                Initialize-TabControlGrids -Panel $Panel

                # Event-Handler für Lade-Buttons
                if ($btnLoadErpCrm) {
                    $btnLoadErpCrm.add_Click({
                        # Hier Logik zum Laden von ERP/CRM-Systemen aus einer Konfigurationsdatei oder API
                        Write-Log -Message "Lade ERP/CRM-Systeme..." -Level "INFO"
                        $dgErpCrm.ItemsSource = @(
                            [pscustomobject]@{ Name = "SAP S/4HANA"; Description = "ERP-System"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Microsoft Dynamics 365"; Description = "ERP-System"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "HubSpot"; Description = "CRM-System"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "CAS GenesisWorld"; Description = "CRM-System"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Salesforce"; Description = "CRM-System"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Zoho CRM"; Description = "CRM-System"; IsEnabled = $false }
                        )
                    })
                }

                if ($btnLoadDevTools) {
                    $btnLoadDevTools.add_Click({
                        # Hier Logik zum Laden von Entwickler-Tools
                        Write-Log -Message "Lade Entwickler-Tools..." -Level "INFO"
                        $dgDevTools.ItemsSource = @(
                            [pscustomobject]@{ Name = "Asana"; Description = "Projektmanagement"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Jira"; Description = "Projektmanagement"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Confluence"; Description = "Dokumentation"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Slack"; Description = "Kommunikation"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Trello"; Description = "Aufgabenverwaltung"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Asana"; Description = "Projektmanagement"; IsEnabled = $false },                    
                            [pscustomobject]@{ Name = "GitLab"; Description = "Versionskontrolle"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "GitHub"; Description = "Versionskontrolle"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Bitbucket"; Description = "Versionskontrolle"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Visual Studio Code"; Description = "Code-Editor"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "IntelliJ IDEA"; Description = "Code-Editor"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Eclipse"; Description = "Code-Editor"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "NetBeans"; Description = "Code-Editor"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Postman"; Description = "API-Testing"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Docker"; Description = "Containerisierung"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Kubernetes"; Description = "Container-Orchestrierung"; IsEnabled = $false }
                        )
                    })
                }

                if ($btnLoadOtherSystems) {
                    $btnLoadOtherSystems.add_Click({                
                        # Hier Logik zum Laden weiterer Systeme
                        Write-Log -Message "Lade weitere Systeme..." -Level "INFO"
                        $dgOtherSystems.ItemsSource = @(
                            [pscustomobject]@{ Name = "Adobe Creative Cloud"; Description = "Grafik-Software"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Figma"; Description = "Grafik-UX-Design"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Canva"; Description = "Grafik-Design-Tool"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Microsoft Office"; Description = "Office-Suite"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "LibreOffice"; Description = "Open-Source Office-Suite"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "GIMP"; Description = "Bildbearbeitung"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Inkscape"; Description = "Vektorgrafik-Editor"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Blender"; Description = "3D-Modellierung"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "AutoCAD"; Description = "CAD-Software"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "MATLAB"; Description = "Mathematische Software"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "OTRS"; Description = "Ticket-System"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Zendesk"; Description = "Support-Ticket-System"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Freshdesk"; Description = "Support-Ticket-System"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Zoom"; Description = "Videokonferenz"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Microsoft Teams"; Description = "Kommunikation"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Webex"; Description = "Kommunikation"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Google Workspace"; Description = "Produktivitäts-Suite"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Dropbox"; Description = "Cloud-Speicher"; IsEnabled = $false },
                            [pscustomobject]@{ Name = "Box"; Description = "Cloud-Speicher"; IsEnabled = $false }                )
                    })
                }

                # Event-Handler für Navigationsbuttons
                if ($btnPrevStep5) {
                    $btnPrevStep5.add_Click({ Switch-Tab -TargetPanel $global:Variables["step4Panel"] })
                }
                if ($btnNextStep5) {
                    $btnNextStep5.add_Click({ Switch-Tab -TargetPanel $global:Variables["step6Panel"] })
                }
                if ($btnUpdateUser5) {
                    $btnUpdateUser5.add_Click({
                        # Hier die Logik zum Konfigurieren der Services für den Benutzer einfügen
                        Write-Log -Message "Services & Applikationen werden konfiguriert..." -Level "INFO"
                        [System.Windows.MessageBox]::Show("Die ausgewählten Services und Applikationen werden für den Benutzer konfiguriert.", "Service Konfiguration", "OK", "Information")
                    })
                }

                Write-Log -Message "Tab 5 (Services & Applikationen) erfolgreich initialisiert." -Level "DEBUG"
            }
            catch {
                Write-Log -Message "Fehler bei der Initialisierung von Tab 5: $($_.Exception.Message)" -Level "ERROR"
            }
        }
        # Initialisierungsfunktion für Tab 6
        function Initialize-Tab6 {
            param([System.Windows.Controls.Border]$Panel)
            
            try {
                Write-Log -Message "Initialisiere Tab 6 (Weitere Services)" -Level "DEBUG"
                
                # Steuerelemente für Tab 6 holen
                $chkEnableTelephony = $Window.FindName("chkEnableTelephony")
                $cmbTelephonySystem = $Window.FindName("cmbTelephonySystem")
                $btnTestTelephonyConnection = $Window.FindName("btnTestTelephonyConnection")
                $txtExtensionNumber = $Window.FindName("txtExtensionNumber")
                $btnSuggestExtension = $Window.FindName("btnSuggestExtension")
                $txtVoicemailPin = $Window.FindName("txtVoicemailPin")
                $btnGeneratePin = $Window.FindName("btnGeneratePin")
                
                $chkEnableVpn = $Window.FindName("chkEnableVpn")
                $chkOrderMobileDevice = $Window.FindName("chkOrderMobileDevice")
                $chkEnableFleetManagement = $Window.FindName("chkEnableFleetManagement")

                $btnPrevStep6 = $Window.FindName("btnPrevStep6")
                $btnUpdateUser6 = $Window.FindName("btnUpdateUser6")
                $btnNextStep6 = $Window.FindName("btnNextStep6")

                # Event-Handler für Navigationsbuttons
                if ($btnPrevStep6) {
                    $btnPrevStep6.add_Click({ Switch-Tab -TargetPanel $global:Variables["step5Panel"] })
                }
                if ($btnNextStep6) {
                    $btnNextStep6.add_Click({ Switch-Tab -TargetPanel $global:Variables["step7Panel"] })
                }
                if ($btnUpdateUser6) {
                    $btnUpdateUser6.add_Click({
                        # Hier die Logik zum Konfigurieren der weiteren Services für den Benutzer einfügen
                        Write-Log -Message "Weitere Services werden konfiguriert..." -Level "INFO"
                        [System.Windows.MessageBox]::Show("Die ausgewählten weiteren Services werden für den Benutzer konfiguriert.", "Service Konfiguration", "OK", "Information")
                    })
                }

                # Event-Handler für Telefonie
                if ($btnTestTelephonyConnection) {
                    $btnTestTelephonyConnection.add_Click({
                        # Logik zum Testen der Verbindung zum ausgewählten Telefonie-System
                        $system = $cmbTelephonySystem.SelectedItem.Content
                        Write-Log -Message "Teste Verbindung zu Telefonie-System: $system" -Level "INFO"
                        [System.Windows.MessageBox]::Show("Verbindungstest für '$system' wird durchgeführt...", "Verbindungstest", "OK", "Information")
                    })
                }

                if ($btnSuggestExtension) {
                    $btnSuggestExtension.add_Click({
                        # Logik zum Vorschlagen einer freien Rufnummer
                        Write-Log -Message "Schlage Rufnummer vor..." -Level "INFO"
                        # Beispiel: $txtExtensionNumber.Text = Get-StarfaceAvailableExtensions -Department "IT" | Select-Object -First 1
                        [System.Windows.MessageBox]::Show("Eine freie Rufnummer wird vorgeschlagen.", "Rufnummer", "OK", "Information")
                    })
                }

                if ($btnGeneratePin) {
                    $btnGeneratePin.add_Click({
                        # Logik zum Generieren einer PIN
                        $pin = -join ((1..4) | ForEach-Object { Get-Random -Minimum 0 -Maximum 9 })
                        $txtVoicemailPin.Text = $pin
                        Write-Log -Message "Voicemail-PIN generiert: $pin" -Level "INFO"
                    })
                }

                Write-Log -Message "Tab 6 (Weitere Services) erfolgreich initialisiert." -Level "DEBUG"
            }
            catch {
                Write-Log -Message "Fehler bei der Initialisierung von Tab 6: $($_.Exception.Message)" -Level "ERROR"
            }
        }

## Code Schnippsel wo noch unbekannt sind


# Funktion zum Laden von externen Modulen für Tab 5 und 6
function Import-ExternalModules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("ERP", "CRM", "DevTools", "PBX", "Starface")]
        [string]$ModuleType
    )
    
    try {
        Write-Log -Message "Lade externes Modul: $ModuleType" -Level "INFO"
        
        # Bestimme den Modulpfad
        $modulePath = switch ($ModuleType) {
            "ERP" { Join-Path $ScriptRoot "Modules\ERP-Module.psm1" }
            "CRM" { Join-Path $ScriptRoot "Modules\CRM-Module.psm1" }
            "DevTools" { Join-Path $ScriptRoot "Modules\DevTools-Module.psm1" }
            "PBX" { Join-Path $ScriptRoot "Modules\PBX-Module.psm1" }
            "Starface" { Join-Path $ScriptRoot "Modules\Starface-Module.psm1" }
        }
        
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force
            Write-Log -Message "Modul $ModuleType erfolgreich geladen" -Level "INFO"
            return $true
        }
        else {
            Write-Log -Message "Modul $ModuleType nicht gefunden: $modulePath" -Level "WARN"
            return $false
        }
        
    }
    catch {
        Write-Log -Message "Fehler beim Laden von Modul ${ModuleType}: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Funktion zum Laden von ERP/CRM-Daten
function Load-ErpCrmData {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log -Message "Lade ERP/CRM-Daten..." -Level "INFO"
        
        # Lade ERP-Modul
        if (Import-ExternalModules -ModuleType "ERP") {
            $erpData = Get-ERPSystems
        }
        
        # Lade CRM-Modul
        if (Import-ExternalModules -ModuleType "CRM") {
            $crmData = Get-CRMSystems
        }
        
        # Fallback wenn Module nicht verfügbar
        if (-not $erpData -and -not $crmData) {
            Write-Log -Message "ERP/CRM-Module nicht verfügbar, verwende Fallback-Daten" -Level "WARN"
            return @(
                [PSCustomObject]@{ System = "SAP"; Access = "Nein"; UserID = ""; Status = "Nicht konfiguriert" },
                [PSCustomObject]@{ System = "Dynamics"; Access = "Nein"; UserID = ""; Status = "Nicht konfiguriert" },
                [PSCustomObject]@{ System = "Salesforce"; Access = "Nein"; UserID = ""; Status = "Nicht konfiguriert" }
            )
        }
        
        return $erpData + $crmData
        
    }
    catch {
        Write-Log -Message "Fehler beim Laden der ERP/CRM-Daten: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

# Funktion zum Laden von Developer-Tools-Daten
function Load-DevToolsData {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log -Message "Lade Developer-Tools-Daten..." -Level "INFO"
        
        # Lade DevTools-Modul
        if (Import-ExternalModules -ModuleType "DevTools") {
            $devToolsData = Get-DeveloperTools
        }
        
        # Fallback wenn Modul nicht verfügbar
        if (-not $devToolsData) {
            Write-Log -Message "DevTools-Modul nicht verfügbar, verwende Fallback-Daten" -Level "WARN"
            return @(
                [PSCustomObject]@{ Tool = "Visual Studio"; Access = "Nein"; License = ""; Status = "Nicht konfiguriert" },
                [PSCustomObject]@{ Tool = "Git"; Access = "Nein"; License = ""; Status = "Nicht konfiguriert" },
                [PSCustomObject]@{ Tool = "Docker"; Access = "Nein"; License = ""; Status = "Nicht konfiguriert" }
            )
        }
        
        return $devToolsData
        
    }
    catch {
        Write-Log -Message "Fehler beim Laden der Developer-Tools-Daten: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

# Funktion zum Laden von Starface-PBX-Daten
function Load-StarfacePBXData {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log -Message "Lade Starface-PBX-Daten..." -Level "INFO"
        
        # Lade Starface-Modul
        if (Import-ExternalModules -ModuleType "Starface") {
            $starfaceData = Get-StarfaceUsers
        }
        
        # Fallback wenn Modul nicht verfügbar
        if (-not $starfaceData) {
            Write-Log -Message "Starface-Modul nicht verfügbar, verwende Fallback-Daten" -Level "WARN"
            return @{
                ExtensionNumber = "Nicht verfügbar"
                VoicemailEnabled = $false
                Status = "Modul nicht geladen"
            }
        }
        
        return $starfaceData
        
    }
    catch {
        Write-Log -Message "Fehler beim Laden der Starface-PBX-Daten: $($_.Exception.Message)" -Level "ERROR"
        return @{
            ExtensionNumber = "Fehler"
            VoicemailEnabled = $false
            Status = "Fehler beim Laden"
        }
    }
}        

## weitere Code Schnippsel

foreach ($controlName in $controlsToLoad) {
            $control = $Window.FindName($controlName)
            if ($control) {
            # Mappen step4PanelCloudOnly zu step4Panel für Kompatibilität
            # if ($controlName -eq "step4PanelCloudOnly") {
            #     $global:Variables["step4Panel"] = $control
            # } else {
            #    $global:Variables[$controlName] = $control
            # }
            Write-Log -Message "Steuerelement '$controlName' gefunden und gebunden." -Level "DEBUG"
            }
            else {
                Write-Log -Message "Steuerelement '$controlName' konnte nicht in der XAML-Datei gefunden werden." -Level "WARN"
            }

  ---

## XAML Code Navigation

                        <Button x:Name="btnStep4" Style="{StaticResource NavButton}" Tag="4">
                        <StackPanel Orientation="Horizontal">
                        <Border Width="18" Height="18" Background="{StaticResource MediumGrayBrush}" CornerRadius="9" Margin="0,0,8,0">
                        <TextBlock Text="4" FontSize="10" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock Text="4. Microsoft 365" VerticalAlignment="Center"/>
                        </StackPanel>
                        </Button>

                        <Button x:Name="btnStep5" Style="{StaticResource NavButton}" Tag="5">
                        <StackPanel Orientation="Horizontal">
                        <Border Width="18" Height="18" Background="{StaticResource MediumGrayBrush}" CornerRadius="9" Margin="0,0,8,0">
                        <TextBlock Text="5" FontSize="10" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock Text="5. Services &amp; Applikationen" VerticalAlignment="Center"/>
                        </StackPanel>
                        </Button>

                        <Button x:Name="btnStep6" Style="{StaticResource NavButton}" Tag="6">
                        <StackPanel Orientation="Horizontal">
                        <Border Width="18" Height="18" Background="{StaticResource MediumGrayBrush}" CornerRadius="9" Margin="0,0,8,0">
                        <TextBlock Text="6" FontSize="10" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock Text="6. Weitere Services" VerticalAlignment="Center"/>
                        </StackPanel>
                        </Button>

## XAML Code Tabs

            <!-- Step 4: Microsoft 365 (Cloud-Only Scenario) -->
                                <Border x:Name="step4PanelCloudOnly" Style="{StaticResource Card}" Visibility="Collapsed">
                                    <StackPanel>
                                        <TextBlock Text="Schritt 4: Microsoft 365 Integration" FontWeight="Bold" FontSize="18" Margin="0,0,0,20"/>

                                        <TextBlock Style="{StaticResource SectionHeader}" Text="Microsoft 365 Lizenzierung"/>
                                        <CheckBox x:Name="chkEnableO365" Content="Microsoft 365 aktivieren" FontWeight="SemiBold" Margin="0,0,0,10"/>

                                        <Grid IsEnabled="{Binding IsChecked, ElementName=chkEnableO365}">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="150"/>
                                                <ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>
                                            <Grid.RowDefinitions>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="Auto"/>
                                            </Grid.RowDefinitions>

                                            <Label Content="Lizenz:" Grid.Row="0" Grid.Column="0" VerticalAlignment="Center"/>
                                            <ComboBox x:Name="cmbO365License" Grid.Row="0" Grid.Column="1">
                                                <ComboBoxItem Content="Microsoft 365 Business Basic"/>
                                                <ComboBoxItem Content="Microsoft 365 Business Standard"/>
                                                <ComboBoxItem Content="Microsoft 365 Business Premium"/>
                                                <ComboBoxItem Content="Office 365 E3"/>
                                                <ComboBoxItem Content="Office 365 E5"/>
                                            </ComboBox>

                                            <Label Content="Nutzungsstandort:" Grid.Row="1" Grid.Column="0" VerticalAlignment="Center"/>
                                            <ComboBox x:Name="cmbUsageLocation" Grid.Row="1" Grid.Column="1">
                                                <ComboBoxItem Content="DE - Deutschland" IsSelected="True"/>
                                                <ComboBoxItem Content="AT - Österreich"/>
                                                <ComboBoxItem Content="CH - Schweiz"/>
                                            </ComboBox>
                                        </Grid>

                                        <TextBlock Style="{StaticResource SectionHeader}" Text="Exchange Online"/>
                                        <StackPanel IsEnabled="{Binding IsChecked, ElementName=chkEnableO365}">
                                            <CheckBox x:Name="chkCreateMailbox" Content="Exchange Postfach erstellen" Margin="5" IsChecked="True"/>
                                            <CheckBox x:Name="chkForwardingAddress" Content="E-Mail-Weiterleitung aktivieren" Margin="5"/>
                                            <Grid Margin="20,5,0,0" IsEnabled="{Binding IsChecked, ElementName=chkForwardingAddress}">
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="120"/>
                                                    <ColumnDefinition Width="*"/>
                                                </Grid.ColumnDefinitions>
                                                <Label Content="Weiterleitung an:" VerticalAlignment="Center"/>
                                                <TextBox x:Name="txtForwardingAddress" Grid.Column="1"/>
                                            </Grid>
                                        </StackPanel>

                                        <!-- Step Buttons -->
                                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
                                            <Button x:Name="btnPrevStep4" Content="Zurück" Style="{StaticResource ModernButton}" 
                                                    Background="{StaticResource DarkGrayBrush}" Margin="0,0,10,0"/>
                                            <Button x:Name="btnUpdateUser4" Content="Microsoft 365 konfigurieren" Style="{StaticResource ModernButton}" 
                                                    Background="{StaticResource WarningBrush}" Margin="0,0,10,0"/>
                                            <Button x:Name="btnNextStep4" Content="Weiter zu Services >" Style="{StaticResource ModernButton}"/>
                                        </StackPanel>
                                    </StackPanel>
                                </Border>


                                <!-- Step 4: AD Synchronisation (Hybrid Scenario) -->
                                <Border x:Name="step4PanelHybrid" Style="{StaticResource Card}" Visibility="Collapsed">
                                    <StackPanel>
                                        <TextBlock Text="Schritt 4: Active Directory Synchronisation" FontWeight="Bold" FontSize="18" Margin="0,0,0,20"/>

                                        <TextBlock Style="{StaticResource SectionHeader}" Text="AD Connect Synchronisation"/>
                                        
                                        <Border Background="#E3F2FD" BorderBrush="{StaticResource PrimaryBrush}" BorderThickness="1" CornerRadius="4" Padding="12" Margin="0,0,0,15">
                                            <StackPanel Orientation="Horizontal">
                                                <TextBlock Text="ℹ️" FontSize="16" Margin="0,0,8,0" Foreground="{StaticResource PrimaryBrush}"/>
                                                <TextBlock Text="In diesem Schritt wird die Synchronisation mit Microsoft 365 über AD Connect angestoßen. Der Benutzer muss im AD bereits erstellt sein." 
                                                        FontWeight="SemiBold" Foreground="{StaticResource PrimaryBrush}" TextWrapping="Wrap"/>
                                            </StackPanel>
                                        </Border>

                                        <Button x:Name="btnStartADSync" Content="AD Sync starten" Style="{StaticResource ModernButton}" 
                                                Background="{StaticResource PrimaryBrush}" HorizontalAlignment="Left" Width="200" Margin="0,10,0,10"/>

                                        <TextBlock Text="Synchronisationsstatus:" FontWeight="SemiBold" Margin="0,10,0,5"/>
                                        <TextBox x:Name="txtADSyncStatus" Height="250" IsReadOnly="True" Background="{StaticResource LightGrayBrush}" 
                                                VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"
                                                Text="Warte auf Start des Synchronisationsvorgangs..."/>

                                        <!-- Step Buttons -->
                                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
                                            <Button x:Name="btnPrevStep4Hybrid" Content="Zurück" Style="{StaticResource ModernButton}" 
                                                    Background="{StaticResource DarkGrayBrush}" Margin="0,0,10,0"/>
                                            <Button x:Name="btnNextStep4Hybrid" Content="Weiter zu Services >" Style="{StaticResource ModernButton}"/>
                                        </StackPanel>
                                    </StackPanel>
                                </Border>

                                <!-- Step 5: Services & Applikationen -->
                                <Border x:Name="step5Panel" Style="{StaticResource Card}" Visibility="Collapsed">
                                    <StackPanel>
                                        <TextBlock Text="Schritt 5: Services &amp; Applikationen" FontWeight="Bold" FontSize="18" Margin="0,0,0,20"/>
                                        <TextBlock Style="{StaticResource SectionHeader}" Text="Zugriff auf Unternehmensanwendungen"/>
                                        

                                        <TabControl Margin="0,10,0,0">
                                            <TabItem Header="ERP / CRM Systeme" x:Name="tabErpCrm">
                                                <Grid Margin="10">
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="*" />
                                                    </Grid.RowDefinitions>
                                                    <Button
                                                        x:Name="btnLoadErpCrm"
                                                        Width="150"
                                                        Margin="0,0,0,10"
                                                        HorizontalAlignment="Left"
                                                        Content="Systeme laden" />
                                                    <DataGrid
                                                        x:Name="dgErpCrm"
                                                        Grid.Row="1"
                                                        AutoGenerateColumns="False"
                                                        IsReadOnly="True">
                                                        <DataGrid.Columns>
                                                            <DataGridTextColumn
                                                                Width="*"
                                                                Binding="{Binding SystemName}"
                                                                Header="System" />
                                                            <DataGridTextColumn
                                                                Width="*"
                                                                Binding="{Binding Role}"
                                                                Header="Rolle/Profil" />
                                                            <DataGridCheckBoxColumn
                                                                Width="100"
                                                                Binding="{Binding HasAccess}"
                                                                Header="Zugriff" />
                                                        </DataGrid.Columns>
                                                    </DataGrid>
                                                </Grid>
                                            </TabItem>
                                            <TabItem Header="Entwickler-Tools" x:Name="tabDevTools">
                                                <Grid Margin="10">
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="*" />
                                                    </Grid.RowDefinitions>
                                                    <Button
                                                        x:Name="btnLoadDevTools"
                                                        Width="150"
                                                        Margin="0,0,0,10"
                                                        HorizontalAlignment="Left"
                                                        Content="Tools laden" />
                                                    <DataGrid
                                                        x:Name="dgDevTools"
                                                        Grid.Row="1"
                                                        AutoGenerateColumns="False"
                                                        IsReadOnly="True">
                                                        <DataGrid.Columns>
                                                            <DataGridTextColumn
                                                                Width="*"
                                                                Binding="{Binding ToolName}"
                                                                Header="Tool" />
                                                            <DataGridTextColumn
                                                                Width="*"
                                                                Binding="{Binding Role}"
                                                                Header="Rolle/Projekt" />
                                                            <DataGridCheckBoxColumn
                                                                Width="100"
                                                                Binding="{Binding HasAccess}"
                                                                Header="Zugriff" />
                                                        </DataGrid.Columns>
                                                    </DataGrid>
                                                </Grid>
                                            </TabItem>
                                            <TabItem Header="Weitere Systeme" x:Name="tabOtherSystems">
                                                <Grid Margin="10">
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="*" />
                                                    </Grid.RowDefinitions>
                                                    <Button
                                                        x:Name="btnLoadOtherSystems"
                                                        Width="150"
                                                        Margin="0,0,0,10"
                                                        HorizontalAlignment="Left"
                                                        Content="Systeme laden" />
                                                    <DataGrid
                                                        x:Name="dgOtherSystems"
                                                        Grid.Row="1"
                                                        AutoGenerateColumns="False"
                                                        IsReadOnly="True">
                                                        <DataGrid.Columns>
                                                            <DataGridTextColumn
                                                                Width="*"
                                                                Binding="{Binding SystemName}"
                                                                Header="System" />
                                                            <DataGridCheckBoxColumn
                                                                Width="100"
                                                                Binding="{Binding HasAccess}"
                                                                Header="Zugriff" />
                                                        </DataGrid.Columns>
                                                    </DataGrid>
                                                </Grid>
                                            </TabItem>
                                        </TabControl>

                                        <!-- Step Buttons -->
                                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
                                            <Button x:Name="btnPrevStep5" Content="&lt; Zurück" Style="{StaticResource ModernButton}" 
                                                    Background="{StaticResource DarkGrayBrush}" Margin="0,0,10,0"/>
                                            <Button x:Name="btnUpdateUser5" Content="Services konfigurieren" Style="{StaticResource ModernButton}" 
                                                    Background="{StaticResource WarningBrush}" Margin="0,0,10,0"/>
                                            <Button x:Name="btnNextStep5" Content="Weiter zur Zusammenfassung >" Style="{StaticResource ModernButton}"/>
                                        </StackPanel>
                                    </StackPanel>
                                </Border>

                                <!-- Step 6: Weitere Services -->
                                <Border x:Name="step6Panel" Style="{StaticResource Card}" Visibility="Collapsed">
                                    <StackPanel>
                                        <TextBlock Text="Schritt 6: Weitere Services" FontWeight="Bold" FontSize="18" Margin="0,0,0,20"/>
                                        <TextBlock Style="{StaticResource SectionHeader}" Text="Zusätzliche Zugriffsberechtigungen"/>

                                        <!-- Information Box -->
                                        <Border Background="#E3F2FD" BorderBrush="{StaticResource PrimaryBrush}" BorderThickness="1" 
                                                CornerRadius="4" Padding="10" Margin="0,0,0,15">
                                            <StackPanel>
                                                <TextBlock Text="💡 Service-Konfiguration" FontWeight="Bold" FontSize="11" Foreground="{StaticResource PrimaryBrush}"/>
                                                <TextBlock Text="Konfigurieren Sie zusätzliche Business-Anwendungen und Systeme für den neuen Benutzer. Diese Einstellungen werden nach der Benutzererstellung angewendet." 
                                                        FontSize="10" Foreground="{StaticResource PrimaryBrush}" TextWrapping="Wrap" Margin="0,3,0,0"/>
                                            </StackPanel>
                                        </Border>

                                        <TabControl Margin="0,10,0,0">
                                            <TabItem Header="Telefonie &amp; Kommunikation" x:Name="tabTelephony">
                                                <Grid Margin="10">
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="*" />
                                                    </Grid.RowDefinitions>
                                                    
                                                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
                                                        <Button x:Name="btnLoadTelephony" Width="150" Margin="0,0,10,0" Content="Systeme laden" />
                                                        <Button x:Name="btnRefreshTelephony" Width="100" Content="Aktualisieren" />
                                                    </StackPanel>
                                                    
                                                    <TextBlock Grid.Row="1" Text="Telefon- und Kommunikationssysteme" FontWeight="SemiBold" Margin="0,0,0,5"/>
                                                    
                                                    <DataGrid x:Name="dgTelephony" Grid.Row="2" AutoGenerateColumns="False" CanUserAddRows="False" Height="200">
                                                        <DataGrid.Columns>
                                                            <DataGridCheckBoxColumn Width="60" Binding="{Binding HasAccess}" Header="Aktiv" />
                                                            <DataGridTextColumn Width="200" Binding="{Binding SystemName}" Header="System" IsReadOnly="True"/>
                                                            <DataGridTextColumn Width="*" Binding="{Binding Details}" Header="Details/Konfiguration" />
                                                            <DataGridComboBoxColumn Width="120" SelectedItemBinding="{Binding AccessLevel}" Header="Zugriffslevel">
                                                                <DataGridComboBoxColumn.ElementStyle>
                                                                    <Style TargetType="ComboBox">
                                                                        <Setter Property="ItemsSource">
                                                                            <Setter.Value>
                                                                                <x:Array Type="sys:String" xmlns:sys="clr-namespace:System;assembly=mscorlib">
                                                                                    <sys:String>Standard</sys:String>
                                                                                    <sys:String>Erweitert</sys:String>
                                                                                    <sys:String>Administrator</sys:String>
                                                                                </x:Array>
                                                                            </Setter.Value>
                                                                        </Setter>
                                                                    </Style>
                                                                </DataGridComboBoxColumn.ElementStyle>
                                                            </DataGridComboBoxColumn>
                                                        </DataGrid.Columns>
                                                    </DataGrid>
                                                </Grid>
                                            </TabItem>
                                            
                                            <TabItem Header="Business Intelligence" x:Name="tabBI">
                                                <Grid Margin="10">
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="*" />
                                                    </Grid.RowDefinitions>
                                                    
                                                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
                                                        <Button x:Name="btnLoadBI" Width="150" Margin="0,0,10,0" Content="BI-Tools laden" />
                                                        <Button x:Name="btnConfigureBI" Width="120" Content="Konfigurieren" />
                                                    </StackPanel>
                                                    
                                                    <TextBlock Grid.Row="1" Text="Business Intelligence &amp; Analytics Tools" FontWeight="SemiBold" Margin="0,0,0,5"/>
                                                    
                                                    <DataGrid x:Name="dgBI" Grid.Row="2" AutoGenerateColumns="False" CanUserAddRows="False" Height="200">
                                                        <DataGrid.Columns>
                                                            <DataGridCheckBoxColumn Width="60" Binding="{Binding HasAccess}" Header="Aktiv" />
                                                            <DataGridTextColumn Width="180" Binding="{Binding ToolName}" Header="BI-Tool" IsReadOnly="True"/>
                                                            <DataGridTextColumn Width="150" Binding="{Binding LicenseType}" Header="Lizenztyp" />
                                                            <DataGridTextColumn Width="*" Binding="{Binding Dashboards}" Header="Dashboards/Reports" />
                                                            <DataGridComboBoxColumn Width="100" SelectedItemBinding="{Binding Role}" Header="Rolle">
                                                                <DataGridComboBoxColumn.ElementStyle>
                                                                    <Style TargetType="ComboBox">
                                                                        <Setter Property="ItemsSource">
                                                                            <Setter.Value>
                                                                                <x:Array Type="sys:String" xmlns:sys="clr-namespace:System;assembly=mscorlib">
                                                                                    <sys:String>Viewer</sys:String>
                                                                                    <sys:String>Creator</sys:String>
                                                                                    <sys:String>Admin</sys:String>
                                                                                </x:Array>
                                                                            </Setter.Value>
                                                                        </Setter>
                                                                    </Style>
                                                                </DataGridComboBoxColumn.ElementStyle>
                                                            </DataGridComboBoxColumn>
                                                        </DataGrid.Columns>
                                                    </DataGrid>
                                                </Grid>
                                            </TabItem>
                                            
                                            <TabItem Header="Sicherheit &amp; Compliance" x:Name="tabSecurity">
                                                <Grid Margin="10">
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="*" />
                                                    </Grid.RowDefinitions>
                                                    
                                                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
                                                        <Button x:Name="btnLoadSecurity" Width="150" Margin="0,0,10,0" Content="Security Tools laden" />
                                                        <Button x:Name="btnSecurityCheck" Width="120" Content="Sicherheitscheck" />
                                                    </StackPanel>
                                                    
                                                    <TextBlock Grid.Row="1" Text="Sicherheits- und Compliance-Tools" FontWeight="SemiBold" Margin="0,0,0,5"/>
                                                    
                                                    <DataGrid x:Name="dgSecurity" Grid.Row="2" AutoGenerateColumns="False" CanUserAddRows="False" Height="200">
                                                        <DataGrid.Columns>
                                                            <DataGridCheckBoxColumn Width="60" Binding="{Binding IsEnabled}" Header="Aktiv" />
                                                            <DataGridTextColumn Width="180" Binding="{Binding SecurityTool}" Header="Security Tool" IsReadOnly="True"/>
                                                            <DataGridTextColumn Width="120" Binding="{Binding Category}" Header="Kategorie" IsReadOnly="True"/>
                                                            <DataGridTextColumn Width="*" Binding="{Binding PolicySet}" Header="Richtlinien-Set" />
                                                            <DataGridComboBoxColumn Width="120" SelectedItemBinding="{Binding ComplianceLevel}" Header="Compliance">
                                                                <DataGridComboBoxColumn.ElementStyle>
                                                                    <Style TargetType="ComboBox">
                                                                        <Setter Property="ItemsSource">
                                                                            <Setter.Value>
                                                                                <x:Array Type="sys:String" xmlns:sys="clr-namespace:System;assembly=mscorlib">
                                                                                    <sys:String>Basic</sys:String>
                                                                                    <sys:String>Standard</sys:String>
                                                                                    <sys:String>Enhanced</sys:String>
                                                                                    <sys:String>Maximum</sys:String>
                                                                                </x:Array>
                                                                            </Setter.Value>
                                                                        </Setter>
                                                                    </Style>
                                                                </DataGridComboBoxColumn.ElementStyle>
                                                            </DataGridComboBoxColumn>
                                                        </DataGrid.Columns>
                                                    </DataGrid>
                                                </Grid>
                                            </TabItem>
                                            
                                            <TabItem Header="Projektmanagement" x:Name="tabProjectMgmt">
                                                <Grid Margin="10">
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="*" />
                                                    </Grid.RowDefinitions>
                                                    
                                                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
                                                        <Button x:Name="btnLoadPM" Width="150" Margin="0,0,10,0" Content="PM-Tools laden" />
                                                        <Button x:Name="btnCreateProjects" Width="120" Content="Projekte erstellen" />
                                                    </StackPanel>
                                                    
                                                    <TextBlock Grid.Row="1" Text="Projektmanagement &amp; Collaboration Tools" FontWeight="SemiBold" Margin="0,0,0,5"/>
                                                    
                                                    <DataGrid x:Name="dgProjectMgmt" Grid.Row="2" AutoGenerateColumns="False" CanUserAddRows="False" Height="200">
                                                        <DataGrid.Columns>
                                                            <DataGridCheckBoxColumn Width="60" Binding="{Binding HasAccess}" Header="Aktiv" />
                                                            <DataGridTextColumn Width="160" Binding="{Binding ToolName}" Header="Tool" IsReadOnly="True"/>
                                                            <DataGridTextColumn Width="*" Binding="{Binding ProjectsAccess}" Header="Projekte/Workspaces" />
                                                            <DataGridComboBoxColumn Width="120" SelectedItemBinding="{Binding Role}" Header="Projektrolle">
                                                                <DataGridComboBoxColumn.ElementStyle>
                                                                    <Style TargetType="ComboBox">
                                                                        <Setter Property="ItemsSource">
                                                                            <Setter.Value>
                                                                                <x:Array Type="sys:String" xmlns:sys="clr-namespace:System;assembly=mscorlib">
                                                                                    <sys:String>Member</sys:String>
                                                                                    <sys:String>Contributor</sys:String>
                                                                                    <sys:String>Manager</sys:String>
                                                                                    <sys:String>Owner</sys:String>
                                                                                </x:Array>
                                                                            </Setter.Value>
                                                                        </Setter>
                                                                    </Style>
                                                                </DataGridComboBoxColumn.ElementStyle>
                                                            </DataGridComboBoxColumn>
                                                            <DataGridComboBoxColumn Width="100" SelectedItemBinding="{Binding LicenseType}" Header="Lizenz">
                                                                <DataGridComboBoxColumn.ElementStyle>
                                                                    <Style TargetType="ComboBox">
                                                                        <Setter Property="ItemsSource">
                                                                            <Setter.Value>
                                                                                <x:Array Type="sys:String" xmlns:sys="clr-namespace:System;assembly=mscorlib">
                                                                                    <sys:String>Basic</sys:String>
                                                                                    <sys:String>Standard</sys:String>
                                                                                    <sys:String>Premium</sys:String>
                                                                                </x:Array>
                                                                            </Setter.Value>
                                                                        </Setter>
                                                                    </Style>
                                                                </DataGridComboBoxColumn.ElementStyle>
                                                            </DataGridComboBoxColumn>
                                                        </DataGrid.Columns>
                                                    </DataGrid>
                                                </Grid>
                                            </TabItem>
                                            
                                            <TabItem Header="Cloud Services" x:Name="tabCloudServices">
                                                <Grid Margin="10">
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="*" />
                                                    </Grid.RowDefinitions>
                                                    
                                                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
                                                        <Button x:Name="btnLoadCloudServices" Width="150" Margin="0,0,10,0" Content="Cloud Services laden" />
                                                        <Button x:Name="btnProvisionCloud" Width="120" Content="Bereitstellen" />
                                                    </StackPanel>
                                                    
                                                    <TextBlock Grid.Row="1" Text="Cloud-Plattformen &amp; Services" FontWeight="SemiBold" Margin="0,0,0,5"/>
                                                    
                                                    <DataGrid x:Name="dgCloudServices" Grid.Row="2" AutoGenerateColumns="False" CanUserAddRows="False" Height="200">
                                                        <DataGrid.Columns>
                                                            <DataGridCheckBoxColumn Width="60" Binding="{Binding IsEnabled}" Header="Aktiv" />
                                                            <DataGridTextColumn Width="140" Binding="{Binding ServiceName}" Header="Cloud Service" IsReadOnly="True"/>
                                                            <DataGridTextColumn Width="100" Binding="{Binding Provider}" Header="Anbieter" IsReadOnly="True"/>
                                                            <DataGridTextColumn Width="*" Binding="{Binding ResourceAccess}" Header="Ressourcen/Berechtigung" />
                                                            <DataGridComboBoxColumn Width="120" SelectedItemBinding="{Binding AccessLevel}" Header="Zugriffslevel">
                                                                <DataGridComboBoxColumn.ElementStyle>
                                                                    <Style TargetType="ComboBox">
                                                                        <Setter Property="ItemsSource">
                                                                            <Setter.Value>
                                                                                <x:Array Type="sys:String" xmlns:sys="clr-namespace:System;assembly=mscorlib">
                                                                                    <sys:String>Read-Only</sys:String>
                                                                                    <sys:String>Contributor</sys:String>
                                                                                    <sys:String>Owner</sys:String>
                                                                                    <sys:String>Admin</sys:String>
                                                                                </x:Array>
                                                                            </Setter.Value>
                                                                        </Setter>
                                                                    </Style>
                                                                </DataGridComboBoxColumn.ElementStyle>
                                                            </DataGridComboBoxColumn>
                                                        </DataGrid.Columns>
                                                    </DataGrid>
                                                </Grid>
                                            </TabItem>
                                            
                                            <TabItem Header="Weitere Services" x:Name="tabAdditionalServices">
                                                <Grid Margin="10">
                                                    <Grid.RowDefinitions>
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="Auto" />
                                                        <RowDefinition Height="*" />
                                                        <RowDefinition Height="Auto" />
                                                    </Grid.RowDefinitions>
                                                    
                                                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
                                                        <Button x:Name="btnLoadAdditionalServices" Width="150" Margin="0,0,10,0" Content="Services laden" />
                                                        <Button x:Name="btnAddCustomService" Width="120" Content="Custom Service" />
                                                    </StackPanel>
                                                    
                                                    <TextBlock Grid.Row="1" Text="Weitere Business-Anwendungen &amp; Tools" FontWeight="SemiBold" Margin="0,0,0,5"/>
                                                    
                                                    <DataGrid x:Name="dgAdditionalServices" Grid.Row="2" AutoGenerateColumns="False" CanUserAddRows="True" Height="150">
                                                        <DataGrid.Columns>
                                                            <DataGridCheckBoxColumn Width="60" Binding="{Binding IsEnabled}" Header="Aktiv" />
                                                            <DataGridTextColumn Width="160" Binding="{Binding ServiceName}" Header="Service/Anwendung" />
                                                            <DataGridTextColumn Width="*" Binding="{Binding Description}" Header="Beschreibung" />
                                                            <DataGridTextColumn Width="120" Binding="{Binding Version}" Header="Version" />
                                                            <DataGridComboBoxColumn Width="100" SelectedItemBinding="{Binding Priority}" Header="Priorität">
                                                                <DataGridComboBoxColumn.ElementStyle>
                                                                    <Style TargetType="ComboBox">
                                                                        <Setter Property="ItemsSource">
                                                                            <Setter.Value>
                                                                                <x:Array Type="sys:String" xmlns:sys="clr-namespace:System;assembly=mscorlib">
                                                                                    <sys:String>Niedrig</sys:String>
                                                                                    <sys:String>Normal</sys:String>
                                                                                    <sys:String>Hoch</sys:String>
                                                                                    <sys:String>Kritisch</sys:String>
                                                                                </x:Array>
                                                                            </Setter.Value>
                                                                        </Setter>
                                                                    </Style>
                                                                </DataGridComboBoxColumn.ElementStyle>
                                                            </DataGridComboBoxColumn>
                                                        </DataGrid.Columns>
                                                    </DataGrid>
                                                    
                                                    <!-- Service Statistics -->
                                                    <Border Grid.Row="3" Background="{StaticResource LightGrayBrush}" CornerRadius="4" Padding="10" Margin="0,10,0,0">
                                                        <Grid>
                                                            <Grid.ColumnDefinitions>
                                                                <ColumnDefinition Width="*"/>
                                                                <ColumnDefinition Width="*"/>
                                                                <ColumnDefinition Width="*"/>
                                                                <ColumnDefinition Width="*"/>
                                                            </Grid.ColumnDefinitions>
                                                            <StackPanel Grid.Column="0" HorizontalAlignment="Center">
                                                                <TextBlock x:Name="totalServicesCount" Text="0" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center"/>
                                                                <TextBlock Text="Gesamt Services" FontSize="10" HorizontalAlignment="Center"/>
                                                            </StackPanel>
                                                            <StackPanel Grid.Column="1" HorizontalAlignment="Center">
                                                                <TextBlock x:Name="activeServicesCount" Text="0" FontSize="18" FontWeight="Bold" Foreground="{StaticResource SuccessBrush}" HorizontalAlignment="Center"/>
                                                                <TextBlock Text="Aktive Services" FontSize="10" HorizontalAlignment="Center"/>
                                                            </StackPanel>
                                                            <StackPanel Grid.Column="2" HorizontalAlignment="Center">
                                                                <TextBlock x:Name="pendingServicesCount" Text="0" FontSize="18" FontWeight="Bold" Foreground="{StaticResource WarningBrush}" HorizontalAlignment="Center"/>
                                                                <TextBlock Text="Wartend" FontSize="10" HorizontalAlignment="Center"/>
                                                            </StackPanel>
                                                            <StackPanel Grid.Column="3" HorizontalAlignment="Center">
                                                                <TextBlock x:Name="estimatedCostText" Text="€0.00" FontSize="18" FontWeight="Bold" Foreground="{StaticResource PrimaryBrush}" HorizontalAlignment="Center"/>
                                                                <TextBlock Text="Geschätzte Kosten/Monat" FontSize="10" HorizontalAlignment="Center"/>
                                                            </StackPanel>
                                                        </Grid>
                                                    </Border>
                                                </Grid>
                                            </TabItem>
                                        </TabControl>

                                        <!-- Step Buttons -->
                                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
                                            <Button x:Name="btnPrevStep6" Content="&lt; Zurück" Style="{StaticResource ModernButton}" 
                                                    Background="{StaticResource DarkGrayBrush}" Margin="0,0,10,0"/>
                                            <Button x:Name="btnValidateServices" Content="Services validieren" Style="{StaticResource ModernButton}" 
                                                    Background="{StaticResource WarningBrush}" Margin="0,0,10,0"/>
                                            <Button x:Name="btnUpdateUser6" Content="Services konfigurieren" Style="{StaticResource ModernButton}" 
                                                    Background="{StaticResource WarningBrush}" Margin="0,0,10,0"/>
                                            <Button x:Name="btnNextStep6" Content="Weiter zur Zusammenfassung >" Style="{StaticResource ModernButton}"/>
                                        </StackPanel>
                                    </StackPanel>
                                </Border>