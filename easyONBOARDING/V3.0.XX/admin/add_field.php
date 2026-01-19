<?php
require_once '../config.php';
redirectIfNotAdmin();

$stepId = intval($_GET['step_id'] ?? 0);
$message = ''; $error = '';

if (!$stepId) {
    header('Location: dashboard.php?tab=workflows');
    exit();
}

// Schritt abrufen
$stmt = $db->prepare('SELECT ws.*, w.id as workflow_id FROM workflow_steps ws JOIN workflows w ON ws.workflow_id = w.id WHERE ws.id = ?');
$stmt->execute([$stepId]);
$step = $stmt->fetch();

if (!$step) {
    header('Location: dashboard.php?tab=workflows');
    exit();
}

// Bestehende Felder abrufen
$stmt = $db->prepare('SELECT * FROM form_fields WHERE step_id = ? ORDER BY field_order');
$stmt->execute([$stepId]);
$fields = $stmt->fetchAll();

// Feld hinzufügen
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['add_field'])) {
    try {
        $field_name = sanitize($_POST['field_name'] ?? '');
        $field_type = sanitize($_POST['field_type'] ?? '');
        $label = sanitize($_POST['label'] ?? '');
        $placeholder = sanitize($_POST['placeholder'] ?? '');
        $is_required = isset($_POST['is_required']) ? 1 : 0;
        $field_order = intval($_POST['field_order'] ?? count($fields) + 1);

        if (empty($field_name) || empty($field_type) || empty($label)) {
            throw new Exception('Alle Pflichtfelder erforderlich');
        }

        $field_types = ['text', 'email', 'phone', 'textarea', 'date', 'select', 'radio', 'checkbox', 'number'];
        if (!in_array($field_type, $field_types)) {
            throw new Exception('Ungültiger Feldtyp');
        }

        $stmt = $db->prepare('INSERT INTO form_fields (step_id, field_name, field_type, label, placeholder, is_required, field_order) VALUES (?, ?, ?, ?, ?, ?, ?)');
        $stmt->execute([$stepId, $field_name, $field_type, $label, $placeholder, $is_required, $field_order]);

        $message = 'Feld hinzugefügt!';
        logAction($_SESSION['user_id'], 'add_field', 'Feld hinzugefügt: ' . $label . ' (Schritt ' . $step['title'] . ')');

        // Felder neu abrufen
        $stmt = $db->prepare('SELECT * FROM form_fields WHERE step_id = ? ORDER BY field_order');
        $stmt->execute([$stepId]);
        $fields = $stmt->fetchAll();
    } catch (Exception $e) {
        $error = $e->getMessage();
    }
}

// Feld löschen
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete_field'])) {
    try {
        $field_id = intval($_POST['field_id'] ?? 0);
        
        $stmt = $db->prepare('SELECT label FROM form_fields WHERE id = ?');
        $stmt->execute([$field_id]);
        $field = $stmt->fetch();

        if (!$field) throw new Exception('Feld nicht gefunden');

        $db->prepare('DELETE FROM form_responses WHERE field_id = ?')->execute([$field_id]);
        $db->prepare('DELETE FROM form_fields WHERE id = ?')->execute([$field_id]);

        $message = 'Feld gelöscht!';
        logAction($_SESSION['user_id'], 'delete_field', 'Feld gelöscht: ' . $field['label']);

        // Felder neu abrufen
        $stmt = $db->prepare('SELECT * FROM form_fields WHERE step_id = ? ORDER BY field_order');
        $stmt->execute([$stepId]);
        $fields = $stmt->fetchAll();
    } catch (Exception $e) {
        $error = $e->getMessage();
    }
}
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Felder verwalten - <?php echo SITE_NAME; ?></title>
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
                <a href="edit_workflow.php?id=<?php echo $step['workflow_id']; ?>" class="text-gray-600 hover:bg-gray-100 block px-4 py-2 rounded-lg">
                    📊 Zurück zum Workflow
                </a>
            </nav>
        </aside>

        <main class="flex-1 p-8">
            <div class="mb-8">
                <h2 class="text-3xl font-bold text-gray-800">📋 Formularfelder verwalten</h2>
                <p class="text-gray-600 mt-2">
                    Workflow: <span class="font-semibold"><?php echo htmlspecialchars($step['title']); ?></span> 
                    (Rolle: <span class="text-blue-600"><?php echo htmlspecialchars($step['role']); ?></span>)
                </p>
            </div>

            <?php if ($error): ?>
                <div class="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700 rounded">
                    <?php echo htmlspecialchars($error); ?>
                </div>
            <?php endif; ?>

            <?php if ($message): ?>
                <div class="mb-6 p-4 bg-green-50 border-l-4 border-green-500 text-green-700 rounded">
                    ✅ <?php echo htmlspecialchars($message); ?>
                </div>
            <?php endif; ?>

            <div class="grid grid-cols-3 gap-8">
                <!-- Neues Feld (Linke Spalte) -->
                <div class="col-span-1">
                    <div class="bg-white rounded-lg shadow p-6 sticky top-8">
                        <h3 class="text-lg font-semibold text-gray-800 mb-4">➕ Neues Feld</h3>
                        <form method="POST" class="space-y-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">Feldname *</label>
                                <input type="text" name="field_name" placeholder="z.B. first_name" required 
                                       class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm">
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">Feldtyp *</label>
                                <select name="field_type" required class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm">
                                    <option value="">-- Wählen --</option>
                                    <option value="text">Text</option>
                                    <option value="email">E-Mail</option>
                                    <option value="phone">Telefon</option>
                                    <option value="textarea">Textarea</option>
                                    <option value="date">Datum</option>
                                    <option value="number">Zahl</option>
                                    <option value="select">Dropdown</option>
                                    <option value="radio">Radio Buttons</option>
                                    <option value="checkbox">Checkbox</option>
                                </select>
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">Label *</label>
                                <input type="text" name="label" placeholder="z.B. Vorname" required 
                                       class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm">
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">Platzhalter</label>
                                <input type="text" name="placeholder" placeholder="z.B. Ihren Namen eingeben..." 
                                       class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm">
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">Reihenfolge</label>
                                <input type="number" name="field_order" value="<?php echo count($fields) + 1; ?>" min="1"
                                       class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm">
                            </div>
                            <label class="flex items-center text-sm">
                                <input type="checkbox" name="is_required" class="w-4 h-4 text-blue-600 rounded focus:ring-2 focus:ring-blue-500">
                                <span class="ml-2 font-medium text-gray-700">Erforderlich</span>
                            </label>
                            <button type="submit" name="add_field" class="w-full bg-blue-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors text-sm">
                                ➕ Feld hinzufügen
                            </button>
                        </form>
                    </div>
                </div>

                <!-- Bestehende Felder (Rechte Spalten) -->
                <div class="col-span-2">
                    <div class="bg-white rounded-lg shadow overflow-hidden">
                        <div class="px-6 py-4 bg-gray-100 border-b">
                            <h3 class="text-lg font-semibold text-gray-800">
                                📊 Felder (<?php echo count($fields); ?>)
                            </h3>
                        </div>

                        <?php if (empty($fields)): ?>
                            <div class="p-12 text-center text-gray-500">
                                <p class="text-lg mb-2">Noch keine Felder vorhanden</p>
                                <p class="text-sm">Fügen Sie ein Feld hinzu, um zu beginnen</p>
                            </div>
                        <?php else: ?>
                            <div class="divide-y">
                                <?php foreach ($fields as $field): ?>
                                    <div class="p-6 hover:bg-blue-50 transition-colors">
                                        <div class="flex items-start justify-between gap-4">
                                            <div class="flex-1">
                                                <div class="flex items-center gap-2 mb-2">
                                                    <h4 class="font-semibold text-gray-800"><?php echo htmlspecialchars($field['label']); ?></h4>
                                                    <span class="bg-blue-100 text-blue-800 px-2 py-1 rounded text-xs font-semibold">
                                                        <?php echo htmlspecialchars($field['field_type']); ?>
                                                    </span>
                                                    <?php if ($field['is_required']): ?>
                                                        <span class="bg-red-100 text-red-800 px-2 py-1 rounded text-xs font-semibold">Erforderlich</span>
                                                    <?php endif; ?>
                                                </div>
                                                <p class="text-sm text-gray-600">
                                                    <code class="bg-gray-100 px-2 py-1 rounded"><?php echo htmlspecialchars($field['field_name']); ?></code>
                                                </p>
                                                <?php if (!empty($field['placeholder'])): ?>
                                                    <p class="text-sm text-gray-500 mt-1">
                                                        Platzhalter: <em><?php echo htmlspecialchars($field['placeholder']); ?></em>
                                                    </p>
                                                <?php endif; ?>
                                                <p class="text-xs text-gray-400 mt-2">Reihenfolge: <?php echo $field['field_order']; ?></p>
                                            </div>
                                            <div class="flex gap-2">
                                                <a href="edit_field.php?field_id=<?php echo $field['id']; ?>" 
                                                   class="bg-gray-200 hover:bg-gray-300 text-gray-800 px-3 py-1 rounded text-sm font-semibold transition-colors">
                                                    ✎ Bearbeiten
                                                </a>
                                                <form method="POST" class="inline" onsubmit="return confirm('Feld löschen?');">
                                                    <input type="hidden" name="field_id" value="<?php echo $field['id']; ?>">
                                                    <button type="submit" name="delete_field" class="bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded text-sm font-semibold transition-colors">
                                                        🗑️ Löschen
                                                    </button>
                                                </form>
                                            </div>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </main>
    </div>
</body>
</html>
