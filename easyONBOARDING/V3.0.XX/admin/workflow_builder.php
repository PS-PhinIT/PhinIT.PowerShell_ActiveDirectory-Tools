<?php
/**
 * Workflow Builder UI - Phase 7
 * Visueller Editor für Onboarding Workflows mit Drag & Drop
 */

require_once '../config.php';
redirectIfNotAdmin();

$action = $_GET['action'] ?? 'list';
$workflowId = $_GET['id'] ?? null;

// AJAX Endpoints
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['ajax'])) {
    $ajax = $_POST['ajax'];
    
    switch ($ajax) {
        case 'save_workflow':
            $data = json_decode($_POST['data'], true);
            if (!$data['name']) exit(json_encode(['error' => 'Name required']));
            
            if ($data['id']) {
                $stmt = $db->prepare('UPDATE workflows SET name = ?, description = ?, config = ?, updated_at = NOW() WHERE id = ?');
                $stmt->execute([$data['name'], $data['description'], json_encode($data['steps']), $data['id']]);
                logAction($_SESSION['user_id'], 'workflow_updated', "Workflow {$data['id']} updated");
                exit(json_encode(['success' => true, 'id' => $data['id']]));
            } else {
                $stmt = $db->prepare('INSERT INTO workflows (name, description, config, is_active, created_by, created_at) VALUES (?, ?, ?, 1, ?, NOW())');
                $stmt->execute([$data['name'], $data['description'], json_encode($data['steps']), $_SESSION['user_id']]);
                $id = $db->lastInsertId();
                logAction($_SESSION['user_id'], 'workflow_created', "New workflow $id");
                exit(json_encode(['success' => true, 'id' => $id]));
            }
            break;
            
        case 'delete_workflow':
            $id = (int)$_POST['id'];
            $db->prepare('DELETE FROM workflows WHERE id = ?')->execute([$id]);
            logAction($_SESSION['user_id'], 'workflow_deleted', "Workflow $id deleted");
            exit(json_encode(['success' => true]));
            
        case 'duplicate_workflow':
            $id = (int)$_POST['id'];
            $src = $db->prepare('SELECT * FROM workflows WHERE id = ?')->execute([$id]);
            $workflow = $src->fetch(PDO::FETCH_ASSOC);
            
            $stmt = $db->prepare('INSERT INTO workflows (name, description, config, is_active, created_by, created_at) VALUES (?, ?, ?, 1, ?, NOW())');
            $stmt->execute([
                $workflow['name'] . ' (Kopie)',
                $workflow['description'],
                $workflow['config'],
                $_SESSION['user_id']
            ]);
            exit(json_encode(['success' => true, 'id' => $db->lastInsertId()]));
    }
}

// Workflows laden
$stmt = $db->prepare('SELECT * FROM workflows ORDER BY created_at DESC');
$stmt->execute();
$workflows = $stmt->fetchAll(PDO::FETCH_ASSOC);

$currentWorkflow = null;
if ($workflowId) {
    $stmt = $db->prepare('SELECT * FROM workflows WHERE id = ?');
    $stmt->execute([$workflowId]);
    $currentWorkflow = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($currentWorkflow) {
        $currentWorkflow['steps'] = json_decode($currentWorkflow['config'], true) ?? [];
    }
}

?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Workflow Builder - easyONBOARDING</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
    <style>
        .drag-handle { cursor: grab; }
        .drag-handle:active { cursor: grabbing; }
        .step-box {
            background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
            border-radius: 8px;
            padding: 16px;
            color: white;
            cursor: move;
            transition: all 0.2s;
        }
        .step-box:hover { transform: scale(1.05); box-shadow: 0 10px 25px rgba(37, 99, 235, 0.3); }
        .step-box.active { background: linear-gradient(135deg, #10b981 0%, #059669 100%); }
        .connector-line { stroke: #3b82f6; stroke-width: 2; }
        .builder-canvas {
            background: linear-gradient(45deg, #f8f9fa 25%, transparent 25%, transparent 75%, #f8f9fa 75%, #f8f9fa),
                        linear-gradient(45deg, #f8f9fa 25%, transparent 25%, transparent 75%, #f8f9fa 75%, #f8f9fa);
            background-size: 20px 20px;
            background-position: 0 0, 10px 10px;
            background-color: #fafbfc;
        }
    </style>
</head>
<body class="bg-gray-50">
    <div class="flex h-screen">
        <!-- Sidebar -->
        <div class="w-64 bg-white shadow-lg overflow-y-auto">
            <div class="p-6">
                <h2 class="text-xl font-bold text-gray-800 mb-4">📋 Workflows</h2>
                
                <button onclick="newWorkflow()" class="w-full bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg mb-4 transition">
                    ➕ Neuer Workflow
                </button>
                
                <div class="space-y-2">
                    <?php foreach ($workflows as $wf): ?>
                    <div class="p-3 bg-gray-50 rounded-lg hover:bg-gray-100 cursor-pointer group" 
                         onclick="selectWorkflow(<?= $wf['id'] ?>)"
                         style="border-left: 4px solid <?= ($currentWorkflow && $currentWorkflow['id'] == $wf['id']) ? '#3b82f6' : '#e5e7eb' ?>">
                        <div class="font-semibold text-sm text-gray-800"><?= htmlspecialchars($wf['name']) ?></div>
                        <div class="text-xs text-gray-500 mt-1"><?= count(json_decode($wf['config'] ?? '[]', true)) ?> Schritte</div>
                        <div class="flex gap-1 mt-2 opacity-0 group-hover:opacity-100 transition text-xs">
                            <button onclick="duplicateWorkflow(<?= $wf['id'] ?>, event)" class="text-blue-500 hover:text-blue-700">📋 Kopieren</button>
                            <button onclick="deleteWorkflow(<?= $wf['id'] ?>, event)" class="text-red-500 hover:text-red-700">🗑️ Löschen</button>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </div>
        </div>

        <!-- Main Builder Area -->
        <div class="flex-1 flex flex-col" x-data="workflowBuilder()">
            <!-- Header -->
            <div class="bg-white shadow-sm border-b px-6 py-4 flex justify-between items-center">
                <div>
                    <h1 class="text-2xl font-bold text-gray-800">
                        <?php if ($currentWorkflow): ?>
                            🏗️ <?= htmlspecialchars($currentWorkflow['name']) ?>
                        <?php else: ?>
                            Workflow Builder
                        <?php endif; ?>
                    </h1>
                </div>
                <?php if ($currentWorkflow): ?>
                <div class="flex gap-3">
                    <button @click="previewMode = !previewMode" class="px-4 py-2 bg-gray-200 hover:bg-gray-300 rounded-lg transition">
                        👁️ Vorschau
                    </button>
                    <button @click="saveWorkflow()" class="px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg transition">
                        💾 Speichern
                    </button>
                </div>
                <?php endif; ?>
            </div>

            <?php if ($currentWorkflow): ?>
            <!-- Builder Content -->
            <div class="flex-1 flex gap-4 p-6 overflow-hidden">
                <!-- Canvas -->
                <div class="flex-1 bg-white rounded-lg shadow-lg overflow-auto builder-canvas relative" style="min-height: 600px;">
                    <svg id="canvas" class="absolute top-0 left-0 w-full h-full pointer-events-none" style="z-index: 1;"></svg>
                    
                    <div class="relative p-8" style="z-index: 2;">
                        <!-- Steps anzeigen -->
                        <template x-for="(step, idx) in steps" :key="idx">
                            <div class="mb-8">
                                <div @click="editStep(idx)" class="step-box inline-block min-w-64" :class="{ 'active': activeStep === idx }">
                                    <div class="flex justify-between items-start">
                                        <div>
                                            <div class="font-bold text-lg" x-text="step.title"></div>
                                            <div class="text-sm opacity-90 mt-1" x-text="step.description"></div>
                                            <div class="text-xs opacity-75 mt-2">👤 <span x-text="step.role"></span></div>
                                        </div>
                                        <button @click.stop="removeStep(idx)" class="text-white hover:text-red-200 text-xl">✕</button>
                                    </div>
                                </div>
                                <template x-if="idx < steps.length - 1">
                                    <div class="text-center my-2 text-gray-400">⬇️</div>
                                </template>
                            </div>
                        </template>

                        <!-- Add Step Button -->
                        <button @click="addStep()" class="mt-8 px-6 py-3 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition">
                            ➕ Schritt hinzufügen
                        </button>
                    </div>
                </div>

                <!-- Right Panel - Step Editor -->
                <div class="w-80 bg-white rounded-lg shadow-lg p-6 overflow-y-auto">
                    <template x-if="activeStep !== null && steps[activeStep]">
                        <div>
                            <h3 class="text-lg font-bold mb-4">✏️ Schritt bearbeiten</h3>
                            
                            <div class="space-y-4">
                                <div>
                                    <label class="block text-sm font-semibold mb-1">Titel</label>
                                    <input type="text" x-model="steps[activeStep].title" class="w-full px-3 py-2 border rounded-lg" />
                                </div>

                                <div>
                                    <label class="block text-sm font-semibold mb-1">Beschreibung</label>
                                    <textarea x-model="steps[activeStep].description" class="w-full px-3 py-2 border rounded-lg h-20"></textarea>
                                </div>

                                <div>
                                    <label class="block text-sm font-semibold mb-1">Rolle</label>
                                    <select x-model="steps[activeStep].role" class="w-full px-3 py-2 border rounded-lg">
                                        <option value="HR">HR</option>
                                        <option value="Manager">Manager</option>
                                        <option value="Supervisor">Abteilungsleiter</option>
                                        <option value="IT">IT</option>
                                    </select>
                                </div>

                                <div>
                                    <label class="block text-sm font-semibold mb-1">Bedingung (optional)</label>
                                    <input type="text" x-model="steps[activeStep].condition" placeholder="z.B. department == 'IT'" class="w-full px-3 py-2 border rounded-lg text-xs" />
                                </div>

                                <div>
                                    <label class="flex items-center gap-2">
                                        <input type="checkbox" x-model="steps[activeStep].required" />
                                        <span class="text-sm font-semibold">Erforderlich</span>
                                    </label>
                                </div>

                                <div>
                                    <label class="block text-sm font-semibold mb-1">Zeitlimit (Tage)</label>
                                    <input type="number" x-model.number="steps[activeStep].timeLimit" class="w-full px-3 py-2 border rounded-lg" />
                                </div>

                                <div class="pt-4 border-t">
                                    <label class="block text-sm font-semibold mb-2">⚙️ Konfiguration JSON</label>
                                    <textarea x-model="steps[activeStep].config" class="w-full px-2 py-1 border rounded-lg text-xs font-mono h-24"></textarea>
                                </div>
                            </div>
                        </div>
                    </template>

                    <template x-if="activeStep === null">
                        <div class="text-center py-12 text-gray-400">
                            <div class="text-4xl mb-4">👈</div>
                            <p>Wählen Sie einen Schritt aus</p>
                        </div>
                    </template>
                </div>
            </div>

            <!-- Footer -->
            <div class="bg-gray-100 border-t px-6 py-4 flex justify-between items-center">
                <div class="text-sm text-gray-600">
                    📊 <span x-text="`${steps.length} Schritte`"></span>
                </div>
                <div class="flex gap-3">
                    <button @click="exportWorkflow()" class="px-4 py-2 bg-purple-500 hover:bg-purple-600 text-white rounded-lg transition">
                        📥 Exportieren
                    </button>
                    <button @click="saveWorkflow()" class="px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg transition">
                        💾 Speichern
                    </button>
                </div>
            </div>

            <?php else: ?>
            <!-- No Workflow Selected -->
            <div class="flex-1 flex items-center justify-center">
                <div class="text-center">
                    <div class="text-6xl mb-4">📋</div>
                    <h2 class="text-2xl font-bold text-gray-800 mb-2">Keinen Workflow ausgewählt</h2>
                    <p class="text-gray-600 mb-6">Wählen Sie einen Workflow aus der Liste oder erstellen Sie einen neuen</p>
                    <button onclick="newWorkflow()" class="px-6 py-3 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition">
                        ➕ Neuer Workflow
                    </button>
                </div>
            </div>
            <?php endif; ?>
        </div>
    </div>

    <script>
        function workflowBuilder() {
            return {
                steps: <?= json_encode($currentWorkflow['steps'] ?? []) ?>,
                activeStep: null,
                previewMode: false,

                addStep() {
                    this.steps.push({
                        title: 'Neuer Schritt',
                        description: '',
                        role: 'HR',
                        condition: '',
                        required: true,
                        timeLimit: 0,
                        config: '{}'
                    });
                    this.activeStep = this.steps.length - 1;
                },

                editStep(idx) {
                    this.activeStep = this.activeStep === idx ? null : idx;
                },

                removeStep(idx) {
                    if (confirm('Schritt wirklich löschen?')) {
                        this.steps.splice(idx, 1);
                        this.activeStep = null;
                    }
                },

                saveWorkflow() {
                    const data = {
                        id: <?= json_encode($currentWorkflow['id'] ?? null) ?>,
                        name: document.querySelector('h1').textContent.replace('🏗️ ', '').trim(),
                        description: '',
                        steps: this.steps
                    };

                    const formData = new FormData();
                    formData.append('ajax', 'save_workflow');
                    formData.append('data', JSON.stringify(data));

                    fetch(window.location.pathname, { method: 'POST', body: formData })
                        .then(r => r.json())
                        .then(r => {
                            if (r.success) {
                                alert('✅ Workflow gespeichert!');
                                location.reload();
                            }
                        });
                },

                exportWorkflow() {
                    const json = JSON.stringify(this.steps, null, 2);
                    const blob = new Blob([json], { type: 'application/json' });
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = 'workflow.json';
                    a.click();
                }
            };
        }

        function selectWorkflow(id) {
            location.href = '?action=edit&id=' + id;
        }

        function newWorkflow() {
            const name = prompt('Workflow Name:');
            if (!name) return;

            const formData = new FormData();
            formData.append('ajax', 'save_workflow');
            formData.append('data', JSON.stringify({ name, description: '', steps: [] }));

            fetch(window.location.pathname, { method: 'POST', body: formData })
                .then(r => r.json())
                .then(r => {
                    if (r.success) {
                        location.href = '?action=edit&id=' + r.id;
                    }
                });
        }

        function duplicateWorkflow(id, e) {
            e.stopPropagation();
            const formData = new FormData();
            formData.append('ajax', 'duplicate_workflow');
            formData.append('id', id);

            fetch(window.location.pathname, { method: 'POST', body: formData })
                .then(r => r.json())
                .then(r => {
                    if (r.success) {
                        location.href = '?action=edit&id=' + r.id;
                    }
                });
        }

        function deleteWorkflow(id, e) {
            e.stopPropagation();
            if (!confirm('Workflow wirklich löschen?')) return;

            const formData = new FormData();
            formData.append('ajax', 'delete_workflow');
            formData.append('id', id);

            fetch(window.location.pathname, { method: 'POST', body: formData })
                .then(r => r.json())
                .then(r => {
                    if (r.success) {
                        location.href = window.location.pathname;
                    }
                });
        }
    </script>
</body>
</html>
?>
