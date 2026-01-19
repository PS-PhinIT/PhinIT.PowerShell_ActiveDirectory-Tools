# 📖 HOWTO - Schritt-für-Schritt Guides

**Praktische Anleitungen für häufige Aufgaben in easyONBOARDING**

---

## 🎯 Inhaltsverzeichnis

1. [Ersten Workflow erstellen](#workflow-erstellen)
2. [Neuen Mitarbeiter onboarden](#mitarbeiter-onboarden)
3. [Admin-Benutzer verwalten](#admin-benutzer)
4. [Branding anpassen](#branding-anpassen)
5. [Email-Templates konfigurieren](#email-templates)
6. [Daten exportieren](#daten-exportieren)
7. [API nutzen](#api-nutzen)
8. [LDAP einrichten](#ldap-setup)

---

## 🏗️ Workflow erstellen {#workflow-erstellen}

### Ziel: Einfachen HR → Manager → IT Workflow erstellen

#### Schritt 1: Workflow Builder öffnen
```
1. Admin Panel anmelden
2. Menü: 🏗️ Workflow Builder
3. Klick auf "➕ Neuer Workflow"
4. Name eingeben: "Standard Onboarding"
```

#### Schritt 2: Schritte hinzufügen
```
Linke Seite - Workflow wird oben in der Canvas angezeigt

1. Klick auf "➕ Schritt hinzufügen" im Canvas
2. Erste Schritt bearbeiten (Rechte Seite):
   - Titel: "HR-Genehmigung"
   - Beschreibung: "HR prüft und genehmigt neuen Mitarbeiter"
   - Rolle: "HR"
   - Erforderlich: ✓ Ja
   - Zeitlimit: 2 Tage
```

#### Schritt 3: Weitere Schritte
```
Wiederholen Sie Schritt 1-2 für:

Schritt 2 - Manager-Genehmigung:
   - Titel: "Manager-Genehmigung"
   - Rolle: "Manager"
   - Bedingung: (leer - für alle)
   - Zeitlimit: 1 Tag

Schritt 3 - IT-Setup:
   - Titel: "IT-Setup"
   - Rolle: "IT"
   - Bedingung: (leer)
   - Zeitlimit: 3 Tage

Schritt 4 - Abschluss:
   - Titel: "HR-Abschluss"
   - Rolle: "HR"
   - Erforderlich: ✗ Nein (optional)
   - Zeitlimit: 0 (kein Limit)
```

#### Schritt 4: Workflow speichern
```
1. Rechts unten auf "💾 Speichern" klicken
2. Bestätigung warten
3. Workflow ist jetzt aktiv
```

---

## 👨‍💼 Neuen Mitarbeiter onboarden {#mitarbeiter-onboarden}

### Ziel: Onboarding-Fall für neue Mitarbeiterin erstellen

#### Schritt 1: HR-Dashboard öffnen
```
1. Als HR-Benutzer anmelden
2. HR Dashboard öffnen
3. Klick auf "➕ Neuer Fall"
```

#### Schritt 2: Mitarbeiter-Daten eingeben
```
Formular ausfüllen:

PERSÖNLICHE DATEN:
  - Vorname: "Anna"
  - Nachname: "Schmidt"
  - E-Mail: "anna.schmidt@company.de"
  - Geburtsdatum: "15.03.1990"

POSITION:
  - Stelle: "Senior Developer"
  - Abteilung: "IT"
  - Start-Datum: "01.03.2025"
  - Manager: "Klaus Weber"

WEITERE INFOS:
  - Vertrag: "Vollzeit"
  - Übernahme-Quelle: "Externe Bewerbung"
```

#### Schritt 3: Workflow auswählen
```
Dropdown "Workflow auswählen":
  - "Standard Onboarding" (den wir gerade erstellt haben)
```

#### Schritt 4: Fall erstellen
```
1. Auf "✅ Fall erstellen" klicken
2. Fall-Nummer wird generiert (z.B. "ONB-20250301-001")
3. System versendet Benachrichtigungen
4. Workflow startet automatisch
```

#### Schritt 5: Fortschritt überwachen
```
Fall-Details anschauen:
  - HR-Genehmigung: ⏳ Ausstehend
  - Manager-Genehmigung: ⏳ Wartend
  - IT-Setup: ⏳ Wartend
  - Abschluss: ⏳ Wartend
```

---

## 🔑 Admin-Benutzer verwalten {#admin-benutzer}

### Ziel: Neuen Admin hinzufügen

#### Schritt 1: Admin-Panel öffnen
```
1. Als Admin anmelden
2. Admin Panel → 👥 Benutzer-Management
```

#### Schritt 2: Neuen Benutzer hinzufügen
```
Klick auf "➕ Neuer Benutzer"

BENUTZERDATEN:
  - Vorname: "Peter"
  - Nachname: "Müller"
  - E-Mail: "peter.mueller@company.de"
  - Benutzername: "pmueller"
  - Passwort: (Auto-generiert) "Xk9$mP2@Lq5"

ROLLE & RECHTE:
  - Rolle: "Admin"
  - Abteilung: (nicht erforderlich für Admin)
  - Aktiv: ✓ Ja
```

#### Schritt 3: Benutzer speichern
```
1. Auf "✅ Benutzer erstellen" klicken
2. Bestätigungsmeldung
3. Email mit Zugangsdaten wird versendet
```

#### Schritt 4: Benutzer bearbeiten
```
In der Benutzer-Liste:
  - Benutzer auswählen
  - Auf "✏️ Bearbeiten" klicken
  - Daten anpassen
  - "💾 Speichern" klicken
```

---

## 🎨 Branding anpassen {#branding-anpassen}

### Ziel: System mit Firmenfarben personalisieren

#### Schritt 1: Customization öffnen
```
Admin Panel → 🎨 Customization → Branding Tab
```

#### Schritt 2: Firmeninfos eintragen
```
FIRMENINFORMATIONEN:
  - Firmenname: "Meine GmbH"
  - Logo URL: "https://example.com/logo.png"
  - Support-Email: "support@meine-gmbh.de"
  - Telefon: "+49 (0)123 456789"
  - Website: "https://www.meine-gmbh.de"

FOOTER-TEXT:
  "© 2025 Meine GmbH. Alle Rechte vorbehalten."
```

#### Schritt 3: Farben anpassen
```
PRIMÄR-FARBE (für Hauptelemente):
  - Klick auf Farbfeld
  - Farbe wählen: z.B. #2563eb (Blau)
  - Oder Hex-Code eingeben

SEKUNDÄR-FARBE (für Success/Positiv):
  - Farbe: z.B. #10b981 (Grün)

AKZENT-FARBE (für Warnung):
  - Farbe: z.B. #f59e0b (Orange)
```

#### Schritt 4: Speichern & Vorschau
```
1. "💾 Branding speichern" klicken
2. Unten ist die Live-Vorschau zu sehen
3. Das ganze System nutzt nun die Farben
```

---

## 📧 Email-Templates konfigurieren {#email-templates}

### Ziel: Willkommens-Email anpassen

#### Schritt 1: Templates öffnen
```
Admin Panel → 🎨 Customization → Email-Vorlagen Tab
```

#### Schritt 2: Template auswählen
```
VERFÜGBARE TEMPLATES:
  1. 👋 Willkommensnachricht
  2. 🔐 Zugangsdaten
  3. ⏰ Erinnerung
  4. ✅ Abschluss

Klick auf "👋 Willkommensnachricht"
```

#### Schritt 3: Template bearbeiten
```
TEMPLATE-NAME:
  "Willkommen im Team!"

BETREFF:
  "Willkommen {EMPLOYEE_NAME} - Wir freuen uns auf dich! 🎉"

HTML BODY (Beispiel):
  <h1>Willkommen {EMPLOYEE_NAME}!</h1>
  <p>Wir freuen uns, dich in unserem Team begrüßen zu dürfen.</p>
  <p><strong>Dein Start-Datum:</strong> {START_DATE}</p>
  <p><strong>Position:</strong> {POSITION}</p>
  <p>Wenn du Fragen hast, kontaktiere dein HR-Team.</p>

VERFÜGBARE VARIABLEN:
  - {EMPLOYEE_NAME}  → "Max Mustermann"
  - {START_DATE}     → "01.03.2025"
  - {POSITION}       → "Senior Developer"
  - {DEPARTMENT}     → "IT"
  - {COMPANY_NAME}   → "Meine GmbH"
```

#### Schritt 4: Speichern
```
1. "💾 Speichern" klicken
2. Template ist sofort aktiv
3. Nächste Emails nutzen die neue Vorlage
```

---

## 📄 Daten exportieren {#daten-exportieren}

### Ziel: Onboarding-Daten als CSV/PDF exportieren

#### Schritt 1: Fall auswählen
```
HR Dashboard → Fall anklicken
```

#### Schritt 2: CSV exportieren
```
1. Klick auf "📥 CSV Export"
2. Datei wird heruntergeladen: "Case_ONB20250301001.csv"
3. In Excel öffnen für weitere Analyse
```

#### Schritt 3: PDF exportieren
```
1. Klick auf "📄 PDF Export"
2. Schönes Onboarding-Dokument öffnet sich
3. Mit "Drucken" → "Als PDF speichern"
4. Oder direkt herunterladen
```

#### Schritt 4: PDF-Inhalt
```
Das PDF enthält:
  ✓ Persönliche Informationen
  ✓ Generierte Zugangsdaten
  ✓ Erste Schritte Checkliste
  ✓ Einarbeitungsplan
  ✓ Wichtige Kontakte
```

---

## 🔗 API nutzen {#api-nutzen}

### Ziel: Über PowerShell neuen Fall erstellen

#### Schritt 1: API-Key generieren
```
1. Admin Panel → 🔐 API-Keys
2. "➕ Neuer API-Key" erstellen
3. Key kopieren: "sk_live_abc123def456"
```

#### Schritt 2: PowerShell-Skript erstellen
```powershell
# Variablen setzen
$apiUrl = "http://localhost/easyONBOARDING/api/create_case.php"
$apiKey = "sk_live_abc123def456"

# Mitarbeiter-Daten vorbereiten
$employeeData = @{
    employee_first_name = "Thomas"
    employee_last_name  = "König"
    employee_email      = "thomas.koenig@company.de"
    job_title          = "Product Manager"
    department         = "Management"
    start_date         = "2025-03-15"
    workflow_id        = 1
} | ConvertTo-Json

# HTTP-Header setzen
$headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type"  = "application/json"
}

# API-Request senden
$response = Invoke-RestMethod `
    -Uri $apiUrl `
    -Method POST `
    -Headers $headers `
    -Body $employeeData

# Ergebnis anzeigen
Write-Host "✅ Fall erstellt!"
Write-Host "Fall-Nummer: $($response.case_number)"
Write-Host "Benutzer: $($response.generated_username)"
```

#### Schritt 3: Skript ausführen
```powershell
# Script speichern als: create_employee.ps1
# Ausführen:
.\create_employee.ps1

# Output:
# ✅ Fall erstellt!
# Fall-Nummer: ONB-20250315-042
# Benutzer: tkonig
```

---

## 🔐 LDAP einrichten {#ldap-setup}

### Ziel: Windows Active Directory verbinden

#### Schritt 1: LDAP-Daten sammeln
```
Von Ihrem Netzwerk-Admin erfragen:
  - LDAP Server: ldap://ad.company.local
  - Service Account: CN=svc_onboarding,CN=Users,DC=company,DC=local
  - Service Account Passwort: (geheim)
  - Base DN: DC=company,DC=local
  - User Search Base: CN=Users,DC=company,DC=local
```

#### Schritt 2: config.php konfigurieren
```php
// Datei öffnen: config.php

// LDAP aktivieren
define('LDAP_ENABLED', true);

// LDAP-Server
define('LDAP_SERVER', 'ldap://ad.company.local');
define('LDAP_PORT', 389);

// Service Account
define('LDAP_BIND_USER', 'CN=svc_onboarding,CN=Users,DC=company,DC=local');
define('LDAP_BIND_PASS', 'password123');

// Base DN
define('LDAP_BASE_DN', 'DC=company,DC=local');
define('LDAP_USER_BASE_DN', 'CN=Users,DC=company,DC=local');

// User-Suche
define('LDAP_USER_FILTER', '(&(objectClass=user)(sAMAccountName={username}))');
define('LDAP_USER_ATTR', 'sAMAccountName');
```

#### Schritt 3: LDAP testen
```
1. Login-Seite öffnen
2. "🔓 LDAP Login" Tab klicken
3. Windows-Benutzername & Passwort eingeben
4. Wenn erfolgreich: Automatisch anmelden
```

#### Schritt 4: Benutzer synchronisieren
```
Admin Panel → 🔧 Einstellungen → LDAP-Sync
  1. "🔄 Alle Benutzer synchronisieren" klicken
  2. System importiert alle AD-Benutzer
  3. Rollen automatisch zuweisen
```

---

## 🆘 Häufige Fragen

### Q: Wie ändere ich ein Passwort?
```
A: Admin Panel → 👥 Benutzer → [Benutzer] → ✏️ Bearbeiten
   → Passwort-Feld → "🎲 Generieren" oder manuell eingeben → Speichern
```

### Q: Wie lösche ich einen Benutzer?
```
A: Admin Panel → 👥 Benutzer → [Benutzer] → 🗑️ Löschen
   → "Deaktivieren" (sicherer) oder "Permanent löschen"
```

### Q: Wie exportiere ich alle Fälle?
```
A: Admin Panel → 📊 Analytics → "📥 Alle Daten exportieren"
```

### Q: Wie konfiguriere ich automatische Reminders?
```
A: Admin Panel → 🎨 Customization → Email-Vorlagen
   → "⏰ Erinnerung" Template anpassen
```

---

**Viel Erfolg! 🚀**

Weitere Fragen? Siehe **README.md** oder **API.md**

---

**Version:** 3.0.0  
**Letzte Aktualisierung:** 2025
