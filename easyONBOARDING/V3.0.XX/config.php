<?php
// Konfigurationsdatei für das Onboarding-System
session_start();

// Datenbankeinstellungen
define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASS', '');
define('DB_NAME', 'onboarding_system');

// Systemeinstellungen
define('SITE_URL', 'http://localhost/easyONBOARDING/V3.0.XX/');
define('SITE_NAME', 'PowerShell Onboarding System');
define('ADMIN_EMAIL', 'admin@company.com');
define('PASSWORD_LENGTH', 12);
define('MAX_LOGIN_ATTEMPTS', 5);
define('LOCKOUT_TIME', 900); // 15 Minuten

// Rollen definieren
define('ROLES', ['HR', 'Abteilungsleiter', 'Chef', 'IT', 'Admin']);
define('WORKFLOW_SEQUENCE', ['HR', 'Abteilungsleiter', 'Chef', 'IT', 'HR']);

// ===== SSO KONFIGURATION (Single Sign-On) =====
// LDAP / Windows AD Einstellungen
define('ENABLE_SSO', true);                          // SSO aktivieren/deaktivieren
define('LDAP_ENABLED', true);                        // LDAP (Windows AD) aktivieren
define('LDAP_HOST', 'ldap://192.168.1.100');        // AD-Server (IP oder Hostname)
define('LDAP_PORT', 389);                            // Standard LDAP Port
define('LDAP_VERSION', 3);                           // LDAP Protocol Version
define('LDAP_BASE_DN', 'dc=company,dc=local');      // Base DN (z.B. DC=company,DC=local)
define('LDAP_USER_OU', 'ou=Users');                  // User OU (z.B. OU=Users)
define('LDAP_DOMAIN', 'COMPANY');                    // Windows Domain Name
define('LDAP_BIND_DN', 'CN=OnboardingService,cn=Users,dc=company,dc=local');  // Service Account DN
define('LDAP_BIND_PASS', 'ServiceAccountPassword');  // Service Account Password
define('LDAP_TIMEOUT', 10);                          // Connection Timeout

// MS365 OAuth2 Einstellungen (optional)
define('ENABLE_MS365_SSO', false);                   // MS365 OAuth2 aktivieren
define('MS365_CLIENT_ID', 'your-client-id');        // Azure App Registration Client ID
define('MS365_CLIENT_SECRET', 'your-client-secret');// Client Secret
define('MS365_TENANT_ID', 'common');                 // Azure Tenant ID (common oder spezifisch)
define('MS365_AUTHORITY', 'https://login.microsoftonline.com/' . MS365_TENANT_ID);
define('MS365_SCOPES', 'https://graph.microsoft.com/.default');

// SSO Allgemeine Einstellungen
define('AUTO_CREATE_SSO_USERS', true);               // Automatisch Benutzer aus AD/MS365 erstellen
define('SSO_AUTO_ROLE', 'HR');                       // Standard-Rolle für neue SSO-Benutzer
define('SSO_AUTO_DEPARTMENT', 'IT');                 // Standard-Abteilung
define('AUTO_SYNC_ATTRIBUTES', true);                // Automatisch Name, Email, etc. aktualisieren
define('SSO_SESSION_TIMEOUT', 3600);                 // Session Timeout (1 Stunde)
define('SSO_REMEMBER_ME_DAYS', 7);                   // Remember-Me Gültigkeitsdauer

// ===== END SSO KONFIGURATION =====

// Datenbank verbinden
$db = null;
try {
    $db = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER,
        DB_PASS,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false
        ]
    );
} catch (PDOException $e) {
    die(json_encode(['error' => 'Datenbankverbindung fehlgeschlagen: ' . $e->getMessage()]));
}

// Hilfsfunktionen
function isLoggedIn() {
    return isset($_SESSION['user_id']) && isset($_SESSION['role']);
}

function redirectIfNotLoggedIn() {
    if (!isLoggedIn()) {
        header('Location: ' . SITE_URL . 'login.php');
        exit();
    }
}

function redirectIfNotAdmin() {
    if (!isLoggedIn() || $_SESSION['role'] !== 'Admin') {
        header('Location: ' . SITE_URL . 'index.php');
        exit();
    }
}

function redirectIfNotRole($role) {
    if (!isLoggedIn() || !in_array($_SESSION['role'], (array)$role)) {
        header('Location: ' . SITE_URL . 'index.php');
        exit();
    }
}

// Passwort & Benutzername Generierung
function generatePassword($length = PASSWORD_LENGTH) {
    $uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    $lowercase = 'abcdefghijklmnopqrstuvwxyz';
    $numbers = '0123456789';
    $special = '!@#$%^&*-_=+';
    
    $password = '';
    $password .= $uppercase[random_int(0, strlen($uppercase) - 1)];
    $password .= $lowercase[random_int(0, strlen($lowercase) - 1)];
    $password .= $numbers[random_int(0, strlen($numbers) - 1)];
    $password .= $special[random_int(0, strlen($special) - 1)];
    
    $allChars = $uppercase . $lowercase . $numbers . $special;
    for ($i = 4; $i < $length; $i++) {
        $password .= $allChars[random_int(0, strlen($allChars) - 1)];
    }
    
    return str_shuffle($password);
}

function generateUsername($firstName, $lastName) {
    $username = strtolower(substr($firstName, 0, 1) . $lastName);
    return preg_replace('/[^a-z0-9]/', '', $username);
}

function generateEmail($firstName, $lastName, $domain = 'company.com') {
    $email = strtolower($firstName . '.' . $lastName . '@' . $domain);
    return preg_replace('/[^a-z0-9@.]/', '', $email);
}

function generateCaseNumber() {
    return 'ONBOARD-' . date('YmdHis') . '-' . strtoupper(bin2hex(random_bytes(3)));
}

// Validierungs-Funktionen
function validateEmail($email) {
    return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
}

function validateUsername($username) {
    return preg_match('/^[a-z0-9]{3,50}$/i', $username);
}

function validatePassword($password) {
    return strlen($password) >= 8 &&
           preg_match('/[A-Z]/', $password) &&
           preg_match('/[a-z]/', $password) &&
           preg_match('/[0-9]/', $password);
}

function sanitize($input) {
    if (is_array($input)) {
        return array_map('sanitize', $input);
    }
    return htmlspecialchars(trim($input), ENT_QUOTES, 'UTF-8');
}

function escape($input) {
    global $db;
    return $db->quote($input);
}

// Logging-Funktionen mit IP-Address
function getClientIP() {
    $ip = '';
    if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
        $ip = $_SERVER['HTTP_CLIENT_IP'];
    } elseif (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ip = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0];
    } else {
        $ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    }
    return filter_var($ip, FILTER_VALIDATE_IP) ? $ip : '0.0.0.0';
}

function logAction($userId, $action, $details = '') {
    global $db;
    try {
        $ip = getClientIP();
        $stmt = $db->prepare('INSERT INTO logs (user_id, action, details, ip_address, created_at) VALUES (?, ?, ?, ?, NOW())');
        $stmt->execute([$userId, $action, $details, $ip]);
    } catch (Exception $e) {
        error_log('Logging error: ' . $e->getMessage());
    }
}

function logApiRequest($endpoint, $method, $statusCode, $request, $response, $caseId = null) {
    global $db;
    try {
        $stmt = $db->prepare('
            INSERT INTO api_logs (endpoint, method, status_code, request_data, response_data, case_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?, NOW())
        ');
        $stmt->execute([
            $endpoint,
            $method,
            $statusCode,
            json_encode($request),
            json_encode($response),
            $caseId
        ]);
    } catch (Exception $e) {
        error_log('API Logging error: ' . $e->getMessage());
    }
}

// JSON-Response Hilfsfunktion
function jsonResponse($data, $statusCode = 200) {
    http_response_code($statusCode);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit();
}

// Fehler-Handler
function handleError($message, $statusCode = 400) {
    jsonResponse(['error' => $message], $statusCode);
}

// Success-Response
function successResponse($data, $message = 'Erfolg') {
    jsonResponse([
        'success' => true,
        'message' => $message,
        'data' => $data
    ], 200);
}

// CSRF-Token Generierung
function generateCSRFToken() {
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function verifyCSRFToken($token) {
    return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
}

?>
