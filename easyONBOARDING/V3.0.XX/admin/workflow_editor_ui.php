<?php
require_once '../config.php';
redirectIfNotAdmin();

// Alle Workflows abrufen
$stmt = $db->query('SELECT * FROM workflows ORDER BY created_at DESC');
$workflows = $stmt->fetchAll();

// Workflow-ID aus URL
$workflowId = intval($_GET['id'] ?? 0);
$workflow = null;
$steps = [];

if ($workflowId) {
    $stmt = $db->prepare('SELECT * FROM workflows WHERE id = ?');
    $stmt->execute([$workflowId]);
    $workflow = $stmt->fetch();

    if ($workflow) {
        $stmt = $db->prepare('SELECT * FROM workflow_steps WHERE workflow_id = ? ORDER BY step_number');
        $stmt->execute([$workflowId]);
        $steps = $stmt->fetchAll();
    }
}
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Workflow-Editor - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
</head>
<body class="bg-gray-50 font-sans">
    <div class="min-h-screen flex">
        <!-- Sidebar -->
        <aside class="w-64 bg-white shadow-lg border-r border-gray-200 overflow-y-auto">
            <div class="p-6">
                <div class="flex items-center gap-3 mb-8">
                    <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path d="M13 10V3L4 14h7v7l9-11h-7z" stroke-linecap="round" stroke-linejoin="round"></path>
                    </svg>
                    <h1 class="text-lg font-bold text-gray-800">Workflow Editor</h1>
                </div>

                <div class="mb-6">
                    <h3 class="text-sm font-semibold text-gray-700 mb-3 uppercase tracking-wide">Workflows</h3>
                    <div class="space-y-2 max-h-96 overflow-y-auto">
                        <?php foreach ($workflows as $w): ?>
                            <a href="?id=<?php echo $w['id']; ?>" 
                               class="block px-4 py-2 rounded-lg transition-colors <?php echo ($workflowId === $w['id']) ? 'bg-blue-100 text-blue-700 border-l-4 border-blue-600' : 'text-gray-700 hover:bg-gray-100'; ?>">
                                <div class="font-semibold text-sm"><?php echo htmlspecialchars($w['name']); ?></div>
                                <div class="text-xs text-gray-500 mt-1">
                                    <?php
                                    $stmt = $db->prepare('SELECT COUNT(*) as cnt FROM workflow_steps WHERE workflow_id = ?');
                                    $stmt->execute([$w['id']]);
                                    $count = $stmt->fetch()['cnt'];
                                    echo $count . ' Schritte';
                                    ?>
                                </div>
                            </a>
                        <?php endforeach; ?>
                    </div>
                </div>

                <a href="edit_workflow.php" class="w-full bg-blue-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors inline-block text-center text-sm">
                    ➕ Neuer Workflow
                </a>
            </div>
        </aside>

        <!-- Main Content -->
        <main class="flex-1 p-8 overflow-auto">
            <?php if (!$workflow): ?>
                <!-- Keine Workflow ausgewählt -->
                <div class="flex items-center justify-center h-screen">
                    <div class="text-center">
                        <svg class="h-16 w-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                            <path d="M13 10V3L4 14h7v7l9-11h-7z" stroke-linecap="round" stroke-linejoin="round"></path>
                        </svg>
                        <h2 class="text-2xl font-bold text-gray-800 mb-2">Wählen Sie einen Workflow aus</h2>
                        <p class="text-gray-600">Wählen Sie einen Workflow aus der Liste links aus, um ihn zu visualisieren und zu bearbeiten</p>
                    </div>
                </div>

            <?php else: ?>
                <!-- Workflow Editor -->
                <div class="mb-8">
                    <div class="flex items-center justify-between">
                        <div>
                            <h2 class="text-3xl font-bold text-gray-800 mb-2"><?php echo htmlspecialchars($workflow['name']); ?></h2>
                            <p class="text-gray-600"><?php echo htmlspecialchars($workflow['description']); ?></p>
                        </div>
                        <div class="flex gap-2">
                            <a href="edit_workflow.php?id=<?php echo $workflow['id']; ?>" class="bg-blue-600 text-white font-semibold py-2 px-6 rounded-lg hover:bg-blue-700 transition-colors">
                                ✎ Bearbeiten
                            </a>
                            <label class="flex items-center">
                                <input type="checkbox" <?php echo $workflow['is_active'] ? 'checked' : ''; ?> disabled
                                       class="w-4 h-4 text-green-600 rounded">
                                <span class="ml-2 font-semibold text-gray-700"><?php echo $workflow['is_active'] ? 'Aktiv' : 'Inaktiv'; ?></span>
                            </label>
                        </div>
                    </div>
                </div>

                <!-- Workflow Visualization -->
                <div class="grid grid-cols-1 gap-8">
                    <!-- Flow Diagram -->
                    <div class="bg-white rounded-lg shadow p-8">
                        <h3 class="text-xl font-semibold text-gray-800 mb-6">📊 Workflow-Ablauf</h3>
                        <div id="workflow-canvas" class="relative w-full bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg p-8 min-h-96 overflow-x-auto border-2 border-dashed border-gray-300">
                            <svg id="workflow-svg" class="w-full" height="250" style="min-width: 100%;">
                                <!-- Steps werden hier gezeichnet -->
                            </svg>
                        </div>
                    </div>

                    <!-- Steps Table -->
                    <div class="bg-white rounded-lg shadow overflow-hidden">
                        <div class="px-8 py-6 bg-gradient-to-r from-blue-600 to-blue-700 border-b">
                            <h3 class="text-xl font-semibold text-white">Workflow-Schritte (<?php echo count($steps); ?>)</h3>
                        </div>

                        <?php if (empty($steps)): ?>
                            <div class="p-8 text-center text-gray-500">
                                <p class="text-lg mb-2">Keine Schritte vorhanden</p>
                                <p class="text-sm">
                                    <a href="edit_workflow.php?id=<?php echo $workflow['id']; ?>" class="text-blue-600 hover:underline">
                                        Klicken Sie hier, um Schritte hinzuzufügen
                                    </a>
                                </p>
                            </div>
                        <?php else: ?>
                            <div class="overflow-x-auto">
                                <table class="w-full">
                                    <thead class="bg-gray-100 border-b border-gray-200">
                                        <tr>
                                            <th class="px-8 py-4 text-left text-sm font-semibold text-gray-700">#</th>
                                            <th class="px-8 py-4 text-left text-sm font-semibold text-gray-700">Rolle</th>
                                            <th class="px-8 py-4 text-left text-sm font-semibold text-gray-700">Titel</th>
                                            <th class="px-8 py-4 text-left text-sm font-semibold text-gray-700">Felder</th>
                                            <th class="px-8 py-4 text-left text-sm font-semibold text-gray-700">Aktion</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-gray-200">
                                        <?php foreach ($steps as $step): ?>
                                            <?php
                                            $stmt = $db->prepare('SELECT COUNT(*) as cnt FROM form_fields WHERE step_id = ?');
                                            $stmt->execute([$step['id']]);
                                            $fieldCount = $stmt->fetch()['cnt'];
                                            ?>
                                            <tr class="hover:bg-blue-50 transition-colors">
                                                <td class="px-8 py-4">
                                                    <span class="bg-blue-100 text-blue-800 font-bold px-3 py-1 rounded-full text-sm">
                                                        <?php echo $step['step_number']; ?>
                                                    </span>
                                                </td>
                                                <td class="px-8 py-4">
                                                    <span class="bg-purple-100 text-purple-800 font-semibold px-3 py-1 rounded text-sm">
                                                        <?php echo htmlspecialchars($step['role']); ?>
                                                    </span>
                                                </td>
                                                <td class="px-8 py-4 font-semibold text-gray-800">
                                                    <?php echo htmlspecialchars($step['title']); ?>
                                                </td>
                                                <td class="px-8 py-4">
                                                    <span class="bg-green-100 text-green-800 font-semibold px-3 py-1 rounded text-sm">
                                                        <?php echo $fieldCount; ?> Felder
                                                    </span>
                                                </td>
                                                <td class="px-8 py-4">
                                                    <a href="add_field.php?step_id=<?php echo $step['id']; ?>" 
                                                       class="text-blue-600 hover:text-blue-800 font-semibold text-sm">
                                                        📋 Verwalten
                                                    </a>
                                                </td>
                                            </tr>
                                        <?php endforeach; ?>
                                    </tbody>
                                </table>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            <?php endif; ?>
        </main>
    </div>

    <script>
        function drawWorkflow() {
            const steps = <?php echo json_encode($steps); ?>;
            const svg = document.getElementById('workflow-svg');
            
            if (steps.length === 0) {
                svg.innerHTML = '<text x="50%" y="50%" text-anchor="middle" fill="#999">Keine Schritte vorhanden</text>';
                return;
            }

            let svgContent = '';
            const stepWidth = 140;
            const stepHeight = 80;
            const spacing = 40;
            const startY = 50;
            
            // Arrow Marker
            svgContent += `
                <defs>
                    <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
                        <polygon points="0 0, 10 3, 0 6" fill="#3b82f6" />
                    </marker>
                </defs>
            `;

            // Draw steps and arrows
            for (let i = 0; i < steps.length; i++) {
                const step = steps[i];
                const x = i * (stepWidth + spacing) + 20;
                const y = startY;

                // Role badge
                const roleColor = {
                    'HR': '#dbeafe', 'IT': '#dcfce7', 'Chef': '#fed7aa', 
                    'Abteilungsleiter': '#e0e7ff', 'Admin': '#fce7f3'
                }[step.role] || '#e5e7eb';
                const roleTextColor = {
                    'HR': '#0369a1', 'IT': '#15803d', 'Chef': '#b45309',
                    'Abteilungsleiter': '#3730a3', 'Admin': '#be185d'
                }[step.role] || '#374151';

                // Step box
                svgContent += `
                    <g class="step-box">
                        <rect x="${x}" y="${y}" width="${stepWidth}" height="${stepHeight}" 
                              fill="${roleColor}" stroke="#3b82f6" stroke-width="2" rx="8" />
                        <text x="${x + stepWidth/2}" y="${y + 25}" text-anchor="middle" 
                              font-size="14" font-weight="bold" fill="${roleTextColor}">
                            Schritt ${step.step_number}
                        </text>
                        <text x="${x + stepWidth/2}" y="${y + 50}" text-anchor="middle" 
                              font-size="11" fill="#666" style="word-wrap: break-word;">
                            ${step.role}
                        </text>
                        <text x="${x + stepWidth/2}" y="${y + 65}" text-anchor="middle" 
                              font-size="10" fill="#999">
                            ${step.title.substring(0, 15)}...
                        </text>
                    </g>
                `;

                // Arrow to next step
                if (i < steps.length - 1) {
                    const nextX = (i + 1) * (stepWidth + spacing) + 20;
                    svgContent += `
                        <line x1="${x + stepWidth}" y1="${y + stepHeight/2}" 
                              x2="${nextX}" y2="${y + stepHeight/2}" 
                              stroke="#3b82f6" stroke-width="2" marker-end="url(#arrowhead)" />
                    `;
                }
            }

            svg.innerHTML = svgContent;
        }

        // Draw on page load
        document.addEventListener('DOMContentLoaded', drawWorkflow);
    </script>
</body>
</html>
