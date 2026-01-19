<?php
require_once 'config.php';

if (isLoggedIn()) {
    header('Location: ' . SITE_URL . 'index.php');
    exit();
}

$error = '';
$success = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = sanitize($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';

    if (empty($username) || empty($password)) {
        $error = 'Benutzername und Passwort sind erforderlich.';
    } else {
        try {
            $stmt = $db->prepare('SELECT id, username, password_hash, role, first_name, last_name FROM users WHERE username = ? AND is_active = TRUE');
            $stmt->execute([$username]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($user && password_verify($password, $user['password_hash'])) {
                $_SESSION['user_id'] = $user['id'];
                $_SESSION['username'] = $user['username'];
                $_SESSION['role'] = $user['role'];
                $_SESSION['first_name'] = $user['first_name'];
                $_SESSION['last_name'] = $user['last_name'];

                logAction($user['id'], 'login', 'Benutzer angemeldet');
                header('Location: ' . SITE_URL . 'index.php');
                exit();
            } else {
                $error = 'Ungültige Anmeldedaten.';
            }
        } catch (Exception $e) {
            $error = 'Ein Fehler ist aufgetreten: ' . $e->getMessage();
        }
    }
}
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Anmeldung - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
</head>
<body class="bg-gradient-to-br from-blue-50 to-indigo-100 min-h-screen flex items-center justify-center font-sans">
    <div class="w-full max-w-md">
        <div class="bg-white rounded-lg shadow-2xl p-8">
            <div class="flex justify-center mb-8">
                <div class="bg-blue-100 p-3 rounded-full">
                    <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" stroke-linecap="round" stroke-linejoin="round"></path>
                    </svg>
                </div>
            </div>

            <h1 class="text-3xl font-bold text-center text-gray-800 mb-2"><?php echo SITE_NAME; ?></h1>
            <p class="text-center text-gray-600 mb-8">Bitte melden Sie sich an</p>

            <?php if (!empty($error)): ?>
                <div class="mb-4 p-4 bg-red-50 border-l-4 border-red-500 text-red-700">
                    <?php echo htmlspecialchars($error); ?>
                </div>
            <?php endif; ?>

            <?php if (!empty($success)): ?>
                <div class="mb-4 p-4 bg-green-50 border-l-4 border-green-500 text-green-700">
                    <?php echo htmlspecialchars($success); ?>
                </div>
            <?php endif; ?>

            <form method="POST" class="space-y-4">
                <div>
                    <label for="username" class="block text-sm font-medium text-gray-700 mb-2">Benutzername</label>
                    <input type="text" id="username" name="username" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="Benutzername">
                </div>

                <div>
                    <label for="password" class="block text-sm font-medium text-gray-700 mb-2">Passwort</label>
                    <input type="password" id="password" name="password" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="Passwort">
                </div>

                <button type="submit" class="w-full bg-blue-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors duration-200">
                    Anmelden
                </button>
            </form>

            <div class="mt-6 p-4 bg-blue-50 rounded-lg text-sm text-gray-700">
                <p class="font-semibold mb-2">Demo-Anmeldedaten:</p>
                <p><strong>HR:</strong> hr / password123</p>
                <p><strong>Admin:</strong> admin / admin123</p>
            </div>
        </div>
    </div>
</body>
</html>
