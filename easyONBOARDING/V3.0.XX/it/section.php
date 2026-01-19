<?php
/**
 * IT Sektion - Spezifische Informationen für IT
 * Enthält: Account-Setup, Hardware, Software, Sicherheit
 */

require_once '../config.php';
redirectIfNotLoggedIn();

// Nur für IT und Admin
if (!in_array($_SESSION['role'], ['IT', 'Admin'])) {
    die('Zugriff verweigert');
}

$caseId = intval($_GET['case_id'] ?? 0);
if (!$caseId) {
    header('Location: ../index.php');
    exit();
}

// Case abrufen
$stmt = $db->prepare('SELECT * FROM onboarding_cases WHERE id = ?');
$stmt->execute([$caseId]);
$case = $stmt->fetch();

if (!$case) {
    header('Location: ../index.php');
    exit();
}

$tab = sanitize($_GET['tab'] ?? 'overview');

?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IT Bereich - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50 font-sans">
    <div class="min-h-screen">
        <!-- Header -->
        <div class="bg-gradient-to-r from-green-600 to-emerald-600 text-white shadow-lg">
            <div class="max-w-7xl mx-auto px-6 py-6">
                <div class="flex items-center justify-between">
                    <div>
                        <h1 class="text-3xl font-bold">💻 IT Bereich</h1>
                        <p class="text-green-100 mt-1">Fall #<?php echo htmlspecialchars($case['case_number']); ?> - Technisches Onboarding</p>
                    </div>
                    <a href="../index.php" class="bg-white text-green-600 px-4 py-2 rounded-lg font-semibold hover:bg-green-50 transition">← Zurück</a>
                </div>
            </div>
        </div>

        <!-- Tabs -->
        <div class="border-b border-gray-200 bg-white sticky top-0 z-10">
            <div class="max-w-7xl mx-auto px-6">
                <div class="flex space-x-8 overflow-x-auto">
                    <a href="?case_id=<?php echo $caseId; ?>&tab=overview" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'overview' ? 'border-green-600 text-green-600' : 'border-transparent text-gray-600'; ?>">
                        📋 Übersicht
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=accounts" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'accounts' ? 'border-green-600 text-green-600' : 'border-transparent text-gray-600'; ?>">
                        👤 Accounts
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=hardware" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'hardware' ? 'border-green-600 text-green-600' : 'border-transparent text-gray-600'; ?>">
                        🖥️ Hardware
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=software" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'software' ? 'border-green-600 text-green-600' : 'border-transparent text-gray-600'; ?>">
                        📦 Software
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=security" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'security' ? 'border-green-600 text-green-600' : 'border-transparent text-gray-600'; ?>">
                        🔐 Sicherheit
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=credentials" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'credentials' ? 'border-green-600 text-green-600' : 'border-transparent text-gray-600'; ?>">
                        🔑 Credentials
                    </a>
                </div>
            </div>
        </div>

        <!-- Content -->
        <main class="max-w-7xl mx-auto px-6 py-8">

            <!-- OVERVIEW -->
            <?php if ($tab === 'overview'): ?>
                <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    <div class="lg:col-span-2">
                        <div class="bg-white rounded-lg shadow-md p-6 mb-6">
                            <h2 class="text-2xl font-bold text-gray-800 mb-4">🎯 IT Onboarding Checklist</h2>
                            <div class="space-y-3">
                                <div class="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-green-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">✅ AD-Account erstellt</p>
                                        <p class="text-sm text-gray-600">Windows / Active Directory Login</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-green-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">💻 Laptop/PC bereitgestellt</p>
                                        <p class="text-sm text-gray-600">Hardware konfiguriert und ausgeliefert</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-green-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">📧 Email-Account aktiviert</p>
                                        <p class="text-sm text-gray-600">Exchange / Outlook konfiguriert</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-green-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-green-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">🔐 Sicherheit & Policies</p>
                                        <p class="text-sm text-gray-600">VPN, Antivirus, Firewall konfiguriert</p>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Quick Setup -->
                        <div class="bg-white rounded-lg shadow-md p-6">
                            <h3 class="text-lg font-bold text-gray-800 mb-4">⚡ Schnelles Setup</h3>
                            <div class="bg-blue-50 p-4 rounded-lg">
                                <p class="text-sm text-gray-700 mb-3">Führe diese Schritte in Reihenfolge aus:</p>
                                <ol class="list-decimal list-inside space-y-2 text-sm">
                                    <li><strong>AD-Account:</strong> Benutzer im Active Directory anlegen</li>
                                    <li><strong>Email:</strong> Exchange-Postfach erstellen</li>
                                    <li><strong>Gruppen:</strong> Security Groups hinzufügen</li>
                                    <li><strong>Hardware:</strong> PC/Laptop austeilen</li>
                                    <li><strong>Software:</strong> Alle Programme installieren</li>
                                    <li><strong>Sicherheit:</strong> Policies & MFA aktivieren</li>
                                </ol>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6 sticky top-24">
                        <h3 class="font-bold text-gray-800 mb-4">ℹ️ Mitarbeiter Info</h3>
                        <div class="space-y-3 text-sm">
                            <div>
                                <p class="text-gray-600">Name</p>
                                <p class="font-semibold"><?php echo htmlspecialchars($case['employee_first_name'] . ' ' . $case['employee_last_name']); ?></p>
                            </div>
                            <div>
                                <p class="text-gray-600">Abteilung</p>
                                <p class="font-semibold"><?php echo htmlspecialchars($case['department']); ?></p>
                            </div>
                            <div>
                                <p class="text-gray-600">Position</p>
                                <p class="font-semibold"><?php echo htmlspecialchars($case['job_title'] ?? 'N/A'); ?></p>
                            </div>
                            <div>
                                <p class="text-gray-600">Startdatum</p>
                                <p class="font-semibold"><?php echo date('d.m.Y', strtotime($case['start_date'] ?? 'now')); ?></p>
                            </div>
                        </div>
                    </div>
                </div>

            <!-- ACCOUNTS -->
            <?php elseif ($tab === 'accounts'): ?>
                <div class="space-y-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h2 class="text-2xl font-bold text-gray-800 mb-4">👤 Benutzer-Accounts</h2>
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div class="p-4 bg-blue-50 rounded-lg border-l-4 border-blue-600">
                                <p class="font-semibold text-gray-800">🪟 Windows/Active Directory</p>
                                <div class="mt-2 text-sm space-y-1">
                                    <p><strong>Username:</strong> <?php echo strtolower(substr($case['employee_first_name'], 0, 1) . '.' . $case['employee_last_name']); ?></p>
                                    <p><strong>Status:</strong> <span class="bg-green-100 text-green-800 px-2 py-1 rounded text-xs font-semibold">Zu erstellen</span></p>
                                    <p><strong>Organisationseeinheit:</strong> OU=<?php echo htmlspecialchars($case['department']); ?></p>
                                </div>
                            </div>

                            <div class="p-4 bg-green-50 rounded-lg border-l-4 border-green-600">
                                <p class="font-semibold text-gray-800">📧 Exchange / Email</p>
                                <div class="mt-2 text-sm space-y-1">
                                    <p><strong>Adresse:</strong> <?php echo htmlspecialchars($case['employee_email']); ?></p>
                                    <p><strong>Postfach-Größe:</strong> 100 GB</p>
                                    <p><strong>Archiv:</strong> Unbegrenzt</p>
                                </div>
                            </div>

                            <div class="p-4 bg-purple-50 rounded-lg border-l-4 border-purple-600">
                                <p class="font-semibold text-gray-800">☁️ Microsoft 365</p>
                                <div class="mt-2 text-sm space-y-1">
                                    <p><strong>Lizenz:</strong> E3 / E5</p>
                                    <p><strong>OneDrive:</strong> 1 TB</p>
                                    <p><strong>Teams:</strong> Aktiviert</p>
                                </div>
                            </div>

                            <div class="p-4 bg-orange-50 rounded-lg border-l-4 border-orange-600">
                                <p class="font-semibold text-gray-800">🔒 Multi-Factor Auth</p>
                                <div class="mt-2 text-sm space-y-1">
                                    <p><strong>MFA:</strong> Erforderlich</p>
                                    <p><strong>Methode:</strong> Authenticator App</p>
                                    <p><strong>Backup Codes:</strong> Generiert</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">✅ Sicherheitsgruppen</h3>
                        <div class="space-y-2">
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                <span>GRP-<?php echo htmlspecialchars($case['department']); ?>-Users</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                <span>GRP-Employees-All</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                <span>GRP-VPN-Users</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                <span>GRP-Printing-<?php echo htmlspecialchars($case['department']); ?></span>
                            </label>
                        </div>
                    </div>
                </div>

            <!-- HARDWARE -->
            <?php elseif ($tab === 'hardware'): ?>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">💻 Computer</h3>
                        <div class="space-y-3">
                            <div class="p-4 bg-blue-50 rounded-lg">
                                <p class="font-semibold">🖥️ Desktop / Laptop</p>
                                <p class="text-sm text-gray-600 mt-2">
                                    Modell: Dell Latitude 5000 Serie<br>
                                    CPU: Intel i7 11. Gen<br>
                                    RAM: 16 GB DDR4<br>
                                    SSD: 512 GB NVMe<br>
                                    OS: Windows 11 Pro
                                </p>
                            </div>
                            <div class="p-4 bg-green-50 rounded-lg">
                                <p class="font-semibold">📱 Smartphone</p>
                                <p class="text-sm text-gray-600 mt-2">
                                    Gerät: iPhone 14 / Samsung S23<br>
                                    Vertrag: Telekom Business<br>
                                    Datenvolumen: Unbegrenzt<br>
                                    MDM: Intune Management
                                </p>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">🎧 Peripherie</h3>
                        <div class="space-y-3">
                            <div class="p-4 bg-purple-50 rounded-lg">
                                <label class="flex items-center gap-3">
                                    <input type="checkbox" class="w-5 h-5 text-purple-600 rounded">
                                    <span>🖱️ Ergonomische Maus</span>
                                </label>
                            </div>
                            <div class="p-4 bg-orange-50 rounded-lg">
                                <label class="flex items-center gap-3">
                                    <input type="checkbox" class="w-5 h-5 text-orange-600 rounded">
                                    <span>⌨️ Mechanische Tastatur</span>
                                </label>
                            </div>
                            <div class="p-4 bg-pink-50 rounded-lg">
                                <label class="flex items-center gap-3">
                                    <input type="checkbox" class="w-5 h-5 text-pink-600 rounded">
                                    <span>🖥️ Monitor (2x 27" 4K)</span>
                                </label>
                            </div>
                            <div class="p-4 bg-cyan-50 rounded-lg">
                                <label class="flex items-center gap-3">
                                    <input type="checkbox" class="w-5 h-5 text-cyan-600 rounded">
                                    <span>🎙️ Headset / Mikrofon</span>
                                </label>
                            </div>
                        </div>
                    </div>
                </div>

            <!-- SOFTWARE -->
            <?php elseif ($tab === 'software'): ?>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">📦 Standard-Software</h3>
                        <div class="space-y-2">
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                <span>Microsoft Office 365</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                <span>Visual Studio Code</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                <span>Git / GitHub Desktop</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                <span>Docker Desktop</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                <span>Slack / Teams</span>
                            </label>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">🔒 Sicherheits-Tools</h3>
                        <div class="space-y-2">
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-red-600 rounded">
                                <span>Windows Defender</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-red-600 rounded">
                                <span>Sophos Endpoint Protection</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-red-600 rounded">
                                <span>Cisco AnyConnect VPN</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-red-600 rounded">
                                <span>Microsoft Defender for Endpoint</span>
                            </label>
                            <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                <input type="checkbox" class="w-5 h-5 text-red-600 rounded">
                                <span>Password Manager (1Password)</span>
                            </label>
                        </div>
                    </div>
                </div>

            <!-- SECURITY -->
            <?php elseif ($tab === 'security'): ?>
                <div class="space-y-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h2 class="text-2xl font-bold text-gray-800 mb-4">🔐 Sicherheits-Richtlinien</h2>
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div class="p-4 bg-red-50 border-l-4 border-red-600 rounded">
                                <p class="font-semibold text-gray-800">🔒 Passwort-Richtlinien</p>
                                <ul class="text-sm text-gray-600 mt-2 space-y-1">
                                    <li>• Min. 14 Zeichen</li>
                                    <li>• Großbuchstaben + Zahlen + Sonderzeichen</li>
                                    <li>• Wechsel alle 90 Tage</li>
                                    <li>• Keine Wiederholung der letzten 5</li>
                                </ul>
                            </div>
                            <div class="p-4 bg-yellow-50 border-l-4 border-yellow-600 rounded">
                                <p class="font-semibold text-gray-800">📱 Multi-Factor Authentication</p>
                                <ul class="text-sm text-gray-600 mt-2 space-y-1">
                                    <li>• Erforderlich für alle Konten</li>
                                    <li>• Microsoft Authenticator</li>
                                    <li>• Backup-Codes archivieren</li>
                                    <li>• 2FA auch für VPN</li>
                                </ul>
                            </div>
                            <div class="p-4 bg-blue-50 border-l-4 border-blue-600 rounded">
                                <p class="font-semibold text-gray-800">🌐 Fernzugriff (VPN)</p>
                                <ul class="text-sm text-gray-600 mt-2 space-y-1">
                                    <li>• Cisco AnyConnect erforderlich</li>
                                    <li>• Split Tunneling deaktiviert</li>
                                    <li>• Automatischer Disconnect</li>
                                    <li>• IP-Whitelisting</li>
                                </ul>
                            </div>
                            <div class="p-4 bg-green-50 border-l-4 border-green-600 rounded">
                                <p class="font-semibold text-gray-800">🔓 Datensicherung</p>
                                <ul class="text-sm text-gray-600 mt-2 space-y-1">
                                    <li>• Tägliche Backups</li>
                                    <li>• OneDrive Sync 24/7</li>
                                    <li>• 30 Tage Wiederherstellung</li>
                                    <li>• Verschlüsseling at Rest & In Transit</li>
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>

            <!-- CREDENTIALS -->
            <?php elseif ($tab === 'credentials'): ?>
                <div class="bg-white rounded-lg shadow-md p-6">
                    <h2 class="text-2xl font-bold text-gray-800 mb-6">🔑 Zugangsdaten</h2>
                    <div class="bg-yellow-50 p-4 rounded-lg mb-6 border-l-4 border-yellow-600">
                        <p class="text-sm text-yellow-800"><strong>⚠️ Sicherheitshinweis:</strong> Diese Daten sollten in einem sicheren Password Manager gespeichert werden. Niemals per Email verschicken!</p>
                    </div>

                    <div class="grid grid-cols-1 gap-6">
                        <div class="p-6 bg-blue-50 rounded-lg border border-blue-200">
                            <h3 class="font-bold text-gray-800 mb-3">🪟 Windows / Active Directory</h3>
                            <div class="space-y-2 text-sm">
                                <p><strong>Username:</strong> <code class="bg-white px-2 py-1 rounded">{{ username }}</code></p>
                                <p><strong>Password:</strong> <code class="bg-white px-2 py-1 rounded">[Generiert bei Erstanmeldung]</code></p>
                                <p><strong>Erste Anmeldung:</strong> PC während Onboarding-Session</p>
                                <p><strong>Domain:</strong> COMPANY.LOCAL</p>
                            </div>
                        </div>

                        <div class="p-6 bg-green-50 rounded-lg border border-green-200">
                            <h3 class="font-bold text-gray-800 mb-3">📧 Email / Exchange</h3>
                            <div class="space-y-2 text-sm">
                                <p><strong>Email:</strong> <code class="bg-white px-2 py-1 rounded"><?php echo htmlspecialchars($case['employee_email']); ?></code></p>
                                <p><strong>Outlook Web:</strong> <code class="bg-white px-2 py-1 rounded">outlook.office.com</code></p>
                                <p><strong>IMAP/SMTP:</strong> outlook.office365.com</p>
                                <p><strong>Authentifizierung:</strong> OAuth2 / Modern Auth</p>
                            </div>
                        </div>

                        <div class="p-6 bg-purple-50 rounded-lg border border-purple-200">
                            <h3 class="font-bold text-gray-800 mb-3">☁️ Microsoft 365</h3>
                            <div class="space-y-2 text-sm">
                                <p><strong>Portal:</strong> <code class="bg-white px-2 py-1 rounded">office.com</code></p>
                                <p><strong>Teams:</strong> <code class="bg-white px-2 py-1 rounded">teams.microsoft.com</code></p>
                                <p><strong>OneDrive:</strong> <code class="bg-white px-2 py-1 rounded">1TB Storage</code></p>
                                <p><strong>SharePoint:</strong> <code class="bg-white px-2 py-1 rounded">company.sharepoint.com</code></p>
                            </div>
                        </div>
                    </div>
                </div>

            <?php endif; ?>
        </main>
    </div>
</body>
</html>
