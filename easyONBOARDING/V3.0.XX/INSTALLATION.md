# 📖 Installation Guide - easyONBOARDING V3.0

**Detaillierte Installationsanleitung für Windows, Linux und Production**

---

## 🎯 Anforderungen

### Minimum System-Anforderungen

| Komponente | Anforderung |
|-----------|------------|
| **PHP** | 8.0+ (mit PDO MySQL) |
| **MySQL** | 8.0+ oder MariaDB 10.5+ |
| **Apache** | 2.4+ mit mod_rewrite |
| **RAM** | 2 GB |
| **Speicher** | 500 MB verfügbar |

### PHP-Extensions
```
- pdo_mysql
- json
- curl
- mbstring
- gd (für Bilder)
- openssl (für SSL)
```

Prüfen mit:
```bash
php -m | grep "pdo_mysql\|json\|curl"
```

---

## 💻 Windows Installation (Apache/PHP/MySQL)

### Schritt 1: Abhängigkeiten installieren

#### Option A: XAMPP (Empfohlen für Anfänger)
```bash
1. Download: https://www.apachefriends.org/
2. Installieren Sie XAMPP
3. Starten Sie den XAMPP Control Panel
4. Klicken Sie auf "Start" neben Apache und MySQL
```

#### Option B: Manuelle Installation
```bash
# 1. PHP installieren
- Download: https://windows.php.net/download/
- Entpacken nach: C:\php
- php.ini in C:\php kopieren und bearbeiten

# 2. MySQL installieren
- Download: https://dev.mysql.com/downloads/mysql/
- Installieren Sie MySQL Server
- Merken Sie sich das Root-Passwort

# 3. Apache installieren
- Download: https://httpd.apache.org/download.cgi
- Führen Sie den MSI-Installer aus
```

### Schritt 2: easyONBOARDING herunterladen

```bash
# Gehen Sie zu Ihrem Apache-Dokumentenverzeichnis
cd C:\xampp\htdocs  # oder C:\Apache24\htdocs

# Repository klonen
git clone https://github.com/yourorg/easyONBOARDING.git
cd easyONBOARDING
```

### Schritt 3: Composer installieren

```bash
# 1. Composer Download
Download: https://getcomposer.org/Composer-Setup.exe
Führen Sie den Installer aus

# 2. Abhängigkeiten installieren
cd C:\xampp\htdocs\easyONBOARDING
composer install
```

### Schritt 4: Datenbank einrichten

```bash
# 1. MySQL öffnen (Command Line Client)
mysql -u root -p
# Passwort eingeben

# 2. SQL-Skripte ausführen (in MySQL)
mysql> source database.sql;
mysql> source database_phase6_extensions.sql;
mysql> exit;
```

**Oder über GUI (phpMyAdmin):**
```
1. Öffnen Sie http://localhost/phpmyadmin
2. Neue Datenbank erstellen: "easyonboarding"
3. Menü: Import
4. Datei wählen: database.sql
5. "Go" klicken
6. Wiederholen Sie es mit database_phase6_extensions.sql
```

### Schritt 5: Konfiguration anpassen

**Bearbeiten Sie `config.php`:**

```php
// Datenbank-Einstellungen
define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASS', 'your-password');  // Ihr MySQL-Passwort
define('DB_NAME', 'easyonboarding');

// Optional: Email-Service
define('EMAIL_SMTP_HOST', 'smtp.gmail.com');
define('EMAIL_SMTP_USER', 'your-email@gmail.com');
define('EMAIL_SMTP_PASS', 'app-password');  // Google App Password
define('EMAIL_FROM', 'noreply@company.de');
```

### Schritt 6: Setup starten

```bash
# Öffnen Sie den Browser
http://localhost/easyONBOARDING/setup.php

# Folgen Sie den Anweisungen auf dem Bildschirm
# Das System erstellt automatisch:
# - Datenbank-Tabellen
# - Admin-Benutzer
# - Demo-Workflows
```

### Schritt 7: Login testen

```
URL: http://localhost/easyONBOARDING/
Benutzername: admin
Passwort: admin123
```

✅ **Installation abgeschlossen!**

---

## 🐧 Linux Installation (Debian/Ubuntu)

### Schritt 1: Abhängigkeiten installieren

```bash
# Pakete aktualisieren
sudo apt update && sudo apt upgrade -y

# PHP und Erweiterungen
sudo apt install -y php php-cli php-mysql php-curl php-json php-mbstring php-gd

# Apache
sudo apt install -y apache2 apache2-utils libapache2-mod-php

# MySQL
sudo apt install -y mysql-server

# Git
sudo apt install -y git
```

### Schritt 2: Apache vorbereiten

```bash
# mod_rewrite aktivieren
sudo a2enmod rewrite

# Apache neu starten
sudo systemctl restart apache2
```

### Schritt 3: easyONBOARDING installieren

```bash
# Gehen Sie zum Web-Root
cd /var/www/html

# Repository klonen
sudo git clone https://github.com/yourorg/easyONBOARDING.git
cd easyONBOARDING

# Berechtigungen setzen
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
sudo chmod -R 777 logs/
```

### Schritt 4: Composer installieren

```bash
# Composer Download
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Abhängigkeiten installieren
composer install
```

### Schritt 5: MySQL-Datenbank einrichten

```bash
# MySQL öffnen
sudo mysql -u root -p

# SQL ausführen (in MySQL)
mysql> CREATE DATABASE easyonboarding CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
mysql> source /var/www/html/easyONBOARDING/database.sql;
mysql> source /var/www/html/easyONBOARDING/database_phase6_extensions.sql;
mysql> exit;
```

### Schritt 6: Konfiguration

```bash
# config.php bearbeiten
sudo nano /var/www/html/easyONBOARDING/config.php

# Datenbank-Daten eintragen:
define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASS', 'your-password');
define('DB_NAME', 'easyonboarding');
```

### Schritt 7: Setup starten

```bash
# Browser öffnen
http://your-server-ip/easyONBOARDING/setup.php
```

✅ **Installation abgeschlossen!**

---

## 🌐 Production Deployment (Apache + SSL)

### Schritt 1: SSL-Zertifikat installieren

```bash
# Mit Let's Encrypt (Empfohlen)
sudo apt install -y certbot python3-certbot-apache

# Zertifikat erstellen
sudo certbot certonly --apache -d yourdomain.com

# Apache SSL aktivieren
sudo a2enmod ssl
sudo a2ensite default-ssl.conf
```

### Schritt 2: Virtual Host konfigurieren

**Bearbeiten Sie `/etc/apache2/sites-available/easyonboarding.conf`:**

```apache
<VirtualHost *:80>
    ServerName yourdomain.com
    ServerAdmin admin@yourdomain.com
    DocumentRoot /var/www/easyonboarding

    # Redirect zu HTTPS
    Redirect permanent / https://yourdomain.com/
</VirtualHost>

<VirtualHost *:443>
    ServerName yourdomain.com
    ServerAdmin admin@yourdomain.com
    DocumentRoot /var/www/easyonboarding

    # SSL Konfiguration
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/yourdomain.com/privkey.pem

    <Directory /var/www/easyonboarding>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Security Headers
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
</VirtualHost>
```

### Schritt 3: Virtual Host aktivieren

```bash
sudo a2ensite easyonboarding.conf
sudo apache2ctl configtest  # Sollte "Syntax OK" ausgeben
sudo systemctl restart apache2
```

### Schritt 4: Sicherheit

```bash
# .htaccess überprüfen
# Sollte sich im Root-Verzeichnis befinden und Security Headers definieren

# PHP-Sicherheit
sudo nano /etc/php/8.x/apache2/php.ini
# Ändern Sie:
display_errors = Off
log_errors = On
error_log = /var/log/php_errors.log
```

### Schritt 5: Backup einrichten

```bash
# Tägliches Backup-Skript
sudo nano /usr/local/bin/backup-easyonboarding.sh

#!/bin/bash
BACKUP_DIR="/backups/easyonboarding"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Datenbank-Backup
mysqldump -u root -p'password' easyonboarding > $BACKUP_DIR/db_$DATE.sql

# Dateien-Backup
tar -czf $BACKUP_DIR/files_$DATE.tar.gz /var/www/easyonboarding

# Alte Backups löschen (älter als 30 Tage)
find $BACKUP_DIR -type f -mtime +30 -delete

# Cron-Job hinzufügen
sudo crontab -e
# Hinzufügen: 0 2 * * * /usr/local/bin/backup-easyonboarding.sh
```

---

## 🔧 Nach der Installation

### Schritt 1: Admin-Benutzer ändern

```
Admin Panel → Benutzer-Management → admin bearbeiten
Ändern Sie das Standard-Passwort!
```

### Schritt 2: Email konfigurieren

```
Admin Panel → 🎨 Customization → Branding
Geben Sie Ihre Support-Email & Telefon ein
```

### Schritt 3: Ersten Workflow erstellen

```
Admin Panel → 🏗️ Workflow Builder
1. Neuer Workflow
2. Schritte hinzufügen
3. Speichern & Aktivieren
```

### Schritt 4: LDAP konfigurieren (optional)

**Bearbeiten Sie `config.php`:**

```php
define('LDAP_ENABLED', true);
define('LDAP_SERVER', 'ldap://your-domain.com');
define('LDAP_USER', 'CN=service.account,CN=Users,DC=domain,DC=com');
define('LDAP_PASS', 'password');
define('LDAP_BASE_DN', 'DC=domain,DC=com');
```

---

## ⚠️ Häufige Probleme

### Problem: "PDO-Fehler: Verbindung verweigert"
```
Lösung:
1. Überprüfen Sie, ob MySQL läuft: sudo systemctl status mysql
2. Überprüfen Sie DB-Credentials in config.php
3. Starten Sie MySQL neu: sudo systemctl restart mysql
```

### Problem: ".htaccess funktioniert nicht"
```
Lösung:
1. Apache-Rewrite aktivieren: sudo a2enmod rewrite
2. Überprüfen Sie AllowOverride in Virtual Host: AllowOverride All
3. Apache neu starten: sudo systemctl restart apache2
```

### Problem: "Permission denied" Fehler
```
Lösung:
sudo chown -R www-data:www-data /var/www/easyonboarding
sudo chmod -R 755 /var/www/easyonboarding
sudo chmod -R 777 /var/www/easyonboarding/logs
```

### Problem: "TCPDF nicht gefunden"
```
Lösung:
cd /var/www/easyonboarding
composer require tecnickcom/tcpdf
```

---

## ✅ Installations-Checkliste

```
Vor dem Live-Betrieb überprüfen:

[ ] PHP 8.0+ installiert
[ ] MySQL läuft
[ ] Apache mit mod_rewrite
[ ] Datenbanken erstellt
[ ] config.php konfiguriert
[ ] Admin-Passwort geändert
[ ] Email-Service konfiguriert
[ ] SSL-Zertifikat installiert
[ ] Firewall konfiguriert (Port 80, 443)
[ ] Backups eingerichtet
[ ] Logs konfiguriert
[ ] Erste Benutzer erstellt
[ ] Workflows definiert
[ ] Tests durchgeführt
```

---

## 📞 Support

Bei Problemen:
1. Siehe **TROUBLESHOOTING.md**
2. Kontrollieren Sie die Logs: `logs/error.log`
3. Kontaktieren Sie: support@example.com

---

**Version:** 3.0.0  
**Letzte Aktualisierung:** 2025
