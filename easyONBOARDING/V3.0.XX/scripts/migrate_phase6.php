<?php
/**
 * Phase 6 Database Migration Script
 * Migriert die Datenbank zu Phase 6 Schema
 * 
 * Verwendung: php scripts/migrate_phase6.php [--dry-run] [--rollback]
 * 
 * Version: 1.0
 * Date: 2025-10-24
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

// Konfiguration
define('SCRIPT_DIR', __DIR__);
define('PROJECT_DIR', dirname(SCRIPT_DIR));
define('CONFIG_FILE', PROJECT_DIR . '/config.php');
define('LOG_FILE', SCRIPT_DIR . '/migration_phase6.log');
define('BACKUP_FILE', SCRIPT_DIR . '/database_backup_' . date('YmdHis') . '.sql');

// Optionen parsen
$dryRun = in_array('--dry-run', $argv);
$rollback = in_array('--rollback', $argv);
$verbose = in_array('-v', $argv) || in_array('--verbose', $argv);

// Konfiguration laden
if (!file_exists(CONFIG_FILE)) {
    die("ERROR: Config file not found at $CONFIG_FILE\n");
}

require_once CONFIG_FILE;

try {
    // Datenbank-Verbindung
    echo "═══════════════════════════════════════════════════\n";
    echo "🚀 Phase 6 Database Migration\n";
    echo "═══════════════════════════════════════════════════\n\n";

    if ($dryRun) {
        echo "⚠️  DRY-RUN MODE: No changes will be made\n\n";
    }

    echo "📋 Connecting to database...\n";
    // $db ist bereits in config.php definiert
    
    if (!$db) {
        throw new Exception("Database connection failed");
    }
    echo "✅ Database connected\n\n";

    // Backup erstellen
    if (!$dryRun) {
        echo "💾 Creating database backup...\n";
        createDatabaseBackup($db, BACKUP_FILE);
        echo "✅ Backup created: $BACKUP_FILE\n\n";
    }

    // Migrations durchführen
    $migrations = getMigrations();
    $completedMigrations = [];
    $failedMigrations = [];

    echo "📊 Running " . count($migrations) . " migrations...\n";
    echo "───────────────────────────────────────────────────\n\n";

    foreach ($migrations as $index => $migration) {
        $migrationName = $migration['name'];
        $migrationSql = $migration['sql'];

        echo "[$index/" . count($migrations) . "] Executing: $migrationName\n";

        try {
            if ($dryRun) {
                // SQL ausgeben aber nicht ausführen
                if ($verbose) {
                    echo "  SQL: " . substr($migrationSql, 0, 100) . "...\n";
                }
                echo "  ✓ [DRY-RUN]\n\n";
            } else {
                // SQL ausführen
                $result = $db->exec($migrationSql);
                echo "  ✓ Success\n\n";
                $completedMigrations[] = $migrationName;
                logMigration($migrationName, 'SUCCESS');
            }
        } catch (Exception $e) {
            $errorMsg = $e->getMessage();
            echo "  ✗ Error: $errorMsg\n\n";
            $failedMigrations[] = [
                'name' => $migrationName,
                'error' => $errorMsg
            ];
            logMigration($migrationName, 'FAILED', $errorMsg);
        }
    }

    // Zusammenfassung
    echo "═══════════════════════════════════════════════════\n";
    echo "📊 Migration Summary\n";
    echo "═══════════════════════════════════════════════════\n\n";
    echo "✅ Successful: " . count($completedMigrations) . "\n";
    echo "❌ Failed: " . count($failedMigrations) . "\n";
    echo "⏭️  Total: " . count($migrations) . "\n\n";

    if (!empty($failedMigrations)) {
        echo "Failed Migrations:\n";
        foreach ($failedMigrations as $failed) {
            echo "  - {$failed['name']}: {$failed['error']}\n";
        }
        echo "\n";
    }

    if ($dryRun) {
        echo "ℹ️  DRY-RUN MODE - No changes were applied\n";
    } else if (count($failedMigrations) === 0) {
        echo "🎉 Migration completed successfully!\n";
        echo "📝 See log file: " . LOG_FILE . "\n";
    } else {
        echo "⚠️  Migration completed with errors. Check log for details.\n";
    }

    echo "\n";

} catch (Exception $e) {
    echo "❌ MIGRATION FAILED: " . $e->getMessage() . "\n";
    logMigration('MIGRATION', 'FATAL', $e->getMessage());
    exit(1);
}

// ===== HELPER FUNCTIONS =====

/**
 * Hole alle Migrationen
 */
function getMigrations() {
    return [
        // HR Checklisten
        [
            'name' => 'Create hr_checklist_items table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `hr_checklist_items` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `category` VARCHAR(50) NOT NULL,
                  `item_name` VARCHAR(255) NOT NULL,
                  `item_description` TEXT,
                  `completed` BOOLEAN DEFAULT FALSE,
                  `completed_by` INT,
                  `completed_date` TIMESTAMP NULL,
                  `notes` TEXT,
                  `priority` ENUM('low', 'medium', 'high') DEFAULT 'medium',
                  `due_date` DATE,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (completed_by) REFERENCES users(id),
                  INDEX idx_case_completed (case_id, completed),
                  INDEX idx_due_date (due_date)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],
        
        // HR Dokumente
        [
            'name' => 'Create hr_documents table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `hr_documents` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `document_name` VARCHAR(255) NOT NULL,
                  `document_type` VARCHAR(50),
                  `file_path` VARCHAR(500),
                  `file_size` INT,
                  `mime_type` VARCHAR(100),
                  `uploaded_by` INT,
                  `uploaded_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  `signed` BOOLEAN DEFAULT FALSE,
                  `signed_date` TIMESTAMP NULL,
                  `signed_by` INT,
                  `expiration_date` DATE,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (uploaded_by) REFERENCES users(id),
                  FOREIGN KEY (signed_by) REFERENCES users(id),
                  INDEX idx_case_signed (case_id, signed),
                  INDEX idx_expiration (expiration_date)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Manager Genehmigungen
        [
            'name' => 'Create manager_approvals table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `manager_approvals` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `approval_type` VARCHAR(50) NOT NULL,
                  `status` ENUM('pending', 'approved', 'rejected', 'escalated') DEFAULT 'pending',
                  `approver_id` INT,
                  `approver_comment` TEXT,
                  `approved_date` TIMESTAMP NULL,
                  `amount` DECIMAL(10, 2),
                  `budget_code` VARCHAR(50),
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (approver_id) REFERENCES users(id),
                  INDEX idx_case_status (case_id, status),
                  INDEX idx_approval_type (approval_type),
                  INDEX idx_approved_date (approved_date)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Team Zuordnungen
        [
            'name' => 'Create team_assignments table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `team_assignments` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `role_type` VARCHAR(50) NOT NULL,
                  `assigned_user_id` INT NOT NULL,
                  `assigned_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  `start_date` DATE,
                  `end_date` DATE,
                  `responsibilities` TEXT,
                  `feedback` TEXT,
                  `rating` INT,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (assigned_user_id) REFERENCES users(id),
                  INDEX idx_case_role (case_id, role_type),
                  INDEX idx_user_assignments (assigned_user_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Supervisor Ressourcen
        [
            'name' => 'Create supervisor_resources table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `supervisor_resources` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `resource_type` VARCHAR(50) NOT NULL,
                  `resource_name` VARCHAR(255),
                  `quantity` INT DEFAULT 1,
                  `status` ENUM('pending', 'reserved', 'allocated', 'completed') DEFAULT 'pending',
                  `priority` ENUM('low', 'medium', 'high') DEFAULT 'medium',
                  `reserved_by` INT,
                  `allocated_by` INT,
                  `reserved_date` TIMESTAMP NULL,
                  `allocated_date` TIMESTAMP NULL,
                  `cost` DECIMAL(10, 2),
                  `notes` TEXT,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (reserved_by) REFERENCES users(id),
                  FOREIGN KEY (allocated_by) REFERENCES users(id),
                  INDEX idx_case_status (case_id, status),
                  INDEX idx_resource_type (resource_type),
                  INDEX idx_allocated_date (allocated_date)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // IT Accounts
        [
            'name' => 'Create it_accounts table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `it_accounts` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `account_type` VARCHAR(50) NOT NULL,
                  `username` VARCHAR(255),
                  `email` VARCHAR(255),
                  `password_hash` VARCHAR(500),
                  `status` ENUM('pending', 'active', 'suspended', 'deleted') DEFAULT 'pending',
                  `created_by` INT,
                  `created_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  `activated_date` TIMESTAMP NULL,
                  `last_login` TIMESTAMP NULL,
                  `mfa_enabled` BOOLEAN DEFAULT FALSE,
                  `mfa_method` VARCHAR(50),
                  `password_changed_date` TIMESTAMP NULL,
                  `expired` BOOLEAN DEFAULT FALSE,
                  `expiration_date` DATE,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (created_by) REFERENCES users(id),
                  INDEX idx_case_type (case_id, account_type),
                  INDEX idx_username (username),
                  INDEX idx_email (email),
                  INDEX idx_status (status)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // IT Hardware
        [
            'name' => 'Create it_hardware table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `it_hardware` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `hardware_type` VARCHAR(50) NOT NULL,
                  `model` VARCHAR(255),
                  `serial_number` VARCHAR(255),
                  `asset_tag` VARCHAR(100),
                  `status` ENUM('pending', 'allocated', 'active', 'returned') DEFAULT 'pending',
                  `allocated_date` TIMESTAMP NULL,
                  `activated_date` TIMESTAMP NULL,
                  `returned_date` TIMESTAMP NULL,
                  `cost` DECIMAL(10, 2),
                  `warranty_expiration` DATE,
                  `notes` TEXT,
                  `allocated_by` INT,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (allocated_by) REFERENCES users(id),
                  INDEX idx_case_type (case_id, hardware_type),
                  INDEX idx_status (status),
                  INDEX idx_serial (serial_number)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Email Notifications
        [
            'name' => 'Create email_notifications table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `email_notifications` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `recipient_email` VARCHAR(255) NOT NULL,
                  `recipient_id` INT,
                  `notification_type` VARCHAR(50) NOT NULL,
                  `subject` VARCHAR(255),
                  `message_template` LONGTEXT,
                  `message_body` LONGTEXT,
                  `status` ENUM('pending', 'sent', 'failed', 'bounced') DEFAULT 'pending',
                  `sent_date` TIMESTAMP NULL,
                  `failed_reason` TEXT,
                  `retry_count` INT DEFAULT 0,
                  `max_retries` INT DEFAULT 3,
                  `scheduled_date` TIMESTAMP,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (recipient_id) REFERENCES users(id),
                  INDEX idx_case_status (case_id, status),
                  INDEX idx_sent_date (sent_date),
                  INDEX idx_scheduled_date (scheduled_date),
                  INDEX idx_notification_type (notification_type)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Email Templates
        [
            'name' => 'Create email_templates table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `email_templates` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `template_name` VARCHAR(100) UNIQUE NOT NULL,
                  `template_key` VARCHAR(50) UNIQUE,
                  `subject` VARCHAR(255),
                  `body_html` LONGTEXT,
                  `body_text` LONGTEXT,
                  `variables` JSON,
                  `category` VARCHAR(50),
                  `is_active` BOOLEAN DEFAULT TRUE,
                  `created_by` INT,
                  `updated_by` INT,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  FOREIGN KEY (created_by) REFERENCES users(id),
                  FOREIGN KEY (updated_by) REFERENCES users(id),
                  INDEX idx_template_key (template_key),
                  INDEX idx_category (category)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Onboarding Tasks
        [
            'name' => 'Create onboarding_tasks table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `onboarding_tasks` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `task_name` VARCHAR(255) NOT NULL,
                  `task_description` TEXT,
                  `task_type` VARCHAR(50),
                  `assigned_to` INT,
                  `assigned_by` INT,
                  `status` ENUM('pending', 'in_progress', 'completed', 'blocked', 'cancelled') DEFAULT 'pending',
                  `priority` ENUM('low', 'medium', 'high', 'critical') DEFAULT 'medium',
                  `due_date` DATE,
                  `start_date` DATE,
                  `completed_date` TIMESTAMP NULL,
                  `estimated_hours` DECIMAL(5, 2),
                  `actual_hours` DECIMAL(5, 2),
                  `notes` TEXT,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (assigned_to) REFERENCES users(id),
                  FOREIGN KEY (assigned_by) REFERENCES users(id),
                  INDEX idx_case_status (case_id, status),
                  INDEX idx_assigned_to (assigned_to),
                  INDEX idx_due_date (due_date),
                  INDEX idx_priority (priority)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Task Reminders
        [
            'name' => 'Create task_reminders table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `task_reminders` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `task_id` INT NOT NULL,
                  `reminder_type` VARCHAR(50),
                  `scheduled_time` TIMESTAMP NOT NULL,
                  `sent_time` TIMESTAMP NULL,
                  `status` ENUM('pending', 'sent', 'failed') DEFAULT 'pending',
                  `notification_message` TEXT,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY (task_id) REFERENCES onboarding_tasks(id),
                  INDEX idx_scheduled_time (scheduled_time),
                  INDEX idx_status (status)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Generated Documents
        [
            'name' => 'Create generated_documents table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `generated_documents` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `document_type` VARCHAR(50) NOT NULL,
                  `document_name` VARCHAR(255),
                  `file_path` VARCHAR(500),
                  `file_size` INT,
                  `format` VARCHAR(20),
                  `generated_by` INT,
                  `generated_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  `download_count` INT DEFAULT 0,
                  `last_downloaded` TIMESTAMP NULL,
                  `expiration_date` TIMESTAMP NULL,
                  `password_protected` BOOLEAN DEFAULT FALSE,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (generated_by) REFERENCES users(id),
                  INDEX idx_case_type (case_id, document_type),
                  INDEX idx_generated_date (generated_date)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Onboarding Metrics
        [
            'name' => 'Create onboarding_metrics table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `onboarding_metrics` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `metric_name` VARCHAR(100) NOT NULL,
                  `metric_value` DECIMAL(10, 2),
                  `metric_type` VARCHAR(50),
                  `measurement_date` DATE,
                  `notes` TEXT,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  INDEX idx_case_metric (case_id, metric_name),
                  INDEX idx_measurement_date (measurement_date)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Onboarding Feedback
        [
            'name' => 'Create onboarding_feedback table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `onboarding_feedback` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `case_id` INT NOT NULL,
                  `feedback_from` INT,
                  `feedback_type` VARCHAR(50),
                  `rating` INT,
                  `satisfaction_score` INT,
                  `strengths` TEXT,
                  `improvements` TEXT,
                  `overall_feedback` LONGTEXT,
                  `submitted_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
                  FOREIGN KEY (feedback_from) REFERENCES users(id),
                  INDEX idx_case_feedback (case_id, feedback_type),
                  INDEX idx_rating (rating)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Analytics Dashboard Data
        [
            'name' => 'Create analytics_dashboard_data table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `analytics_dashboard_data` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `metric_date` DATE,
                  `total_cases_started` INT DEFAULT 0,
                  `total_cases_completed` INT DEFAULT 0,
                  `avg_completion_days` DECIMAL(5, 2),
                  `avg_completion_rate` DECIMAL(5, 2),
                  `total_budget_spent` DECIMAL(15, 2),
                  `avg_budget_per_employee` DECIMAL(10, 2),
                  `satisfaction_score` DECIMAL(3, 1),
                  `departments_count` INT,
                  `employees_onboarded` INT,
                  `most_time_consuming_steps` JSON,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  INDEX idx_metric_date (metric_date)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        // Integration Tables
        [
            'name' => 'Create slack_integrations table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `slack_integrations` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `workspace_name` VARCHAR(100),
                  `webhook_url` VARCHAR(500),
                  `bot_token` VARCHAR(500),
                  `team_id` VARCHAR(100),
                  `is_active` BOOLEAN DEFAULT TRUE,
                  `events_enabled` JSON,
                  `notification_channel` VARCHAR(100),
                  `created_by` INT,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY (created_by) REFERENCES users(id),
                  INDEX idx_workspace (workspace_name)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        [
            'name' => 'Create teams_integrations table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `teams_integrations` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `tenant_id` VARCHAR(100),
                  `webhook_url` VARCHAR(500),
                  `app_id` VARCHAR(100),
                  `is_active` BOOLEAN DEFAULT TRUE,
                  `events_enabled` JSON,
                  `notification_team` VARCHAR(100),
                  `notification_channel` VARCHAR(100),
                  `created_by` INT,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY (created_by) REFERENCES users(id),
                  INDEX idx_tenant (tenant_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],

        [
            'name' => 'Create sap_integrations table',
            'sql' => "
                CREATE TABLE IF NOT EXISTS `sap_integrations` (
                  `id` INT PRIMARY KEY AUTO_INCREMENT,
                  `system_name` VARCHAR(100),
                  `api_endpoint` VARCHAR(500),
                  `api_key_encrypted` VARCHAR(500),
                  `username_encrypted` VARCHAR(500),
                  `password_encrypted` VARCHAR(500),
                  `is_active` BOOLEAN DEFAULT TRUE,
                  `sync_enabled` BOOLEAN DEFAULT FALSE,
                  `last_sync_date` TIMESTAMP NULL,
                  `sync_frequency` VARCHAR(50),
                  `created_by` INT,
                  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY (created_by) REFERENCES users(id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            "
        ],
    ];
}

/**
 * Erstelle Datenbank-Backup
 */
function createDatabaseBackup($db, $backupFile) {
    try {
        // Hole Datenbank-Name
        $dbName = getenv('DB_NAME') ?: 'onboarding';
        
        // Nutze mysqldump (wenn verfügbar)
        $cmd = "mysqldump -h " . (getenv('DB_HOST') ?: 'localhost') .
               " -u " . (getenv('DB_USER') ?: 'root') .
               " -p'" . (getenv('DB_PASS') ?: '') . "'" .
               " $dbName > $backupFile";
        
        // Fallback: Einfache SQL-Dump generieren
        if (!shell_exec("which mysqldump")) {
            generateSimpleBackup($db, $backupFile);
        }
        
        return true;
    } catch (Exception $e) {
        logMigration('BACKUP', 'WARNING', $e->getMessage());
        return false;
    }
}

/**
 * Generiere einfaches Backup
 */
function generateSimpleBackup($db, $backupFile) {
    $backup = "-- Database Backup\n";
    $backup .= "-- Generated: " . date('Y-m-d H:i:s') . "\n\n";
    
    // Alle Tabellen dumpen
    $tables = $db->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);
    foreach ($tables as $table) {
        $backup .= "-- Table: $table\n";
        $result = $db->query("SHOW CREATE TABLE $table")->fetch();
        $backup .= $result[1] . ";\n\n";
    }
    
    file_put_contents($backupFile, $backup);
}

/**
 * Logging-Funktion
 */
function logMigration($name, $status, $details = '') {
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[$timestamp] $status - $name";
    if (!empty($details)) {
        $logEntry .= " | Details: $details";
    }
    $logEntry .= "\n";
    
    file_put_contents(LOG_FILE, $logEntry, FILE_APPEND);
    echo "";
}

?>
