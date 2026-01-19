<?php
require_once '../config.php';

header('Content-Type: application/json');

try {
    $stepId = intval($_GET['step_id'] ?? 0);

    if (!$stepId) {
        echo json_encode([]);
        exit();
    }

    $stmt = $db->prepare('SELECT * FROM form_fields WHERE step_id = ? ORDER BY field_order');
    $stmt->execute([$stepId]);
    $fields = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode($fields);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
?>
