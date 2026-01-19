<?php
/**
 * MS365 OAuth2 Callback Handler
 * Verarbeitet die Rückleitung von Microsoft nach erfolgreicher Authentifizierung
 */

session_start();
require_once '../config.php';

class MS365Auth {
    private $clientId;
    private $clientSecret;
    private $authority;
    private $scopes;
    private $errors = [];

    public function __construct() {
        $this->clientId = MS365_CLIENT_ID;
        $this->clientSecret = MS365_CLIENT_SECRET;
        $this->authority = MS365_AUTHORITY;
        $this->scopes = MS365_SCOPES;
    }

    /**
     * Access Token von Authorization Code abrufen
     */
    public function getAccessToken($code, $redirectUri) {
        try {
            $tokenEndpoint = $this->authority . '/oauth2/v2.0/token';
            
            $params = [
                'client_id' => $this->clientId,
                'client_secret' => $this->clientSecret,
                'code' => $code,
                'redirect_uri' => $redirectUri,
                'grant_type' => 'authorization_code',
                'scope' => $this->scopes
            ];

            // cURL Request
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $tokenEndpoint);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($params));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 30);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            curl_close($ch);

            if ($curlError) {
                throw new Exception('cURL Error: ' . $curlError);
            }

            $tokenData = json_decode($response, true);

            if ($httpCode !== 200 || isset($tokenData['error'])) {
                throw new Exception('Token Error: ' . ($tokenData['error_description'] ?? 'Unknown error'));
            }

            return $tokenData['access_token'] ?? null;

        } catch (Exception $e) {
            $this->errors[] = $e->getMessage();
            return false;
        }
    }

    /**
     * Benutzer-Daten von Microsoft Graph abrufen
     */
    public function getUserData($accessToken) {
        try {
            $graphEndpoint = 'https://graph.microsoft.com/v1.0/me';

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $graphEndpoint);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json'
            ]);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 30);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($httpCode !== 200) {
                throw new Exception('Graph API Error: HTTP ' . $httpCode);
            }

            $userData = json_decode($response, true);

            if (isset($userData['error'])) {
                throw new Exception('Graph Error: ' . $userData['error']['message']);
            }

            return [
                'id' => $userData['id'] ?? '',
                'username' => $userData['userPrincipalName'] ?? '',
                'email' => $userData['mail'] ?? $userData['userPrincipalName'] ?? '',
                'first_name' => $userData['givenName'] ?? '',
                'last_name' => $userData['surname'] ?? '',
                'department' => $userData['department'] ?? 'IT',
                'job_title' => $userData['jobTitle'] ?? '',
                'office_location' => $userData['officeLocation'] ?? ''
            ];

        } catch (Exception $e) {
            $this->errors[] = $e->getMessage();
            return false;
        }
    }

    /**
     * Benutzer in DB synchronisieren/erstellen
     */
    public function syncUser($db, $userData) {
        try {
            if (AUTO_CREATE_SSO_USERS) {
                // Rolle basierend auf Email bestimmen (vereinfacht)
                $role = SSO_AUTO_ROLE;
                if (stripos($userData['email'], 'admin') !== false) {
                    $role = 'Admin';
                } elseif (stripos($userData['email'], 'hr') !== false) {
                    $role = 'HR';
                } elseif (stripos($userData['email'], 'it') !== false) {
                    $role = 'IT';
                }

                // Username von Email ableiten
                $username = explode('@', $userData['email'])[0] ?? $userData['username'];

                $stmt = $db->prepare('
                    INSERT INTO users (username, email, first_name, last_name, department, role, is_active, sso_id, sso_provider)
                    VALUES (?, ?, ?, ?, ?, ?, 1, ?, "ms365")
                    ON DUPLICATE KEY UPDATE 
                    email = VALUES(email),
                    first_name = VALUES(first_name),
                    last_name = VALUES(last_name),
                    department = VALUES(department),
                    role = VALUES(role),
                    sso_provider = "ms365",
                    updated_at = NOW()
                ');

                $stmt->execute([
                    $username,
                    $userData['email'],
                    $userData['first_name'],
                    $userData['last_name'],
                    $userData['department'],
                    $role,
                    $userData['id']
                ]);

                return ['success' => true, 'user' => $userData];
            }

            return ['success' => false, 'message' => 'Auto-Create deaktiviert'];

        } catch (Exception $e) {
            return ['success' => false, 'message' => $e->getMessage()];
        }
    }

    public function getErrors() {
        return $this->errors;
    }
}

// ===== CALLBACK VERARBEITUNG =====

$error = '';
$success = false;

try {
    // Validierung der Parameter
    $code = $_GET['code'] ?? null;
    $state = $_GET['state'] ?? null;
    $error_param = $_GET['error'] ?? null;

    if ($error_param) {
        throw new Exception('Microsoft Error: ' . htmlspecialchars($error_param));
    }

    if (!$code) {
        throw new Exception('Authorization Code fehlt');
    }

    // MS365Auth Instanz erstellen
    $ms365 = new MS365Auth();

    // Access Token abrufen
    $accessToken = $ms365->getAccessToken($code, SITE_URL . 'sso/ms365_callback.php');

    if (!$accessToken) {
        throw new Exception('Token Abruf fehlgeschlagen: ' . implode(', ', $ms365->getErrors()));
    }

    // Benutzer-Daten abrufen
    $userData = $ms365->getUserData($accessToken);

    if (!$userData) {
        throw new Exception('Benutzer-Daten konnten nicht abgerufen werden: ' . implode(', ', $ms365->getErrors()));
    }

    // Benutzer synchronisieren/erstellen
    $syncResult = $ms365->syncUser($db, $userData);

    if ($syncResult['success']) {
        // Benutzer in DB abrufen
        $stmt = $db->prepare('SELECT * FROM users WHERE sso_id = ? AND sso_provider = "ms365"');
        $stmt->execute([$userData['id']]);
        $user = $stmt->fetch();

        if ($user) {
            // Session setzen
            $_SESSION['user_id'] = $user['id'];
            $_SESSION['username'] = $user['username'];
            $_SESSION['first_name'] = $user['first_name'];
            $_SESSION['last_name'] = $user['last_name'];
            $_SESSION['role'] = $user['role'];
            $_SESSION['sso_method'] = 'ms365';
            $_SESSION['sso_id'] = $user['sso_id'];
            $_SESSION['access_token'] = $accessToken;

            logAction($user['id'], 'sso_ms365_login', 'SSO MS365 Login erfolgreich');

            $success = true;

            // Weiterleitung nach 2 Sekunden
            header('Refresh: 2; url=' . SITE_URL . 'index.php');
        } else {
            throw new Exception('Benutzer konnte nicht geladen werden');
        }
    } else {
        throw new Exception($syncResult['message'] ?? 'Synchronisation fehlgeschlagen');
    }

} catch (Exception $e) {
    $error = $e->getMessage();
    error_log('MS365 Callback Error: ' . $e->getMessage());
}

?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SSO Callback - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gradient-to-br from-blue-50 to-indigo-100 min-h-screen flex items-center justify-center">
    <div class="text-center">
        <?php if ($success): ?>
            <div class="bg-white rounded-lg shadow-xl p-8 max-w-md">
                <div class="text-4xl mb-4">✅</div>
                <h1 class="text-2xl font-bold text-gray-800 mb-2">Erfolgreich angemeldet!</h1>
                <p class="text-gray-600 mb-4">Sie werden in Kürze weitergeleitet...</p>
                <div class="inline-block">
                    <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                </div>
            </div>
        <?php else: ?>
            <div class="bg-white rounded-lg shadow-xl p-8 max-w-md">
                <div class="text-4xl mb-4">❌</div>
                <h1 class="text-2xl font-bold text-red-600 mb-2">Fehler</h1>
                <p class="text-gray-600 mb-6"><?php echo htmlspecialchars($error); ?></p>
                <a href="sso_login.php?method=ms365" class="inline-block bg-blue-600 text-white font-semibold py-2 px-6 rounded-lg hover:bg-blue-700">
                    Erneut versuchen
                </a>
            </div>
        <?php endif; ?>
    </div>
</body>
</html>
