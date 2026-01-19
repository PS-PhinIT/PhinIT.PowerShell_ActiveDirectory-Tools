/**
 * easyONBOARDING - Phase 6 Database Extensions
 * Datenspeicherung, E-Mail, PDF, Task-Scheduling, Analytics
 * Version: 3.0.6
 * Date: 2025-10-24
 */

-- ===== HR SECTION - CHECKLISTEN SPEICHERUNG =====

CREATE TABLE IF NOT EXISTS `hr_checklist_items` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `category` VARCHAR(50) NOT NULL, -- 'contracts', 'insurance', 'taxes', 'personal'
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

CREATE TABLE IF NOT EXISTS `hr_documents` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `document_name` VARCHAR(255) NOT NULL,
  `document_type` VARCHAR(50), -- 'contract', 'policy', 'agreement', 'form'
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

-- ===== MANAGER/CHEF - GENEHMIGUNGEN & BUDGET =====

CREATE TABLE IF NOT EXISTS `manager_approvals` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `approval_type` VARCHAR(50) NOT NULL, -- 'financial', 'it_equipment', 'workspace', 'hiring'
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

CREATE TABLE IF NOT EXISTS `team_assignments` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `role_type` VARCHAR(50) NOT NULL, -- 'manager', 'mentor', 'trainer', 'tech_lead'
  `assigned_user_id` INT NOT NULL,
  `assigned_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `start_date` DATE,
  `end_date` DATE,
  `responsibilities` TEXT,
  `feedback` TEXT,
  `rating` INT, -- 1-5 scale
  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
  FOREIGN KEY (assigned_user_id) REFERENCES users(id),
  INDEX idx_case_role (case_id, role_type),
  INDEX idx_user_assignments (assigned_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===== SUPERVISOR - RESSOURCEN PLANUNG =====

CREATE TABLE IF NOT EXISTS `supervisor_resources` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `resource_type` VARCHAR(50) NOT NULL, -- 'workstation', 'phone', 'software', 'training'
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

-- ===== IT SECTION - ACCOUNTS & CREDENTIALS =====

CREATE TABLE IF NOT EXISTS `it_accounts` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `account_type` VARCHAR(50) NOT NULL, -- 'ad', 'exchange', 'ms365', 'slack', 'vpn'
  `username` VARCHAR(255),
  `email` VARCHAR(255),
  `password_hash` VARCHAR(500),
  `status` ENUM('pending', 'active', 'suspended', 'deleted') DEFAULT 'pending',
  `created_by` INT,
  `created_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `activated_date` TIMESTAMP NULL,
  `last_login` TIMESTAMP NULL,
  `mfa_enabled` BOOLEAN DEFAULT FALSE,
  `mfa_method` VARCHAR(50), -- 'totp', 'sms', 'email'
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

CREATE TABLE IF NOT EXISTS `it_hardware` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `hardware_type` VARCHAR(50) NOT NULL, -- 'workstation', 'laptop', 'phone', 'peripherals'
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

-- ===== EMAIL NOTIFICATIONS & REMINDERS =====

CREATE TABLE IF NOT EXISTS `email_notifications` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `recipient_email` VARCHAR(255) NOT NULL,
  `recipient_id` INT,
  `notification_type` VARCHAR(50) NOT NULL, -- 'onboarding_start', 'approval_required', 'reminder', 'completion'
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

CREATE TABLE IF NOT EXISTS `email_templates` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `template_name` VARCHAR(100) UNIQUE NOT NULL,
  `template_key` VARCHAR(50) UNIQUE,
  `subject` VARCHAR(255),
  `body_html` LONGTEXT,
  `body_text` LONGTEXT,
  `variables` JSON, -- JSON array of available template variables
  `category` VARCHAR(50), -- 'onboarding', 'approval', 'reminder', 'completion'
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

-- ===== TASK SCHEDULING & REMINDERS =====

CREATE TABLE IF NOT EXISTS `onboarding_tasks` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `task_name` VARCHAR(255) NOT NULL,
  `task_description` TEXT,
  `task_type` VARCHAR(50), -- 'hr_checklist', 'it_setup', 'training', 'meeting'
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

CREATE TABLE IF NOT EXISTS `task_reminders` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `task_id` INT NOT NULL,
  `reminder_type` VARCHAR(50), -- 'email', 'notification', 'sms'
  `scheduled_time` TIMESTAMP NOT NULL,
  `sent_time` TIMESTAMP NULL,
  `status` ENUM('pending', 'sent', 'failed') DEFAULT 'pending',
  `notification_message` TEXT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (task_id) REFERENCES onboarding_tasks(id),
  INDEX idx_scheduled_time (scheduled_time),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===== PDF DOCUMENTS & EXPORTS =====

CREATE TABLE IF NOT EXISTS `generated_documents` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `document_type` VARCHAR(50) NOT NULL, -- 'onboarding_guide', 'checklist', 'contract', 'certificate'
  `document_name` VARCHAR(255),
  `file_path` VARCHAR(500),
  `file_size` INT,
  `format` VARCHAR(20), -- 'pdf', 'docx', 'xlsx'
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

-- ===== ADVANCED ANALYTICS =====

CREATE TABLE IF NOT EXISTS `onboarding_metrics` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `metric_name` VARCHAR(100) NOT NULL,
  `metric_value` DECIMAL(10, 2),
  `metric_type` VARCHAR(50), -- 'duration', 'cost', 'completion_rate', 'satisfaction'
  `measurement_date` DATE,
  `notes` TEXT,
  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
  INDEX idx_case_metric (case_id, metric_name),
  INDEX idx_measurement_date (measurement_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `onboarding_feedback` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `case_id` INT NOT NULL,
  `feedback_from` INT,
  `feedback_type` VARCHAR(50), -- 'employee', 'manager', 'department', 'hr'
  `rating` INT, -- 1-5 scale
  `satisfaction_score` INT, -- 1-10 scale
  `strengths` TEXT,
  `improvements` TEXT,
  `overall_feedback` LONGTEXT,
  `submitted_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
  FOREIGN KEY (feedback_from) REFERENCES users(id),
  INDEX idx_case_feedback (case_id, feedback_type),
  INDEX idx_rating (rating)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

-- ===== INTEGRATIONS & WEBHOOKS (ERWEITERT) =====

CREATE TABLE IF NOT EXISTS `slack_integrations` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `workspace_name` VARCHAR(100),
  `webhook_url` VARCHAR(500),
  `bot_token` VARCHAR(500),
  `team_id` VARCHAR(100),
  `is_active` BOOLEAN DEFAULT TRUE,
  `events_enabled` JSON, -- ['onboarding_start', 'approval_required', 'completion']
  `notification_channel` VARCHAR(100),
  `created_by` INT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id),
  INDEX idx_workspace (workspace_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
  `sync_frequency` VARCHAR(50), -- 'hourly', 'daily', 'weekly'
  `created_by` INT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===== CUSTOM TEMPLATES & BRANDING (PHASE 7) =====

CREATE TABLE IF NOT EXISTS `onboarding_templates` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `template_name` VARCHAR(100) UNIQUE NOT NULL,
  `template_type` VARCHAR(50), -- 'document', 'email', 'checklist'
  `description` TEXT,
  `template_content` LONGTEXT,
  `variables` JSON,
  `is_active` BOOLEAN DEFAULT TRUE,
  `is_default` BOOLEAN DEFAULT FALSE,
  `department` VARCHAR(50),
  `created_by` INT,
  `updated_by` INT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id),
  FOREIGN KEY (updated_by) REFERENCES users(id),
  INDEX idx_template_type (template_type),
  INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `branding_settings` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `setting_key` VARCHAR(100) UNIQUE NOT NULL,
  `setting_value` LONGTEXT,
  `setting_type` VARCHAR(50), -- 'text', 'color', 'image', 'json'
  `description` TEXT,
  `updated_by` INT,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (updated_by) REFERENCES users(id),
  INDEX idx_setting_key (setting_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===== WORKFLOW BUILDER (PHASE 7) =====

CREATE TABLE IF NOT EXISTS `workflow_templates` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `template_name` VARCHAR(100) UNIQUE NOT NULL,
  `description` TEXT,
  `workflow_config` JSON, -- Komplexe Workflow-Konfiguration
  `is_active` BOOLEAN DEFAULT TRUE,
  `is_default` BOOLEAN DEFAULT FALSE,
  `version` INT DEFAULT 1,
  `created_by` INT,
  `updated_by` INT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id),
  FOREIGN KEY (updated_by) REFERENCES users(id),
  INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `workflow_automations` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `automation_name` VARCHAR(100) UNIQUE NOT NULL,
  `trigger_type` VARCHAR(50), -- 'on_case_creation', 'on_approval', 'on_date', 'on_status_change'
  `trigger_condition` JSON,
  `action_type` VARCHAR(50), -- 'send_email', 'create_task', 'update_status', 'call_api'
  `action_config` JSON,
  `is_active` BOOLEAN DEFAULT TRUE,
  `priority` INT DEFAULT 0,
  `execution_count` INT DEFAULT 0,
  `last_execution` TIMESTAMP NULL,
  `created_by` INT,
  `updated_by` INT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id),
  FOREIGN KEY (updated_by) REFERENCES users(id),
  INDEX idx_trigger_type (trigger_type),
  INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===== DEFAULT EMAIL TEMPLATES =====

INSERT INTO `email_templates` (`template_name`, `template_key`, `subject`, `body_html`, `category`, `is_active`, `created_by`) VALUES
('Onboarding Start', 'onboarding_start', 'Willkommen zum Onboarding!', '<h2>Willkommen!</h2><p>Ihr Onboarding-Prozess hat begonnen.</p>', 'onboarding', TRUE, 1),
('Approval Required', 'approval_required', 'Genehmigung erforderlich', '<p>Eine Genehmigung ist erforderlich für Fall {case_number}</p>', 'approval', TRUE, 1),
('Reminder Notification', 'reminder', 'Erinnerung: Aufgabe fällig', '<p>Sie haben eine fällige Aufgabe: {task_name}</p>', 'reminder', TRUE, 1),
('Completion Notification', 'completion', 'Onboarding abgeschlossen', '<p>Das Onboarding für {employee_name} ist abgeschlossen!</p>', 'completion', TRUE, 1);

-- ===== INDEXES FÜR PERFORMANCE =====

CREATE INDEX IF NOT EXISTS idx_case_updated ON onboarding_cases(updated_at);
CREATE INDEX IF NOT EXISTS idx_case_status_date ON onboarding_cases(status, created_at);
CREATE INDEX IF NOT EXISTS idx_user_role_active ON users(role, is_active);
CREATE INDEX IF NOT EXISTS idx_workflow_active ON workflows(is_active);

-- ===== COMPLETION =====

SELECT 'Phase 6 Database Extensions Successfully Created!' AS status;
