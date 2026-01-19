<?php
require_once '../config.php';
redirectIfNotLoggedIn();

$caseId = intval($_GET['id'] ?? 0);

if (!$caseId) {
    die('Ungültige Fallnummer');
}

// Fall abrufen
$stmt = $db->prepare('SELECT * FROM onboarding_cases WHERE id = ?');
$stmt->execute([$caseId]);
$case = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$case) {
    die('Fall nicht gefunden');
}

// Alle Antworten abrufen
$stmt = $db->prepare('
    SELECT fr.*, ff.label 
    FROM form_responses fr
    JOIN form_fields ff ON fr.field_id = ff.id
    WHERE fr.case_id = ?
    ORDER BY fr.submitted_at
');
$stmt->execute([$caseId]);
$responses = $stmt->fetchAll(PDO::FETCH_ASSOC);

// CSV-Header
$filename = 'Onboarding_' . $case['case_number'] . '_' . date('Y-m-d_H-i-s') . '.csv';
header('Content-Type: text/csv; charset=utf-8');
header('Content-Disposition: attachment; filename="' . $filename . '"');

// UTF-8 BOM für Excel
echo "\xEF\xBB\xBF";

// Datei in PHP-Output schreiben
$output = fopen('php://output', 'w');

// CSV-Kopfzeile schreiben
fputcsv($output, [
    'Fallnummer',
    'Vorname',
    'Nachname',
    'E-Mail',
    'Benutzername',
    'Abteilung',
    'Stellenbezeichnung',
    'Startdatum',
    'Status',
    'Erstellungsdatum'
], ';');

// Basis-Daten schreiben
fputcsv($output, [
    $case['case_number'],
    $case['employee_first_name'],
    $case['employee_last_name'],
    $case['employee_email'],
    $case['employee_username'],
    $case['department'],
    $case['job_title'],
    $case['start_date'],
    $case['status'],
    date('d.m.Y H:i:s', strtotime($case['created_at']))
], ';');

// Leerzeile
fputcsv($output, [], ';');

// Formularantworten schreiben
if (!empty($responses)) {
    fputcsv($output, ['FORMULARANTWORTEN'], ';');
    fputcsv($output, ['Feld', 'Wert', 'Eingegeben am'], ';');
    
    foreach ($responses as $response) {
        fputcsv($output, [
            $response['label'],
            $response['response_value'],
            date('d.m.Y H:i:s', strtotime($response['submitted_at']))
        ], ';');
    }
}

fclose($output);
exit();
?>
