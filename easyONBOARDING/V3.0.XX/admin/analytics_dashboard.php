<?php
require_once '../config.php';
redirectIfNotAdmin();

// Statistiken abrufen
$stats = [
    'total_cases' => 0,
    'completed_cases' => 0,
    'pending_cases' => 0,
    'total_users' => 0,
    'active_users' => 0,
];

$stmt = $db->query('SELECT COUNT(*) as cnt FROM onboarding_cases');
$stats['total_cases'] = $stmt->fetch()['cnt'];

$stmt = $db->query('SELECT COUNT(*) as cnt FROM onboarding_cases WHERE status = "completed"');
$stats['completed_cases'] = $stmt->fetch()['cnt'];

$stmt = $db->query('SELECT COUNT(*) as cnt FROM onboarding_cases WHERE status = "pending"');
$stats['pending_cases'] = $stmt->fetch()['cnt'];

$stmt = $db->query('SELECT COUNT(*) as cnt FROM users');
$stats['total_users'] = $stmt->fetch()['cnt'];

$stmt = $db->query('SELECT COUNT(*) as cnt FROM users WHERE is_active = 1');
$stats['active_users'] = $stmt->fetch()['cnt'];

// Case-Status für Pie-Chart
$stmt = $db->query('SELECT status, COUNT(*) as count FROM onboarding_cases GROUP BY status');
$casesByStatus = $stmt->fetchAll(PDO::FETCH_KEY_PAIR);

// Cases pro Woche (Zeitreihe)
$stmt = $db->query('SELECT DATE(created_at) as date, COUNT(*) as count FROM onboarding_cases WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) GROUP BY DATE(created_at) ORDER BY date');
$casesTrend = [];
foreach ($stmt->fetchAll() as $row) {
    $casesTrend[$row['date']] = $row['count'];
}

// Cases pro Abteilung
$stmt = $db->query('SELECT department, COUNT(*) as count FROM onboarding_cases WHERE department IS NOT NULL GROUP BY department ORDER BY count DESC LIMIT 10');
$casesByDepartment = [];
foreach ($stmt->fetchAll() as $row) {
    $casesByDepartment[$row['department']] = $row['count'];
}

// Rollen-Statistiken
$stmt = $db->query('SELECT role, COUNT(*) as count FROM users GROUP BY role ORDER BY count DESC');
$usersByRole = [];
foreach ($stmt->fetchAll() as $row) {
    $usersByRole[$row['role']] = $row['count'];
}

// Aktive Cases pro Rolle
$stmt = $db->query('SELECT ws.role, COUNT(DISTINCT sp.case_id) as count FROM workflow_steps ws JOIN step_progress sp ON ws.id = sp.step_id WHERE sp.status = "pending" GROUP BY ws.role');
$casesByRole = [];
foreach ($stmt->fetchAll() as $row) {
    $casesByRole[$row['role']] = $row['count'];
}

// Letzte Aktivitäten
$stmt = $db->query('SELECT * FROM logs ORDER BY created_at DESC LIMIT 10');
$recentActivities = $stmt->fetchAll();
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Analytics & Statistiken - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/3.9.1/chart.min.js"></script>
</head>
<body class="bg-gray-50 font-sans">
    <div class="min-h-screen">
        <!-- Header -->
        <div class="bg-white shadow-md border-b border-gray-200 sticky top-0 z-10">
            <div class="max-w-7xl mx-auto px-6 py-4">
                <div class="flex items-center justify-between">
                    <div>
                        <h1 class="text-3xl font-bold text-gray-800">📊 Analytics & Statistiken</h1>
                        <p class="text-gray-600 mt-1">Systemübersicht und Key Performance Indicators</p>
                    </div>
                    <a href="dashboard.php" class="text-gray-600 hover:bg-gray-100 px-4 py-2 rounded-lg transition-colors">
                        ← Zurück
                    </a>
                </div>
            </div>
        </div>

        <main class="max-w-7xl mx-auto p-6">
            <!-- KPI Cards -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4 mb-8">
                <div class="bg-white rounded-lg shadow p-6 border-l-4 border-blue-500">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="text-gray-600 text-sm font-semibold">Gesamt Cases</p>
                            <p class="text-3xl font-bold text-gray-800 mt-2"><?php echo $stats['total_cases']; ?></p>
                        </div>
                        <div class="text-4xl">📋</div>
                    </div>
                </div>

                <div class="bg-white rounded-lg shadow p-6 border-l-4 border-green-500">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="text-gray-600 text-sm font-semibold">Abgeschlossen</p>
                            <p class="text-3xl font-bold text-gray-800 mt-2"><?php echo $stats['completed_cases']; ?></p>
                        </div>
                        <div class="text-4xl">✅</div>
                    </div>
                </div>

                <div class="bg-white rounded-lg shadow p-6 border-l-4 border-yellow-500">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="text-gray-600 text-sm font-semibold">Ausstehend</p>
                            <p class="text-3xl font-bold text-gray-800 mt-2"><?php echo $stats['pending_cases']; ?></p>
                        </div>
                        <div class="text-4xl">⏳</div>
                    </div>
                </div>

                <div class="bg-white rounded-lg shadow p-6 border-l-4 border-purple-500">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="text-gray-600 text-sm font-semibold">Benutzer</p>
                            <p class="text-3xl font-bold text-gray-800 mt-2"><?php echo $stats['total_users']; ?></p>
                        </div>
                        <div class="text-4xl">👥</div>
                    </div>
                </div>

                <div class="bg-white rounded-lg shadow p-6 border-l-4 border-green-600">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="text-gray-600 text-sm font-semibold">Aktiv</p>
                            <p class="text-3xl font-bold text-gray-800 mt-2"><?php echo $stats['active_users']; ?></p>
                        </div>
                        <div class="text-4xl">🟢</div>
                    </div>
                </div>
            </div>

            <!-- Charts -->
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
                <!-- Case Status Pie Chart -->
                <div class="bg-white rounded-lg shadow p-6">
                    <h3 class="text-lg font-semibold text-gray-800 mb-4">Case-Status Verteilung</h3>
                    <canvas id="statusChart" height="80"></canvas>
                </div>

                <!-- Users by Role Pie Chart -->
                <div class="bg-white rounded-lg shadow p-6">
                    <h3 class="text-lg font-semibold text-gray-800 mb-4">Benutzer pro Rolle</h3>
                    <canvas id="rolesChart" height="80"></canvas>
                </div>

                <!-- Cases Trend Line Chart -->
                <div class="bg-white rounded-lg shadow p-6">
                    <h3 class="text-lg font-semibold text-gray-800 mb-4">Case-Trend (30 Tage)</h3>
                    <canvas id="trendChart" height="80"></canvas>
                </div>

                <!-- Cases by Department Bar Chart -->
                <div class="bg-white rounded-lg shadow p-6">
                    <h3 class="text-lg font-semibold text-gray-800 mb-4">Cases pro Abteilung</h3>
                    <canvas id="departmentChart" height="80"></canvas>
                </div>

                <!-- Pending Cases by Role -->
                <div class="bg-white rounded-lg shadow p-6">
                    <h3 class="text-lg font-semibold text-gray-800 mb-4">Ausstehende Cases pro Rolle</h3>
                    <canvas id="pendingRolesChart" height="80"></canvas>
                </div>

                <!-- Completion Rate -->
                <div class="bg-white rounded-lg shadow p-6">
                    <h3 class="text-lg font-semibold text-gray-800 mb-4">Abschlussrate</h3>
                    <div class="flex items-center justify-center h-80">
                        <div class="text-center">
                            <div class="text-6xl font-bold text-blue-600">
                                <?php echo $stats['total_cases'] > 0 ? round(($stats['completed_cases'] / $stats['total_cases']) * 100) : 0; ?>%
                            </div>
                            <p class="text-gray-600 mt-4">von <?php echo $stats['total_cases']; ?> Cases</p>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Recent Activities -->
            <div class="bg-white rounded-lg shadow p-6">
                <h3 class="text-lg font-semibold text-gray-800 mb-4">Letzte Aktivitäten</h3>
                <div class="overflow-x-auto">
                    <table class="w-full">
                        <thead class="bg-gray-100 border-b">
                            <tr>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-700">Zeit</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-700">Benutzer</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-700">Aktion</th>
                                <th class="px-6 py-3 text-left text-sm font-semibold text-gray-700">Details</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            <?php foreach ($recentActivities as $activity): ?>
                                <tr class="hover:bg-gray-50">
                                    <td class="px-6 py-3 text-sm text-gray-600">
                                        <?php echo date('d.m.Y H:i', strtotime($activity['created_at'])); ?>
                                    </td>
                                    <td class="px-6 py-3 text-sm font-semibold text-gray-800">
                                        <?php echo htmlspecialchars($activity['user_id']); ?>
                                    </td>
                                    <td class="px-6 py-3 text-sm">
                                        <span class="bg-blue-100 text-blue-800 px-2 py-1 rounded text-xs font-semibold">
                                            <?php echo htmlspecialchars($activity['action']); ?>
                                        </span>
                                    </td>
                                    <td class="px-6 py-3 text-sm text-gray-600">
                                        <?php echo htmlspecialchars(substr($activity['details'], 0, 50)); ?>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </main>
    </div>

    <script>
        // Case Status Chart
        new Chart(document.getElementById('statusChart'), {
            type: 'doughnut',
            data: {
                labels: <?php echo json_encode(array_keys($casesByStatus)); ?>,
                datasets: [{
                    data: <?php echo json_encode(array_values($casesByStatus)); ?>,
                    backgroundColor: ['#3b82f6', '#10b981', '#f59e0b', '#ef4444'],
                    borderColor: ['#1e3a8a', '#047857', '#b45309', '#991b1b'],
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: { position: 'bottom' }
                }
            }
        });

        // Users by Role Chart
        new Chart(document.getElementById('rolesChart'), {
            type: 'pie',
            data: {
                labels: <?php echo json_encode(array_keys($usersByRole)); ?>,
                datasets: [{
                    data: <?php echo json_encode(array_values($usersByRole)); ?>,
                    backgroundColor: ['#3b82f6', '#10b981', '#f59e0b', '#8b5cf6', '#ec4899'],
                    borderColor: '#fff',
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: { position: 'bottom' }
                }
            }
        });

        // Cases Trend Chart
        new Chart(document.getElementById('trendChart'), {
            type: 'line',
            data: {
                labels: <?php echo json_encode(array_keys($casesTrend)); ?>,
                datasets: [{
                    label: 'Neue Cases',
                    data: <?php echo json_encode(array_values($casesTrend)); ?>,
                    borderColor: '#3b82f6',
                    backgroundColor: 'rgba(59, 130, 246, 0.1)',
                    tension: 0.4,
                    fill: true,
                    pointBackgroundColor: '#3b82f6',
                    pointBorderColor: '#fff',
                    pointBorderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: { display: true }
                },
                scales: {
                    y: { beginAtZero: true }
                }
            }
        });

        // Cases by Department Chart
        new Chart(document.getElementById('departmentChart'), {
            type: 'bar',
            data: {
                labels: <?php echo json_encode(array_keys($casesByDepartment)); ?>,
                datasets: [{
                    label: 'Cases',
                    data: <?php echo json_encode(array_values($casesByDepartment)); ?>,
                    backgroundColor: '#3b82f6',
                    borderColor: '#1e3a8a',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                indexAxis: 'y',
                plugins: {
                    legend: { display: false }
                }
            }
        });

        // Pending Cases by Role Chart
        new Chart(document.getElementById('pendingRolesChart'), {
            type: 'bar',
            data: {
                labels: <?php echo json_encode(array_keys($casesByRole)); ?>,
                datasets: [{
                    label: 'Ausstehend',
                    data: <?php echo json_encode(array_values($casesByRole)); ?>,
                    backgroundColor: '#f59e0b',
                    borderColor: '#b45309',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: { display: false }
                },
                scales: {
                    y: { beginAtZero: true }
                }
            }
        });
    </script>
</body>
</html>
