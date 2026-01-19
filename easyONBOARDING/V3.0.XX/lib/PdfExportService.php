<?php
/**
 * PDF Export Service - Phase 6.3
 * Generiert Onboarding-Dokumente als PDF mit TCPDF
 */

require_once 'vendor/autoload.php';

class PdfExportService {
    private $db;
    private $pdf;
    
    public function __construct($db) {
        $this->db = $db;
    }
    
    public function generateOnboardingPDF($caseId) {
        try {
            $case = $this->getCaseData($caseId);
            if (!$case) throw new Exception("Case not found");
            
            $this->pdf = new \TCPDF('P', 'mm', 'A4', true, 'UTF-8', false);
            $this->pdf->SetDefaultMonospacedFont(PDF_FONT_MONOSPACED);
            $this->pdf->SetMargins(15, 15, 15);
            $this->pdf->SetAutoPageBreak(true, 15);
            $this->pdf->SetFont('helvetica', '', 11);
            
            // Seite 1: Titels eite
            $this->addTitlePage($case);
            
            // Seite 2: Persönliche Daten
            $this->addPersonalInfoPage($case);
            
            // Seite 3: Anmeldedaten
            $this->addCredentialsPage($case);
            
            // Seite 4: Checkliste
            $this->addChecklistPage($case);
            
            // Seite 5: Timeline
            $this->addTimelinePage($case);
            
            // Seite 6: Kontakte
            $this->addContactsPage($case);
            
            // PDF speichern
            $filename = 'Onboarding_' . $case['case_number'] . '_' . date('YmdHis') . '.pdf';
            $filepath = 'exports/' . $filename;
            
            @mkdir('exports', 0755, true);
            $this->pdf->Output($filepath, 'F');
            
            // Metadata speichern
            $this->saveGeneratedDocument($caseId, 'onboarding_guide', $filepath, filesize($filepath));
            
            logAction($_SESSION['user_id'] ?? 0, 'pdf_generated', "PDF generated for case $caseId");
            return $filepath;
            
        } catch (Exception $e) {
            logAction(0, 'pdf_error', $e->getMessage());
            throw $e;
        }
    }
    
    private function addTitlePage($case) {
        $this->pdf->AddPage();
        $this->pdf->SetFont('helvetica', 'B', 28);
        $this->pdf->SetTextColor(37, 99, 235);
        $this->pdf->Cell(0, 40, '🎉', 0, 1, 'C');
        $this->pdf->Cell(0, 20, 'Willkommen im Team!', 0, 1, 'C');
        
        $this->pdf->SetFont('helvetica', '', 14);
        $this->pdf->SetTextColor(100, 100, 100);
        $this->pdf->Ln(20);
        $this->pdf->Cell(0, 10, 'Onboarding-Dokument für', 0, 1, 'C');
        
        $this->pdf->SetFont('helvetica', 'B', 18);
        $this->pdf->SetTextColor(0, 0, 0);
        $this->pdf->Cell(0, 15, $case['employee_first_name'] . ' ' . $case['employee_last_name'], 0, 1, 'C');
        
        $this->pdf->SetFont('helvetica', '', 12);
        $this->pdf->SetTextColor(100, 100, 100);
        $this->pdf->Ln(30);
        $this->pdf->Cell(0, 8, 'Fall-Nr: ' . $case['case_number'], 0, 1, 'C');
        $this->pdf->Cell(0, 8, 'Erstellt: ' . date('d.m.Y H:i'), 0, 1, 'C');
    }
    
    private function addPersonalInfoPage($case) {
        $this->pdf->AddPage();
        $this->pdf->SetFont('helvetica', 'B', 16);
        $this->pdf->SetTextColor(37, 99, 235);
        $this->pdf->Cell(0, 12, '👤 Persönliche Informationen', 0, 1);
        $this->pdf->Ln(5);
        
        $this->pdf->SetFont('helvetica', '', 11);
        $this->pdf->SetTextColor(0, 0, 0);
        
        $info = [
            'Name' => $case['employee_first_name'] . ' ' . $case['employee_last_name'],
            'Position' => $case['job_title'] ?? 'N/A',
            'Abteilung' => $case['department'],
            'Startdatum' => date('d.m.Y', strtotime($case['start_date'] ?? 'now')),
            'E-Mail' => $case['employee_email'] ?? 'N/A',
        ];
        
        foreach ($info as $label => $value) {
            $this->pdf->SetFont('helvetica', 'B', 11);
            $this->pdf->Cell(40, 8, $label . ':');
            $this->pdf->SetFont('helvetica', '', 11);
            $this->pdf->Cell(0, 8, $value, 0, 1);
        }
    }
    
    private function addCredentialsPage($case) {
        $this->pdf->AddPage();
        $this->pdf->SetFont('helvetica', 'B', 16);
        $this->pdf->SetTextColor(220, 38, 38);
        $this->pdf->Cell(0, 12, '🔐 Anmeldedaten (VERTRAULICH)', 0, 1);
        $this->pdf->Ln(5);
        
        // Warnung Box
        $this->pdf->SetFillColor(254, 242, 242);
        $this->pdf->SetTextColor(127, 29, 29);
        $this->pdf->SetFont('helvetica', 'B', 10);
        $this->pdf->MultiCell(0, 8, '⚠️  WICHTIG: Diese Daten sind vertraulich! Geben Sie Ihr Passwort nicht weiter und ändern Sie es beim ersten Login.', 0, 'L', true);
        $this->pdf->Ln(5);
        
        $this->pdf->SetTextColor(0, 0, 0);
        $this->pdf->SetFont('helvetica', '', 11);
        
        $credentials = [
            'Benutzername' => $case['generated_username'] ?? 'N/A',
            'E-Mail' => $case['generated_email'] ?? 'N/A',
            'Passwort' => $case['generated_password'] ?? 'N/A',
            'Gültig ab' => date('d.m.Y'),
        ];
        
        foreach ($credentials as $label => $value) {
            $this->pdf->SetFont('helvetica', 'B', 11);
            $this->pdf->Cell(40, 8, $label . ':');
            $this->pdf->SetFont('courier', '', 11);
            $this->pdf->Cell(0, 8, $value, 0, 1);
        }
    }
    
    private function addChecklistPage($case) {
        $this->pdf->AddPage();
        $this->pdf->SetFont('helvetica', 'B', 16);
        $this->pdf->SetTextColor(37, 99, 235);
        $this->pdf->Cell(0, 12, '✅ Erste Schritte Checkliste', 0, 1);
        $this->pdf->Ln(5);
        
        $this->pdf->SetFont('helvetica', '', 11);
        $this->pdf->SetTextColor(0, 0, 0);
        
        $checklist = [
            '☐ Arbeitsplatz & Equipment erhalten',
            '☐ Zugang zu IT-Systemen konfiguriert',
            '☐ Willkommensgespräch mit Manager',
            '☐ Team-Vorstellung',
            '☐ Abteilungs-Schulungen',
            '☐ Sicherheits- & Compliance-Training',
            '☐ Erste Aufgaben zugewiesen',
        ];
        
        foreach ($checklist as $item) {
            $this->pdf->Cell(0, 8, $item, 0, 1);
        }
    }
    
    private function addTimelinePage($case) {
        $this->pdf->AddPage();
        $this->pdf->SetFont('helvetica', 'B', 16);
        $this->pdf->SetTextColor(37, 99, 235);
        $this->pdf->Cell(0, 12, '📅 Einarbeitungsplan', 0, 1);
        $this->pdf->Ln(5);
        
        $this->pdf->SetFont('helvetica', '', 11);
        $this->pdf->SetTextColor(0, 0, 0);
        
        $timeline = [
            ['Woche 1', 'Kennenlernphase - Team-Vorstellung, Arbeitsplatz, Systeme'],
            ['Woche 2-3', 'Schulungen & erste Aufgaben mit Mentor-Unterstützung'],
            ['Woche 4', 'Check-in Gespräch - Feedback & Anpassungen'],
            ['Monat 2-3', 'Volle Integration - eigenständige Arbeit & Projekte'],
        ];
        
        foreach ($timeline as $item) {
            $this->pdf->SetFont('helvetica', 'B', 11);
            $this->pdf->Cell(30, 8, $item[0]);
            $this->pdf->SetFont('helvetica', '', 11);
            $this->pdf->MultiCell(0, 8, $item[1], 0, 'L');
            $this->pdf->Ln(2);
        }
    }
    
    private function addContactsPage($case) {
        $this->pdf->AddPage();
        $this->pdf->SetFont('helvetica', 'B', 16);
        $this->pdf->SetTextColor(37, 99, 235);
        $this->pdf->Cell(0, 12, '👥 Wichtige Kontakte', 0, 1);
        $this->pdf->Ln(5);
        
        $this->pdf->SetFont('helvetica', '', 11);
        $this->pdf->SetTextColor(0, 0, 0);
        
        $contacts = [
            ['Manager', 'Klaus Weber', 'klaus.weber@company.local', '+49 (0)123 456789'],
            ['HR', 'Petra Müller', 'petra.mueller@company.local', '+49 (0)123 456000'],
            ['IT Support', 'IT Team', 'itsupport@company.local', '+49 (0)123 456999'],
        ];
        
        foreach ($contacts as $contact) {
            $this->pdf->SetFont('helvetica', 'B', 11);
            $this->pdf->Cell(0, 8, $contact[0], 0, 1);
            $this->pdf->SetFont('helvetica', '', 10);
            $this->pdf->Cell(0, 6, $contact[1], 0, 1);
            $this->pdf->Cell(0, 6, $contact[2], 0, 1);
            $this->pdf->Cell(0, 6, $contact[3], 0, 1);
            $this->pdf->Ln(3);
        }
    }
    
    private function getCaseData($caseId) {
        $stmt = $this->db->prepare('SELECT * FROM onboarding_cases WHERE id = ? LIMIT 1');
        $stmt->execute([$caseId]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    private function saveGeneratedDocument($caseId, $type, $filepath, $filesize) {
        $stmt = $this->db->prepare('
            INSERT INTO generated_documents 
            (case_id, document_type, document_name, file_path, file_size, format, generated_by, generated_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
        ');
        $stmt->execute([
            $caseId,
            $type,
            basename($filepath),
            $filepath,
            $filesize,
            'pdf',
            $_SESSION['user_id'] ?? 0
        ]);
    }
}
?>
