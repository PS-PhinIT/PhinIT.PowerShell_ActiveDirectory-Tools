<?php
require_once '../config.php';
redirectIfNotAdmin();

$workflowId = intval($_GET['id'] ?? 0);
$message = ''; $error = '';

// Bei neuem Workflow
if (!$workflowId) {
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['create_workflow'])) {
        try {
            $name = sanitize($_POST['name'] ?? '');
            $description = sanitize($_POST['description'] ?? '');

            if (empty($name)) throw new Exception('Name erforderlich');

            $stmt = $db->prepare('INSERT INTO workflows (name, description, is_active, step_order) VALUES (?, ?, 1, ?)');
            $stmt->execute([$name, $description, json_encode([])]);

            logAction($_SESSION['user_id'], 'create_workflow', 'Workflow erstellt: ' . $name);
            header('Location: edit_workflow.php?id=' . $db->lastInsertId() . '&message=created');
            exit();
        } catch (Exception $e) {
            $error = $e->getMessage();
        }
    }
} else {
    // Existierenden Workflow laden
    $stmt = $db->prepare('SELECT * FROM workflows WHERE id = ?');
    $stmt->execute([$workflowId]);
    $workflow = $stmt->fetch();

    if (!$workflow) {
        header('Location: dashboard.php?tab=workflows');
        exit();
    }

    // Schritte abrufen
    $stmt = $db->prepare('SELECT * FROM workflow_steps WHERE workflow_id = ? ORDER BY step_number');
    $stmt->execute([$workflowId]);
    $steps = $stmt->fetchAll();

    // Workflow aktualisieren
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['update_workflow'])) {
        try {
            $name = sanitize($_POST['name'] ?? '');
            $description = sanitize($_POST['description'] ?? '');
            $is_active = isset($_POST['is_active']) ? 1 : 0;

            $stmt = $db->prepare('UPDATE workflows SET name = ?, description = ?, is_active = ?, updated_at = NOW() WHERE id = ?');
            $stmt->execute([$name, $description, $is_active, $workflowId]);

            $message = 'Workflow aktualisiert!';
            logAction($_SESSION['user_id'], 'update_workflow', 'Workflow aktualisiert: ' . $name);

            // Daten neu abrufen
            $stmt = $db->prepare('SELECT * FROM workflows WHERE id = ?');
            $stmt->execute([$workflowId]);
            $workflow = $stmt->fetch();
        } catch (Exception $e) {
            $error = $e->getMessage();
        }
    }

    // Neuen Schritt hinzufügen
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['add_step'])) {
        try {
            $step_number = intval($_POST['step_number'] ?? 0);
            $role = sanitize($_POST['role'] ?? '');
            $title = sanitize($_POST['title'] ?? '');
            $description = sanitize($_POST['step_description'] ?? '');

            if (!$step_number || empty($role) || empty($title)) throw new Exception('Alle Felder erforderlich');
            if (!in_array($role, ROLES)) throw new Exception('Ungültige Rolle');

            $stmt = $db->prepare('INSERT INTO workflow_steps (workflow_id, step_number, role, title, description, is_mandatory) VALUES (?, ?, ?, ?, ?, 1)');
            $stmt->execute([$workflowId, $step_number, $role, $title, $description]);

            $message = 'Schritt hinzugefügt!';
            
            // Schritte neu abrufen
            $stmt = $db->prepare('SELECT * FROM workflow_steps WHERE workflow_id = ? ORDER BY step_number');
            $stmt->execute([$workflowId]);
            $steps = $stmt->fetchAll();
        } catch (Exception $e) {
            $error = $e->getMessage();
        }
    }
}
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo ($workflowId ? 'Workflow bearbeiten' : 'Workflow erstellen'); ?> - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50 font-sans">
    <div class="min-h-screen flex">
        <aside class="w-64 bg-white shadow-lg p-6">
            <div class="flex items-center gap-3 mb-8">
                <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75" stroke-linecap="round" stroke-linejoin="round"></path>
                </svg>
                <h1 class="text-lg font-bold text-gray-800">Admin</h1>
            </div>
            <nav class="space-y-2">
                <a href="dashboard.php?tab=workflows" class="text-gray-600 hover:bg-gray-100 block px-4 py-2 rounded-lg">📊 Zurück</a>
            </nav>
        </aside>

        <main class="flex-1 p-8">
            <h2 class="text-3xl font-bold text-gray-800 mb-8">
                <?php echo $workflowId ? '🔄 Workflow bearbeiten' : '➕ Neuer Workflow'; ?>
            </h2>

            <?php if ($error): ?>
                <div class="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700">
                    <?php echo htmlspecialchars($error); ?>
                </div>
            <?php endif; ?>

            <?php if ($message): ?>
                <div class="mb-6 p-4 bg-green-50 border-l-4 border-green-500 text-green-700">
                    ✅ <?php echo htmlspecialchars($message); ?>
                </div>
            <?php endif; ?>

            <div class="max-w-4xl bg-white rounded-lg shadow p-8">
                <?php if (!$workflowId): ?>
                    <!-- Neuer Workflow -->
                    <form method="POST" class="space-y-6">
                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">Workflow-Name *</label>
                            <input type="text" name="name" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">Beschreibung</label>
                            <textarea name="description" rows="3" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"></textarea>
                        </div>
                        <button type="submit" name="create_workflow" class="bg-blue-600 text-white font-semibold py-2 px-6 rounded-lg hover:bg-blue-700">
                            ✓ Workflow erstellen
                        </button>
                    </form>

                <?php else: ?>
                    <!-- Workflow bearbeiten -->
                    <div class="mb-8 pb-8 border-b">
                        <h3 class="text-xl font-semibold text-gray-800 mb-4">Workflow-Information</h3>
                        <form method="POST" class="space-y-6">
                            <div class="grid grid-cols-2 gap-6">
                                <div>
                                    <label class="block text-sm font-medium text-gray-700 mb-2">Name *</label>
                                    <input type="text" name="name" value="<?php echo htmlspecialchars($workflow['name']); ?>" required 
                                           class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                                </div>
                                <div class="flex items-end">
                                    <label class="flex items-center">
                                        <input type="checkbox" name="is_active" <?php echo $workflow['is_active'] ? 'checked' : ''; ?> 
                                               class="w-4 h-4 text-blue-600 rounded focus:ring-2 focus:ring-blue-500">
                                        <span class="ml-2 text-sm font-medium text-gray-700">Aktiv</span>
                                    </label>
                                </div>
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">Beschreibung</label>
                                <textarea name="description" rows="3" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                                    <?php echo htmlspecialchars($workflow['description'] ?? ''); ?>
                                </textarea>
                            </div>
                            <button type="submit" name="update_workflow" class="bg-green-600 text-white font-semibold py-2 px-6 rounded-lg hover:bg-green-700">
                                ✓ Änderungen speichern
                            </button>
                        </form>
                    </div>

                    <!-- Schritte verwalten -->
                    <div>
                        <h3 class="text-xl font-semibold text-gray-800 mb-4">Workflow-Schritte</h3>

                        <!-- Bestehende Schritte -->
                        <div class="mb-8">
                            <table class="w-full">
                                <thead class="bg-gray-100">
                                    <tr>
                                        <th class="px-4 py-2 text-left text-sm font-semibold">Schritt</th>
                                        <th class="px-4 py-2 text-left text-sm font-semibold">Rolle</th>
                                        <th class="px-4 py-2 text-left text-sm font-semibold">Titel</th>
                                        <th class="px-4 py-2 text-left text-sm font-semibold">Aktion</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($steps as $step): ?>
                                        <tr class="border-b hover:bg-gray-50">
                                            <td class="px-4 py-3">#<?php echo $step['step_number']; ?></td>
                                            <td class="px-4 py-3">
                                                <span class="bg-blue-100 text-blue-800 px-2 py-1 rounded text-sm font-semibold">
                                                    <?php echo htmlspecialchars($step['role']); ?>
                                                </span>
                                            </td>
                                            <td class="px-4 py-3"><?php echo htmlspecialchars($step['title']); ?></td>
                                            <td class="px-4 py-3">
                                                <a href="edit_field.php?step_id=<?php echo $step['id']; ?>" class="text-blue-600 hover:underline text-sm">
                                                    Felder bearbeiten
                                                </a>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>

                        <!-- Neuen Schritt hinzufügen -->
                        <div class="bg-blue-50 p-6 rounded-lg">
                            <h4 class="font-semibold text-gray-800 mb-4">Neuen Schritt hinzufügen</h4>
                            <form method="POST" class="grid grid-cols-2 gap-4">
                                <div>
                                    <label class="block text-sm font-medium text-gray-700 mb-2">Schritt-Nummer</label>
                                    <input type="number" name="step_number" min="1" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                                </div>
                                <div>
                                    <label class="block text-sm font-medium text-gray-700 mb-2">Rolle</label>
                                    <select name="role" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                                        <option value="">-- Rolle wählen --</option>
                                        <?php foreach (ROLES as $r): if ($r !== 'Admin') echo "<option value='$r'>$r</option>"; endforeach; ?>
                                    </select>
                                </div>
                                <div class="col-span-2">
                                    <label class="block text-sm font-medium text-gray-700 mb-2">Titel</label>
                                    <input type="text" name="title" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                                </div>
                                <div class="col-span-2">
                                    <label class="block text-sm font-medium text-gray-700 mb-2">Beschreibung</label>
                                    <textarea name="step_description" rows="2" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"></textarea>
                                </div>
                                <button type="submit" name="add_step" class="col-span-2 bg-blue-600 text-white font-semibold py-2 px-6 rounded-lg hover:bg-blue-700">
                                    ➕ Schritt hinzufügen
                                </button>
                            </form>
                        </div>
                    </div>
                <?php endif; ?>
            </div>
        </main>
    </div>
</body>
</html>
