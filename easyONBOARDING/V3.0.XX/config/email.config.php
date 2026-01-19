<?php
/**
 * EMAIL CONFIGURATION - Phase 6
 * SMTP Settings, Templates & Email-Service Setup
 * 
 * Version: 1.0
 * Date: 2025-10-24
 */

// ===== SMTP CONFIGURATION =====

define('EMAIL_SMTP_HOST', getenv('SMTP_HOST') ?: 'smtp.company.local');
define('EMAIL_SMTP_PORT', getenv('SMTP_PORT') ?: 587);
define('EMAIL_SMTP_USER', getenv('SMTP_USER') ?: 'onboarding@company.local');
define('EMAIL_SMTP_PASS', getenv('SMTP_PASS') ?: '');
define('EMAIL_SMTP_ENCRYPTION', getenv('SMTP_ENCRYPTION') ?: 'tls');
define('EMAIL_FROM_ADDRESS', getenv('EMAIL_FROM') ?: 'onboarding@company.local');
define('EMAIL_FROM_NAME', getenv('EMAIL_FROM_NAME') ?: 'easyONBOARDING System');
define('EMAIL_REPLY_TO', getenv('EMAIL_REPLY_TO') ?: 'support@company.local');

// ===== EMAIL SERVICE SETTINGS =====

define('EMAIL_MAX_RETRIES', 3);
define('EMAIL_RETRY_DELAY', 3600); // 1 Stunde
define('EMAIL_BATCH_SIZE', 50);
define('EMAIL_USE_PHPMAILER', true);
define('EMAIL_USE_PHP_MAIL_FALLBACK', true);
define('EMAIL_DEBUG', getenv('EMAIL_DEBUG') ?: false);

// ===== EMAIL TEMPLATES CONFIGURATION =====

$EMAIL_TEMPLATES = [
    'onboarding_start' => [
        'name' => 'Willkommen zum Onboarding',
        'subject' => 'Willkommen, {employee_name}! 🎉',
        'description' => 'Wird gesendet, wenn ein neuer Onboarding-Fall erstellt wird',
        'variables' => ['employee_name', 'job_title', 'department', 'start_date', 'manager_name', 'company_name'],
        'enabled' => true,
    ],
    
    'approval_required' => [
        'name' => 'Genehmigung erforderlich',
        'subject' => 'Genehmigung erforderlich - Fall {case_number}',
        'description' => 'Wird gesendet, wenn eine Genehmigung erforderlich ist',
        'variables' => ['case_number', 'employee_name', 'approval_type', 'approval_url'],
        'enabled' => true,
    ],
    
    'approval_approved' => [
        'name' => 'Genehmigung bestätigt',
        'subject' => 'Genehmigung bestätigt - Fall {case_number}',
        'description' => 'Wird gesendet, wenn eine Genehmigung erfolgt ist',
        'variables' => ['case_number', 'employee_name', 'approved_by', 'approval_date'],
        'enabled' => true,
    ],
    
    'task_reminder' => [
        'name' => 'Aufgaben-Erinnerung',
        'subject' => 'Erinnerung: {task_name} - Fällig am {due_date}',
        'description' => 'Erinnerung für anstehende Aufgaben',
        'variables' => ['task_name', 'due_date', 'assigned_by', 'task_url'],
        'enabled' => true,
    ],
    
    'onboarding_completion' => [
        'name' => 'Onboarding abgeschlossen',
        'subject' => 'Willkommen im Team! Dein Onboarding ist abgeschlossen 🎊',
        'description' => 'Wird gesendet, wenn das Onboarding abgeschlossen ist',
        'variables' => ['employee_name', 'completion_date', 'first_day_info', 'hr_contact'],
        'enabled' => true,
    ],
    
    'escalation_alert' => [
        'name' => 'Eskalations-Warnung',
        'subject' => 'ESKALATION: Fall {case_number} erfordert Aufmerksamkeit',
        'description' => 'Warnung bei überfälligen Genehmigungen',
        'variables' => ['case_number', 'employee_name', 'overdue_days', 'escalation_contact'],
        'enabled' => true,
    ],
    
    'feedback_request' => [
        'name' => 'Feedback-Anfrage',
        'subject' => 'Wir möchten Ihre Meinung zum Onboarding erfahren',
        'description' => 'Anfrage für Onboarding-Feedback',
        'variables' => ['employee_name', 'feedback_url', 'survey_deadline'],
        'enabled' => true,
    ],
];

// ===== HTML EMAIL TEMPLATES =====

function getEmailTemplate($templateKey) {
    global $EMAIL_TEMPLATES;
    
    if (!isset($EMAIL_TEMPLATES[$templateKey])) {
        return null;
    }
    
    $template = $EMAIL_TEMPLATES[$templateKey];
    
    // HTML Body generieren
    $htmlBody = getEmailHtmlBody($templateKey);
    
    return [
        'name' => $template['name'],
        'subject' => $template['subject'],
        'description' => $template['description'],
        'variables' => $template['variables'],
        'enabled' => $template['enabled'],
        'html_body' => $htmlBody,
        'text_body' => getEmailTextBody($templateKey),
    ];
}

/**
 * HTML-Email Body Templates
 */
function getEmailHtmlBody($templateKey) {
    $baseUrl = defined('SITE_URL') ? SITE_URL : 'http://onboarding.local';
    
    $templates = [
        'onboarding_start' => <<<HTML
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #2563eb; color: white; padding: 20px; border-radius: 5px; text-align: center; }
        .content { background: #f9fafb; padding: 20px; margin: 20px 0; border-left: 4px solid #2563eb; }
        .button { display: inline-block; background: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 10px 0; }
        .footer { text-align: center; font-size: 12px; color: #999; margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎉 Willkommen im Team!</h1>
        </div>
        
        <div class="content">
            <p>Liebe/r <strong>{employee_name}</strong>,</p>
            <p>herzlich willkommen in unserem Unternehmen!</p>
            <p>Dein Onboarding-Prozess hat eben begonnen. In den nächsten Wochen wirst du von unserem Team betreut und bei allen Schritten unterstützt.</p>
            
            <h3>📋 Deine Informationen:</h3>
            <ul>
                <li><strong>Position:</strong> {job_title}</li>
                <li><strong>Abteilung:</strong> {department}</li>
                <li><strong>Startdatum:</strong> {start_date}</li>
                <li><strong>Dein Manager:</strong> {manager_name}</li>
            </ul>
        </div>
        
        <p style="text-align: center;">
            <a href="{onboarding_url}" class="button">Zum Onboarding Portal</a>
        </p>
        
        <div class="footer">
            <p>Mit freundlichen Grüßen<br>Das easyONBOARDING Team</p>
            <p>{company_name}</p>
        </div>
    </div>
</body>
</html>
HTML,

        'approval_required' => <<<HTML
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #f59e0b; color: white; padding: 20px; border-radius: 5px; text-align: center; }
        .alert { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0; }
        .button { display: inline-block; background: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⏳ Genehmigung erforderlich</h1>
        </div>
        
        <div class="alert">
            <p><strong>Ein Onboarding-Fall wartet auf Ihre Genehmigung:</strong></p>
            <p>Fall: <strong>{case_number}</strong><br>
            Mitarbeiter: <strong>{employee_name}</strong><br>
            Art: <strong>{approval_type}</strong></p>
        </div>
        
        <p style="text-align: center;">
            <a href="{approval_url}" class="button">Jetzt genehmigen</a>
        </p>
        
        <div style="margin-top: 30px; font-size: 12px; color: #999; border-top: 1px solid #eee; padding-top: 20px;">
            <p>Dies ist eine automatisch generierte Nachricht. Bitte antworten Sie nicht auf diese E-Mail.</p>
        </div>
    </div>
</body>
</html>
HTML,

        'task_reminder' => <<<HTML
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #7c3aed; color: white; padding: 20px; border-radius: 5px; text-align: center; }
        .task-box { background: #f3f4f6; padding: 15px; margin: 20px 0; border-left: 4px solid #7c3aed; }
        .button { display: inline-block; background: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📌 Aufgaben-Erinnerung</h1>
        </div>
        
        <p>Liebe/r Nutzer,</p>
        <p>Sie haben eine anstehende Aufgabe im Onboarding-Prozess:</p>
        
        <div class="task-box">
            <h3>{task_name}</h3>
            <p><strong>Fällig am:</strong> {due_date}</p>
            <p><strong>Zugewiesen von:</strong> {assigned_by}</p>
        </div>
        
        <p style="text-align: center;">
            <a href="{task_url}" class="button">Zur Aufgabe</a>
        </p>
    </div>
</body>
</html>
HTML,

        'onboarding_completion' => <<<HTML
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #10b981; color: white; padding: 20px; border-radius: 5px; text-align: center; }
        .content { background: #ecfdf5; padding: 20px; margin: 20px 0; border-left: 4px solid #10b981; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎊 Willkommen im Team!</h1>
        </div>
        
        <div class="content">
            <p>Liebe/r <strong>{employee_name}</strong>,</p>
            <p>herzlichen Glückwunsch! Dein Onboarding-Prozess ist nun abgeschlossen.</p>
            <p>Du bist jetzt vollständig ins Team integriert und kannst mit vollem Elan durchstarten.</p>
            
            <h3>📋 Was ist zu tun?</h3>
            <p>{first_day_info}</p>
            
            <h3>❓ Fragen?</h3>
            <p>Bei Fragen kannst du dich jederzeit an folgende Person wenden:<br>
            <strong>{hr_contact}</strong></p>
        </div>
    </div>
</body>
</html>
HTML,
    ];
    
    return $templates[$templateKey] ?? '<p>Template not found</p>';
}

/**
 * Text Email Body Templates
 */
function getEmailTextBody($templateKey) {
    $templates = [
        'onboarding_start' => "Willkommen im Team!\n\nLiebe/r {employee_name},\n\nHerzlich willkommen! Dein Onboarding-Prozess hat begonnen.\n\nPosition: {job_title}\nAbteilung: {department}\nStartdatum: {start_date}\nDein Manager: {manager_name}\n\nZum Onboarding Portal: {onboarding_url}",
        
        'approval_required' => "Genehmigung erforderlich\n\nEin Onboarding-Fall wartet auf Ihre Genehmigung:\n\nFall: {case_number}\nMitarbeiter: {employee_name}\nArt: {approval_type}\n\nZur Genehmigung: {approval_url}",
        
        'task_reminder' => "Aufgaben-Erinnerung\n\nSie haben eine anstehende Aufgabe:\n\n{task_name}\nFällig am: {due_date}\nZugewiesen von: {assigned_by}\n\nZur Aufgabe: {task_url}",
        
        'onboarding_completion' => "Glückwunsch! Dein Onboarding ist abgeschlossen!\n\nLiebe/r {employee_name},\n\nDein Onboarding-Prozess ist nun beendet. Du bist vollständig ins Team integriert.\n\n{first_day_info}\n\nBei Fragen: {hr_contact}",
    ];
    
    return $templates[$templateKey] ?? 'Template not found';
}

// ===== EMAIL VALIDATION =====

function validateEmailRecipients($recipients) {
    if (is_string($recipients)) {
        $recipients = [$recipients];
    }
    
    foreach ($recipients as $email) {
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return false;
        }
    }
    
    return true;
}

// ===== CRON JOB HELPER =====

function shouldRunEmailCron() {
    $lockFile = sys_get_temp_dir() . '/email_cron.lock';
    
    if (file_exists($lockFile)) {
        $lastRun = filemtime($lockFile);
        if (time() - $lastRun < 300) { // 5 Minuten
            return false;
        }
    }
    
    touch($lockFile);
    return true;
}

// ===== EMAIL SERVICE INITIALIZATION =====

function initializeEmailService() {
    // Prüfe ob PHPMailer vorhanden ist
    if (!file_exists(__DIR__ . '/../vendor/autoload.php')) {
        // Fallback zu PHP mail()
        define('USE_PHP_MAIL', true);
        return;
    }
    
    // PHPMailer initialisieren
    require_once __DIR__ . '/../vendor/autoload.php';
    define('USE_PHPMAILER', true);
}

?>
