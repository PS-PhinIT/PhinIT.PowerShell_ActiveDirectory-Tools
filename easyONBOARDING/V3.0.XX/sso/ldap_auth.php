<?php
/**
 * LDAP Authentication Handler
 * Verbindung zu Windows Active Directory / LDAP
 * 
 * Unterstützt:
 * - Benutzer-Authentifizierung gegen AD
 * - Benutzer-Attribut Synchronisation
 * - Automatische Benutzer-Erstellung
 * - Gruppen-Mapping
 */

require_once '../config.php';

class LDAPAuth {
    private $ldapConnection = null;
    private $host;
    private $port;
    private $baseDn;
    private $domain;
    private $bindDn;
    private $bindPass;
    private $timeout;
    private $errors = [];

    public function __construct() {
        $this->host = LDAP_HOST;
        $this->port = LDAP_PORT;
        $this->baseDn = LDAP_BASE_DN;
        $this->domain = LDAP_DOMAIN;
        $this->bindDn = LDAP_BIND_DN;
        $this->bindPass = LDAP_BIND_PASS;
        $this->timeout = LDAP_TIMEOUT;
    }

    /**
     * Mit LDAP-Server verbinden
     */
    public function connect() {
        try {
            // Verbindung herstellen
            $this->ldapConnection = ldap_connect($this->host, $this->port);
            
            if (!$this->ldapConnection) {
                throw new Exception('LDAP-Verbindung fehlgeschlagen: ' . ldap_error($this->ldapConnection));
            }

            // LDAP-Optionen setzen
            ldap_set_option($this->ldapConnection, LDAP_OPT_PROTOCOL_VERSION, LDAP_VERSION);
            ldap_set_option($this->ldapConnection, LDAP_OPT_NETWORK_TIMEOUT, $this->timeout);
            ldap_set_option($this->ldapConnection, LDAP_OPT_REFERRALS, 0);

            return true;
        } catch (Exception $e) {
            $this->errors[] = $e->getMessage();
            return false;
        }
    }

    /**
     * Mit Service-Account an LDAP binden
     */
    public function bind() {
        if (!$this->ldapConnection) {
            $this->connect();
        }

        try {
            $bind = @ldap_bind($this->ldapConnection, $this->bindDn, $this->bindPass);
            
            if (!$bind) {
                throw new Exception('Service-Account Binding fehlgeschlagen: ' . ldap_error($this->ldapConnection));
            }

            return true;
        } catch (Exception $e) {
            $this->errors[] = $e->getMessage();
            return false;
        }
    }

    /**
     * Benutzer authentifizieren
     * @param string $username Benutzername oder Email
     * @param string $password Passwort
     * @return array|false Benutzer-Daten oder false
     */
    public function authenticate($username, $password) {
        if (!$username || !$password) {
            $this->errors[] = 'Benutzername und Passwort erforderlich';
            return false;
        }

        try {
            if (!$this->bind()) {
                return false;
            }

            // Benutzer im AD suchen
            $searchFilter = "(|(sAMAccountName=$username)(mail=$username))";
            $searchResult = @ldap_search($this->ldapConnection, $this->baseDn, $searchFilter);

            if (!$searchResult) {
                throw new Exception('LDAP-Suche fehlgeschlagen: ' . ldap_error($this->ldapConnection));
            }

            $entries = ldap_get_entries($this->ldapConnection, $searchResult);

            if ($entries['count'] !== 1) {
                throw new Exception('Benutzer nicht gefunden oder Duplikate');
            }

            $userDn = $entries[0]['dn'];
            
            // Mit Benutzer-Credentials testen
            $userBind = @ldap_bind($this->ldapConnection, $userDn, $password);

            if (!$userBind) {
                throw new Exception('Authentifizierung fehlgeschlagen: Falsches Passwort');
            }

            // Benutzer-Daten auslesen
            $userData = $this->extractUserData($entries[0]);
            
            return $userData;

        } catch (Exception $e) {
            $this->errors[] = $e->getMessage();
            return false;
        }
    }

    /**
     * Benutzer-Daten aus LDAP-Entry extrahieren
     */
    private function extractUserData($ldapEntry) {
        $userData = [
            'username' => $ldapEntry['samaccountname'][0] ?? '',
            'first_name' => $ldapEntry['givenname'][0] ?? '',
            'last_name' => $ldapEntry['sn'][0] ?? '',
            'email' => $ldapEntry['mail'][0] ?? '',
            'phone' => $ldapEntry['telephonenumber'][0] ?? '',
            'department' => $ldapEntry['department'][0] ?? 'IT',
            'title' => $ldapEntry['title'][0] ?? '',
            'office' => $ldapEntry['physicaldeliveryofficename'][0] ?? '',
            'dn' => $ldapEntry['dn'],
            'groups' => $this->extractGroups($ldapEntry)
        ];

        return $userData;
    }

    /**
     * AD-Gruppen extrahieren
     */
    private function extractGroups($ldapEntry) {
        $groups = [];
        
        if (isset($ldapEntry['memberof'])) {
            for ($i = 0; $i < $ldapEntry['memberof']['count']; $i++) {
                // CN=GroupName,... Format parsen
                preg_match('/CN=([^,]+)/i', $ldapEntry['memberof'][$i], $matches);
                if (isset($matches[1])) {
                    $groups[] = $matches[1];
                }
            }
        }

        return $groups;
    }

    /**
     * Rolle basierend auf AD-Gruppen bestimmen
     */
    public function mapADGroupsToRole($adGroups) {
        // Mapping von AD-Gruppen zu System-Rollen
        $groupRoleMap = [
            'OnboardingAdmins' => 'Admin',
            'HRDepartment' => 'HR',
            'ITDepartment' => 'IT',
            'Managers' => 'Chef',
            'Supervisors' => 'Abteilungsleiter'
        ];

        foreach ($adGroups as $group) {
            if (isset($groupRoleMap[$group])) {
                return $groupRoleMap[$group];
            }
        }

        // Fallback-Rolle
        return SSO_AUTO_ROLE;
    }

    /**
     * Alle Benutzer aus AD synchronisieren
     */
    public function syncAllUsers($db) {
        if (!$this->bind()) {
            return ['success' => false, 'message' => 'LDAP Binding fehlgeschlagen', 'errors' => $this->errors];
        }

        try {
            $filter = '(objectClass=person)';
            $attributes = ['sAMAccountName', 'mail', 'givenName', 'sn', 'department', 'title', 'telephoneNumber'];
            
            $search = @ldap_search($this->ldapConnection, $this->baseDn, $filter, $attributes);

            if (!$search) {
                throw new Exception('LDAP-Suche fehlgeschlagen');
            }

            $entries = ldap_get_entries($this->ldapConnection, $search);
            $syncedCount = 0;
            $errors = [];

            for ($i = 0; $i < $entries['count']; $i++) {
                try {
                    $userData = $this->extractUserData($entries[$i]);
                    
                    // Benutzer in DB synchronisieren oder erstellen
                    $stmt = $db->prepare('
                        INSERT INTO users (username, email, first_name, last_name, department, role, is_active, sso_id)
                        VALUES (?, ?, ?, ?, ?, ?, 1, ?)
                        ON DUPLICATE KEY UPDATE 
                        email = VALUES(email),
                        first_name = VALUES(first_name),
                        last_name = VALUES(last_name),
                        department = VALUES(department),
                        updated_at = NOW()
                    ');

                    $role = $this->mapADGroupsToRole($userData['groups']);
                    
                    $stmt->execute([
                        $userData['username'],
                        $userData['email'],
                        $userData['first_name'],
                        $userData['last_name'],
                        $userData['department'],
                        $role,
                        $userData['dn']
                    ]);

                    $syncedCount++;
                } catch (Exception $e) {
                    $errors[] = 'Benutzer ' . ($userData['username'] ?? 'unknown') . ': ' . $e->getMessage();
                }
            }

            return [
                'success' => true,
                'synced_count' => $syncedCount,
                'errors' => $errors
            ];

        } catch (Exception $e) {
            return ['success' => false, 'message' => $e->getMessage(), 'errors' => $this->errors];
        }
    }

    /**
     * Einzelnen Benutzer synchronisieren
     */
    public function syncUser($db, $userData) {
        try {
            if (AUTO_CREATE_SSO_USERS) {
                $role = $this->mapADGroupsToRole($userData['groups']);

                $stmt = $db->prepare('
                    INSERT INTO users (username, email, first_name, last_name, department, role, is_active, sso_id)
                    VALUES (?, ?, ?, ?, ?, ?, 1, ?)
                    ON DUPLICATE KEY UPDATE 
                    email = VALUES(email),
                    first_name = VALUES(first_name),
                    last_name = VALUES(last_name),
                    department = VALUES(department),
                    role = VALUES(role),
                    updated_at = NOW()
                ');

                $stmt->execute([
                    $userData['username'],
                    $userData['email'],
                    $userData['first_name'],
                    $userData['last_name'],
                    $userData['department'],
                    $role,
                    $userData['dn']
                ]);

                return ['success' => true, 'user' => $userData];
            }

            return ['success' => false, 'message' => 'Auto-Create deaktiviert'];

        } catch (Exception $e) {
            return ['success' => false, 'message' => $e->getMessage()];
        }
    }

    /**
     * Verbindung schließen
     */
    public function close() {
        if ($this->ldapConnection) {
            ldap_close($this->ldapConnection);
            $this->ldapConnection = null;
        }
    }

    /**
     * Fehler abrufen
     */
    public function getErrors() {
        return $this->errors;
    }
}

// Automatische Datenbankupdate für SSO
function createSSOTables($db) {
    $sql = '
        ALTER TABLE users ADD COLUMN IF NOT EXISTS sso_id VARCHAR(500) UNIQUE;
        ALTER TABLE users ADD COLUMN IF NOT EXISTS sso_provider VARCHAR(50) DEFAULT "ldap";
        ALTER TABLE users ADD COLUMN IF NOT EXISTS last_ldap_sync TIMESTAMP;
        ALTER TABLE users ADD INDEX idx_sso_id (sso_id);
    ';

    try {
        foreach (explode(';', $sql) as $statement) {
            if (trim($statement)) {
                $db->exec(trim($statement));
            }
        }
        return true;
    } catch (Exception $e) {
        error_log('SSO Table Creation Error: ' . $e->getMessage());
        return false;
    }
}
?>
