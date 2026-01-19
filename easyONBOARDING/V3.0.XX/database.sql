-- Onboarding System Datenbank Schema (VERBESSERT)

CREATE DATABASE IF NOT EXISTS onboarding_system;
USE onboarding_system;

-- Benutzer-Tabelle
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('HR', 'Abteilungsleiter', 'Chef', 'IT', 'Admin') NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    department VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_role (role)
);

-- Abteilungen
CREATE TABLE departments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    manager_id INT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (manager_id) REFERENCES users(id)
);

-- Onboarding-Prozesse
CREATE TABLE onboarding_cases (
    id INT PRIMARY KEY AUTO_INCREMENT,
    case_number VARCHAR(20) UNIQUE NOT NULL,
    employee_first_name VARCHAR(100) NOT NULL,
    employee_last_name VARCHAR(100) NOT NULL,
    employee_email VARCHAR(100),
    employee_username VARCHAR(50),
    employee_password VARCHAR(255),
    department VARCHAR(100),
    job_title VARCHAR(100),
    manager_id INT,
    start_date DATE,
    status ENUM('pending', 'in_progress', 'completed', 'rejected') DEFAULT 'pending',
    current_step INT DEFAULT 0,
    current_role ENUM('HR', 'Abteilungsleiter', 'Chef', 'IT') NOT NULL DEFAULT 'HR',
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (manager_id) REFERENCES users(id),
    FOREIGN KEY (created_by) REFERENCES users(id),
    INDEX idx_status (status),
    INDEX idx_current_role (current_role),
    INDEX idx_case_number (case_number)
);

-- Workflow-Definition
CREATE TABLE workflows (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    step_order JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_active (is_active)
);

-- Workflow-Schritte
CREATE TABLE workflow_steps (
    id INT PRIMARY KEY AUTO_INCREMENT,
    workflow_id INT NOT NULL,
    step_number INT NOT NULL,
    role ENUM('HR', 'Abteilungsleiter', 'Chef', 'IT') NOT NULL,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    is_mandatory BOOLEAN DEFAULT TRUE,
    can_skip BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (workflow_id) REFERENCES workflows(id) ON DELETE CASCADE,
    UNIQUE KEY unique_step (workflow_id, step_number),
    INDEX idx_workflow (workflow_id)
);

-- Formularfelder
CREATE TABLE form_fields (
    id INT PRIMARY KEY AUTO_INCREMENT,
    step_id INT NOT NULL,
    field_name VARCHAR(100) NOT NULL,
    field_type ENUM('text', 'email', 'password', 'number', 'date', 'select', 'checkbox', 'textarea') NOT NULL,
    label VARCHAR(100) NOT NULL,
    placeholder VARCHAR(100),
    is_required BOOLEAN DEFAULT FALSE,
    is_auto_filled BOOLEAN DEFAULT FALSE,
    default_value VARCHAR(255),
    options JSON,
    field_order INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (step_id) REFERENCES workflow_steps(id) ON DELETE CASCADE,
    INDEX idx_step (step_id)
);

-- Eingaben der Benutzer
CREATE TABLE form_responses (
    id INT PRIMARY KEY AUTO_INCREMENT,
    case_id INT NOT NULL,
    step_id INT NOT NULL,
    field_id INT NOT NULL,
    response_value LONGTEXT,
    user_id INT,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (case_id) REFERENCES onboarding_cases(id) ON DELETE CASCADE,
    FOREIGN KEY (step_id) REFERENCES workflow_steps(id),
    FOREIGN KEY (field_id) REFERENCES form_fields(id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_case (case_id),
    INDEX idx_step (step_id)
);

-- Schritt-Fortschritt
CREATE TABLE step_progress (
    id INT PRIMARY KEY AUTO_INCREMENT,
    case_id INT NOT NULL,
    step_id INT NOT NULL,
    status ENUM('pending', 'in_progress', 'completed', 'rejected') DEFAULT 'pending',
    assigned_to INT,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (case_id) REFERENCES onboarding_cases(id) ON DELETE CASCADE,
    FOREIGN KEY (step_id) REFERENCES workflow_steps(id),
    FOREIGN KEY (assigned_to) REFERENCES users(id),
    UNIQUE KEY unique_progress (case_id, step_id),
    INDEX idx_case (case_id),
    INDEX idx_status (status)
);

-- Audit-Log
CREATE TABLE logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_user (user_id),
    INDEX idx_action (action),
    INDEX idx_created (created_at)
);

-- Generierte Dokumente
CREATE TABLE generated_documents (
    id INT PRIMARY KEY AUTO_INCREMENT,
    case_id INT NOT NULL,
    document_type ENUM('csv', 'pdf', 'docx') NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    file_size INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (case_id) REFERENCES onboarding_cases(id) ON DELETE CASCADE,
    INDEX idx_case (case_id)
);

-- API-Log für externe Integrationen
CREATE TABLE api_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    api_key_hash VARCHAR(255),
    endpoint VARCHAR(255),
    method VARCHAR(10),
    status_code INT,
    request_data LONGTEXT,
    response_data LONGTEXT,
    case_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (case_id) REFERENCES onboarding_cases(id),
    INDEX idx_endpoint (endpoint),
    INDEX idx_created (created_at)
);

-- Webhooks für externe Event-Callbacks
CREATE TABLE webhooks (
    id INT PRIMARY KEY AUTO_INCREMENT,
    url VARCHAR(255) NOT NULL,
    events JSON NOT NULL,
    description TEXT,
    secret VARCHAR(255) NOT NULL,
    user_id INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    last_triggered_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_active (is_active),
    INDEX idx_user (user_id)
);

-- Webhook Delivery Logs
CREATE TABLE webhook_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    webhook_id INT NOT NULL,
    event VARCHAR(100),
    payload LONGTEXT,
    response_code INT,
    response_body LONGTEXT,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (webhook_id) REFERENCES webhooks(id) ON DELETE CASCADE,
    INDEX idx_webhook (webhook_id),
    INDEX idx_sent (sent_at)
);

-- Standard-Workflow einfügen
INSERT INTO workflows (name, description, is_active, step_order) VALUES
('Standard Workflow', 'Standard Onboarding Workflow', TRUE, '[1, 2, 3, 4, 5]');

-- Standard-Schritte einfügen
INSERT INTO workflow_steps (workflow_id, step_number, role, title, description, is_mandatory, can_skip) VALUES
(1, 1, 'HR', 'Personalien erfassen', 'Grundinformationen des neuen Mitarbeiters', TRUE, FALSE),
(1, 2, 'Abteilungsleiter', 'Abteilungsleiter Genehmigung', 'Genehmigung durch den Abteilungsleiter', TRUE, FALSE),
(1, 3, 'Chef', 'Chef Genehmigung', 'Genehmigung durch den Chef', TRUE, FALSE),
(1, 4, 'IT', 'IT-Ausstattung', 'Bereitstellung von IT-Ressourcen', TRUE, FALSE),
(1, 5, 'HR', 'Abschluss', 'Finalisierung des Onboarding-Prozesses', TRUE, FALSE);

-- Standardfelder für Schritt 1 (HR - Personalien)
INSERT INTO form_fields (step_id, field_name, field_type, label, is_required, field_order) VALUES
(1, 'first_name', 'text', 'Vorname', TRUE, 1),
(1, 'last_name', 'text', 'Nachname', TRUE, 2),
(1, 'email', 'email', 'Email-Adresse', TRUE, 3),
(1, 'department', 'select', 'Abteilung', TRUE, 4),
(1, 'job_title', 'text', 'Stellenbezeichnung', TRUE, 5),
(1, 'start_date', 'date', 'Startdatum', TRUE, 6),
(1, 'manager', 'select', 'Vorgesetzter', TRUE, 7);

-- Standard-Abteilungen
INSERT INTO departments (name, description, is_active) VALUES
('Engineering', 'Entwicklungs- und Engineering-Team', TRUE),
('Marketing', 'Marketing und Kommunikation', TRUE),
('Sales', 'Vertrieb und Kundenakquise', TRUE),
('HR', 'Personalwesen und Verwaltung', TRUE),
('IT', 'IT-Support und Infrastruktur', TRUE);
