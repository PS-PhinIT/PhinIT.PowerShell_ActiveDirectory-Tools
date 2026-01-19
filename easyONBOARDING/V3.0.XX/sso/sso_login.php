<?php
/**
 * SSO Login Page
 * Unterstützt LDAP (Windows AD) und MS365 OAuth2
 */

session_start();
require_once '../config.php';

// Wenn bereits angemeldet, weiterleiten
if (isset($_SESSION['user_id'])) {
    header('Location: ../index.php');
    exit();
}

$error = '';
$success = '';
$ssoMethod = sanitize($_GET['method'] ?? 'ldap'); // ldap oder ms365

// LDAP Login-Verarbeitung
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['ldap_login'])) {
    if (!LDAP_ENABLED) {
        $error = 'LDAP ist nicht aktiviert';
    } else {
        require_once 'ldap_auth.php';
        
        $username = sanitize($_POST['username'] ?? '');
        $password = $_POST['password'] ?? '';
        
        if (empty($username) || empty($password)) {
            $error = 'Benutzername und Passwort erforderlich';
        } else {
            try {
                $ldap = new LDAPAuth();
                
                // Authentifizierung gegen AD
                $userData = $ldap->authenticate($username, $password);
                
                if ($userData) {
                    // Benutzer synchronisieren/erstellen
                    $syncResult = $ldap->syncUser($db, $userData);
                    
                    if ($syncResult['success']) {
                        // Benutzer in DB abrufen
                        $stmt = $db->prepare('SELECT * FROM users WHERE username = ? AND sso_provider = "ldap"');
                        $stmt->execute([$userData['username']]);
                        $user = $stmt->fetch();
                        
                        if ($user) {
                            // Session setzen
                            $_SESSION['user_id'] = $user['id'];
                            $_SESSION['username'] = $user['username'];
                            $_SESSION['first_name'] = $user['first_name'];
                            $_SESSION['last_name'] = $user['last_name'];
                            $_SESSION['role'] = $user['role'];
                            $_SESSION['sso_method'] = 'ldap';
                            $_SESSION['sso_id'] = $user['sso_id'];
                            
                            // Remember-Me Cookie (optional)
                            if (isset($_POST['remember'])) {
                                setcookie('sso_username', $username, time() + (SSO_REMEMBER_ME_DAYS * 86400), '/');
                            }
                            
                            logAction($user['id'], 'sso_ldap_login', 'SSO LDAP Login erfolgreich');
                            
                            // Weiterleitung
                            $redirect = isset($_GET['redirect']) ? sanitize($_GET['redirect']) : '../index.php';
                            header('Location: ' . $redirect);
                            exit();
                        } else {
                            $error = 'Benutzer konnte nicht erstellt werden';
                        }
                    } else {
                        $error = $syncResult['message'] ?? 'Synchronisation fehlgeschlagen';
                    }
                } else {
                    $error = 'Authentifizierung fehlgeschlagen';
                    $ldapErrors = $ldap->getErrors();
                    if (!empty($ldapErrors)) {
                        error_log('LDAP Errors: ' . implode(', ', $ldapErrors));
                    }
                }
                
                $ldap->close();
                
            } catch (Exception $e) {
                $error = 'Fehler: ' . $e->getMessage();
                error_log('SSO Login Error: ' . $e->getMessage());
            }
        }
    }
}

// MS365 OAuth Login-Button
if (isset($_GET['action']) && $_GET['action'] === 'ms365_login' && ENABLE_MS365_SSO) {
    // Redirect zu MS365 Login
    $authUrl = MS365_AUTHORITY . '/oauth2/v2.0/authorize?' . http_build_query([
        'client_id' => MS365_CLIENT_ID,
        'response_type' => 'code',
        'scope' => MS365_SCOPES,
        'redirect_uri' => SITE_URL . 'sso/ms365_callback.php',
        'state' => bin2hex(random_bytes(16)),
        'prompt' => 'login'
    ]);
    
    $_SESSION['oauth_state'] = $_GET['state'] ?? '';
    header('Location: ' . $authUrl);
    exit();
}

?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SSO Login - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
</head>
<body class="bg-gradient-to-br from-blue-50 to-indigo-100 min-h-screen flex items-center justify-center font-sans">
    <div class="w-full max-w-md">
        <!-- Header -->
        <div class="text-center mb-8">
            <div class="inline-block bg-gradient-to-br from-blue-600 to-indigo-600 text-white rounded-lg p-3 mb-4">
                <svg class="h-8 w-8" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                </svg>
            </div>
            <h1 class="text-3xl font-bold text-gray-800"><?php echo SITE_NAME; ?></h1>
            <p class="text-gray-600 mt-2">Single Sign-On</p>
        </div>

        <!-- Main Card -->
        <div class="bg-white rounded-lg shadow-xl overflow-hidden">
            <!-- Tabs -->
            <div class="flex border-b border-gray-200">
                <button onclick="switchTab('ldap')" class="flex-1 py-4 px-6 text-center font-semibold border-b-2 <?php echo $ssoMethod === 'ldap' ? 'border-blue-600 text-blue-600' : 'border-gray-200 text-gray-600'; ?> transition-colors">
                    🏢 AD / LDAP
                </button>
                <?php if (ENABLE_MS365_SSO): ?>
                    <button onclick="switchTab('ms365')" class="flex-1 py-4 px-6 text-center font-semibold border-b-2 <?php echo $ssoMethod === 'ms365' ? 'border-blue-600 text-blue-600' : 'border-gray-200 text-gray-600'; ?> transition-colors">
                        ☁️ MS365
                    </button>
                <?php endif; ?>
            </div>

            <!-- Content -->
            <div class="p-8">
                <!-- Error Message -->
                <?php if ($error): ?>
                    <div class="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700 rounded">
                        <p class="font-semibold">❌ Fehler</p>
                        <p class="text-sm"><?php echo htmlspecialchars($error); ?></p>
                    </div>
                <?php endif; ?>

                <!-- LDAP Login -->
                <div id="ldap-tab" class="<?php echo $ssoMethod !== 'ldap' ? 'hidden' : ''; ?>">
                    <form method="POST" class="space-y-6">
                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">
                                Benutzername oder Email
                            </label>
                            <input type="text" name="username" placeholder="z.B. max.mueller oder max.mueller@company.de" 
                                   class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                                   <?php echo isset($_POST['ldap_login']) && !empty($_POST['username']) ? 'value="' . htmlspecialchars($_POST['username']) . '"' : ''; ?>
                                   required>
                        </div>

                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">
                                Passwort
                            </label>
                            <input type="password" name="password" placeholder="Ihr Windows/AD Passwort"
                                   class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                                   required>
                        </div>

                        <label class="flex items-center text-sm">
                            <input type="checkbox" name="remember" class="w-4 h-4 text-blue-600 rounded focus:ring-2 focus:ring-blue-500">
                            <span class="ml-2 text-gray-700">Auf diesem Gerät angemeldet bleiben</span>
                        </label>

                        <button type="submit" name="ldap_login" class="w-full bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-semibold py-3 px-4 rounded-lg hover:shadow-lg transition-shadow">
                            🏢 Mit Active Directory anmelden
                        </button>
                    </form>

                    <div class="mt-6 pt-6 border-t border-gray-200 text-sm text-gray-600 text-center">
                        <p>Verwenden Sie Ihre Windows/AD-Anmeldedaten</p>
                    </div>
                </div>

                <!-- MS365 Login -->
                <?php if (ENABLE_MS365_SSO): ?>
                    <div id="ms365-tab" class="<?php echo $ssoMethod !== 'ms365' ? 'hidden' : ''; ?>">
                        <div class="space-y-4">
                            <p class="text-gray-600 text-sm">
                                Melden Sie sich mit Ihrem Microsoft 365-Konto an.
                            </p>

                            <a href="?action=ms365_login" class="w-full bg-gradient-to-r from-blue-500 to-blue-600 text-white font-semibold py-3 px-4 rounded-lg hover:shadow-lg transition-shadow flex items-center justify-center gap-2">
                                ☁️ Mit Microsoft 365 anmelden
                            </a>
                        </div>

                        <div class="mt-6 pt-6 border-t border-gray-200 text-sm text-gray-600 text-center">
                            <p>Sie werden zu Microsoft weitergeleitet</p>
                        </div>
                    </div>
                <?php endif; ?>
            </div>
        </div>

        <!-- Footer Links -->
        <div class="mt-6 text-center text-sm text-gray-600">
            <p>Zurück zum <a href="../login.php" class="text-blue-600 hover:underline font-semibold">normalen Login</a></p>
        </div>
    </div>

    <script>
        function switchTab(tab) {
            // Alle Tabs verstecken
            document.getElementById('ldap-tab').classList.add('hidden');
            <?php if (ENABLE_MS365_SSO): ?>
                document.getElementById('ms365-tab').classList.add('hidden');
            <?php endif; ?>

            // Gewählten Tab anzeigen
            document.getElementById(tab + '-tab').classList.remove('hidden');

            // URL aktualisieren
            window.history.pushState({}, '', '?method=' + tab);
        }
    </script>
</body>
</html>
