<?php
/**
 * PDF-Export für Onboarding-Dokumente
 * Generiert ein professionelles Onboarding-Dokument mit allen relevanten Informationen
 */

require_once '../config.php';
redirectIfNotLoggedIn();

$caseId = intval($_GET['id'] ?? 0);

if (!$caseId) {
    die('Ungültige Fallnummer');
}

// Fall abrufen
$stmt = $db->prepare('SELECT * FROM onboarding_cases WHERE id = ?');
$stmt->execute([$caseId]);
$case = $stmt->fetch();

if (!$case) {
    die('Fall nicht gefunden');
}

// Alle Antworten abrufen
$stmt = $db->prepare('
    SELECT fr.*, ff.label, ff.field_name
    FROM form_responses fr
    JOIN form_fields ff ON fr.field_id = ff.id
    WHERE fr.case_id = ?
    ORDER BY fr.submitted_at
');
$stmt->execute([$caseId]);
$responses = $stmt->fetchAll();

// PDF generieren
header('Content-Type: application/pdf');
header('Content-Disposition: attachment; filename="Onboarding_' . $case['case_number'] . '.pdf"');

// PDF-Klasse (einfache Alternative zu TCPDF)
class SimplePDF {
    private $lines = [];
    private $currentY = 20;
    private $pageHeight = 297;
    private $margin = 15;
    
    public function __construct() {
        $this->lines[] = "%PDF-1.4\n";
    }
    
    public function addTitle($text) {
        $this->lines[] = "<!-- TITLE: " . htmlspecialchars($text) . " -->\n";
        echo "<!DOCTYPE html>\n<html>\n<head>\n";
        echo "<meta charset='UTF-8'>\n";
        echo "<title>Onboarding-Dokument - " . htmlspecialchars($text) . "</title>\n";
        echo "<style>\n";
        echo "body { font-family: Arial, sans-serif; line-height: 1.6; margin: 20px; }\n";
        echo "h1 { color: #0c7ff2; border-bottom: 3px solid #0c7ff2; padding-bottom: 10px; }\n";
        echo "h2 { color: #0c7ff2; margin-top: 30px; margin-bottom: 15px; }\n";
        echo "table { width: 100%; border-collapse: collapse; margin: 15px 0; }\n";
        echo "th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }\n";
        echo "th { background-color: #0c7ff2; color: white; }\n";
        echo "tr:nth-child(even) { background-color: #f9f9f9; }\n";
        echo ".info-box { background-color: #e3f2fd; border-left: 4px solid #0c7ff2; padding: 15px; margin: 15px 0; }\n";
        echo ".warning-box { background-color: #fff3e0; border-left: 4px solid #ff9800; padding: 15px; margin: 15px 0; }\n";
        echo ".section { page-break-inside: avoid; margin: 20px 0; }\n";
        echo ".footer { margin-top: 40px; border-top: 1px solid #ddd; padding-top: 20px; text-align: center; color: #666; font-size: 12px; }\n";
        echo "@media print { body { margin: 0; } .no-print { display: none; } }\n";
        echo "</style>\n";
        echo "</head>\n<body>\n";
    }
    
    public function render() {
        // Wird in der Funktion unten aufgerufen
    }
}

// Benutzer abrufen
$stmt = $db->prepare('SELECT first_name, last_name FROM users WHERE id = ?');
$stmt->execute([$case['created_by']]);
$creator = $stmt->fetch();

// Manager-Info abrufen
$manager_info = null;
if ($case['manager_id']) {
    $stmt = $db->prepare('SELECT first_name, last_name, email FROM users WHERE id = ?');
    $stmt->execute([$case['manager_id']]);
    $manager_info = $stmt->fetch();
}

// HTML-basiertes PDF generieren (browser-friendly)
echo "<!DOCTYPE html>\n";
echo "<html lang='de'>\n";
echo "<head>\n";
echo "<meta charset='UTF-8'>\n";
echo "<meta name='viewport' content='width=device-width, initial-scale=1.0'>\n";
echo "<title>Onboarding-Dokument - " . htmlspecialchars($case['case_number']) . "</title>\n";
echo "<style>\n";
echo "* { margin: 0; padding: 0; }\n";
echo "body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; background: #fff; }\n";
echo "page { display: block; page-break-after: always; margin: 20mm auto; padding: 20mm; max-width: 210mm; box-shadow: 0 0 0 1px #ddd; }\n";
echo ".header { text-align: center; margin-bottom: 40px; border-bottom: 3px solid #0c7ff2; padding-bottom: 20px; }\n";
echo ".header h1 { font-size: 28px; color: #0c7ff2; margin-bottom: 10px; }\n";
echo ".header p { color: #666; font-size: 14px; }\n";
echo ".case-info { background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0; }\n";
echo ".info-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #ddd; }\n";
echo ".info-row:last-child { border-bottom: none; }\n";
echo ".info-label { font-weight: bold; color: #0c7ff2; width: 40%; }\n";
echo ".info-value { width: 60%; }\n";
echo ".section { margin: 30px 0; }\n";
echo ".section-title { font-size: 18px; color: #0c7ff2; border-bottom: 2px solid #0c7ff2; padding-bottom: 10px; margin-bottom: 15px; font-weight: bold; }\n";
echo ".section-content { padding: 15px; }\n";
echo ".credential-box { background: #fff3e0; border-left: 4px solid #ff9800; padding: 15px; margin: 15px 0; border-radius: 3px; }\n";
echo ".credential-item { margin: 10px 0; font-family: 'Courier New', monospace; }\n";
echo ".credential-item span { font-weight: bold; color: #e65100; }\n";
echo ".table { width: 100%; border-collapse: collapse; margin: 15px 0; }\n";
echo ".table th, .table td { border: 1px solid #ddd; padding: 12px; text-align: left; }\n";
echo ".table th { background-color: #0c7ff2; color: white; font-weight: bold; }\n";
echo ".table tr:nth-child(even) { background-color: #f9f9f9; }\n";
echo ".timeline { position: relative; margin: 30px 0; }\n";
echo ".timeline-item { margin-left: 30px; margin-bottom: 20px; position: relative; }\n";
echo ".timeline-item::before { content: ''; position: absolute; left: -20px; top: 5px; width: 12px; height: 12px; border-radius: 50%; background: #0c7ff2; }\n";
echo ".timeline-item-title { font-weight: bold; color: #0c7ff2; }\n";
echo ".timeline-item-status { color: #666; font-size: 12px; }\n";
echo ".footer { margin-top: 40px; border-top: 2px solid #ddd; padding-top: 20px; text-align: center; color: #999; font-size: 11px; }\n";
echo ".print-button { display: none; }\n";
echo "@media print {\n";
echo "  body { margin: 0; padding: 0; background: white; }\n";
echo "  page { box-shadow: none; margin: 0; padding: 20mm; }\n";
echo "  .print-button { display: block; position: fixed; top: 10px; right: 10px; }\n";
echo "}\n";
echo "@page { size: A4; margin: 20mm; }\n";
echo "</style>\n";
echo "</head>\n";
echo "<body>\n";

// ===== HEADER =====
echo "<page>\n";
echo "<div class='header'>\n";
echo "<h1>📋 Onboarding-Dokument</h1>\n";
echo "<p>Willkommen bei " . SITE_NAME . "</p>\n";
echo "</div>\n";

// ===== FALLNUMMER & GRUNDINFO =====
echo "<div class='case-info'>\n";
echo "<div class='info-row'>\n";
echo "<span class='info-label'>Fallnummer:</span>\n";
echo "<span class='info-value'><strong>" . htmlspecialchars($case['case_number']) . "</strong></span>\n";
echo "</div>\n";
echo "<div class='info-row'>\n";
echo "<span class='info-label'>Erstellt am:</span>\n";
echo "<span class='info-value'>" . date('d.m.Y H:i', strtotime($case['created_at'])) . "</span>\n";
echo "</div>\n";
echo "<div class='info-row'>\n";
echo "<span class='info-label'>Status:</span>\n";
echo "<span class='info-value'><strong>" . ucfirst($case['status']) . "</strong></span>\n";
echo "</div>\n";
echo "</div>\n";

// ===== MITARBEITERDATEN =====
echo "<div class='section'>\n";
echo "<div class='section-title'>👤 Mitarbeiterdaten</div>\n";
echo "<div class='section-content'>\n";
echo "<table class='table'>\n";
echo "<tr><th>Feld</th><th>Wert</th></tr>\n";
echo "<tr><td>Vorname</td><td>" . htmlspecialchars($case['employee_first_name']) . "</td></tr>\n";
echo "<tr><td>Nachname</td><td>" . htmlspecialchars($case['employee_last_name']) . "</td></tr>\n";
echo "<tr><td>Email</td><td>" . htmlspecialchars($case['employee_email']) . "</td></tr>\n";
echo "<tr><td>Benutzername</td><td><code>" . htmlspecialchars($case['employee_username']) . "</code></td></tr>\n";
echo "<tr><td>Abteilung</td><td>" . htmlspecialchars($case['department']) . "</td></tr>\n";
echo "<tr><td>Position</td><td>" . htmlspecialchars($case['job_title']) . "</td></tr>\n";
echo "<tr><td>Startdatum</td><td>" . ($case['start_date'] ? date('d.m.Y', strtotime($case['start_date'])) : '-') . "</td></tr>\n";
if ($manager_info) {
    echo "<tr><td>Vorgesetzter</td><td>" . htmlspecialchars($manager_info['first_name'] . ' ' . $manager_info['last_name']) . "</td></tr>\n";
}
echo "</table>\n";
echo "</div>\n";
echo "</div>\n";

// ===== ZUGANGSDATEN (KENNWORT) =====
if ($case['employee_password']) {
    echo "<div class='section'>\n";
    echo "<div class='section-title'>🔐 Zugangsdaten</div>\n";
    echo "<div class='section-content'>\n";
    echo "<div class='credential-box'>\n";
    echo "<div class='credential-item'>Benutzername: <span>" . htmlspecialchars($case['employee_username']) . "</span></div>\n";
    echo "<div class='credential-item'>Passwort: <span>" . htmlspecialchars($case['employee_password']) . "</span></div>\n";
    echo "<p style='margin-top: 15px; font-size: 12px; color: #e65100;'>\n";
    echo "⚠️ <strong>WICHTIG:</strong> Bitte sichern Sie diese Daten. Das Passwort sollte bei der ersten Anmeldung geändert werden.\n";
    echo "</p>\n";
    echo "</div>\n";
    echo "</div>\n";
    echo "</div>\n";
}

// ===== FORMULARANTWORTEN =====
if (!empty($responses)) {
    echo "<div class='section'>\n";
    echo "<div class='section-title'>📝 Erfasste Informationen</div>\n";
    echo "<div class='section-content'>\n";
    echo "<table class='table'>\n";
    echo "<tr><th>Feld</th><th>Wert</th><th>Erfasst am</th></tr>\n";
    
    foreach ($responses as $response) {
        $value = htmlspecialchars(substr($response['response_value'], 0, 100));
        if (strlen($response['response_value']) > 100) {
            $value .= '...';
        }
        echo "<tr>\n";
        echo "<td>" . htmlspecialchars($response['label']) . "</td>\n";
        echo "<td>" . $value . "</td>\n";
        echo "<td>" . date('d.m.Y H:i', strtotime($response['submitted_at'])) . "</td>\n";
        echo "</tr>\n";
    }
    
    echo "</table>\n";
    echo "</div>\n";
    echo "</div>\n";
}

// ===== FORTSCHRITT =====
$stmt = $db->prepare('
    SELECT sp.*, ws.title, ws.role
    FROM step_progress sp
    LEFT JOIN workflow_steps ws ON sp.step_id = ws.id
    WHERE sp.case_id = ?
    ORDER BY sp.id
');
$stmt->execute([$caseId]);
$progress_items = $stmt->fetchAll();

if (!empty($progress_items)) {
    echo "<div class='section'>\n";
    echo "<div class='section-title'>📊 Workflow-Fortschritt</div>\n";
    echo "<div class='section-content'>\n";
    echo "<div class='timeline'>\n";
    
    foreach ($progress_items as $item) {
        $status_text = ucfirst($item['status']);
        $status_icon = match($item['status']) {
            'completed' => '✅',
            'in_progress' => '⏳',
            'pending' => '⏹️',
            'rejected' => '❌',
            default => '❓'
        };
        
        echo "<div class='timeline-item'>\n";
        echo "<div class='timeline-item-title'>$status_icon " . htmlspecialchars($item['title']) . " (" . $item['role'] . ")</div>\n";
        echo "<div class='timeline-item-status'>Status: $status_text";
        if ($item['completed_at']) {
            echo " - Abgeschlossen: " . date('d.m.Y H:i', strtotime($item['completed_at']));
        }
        if ($item['notes']) {
            echo " - Notiz: " . htmlspecialchars($item['notes']);
        }
        echo "</div>\n";
        echo "</div>\n";
    }
    
    echo "</div>\n";
    echo "</div>\n";
    echo "</div>\n";
}

// ===== WICHTIGE INFORMATIONEN =====
echo "<div class='section'>\n";
echo "<div class='section-title'>ℹ️ Wichtige Informationen</div>\n";
echo "<div class='section-content'>\n";
echo "<ul style='margin-left: 20px;'>\n";
echo "<li>Bitte ändern Sie Ihr Passwort bei der ersten Anmeldung</li>\n";
echo "<li>Kontaktieren Sie den IT-Support für technische Fragen: " . ADMIN_EMAIL . "</li>\n";
echo "<li>Dokumentation finden Sie unter: " . SITE_URL . "</li>\n";
echo "<li>Alle Ihre Daten werden sicher in unserem System gespeichert</li>\n";
echo "</ul>\n";
echo "</div>\n";
echo "</div>\n";

// ===== UNTERSCHRIFTSFELDER =====
echo "<div class='section' style='margin-top: 60px;'>\n";
echo "<table class='table' style='margin-top: 30px;'>\n";
echo "<tr>\n";
echo "<td style='width: 50%; vertical-align: bottom; height: 60px;'>\n";
echo "Unterschrift Mitarbeiter: _______________\n";
echo "</td>\n";
echo "<td style='width: 50%; vertical-align: bottom; height: 60px; border-left: none;'>\n";
echo "Unterschrift HR: _______________\n";
echo "</td>\n";
echo "</tr>\n";
echo "</table>\n";
echo "</div>\n";

// ===== FOOTER =====
echo "<div class='footer'>\n";
echo "<p>\n";
echo "Dieses Dokument wurde am " . date('d.m.Y H:i:s') . " generiert.<br>\n";
echo "PowerShell Onboarding System V3.0.2 | " . SITE_NAME . "<br>\n";
echo "© 2025 - Alle Rechte vorbehalten\n";
echo "</p>\n";
echo "</div>\n";

echo "</page>\n";
echo "</body>\n";
echo "</html>\n";

// Log die PDF-Generierung
logAction($_SESSION['user_id'], 'export_pdf', 'PDF generiert für Fall: ' . $case['case_number']);

?>
