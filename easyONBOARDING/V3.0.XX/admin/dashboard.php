<?php
require_once '../config.php';
redirectIfNotAdmin();

$tab = $_GET['tab'] ?? 'overview';

// Statistiken abrufen
$stats = [];
$stmt = $db->query('SELECT COUNT(*) as total FROM onboarding_cases');
$stats['total_cases'] = $stmt->fetch(PDO::FETCH_ASSOC)['total'];

$stmt = $db->query('SELECT COUNT(*) as completed FROM onboarding_cases WHERE status = "completed"');
$stats['completed'] = $stmt->fetch(PDO::FETCH_ASSOC)['completed'];

$stmt = $db->query('SELECT COUNT(*) as pending FROM onboarding_cases WHERE status = "pending"');
$stats['pending'] = $stmt->fetch(PDO::FETCH_ASSOC)['pending'];

$stmt = $db->query('SELECT COUNT(*) as active FROM users WHERE is_active = TRUE');
$stats['active_users'] = $stmt->fetch(PDO::FETCH_ASSOC)['active_users'];

// Workflows abrufen
$workflows_stmt = $db->query('SELECT * FROM workflows');
$workflows = $workflows_stmt->fetchAll(PDO::FETCH_ASSOC);

// Benutzer abrufen
$users_stmt = $db->query('SELECT * FROM users ORDER BY created_at DESC');
$users = $users_stmt->fetchAll(PDO::FETCH_ASSOC);
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Dashboard - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
</head>
<body class="bg-gray-50 font-sans">
    <div class="min-h-screen flex">
        <!-- Sidebar -->
        <aside class="w-64 bg-white shadow-lg">
            <div class="p-6">
                <div class="flex items-center gap-3 mb-8">
                    <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" stroke-linecap="round" stroke-linejoin="round"></path>
                    </svg>
                    <h1 class="text-lg font-bold text-gray-800">Admin Panel</h1>
                </div>

                <nav class="space-y-2">
                    <a href="?tab=overview" class="<?php echo $tab === 'overview' ? 'bg-blue-100 text-blue-600' : 'text-gray-600 hover:bg-gray-100'; ?> block px-4 py-2 rounded-lg transition-colors">
                        📊 Übersicht
                    </a>
                    <a href="analytics_dashboard.php" class="text-gray-600 hover:bg-gray-100 block px-4 py-2 rounded-lg transition-colors">
                        📈 Analytics
                    </a>
                    <a href="workflow_editor_ui.php" class="text-gray-600 hover:bg-gray-100 block px-4 py-2 rounded-lg transition-colors">
                        🎨 Workflow Editor
                    </a>
                    <a href="?tab=workflows" class="<?php echo $tab === 'workflows' ? 'bg-blue-100 text-blue-600' : 'text-gray-600 hover:bg-gray-100'; ?> block px-4 py-2 rounded-lg transition-colors">
                        🔄 Workflows
                    </a>
                    <a href="?tab=fields" class="<?php echo $tab === 'fields' ? 'bg-blue-100 text-blue-600' : 'text-gray-600 hover:bg-gray-100'; ?> block px-4 py-2 rounded-lg transition-colors">
                        📋 Formularfelder
                    </a>
                    <a href="?tab=users" class="<?php echo $tab === 'users' ? 'bg-blue-100 text-blue-600' : 'text-gray-600 hover:bg-gray-100'; ?> block px-4 py-2 rounded-lg transition-colors">
                        👥 Benutzer
                    </a>
                    <a href="?tab=cases" class="<?php echo $tab === 'cases' ? 'bg-blue-100 text-blue-600' : 'text-gray-600 hover:bg-gray-100'; ?> block px-4 py-2 rounded-lg transition-colors">
                        📁 Fälle
                    </a>
                    <a href="?tab=logs" class="<?php echo $tab === 'logs' ? 'bg-blue-100 text-blue-600' : 'text-gray-600 hover:bg-gray-100'; ?> block px-4 py-2 rounded-lg transition-colors">
                        📜 Audit-Log
                    </a>
                </nav>
            </div>

            <div class="absolute bottom-0 left-0 right-0 p-4 border-t border-gray-200 bg-gray-50">
                <p class="text-sm text-gray-600 mb-2">Angemeldet als:</p>
                <p class="text-sm font-semibold text-gray-800"><?php echo $_SESSION['first_name'] . ' ' . $_SESSION['last_name']; ?></p>
                <a href="../logout.php" class="text-xs text-blue-600 hover:underline mt-2 inline-block">Abmelden</a>
            </div>
        </aside>

        <!-- Main Content -->
        <main class="flex-1 p-8">
            <?php if ($tab === 'overview'): ?>
                <h2 class="text-3xl font-bold text-gray-800 mb-8">Dashboard Übersicht</h2>

                <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
                    <div class="bg-white rounded-lg shadow p-6">
                        <div class="flex items-center justify-between">
                            <div>
                                <p class="text-gray-600 text-sm">Gesamte Fälle</p>
                                <p class="text-3xl font-bold text-gray-800"><?php echo $stats['total_cases']; ?></p>
                            </div>
                            <div class="bg-blue-100 p-3 rounded-full">
                                <svg class="h-6 w-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path>
                                </svg>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow p-6">
                        <div class="flex items-center justify-between">
                            <div>
                                <p class="text-gray-600 text-sm">Abgeschlossen</p>
                                <p class="text-3xl font-bold text-green-600"><?php echo $stats['completed']; ?></p>
                            </div>
                            <div class="bg-green-100 p-3 rounded-full">
                                <svg class="h-6 w-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                </svg>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow p-6">
                        <div class="flex items-center justify-between">
                            <div>
                                <p class="text-gray-600 text-sm">Ausstehend</p>
                                <p class="text-3xl font-bold text-orange-600"><?php echo $stats['pending']; ?></p>
                            </div>
                            <div class="bg-orange-100 p-3 rounded-full">
                                <svg class="h-6 w-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                                </svg>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow p-6">
                        <div class="flex items-center justify-between">
                            <div>
                                <p class="text-gray-600 text-sm">Aktive Benutzer</p>
                                <p class="text-3xl font-bold text-purple-600"><?php echo $stats['active_users']; ?></p>
                            </div>
                            <div class="bg-purple-100 p-3 rounded-full">
                                <svg class="h-6 w-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 12H9m6 0H9m6 0a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                                </svg>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="bg-white rounded-lg shadow p-6">
                    <h3 class="text-xl font-semibold text-gray-800 mb-4">Schnellstart</h3>
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <a href="?tab=workflows" class="p-4 border-2 border-dashed border-blue-300 rounded-lg hover:border-blue-500 transition-colors">
                            <p class="font-semibold text-blue-600">Workflow erstellen</p>
                            <p class="text-sm text-gray-600">Neuen Onboarding-Workflow definieren</p>
                        </a>
                        <a href="?tab=users" class="p-4 border-2 border-dashed border-green-300 rounded-lg hover:border-green-500 transition-colors">
                            <p class="font-semibold text-green-600">Benutzer hinzufügen</p>
                            <p class="text-sm text-gray-600">Neue Benutzer oder Rollen erstellen</p>
                        </a>
                        <a href="?tab=fields" class="p-4 border-2 border-dashed border-purple-300 rounded-lg hover:border-purple-500 transition-colors">
                            <p class="font-semibold text-purple-600">Felder verwalten</p>
                            <p class="text-sm text-gray-600">Formularfelder anpassen</p>
                        </a>
                    </div>
                </div>

            <?php elseif ($tab === 'workflows'): ?>
                <h2 class="text-3xl font-bold text-gray-800 mb-8">Workflows verwalten</h2>

                <div class="mb-6">
                    <a href="edit_workflow.php" class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors inline-flex items-center gap-2">
                        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
                        </svg>
                        Neuer Workflow
                    </a>
                </div>

                <div class="bg-white rounded-lg shadow overflow-hidden">
                    <table class="w-full">
                        <thead class="bg-gray-50 border-b border-gray-200">
                            <tr>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Name</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Beschreibung</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Status</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Aktionen</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            <?php foreach ($workflows as $workflow): ?>
                                <tr class="hover:bg-gray-50 transition-colors">
                                    <td class="px-6 py-4 text-sm font-medium text-gray-800"><?php echo htmlspecialchars($workflow['name']); ?></td>
                                    <td class="px-6 py-4 text-sm text-gray-600"><?php echo htmlspecialchars($workflow['description'] ?? '-'); ?></td>
                                    <td class="px-6 py-4 text-sm">
                                        <span class="<?php echo $workflow['is_active'] ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'; ?> px-3 py-1 rounded-full text-xs font-semibold">
                                            <?php echo $workflow['is_active'] ? 'Aktiv' : 'Inaktiv'; ?>
                                        </span>
                                    </td>
                                    <td class="px-6 py-4 text-sm space-x-2">
                                        <a href="edit_workflow.php?id=<?php echo $workflow['id']; ?>" class="text-blue-600 hover:underline">Bearbeiten</a>
                                        <a href="delete_workflow.php?id=<?php echo $workflow['id']; ?>" class="text-red-600 hover:underline" onclick="return confirm('Sicher?');">Löschen</a>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>

            <?php elseif ($tab === 'users'): ?>
                <h2 class="text-3xl font-bold text-gray-800 mb-8">Benutzer verwalten</h2>

                <div class="mb-6">
                    <a href="add_user.php" class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors inline-flex items-center gap-2">
                        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
                        </svg>
                        Benutzer hinzufügen
                    </a>
                </div>

                <div class="bg-white rounded-lg shadow overflow-hidden">
                    <table class="w-full">
                        <thead class="bg-gray-50 border-b border-gray-200">
                            <tr>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Name</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Benutzername</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Rolle</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Abteilung</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Status</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Aktionen</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            <?php foreach ($users as $user): ?>
                                <tr class="hover:bg-gray-50 transition-colors">
                                    <td class="px-6 py-4 text-sm font-medium text-gray-800"><?php echo htmlspecialchars($user['first_name'] . ' ' . $user['last_name']); ?></td>
                                    <td class="px-6 py-4 text-sm text-gray-600"><?php echo htmlspecialchars($user['username']); ?></td>
                                    <td class="px-6 py-4 text-sm"><span class="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-xs font-semibold"><?php echo $user['role']; ?></span></td>
                                    <td class="px-6 py-4 text-sm text-gray-600"><?php echo htmlspecialchars($user['department'] ?? '-'); ?></td>
                                    <td class="px-6 py-4 text-sm">
                                        <span class="<?php echo $user['is_active'] ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'; ?> px-3 py-1 rounded-full text-xs font-semibold">
                                            <?php echo $user['is_active'] ? 'Aktiv' : 'Inaktiv'; ?>
                                        </span>
                                    </td>
                                    <td class="px-6 py-4 text-sm space-x-2">
                                        <a href="edit_user.php?id=<?php echo $user['id']; ?>" class="text-blue-600 hover:underline">Bearbeiten</a>
                                        <a href="delete_user.php?id=<?php echo $user['id']; ?>" class="text-red-600 hover:underline" onclick="return confirm('Sicher?');">Löschen</a>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>

            <?php elseif ($tab === 'fields'): ?>
                <h2 class="text-3xl font-bold text-gray-800 mb-8">Formularfelder verwalten</h2>
                <div class="bg-white rounded-lg shadow p-6">
                    <p class="text-gray-600 mb-4">Wählen Sie einen Workflow und einen Schritt, um die Felder zu verwalten:</p>
                    <select id="workflow_select" class="w-full md:w-1/2 px-4 py-2 border border-gray-300 rounded-lg" onchange="loadSteps(this.value)">
                        <option value="">-- Workflow wählen --</option>
                        <?php foreach ($workflows as $wf): ?>
                            <option value="<?php echo $wf['id']; ?>"><?php echo htmlspecialchars($wf['name']); ?></option>
                        <?php endforeach; ?>
                    </select>

                    <div id="steps_container" class="mt-6 hidden">
                        <select id="step_select" class="w-full md:w-1/2 px-4 py-2 border border-gray-300 rounded-lg" onchange="loadFields(this.value)">
                            <option value="">-- Schritt wählen --</option>
                        </select>
                    </div>

                    <div id="fields_container" class="mt-6 hidden">
                        <div id="fields_list"></div>
                        <button onclick="addNewField()" class="mt-4 bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors">
                            + Feld hinzufügen
                        </button>
                    </div>
                </div>

            <?php elseif ($tab === 'cases'): ?>
                <h2 class="text-3xl font-bold text-gray-800 mb-8">Onboarding-Fälle</h2>
                <?php
                    $cases_stmt = $db->query('SELECT * FROM onboarding_cases ORDER BY created_at DESC');
                    $cases = $cases_stmt->fetchAll(PDO::FETCH_ASSOC);
                ?>
                <div class="bg-white rounded-lg shadow overflow-hidden">
                    <table class="w-full">
                        <thead class="bg-gray-50 border-b border-gray-200">
                            <tr>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Fallnummer</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Mitarbeiter</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Status</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Aktuelle Rolle</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Erstellungsdatum</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Aktionen</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            <?php foreach ($cases as $case): ?>
                                <tr class="hover:bg-gray-50 transition-colors">
                                    <td class="px-6 py-4 text-sm font-medium text-gray-800"><?php echo htmlspecialchars($case['case_number']); ?></td>
                                    <td class="px-6 py-4 text-sm text-gray-600"><?php echo htmlspecialchars($case['employee_first_name'] . ' ' . $case['employee_last_name']); ?></td>
                                    <td class="px-6 py-4 text-sm">
                                        <span class="<?php 
                                            $status_colors = [
                                                'pending' => 'bg-orange-100 text-orange-800',
                                                'in_progress' => 'bg-blue-100 text-blue-800',
                                                'completed' => 'bg-green-100 text-green-800',
                                                'rejected' => 'bg-red-100 text-red-800'
                                            ];
                                            echo $status_colors[$case['status']] ?? 'bg-gray-100 text-gray-800';
                                        ?> px-3 py-1 rounded-full text-xs font-semibold">
                                            <?php echo ucfirst($case['status']); ?>
                                        </span>
                                    </td>
                                    <td class="px-6 py-4 text-sm text-gray-600"><?php echo $case['current_role']; ?></td>
                                    <td class="px-6 py-4 text-sm text-gray-600"><?php echo date('d.m.Y', strtotime($case['created_at'])); ?></td>
                                    <td class="px-6 py-4 text-sm space-x-2">
                                        <a href="view_case.php?id=<?php echo $case['id']; ?>" class="text-blue-600 hover:underline">Anzeigen</a>
                                        <a href="export_case.php?id=<?php echo $case['id']; ?>" class="text-green-600 hover:underline">Exportieren</a>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>

            <?php elseif ($tab === 'logs'): ?>
                <h2 class="text-3xl font-bold text-gray-800 mb-8">Audit-Log</h2>
                <?php
                    $logs_stmt = $db->query('SELECT l.*, u.username FROM logs l LEFT JOIN users u ON l.user_id = u.id ORDER BY l.created_at DESC LIMIT 100');
                    $logs = $logs_stmt->fetchAll(PDO::FETCH_ASSOC);
                ?>
                <div class="bg-white rounded-lg shadow overflow-hidden">
                    <table class="w-full">
                        <thead class="bg-gray-50 border-b border-gray-200">
                            <tr>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Benutzer</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Aktion</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Details</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-600">Zeitstempel</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            <?php foreach ($logs as $log): ?>
                                <tr class="hover:bg-gray-50 transition-colors">
                                    <td class="px-6 py-4 text-sm font-medium text-gray-800"><?php echo htmlspecialchars($log['username'] ?? 'System'); ?></td>
                                    <td class="px-6 py-4 text-sm text-gray-600"><?php echo htmlspecialchars($log['action']); ?></td>
                                    <td class="px-6 py-4 text-sm text-gray-600"><?php echo htmlspecialchars($log['details'] ?? '-'); ?></td>
                                    <td class="px-6 py-4 text-sm text-gray-600"><?php echo date('d.m.Y H:i:s', strtotime($log['created_at'])); ?></td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </main>
    </div>

    <script>
        async function loadSteps(workflowId) {
            if (!workflowId) {
                document.getElementById('steps_container').classList.add('hidden');
                return;
            }

            const response = await fetch('../api/get_steps.php?workflow_id=' + workflowId);
            const steps = await response.json();

            const stepSelect = document.getElementById('step_select');
            stepSelect.innerHTML = '<option value="">-- Schritt wählen --</option>';

            steps.forEach(step => {
                const option = document.createElement('option');
                option.value = step.id;
                option.textContent = `Schritt ${step.step_number}: ${step.title}`;
                stepSelect.appendChild(option);
            });

            document.getElementById('steps_container').classList.remove('hidden');
            document.getElementById('fields_container').classList.add('hidden');
        }

        async function loadFields(stepId) {
            if (!stepId) {
                document.getElementById('fields_container').classList.add('hidden');
                return;
            }

            const response = await fetch('../api/get_fields.php?step_id=' + stepId);
            const fields = await response.json();

            const fieldsList = document.getElementById('fields_list');
            fieldsList.innerHTML = '';

            fields.forEach((field, index) => {
                const fieldHtml = `
                    <div class="mb-4 p-4 border border-gray-200 rounded-lg">
                        <div class="flex justify-between items-start">
                            <div class="flex-1">
                                <p class="font-semibold text-gray-800">${field.label}</p>
                                <p class="text-sm text-gray-600">Typ: ${field.field_type} | Pflichtfeld: ${field.is_required ? 'Ja' : 'Nein'}</p>
                            </div>
                            <button onclick="editField(${field.id})" class="text-blue-600 hover:underline mr-2">Bearbeiten</button>
                            <button onclick="deleteField(${field.id})" class="text-red-600 hover:underline">Löschen</button>
                        </div>
                    </div>
                `;
                fieldsList.insertAdjacentHTML('beforeend', fieldHtml);
            });

            document.getElementById('fields_container').classList.remove('hidden');
        }

        function addNewField() {
            const stepId = document.getElementById('step_select').value;
            if (!stepId) {
                alert('Bitte wählen Sie zuerst einen Schritt.');
                return;
            }
            window.location.href = 'add_field.php?step_id=' + stepId;
        }

        function editField(fieldId) {
            window.location.href = 'edit_field.php?id=' + fieldId;
        }

        function deleteField(fieldId) {
            if (confirm('Dieses Feld wirklich löschen?')) {
                window.location.href = 'delete_field.php?id=' + fieldId;
            }
        }
    </script>
</body>
</html>
