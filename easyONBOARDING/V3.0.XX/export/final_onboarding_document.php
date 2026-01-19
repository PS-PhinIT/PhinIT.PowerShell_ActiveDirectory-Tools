<?php
/**
 * Finales Onboarding-Dokument
 * Zusammenfassung aller Informationen für den neuen Mitarbeiter
 * Kann als PDF gedruckt/exportiert werden
 */

require_once '../config.php';
redirectIfNotLoggedIn();

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

// Generiertes Passwort dekodieren (Demo)
$generatedPassword = $case['generated_password'] ?? substr(md5(uniqid()), 0, 12);
$generatedUsername = $case['generated_username'] ?? strtolower($case['employee_first_name']) . '.' . strtolower($case['employee_last_name']);
$generatedEmail = $case['generated_email'] ?? $generatedUsername . '@company.local';

// PDF Export möglich machen
$exportPdf = isset($_GET['pdf']);

if ($exportPdf) {
    header('Content-Type: application/pdf');
    header('Content-Disposition: attachment; filename="Onboarding_' . $case['case_number'] . '.pdf"');
}
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Onboarding-Dokument - <?php echo htmlspecialchars($case['employee_first_name']); ?></title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
        }
        .container {
            max-width: 210mm;
            height: 297mm;
            margin: 20px auto;
            background: white;
            padding: 40px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
            page-break-after: always;
        }
        .header {
            border-bottom: 3px solid #2563eb;
            margin-bottom: 30px;
            padding-bottom: 20px;
        }
        .header h1 {
            color: #2563eb;
            font-size: 32px;
            margin-bottom: 5px;
        }
        .header p {
            color: #666;
            font-size: 14px;
        }
        .employee-info {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 30px;
            background: #f9fafb;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #2563eb;
        }
        .info-field {
            margin-bottom: 12px;
        }
        .info-label {
            font-weight: 600;
            color: #666;
            font-size: 12px;
            text-transform: uppercase;
            margin-bottom: 4px;
        }
        .info-value {
            font-size: 16px;
            color: #222;
        }
        .section {
            margin-bottom: 30px;
        }
        .section-title {
            font-size: 20px;
            font-weight: 700;
            color: #2563eb;
            margin-bottom: 15px;
            padding-bottom: 8px;
            border-bottom: 2px solid #ddd;
        }
        .credentials {
            background: #fffbeb;
            border-left: 4px solid #f59e0b;
            padding: 15px;
            border-radius: 6px;
            margin-bottom: 15px;
        }
        .credentials-warning {
            background: #fee2e2;
            color: #991b1b;
            padding: 10px;
            border-radius: 4px;
            font-size: 12px;
            margin-bottom: 10px;
            font-weight: 600;
        }
        .credential-field {
            margin-bottom: 10px;
            font-size: 14px;
        }
        .credential-label {
            font-weight: 600;
            color: #666;
            display: inline-block;
            width: 150px;
        }
        .credential-value {
            font-family: 'Courier New', monospace;
            background: white;
            padding: 4px 8px;
            border-radius: 3px;
            border: 1px solid #d1d5db;
        }
        .checklist {
            list-style: none;
            padding: 0;
        }
        .checklist li {
            padding: 10px 0;
            padding-left: 30px;
            position: relative;
            font-size: 14px;
            border-bottom: 1px solid #eee;
        }
        .checklist li:before {
            content: "☐";
            position: absolute;
            left: 0;
            font-size: 18px;
            color: #2563eb;
        }
        .checklist li.completed:before {
            content: "☑";
            color: #10b981;
        }
        .contacts {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
        }
        .contact-card {
            background: #f3f4f6;
            padding: 15px;
            border-radius: 6px;
            border-left: 3px solid #2563eb;
        }
        .contact-name {
            font-weight: 600;
            color: #222;
            margin-bottom: 4px;
        }
        .contact-role {
            font-size: 12px;
            color: #666;
            margin-bottom: 6px;
        }
        .contact-info {
            font-size: 12px;
            color: #555;
        }
        .timeline {
            margin-top: 15px;
        }
        .timeline-item {
            display: flex;
            margin-bottom: 15px;
            position: relative;
            padding-left: 30px;
        }
        .timeline-item:before {
            content: "";
            position: absolute;
            left: 0;
            top: 5px;
            width: 12px;
            height: 12px;
            background: #2563eb;
            border-radius: 50%;
            border: 2px solid white;
        }
        .timeline-item:after {
            content: "";
            position: absolute;
            left: 5px;
            top: 17px;
            width: 2px;
            height: 15px;
            background: #d1d5db;
        }
        .timeline-item:last-child:after {
            display: none;
        }
        .timeline-date {
            font-weight: 600;
            color: #2563eb;
            min-width: 80px;
        }
        .timeline-text {
            color: #666;
            font-size: 14px;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 2px solid #d1d5db;
            text-align: center;
            font-size: 12px;
            color: #999;
        }
        .page-break {
            page-break-after: always;
            margin: 20px 0;
        }
        @media print {
            body {
                background: white;
            }
            .container {
                margin: 0;
                box-shadow: none;
                padding: 20mm;
                max-width: 100%;
            }
            .no-print {
                display: none;
            }
        }
        .header-actions {
            margin-bottom: 20px;
            display: flex;
            gap: 10px;
            justify-content: flex-end;
        }
        .btn {
            padding: 10px 20px;
            border-radius: 6px;
            border: none;
            font-weight: 600;
            cursor: pointer;
            font-size: 14px;
        }
        .btn-primary {
            background: #2563eb;
            color: white;
        }
        .btn-primary:hover {
            background: #1d4ed8;
        }
        .btn-secondary {
            background: #e5e7eb;
            color: #222;
        }
        .btn-secondary:hover {
            background: #d1d5db;
        }
        .highlight {
            background: #fef3c7;
            padding: 2px 4px;
            border-radius: 2px;
        }
    </style>
</head>
<body>
    <?php if (!$exportPdf): ?>
    <div class="header-actions no-print">
        <button class="btn btn-secondary" onclick="window.print()">🖨️ Drucken</button>
        <button class="btn btn-primary" onclick="location.href='?case_id=<?php echo $caseId; ?>&pdf=1'">📄 PDF Export</button>
        <a href="../index.php" class="btn btn-secondary" style="text-decoration: none;">← Zurück</a>
    </div>
    <?php endif; ?>

    <div class="container">
        <!-- HEADER -->
        <div class="header">
            <h1>🎉 Willkommen im Team!</h1>
            <p>Onboarding-Dokument für <?php echo htmlspecialchars($case['employee_first_name'] . ' ' . $case['employee_last_name']); ?></p>
            <p style="margin-top: 10px; font-size: 12px;">Dokument #<?php echo htmlspecialchars($case['case_number']); ?> • <?php echo date('d.m.Y'); ?></p>
        </div>

        <!-- PERSÖNLICHE DATEN -->
        <div class="employee-info">
            <div class="info-field">
                <div class="info-label">Name</div>
                <div class="info-value"><?php echo htmlspecialchars($case['employee_first_name'] . ' ' . $case['employee_last_name']); ?></div>
            </div>
            <div class="info-field">
                <div class="info-label">Position</div>
                <div class="info-value"><?php echo htmlspecialchars($case['job_title'] ?? 'N/A'); ?></div>
            </div>
            <div class="info-field">
                <div class="info-label">Abteilung</div>
                <div class="info-value"><?php echo htmlspecialchars($case['department']); ?></div>
            </div>
            <div class="info-field">
                <div class="info-label">Startdatum</div>
                <div class="info-value"><?php echo date('d.m.Y', strtotime($case['start_date'] ?? 'now')); ?></div>
            </div>
        </div>

        <!-- ANMELDEDATEN (SICHER) -->
        <div class="section">
            <h2 class="section-title">🔐 Ihre Anmeldedaten (Bitte sicher aufbewahren!)</h2>
            <div class="credentials">
                <div class="credentials-warning">
                    ⚠️ WICHTIG: Diese Daten sollten nur Ihnen bekannt sein! Geben Sie Ihr Passwort nicht weiter.
                </div>
                <div class="credential-field">
                    <span class="credential-label">Benutzername:</span>
                    <span class="credential-value"><?php echo htmlspecialchars($generatedUsername); ?></span>
                </div>
                <div class="credential-field">
                    <span class="credential-label">E-Mail:</span>
                    <span class="credential-value"><?php echo htmlspecialchars($generatedEmail); ?></span>
                </div>
                <div class="credential-field">
                    <span class="credential-label">Passwort:</span>
                    <span class="credential-value"><?php echo htmlspecialchars($generatedPassword); ?></span>
                </div>
                <div class="credential-field" style="margin-top: 10px; font-size: 12px; color: #666;">
                    📝 <strong>Hinweis:</strong> Sie sollten Ihr Passwort beim ersten Login ändern.
                </div>
            </div>
        </div>

        <!-- ERSTE SCHRITTE -->
        <div class="section">
            <h2 class="section-title">📋 Ihre ersten Tage</h2>
            <ul class="checklist">
                <li class="completed">Arbeitsplatz und Equipment erhalten</li>
                <li class="completed">Zugang zu IT-Systemen (PC, E-Mail, VPN)</li>
                <li>Willkommensgespräch mit dem Manager</li>
                <li>Team-Vorstellung und Kennenlernen</li>
                <li>Abteilungs-Schulungen und Einführung</li>
                <li>Sicherheits- und Compliance-Training</li>
                <li>Erste Aufgaben und Projekte</li>
            </ul>
        </div>

        <!-- KONTAKTE -->
        <div class="section">
            <h2 class="section-title">👥 Wichtige Kontakte</h2>
            <div class="contacts">
                <div class="contact-card">
                    <div class="contact-name">Klaus Weber</div>
                    <div class="contact-role">Ihr direkter Manager</div>
                    <div class="contact-info">
                        📧 klaus.weber@company.local<br>
                        📞 +49 (0) 123 / 456789<br>
                        📍 Raum 3.12
                    </div>
                </div>
                <div class="contact-card">
                    <div class="contact-name">Petra Müller</div>
                    <div class="contact-role">HR / Personalleitung</div>
                    <div class="contact-info">
                        📧 petra.mueller@company.local<br>
                        📞 +49 (0) 123 / 456000<br>
                        📍 Raum 1.01
                    </div>
                </div>
                <div class="contact-card">
                    <div class="contact-name">Sarah Schmidt</div>
                    <div class="contact-role">Betriebsrat</div>
                    <div class="contact-info">
                        📧 sarah.schmidt@company.local<br>
                        📞 +49 (0) 123 / 456500<br>
                        📍 Raum 2.05
                    </div>
                </div>
                <div class="contact-card">
                    <div class="contact-name">IT Helpdesk</div>
                    <div class="contact-role">Technische Unterstützung</div>
                    <div class="contact-info">
                        📧 itsupport@company.local<br>
                        📞 +49 (0) 123 / 456999<br>
                        🕒 Mo-Fr 08:00-17:00
                    </div>
                </div>
            </div>
        </div>

        <div class="page-break"></div>

        <!-- IT INFORMATIONEN -->
        <div class="section">
            <h2 class="section-title">💻 IT-Systeme und Zugang</h2>
            <div style="margin-bottom: 20px;">
                <h3 style="font-size: 16px; color: #444; margin-bottom: 10px;">E-Mail & Kommunikation</h3>
                <ul class="checklist">
                    <li>Microsoft Outlook (E-Mail)</li>
                    <li>Microsoft Teams (Kommunikation & Meetings)</li>
                    <li>Slack (Abteilungs-Kanäle)</li>
                </ul>
            </div>
            <div style="margin-bottom: 20px;">
                <h3 style="font-size: 16px; color: #444; margin-bottom: 10px;">VPN & Fernzugriff</h3>
                <ul class="checklist">
                    <li>Cisco AnyConnect VPN für Fernarbeit</li>
                    <li>Passwort: siehe obige Anmeldedaten</li>
                    <li>IT-Support bei Problemen: <span class="highlight">itsupport@company.local</span></li>
                </ul>
            </div>
            <div>
                <h3 style="font-size: 16px; color: #444; margin-bottom: 10px;">Sicherheit</h3>
                <ul class="checklist">
                    <li>Ändern Sie Ihr Passwort beim ersten Login</li>
                    <li>Multi-Factor Authentication (MFA) ist erforderlich</li>
                    <li>Verwenden Sie VPN für öffentliche WLANs</li>
                    <li>Sperren Sie Ihren Computer bei Abwesenheit (Windows+L)</li>
                </ul>
            </div>
        </div>

        <!-- BÜRORICHTLINIEN -->
        <div class="section">
            <h2 class="section-title">📚 Wichtige Richtlinien</h2>
            <div style="font-size: 14px; line-height: 1.8;">
                <p><strong>Arbeitszeit:</strong> Montag-Freitag, 08:00-17:00 (flexibel nach Absprache mit Manager)</p>
                <p><strong>Pausen:</strong> 30 Minuten Mittagspause + Kaffeepausen nach Bedarf</p>
                <p><strong>Krankmeldung:</strong> Bitte vor 08:00 telefonisch dem Manager melden</p>
                <p><strong>Urlaub:</strong> Mindestens 2 Wochen Vorlaufzeit, über HR beantragen</p>
                <p><strong>Fernarbeit:</strong> Nach Absprache mit Manager, max. 2x pro Woche</p>
                <p><strong>Datenschutz:</strong> Alle Daten sind vertraulich, DSGVO-Richtlinien befolgen</p>
            </div>
        </div>

        <!-- TIMELINE -->
        <div class="section">
            <h2 class="section-title">📅 Ihr Einarbeitungsplan</h2>
            <div class="timeline">
                <div class="timeline-item">
                    <div class="timeline-date">Woche 1</div>
                    <div class="timeline-text">
                        <strong>Kennenlernphase</strong><br>
                        Team-Vorstellung, Arbeitsplatz einrichten, Systeme konfigurieren
                    </div>
                </div>
                <div class="timeline-item">
                    <div class="timeline-date">Woche 2-3</div>
                    <div class="timeline-text">
                        <strong>Produktive Phase</strong><br>
                        Schulungen, erste Aufgaben, Mentoring mit erfahrenen Kollegen
                    </div>
                </div>
                <div class="timeline-item">
                    <div class="timeline-date">Woche 4</div>
                    <div class="timeline-text">
                        <strong>Check-in mit Manager</strong><br>
                        Feedback-Gespräch, Fragen klären, nächste Schritte besprechen
                    </div>
                </div>
                <div class="timeline-item">
                    <div class="timeline-date">Monat 2-3</div>
                    <div class="timeline-text">
                        <strong>Volle Integration</strong><br>
                        Eigenständige Arbeit, Team-Projekte, regelmäßige Rückmeldung
                    </div>
                </div>
            </div>
        </div>

        <!-- FOOTER -->
        <div class="footer">
            <p>Dieses Dokument wurde automatisch generiert am <?php echo date('d.m.Y H:i'); ?></p>
            <p>Bei Fragen: HR-Abteilung • Petra Müller • petra.mueller@company.local</p>
            <p style="margin-top: 10px; color: #bbb;">Willkommen im Team! 🚀</p>
        </div>
    </div>
</body>
</html>
