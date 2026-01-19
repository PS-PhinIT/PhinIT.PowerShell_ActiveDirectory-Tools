<?php
/**
 * API Endpoint: Case-Status abrufen
 * 
 * GET /api/get_case_status.php?case_number=ONBOARD-xxxxx&api_key=xxx
 * 
 * Response:
 * {
 *     "case_number": "ONBOARD-xxxxx",
 *     "status": "in_progress",
 *     "current_role": "Chef",
 *     "current_step": 3,
 *     "employee_name": "John Doe",
 *     "start_date": "2025-01-15",
 *     "progress": [...]
 * }
 */

require_once '../config.php';
header('Content-Type: application/json; charset=utf-8');

try {
    // Nur GET erlaubt
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        handleError('Nur GET-Requests erlaubt', 405);
    }

    // API-Key validieren
    $apiKey = $_GET['api_key'] ?? $_SERVER['HTTP_X_API_KEY'] ?? null;
    if (!$apiKey || $apiKey !== getenv('ONBOARDING_API_KEY')) {
        handleError('Ungültiger API-Key', 401);
    }

    // Case-Nummer oder ID
    $caseNumber = $_GET['case_number'] ?? null;
    $caseId = $_GET['case_id'] ?? null;

    if (!$caseNumber && !$caseId) {
        handleError('case_number oder case_id erforderlich', 400);
    }

    // Fall abrufen
    if ($caseNumber) {
        $stmt = $db->prepare('SELECT * FROM onboarding_cases WHERE case_number = ?');
        $stmt->execute([$caseNumber]);
    } else {
        $stmt = $db->prepare('SELECT * FROM onboarding_cases WHERE id = ?');
        $stmt->execute([$caseId]);
    }

    $case = $stmt->fetch();

    if (!$case) {
        handleError('Fall nicht gefunden', 404);
    }

    // Fortschritt abrufen
    $stmt = $db->prepare('
        SELECT sp.*, ws.title, ws.role
        FROM step_progress sp
        LEFT JOIN workflow_steps ws ON sp.step_id = ws.id
        WHERE sp.case_id = ?
        ORDER BY sp.id
    ');
    $stmt->execute([$case['id']]);
    $progress = $stmt->fetchAll();

    successResponse([
        'case_id' => $case['id'],
        'case_number' => $case['case_number'],
        'employee_name' => $case['employee_first_name'] . ' ' . $case['employee_last_name'],
        'email' => $case['employee_email'],
        'username' => $case['employee_username'],
        'department' => $case['department'],
        'job_title' => $case['job_title'],
        'start_date' => $case['start_date'],
        'status' => $case['status'],
        'current_role' => $case['current_role'],
        'current_step' => $case['current_step'],
        'created_at' => $case['created_at'],
        'updated_at' => $case['updated_at'],
        'progress' => array_map(function($p) {
            return [
                'step_id' => $p['step_id'],
                'step_title' => $p['title'],
                'role' => $p['role'],
                'status' => $p['status'],
                'completed_at' => $p['completed_at'],
                'notes' => $p['notes']
            ];
        }, $progress)
    ], 'Case-Status erfolgreich abgerufen');

} catch (Exception $e) {
    handleError('Fehler beim Abrufen des Case-Status: ' . $e->getMessage(), 500);
}
?>
