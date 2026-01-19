<?php
/**
 * EmailNotificationService
 * E-Mail Benachrichtigungs-Service für das Onboarding-System
 * Unterstützt Template-Rendering, Scheduling, Retry-Logik und Logging
 * 
 * Version: 1.0
 * Date: 2025-10-24
 */

class EmailNotificationService
{
    private $db;
    private $config;
    private $logger;
    
    // Email-Konfiguration
    private $emailConfig = [
        'from_email' => 'onboarding@company.local',
        'from_name' => 'easyONBOARDING System',
        'smtp_host' => 'smtp.company.local',
        'smtp_port' => 587,
        'smtp_user' => 'onboarding@company.local',
        'smtp_password' => '', // Sollte aus Env-Variable kommen
        'smtp_encryption' => 'tls',
        'max_retries' => 3,
        'retry_delay' => 3600, // 1 Stunde
    ];

    public function __construct($db, $config = [])
    {
        $this->db = $db;
        $this->config = array_merge($this->emailConfig, $config);
    }

    /**
     * Sende eine E-Mail-Benachrichtigung
     */
    public function sendNotification($caseId, $notificationType, $recipientEmail, $recipientId = null, $customData = [])
    {
        try {
            // Template abrufen
            $template = $this->getEmailTemplate($notificationType);
            if (!$template) {
                throw new Exception("Email template '{$notificationType}' not found");
            }

            // Daten für Template vorbereiten
            $caseData = $this->getCaseData($caseId);
            $templateData = array_merge($caseData, $customData);

            // Template rendern
            $subject = $this->renderTemplate($template['subject'], $templateData);
            $bodyHtml = $this->renderTemplate($template['body_html'], $templateData);
            $bodyText = $this->renderTemplate($template['body_text'] ?? '', $templateData);

            // Benachrichtigung in Datenbank speichern
            $notificationId = $this->saveNotification(
                $caseId,
                $notificationType,
                $recipientEmail,
                $recipientId,
                $subject,
                $bodyHtml,
                'pending'
            );

            // E-Mail senden
            $sent = $this->sendEmail(
                $recipientEmail,
                $subject,
                $bodyHtml,
                $bodyText
            );

            if ($sent) {
                $this->updateNotificationStatus($notificationId, 'sent', date('Y-m-d H:i:s'));
                return true;
            } else {
                $this->updateNotificationStatus($notificationId, 'failed', null, 'Email sending failed');
                return false;
            }

        } catch (Exception $e) {
            logAction(0, 'email_notification_error', 'Error sending notification: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Plane eine E-Mail-Benachrichtigung
     */
    public function scheduleNotification($caseId, $notificationType, $recipientEmail, $scheduledDate, $recipientId = null, $customData = [])
    {
        try {
            $template = $this->getEmailTemplate($notificationType);
            if (!$template) {
                throw new Exception("Email template not found");
            }

            $caseData = $this->getCaseData($caseId);
            $templateData = array_merge($caseData, $customData);

            $subject = $this->renderTemplate($template['subject'], $templateData);
            $bodyHtml = $this->renderTemplate($template['body_html'], $templateData);

            // In DB speichern mit geplantes Sendedatum
            $stmt = $this->db->prepare('
                INSERT INTO email_notifications 
                (case_id, recipient_email, recipient_id, notification_type, subject, message_body, status, scheduled_date, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
            ');

            $stmt->execute([
                $caseId,
                $recipientEmail,
                $recipientId,
                $notificationType,
                $subject,
                $bodyHtml,
                'pending',
                $scheduledDate
            ]);

            return $this->db->lastInsertId();
        } catch (Exception $e) {
            logAction(0, 'email_schedule_error', $e->getMessage());
            return false;
        }
    }

    /**
     * Sende alle ausstehenden & geplanten E-Mails
     * (Sollte über CRON/Scheduler ausgeführt werden)
     */
    public function processPendingNotifications()
    {
        try {
            // Finde alle E-Mails die gesendet werden sollen
            $stmt = $this->db->prepare('
                SELECT * FROM email_notifications
                WHERE status = "pending"
                AND (scheduled_date IS NULL OR scheduled_date <= NOW())
                AND retry_count < max_retries
                ORDER BY created_at ASC
                LIMIT 50
            ');
            $stmt->execute();
            $notifications = $stmt->fetchAll(PDO::FETCH_ASSOC);

            $sentCount = 0;
            foreach ($notifications as $notification) {
                if ($this->sendEmail(
                    $notification['recipient_email'],
                    $notification['subject'],
                    $notification['message_body']
                )) {
                    $this->updateNotificationStatus($notification['id'], 'sent', date('Y-m-d H:i:s'));
                    $sentCount++;
                } else {
                    // Retry-Count erhöhen
                    $this->incrementRetryCount($notification['id']);
                }
            }

            return $sentCount;
        } catch (Exception $e) {
            logAction(0, 'email_process_error', $e->getMessage());
            return 0;
        }
    }

    /**
     * Sende eine E-Mail mit PHPMailer oder Mail-Funktion
     */
    private function sendEmail($to, $subject, $bodyHtml, $bodyText = '')
    {
        try {
            // Prüfe ob PHPMailer verfügbar
            if (class_exists('PHPMailer\PHPMailer\PHPMailer')) {
                return $this->sendViaPhpMailer($to, $subject, $bodyHtml, $bodyText);
            }
            
            // Fallback: PHP mail() Funktion
            return $this->sendViaPhpMail($to, $subject, $bodyHtml);

        } catch (Exception $e) {
            logAction(0, 'email_send_error', $e->getMessage());
            return false;
        }
    }

    /**
     * Sende via PHPMailer
     */
    private function sendViaPhpMailer($to, $subject, $bodyHtml, $bodyText = '')
    {
        try {
            $mail = new \PHPMailer\PHPMailer\PHPMailer(true);
            
            // SMTP-Konfiguration
            $mail->isSMTP();
            $mail->Host = $this->config['smtp_host'];
            $mail->SMTPAuth = true;
            $mail->Username = $this->config['smtp_user'];
            $mail->Password = $this->config['smtp_password'];
            $mail->SMTPSecure = $this->config['smtp_encryption'];
            $mail->Port = $this->config['smtp_port'];

            // Absender & Empfänger
            $mail->setFrom($this->config['from_email'], $this->config['from_name']);
            $mail->addAddress($to);

            // Inhalte
            $mail->isHTML(true);
            $mail->Subject = $subject;
            $mail->Body = $bodyHtml;
            if (!empty($bodyText)) {
                $mail->AltBody = $bodyText;
            }

            // Sende
            return $mail->send();

        } catch (\PHPMailer\PHPMailer\Exception $e) {
            logAction(0, 'phpmailer_error', $e->errorMessage());
            return false;
        }
    }

    /**
     * Sende via PHP mail()
     */
    private function sendViaPhpMail($to, $subject, $bodyHtml)
    {
        $headers = "MIME-Version: 1.0\r\n";
        $headers .= "Content-type: text/html; charset=UTF-8\r\n";
        $headers .= "From: {$this->config['from_email']}\r\n";
        $headers .= "Reply-To: {$this->config['from_email']}\r\n";

        return mail($to, $subject, $bodyHtml, $headers);
    }

    /**
     * Lade E-Mail-Template
     */
    private function getEmailTemplate($templateKey)
    {
        try {
            $stmt = $this->db->prepare('
                SELECT * FROM email_templates
                WHERE template_key = ? OR template_name = ?
                AND is_active = TRUE
                LIMIT 1
            ');
            $stmt->execute([$templateKey, $templateKey]);
            return $stmt->fetch(PDO::FETCH_ASSOC);
        } catch (Exception $e) {
            return null;
        }
    }

    /**
     * Abrufen von Case-Daten für Template
     */
    private function getCaseData($caseId)
    {
        try {
            $stmt = $this->db->prepare('
                SELECT c.*, u.first_name, u.last_name, u.email as manager_email
                FROM onboarding_cases c
                LEFT JOIN users u ON c.manager_id = u.id
                WHERE c.id = ?
                LIMIT 1
            ');
            $stmt->execute([$caseId]);
            $case = $stmt->fetch(PDO::FETCH_ASSOC);

            return [
                'case_id' => $case['id'] ?? '',
                'case_number' => $case['case_number'] ?? '',
                'employee_name' => ($case['employee_first_name'] ?? '') . ' ' . ($case['employee_last_name'] ?? ''),
                'employee_email' => $case['employee_email'] ?? '',
                'job_title' => $case['job_title'] ?? '',
                'department' => $case['department'] ?? '',
                'start_date' => $case['start_date'] ?? '',
                'manager_name' => ($case['first_name'] ?? '') . ' ' . ($case['last_name'] ?? ''),
                'manager_email' => $case['manager_email'] ?? '',
                'status' => $case['status'] ?? '',
            ];
        } catch (Exception $e) {
            return [];
        }
    }

    /**
     * Template-Rendering mit Platzhalter-Ersetzung
     */
    private function renderTemplate($template, $data)
    {
        $output = $template;
        
        foreach ($data as $key => $value) {
            $placeholder = '{' . $key . '}';
            $output = str_replace($placeholder, htmlspecialchars($value), $output);
        }

        // Entferne nicht ersetzte Platzhalter
        $output = preg_replace('/\{[a-zA-Z_][a-zA-Z0-9_]*\}/', '', $output);

        return $output;
    }

    /**
     * Speichere Benachrichtigung in Datenbank
     */
    private function saveNotification($caseId, $type, $email, $userId, $subject, $body, $status)
    {
        try {
            $stmt = $this->db->prepare('
                INSERT INTO email_notifications
                (case_id, recipient_email, recipient_id, notification_type, subject, message_body, status, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
            ');

            $stmt->execute([
                $caseId,
                $email,
                $userId,
                $type,
                $subject,
                $body,
                $status
            ]);

            return $this->db->lastInsertId();
        } catch (Exception $e) {
            return false;
        }
    }

    /**
     * Update Benachrichtigungs-Status
     */
    private function updateNotificationStatus($notificationId, $status, $sentDate = null, $failureReason = null)
    {
        try {
            $stmt = $this->db->prepare('
                UPDATE email_notifications
                SET status = ?, sent_date = ?, failed_reason = ?, updated_at = NOW()
                WHERE id = ?
            ');

            return $stmt->execute([
                $status,
                $sentDate,
                $failureReason,
                $notificationId
            ]);
        } catch (Exception $e) {
            return false;
        }
    }

    /**
     * Erhöhe Retry-Count
     */
    private function incrementRetryCount($notificationId)
    {
        try {
            $stmt = $this->db->prepare('
                UPDATE email_notifications
                SET retry_count = retry_count + 1
                WHERE id = ?
            ');
            return $stmt->execute([$notificationId]);
        } catch (Exception $e) {
            return false;
        }
    }

    /**
     * Hole Benachrichtigungs-Verlauf für einen Fall
     */
    public function getNotificationHistory($caseId, $limit = 50)
    {
        try {
            $stmt = $this->db->prepare('
                SELECT * FROM email_notifications
                WHERE case_id = ?
                ORDER BY created_at DESC
                LIMIT ?
            ');
            $stmt->execute([$caseId, $limit]);
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (Exception $e) {
            return [];
        }
    }

    /**
     * Statistiken
     */
    public function getNotificationStats($caseId)
    {
        try {
            $stmt = $this->db->prepare('
                SELECT
                    COUNT(*) as total,
                    SUM(CASE WHEN status = "sent" THEN 1 ELSE 0 END) as sent,
                    SUM(CASE WHEN status = "pending" THEN 1 ELSE 0 END) as pending,
                    SUM(CASE WHEN status = "failed" THEN 1 ELSE 0 END) as failed
                FROM email_notifications
                WHERE case_id = ?
            ');
            $stmt->execute([$caseId]);
            return $stmt->fetch(PDO::FETCH_ASSOC);
        } catch (Exception $e) {
            return null;
        }
    }
}

// ===== VERWENDUNGSBEISPIELE =====
/*

// Instanziierung
$emailService = new EmailNotificationService($db, [
    'smtp_host' => 'smtp.company.local',
    'smtp_user' => 'onboarding@company.local',
    'smtp_password' => getenv('SMTP_PASSWORD'),
]);

// Sende sofortige Benachrichtigung
$emailService->sendNotification(
    $caseId,
    'onboarding_start',
    'employee@company.local',
    $userId,
    ['additional_info' => 'value']
);

// Plane Benachrichtigung für später
$emailService->scheduleNotification(
    $caseId,
    'reminder',
    'manager@company.local',
    date('Y-m-d H:i:s', strtotime('+1 day')),
    $managerId
);

// Verarbeite ausstehende E-Mails (über CRON)
$sentCount = $emailService->processPendingNotifications();

// Hole Verlauf
$history = $emailService->getNotificationHistory($caseId);

// Statistiken
$stats = $emailService->getNotificationStats($caseId);

*/
?>
