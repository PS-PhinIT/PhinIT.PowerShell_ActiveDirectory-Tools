<?php
/**
 * HR Sektion - Spezifische Informationen für HR
 * Enthält: Dokumentation, Checklisten, Verträge, etc.
 */

require_once '../config.php';
redirectIfNotLoggedIn();

// Nur für HR, Abteilungsleiter und Admin
if (!in_array($_SESSION['role'], ['HR', 'Abteilungsleiter', 'Admin'])) {
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
    <title>HR Bereich - <?php echo SITE_NAME; ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
</head>
<body class="bg-gray-50 font-sans">
    <div class="min-h-screen">
        <!-- Header -->
        <div class="bg-gradient-to-r from-purple-600 to-pink-600 text-white shadow-lg">
            <div class="max-w-7xl mx-auto px-6 py-6">
                <div class="flex items-center justify-between">
                    <div>
                        <h1 class="text-3xl font-bold">👥 HR Bereich</h1>
                        <p class="text-purple-100 mt-1">Fall #<?php echo htmlspecialchars($case['case_number']); ?> - <?php echo htmlspecialchars($case['employee_first_name'] . ' ' . $case['employee_last_name']); ?></p>
                    </div>
                    <a href="../index.php" class="bg-white text-purple-600 px-4 py-2 rounded-lg font-semibold hover:bg-purple-50 transition">← Zurück</a>
                </div>
            </div>
        </div>

        <!-- Tabs -->
        <div class="border-b border-gray-200 bg-white sticky top-0 z-10">
            <div class="max-w-7xl mx-auto px-6">
                <div class="flex space-x-8">
                    <a href="?case_id=<?php echo $caseId; ?>&tab=overview" 
                       class="py-4 px-2 border-b-2 font-semibold <?php echo $tab === 'overview' ? 'border-purple-600 text-purple-600' : 'border-transparent text-gray-600 hover:text-gray-800'; ?>">
                        📋 Übersicht
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=checklist" 
                       class="py-4 px-2 border-b-2 font-semibold <?php echo $tab === 'checklist' ? 'border-purple-600 text-purple-600' : 'border-transparent text-gray-600 hover:text-gray-800'; ?>">
                        ✅ Checkliste
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=documents" 
                       class="py-4 px-2 border-b-2 font-semibold <?php echo $tab === 'documents' ? 'border-purple-600 text-purple-600' : 'border-transparent text-gray-600 hover:text-gray-800'; ?>">
                        📄 Dokumente
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=benefits" 
                       class="py-4 px-2 border-b-2 font-semibold <?php echo $tab === 'benefits' ? 'border-purple-600 text-purple-600' : 'border-transparent text-gray-600 hover:text-gray-800'; ?>">
                        💼 Benefits
                    </a>
                    <a href="?case_id=<?php echo $caseId; ?>&tab=contacts" 
                       class="py-4 px-2 border-b-2 font-semibold <?php echo $tab === 'contacts' ? 'border-purple-600 text-purple-600' : 'border-transparent text-gray-600 hover:text-gray-800'; ?>">
                        📞 Kontakte
                    </a>
                </div>
            </div>
        </div>

        <!-- Content -->
        <main class="max-w-7xl mx-auto px-6 py-8">

            <!-- OVERVIEW TAB -->
            <?php if ($tab === 'overview'): ?>
                <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    <!-- Mitarbeiter Info -->
                    <div class="lg:col-span-2">
                        <div class="bg-white rounded-lg shadow-md p-6 mb-6">
                            <h2 class="text-2xl font-bold text-gray-800 mb-4">👤 Mitarbeiter-Information</h2>
                            <div class="grid grid-cols-2 gap-4">
                                <div>
                                    <p class="text-sm text-gray-600">Vorname</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['employee_first_name']); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">Nachname</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['employee_last_name']); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">Email</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['employee_email']); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">Abteilung</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['department']); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">Position</p>
                                    <p class="font-semibold text-gray-800"><?php echo htmlspecialchars($case['job_title'] ?? 'Nicht spezifiziert'); ?></p>
                                </div>
                                <div>
                                    <p class="text-sm text-gray-600">Startdatum</p>
                                    <p class="font-semibold text-gray-800"><?php echo date('d.m.Y', strtotime($case['start_date'] ?? 'now')); ?></p>
                                </div>
                            </div>
                        </div>

                        <!-- HR-Aufgaben -->
                        <div class="bg-white rounded-lg shadow-md p-6">
                            <h2 class="text-2xl font-bold text-gray-800 mb-4">🎯 HR-Aufgaben</h2>
                            <div class="space-y-3">
                                <div class="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-blue-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Arbeitsvertrag vorbereitet</p>
                                        <p class="text-sm text-gray-600">Vertrag ausgedruckt und zur Unterschrift vorbereitet</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-blue-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Versicherungsunterlagen eingereicht</p>
                                        <p class="text-sm text-gray-600">Krankenkasse und Rentenbeitrag angemeldet</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-blue-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Steuerkarte / ELSTER angemeldet</p>
                                        <p class="text-sm text-gray-600">Lohnsteuer-Anmeldung durchgeführt</p>
                                    </div>
                                </div>
                                <div class="flex items-start gap-3 p-4 bg-blue-50 rounded-lg">
                                    <input type="checkbox" class="mt-1 w-5 h-5 text-blue-600 rounded">
                                    <div>
                                        <p class="font-semibold text-gray-800">Betriebsrat Notification</p>
                                        <p class="text-sm text-gray-600">Betriebsrat informiert, falls vorhanden</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Schnelllinks -->
                    <div>
                        <div class="bg-white rounded-lg shadow-md p-6 sticky top-24">
                            <h3 class="font-bold text-gray-800 mb-4">🔗 Schnelllinks</h3>
                            <div class="space-y-2">
                                <a href="#documents" class="block p-3 bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg hover:shadow-md transition text-purple-700 font-semibold">
                                    📄 Verträge & Dokumente
                                </a>
                                <a href="#contacts" class="block p-3 bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg hover:shadow-md transition text-purple-700 font-semibold">
                                    📞 HR-Kontakte
                                </a>
                                <a href="#benefits" class="block p-3 bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg hover:shadow-md transition text-purple-700 font-semibold">
                                    💼 Benefits & Versicherung
                                </a>
                            </div>
                        </div>
                    </div>
                </div>

            <!-- CHECKLIST TAB -->
            <?php elseif ($tab === 'checklist'): ?>
                <div class="bg-white rounded-lg shadow-md p-6">
                    <h2 class="text-2xl font-bold text-gray-800 mb-6">✅ Onboarding Checkliste (HR)</h2>
                    
                    <div class="space-y-6">
                        <!-- Verträge & Administration -->
                        <div class="border-l-4 border-purple-600 pl-4">
                            <h3 class="text-xl font-semibold text-gray-800 mb-3">📋 Verträge & Administration</h3>
                            <div class="space-y-2 ml-4">
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-purple-600 rounded">
                                    <span>Arbeitsvertrag ausgefüllt & unterzeichnet</span>
                                </label>
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-purple-600 rounded">
                                    <span>Datenschutzerklärung unterzeichnet</span>
                                </label>
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-purple-600 rounded">
                                    <span>Arbeitszeitmodell festgelegt</span>
                                </label>
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-purple-600 rounded">
                                    <span>Bankverbindung für Gehaltszahlung erfasst</span>
                                </label>
                            </div>
                        </div>

                        <!-- Soziale Versicherung -->
                        <div class="border-l-4 border-green-600 pl-4">
                            <h3 class="text-xl font-semibold text-gray-800 mb-3">🏥 Soziale Versicherung</h3>
                            <div class="space-y-2 ml-4">
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                    <span>Krankenkasse angemeldet</span>
                                </label>
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                    <span>Rentenversicherung angemeldet</span>
                                </label>
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                    <span>Arbeitslosenversicherung registriert</span>
                                </label>
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-green-600 rounded">
                                    <span>Unfallversicherung angemeldet</span>
                                </label>
                            </div>
                        </div>

                        <!-- Steuern -->
                        <div class="border-l-4 border-blue-600 pl-4">
                            <h3 class="text-xl font-semibold text-gray-800 mb-3">💰 Steuern & Finanzen</h3>
                            <div class="space-y-2 ml-4">
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-blue-600 rounded">
                                    <span>Lohnsteuerkarte / Elster-Anmeldung</span>
                                </label>
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-blue-600 rounded">
                                    <span>Steuer-ID geprüft</span>
                                </label>
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-blue-600 rounded">
                                    <span>Kirchensteuer geklärt</span>
                                </label>
                            </div>
                        </div>

                        <!-- Personal -->
                        <div class="border-l-4 border-orange-600 pl-4">
                            <h3 class="text-xl font-semibold text-gray-800 mb-3">👥 Personelles</h3>
                            <div class="space-y-2 ml-4">
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-orange-600 rounded">
                                    <span>Personalakte angelegt</span>
                                </label>
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-orange-600 rounded">
                                    <span>Betriebsrat / Personalrat benachrichtigt</span>
                                </label>
                                <label class="flex items-center gap-3 p-2 hover:bg-gray-50 rounded">
                                    <input type="checkbox" class="w-5 h-5 text-orange-600 rounded">
                                    <span>Probezeit in System eingetragen</span>
                                </label>
                            </div>
                        </div>
                    </div>
                </div>

            <!-- DOCUMENTS TAB -->
            <?php elseif ($tab === 'documents'): ?>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">📄 Verträge & Vorlagen</h3>
                        <div class="space-y-3">
                            <a href="#" class="block p-3 bg-red-50 border border-red-200 rounded-lg hover:shadow-md transition">
                                <p class="font-semibold text-red-700">📝 Arbeitsvertrag (PDF)</p>
                                <p class="text-sm text-gray-600">Standart Vollzeit / Teilzeit Arbeitsvertrag</p>
                            </a>
                            <a href="#" class="block p-3 bg-blue-50 border border-blue-200 rounded-lg hover:shadow-md transition">
                                <p class="font-semibold text-blue-700">📋 Datenschutz-Erklärung (PDF)</p>
                                <p class="text-sm text-gray-600">DSGVO-konform Datenschutz</p>
                            </a>
                            <a href="#" class="block p-3 bg-green-50 border border-green-200 rounded-lg hover:shadow-md transition">
                                <p class="font-semibold text-green-700">⚖️ Betriebsvereinbarung (PDF)</p>
                                <p class="text-sm text-gray-600">Verschwiegenheit & Code of Conduct</p>
                            </a>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">🏥 Versicherung & Administration</h3>
                        <div class="space-y-3">
                            <a href="#" class="block p-3 bg-purple-50 border border-purple-200 rounded-lg hover:shadow-md transition">
                                <p class="font-semibold text-purple-700">🏥 Versicherungs-Formular</p>
                                <p class="text-sm text-gray-600">Krankenkasse, Rentenbeitrag</p>
                            </a>
                            <a href="#" class="block p-3 bg-yellow-50 border border-yellow-200 rounded-lg hover:shadow-md transition">
                                <p class="font-semibold text-yellow-700">💳 Bankverbindung-Formular</p>
                                <p class="text-sm text-gray-600">IBAN/BIC für Gehaltsüberweisung</p>
                            </a>
                            <a href="#" class="block p-3 bg-indigo-50 border border-indigo-200 rounded-lg hover:shadow-md transition">
                                <p class="font-semibold text-indigo-700">📋 Steuer-ID Bestätigung</p>
                                <p class="text-sm text-gray-600">Für Lohnsteuer-Anmeldung</p>
                            </a>
                        </div>
                    </div>
                </div>

            <!-- BENEFITS TAB -->
            <?php elseif ($tab === 'benefits'): ?>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">💼 Unternehmens-Benefits</h3>
                        <div class="space-y-3">
                            <div class="p-4 bg-green-50 rounded-lg border-l-4 border-green-600">
                                <p class="font-semibold text-gray-800">🚗 Firmenwagen</p>
                                <p class="text-sm text-gray-600">Mercedes E-Klasse oder BMW 3er je nach Position</p>
                            </div>
                            <div class="p-4 bg-blue-50 rounded-lg border-l-4 border-blue-600">
                                <p class="font-semibold text-gray-800">📱 Firmentelefon</p>
                                <p class="text-sm text-gray-600">iPhone oder Samsung Galaxy, Flatrate inklusive</p>
                            </div>
                            <div class="p-4 bg-purple-50 rounded-lg border-l-4 border-purple-600">
                                <p class="font-semibold text-gray-800">💻 Arbeitsplatz</p>
                                <p class="text-sm text-gray-600">Top-Ausstattung mit Monitor, Tastatur, Maus</p>
                            </div>
                            <div class="p-4 bg-orange-50 rounded-lg border-l-4 border-orange-600">
                                <p class="font-semibold text-gray-800">🏃 Fitness</p>
                                <p class="text-sm text-gray-600">Kostenloser Zugang zu Fitness-Studios</p>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">🎁 Zusatzleistungen</h3>
                        <div class="space-y-3">
                            <div class="p-4 bg-pink-50 rounded-lg border-l-4 border-pink-600">
                                <p class="font-semibold text-gray-800">🏥 Krankenversicherung</p>
                                <p class="text-sm text-gray-600">100% Übernahme von AG + AN Beitrag</p>
                            </div>
                            <div class="p-4 bg-red-50 rounded-lg border-l-4 border-red-600">
                                <p class="font-semibold text-gray-800">🎄 Weihnachtsbonund</p>
                                <p class="text-sm text-gray-600">1-2 Monatsgehalt als Weihnachtsgrat</p>
                            </div>
                            <div class="p-4 bg-cyan-50 rounded-lg border-l-4 border-cyan-600">
                                <p class="font-semibold text-gray-800">🏖️ Urlaubstage</p>
                                <p class="text-sm text-gray-600">30 Tage pro Jahr (über Gesetz hinaus)</p>
                            </div>
                            <div class="p-4 bg-lime-50 rounded-lg border-l-4 border-lime-600">
                                <p class="font-semibold text-gray-800">📚 Weiterbildung</p>
                                <p class="text-sm text-gray-600">€2.000 pro Jahr für Fortbildungen</p>
                            </div>
                        </div>
                    </div>
                </div>

            <!-- CONTACTS TAB -->
            <?php elseif ($tab === 'contacts'): ?>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">👥 HR-Team</h3>
                        <div class="space-y-4">
                            <div class="p-4 bg-purple-50 rounded-lg">
                                <p class="font-semibold text-gray-800">📞 HR Manager</p>
                                <p class="text-sm text-gray-600">Petra Müller</p>
                                <p class="text-sm"><a href="tel:+49301234567" class="text-purple-600 hover:underline">+49 30 123456-7</a></p>
                                <p class="text-sm"><a href="mailto:petra.mueller@company.de" class="text-purple-600 hover:underline">petra.mueller@company.de</a></p>
                            </div>
                            <div class="p-4 bg-pink-50 rounded-lg">
                                <p class="font-semibold text-gray-800">📞 HR Assistentin</p>
                                <p class="text-sm text-gray-600">Anna Schmidt</p>
                                <p class="text-sm"><a href="tel:+49301234568" class="text-pink-600 hover:underline">+49 30 123456-8</a></p>
                                <p class="text-sm"><a href="mailto:anna.schmidt@company.de" class="text-pink-600 hover:underline">anna.schmidt@company.de</a></p>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white rounded-lg shadow-md p-6">
                        <h3 class="text-lg font-bold text-gray-800 mb-4">🏢 Wichtige Kontakte</h3>
                        <div class="space-y-4">
                            <div class="p-4 bg-blue-50 rounded-lg">
                                <p class="font-semibold text-gray-800">🏥 Betriebsarzt</p>
                                <p class="text-sm text-gray-600">Dr. Klaus Wagner</p>
                                <p class="text-sm"><a href="tel:+49301234500" class="text-blue-600 hover:underline">+49 30 123456-0</a></p>
                            </div>
                            <div class="p-4 bg-green-50 rounded-lg">
                                <p class="font-semibold text-gray-800">🛡️ Datenschutz</p>
                                <p class="text-sm text-gray-600">Datenschutzbeauftragter</p>
                                <p class="text-sm"><a href="mailto:datenschutz@company.de" class="text-green-600 hover:underline">datenschutz@company.de</a></p>
                            </div>
                            <div class="p-4 bg-orange-50 rounded-lg">
                                <p class="font-semibold text-gray-800">🚨 Sicherheit</p>
                                <p class="text-sm text-gray-600">Brandschutzbeauftragter</p>
                                <p class="text-sm"><a href="tel:+49301234542" class="text-orange-600 hover:underline">+49 30 123456-42</a></p>
                            </div>
                        </div>
                    </div>
                </div>

            <?php endif; ?>
        </main>
    </div>
</body>
</html>
