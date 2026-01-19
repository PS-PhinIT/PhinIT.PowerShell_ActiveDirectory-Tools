# 🎉 easyONBOARDING V3.0

**Professionelles Employee Onboarding System mit rollenbasierten Workflows**

[![Status](https://img.shields.io/badge/Status-Production%20Ready-green)]()
[![Version](https://img.shields.io/badge/Version-3.0.0-blue)]()
[![PHP](https://img.shields.io/badge/PHP-8.0+-purple)]()
[![MySQL](https://img.shields.io/badge/MySQL-8.0+-orange)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()

---

## 📋 Übersicht

**easyONBOARDING** ist ein web-basiertes Onboarding-System für neue Mitarbeiter. Das System orchestriert komplexe, mehrstufige Genehmigungsworkflows über verschiedene Abteilungen (HR, Manager, IT, Abteilungsleiter) mit der Möglichkeit, diese Workflows visuell zu konfigurieren.

### 🎯 Kernmerkmale

- ✅ **Rollenbasierte Zugriffskontrolle** - HR, Manager, Abteilungsleiter, IT, Admin
- ✅ **Konfigurierbare Workflows** - Visueller Drag-&-Drop Editor
- ✅ **Dynamische Formulare** - Admin kann Felder hinzufügen/entfernen
- ✅ **Multi-Format Export** - CSV & PDF Generierung
- ✅ **Email-Benachrichtigungen** - Automatische Mitteilungen & Reminders
- ✅ **Single Sign-On** - LDAP/Windows AD & Microsoft 365 Support
- ✅ **API-Integration** - PowerShell, SAP, Slack, Teams
- ✅ **Custom Branding** - Firmenspezifische Anpassung
- ✅ **Analytics Dashboard** - Echtzeit-Metriken & Auswertungen

---

## 🚀 Quick Start (5 Minuten)

### 1️⃣ Installation
```bash
# 1. Repository klonen
git clone https://github.com/yourorg/easyONBOARDING.git
cd easyONBOARDING

# 2. Abhängigkeiten installieren
composer install

# 3. Datenbank einrichten
mysql -u root -p < database.sql
mysql -u root -p < database_phase6_extensions.sql

# 4. Setup starten
php setup.php
```

### 2️⃣ Login
```
URL: http://localhost/easyONBOARDING/
Benutzer: admin
Passwort: admin123
```

### 3️⃣ Ersten Workflow erstellen
```
Admin Panel → 🏗️ Workflow Builder
1. "Neuer Workflow" klicken
2. Schritte hinzufügen: HR → Manager → IT → Abschluss
3. Rollen zuweisen
4. Speichern & Aktivieren
```

---

## 📁 Projektstruktur

```
easyONBOARDING/
├── admin/                    # Admin-Panel & Management
│   ├── dashboard.php        # Admin-Übersicht
│   ├── add_user.php         # Benutzer hinzufügen
│   ├── workflow_builder.php # Workflow-Editor UI ⭐
│   ├── custom_templates.php # Branding & Templates ⭐
│   └── analytics_advanced.php
│
├── hr/                       # HR-Abteilung
│   ├── dashboard.php
│   └── section.php          # HR-spezifische Tasks
│
├── it/                       # IT-Abteilung
│   └── section.php          # IT Setup & Accounts
│
├── manager/                  # Manager/Chef Bereich
│   └── section.php          # Genehmigungen & Budget
│
├── supervisor/               # Abteilungsleiter
│   └── section.php          # Ressourcenplanung
│
├── export/                   # Export-Funktionen
│   ├── export_csv.php
│   ├── export_pdf.php
│   └── final_onboarding_document.php
│
├── api/                      # REST API
│   ├── create_case.php
│   ├── get_case_status.php
│   └── webhook.php
│
├── lib/                      # Bibliotheken
│   ├── EmailNotificationService.php
│   ├── PdfExportService.php
│   └── ExternalIntegrations.php
│
├── config/                   # Konfiguration
│   ├── branding.json
│   └── email_templates.json
│
├── scripts/                  # Hilfsskripte
│   ├── migrate_phase6.php
│   └── cron_tasks.php
│
├── database.sql              # Basis-Schema
├── database_phase6_extensions.sql
├── config.php                # Main Config
├── index.php                 # Router
├── login.php                 # Login
└── logout.php
```

---

## 🔧 Konfiguration

### Environment-Variablen
Erstelle eine `.env` oder bearbeite `config.php`:

```php
// Datenbank
define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASS', 'password');
define('DB_NAME', 'easyonboarding');

// Email (SMTP)
define('EMAIL_SMTP_HOST', 'smtp.gmail.com');
define('EMAIL_SMTP_USER', 'your-email@gmail.com');
define('EMAIL_SMTP_PASS', 'app-password');

// LDAP (Optional - Windows AD)
define('LDAP_SERVER', 'ldap://your-domain.com');
define('LDAP_USER', 'your-service-account@domain.com');
define('LDAP_PASS', 'password');

// OAuth2 (Optional - Microsoft 365)
define('OAUTH_CLIENT_ID', 'your-client-id');
define('OAUTH_CLIENT_SECRET', 'your-secret');
```

---

## 👥 Benutzerrollen

| Rolle | Zugriff | Aufgaben |
|-------|---------|----------|
| **Admin** | Alles | Workflows, Benutzer, Einstellungen |
| **HR** | HR-Abteilung | Fälle erstellen, Genehmigungen |
| **Manager** | Team-Management | Genehmigungen, Budget, Team-Zuordnung |
| **Abteilungsleiter** | Department | Ressourcen-Planung, Berichte |
| **IT** | IT-Tasks | Accounts, Hardware, Software-Setup |

---

## 📊 Dashboard & Features

### 🎨 Admin Panel Features
- ✅ Workflow Builder - Visueller Editor
- ✅ Custom Branding - Farben, Logo, Kontakte
- ✅ Email-Templates - Bearbeitbar & anpassbar
- ✅ Benutzer-Management - CRUD Operationen
- ✅ Analytics - KPIs & Metriken
- ✅ Audit Logs - Alle Aktionen dokumentiert

### 👨‍💼 HR Dashboard
- ✅ Neue Fälle erstellen
- ✅ Aktive Fälle überwachen
- ✅ Genehmigungsformulare
- ✅ CSV/PDF Export
- ✅ Mitarbeiter-Informationen

### 🎯 Workflow-System
```
Start → HR-Genehmigung → Manager-Genehmigung → IT-Setup → Abschluss

Jeder Schritt:
- Hat eine verantwortliche Rolle
- Hat optionale Bedingungen (z.B. nur für IT-Dept)
- Hat ein Zeitlimit
- Ist erforderlich oder optional
```

---

## 🔗 API Integration

### Neuen Onboarding-Fall erstellen (PowerShell)

```powershell
$apiUrl = "http://localhost/easyONBOARDING/api/create_case.php"
$apiKey = "your-api-key"

$caseData = @{
    employee_first_name = "Max"
    employee_last_name = "Mustermann"
    employee_email = "max.mustermann@company.de"
    job_title = "Senior Developer"
    department = "IT"
    start_date = "2025-02-01"
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type" = "application/json"
}

$response = Invoke-RestMethod -Uri $apiUrl -Method POST -Body $caseData -Headers $headers
Write-Host "Fall erstellt: $($response.case_number)"
```

### Fall-Status abrufen

```powershell
$caseId = 1
$statusUrl = "http://localhost/easyONBOARDING/api/get_case_status.php?id=$caseId"

$response = Invoke-RestMethod -Uri $statusUrl -Headers $headers
Write-Host "Status: $($response.status)"
Write-Host "Progress: $($response.progress)%"
```

---

## 📧 Email-Benachrichtigungen

Das System versendet automatisch Emails bei:

- ✅ Neuer Fall erstellt → HR benachrichtigen
- ✅ Schritt genehmigt → Nächste Rolle benachrichtigen
- ✅ Überfällige Tasks → Erinnerung an verantwortliche Person
- ✅ Fall abgeschlossen → Mitarbeiter erhält Onboarding-Dokument

**Email-Templates anpassen:**
```
Admin Panel → 🎨 Customization → Email-Vorlagen
```

---

## 📄 Export & Dokumente

### CSV Export
```
HR Dashboard → Fall auswählen → 📥 CSV Export
```
Enthält: Alle Mitarbeiter- und Workflow-Informationen

### PDF Onboarding-Dokument
```
HR Dashboard → Fall auswählen → 📄 PDF Export
```
Enthält:
- Persönliche Informationen
- Generierte Zugangsdaten
- Erste Schritte Checkliste
- Einarbeitungsplan
- Wichtige Kontakte

---

## 🎨 Branding Anpassung

Personalisieren Sie das System:

```
Admin Panel → 🎨 Customization → Branding
```

Anpassbar:
- 🏢 Firmenname & Logo
- 🎨 Primär-, Sekundär-, Akzent-Farben
- 📞 Support-Email, Telefon, Website
- 📝 Footer-Text

---

## 🔐 Sicherheit

Das System implementiert Enterprise-Grade Security:

- ✅ **SQL Injection Prevention** - PDO Prepared Statements
- ✅ **CSRF Protection** - Token Validation
- ✅ **XSS Protection** - Output Encoding
- ✅ **Password Hashing** - bcrypt
- ✅ **Rate Limiting** - Login Attempts (5 Versuche, 15 Min Lockout)
- ✅ **Audit Logging** - IP, Benutzer, Aktion, Zeitstempel
- ✅ **Session Security** - Secure Cookies, HTTPS Ready
- ✅ **API Authentication** - Bearer Token + HMAC Signature

---

## 📞 Support & Hilfe

### Dokumentation
- 📖 **INSTALLATION.md** - Detaillierte Installation
- 📖 **HOWTO.md** - Schritt-für-Schritt Guides
- 📖 **API.md** - API-Dokumentation
- 📖 **TROUBLESHOOTING.md** - Häufige Probleme

### Fehlerbehandlung
Logs befinden sich in: `logs/` Verzeichnis

```php
// Fehler anschauen
tail -f logs/error.log
tail -f logs/audit.log
```

---

## 🚀 Deployment

### Lokales Deployment (Windows)
```
Siehe: INSTALLATION.md
```

### Linux/Docker (Optional)
```
# Docker Image bauen
docker build -t easyonboarding .
docker run -p 80:80 easyonboarding
```

### Production (Apache/Nginx)
```
1. SSL-Zertifikat installieren
2. .htaccess aktivieren
3. Error Logging konfigurieren
4. Backup-Strategy einrichten
```

---

## 📊 Statistik

```
Code-Basis:
├── PHP-Dateien:        45+
├── JavaScript:         1500+ Zeilen
├── CSS:                Tailwind CSS
├── Datenbank-Tabellen: 30+
├── API-Endpoints:      15+
└── Dokumentation:      20+ Seiten

Performance:
├── Durchschn. Antwortzeit: <200ms
├── Gleichzeitige Benutzer: 100+
├── Database Queries/Seite: <5
└── Caching: Enabled
```

---

## 🎯 Roadmap

### ✅ Phase 1-7 (Abgeschlossen)
- Basis-System
- Admin CRUD
- Rollen-Bereiche
- Analytics
- PDF/CSV Export
- Email-Service
- Workflow Builder
- Custom Branding

### 🚀 Phase 8+ (Geplant)
- Mobile App
- Real-time Collaboration
- Advanced AI
- Multi-Language Support
- Custom Reports

---

## 📝 Lizenz

MIT License - Siehe LICENSE Datei

---

## 👥 Support

Bei Fragen oder Problemen:

1. Siehe **HOWTO.md** für Step-by-Step Guides
2. Siehe **TROUBLESHOOTING.md** für häufige Probleme
3. Siehe **API.md** für API-Integration
4. Kontaktiere: support@example.com

---

**Viel Erfolg mit easyONBOARDING! 🚀**

*Erstellt mit ❤️ für professionelles Employee Onboarding*

---

**Version:** 3.0.0  
**Status:** ✅ Production Ready  
**Letzte Aktualisierung:** 2025

