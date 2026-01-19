<?php
/**
 * API Endpoint: Onboarding-Fall erstellen
 * 
 * POST /api/create_case.php
 * 
 * Payload (JSON):
 * {
 *     "first_name": "John",
 *     "last_name": "Doe",
 *     "email": "john.doe@company.com",
 *     "department": "Engineering",
 *     "job_title": "Software Engineer",
 *     "start_date": "2025-01-15",
 *     "manager_id": 2,
 *     "api_key": "secret_api_key_here"
 * }
 */

require_once '../config.php';
header('Content-Type: application/json; charset=utf-8');

$request_method = $_SERVER['REQUEST_METHOD'];
$request_data = json_decode(file_get_contents('php://input'), true);

try {
    // Nur POST erlaubt
    if ($request_method !== 'POST') {
        handleError('Nur POST-Requests erlaubt', 405);
    }

    // API-Key validieren
    $apiKey = $request_data['api_key'] ?? $_SERVER['HTTP_X_API_KEY'] ?? null;
    if (!$apiKey || $apiKey !== getenv('ONBOARDING_API_KEY')) {
        logApiRequest('/api/create_case', 'POST', 401, $request_data, ['error' => 'Unauthorized']);
        handleError('Ungültiger API-Key', 401);
    }

    // Input validieren
    $required_fields = ['first_name', 'last_name', 'email', 'department', 'job_title'];
    foreach ($required_fields as $field) {
        if (empty($request_data[$field])) {
            handleError("Feld erforderlich: $field", 400);
        }
    }

    $firstName = sanitize($request_data['first_name']);
    $lastName = sanitize($request_data['last_name']);
    $email = sanitize($request_data['email']);
    $department = sanitize($request_data['department']);
    $jobTitle = sanitize($request_data['job_title']);
    $startDate = $request_data['start_date'] ?? null;
    $managerId = intval($request_data['manager_id'] ?? 0) ?: null;

    // Email validieren
    if (!validateEmail($email)) {
        handleError('Ungültige E-Mail-Adresse', 400);
    }

    // Fallnummer, Benutzername und Passwort generieren
    $caseNumber = generateCaseNumber();
    $password = generatePassword();
    $passwordHash = password_hash($password, PASSWORD_DEFAULT);
    $username = generateUsername($firstName, $lastName);

    // Fall erstellen
    $stmt = $db->prepare('
        INSERT INTO onboarding_cases 
        (case_number, employee_first_name, employee_last_name, employee_email, employee_username, employee_password, department, job_title, manager_id, start_date, status, current_step, current_role, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ');

    $stmt->execute([
        $caseNumber,
        $firstName,
        $lastName,
        $email,
        $username,
        $passwordHash,
        $department,
        $jobTitle,
        $managerId,
        $startDate,
        'pending',
        1,
        'HR',
        1 // System user ID
    ]);

    $caseId = $db->lastInsertId();

    // API-Request loggen
    logApiRequest('/api/create_case', 'POST', 201, ['first_name' => $firstName, 'last_name' => $lastName, 'email' => $email], [
        'case_id' => $caseId,
        'case_number' => $caseNumber
    ], $caseId);

    successResponse([
        'case_id' => $caseId,
        'case_number' => $caseNumber,
        'username' => $username,
        'password' => $password,
        'status' => 'pending'
    ], 'Onboarding-Fall erfolgreich erstellt');

} catch (Exception $e) {
    logApiRequest('/api/create_case', 'POST', 500, $request_data, ['error' => $e->getMessage()]);
    handleError('Fehler beim Erstellen des Falls: ' . $e->getMessage(), 500);
}
?>
