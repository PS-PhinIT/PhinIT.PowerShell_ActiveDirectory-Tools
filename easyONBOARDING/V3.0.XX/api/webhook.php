<?php
/**
 * Webhook Management & Delivery System
 * Ermöglicht es externen Systemen, über Case-Status-Änderungen benachrichtigt zu werden
 */

require_once '../config.php';

$action = $_GET['action'] ?? '';

if ($_SERVER['REQUEST_METHOD'] === 'GET' && $action === 'register') {
    // Webhook registrieren
    redirectIfNotLoggedIn();
    
    $url = sanitize($_POST['webhook_url'] ?? '');
    $events = $_POST['events'] ?? [];
    $description = sanitize($_POST['description'] ?? '');
    
    if (empty($url) || !filter_var($url, FILTER_VALIDATE_URL)) {
        jsonResponse(['error' => 'Ungültige Webhook-URL'], 400);
    }
    
    if (empty($events)) {
        jsonResponse(['error' => 'Mindestens ein Event erforderlich'], 400);
    }
    
    try {
        $webhook_secret = bin2hex(random_bytes(32));
        
        $stmt = $db->prepare('
            INSERT INTO webhooks (url, events, description, secret, user_id, is_active, created_at)
            VALUES (?, ?, ?, ?, ?, 1, NOW())
        ');
        
        $stmt->execute([
            $url,
            json_encode($events),
            $description,
            $webhook_secret,
            $_SESSION['user_id']
        ]);
        
        successResponse(['webhook_id' => $db->lastInsertId(), 'secret' => $webhook_secret], 'Webhook registriert');
    } catch (Exception $e) {
        handleError('Fehler beim Registrieren: ' . $e->getMessage(), 500);
    }
}
elseif ($_SERVER['REQUEST_METHOD'] === 'POST' && $action === 'trigger') {
    // Webhook manuell auslösen (für Testing)
    $event = sanitize($_POST['event'] ?? '');
    $case_id = intval($_POST['case_id'] ?? 0);
    
    if (empty($event) || !$case_id) {
        handleError('Event und Case-ID erforderlich', 400);
    }
    
    dispatchWebhook($event, $case_id);
    successResponse([], 'Webhook ausgelöst');
}
elseif ($_SERVER['REQUEST_METHOD'] === 'GET' && $action === 'test') {
    // Test-Webhook (einfache Bestätigung)
    $signature = $_SERVER['HTTP_X_ONBOARDING_SIGNATURE'] ?? '';
    
    // Signature validieren (optional)
    jsonResponse([
        'status' => 'ok',
        'received_at' => date('c'),
        'test_event' => true
    ]);
}
else {
    handleError('Ungültige Aktion', 400);
}

/**
 * Webhook auslösen und an alle registrierten Services senden
 */
function dispatchWebhook($event, $caseId) {
    global $db;
    
    // Case-Daten abrufen
    $stmt = $db->prepare('SELECT * FROM onboarding_cases WHERE id = ?');
    $stmt->execute([$caseId]);
    $case = $stmt->fetch();
    
    if (!$case) {
        return false;
    }
    
    // Payload generieren
    $payload = [
        'event' => $event,
        'timestamp' => date('c'),
        'case' => [
            'id' => $case['id'],
            'case_number' => $case['case_number'],
            'employee_name' => $case['employee_first_name'] . ' ' . $case['employee_last_name'],
            'employee_email' => $case['employee_email'],
            'department' => $case['department'],
            'status' => $case['status'],
            'current_role' => $case['current_role'],
            'start_date' => $case['start_date']
        ]
    ];
    
    // Alle aktiven Webhooks für diesen Event finden
    $stmt = $db->prepare('
        SELECT * FROM webhooks 
        WHERE is_active = 1 
        AND (events LIKE ? OR events LIKE ? OR events LIKE ?)
    ');
    
    $eventPattern = '%"' . $event . '"%';
    $allPattern = '%"*"%';
    
    $stmt->execute([$eventPattern, $allPattern, '%"all"%']);
    $webhooks = $stmt->fetchAll();
    
    // An jeden Webhook senden
    $results = [];
    foreach ($webhooks as $webhook) {
        $result = sendWebhook($webhook, $payload);
        $results[] = $result;
        
        // Log speichern
        $stmt = $db->prepare('
            INSERT INTO webhook_logs (webhook_id, event, payload, response_code, response_body, sent_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ');
        
        $stmt->execute([
            $webhook['id'],
            $event,
            json_encode($payload),
            $result['status_code'] ?? 0,
            $result['response_body'] ?? ''
        ]);
    }
    
    return $results;
}

/**
 * Webhook an externe Service senden
 */
function sendWebhook($webhook, $payload) {
    // Signature generieren
    $signature = hash_hmac('sha256', json_encode($payload), $webhook['secret']);
    
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => $webhook['url'],
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($payload),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            'X-Onboarding-Signature: sha256=' . $signature,
            'X-Onboarding-Event: ' . $payload['event'],
            'User-Agent: PowerShell-Onboarding-System/3.0.2'
        ],
        CURLOPT_TIMEOUT => 10,
        CURLOPT_CONNECTTIMEOUT => 5
    ]);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    return [
        'success' => $http_code >= 200 && $http_code < 300,
        'status_code' => $http_code,
        'response_body' => $response,
        'error' => $error
    ];
}

?>
