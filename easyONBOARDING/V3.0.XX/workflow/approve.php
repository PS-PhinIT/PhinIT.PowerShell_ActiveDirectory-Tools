<?php
require_once '../config.php';
redirectIfNotLoggedIn();

$role = $_SESSION['role'];
$userId = $_SESSION['user_id'];

// Überprüfe ob Benutzer für Genehmigung berechtigt ist
$allowed_roles = ['Abteilungsleiter', 'Chef', 'IT', 'HR'];
if (!in_array($role, $allowed_roles)) {
    header('Location: ' . SITE_URL . 'index.php');
    exit();
}

$message = '';
$error = '';

// Genehmigung/Ablehnung verarbeiten
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $caseId = intval($_POST['case_id']);
    $action = sanitize($_POST['action']);
    $notes = sanitize($_POST['notes'] ?? '');

    try {
        $stmt = $db->prepare('SELECT * FROM onboarding_cases WHERE id = ?');
        $stmt->execute([$caseId]);
        $case = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$case || $case['current_role'] !== $role) {
            $error = 'Sie haben keine Berechtigung für diesen Fall.';
        } else {
            if ($action === 'approve') {
                // Bestimme nächste Rolle
                $role_sequence = ['HR', 'Abteilungsleiter', 'Chef', 'IT'];
                $current_index = array_search($case['current_role'], $role_sequence);
                
                if ($current_index !== false && isset($role_sequence[$current_index + 1])) {
                    // Nächste Rolle
                    $next_role = $role_sequence[$current_index + 1];
                    $new_status = 'in_progress';
                } else {
                    // Letzter Schritt - abgeschlossen
                    $next_role = $role;
                    $new_status = 'completed';
                }

                $stmt = $db->prepare('
                    UPDATE onboarding_cases 
                    SET current_role = ?, status = ?, current_step = current_step + 1, updated_at = NOW()
                    WHERE id = ?
                ');
                $stmt->execute([$next_role, $new_status, $caseId]);

                // Schritt-Fortschritt aktualisieren
                $stmt = $db->prepare('
                    UPDATE step_progress 
                    SET status = "completed", completed_at = NOW()
                    WHERE case_id = ? AND status = "pending" LIMIT 1
                ');
                $stmt->execute([$caseId]);

                logAction($userId, 'approve_case', 'Fall genehmigt: ' . $case['case_number']);
                $message = 'Fall erfolgreich genehmigt!';
            } elseif ($action === 'reject') {
                $stmt = $db->prepare('UPDATE onboarding_cases SET status = "rejected", updated_at = NOW() WHERE id = ?');
                $stmt->execute([$caseId]);

                logAction($userId, 'reject_case', 'Fall abgelehnt: ' . $case['case_number']);
                $error = 'Fall wurde abgelehnt.';
            }
        }
    } catch (Exception $e) {
        $error = 'Fehler: ' . $e->getMessage();
    }
}

// Fälle für aktuelle Rolle abrufen
$stmt = $db->prepare('
    SELECT * FROM onboarding_cases 
    WHERE current_role = ? AND status IN ("pending", "in_progress")
    ORDER BY created_at DESC
');
$stmt->execute([$role]);
$cases = $stmt->fetchAll(PDO::FETCH_ASSOC);
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Genehmigung - <?php echo SITE_NAME; ?></title>
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
                    <h1 class="text-lg font-bold text-gray-800">Genehmigung</h1>
                </div>

                <nav class="space-y-2">
                    <a href="approve.php" class="bg-blue-100 text-blue-600 block px-4 py-2 rounded-lg transition-colors">
                        ✔️ Genehmigung
                    </a>
                </nav>
            </div>

            <div class="absolute bottom-0 left-0 right-0 p-4 border-t border-gray-200 bg-gray-50">
                <p class="text-sm text-gray-600 mb-2">Rolle:</p>
                <p class="text-sm font-semibold text-gray-800"><?php echo $role; ?></p>
                <p class="text-xs text-gray-600 mt-2"><?php echo $_SESSION['first_name'] . ' ' . $_SESSION['last_name']; ?></p>
                <a href="../logout.php" class="text-xs text-blue-600 hover:underline mt-2 inline-block">Abmelden</a>
            </div>
        </aside>

        <!-- Main Content -->
        <main class="flex-1 p-8">
            <h2 class="text-3xl font-bold text-gray-800 mb-8">Genehmigung - <?php echo $role; ?></h2>

            <?php if (!empty($error)): ?>
                <div class="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700 rounded">
                    <?php echo htmlspecialchars($error); ?>
                </div>
            <?php endif; ?>

            <?php if (!empty($message)): ?>
                <div class="mb-6 p-4 bg-green-50 border-l-4 border-green-500 text-green-700 rounded">
                    <?php echo htmlspecialchars($message); ?>
                </div>
            <?php endif; ?>

            <div class="space-y-6">
                <?php if (empty($cases)): ?>
                    <div class="bg-white rounded-lg shadow p-8 text-center">
                        <p class="text-gray-600 text-lg">Keine Fälle zur Genehmigung ausstehend.</p>
                    </div>
                <?php else: ?>
                    <?php foreach ($cases as $case): ?>
                        <div class="bg-white rounded-lg shadow">
                            <div class="p-6 border-b border-gray-200">
                                <div class="flex justify-between items-start">
                                    <div>
                                        <h3 class="text-xl font-semibold text-gray-800"><?php echo htmlspecialchars($case['employee_first_name'] . ' ' . $case['employee_last_name']); ?></h3>
                                        <p class="text-sm text-gray-600">Fallnummer: <?php echo htmlspecialchars($case['case_number']); ?></p>
                                    </div>
                                    <span class="<?php 
                                        $status_colors = [
                                            'pending' => 'bg-orange-100 text-orange-800',
                                            'in_progress' => 'bg-blue-100 text-blue-800',
                                        ];
                                        echo $status_colors[$case['status']] ?? 'bg-gray-100 text-gray-800';
                                    ?> px-3 py-1 rounded-full text-xs font-semibold">
                                        <?php echo ucfirst($case['status']); ?>
                                    </span>
                                </div>
                            </div>

                            <div class="p-6 bg-gray-50 grid grid-cols-2 md:grid-cols-4 gap-4">
                                <div>
                                    <p class="text-sm text-gray-600">Abteilung</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['department']); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">Stellenbezeichnung</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['job_title']); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">E-Mail</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['employee_email']); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">Startdatum</p>
                                    <p class="font-semibold text-gray-800"><?php echo $case['start_date'] ? date('d.m.Y', strtotime($case['start_date'])) : '-'; ?></p>
                                </div>
                            </div>

                            <div class="p-6">
                                <form method="POST" class="space-y-4">
                                    <input type="hidden" name="case_id" value="<?php echo $case['id']; ?>">

                                    <div>
                                        <label class="block text-sm font-medium text-gray-700 mb-2">Notizen</label>
                                        <textarea name="notes" rows="3" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="Optionale Notizen..."></textarea>
                                    </div>

                                    <div class="flex gap-4">
                                        <button type="submit" name="action" value="approve" class="flex-1 bg-green-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-green-700 transition-colors">
                                            ✅ Genehmigen
                                        </button>
                                        <button type="submit" name="action" value="reject" class="flex-1 bg-red-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-red-700 transition-colors" onclick="return confirm('Sind Sie sicher?');">
                                            ❌ Ablehnen
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    <?php endforeach; ?>
                <?php endif; ?>
            </div>
        </main>
    </div>
</body>
</html>
