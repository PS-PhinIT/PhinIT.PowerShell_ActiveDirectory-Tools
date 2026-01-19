<?php
require_once '../config.php';
redirectIfNotAdmin();

$userId = intval($_GET['id'] ?? 0);
$message = '';
$error = '';

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

// Formular verarbeiten
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $first_name = sanitize($_POST['first_name'] ?? '');
    $last_name = sanitize($_POST['last_name'] ?? '');
    $email = sanitize($_POST['email'] ?? '');
    $role = sanitize($_POST['role'] ?? '');
    $department = sanitize($_POST['department'] ?? '');
    $is_active = isset($_POST['is_active']) ? 1 : 0;
    $change_password = isset($_POST['change_password']);
    $password = $_POST['password'] ?? '';

    // Validierung
    $errors = [];
    if (empty($first_name) || empty($last_name)) {
        $errors[] = 'Vor- und Nachname sind erforderlich.';
    }
    if (!validateEmail($email)) {
        $errors[] = 'Ungültige E-Mail-Adresse.';
    }
    if (!in_array($role, ROLES)) {
        $errors[] = 'Ungültige Rolle.';
    }
    if ($change_password && !empty($password) && !validatePassword($password)) {
        $errors[] = 'Passwort muss mindestens 8 Zeichen lang sein und Großbuchstaben, Kleinbuchstaben und Zahlen enthalten.';
    }

    if (empty($errors)) {
        try {
            if ($change_password && !empty($password)) {
                $passwordHash = password_hash($password, PASSWORD_DEFAULT);
                $stmt = $db->prepare('
                    UPDATE users 
                    SET first_name = ?, last_name = ?, email = ?, role = ?, department = ?, is_active = ?, password_hash = ?, updated_at = NOW()
                    WHERE id = ?
                ');
                $stmt->execute([$first_name, $last_name, $email, $role, $department, $is_active, $passwordHash, $userId]);
            } else {
                $stmt = $db->prepare('
                    UPDATE users 
                    SET first_name = ?, last_name = ?, email = ?, role = ?, department = ?, is_active = ?, updated_at = NOW()
                    WHERE id = ?
                ');
                $stmt->execute([$first_name, $last_name, $email, $role, $department, $is_active, $userId]);
            }

            logAction($_SESSION['user_id'], 'edit_user', 'Benutzer bearbeitet: ' . $user['username']);
            $message = 'Benutzer erfolgreich aktualisiert!';

            // Frische Daten abrufen
            $stmt = $db->prepare('SELECT * FROM users WHERE id = ?');
            $stmt->execute([$userId]);
            $user = $stmt->fetch();
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), 'Duplicate entry') !== false) {
                $error = 'Diese E-Mail-Adresse existiert bereits.';
            } else {
                $error = 'Datenbankfehler: ' . $e->getMessage();
            }
        }
    } else {
        $error = implode('<br>', $errors);
    }
}

// Abteilungen abrufen
$stmt = $db->query('SELECT DISTINCT department FROM users WHERE department IS NOT NULL ORDER BY department');
$departments = $stmt->fetchAll(PDO::FETCH_COLUMN);
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Benutzer bearbeiten - <?php echo SITE_NAME; ?></title>
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
            <h2 class="text-3xl font-bold text-gray-800 mb-8">Benutzer bearbeiten</h2>

            <?php if (!empty($error)): ?>
                <div class="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700 rounded">
                    <?php echo $error; ?>
                </div>
            <?php endif; ?>

            <?php if (!empty($message)): ?>
                <div class="mb-6 p-4 bg-green-50 border-l-4 border-green-500 text-green-700 rounded">
                    <?php echo htmlspecialchars($message); ?>
                </div>
            <?php endif; ?>

            <div class="max-w-2xl bg-white rounded-lg shadow p-8">
                <form method="POST" class="space-y-6">
                    <div class="bg-blue-50 p-4 rounded-lg mb-6">
                        <p class="text-sm text-blue-800"><strong>Benutzername:</strong> <?php echo htmlspecialchars($user['username']); ?></p>
                        <p class="text-sm text-blue-800 mt-1"><strong>Erstellt:</strong> <?php echo date('d.m.Y H:i', strtotime($user['created_at'])); ?></p>
                    </div>

                    <div class="grid grid-cols-2 gap-6">
                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">Vorname *</label>
                            <input type="text" name="first_name" value="<?php echo htmlspecialchars($user['first_name']); ?>"
                                   class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" required>
                        </div>

                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">Nachname *</label>
                            <input type="text" name="last_name" value="<?php echo htmlspecialchars($user['last_name']); ?>"
                                   class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" required>
                        </div>
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">E-Mail *</label>
                        <input type="email" name="email" value="<?php echo htmlspecialchars($user['email']); ?>"
                               class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" required>
                    </div>

                    <div class="grid grid-cols-2 gap-6">
                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">Rolle *</label>
                            <select name="role" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" required>
                                <?php foreach (ROLES as $r): ?>
                                    <option value="<?php echo $r; ?>" <?php echo $user['role'] === $r ? 'selected' : ''; ?>>
                                        <?php echo $r; ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>

                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">Abteilung</label>
                            <select name="department" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                                <option value="">-- Abteilung wählen --</option>
                                <?php foreach ($departments as $dept): ?>
                                    <option value="<?php echo htmlspecialchars($dept); ?>" <?php echo $user['department'] === $dept ? 'selected' : ''; ?>>
                                        <?php echo htmlspecialchars($dept); ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>

                    <div>
                        <label class="flex items-center">
                            <input type="checkbox" name="is_active" <?php echo $user['is_active'] ? 'checked' : ''; ?>
                                   class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500">
                            <span class="ml-2 text-sm font-medium text-gray-700">Benutzer aktiv</span>
                        </label>
                    </div>

                    <hr class="my-6">

                    <div>
                        <label class="flex items-center">
                            <input type="checkbox" id="change_password" name="change_password"
                                   class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                                   onchange="document.getElementById('password_section').style.display = this.checked ? 'block' : 'none'">
                            <span class="ml-2 text-sm font-medium text-gray-700">Passwort ändern</span>
                        </label>
                    </div>

                    <div id="password_section" style="display: none;">
                        <label class="block text-sm font-medium text-gray-700 mb-2">Neues Passwort</label>
                        <input type="password" name="password" id="password"
                               class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                        <p class="text-sm text-gray-500 mt-1">Min. 8 Zeichen: Großbuchstaben, Kleinbuchstaben, Zahlen erforderlich</p>
                        <div class="mt-3 p-3 bg-blue-50 rounded-lg text-sm">
                            <button type="button" onclick="generatePassword()" class="text-blue-600 hover:text-blue-800 font-semibold">
                                🔄 Passwort generieren
                            </button>
                        </div>
                    </div>

                    <div class="flex gap-4 pt-6 border-t">
                        <button type="submit" class="flex-1 bg-blue-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors">
                            ✓ Änderungen speichern
                        </button>
                        <a href="dashboard.php?tab=users" class="flex-1 bg-gray-200 text-gray-800 font-semibold py-2 px-4 rounded-lg text-center hover:bg-gray-300 transition-colors">
                            ✕ Abbrechen
                        </a>
                    </div>
                </form>
            </div>
        </main>
    </div>

    <script>
        function generatePassword() {
            const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
            const lowercase = 'abcdefghijklmnopqrstuvwxyz';
            const numbers = '0123456789';
            const special = '!@#$%^&*-_=+';
            
            let password = '';
            password += uppercase.charAt(Math.floor(Math.random() * uppercase.length));
            password += lowercase.charAt(Math.floor(Math.random() * lowercase.length));
            password += numbers.charAt(Math.floor(Math.random() * numbers.length));
            password += special.charAt(Math.floor(Math.random() * special.length));
            
            const allChars = uppercase + lowercase + numbers + special;
            for (let i = 4; i < 12; i++) {
                password += allChars.charAt(Math.floor(Math.random() * allChars.length));
            }
            
            password = password.split('').sort(() => Math.random() - 0.5).join('');
            document.getElementById('password').value = password;
        }
    </script>
</body>
</html>
