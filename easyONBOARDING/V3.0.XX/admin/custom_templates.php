<?php
/**
 * Custom Templates & Branding Manager - Phase 7
 * Verwaltung von E-Mail-Vorlagen, PDF-Layouts & Corporate Branding
 */

require_once '../config.php';
redirectIfNotAdmin();

$tab = $_GET['tab'] ?? 'branding';
$template_id = $_GET['template'] ?? null;

// AJAX: Branding speichern
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $action = $_POST['action'];
    
    if ($action === 'save_branding') {
        $branding = [
            'company_name' => $_POST['company_name'],
            'company_logo' => $_POST['company_logo'],
            'primary_color' => $_POST['primary_color'],
            'secondary_color' => $_POST['secondary_color'],
            'accent_color' => $_POST['accent_color'],
            'footer_text' => $_POST['footer_text'],
            'support_email' => $_POST['support_email'],
            'phone' => $_POST['phone'],
            'website' => $_POST['website'],
        ];
        
        file_put_contents('config/branding.json', json_encode($branding, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        logAction($_SESSION['user_id'], 'branding_updated', 'System branding updated');
        echo json_encode(['success' => true]);
        exit;
    }
    
    if ($action === 'save_template') {
        $template = [
            'id' => $_POST['template_id'],
            'name' => $_POST['template_name'],
            'subject' => $_POST['template_subject'],
            'body_html' => $_POST['template_body_html'],
            'body_text' => $_POST['template_body_text'],
            'variables' => explode(',', $_POST['template_variables']),
            'enabled' => isset($_POST['template_enabled']),
        ];
        
        $templates = json_decode(file_get_contents('config/email_templates.json'), true) ?? [];
        $key = array_search($_POST['template_id'], array_column($templates, 'id'));
        
        if ($key !== false) {
            $templates[$key] = $template;
        } else {
            $templates[] = $template;
        }
        
        file_put_contents('config/email_templates.json', json_encode($templates, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        logAction($_SESSION['user_id'], 'template_updated', "Template {$_POST['template_id']} updated");
        echo json_encode(['success' => true]);
        exit;
    }
    
    if ($action === 'preview_template') {
        $template = json_decode($_POST['template_body_html'], true);
        $variables = [
            '{EMPLOYEE_NAME}' => 'Max Mustermann',
            '{START_DATE}' => date('d.m.Y'),
            '{POSITION}' => 'Senior Developer',
            '{DEPARTMENT}' => 'IT',
            '{USERNAME}' => 'mmustermann',
            '{PASSWORD}' => '••••••••',
            '{COMPANY_NAME}' => 'Meine Firma',
        ];
        
        $preview = $_POST['template_body_html'];
        foreach ($variables as $var => $val) {
            $preview = str_replace($var, $val, $preview);
        }
        
        echo json_encode(['preview' => $preview]);
        exit;
    }
}

// Branding laden
$branding = json_decode(file_get_contents('config/branding.json'), true) ?? [
    'company_name' => 'easyONBOARDING',
    'primary_color' => '#3b82f6',
    'secondary_color' => '#10b981',
];

// Templates laden
$templates = json_decode(file_get_contents('config/email_templates.json'), true) ?? [];
$currentTemplate = null;
if ($template_id) {
    $key = array_search($template_id, array_column($templates, 'id'));
    if ($key !== false) {
        $currentTemplate = $templates[$key];
    }
}

?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Custom Templates & Branding</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
</head>
<body class="bg-gray-50">
    <div class="flex">
        <!-- Sidebar Nav -->
        <div class="w-64 bg-white shadow-lg h-screen">
            <div class="p-6">
                <h2 class="text-xl font-bold mb-6">⚙️ Customization</h2>
                <nav class="space-y-2">
                    <a href="?tab=branding" class="block p-3 rounded-lg <?= $tab === 'branding' ? 'bg-blue-100 text-blue-700 font-bold' : 'text-gray-700 hover:bg-gray-100' ?>">
                        🎨 Branding
                    </a>
                    <a href="?tab=templates" class="block p-3 rounded-lg <?= $tab === 'templates' ? 'bg-blue-100 text-blue-700 font-bold' : 'text-gray-700 hover:bg-gray-100' ?>">
                        📧 Email-Vorlagen
                    </a>
                    <a href="?tab=pdf" class="block p-3 rounded-lg <?= $tab === 'pdf' ? 'bg-blue-100 text-blue-700 font-bold' : 'text-gray-700 hover:bg-gray-100' ?>">
                        📄 PDF-Layout
                    </a>
                </nav>
            </div>
        </div>

        <!-- Main Content -->
        <div class="flex-1">
            <div class="p-8">
                <?php if ($tab === 'branding'): ?>
                <!-- Branding Tab -->
                <div class="max-w-2xl bg-white rounded-lg shadow-lg p-8">
                    <h1 class="text-3xl font-bold mb-6">🎨 Corporate Branding</h1>
                    
                    <form onsubmit="saveBranding(event)" class="space-y-6">
                        <div class="grid grid-cols-2 gap-6">
                            <div>
                                <label class="block text-sm font-semibold mb-2">Firmenname</label>
                                <input type="text" name="company_name" value="<?= htmlspecialchars($branding['company_name'] ?? '') ?>" 
                                    class="w-full px-4 py-2 border rounded-lg" required />
                            </div>
                            <div>
                                <label class="block text-sm font-semibold mb-2">Logo URL</label>
                                <input type="url" name="company_logo" value="<?= htmlspecialchars($branding['company_logo'] ?? '') ?>" 
                                    class="w-full px-4 py-2 border rounded-lg" />
                            </div>
                        </div>

                        <div class="grid grid-cols-3 gap-6">
                            <div>
                                <label class="block text-sm font-semibold mb-2">Primär-Farbe</label>
                                <div class="flex gap-2">
                                    <input type="color" name="primary_color" value="<?= htmlspecialchars($branding['primary_color'] ?? '#3b82f6') ?>" 
                                        class="w-16 h-10 rounded cursor-pointer" />
                                    <input type="text" value="<?= htmlspecialchars($branding['primary_color'] ?? '#3b82f6') ?>" 
                                        class="flex-1 px-4 py-2 border rounded-lg text-xs font-mono" readonly />
                                </div>
                            </div>
                            <div>
                                <label class="block text-sm font-semibold mb-2">Sekundär-Farbe</label>
                                <div class="flex gap-2">
                                    <input type="color" name="secondary_color" value="<?= htmlspecialchars($branding['secondary_color'] ?? '#10b981') ?>" 
                                        class="w-16 h-10 rounded cursor-pointer" />
                                    <input type="text" value="<?= htmlspecialchars($branding['secondary_color'] ?? '#10b981') ?>" 
                                        class="flex-1 px-4 py-2 border rounded-lg text-xs font-mono" readonly />
                                </div>
                            </div>
                            <div>
                                <label class="block text-sm font-semibold mb-2">Akzent-Farbe</label>
                                <div class="flex gap-2">
                                    <input type="color" name="accent_color" value="<?= htmlspecialchars($branding['accent_color'] ?? '#f59e0b') ?>" 
                                        class="w-16 h-10 rounded cursor-pointer" />
                                    <input type="text" value="<?= htmlspecialchars($branding['accent_color'] ?? '#f59e0b') ?>" 
                                        class="flex-1 px-4 py-2 border rounded-lg text-xs font-mono" readonly />
                                </div>
                            </div>
                        </div>

                        <div>
                            <label class="block text-sm font-semibold mb-2">Footer Text</label>
                            <textarea name="footer_text" class="w-full px-4 py-2 border rounded-lg h-20"><?= htmlspecialchars($branding['footer_text'] ?? '') ?></textarea>
                        </div>

                        <div class="grid grid-cols-3 gap-6">
                            <div>
                                <label class="block text-sm font-semibold mb-2">Support E-Mail</label>
                                <input type="email" name="support_email" value="<?= htmlspecialchars($branding['support_email'] ?? '') ?>" 
                                    class="w-full px-4 py-2 border rounded-lg" />
                            </div>
                            <div>
                                <label class="block text-sm font-semibold mb-2">Telefon</label>
                                <input type="tel" name="phone" value="<?= htmlspecialchars($branding['phone'] ?? '') ?>" 
                                    class="w-full px-4 py-2 border rounded-lg" />
                            </div>
                            <div>
                                <label class="block text-sm font-semibold mb-2">Website</label>
                                <input type="url" name="website" value="<?= htmlspecialchars($branding['website'] ?? '') ?>" 
                                    class="w-full px-4 py-2 border rounded-lg" />
                            </div>
                        </div>

                        <button type="submit" class="w-full bg-blue-500 hover:bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold transition">
                            💾 Branding speichern
                        </button>
                    </form>

                    <!-- Preview -->
                    <div class="mt-12 p-8 border-2 border-dashed rounded-lg" style="background-color: <?= htmlspecialchars($branding['primary_color'] ?? '#3b82f6') ?>20">
                        <div class="text-center">
                            <h3 class="text-2xl font-bold" style="color: <?= htmlspecialchars($branding['primary_color'] ?? '#3b82f6') ?>">
                                <?= htmlspecialchars($branding['company_name'] ?? 'easyONBOARDING') ?>
                            </h3>
                            <p class="mt-4 text-gray-600">Vorschau der Branding-Einstellungen</p>
                        </div>
                    </div>
                </div>

                <?php elseif ($tab === 'templates'): ?>
                <!-- Email Templates Tab -->
                <div class="max-w-4xl bg-white rounded-lg shadow-lg p-8">
                    <h1 class="text-3xl font-bold mb-6">📧 Email-Vorlagen</h1>

                    <div class="grid grid-cols-2 gap-6 mb-8">
                        <div>
                            <h3 class="font-bold mb-4">Verfügbare Vorlagen</h3>
                            <div class="space-y-2">
                                <?php 
                                $default_templates = [
                                    'welcome' => '👋 Willkommensnachricht',
                                    'credentials' => '🔐 Zugangsdaten',
                                    'reminder' => '⏰ Erinnerung',
                                    'completion' => '✅ Abschluss',
                                ];
                                foreach ($default_templates as $id => $name): 
                                ?>
                                <button onclick="selectTemplate('<?= $id ?>')" 
                                    class="block w-full text-left p-3 rounded-lg hover:bg-blue-50 border">
                                    <?= $name ?>
                                </button>
                                <?php endforeach; ?>
                            </div>
                        </div>

                        <div id="template-editor">
                            <?php if ($currentTemplate): ?>
                            <form onsubmit="saveTemplate(event)">
                                <input type="hidden" name="action" value="save_template">
                                <input type="hidden" name="template_id" value="<?= htmlspecialchars($currentTemplate['id']) ?>">
                                
                                <div class="mb-4">
                                    <label class="block text-sm font-semibold mb-2">Template Name</label>
                                    <input type="text" name="template_name" value="<?= htmlspecialchars($currentTemplate['name']) ?>" 
                                        class="w-full px-3 py-2 border rounded-lg" />
                                </div>

                                <div class="mb-4">
                                    <label class="block text-sm font-semibold mb-2">Betreff</label>
                                    <input type="text" name="template_subject" value="<?= htmlspecialchars($currentTemplate['subject']) ?>" 
                                        class="w-full px-3 py-2 border rounded-lg" />
                                </div>

                                <div class="mb-4">
                                    <label class="block text-sm font-semibold mb-2">HTML Body</label>
                                    <textarea name="template_body_html" class="w-full px-3 py-2 border rounded-lg h-32 font-mono text-xs"><?= htmlspecialchars($currentTemplate['body_html'] ?? '') ?></textarea>
                                </div>

                                <div class="mb-4">
                                    <label class="block text-sm font-semibold mb-2">Text Body</label>
                                    <textarea name="template_body_text" class="w-full px-3 py-2 border rounded-lg h-32 font-mono text-xs"><?= htmlspecialchars($currentTemplate['body_text'] ?? '') ?></textarea>
                                </div>

                                <div class="mb-4">
                                    <label class="block text-sm font-semibold mb-2">Variables (komma-getrennt)</label>
                                    <input type="text" name="template_variables" value="<?= implode(',', $currentTemplate['variables'] ?? []) ?>" 
                                        class="w-full px-3 py-2 border rounded-lg text-xs" />
                                </div>

                                <button type="submit" class="w-full bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg transition">
                                    💾 Speichern
                                </button>
                            </form>
                            <?php else: ?>
                            <p class="text-gray-500">Wählen Sie eine Vorlage aus</p>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>

                <?php elseif ($tab === 'pdf'): ?>
                <!-- PDF Layout Tab -->
                <div class="max-w-2xl bg-white rounded-lg shadow-lg p-8">
                    <h1 class="text-3xl font-bold mb-6">📄 PDF-Layout Konfiguration</h1>
                    
                    <form class="space-y-6">
                        <div>
                            <label class="block text-sm font-semibold mb-2">Kopfzeile</label>
                            <textarea class="w-full px-4 py-2 border rounded-lg h-20" placeholder="HTML für PDF Kopfzeile"></textarea>
                        </div>

                        <div>
                            <label class="block text-sm font-semibold mb-2">Fußzeile</label>
                            <textarea class="w-full px-4 py-2 border rounded-lg h-20" placeholder="HTML für PDF Fußzeile"></textarea>
                        </div>

                        <div class="grid grid-cols-2 gap-6">
                            <div>
                                <label class="block text-sm font-semibold mb-2">Papierformat</label>
                                <select class="w-full px-4 py-2 border rounded-lg">
                                    <option value="A4">A4</option>
                                    <option value="A3">A3</option>
                                    <option value="Letter">Letter</option>
                                </select>
                            </div>
                            <div>
                                <label class="block text-sm font-semibold mb-2">Ausrichtung</label>
                                <select class="w-full px-4 py-2 border rounded-lg">
                                    <option value="portrait">Hochformat</option>
                                    <option value="landscape">Querformat</option>
                                </select>
                            </div>
                        </div>

                        <button class="w-full bg-blue-500 hover:bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold transition">
                            💾 PDF-Layout speichern
                        </button>
                    </form>
                </div>
                <?php endif; ?>
            </div>
        </div>
    </div>

    <script>
        function saveBranding(e) {
            e.preventDefault();
            const formData = new FormData(e.target);
            formData.append('action', 'save_branding');

            fetch(window.location.pathname + '?tab=branding', { method: 'POST', body: formData })
                .then(r => r.json())
                .then(d => alert(d.success ? '✅ Branding gespeichert!' : '❌ Fehler'));
        }

        function selectTemplate(id) {
            location.href = '?tab=templates&template=' + id;
        }

        function saveTemplate(e) {
            e.preventDefault();
            const formData = new FormData(e.target);

            fetch(window.location.pathname + '?tab=templates', { method: 'POST', body: formData })
                .then(r => r.json())
                .then(d => alert(d.success ? '✅ Template gespeichert!' : '❌ Fehler'));
        }
    </script>
</body>
</html>
?>
