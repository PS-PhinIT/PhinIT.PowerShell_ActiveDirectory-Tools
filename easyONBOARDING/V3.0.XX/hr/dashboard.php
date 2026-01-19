<?php
require_once '../config.php';
redirectIfNotLoggedIn();

if ($_SESSION['role'] !== 'HR' && $_SESSION['role'] !== 'Admin') {
    header('Location: ' . SITE_URL . 'index.php');
    exit();
}

$message = '';
$error = '';

// Neuer Onboarding-Fall erstellen
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['create_case'])) {
    try {
        $firstName = sanitize($_POST['first_name']);
        $lastName = sanitize($_POST['last_name']);
        $email = sanitize($_POST['email']);
        $department = sanitize($_POST['department']);
        $jobTitle = sanitize($_POST['job_title']);
        $startDate = $_POST['start_date'] ?? null;
        $managerId = intval($_POST['manager'] ?? 0) ?: null;

        if (empty($firstName) || empty($lastName) || empty($email)) {
            $error = 'Vorname, Nachname und E-Mail sind erforderlich.';
        } else {
            // Fallnummer generieren
            $caseNumber = 'ONBOARD-' . date('YmdHis') . '-' . rand(1000, 9999);

            // Passwort generieren
            $password = generatePassword(12);
            $passwordHash = password_hash($password, PASSWORD_DEFAULT);

            // Username und Email generieren falls nicht vorhanden
            $username = generateUsername($firstName, $lastName);
            $generatedEmail = generateEmail($firstName, $lastName);

            $stmt = $db->prepare('
                INSERT INTO onboarding_cases 
                (case_number, employee_first_name, employee_last_name, employee_email, employee_username, employee_password, department, job_title, manager_id, start_date, status, current_step, current_role, created_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ');

            $stmt->execute([
                $caseNumber,
                $firstName,
                $lastName,
                $email,
                $username,
                $passwordHash,
                $department,
                $jobTitle,
                $managerId,
                $startDate,
                'pending',
                1,
                'HR',
                $_SESSION['user_id']
            ]);

            $caseId = $db->lastInsertId();
            logAction($_SESSION['user_id'], 'create_case', 'Fall erstellt: ' . $caseNumber);

            $_SESSION['password'] = $password;
            $_SESSION['username'] = $username;
            $_SESSION['case_id'] = $caseId;

            $message = 'Onboarding-Fall erfolgreich erstellt!';
        }
    } catch (Exception $e) {
        $error = 'Fehler beim Erstellen des Falls: ' . $e->getMessage();
    }
}

// Aktive Fälle abrufen
$stmt = $db->prepare('SELECT * FROM onboarding_cases WHERE status != "completed" ORDER BY created_at DESC');
$stmt->execute();
$activeCases = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Benutzer als Manager abrufen
$stmt = $db->query('SELECT id, first_name, last_name, department FROM users WHERE role IN ("Abteilungsleiter", "Chef") AND is_active = TRUE ORDER BY first_name');
$managers = $stmt->fetchAll(PDO::FETCH_ASSOC);
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HR Dashboard - <?php echo SITE_NAME; ?></title>
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
                    <h1 class="text-lg font-bold text-gray-800">HR Panel</h1>
                </div>

                <nav class="space-y-2">
                    <a href="dashboard.php" class="bg-blue-100 text-blue-600 block px-4 py-2 rounded-lg transition-colors">
                        📊 Dashboard
                    </a>
                    <a href="create_case.php" class="text-gray-600 hover:bg-gray-100 block px-4 py-2 rounded-lg transition-colors">
                        ➕ Neuer Fall
                    </a>
                    <a href="my_cases.php" class="text-gray-600 hover:bg-gray-100 block px-4 py-2 rounded-lg transition-colors">
                        📁 Meine Fälle
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
            <h2 class="text-3xl font-bold text-gray-800 mb-8">HR Dashboard</h2>

            <?php if (!empty($error)): ?>
                <div class="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700 rounded">
                    <?php echo htmlspecialchars($error); ?>
                </div>
            <?php endif; ?>

            <?php if (!empty($message)): ?>
                <div class="mb-6 p-4 bg-green-50 border-l-4 border-green-500 text-green-700 rounded">
                    <?php echo htmlspecialchars($message); ?>
                    <?php if (isset($_SESSION['password'])): ?>
                        <p class="mt-2 font-semibold">
                            Benutzername: <code class="bg-green-100 px-2 py-1 rounded"><?php echo $_SESSION['username']; ?></code>
                        </p>
                        <p>
                            Passwort: <code class="bg-green-100 px-2 py-1 rounded"><?php echo $_SESSION['password']; ?></code>
                        </p>
                    <?php unset($_SESSION['password'], $_SESSION['username']); endif; ?>
                </div>
            <?php endif; ?>

            <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
                <!-- Neuer Fall erstellen -->
                <div class="lg:col-span-1">
                    <div class="bg-white rounded-lg shadow p-6">
                        <h3 class="text-xl font-semibold text-gray-800 mb-4">Neuer Onboarding-Fall</h3>
                        <form method="POST" class="space-y-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">Vorname *</label>
                                <input type="text" name="first_name" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                            </div>

                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">Nachname *</label>
                                <input type="text" name="last_name" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                            </div>

                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">E-Mail *</label>
                                <input type="email" name="email" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                            </div>

                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">Abteilung *</label>
                                <input type="text" name="department" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                            </div>

                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">Stellenbezeichnung *</label>
                                <input type="text" name="job_title" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                            </div>

                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">Startdatum</label>
                                <input type="date" name="start_date" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                            </div>

                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">Vorgesetzter</label>
                                <select name="manager" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                                    <option value="">-- Nicht zugewiesen --</option>
                                    <?php foreach ($managers as $manager): ?>
                                        <option value="<?php echo $manager['id']; ?>"><?php echo htmlspecialchars($manager['first_name'] . ' ' . $manager['last_name'] . ' (' . $manager['department'] . ')'); ?></option>
                                    <?php endforeach; ?>
                                </select>
                            </div>

                            <button type="submit" name="create_case" class="w-full bg-blue-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors">
                                Fall erstellen
                            </button>
                        </form>
                    </div>
                </div>

                <!-- Aktive Fälle -->
                <div class="lg:col-span-2">
                    <div class="bg-white rounded-lg shadow">
                        <div class="px-6 py-4 border-b border-gray-200">
                            <h3 class="text-xl font-semibold text-gray-800">Aktive Onboarding-Fälle</h3>
                        </div>
                        <div class="divide-y divide-gray-200">
                            <?php if (empty($activeCases)): ?>
                                <p class="px-6 py-4 text-gray-600">Keine aktiven Fälle vorhanden.</p>
                            <?php else: ?>
                                <?php foreach ($activeCases as $case): ?>
                                    <div class="px-6 py-4 hover:bg-gray-50 transition-colors">
                                        <div class="flex justify-between items-start">
                                            <div class="flex-1">
                                                <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['employee_first_name'] . ' ' . $case['employee_last_name']); ?></p>
                                                <p class="text-sm text-gray-600">Fallnummer: <?php echo htmlspecialchars($case['case_number']); ?></p>
                                                <p class="text-sm text-gray-600">Abteilung: <?php echo htmlspecialchars($case['department']); ?></p>
                                                <p class="text-sm text-gray-600">Startdatum: <?php echo $case['start_date'] ? date('d.m.Y', strtotime($case['start_date'])) : '-'; ?></p>
                                                <!-- Role-specific Links -->
                                                <div class="mt-3 flex flex-wrap gap-2">
                                                    <a href="../hr/section.php?case_id=<?php echo $case['id']; ?>" class="px-2 py-1 bg-red-100 text-red-700 rounded text-xs font-semibold hover:bg-red-200 transition">👥 HR</a>
                                                    <a href="../manager/section.php?case_id=<?php echo $case['id']; ?>" class="px-2 py-1 bg-blue-100 text-blue-700 rounded text-xs font-semibold hover:bg-blue-200 transition">👔 Manager</a>
                                                    <a href="../supervisor/section.php?case_id=<?php echo $case['id']; ?>" class="px-2 py-1 bg-purple-100 text-purple-700 rounded text-xs font-semibold hover:bg-purple-200 transition">👨‍💼 Abteilungsleiter</a>
                                                    <a href="../it/section.php?case_id=<?php echo $case['id']; ?>" class="px-2 py-1 bg-green-100 text-green-700 rounded text-xs font-semibold hover:bg-green-200 transition">💻 IT</a>
                                                    <a href="../export/final_onboarding_document.php?case_id=<?php echo $case['id']; ?>" class="px-2 py-1 bg-yellow-100 text-yellow-700 rounded text-xs font-semibold hover:bg-yellow-200 transition">📄 Dokument</a>
                                                </div>
                                            </div>
                                            <div class="text-right">
                                                <span class="<?php 
                                                    $status_colors = [
                                                        'pending' => 'bg-orange-100 text-orange-800',
                                                        'in_progress' => 'bg-blue-100 text-blue-800',
                                                        'completed' => 'bg-green-100 text-green-800'
                                                    ];
                                                    echo $status_colors[$case['status']] ?? 'bg-gray-100 text-gray-800';
                                                ?> px-3 py-1 rounded-full text-xs font-semibold">
                                                    <?php echo ucfirst($case['status']); ?>
                                                </span>
                                                <p class="text-sm text-gray-600 mt-2">Rolle: <?php echo $case['current_role']; ?></p>
                                            </div>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>
            </div>
        </main>
    </div>
</body>
</html>
