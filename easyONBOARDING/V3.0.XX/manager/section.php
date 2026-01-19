<?php
/**
 * Manager/Chef Sektion - Spezifische Informationen für Manager
 * Enthält: Genehmigungen, Team-Zuordnung, Budgets, Evaluationen
 */

require_once '../config.php';
redirectIfNotLoggedIn();

// Nur für Chef/Manager und Admin
if (!in_array($_SESSION['role'], ['Chef', 'Admin'])) {
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
    <title>Manager Bereich - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50 font-sans">
    <div class="min-h-screen">
        <!-- Header -->
        <div class="bg-gradient-to-r from-blue-600 to-cyan-600 text-white shadow-lg">
            <div class="max-w-7xl mx-auto px-6 py-6">
                <div class="flex items-center justify-between">
                    <div>
                        <h1 class="text-3xl font-bold">👔 Manager/Chef Bereich</h1>
                        <p class="text-blue-100 mt-1">Fall #<?php echo htmlspecialchars($case['case_number']); ?> - Management & Genehmigung</p>
                    </div>
                    <a href="../index.php" class="bg-white text-blue-600 px-4 py-2 rounded-lg font-semibold hover:bg-blue-50 transition">← Zurück</a>
                </div>
            </div>
        </div>

        <!-- Tabs -->
        <div class="border-b border-gray-200 bg-white sticky top-0 z-10">
            <div class="max-w-7xl mx-auto px-6">
                <div class="flex space-x-8 overflow-x-auto">
                    <a href="?case_id=<?php echo $caseId; ?>&tab=overview" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'overview' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-600'; ?>">
                        📋 Übersicht
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=approval" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'approval' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-600'; ?>">
                        ✅ Genehmigung
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=team" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'team' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-600'; ?>">
                        👥 Team
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=budget" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'budget' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-600'; ?>">
                        💰 Budget
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=evaluation" class="py-4 px-2 border-b-2 font-semibold whitespace-nowrap <?php echo $tab === 'evaluation' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-600'; ?>">
                        📊 Evaluation
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
                            <h2 class="text-2xl font-bold text-gray-800 mb-4">👤 Mitarbeiter Profil</h2>
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
                            <h3 class="text-lg font-bold text-gray-800 mb-4">✅ Manager Checkliste</h3>
                            <div class="space-y-3">
                                <div class="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-blue-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Einstellung genehmigt</p>
                                        <p class="text-sm text-gray-600">Personalentscheidung finalisiert</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-blue-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Team informiert</p>
                                        <p class="text-sm text-gray-600">Team-Meeting durchgeführt</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-blue-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Arbeitsplatz vorbereitet</p>
                                        <p class="text-sm text-gray-600">Desk & Materialien bereitgestellt</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-blue-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Mentor zugewiesen</p>
                                        <p class="text-sm text-gray-600">Einarbeitungspate vorhanden</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6 sticky top-24">
                        <h3 class="font-bold text-gray-800 mb-4">⚡ Quick Actions</h3>
                        <div class="space-y-2">
                            <a href="?case_id=<?php echo $caseId; ?>&tab=approval" class="block p-3 bg-gradient-to-r from-blue-50 to-cyan-50 rounded-lg hover:shadow-md transition text-blue-700 font-semibold text-center">
                                ✅ Genehmigungen
                            </a>
                            <a href="?case_id=<?php echo $caseId; ?>&tab=team" class="block p-3 bg-gradient-to-r from-green-50 to-emerald-50 rounded-lg hover:shadow-md transition text-green-700 font-semibold text-center">
                                👥 Team-Zuordnung
                            </a>
                            <a href="?case_id=<?php echo $caseId; ?>&tab=budget" class="block p-3 bg-gradient-to-r from-orange-50 to-amber-50 rounded-lg hover:shadow-md transition text-orange-700 font-semibold text-center">
                                💰 Budget
                            </a>
                        </div>
                    </div>
                </div>

            <!-- APPROVAL -->
            <?php elseif ($tab === 'approval'): ?>
                <div class="space-y-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h2 class="text-2xl font-bold text-gray-800 mb-4">✅ Genehmigungen</h2>
                        
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                            <div class="p-6 bg-green-50 rounded-lg border-2 border-green-300">
                                <div class="flex items-center justify-between mb-4">
                                    <h3 class="font-bold text-gray-800">✓ HR Genehmigung</h3>
                                    <span class="bg-green-200 text-green-800 px-3 py-1 rounded-full text-sm font-bold">Approved</span>
                                </div>
                                <div class="text-sm text-gray-600 space-y-1">
                                    <p><strong>Genehmigt von:</strong> Petra Müller</p>
                                    <p><strong>Datum:</strong> 15.10.2025</p>
                                    <p><strong>Notiz:</strong> Personalentscheidung positiv</p>
                                </div>
                            </div>

                            <div class="p-6 bg-blue-50 rounded-lg border-2 border-blue-300">
                                <div class="flex items-center justify-between mb-4">
                                    <h3 class="font-bold text-gray-800">⏳ Finanz-Genehmigung</h3>
                                    <span class="bg-yellow-200 text-yellow-800 px-3 py-1 rounded-full text-sm font-bold">Pending</span>
                                </div>
                                <button class="w-full bg-blue-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-blue-700 transition">
                                    🖊️ Jetzt genehmigen
                                </button>
                            </div>

                            <div class="p-6 bg-purple-50 rounded-lg border-2 border-purple-300">
                                <div class="flex items-center justify-between mb-4">
                                    <h3 class="font-bold text-gray-800">⏳ IT-Ausstattung</h3>
                                    <span class="bg-yellow-200 text-yellow-800 px-3 py-1 rounded-full text-sm font-bold">Pending</span>
                                </div>
                                <button class="w-full bg-purple-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-purple-700 transition">
                                    🖊️ Jetzt genehmigen
                                </button>
                            </div>

                            <div class="p-6 bg-orange-50 rounded-lg border-2 border-orange-300">
                                <div class="flex items-center justify-between mb-4">
                                    <h3 class="font-bold text-gray-800">⏳ Arbeitsplatz</h3>
                                    <span class="bg-yellow-200 text-yellow-800 px-3 py-1 rounded-full text-sm font-bold">Pending</span>
                                </div>
                                <button class="w-full bg-orange-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-orange-700 transition">
                                    🖊️ Jetzt genehmigen
                                </button>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">📝 Genehmigungsformular</h3>
                        <form class="space-y-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-2">Bemerkungen</label>
                                <textarea rows="4" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="Ihre Bemerkungen hier..."></textarea>
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

            <!-- TEAM -->
            <?php elseif ($tab === 'team'): ?>
                <div class="space-y-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h2 class="text-2xl font-bold text-gray-800 mb-4">👥 Team-Zuordnung</h2>
                        
                        <div class="space-y-4">
                            <div class="p-4 bg-blue-50 rounded-lg border-l-4 border-blue-600">
                                <div class="flex items-center justify-between">
                                    <div>
                                        <p class="font-semibold text-gray-800">👔 Direkter Manager</p>
                                        <p class="text-sm text-gray-600">Klaus Weber</p>
                                    </div>
                                    <span class="bg-green-100 text-green-800 px-3 py-1 rounded-full text-sm font-bold">✓ Zugewiesen</span>
                                </div>
                            </div>

                            <div class="p-4 bg-green-50 rounded-lg border-l-4 border-green-600">
                                <div class="flex items-center justify-between">
                                    <div>
                                        <p class="font-semibold text-gray-800">👫 Mentor / Buddy</p>
                                        <p class="text-sm text-gray-600">Sarah Müller</p>
                                    </div>
                                    <select class="bg-white border border-gray-300 rounded-lg px-3 py-1 text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-green-500">
                                        <option>Wählen...</option>
                                        <option selected>Sarah Müller</option>
                                        <option>Thomas Schmidt</option>
                                        <option>Eva Fischer</option>
                                    </select>
                                </div>
                            </div>

                            <div class="p-4 bg-purple-50 rounded-lg border-l-4 border-purple-600">
                                <div class="flex items-center justify-between">
                                    <div>
                                        <p class="font-semibold text-gray-800">🎓 Trainer</p>
                                        <p class="text-sm text-gray-600">Für spezialisierte Schulungen</p>
                                    </div>
                                    <select class="bg-white border border-gray-300 rounded-lg px-3 py-1 text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-purple-500">
                                        <option>Wählen...</option>
                                        <option>Marcus Jung</option>
                                        <option>Anna Weber</option>
                                    </select>
                                </div>
                            </div>

                            <div class="p-4 bg-orange-50 rounded-lg border-l-4 border-orange-600">
                                <div class="flex items-center justify-between">
                                    <div>
                                        <p class="font-semibold text-gray-800">🔧 Technical Lead</p>
                                        <p class="text-sm text-gray-600">Für Fachfragen</p>
                                    </div>
                                    <select class="bg-white border border-gray-300 rounded-lg px-3 py-1 text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-orange-500">
                                        <option>Wählen...</option>
                                        <option>Michael Bauer</option>
                                        <option>Lisa König</option>
                                    </select>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

            <!-- BUDGET -->
            <?php elseif ($tab === 'budget'): ?>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">💰 Einstellung Budget</h3>
                        <div class="space-y-4">
                            <div class="p-4 bg-blue-50 rounded-lg">
                                <p class="text-sm text-gray-600">💼 Jahresgehalt</p>
                                <p class="text-2xl font-bold text-gray-800">€ 65.000</p>
                            </div>
                            <div class="p-4 bg-green-50 rounded-lg">
                                <p class="text-sm text-gray-600">🎁 Benefits & Zuschläge</p>
                                <p class="text-2xl font-bold text-gray-800">€ 12.000/Jahr</p>
                            </div>
                            <div class="p-4 bg-purple-50 rounded-lg">
                                <p class="text-sm text-gray-600">📚 Schulung & Entwicklung</p>
                                <p class="text-2xl font-bold text-gray-800">€ 3.000/Jahr</p>
                            </div>
                            <div class="p-4 bg-orange-50 rounded-lg border-2 border-orange-300">
                                <p class="text-sm text-gray-600">💰 Gesamtbudget (1. Jahr)</p>
                                <p class="text-3xl font-bold text-orange-700">€ 80.000</p>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">📊 Budget-Genehmigung</h3>
                        <div class="space-y-4">
                            <div class="p-4 bg-gray-50 rounded-lg">
                                <label class="flex items-center gap-3">
                                    <input type="checkbox" class="w-5 h-5 text-blue-600 rounded">
                                    <span class="font-semibold">Gehalt genehmigt</span>
                                </label>
                            </div>
                            <div class="p-4 bg-gray-50 rounded-lg">
                                <label class="flex items-center gap-3">
                                    <input type="checkbox" class="w-5 h-5 text-blue-600 rounded">
                                    <span class="font-semibold">Benefits freigegeben</span>
                                </label>
                            </div>
                            <div class="p-4 bg-gray-50 rounded-lg">
                                <label class="flex items-center gap-3">
                                    <input type="checkbox" class="w-5 h-5 text-blue-600 rounded">
                                    <span class="font-semibold">Equipment-Budget reserviert</span>
                                </label>
                            </div>
                            <div class="p-4 bg-gray-50 rounded-lg">
                                <label class="flex items-center gap-3">
                                    <input type="checkbox" class="w-5 h-5 text-blue-600 rounded">
                                    <span class="font-semibold">Schulungsbudget genehmigt</span>
                                </label>
                            </div>
                        </div>
                    </div>
                </div>

            <!-- EVALUATION -->
            <?php elseif ($tab === 'evaluation'): ?>
                <div class="bg-white rounded-lg shadow-md p-6">
                    <h2 class="text-2xl font-bold text-gray-800 mb-6">📊 Onboarding Evaluation</h2>
                    
                    <div class="space-y-6">
                        <div>
                            <h3 class="font-bold text-gray-800 mb-3">Week 1-2: Erste Schritte</h3>
                            <div class="space-y-2">
                                <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                    <span>Willkommensgespräch durchgeführt</span>
                                </label>
                                <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                    <span>Arbeitsplatz eingerichtet</span>
                                </label>
                                <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                    <span>Team-Kennenlernen organisiert</span>
                                </label>
                            </div>
                        </div>

                        <div class="border-t pt-6">
                            <h3 class="font-bold text-gray-800 mb-3">Week 3-4: Produktive Phase</h3>
                            <div class="space-y-2">
                                <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                    <span>Erste Aufgaben zugewiesen</span>
                                </label>
                                <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                    <span>Fortschritt mit Mentor besprochen</span>
                                </label>
                                <label class="flex items-center gap-3 p-3 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                    <span>1. Check-in Gespräch</span>
                                </label>
                            </div>
                        </div>

                        <div class="border-t pt-6">
                            <h3 class="font-bold text-gray-800 mb-3">Feedback vom Manager</h3>
                            <textarea rows="5" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="Wie läuft das Onboarding? Besonderheiten?"></textarea>
                        </div>

                        <button class="w-full bg-blue-600 text-white font-semibold py-2 px-4 rounded-lg hover:bg-blue-700 transition">
                            💾 Feedback speichern
                        </button>
                    </div>
                </div>

            <?php endif; ?>
        </main>
    </div>
</body>
</html>
