<?php
require_once '../config.php';

header('Content-Type: application/json');

try {
    $workflowId = intval($_GET['workflow_id'] ?? 0);

    if (!$workflowId) {
        echo json_encode([]);
        exit();
    }

    $stmt = $db->prepare('SELECT id, step_number, role, title, description FROM workflow_steps WHERE workflow_id = ? ORDER BY step_number');
    $stmt->execute([$workflowId]);
    $steps = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode($steps);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
?>
