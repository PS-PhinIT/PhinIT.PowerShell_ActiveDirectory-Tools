# 🔧 Troubleshooting Guide

**Häufige Probleme und Lösungen**

---

## 🆘 Probleme & Lösungen

### ⚠️ Login funktioniert nicht

#### Problem: "Benutzername oder Passwort falsch"
```
Symptome:
- Login schlägt fehl, auch mit richtigen Credentials
- Fehlermeldung auch bei admin/admin123

Lösungen:
1. Session löschen (Browser Cache/Cookies)
2. Browser DevTools: F12 → Application → Cookies → Alle löschen
3. Seite neu laden: Ctrl+Shift+R (Hard Refresh)
4. Inkognito-Modus testen
5. Benutzer in DB prüfen:
   mysql> SELECT id, username, email, is_active FROM users WHERE username='admin';
6. Password zurücksetzen (Database):
   mysql> UPDATE users SET password=MD5('admin123') WHERE username='admin';
```

#### Problem: "403 Forbidden"
```
Symptome:
- Zugriff auf login.php wird blockiert
- .htaccess Fehler

Lösungen:
1. .htaccess korrekt? Datei sollte im Root existieren
2. Apache mod_rewrite aktivieren:
   sudo a2enmod rewrite
   sudo systemctl restart apache2

3. Virtual Host AllowOverride aktivieren:
   <Directory /var/www/easyonboarding>
       AllowOverride All
   </Directory>

4. Dateiberechtigungen prüfen:
   chmod 644 /var/www/easyonboarding/.htaccess
```

---

### 💾 Datenbank-Probleme

#### Problem: "PDO: Verbindung verweigert"
```
Symptome:
- Fehler: "SQLSTATE[HY000]: General error: 2003 Can't connect to MySQL server"
- Login funktioniert nicht
- Alle Seiten zeigen Fehler

Lösungen:
1. MySQL läuft?
   sudo systemctl status mysql
   
2. MySQL starten, falls gestoppt:
   sudo systemctl start mysql

3. Credentials prüfen (config.php):
   define('DB_HOST', 'localhost');
   define('DB_USER', 'root');
   define('DB_PASS', 'correct-password');
   define('DB_NAME', 'easyonboarding');

4. MySQL von außen testen:
   mysql -u root -p -h localhost
   # Passwort eingeben

5. DB existiert?
   mysql> SHOW DATABASES;
   mysql> USE easyonboarding;

6. Tabellen existieren?
   mysql> SHOW TABLES;
   # Sollte mindestens users, workflows, onboarding_cases zeigen
```

#### Problem: "Tabelle existiert nicht"
```
Symptome:
- Fehler: "Table 'easyonboarding.workflows' doesn't exist"
- Einige Funktionen funktionieren, andere nicht

Lösungen:
1. Setup nochmal ausführen:
   http://localhost/easyONBOARDING/setup.php

2. SQL-Skripte manuell ausführen:
   mysql -u root -p easyonboarding < database.sql
   mysql -u root -p easyonboarding < database_phase6_extensions.sql

3. Tabellen überprüfen:
   mysql> DESCRIBE workflows;
   mysql> DESCRIBE onboarding_cases;
```

---

### 📧 Email-Probleme

#### Problem: "Emails werden nicht versendet"
```
Symptome:
- Neue Fälle erstellt, aber keine Benachrichtigungen
- Keine Fehler in Logs

Lösungen:
1. Email-Config überprüfen (config.php):
   define('EMAIL_SMTP_HOST', 'smtp.gmail.com');
   define('EMAIL_SMTP_USER', 'your-email@gmail.com');
   define('EMAIL_SMTP_PASS', 'app-password');

2. SMTP-Verbindung testen (PHP):
   php -r "
   require 'vendor/autoload.php';
   \$mail = new PHPMailer();
   \$mail->isSMTP();
   \$mail->Host = 'smtp.gmail.com';
   \$mail->SMTPAuth = true;
   \$mail->Username = 'your-email@gmail.com';
   \$mail->Password = 'app-password';
   \$mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
   \$mail->Port = 587;
   if (\$mail->smtpConnect()) echo 'OK'; else echo 'FAIL';
   "

3. Emails in Datenbank prüfen:
   mysql> SELECT * FROM email_queue WHERE status='pending';

4. Cron-Job prüfen (für Email-Versand):
   crontab -l
   # Sollte einen Job für scripts/cron_tasks.php haben

5. PHPMailer installiert?
   composer list | grep phpmailer
```

#### Problem: "Gmail App-Passwort funktioniert nicht"
```
Lösungen:
1. 2FA aktivieren in Google Account:
   https://myaccount.google.com/security

2. App-Password generieren:
   https://myaccount.google.com/apppasswords
   - "Mail" + "Windows" wählen
   - 16-stelliges Passwort kopieren

3. In config.php eintragen:
   define('EMAIL_SMTP_PASS', '16-digit-password');

4. Testen mit GMail:
   telnet smtp.gmail.com 587
   # EHLO smtp.gmail.com
   # STARTTLS
   # AUTH LOGIN
   # [encoded username]
   # [encoded password]
```

---

### 🔐 Sicherheits-Probleme

#### Problem: "CSRF Token ist ungültig"
```
Symptome:
- Formular senden zeigt: "CSRF Token invalid"
- Häufig nach Session-Wechsel

Lösungen:
1. Session-Timeout prüfen (config.php):
   ini_set('session.gc_maxlifetime', 3600); // 1 Stunde

2. Session-Verzeichnis überprüfen:
   ls -la /tmp/  # Linux
   # Windows: Prüfe php.ini session.save_path

3. Token regenerieren in Code:
   if (isset($_POST) && !empty($_POST)) {
       $token = $_SESSION['csrf_token'] ?? generateCSRFToken();
   }
```

#### Problem: "SQL Injection Warning"
```
Symptome:
- Sicherheitsprüfungen warnen vor SQL-Anfälligkeit
- Die Applikation nutzt PDO Prepared Statements, aber warnt trotzdem

Lösungen:
1. Code überprüfen - sollte Prepared Statements nutzen:
   $stmt = $db->prepare('SELECT * FROM users WHERE email = ?');
   $stmt->execute([$email]);
   # ✅ RICHTIG

   # ❌ FALSCH:
   $query = "SELECT * FROM users WHERE email = '$email'";
   $result = $db->query($query);

2. Bei Custom-Code: Immer Prepared Statements verwenden
```

---

### 📄 PDF-Export Probleme

#### Problem: "PDF wird nicht generiert"
```
Symptome:
- 💾 PDF Export Button zeigt, aber PDF öffnet nicht
- Fehler: "TCPDF not found"
- Leere Seite

Lösungen:
1. TCPDF installiert?
   composer show | grep tcpdf

2. TCPDF installieren, falls nicht vorhanden:
   composer require tecnickcom/tcpdf

3. Berechtigungen für exports/ Verzeichnis:
   mkdir -p exports/
   chmod 777 exports/

4. PDF-Generator testen:
   cd easyONBOARDING
   php -r "
   require 'vendor/autoload.php';
   \$pdf = new TCPDF();
   \$pdf->AddPage();
   \$pdf->SetFont('helvetica', 'B', 16);
   \$pdf->Cell(0, 10, 'Test PDF');
   \$pdf->Output('test.pdf', 'D');
   "
```

---

### ⚡ Performance-Probleme

#### Problem: "Seite lädt langsam"
```
Symptome:
- Admin Dashboard braucht >5 Sekunden
- Forms sind träge
- Database ist langsam

Lösungen:
1. Database Queries optimieren:
   mysql> EXPLAIN SELECT * FROM onboarding_cases WHERE status='completed';
   # Sollte Indexes nutzen

2. Indexes überprüfen/erstellen:
   mysql> SHOW INDEX FROM onboarding_cases;
   mysql> ALTER TABLE onboarding_cases ADD INDEX idx_status (status);
   mysql> ALTER TABLE onboarding_cases ADD INDEX idx_user_id (created_by);

3. Query-Cache aktivieren:
   mysql> SET SESSION query_cache_type = ON;
   mysql> SHOW VARIABLES LIKE 'query_cache%';

4. PHP-Performance prüfen:
   # Loggen Sie Query-Zeiten in config.php:
   define('DEBUG', true);
   define('LOG_QUERIES', true);

5. Datenbankgröße überprüfen:
   mysql> SELECT table_name, ROUND(data_length/1024/1024) AS MB FROM information_schema.tables 
          WHERE table_schema='easyonboarding' ORDER BY data_length DESC;

6. Old Logs löschen:
   mysql> DELETE FROM audit_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
```

#### Problem: "Speicher-Fehler (Out of Memory)"
```
Symptome:
- Fehler: "Fatal error: Allowed memory size of 134217728 bytes exhausted"
- Datei-Upload schlägt fehl
- CSV-Export zeigt Fehler

Lösungen:
1. Memory Limit erhöhen (php.ini):
   memory_limit = 256M  # Erhöhen von default 128M

2. Oder in config.php:
   ini_set('memory_limit', '256M');

3. Script-Timeout erhöhen:
   max_execution_time = 300  # 5 Minuten
   # Oder in Code:
   set_time_limit(300);

4. Upload-Größe erhöhen:
   upload_max_filesize = 100M
   post_max_size = 100M
```

---

### 🔗 API-Probleme

#### Problem: "API gibt 401 Unauthorized"
```
Symptome:
- API-Requests schlagen mit 401 fehl
- Fehler: "Invalid API Key"

Lösungen:
1. API-Key überprüfen:
   - Korrekt kopiert? (Leerzeichen beachten!)
   - Nicht abgelaufen?
   - Authorization Header korrekt?
   
2. Authorization Header prüfen:
   Authorization: Bearer sk_live_...
   # Nicht nur der Key, sondern "Bearer " + Key

3. API-Key in Database überprüfen:
   mysql> SELECT * FROM api_keys WHERE is_active=1;

4. Header-Case beachten:
   # PHP konvertiert alle Header zu uppercase mit HTTP_ Prefix
   "Authorization" → "HTTP_AUTHORIZATION"
```

#### Problem: "API gibt 400 Bad Request"
```
Symptome:
- Validation-Fehler
- Fehler: "Invalid email format", "Missing required field"

Lösungen:
1. Request-Body überprüfen:
   - Ist es valid JSON?
   - Alle erforderlichen Felder?
   - Datentypen korrekt? (string, int, date)

2. Mit curl testen:
   curl -X POST http://localhost/api/create_case.php \
     -H "Authorization: Bearer key" \
     -H "Content-Type: application/json" \
     -d '{"employee_first_name":"Test"...}'

3. Response-Details prüfen:
   - Error-Message lesen
   - Error-Code beachten
   - Details-Feld für mehr Infos
```

---

### 🌐 LDAP-Probleme

#### Problem: "LDAP-Login funktioniert nicht"
```
Symptome:
- LDAP-Tab zeigt, aber Login schlägt fehl
- Fehler: "LDAP Bind failed"

Lösungen:
1. LDAP-Server erreichen?
   telnet ad.company.local 389
   # Sollte verbinden

2. LDAP-Config überprüfen (config.php):
   define('LDAP_ENABLED', true);
   define('LDAP_SERVER', 'ldap://ad.company.local');
   define('LDAP_PORT', 389);
   define('LDAP_BIND_USER', 'CN=svc_account,...');
   define('LDAP_BIND_PASS', 'password');

3. Service-Account Credentials überprüfen:
   - Existiert der Account?
   - Passwort korrekt?
   - Hat genug Rechte zum User-Search?

4. LDAP-Verbindung mit PHP testen:
   php -r "
   \$ldap = ldap_connect('ad.company.local', 389);
   if (\$ldap) {
       \$bind = ldap_bind(\$ldap, 'CN=svc_account,...', 'password');
       echo \$bind ? 'Connected!' : 'Bind failed';
   }
   "

5. User-Filter überprüfen:
   # Sollte der User zu finden sein?
   # Filter: (&(objectClass=user)(sAMAccountName=username))
```

---

## 🧪 Diagnose-Tools

### Log-Dateien überprüfen
```bash
# Error Log
tail -f logs/error.log

# Audit Log (User-Aktionen)
tail -f logs/audit.log

# API Requests
tail -f logs/api.log

# All logs zusammen
tail -f logs/*.log
```

### Datenbank-Status
```bash
# Verbindung überprüfen
mysql -u root -p -e "SELECT 1"

# Database-Größe
mysql -e "SELECT table_name, ROUND(data_length/1024/1024) AS MB FROM information_schema.tables WHERE table_schema='easyonboarding' ORDER BY data_length DESC"

# Aktive Connections
mysql -e "SHOW PROCESSLIST"
```

### PHP-Info
```bash
# PHP-Version
php --version

# Installierte Extensions
php -m | grep -E "pdo|mysql|curl|json"

# php.ini Location
php -i | grep "php.ini"

# php.ini Settings
php -i | grep -E "memory_limit|max_execution_time|upload_max_filesize"
```

---

## 📞 Support & Weitere Hilfe

Falls das Problem nicht gelöst ist:

1. **Logs prüfen:**
   - `logs/error.log`
   - `logs/audit.log`
   - Browser Console (F12)

2. **Forum/Community:**
   - Siehe README.md für Support-Links

3. **Mit Informationen kontaktieren:**
   - Welche Fehlermeldung?
   - Was genau ist der erwartete vs. tatsächliche Behavior?
   - Letzte Log-Einträge
   - Browser & PHP-Version
   - Reproduzierbarkeitss-Schritte

---

**Version:** 3.0.0  
**Letzte Aktualisierung:** 2025
