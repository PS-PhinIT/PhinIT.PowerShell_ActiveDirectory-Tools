<?php
/**
 * Abteilungsleiter Sektion - Spezifische Informationen für Abteilungsleiter
 * Enthält: Ressourcen-Planung, Berichtsstruktur, Team-Übersicht, Genehmigungen
 */

require_once '../config.php';
redirectIfNotLoggedIn();

// Nur für Abteilungsleiter und Admin
if (!in_array($_SESSION['role'], ['Abteilungsleiter', 'Admin'])) {
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

// Team-Mitarbeiter abrufen (Demo-Daten)
$teamMembers = [
    ['name' => 'Klaus Weber', 'position' => 'Manager', 'team_size' => 8],
    ['name' => 'Sarah Müller', 'position' => 'Senior Developer', 'team_size' => 3],
    ['name' => 'Thomas Schmidt', 'position' => 'Developer', 'team_size' => 2],
];

?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Abteilungsleiter Bereich - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50 font-sans">
    <div class="min-h-screen">
        <!-- Header -->
        <div class="bg-gradient-to-r from-purple-600 to-pink-600 text-white shadow-lg">
            <div class="max-w-7xl mx-auto px-6 py-6">
                <div class="flex items-center justify-between">
                    <div>
                        <h1 class="text-3xl font-bold">👨‍💼 Abteilungsleiter Bereich</h1>
                        <p class="text-purple-100 mt-1">Fall #<?php echo htmlspecialchars($case['case_number']); ?> - Ressourcen & Team-Planung</p>
                    </div>
                    <a href="../index.php" class="bg-white text-purple-600 px-4 py-2 rounded-lg font-semibold hover:bg-purple-50 transition">← Zurück</a>
                </div>
            </div>
        </div>

        <!-- Tabs -->
        <div class="border-b border-gray-200 bg-white sticky top-0 z-10">
            <div class="max-w-7xl mx-auto px-6">
                <div class="flex space-x-8 overflow-x-auto">
                    <a href="?case_id=<?php echo $caseId; ?>&tab=overview" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'overview' ? 'border-purple-600 text-purple-600' : 'border-transparent text-gray-600'; ?>">
                        📋 Übersicht
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=resources" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'resources' ? 'border-purple-600 text-purple-600' : 'border-transparent text-gray-600'; ?>">
                        📊 Ressourcen
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=team" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'team' ? 'border-purple-600 text-purple-600' : 'border-transparent text-gray-600'; ?>">
                        👥 Team-Struktur
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=approval" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'approval' ? 'border-purple-600 text-purple-600' : 'border-transparent text-gray-600'; ?>">
                        ✅ Genehmigung
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=integration" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'integration' ? 'border-purple-600 text-purple-600' : 'border-transparent text-gray-600'; ?>">
                        🔗 Integration
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
                            <h2 class="text-2xl font-bold text-gray-800 mb-4">👤 Neue Mitarbeiterin / Mitarbeiter</h2>
                            <div class="grid grid-cols-2 gap-4">
                                <div>
                                    <p class="text-sm text-gray-600">Name</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['employee_first_name'] . ' ' . $case['employee_last_name']); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">Position</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['job_title'] ?? 'N/A'); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">Abteilung</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['department']); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">Startdatum</p>
                                    <p class="font-semibold text-gray-800"><?php echo date('d.m.Y', strtotime($case['start_date'] ?? 'now')); ?></p>
                                </div>
                            </div>
                        </div>

                        <div class="bg-white rounded-lg shadow-md p-6 mb-6">
                            <h3 class="text-lg font-bold text-gray-800 mb-4">✅ Abteilungsleiter Checkliste</h3>
                            <div class="space-y-3">
                                <div class="flex items-start gap-3 p-4 bg-purple-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-purple-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Team informiert</p>
                                        <p class="text-sm text-gray-600">Alle Team-Mitglieder kennen den Neuzugang</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-purple-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-purple-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Berichtslinie geklärt</p>
                                        <p class="text-sm text-gray-600">Direkter Vorgesetzter und Reporting festgelegt</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-purple-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-purple-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Ressourcen reserviert</p>
                                        <p class="text-sm text-gray-600">Arbeitsplatz, Equipment, Materialien bereitgestellt</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-purple-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-purple-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Abteilungs-Onboarding geplant</p>
                                        <p class="text-sm text-gray-600">Schulungen und Einführung in Prozesse</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-purple-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-purple-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Kennzahlen genehmigt</p>
                                        <p class="text-sm text-gray-600">Budget und Leistungsziele abgestimmt</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6 sticky top-24">
                        <h3 class="font-bold text-gray-800 mb-4">⚡ Quick Actions</h3>
                        <div class="space-y-2">
                            <a href="?case_id=<?php echo $caseId; ?>&tab=resources" class="block p-3 bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg hover:shadow-md transition text-purple-700 font-semibold text-center">
                                📊 Ressourcen
                            </a>
                            <a href="?case_id=<?php echo $caseId; ?>&tab=team" class="block p-3 bg-gradient-to-r from-green-50 to-emerald-50 rounded-lg hover:shadow-md transition text-green-700 font-semibold text-center">
                                👥 Team
                            </a>
                            <a href="?case_id=<?php echo $caseId; ?>&tab=approval" class="block p-3 bg-gradient-to-r from-blue-50 to-cyan-50 rounded-lg hover:shadow-md transition text-blue-700 font-semibold text-center">
                                ✅ Genehmigen
                            </a>
                        </div>
                    </div>
                </div>

            <!-- RESOURCES -->
            <?php elseif ($tab === 'resources'): ?>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">📊 Ressourcen-Planung</h3>
                        <div class="space-y-4">
                            <div class="p-4 bg-blue-50 rounded-lg">
                                <p class="text-sm text-gray-600">💻 Workstation</p>
                                <p class="font-semibold text-gray-800">Desktop + Monitor</p>
                                <label class="flex items-center gap-2 mt-2">
                                    <input type="checkbox" checked class="w-4 h-4 text-blue-600 rounded">
                                    <span class="text-sm">Reserviert</span>
                                </label>
                            </div>

                            <div class="p-4 bg-green-50 rounded-lg">
                                <p class="text-sm text-gray-600">📞 Telefon / Handy</p>
                                <p class="font-semibold text-gray-800">iPhone + Service Plan</p>
                                <label class="flex items-center gap-2 mt-2">
                                    <input type="checkbox" class="w-4 h-4 text-green-600 rounded">
                                    <span class="text-sm">Reserviert</span>
                                </label>
                            </div>

                            <div class="p-4 bg-purple-50 rounded-lg">
                                <p class="text-sm text-gray-600">📚 Schulungen</p>
                                <p class="font-semibold text-gray-800">Interne + Externe</p>
                                <label class="flex items-center gap-2 mt-2">
                                    <input type="checkbox" class="w-4 h-4 text-purple-600 rounded">
                                    <span class="text-sm">Geplant</span>
                                </label>
                            </div>

                            <div class="p-4 bg-orange-50 rounded-lg">
                                <p class="text-sm text-gray-600">🏢 Büroraum</p>
                                <p class="font-semibold text-gray-800">Desk + Ausstattung</p>
                                <label class="flex items-center gap-2 mt-2">
                                    <input type="checkbox" checked class="w-4 h-4 text-orange-600 rounded">
                                    <span class="text-sm">Reserviert</span>
                                </label>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">📈 Abteilungs-Impact</h3>
                        <div class="space-y-4">
                            <div class="p-4 bg-gray-50 rounded-lg">
                                <p class="text-sm text-gray-600">Aktuelle Teamgröße</p>
                                <p class="text-2xl font-bold text-gray-800">12 Personen</p>
                                <div class="mt-2 w-full bg-gray-300 rounded-full h-2">
                                    <div class="bg-purple-600 h-2 rounded-full" style="width: 85%;"></div>
                                </div>
                                <p class="text-xs text-gray-600 mt-1">85% Kapazität</p>
                            </div>

                            <div class="p-4 bg-gray-50 rounded-lg">
                                <p class="text-sm text-gray-600">Nach Einstellung</p>
                                <p class="text-2xl font-bold text-purple-600">13 Personen</p>
                                <div class="mt-2 w-full bg-gray-300 rounded-full h-2">
                                    <div class="bg-green-600 h-2 rounded-full" style="width: 92%;"></div>
                                </div>
                                <p class="text-xs text-gray-600 mt-1">92% Kapazität</p>
                            </div>

                            <div class="p-4 bg-blue-50 rounded-lg">
                                <p class="text-sm text-gray-600">Budgetauswirkung</p>
                                <p class="font-semibold text-gray-800">€ 65.000 + 12.000 (Benefits)</p>
                                <p class="text-xs text-blue-600 mt-1">✓ Im Plan genehmigt</p>
                            </div>
                        </div>
                    </div>
                </div>

            <!-- TEAM-STRUKTUR -->
            <?php elseif ($tab === 'team'): ?>
                <div class="space-y-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h2 class="text-2xl font-bold text-gray-800 mb-4">👥 Team-Struktur</h2>
                        
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                            <?php foreach ($teamMembers as $index => $member): ?>
                                <div class="p-6 border-2 border-purple-200 rounded-lg hover:shadow-md transition">
                                    <div class="flex items-center justify-between mb-4">
                                        <div>
                                            <p class="font-semibold text-gray-800"><?php echo $member['name']; ?></p>
                                            <p class="text-sm text-gray-600"><?php echo $member['position']; ?></p>
                                        </div>
                                        <div class="text-3xl">👤</div>
                                    </div>
                                    <div class="bg-purple-50 px-3 py-2 rounded-lg">
                                        <p class="text-sm text-gray-600">Team-Größe</p>
                                        <p class="font-bold text-purple-700"><?php echo $member['team_size']; ?> Personen</p>
                                    </div>
                                </div>
                            <?php endforeach; ?>

                            <div class="p-6 border-2 border-green-200 rounded-lg bg-green-50">
                                <div class="flex items-center justify-between mb-4">
                                    <div>
                                        <p class="font-semibold text-gray-800">➕ Neue Mitarbeiterin</p>
                                        <p class="text-sm text-gray-600"><?php echo htmlspecialchars($case['job_title'] ?? 'Position'); ?></p>
                                    </div>
                                    <div class="text-3xl">🆕</div>
                                </div>
                                <div class="bg-green-100 px-3 py-2 rounded-lg">
                                    <p class="text-sm text-gray-600">Reports zu:</p>
                                    <p class="font-bold text-green-700">Klaus Weber</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">📊 Berichtslinie</h3>
                        <div class="space-y-4">
                            <div class="p-4 bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg border-l-4 border-purple-600">
                                <p class="text-sm text-gray-600">Direkter Manager</p>
                                <p class="font-semibold text-gray-800">Klaus Weber</p>
                                <p class="text-xs text-gray-600 mt-2">Verantwortung für tägliche Aufgaben & Entwicklung</p>
                            </div>

                            <div class="p-4 bg-gradient-to-r from-blue-50 to-cyan-50 rounded-lg border-l-4 border-blue-600">
                                <p class="text-sm text-gray-600">Abteilungsleiter</p>
                                <p class="font-semibold text-gray-800">Sie (Abteilungsleiter)</p>
                                <p class="text-xs text-gray-600 mt-2">Strategische Leitung & Ressourcen</p>
                            </div>

                            <div class="p-4 bg-gradient-to-r from-green-50 to-emerald-50 rounded-lg border-l-4 border-green-600">
                                <p class="text-sm text-gray-600">Geschäftsführung</p>
                                <p class="font-semibold text-gray-800">Vorstand</p>
                                <p class="text-xs text-gray-600 mt-2">Übergeordnete Ziele & Unternehmensstrategie</p>
                            </div>
                        </div>
                    </div>
                </div>

            <!-- APPROVAL -->
            <?php elseif ($tab === 'approval'): ?>
                <div class="space-y-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h2 class="text-2xl font-bold text-gray-800 mb-4">✅ Abteilungsleiter Genehmigung</h2>
                        
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
                            <div class="p-6 bg-green-50 rounded-lg border-2 border-green-300">
                                <div class="flex items-center justify-between mb-4">
                                    <h3 class="font-bold text-gray-800">✓ HR Genehmigung</h3>
                                    <span class="bg-green-200 text-green-800 px-3 py-1 rounded-full text-sm font-bold">Approved</span>
                                </div>
                                <div class="text-sm text-gray-600 space-y-1">
                                    <p><strong>Von:</strong> Petra Müller</p>
                                    <p><strong>Datum:</strong> 15.10.2025</p>
                                </div>
                            </div>

                            <div class="p-6 bg-blue-50 rounded-lg border-2 border-blue-300">
                                <div class="flex items-center justify-between mb-4">
                                    <h3 class="font-bold text-gray-800">⏳ Abteilungsleiter</h3>
                                    <span class="bg-yellow-200 text-yellow-800 px-3 py-1 rounded-full text-sm font-bold">Pending</span>
                                </div>
                                <button class="w-full bg-purple-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-purple-700 transition mt-2">
                                    🖊️ Jetzt genehmigen
                                </button>
                            </div>

                            <div class="p-6 bg-purple-50 rounded-lg border-2 border-purple-300">
                                <div class="flex items-center justify-between mb-4">
                                    <h3 class="font-bold text-gray-800">⏳ Ressourcen</h3>
                                    <span class="bg-yellow-200 text-yellow-800 px-3 py-1 rounded-full text-sm font-bold">Pending</span>
                                </div>
                                <button class="w-full bg-purple-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-purple-700 transition mt-2">
                                    🖊️ Ressourcen genehmigen
                                </button>
                            </div>

                            <div class="p-6 bg-orange-50 rounded-lg border-2 border-orange-300">
                                <div class="flex items-center justify-between mb-4">
                                    <h3 class="font-bold text-gray-800">⏳ Team-Integration</h3>
                                    <span class="bg-yellow-200 text-yellow-800 px-3 py-1 rounded-full text-sm font-bold">Pending</span>
                                </div>
                                <button class="w-full bg-orange-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-orange-700 transition mt-2">
                                    🖊️ Freigeben
                                </button>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">📝 Genehmigungsformular</h3>
                        <form class="space-y-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">Bemerkungen zur Einstellung</label>
                                <textarea rows="4" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500" placeholder="Ihre Bewertung und Bemerkungen..."></textarea>
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">Ressourcenplanung</label>
                                <textarea rows="3" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500" placeholder="Ressourcen für diese Einstellung..."></textarea>
                            </div>
                            <div class="flex gap-3">
                                <button type="button" class="flex-1 bg-green-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-green-700 transition">
                                    ✓ Genehmigt
                                </button>
                                <button type="button" class="flex-1 bg-red-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-red-700 transition">
                                    ✗ Abgelehnt
                                </button>
                            </div>
                        </form>
                    </div>
                </div>

            <!-- INTEGRATION -->
            <?php elseif ($tab === 'integration'): ?>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">🔗 Abteilungs-Integration</h3>
                        <div class="space-y-4">
                            <div class="p-4 bg-blue-50 rounded-lg">
                                <p class="font-semibold text-gray-800">✓ Projekt-Zuordnung</p>
                                <p class="text-sm text-gray-600 mt-1">Mitarbeiter zu Projekten hinzufügen</p>
                                <button class="mt-3 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition text-sm font-semibold">
                                    → Projekte
                                </button>
                            </div>

                            <div class="p-4 bg-green-50 rounded-lg">
                                <p class="font-semibold text-gray-800">✓ Mentoring-Programm</p>
                                <p class="text-sm text-gray-600 mt-1">Mit Mentor im Team verbinden</p>
                                <button class="mt-3 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition text-sm font-semibold">
                                    → Mentor zuweisen
                                </button>
                            </div>

                            <div class="p-4 bg-purple-50 rounded-lg">
                                <p class="font-semibold text-gray-800">✓ Slack / Teams</p>
                                <p class="text-sm text-gray-600 mt-1">Zu Abteilungs-Kanälen hinzufügen</p>
                                <button class="mt-3 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition text-sm font-semibold">
                                    → Kanäle einrichten
                                </button>
                            </div>

                            <div class="p-4 bg-orange-50 rounded-lg">
                                <p class="font-semibold text-gray-800">✓ Dokumentation</p>
                                <p class="text-sm text-gray-600 mt-1">Abteilungs-Wiki & Ressourcen</p>
                                <button class="mt-3 px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition text-sm font-semibold">
                                    → Links
                                </button>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">📅 Einarbeitungsplan</h3>
                        <div class="space-y-3">
                            <div class="p-3 bg-red-50 border-l-4 border-red-600 rounded">
                                <p class="font-semibold text-red-800">Woche 1</p>
                                <p class="text-sm text-gray-600">Team-Kennenlernen, Arbeitsplatz, Prozess-Übersicht</p>
                            </div>
                            <div class="p-3 bg-orange-50 border-l-4 border-orange-600 rounded">
                                <p class="font-semibold text-orange-800">Woche 2-3</p>
                                <p class="text-sm text-gray-600">Spezialtrainings, Mentoring, erste Projekte</p>
                            </div>
                            <div class="p-3 bg-yellow-50 border-l-4 border-yellow-600 rounded">
                                <p class="font-semibold text-yellow-800">Woche 4</p>
                                <p class="text-sm text-gray-600">Eigenständige Arbeit, Check-in mit Manager</p>
                            </div>
                            <div class="p-3 bg-green-50 border-l-4 border-green-600 rounded">
                                <p class="font-semibold text-green-800">Monat 2-3</p>
                                <p class="text-sm text-gray-600">Vollständige Integration, regelmäßige Rückmeldung</p>
                            </div>
                        </div>
                    </div>
                </div>

            <?php endif; ?>
        </main>
    </div>
</body>
</html>
