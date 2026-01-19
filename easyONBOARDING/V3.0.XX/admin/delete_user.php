<?php
/**
 * Benutzer löschen/deaktivieren
 * Erlaubt Administratoren, Benutzer zu deaktivieren oder zu löschen
 */

require_once '../config.php';
redirectIfNotAdmin();

$userId = intval($_GET['id'] ?? 0);
$action = sanitize($_GET['action'] ?? 'confirm'); // confirm, deactivate, delete

if (!$userId) {
    header('Location: dashboard.php?tab=users');
    exit();
}

// Benutzer abrufen
$stmt = $db->prepare('SELECT * FROM users WHERE id = ?');
$stmt->execute([$userId]);
$user = $stmt->fetch();

if (!$user) {
    header('Location: dashboard.php?tab=users');
    exit();
}

// Verhindere, dass sich selbst löscht
if ($user['id'] === $_SESSION['user_id']) {
    header('Location: dashboard.php?tab=users&error=cannot_delete_self');
    exit();
}

$message = '';
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = sanitize($_POST['action'] ?? '');
    $confirmation = sanitize($_POST['confirmation'] ?? '');

    if ($action === 'deactivate') {
        try {
            if ($confirmation !== 'deactivate') {
                throw new Exception('Bestätigung erforderlich');
            }

            $stmt = $db->prepare('UPDATE users SET is_active = 0, updated_at = NOW() WHERE id = ?');
            $stmt->execute([$userId]);

            logAction($_SESSION['user_id'], 'deactivate_user', 'Benutzer deaktiviert: ' . $user['username']);
            
            header('Location: dashboard.php?tab=users&message=User deactivated');
            exit();
        } catch (Exception $e) {
            $error = $e->getMessage();
        }
    } elseif ($action === 'delete') {
        try {
            if ($confirmation !== 'permanently_delete') {
                throw new Exception('Bestätigung erforderlich');
            }

            // Backup der Benutzerdaten vor dem Löschen
            $backup_data = json_encode($user);
            $stmt = $db->prepare('INSERT INTO user_deletion_logs (user_id, username, backup_data, deleted_by, deleted_at) VALUES (?, ?, ?, ?, NOW())');
            $stmt->execute([$userId, $user['username'], $backup_data, $_SESSION['user_id']]);

            // Alle Referenzen aktualisieren
            $db->prepare('UPDATE onboarding_cases SET created_by = NULL WHERE created_by = ?')->execute([$userId]);
            $db->prepare('UPDATE onboarding_cases SET manager_id = NULL WHERE manager_id = ?')->execute([$userId]);
            $db->prepare('DELETE FROM logs WHERE user_id = ?')->execute([$userId]);

            // Benutzer löschen
            $stmt = $db->prepare('DELETE FROM users WHERE id = ?');
            $stmt->execute([$userId]);

            logAction($_SESSION['user_id'], 'delete_user', 'Benutzer gelöscht: ' . $user['username']);
            
            header('Location: dashboard.php?tab=users&message=User deleted permanently');
            exit();
        } catch (Exception $e) {
            $error = 'Fehler: ' . $e->getMessage();
        }
    }
}

?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Benutzer löschen - <?php echo SITE_NAME; ?></title>
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
                    <a href="dashboard.php" class="text-gray-600 hover:bg-gray-100 block px-4 py-2 rounded-lg transition-colors">
                        📊 Zurück
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
            <h2 class="text-3xl font-bold text-gray-800 mb-8">⚠️ Benutzer löschen</h2>

            <?php if (!empty($error)): ?>
                <div class="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700 rounded">
                    <?php echo htmlspecialchars($error); ?>
                </div>
            <?php endif; ?>

            <div class="max-w-2xl">
                <!-- Benutzer-Information -->
                <div class="bg-white rounded-lg shadow p-8 mb-8">
                    <h3 class="text-xl font-semibold text-gray-800 mb-6">Benutzer-Information</h3>
                    <table class="w-full">
                        <tr class="border-b">
                            <td class="py-3 font-medium text-gray-700">Name:</td>
                            <td class="py-3 text-gray-800"><?php echo htmlspecialchars($user['first_name'] . ' ' . $user['last_name']); ?></td>
                        </tr>
                        <tr class="border-b">
                            <td class="py-3 font-medium text-gray-700">Benutzername:</td>
                            <td class="py-3 text-gray-800"><?php echo htmlspecialchars($user['username']); ?></td>
                        </tr>
                        <tr class="border-b">
                            <td class="py-3 font-medium text-gray-700">Email:</td>
                            <td class="py-3 text-gray-800"><?php echo htmlspecialchars($user['email']); ?></td>
                        </tr>
                        <tr class="border-b">
                            <td class="py-3 font-medium text-gray-700">Rolle:</td>
                            <td class="py-3 text-gray-800"><?php echo htmlspecialchars($user['role']); ?></td>
                        </tr>
                        <tr>
                            <td class="py-3 font-medium text-gray-700">Status:</td>
                            <td class="py-3">
                                <span class="<?php echo $user['is_active'] ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'; ?> px-3 py-1 rounded-full text-sm font-semibold">
                                    <?php echo $user['is_active'] ? 'Aktiv' : 'Inaktiv'; ?>
                                </span>
                            </td>
                        </tr>
                    </table>
                </div>

                <!-- Optionen -->
                <div class="space-y-6">
                    <!-- Option 1: Deaktivieren -->
                    <div class="bg-yellow-50 border-2 border-yellow-200 rounded-lg p-8">
                        <div class="flex items-start gap-4">
                            <div class="text-2xl">🔒</div>
                            <div class="flex-1">
                                <h4 class="text-lg font-semibold text-gray-800 mb-2">Benutzer deaktivieren</h4>
                                <p class="text-gray-700 mb-4">
                                    Der Benutzer kann sich nicht mehr anmelden, alle Daten bleiben aber erhalten. Dies kann rückgängig gemacht werden.
                                </p>
                                <form method="POST" class="space-y-4">
                                    <div>
                                        <label class="block text-sm font-medium text-gray-700 mb-2">
                                            Bestätigung eingeben: <code class="bg-yellow-100 px-2 py-1 rounded">deactivate</code>
                                        </label>
                                        <input type="text" name="confirmation" placeholder="deactivate eingeben" 
                                               class="w-full px-4 py-2 border border-yellow-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-yellow-500">
                                    </div>
                                    <input type="hidden" name="action" value="deactivate">
                                    <button type="submit" class="bg-yellow-600 text-white font-semibold py-2 px-6 rounded-lg hover:bg-yellow-700 transition-colors">
                                        🔒 Benutzer deaktivieren
                                    </button>
                                </form>
                            </div>
                        </div>
                    </div>

                    <!-- Option 2: Löschen -->
                    <div class="bg-red-50 border-2 border-red-300 rounded-lg p-8">
                        <div class="flex items-start gap-4">
                            <div class="text-2xl">🗑️</div>
                            <div class="flex-1">
                                <h4 class="text-lg font-semibold text-red-800 mb-2">⚠️ Benutzer permanent löschen</h4>
                                <p class="text-red-700 mb-4">
                                    <strong>WARNUNG:</strong> Dies löscht den Benutzer dauerhaft. Die Aktion kann nicht rückgängig gemacht werden, obwohl Backups gespeichert werden.
                                </p>
                                <ul class="list-disc list-inside text-red-700 mb-4 text-sm">
                                    <li>Alle Benutzer-Daten werden gelöscht</li>
                                    <li>Referenzen in Cases werden aufgeräumt</li>
                                    <li>Audit-Logs werden entfernt</li>
                                    <li>Ein Backup wird gespeichert für gesetzliche Anforderungen</li>
                                </ul>
                                <form method="POST" class="space-y-4">
                                    <div>
                                        <label class="block text-sm font-medium text-red-700 mb-2">
                                            Bestätigung eingeben: <code class="bg-red-100 px-2 py-1 rounded">permanently_delete</code>
                                        </label>
                                        <input type="text" name="confirmation" placeholder="permanently_delete eingeben" 
                                               class="w-full px-4 py-2 border border-red-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-red-500">
                                    </div>
                                    <input type="hidden" name="action" value="delete">
                                    <button type="submit" onclick="return confirm('Dies löscht den Benutzer dauerhaft! Sicher?')" 
                                            class="bg-red-600 text-white font-semibold py-2 px-6 rounded-lg hover:bg-red-700 transition-colors">
                                        🗑️ Permanent löschen
                                    </button>
                                </form>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Zurück-Button -->
                <div class="mt-8">
                    <a href="dashboard.php?tab=users" class="inline-flex items-center gap-2 text-blue-600 hover:text-blue-800 font-semibold">
                        ← Zurück zur Benutzer-Liste
                    </a>
                </div>
            </div>
        </main>
    </div>
</body>
</html>
