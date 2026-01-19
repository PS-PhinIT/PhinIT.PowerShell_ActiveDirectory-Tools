# 🔗 API Dokumentation - easyONBOARDING

**REST API für externe System-Integration**

---

## 📋 Übersicht

Die easyONBOARDING API ermöglicht externe Systeme (HR-Software, PowerShell, SAP, etc.) um:
- ✅ Neue Onboarding-Fälle zu erstellen
- ✅ Fall-Status abzurufen
- ✅ Workflows zu verwalten
- ✅ Webhooks zu empfangen

**Base URL:** `http://your-server/easyONBOARDING/api/`

**Authentifizierung:** Bearer Token (API Key)

---

## 🔐 Authentifizierung

### API-Key generieren
```
1. Admin Panel anmelden
2. 🔐 API-Keys
3. "➕ Neuer API-Key" erstellen
4. Key kopieren: "sk_live_abc123xyz789"
```

### In Request verwenden
```http
Authorization: Bearer sk_live_abc123xyz789
Content-Type: application/json
```

### PowerShell Beispiel
```powershell
$headers = @{
    "Authorization" = "Bearer sk_live_abc123xyz789"
    "Content-Type" = "application/json"
}
```

---

## 📌 API Endpoints

### 1️⃣ Neuen Fall erstellen
**`POST /api/create_case.php`**

#### Request
```bash
curl -X POST http://localhost/easyONBOARDING/api/create_case.php \
  -H "Authorization: Bearer sk_live_abc123xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "employee_first_name": "Max",
    "employee_last_name": "Mustermann",
    "employee_email": "max.mustermann@company.de",
    "job_title": "Senior Developer",
    "department": "IT",
    "start_date": "2025-03-01",
    "workflow_id": 1
  }'
```

#### Request-Parameter
| Parameter | Typ | Erforderlich | Beschreibung |
|-----------|-----|-------------|-------------|
| `employee_first_name` | String | ✅ Ja | Vorname |
| `employee_last_name` | String | ✅ Ja | Nachname |
| `employee_email` | String | ✅ Ja | E-Mail Adresse |
| `job_title` | String | ✅ Ja | Position/Stelle |
| `department` | String | ✅ Ja | Abteilung |
| `start_date` | String | ✅ Ja | Startdatum (YYYY-MM-DD) |
| `workflow_id` | Int | ❌ Nein | Workflow-ID (default: 1) |
| `manager_id` | Int | ❌ Nein | Manager-User-ID |

#### Response (Success)
```json
{
  "success": true,
  "case_id": 42,
  "case_number": "ONB-20250301-042",
  "generated_username": "mmustermann",
  "generated_email": "mmustermann@company.local",
  "generated_password": "Xk$9mP2@Lq5vR8!B",
  "message": "Fall erfolgreich erstellt"
}
```

#### Response (Error)
```json
{
  "success": false,
  "error": "Invalid email format",
  "code": "VALIDATION_ERROR"
}
```

---

### 2️⃣ Fall-Status abrufen
**`GET /api/get_case_status.php?id=42`**

#### Request
```bash
curl -H "Authorization: Bearer sk_live_abc123xyz789" \
  http://localhost/easyONBOARDING/api/get_case_status.php?id=42
```

#### Response
```json
{
  "success": true,
  "case": {
    "id": 42,
    "case_number": "ONB-20250301-042",
    "employee_name": "Max Mustermann",
    "department": "IT",
    "status": "in_progress",
    "progress": 50,
    "start_date": "2025-03-01",
    "current_step": {
      "step_id": 2,
      "title": "Manager-Genehmigung",
      "role": "Manager",
      "status": "pending",
      "assigned_to": "Klaus Weber"
    },
    "timeline": [
      {
        "step": "HR-Genehmigung",
        "status": "completed",
        "completed_by": "Petra Müller",
        "completed_at": "2025-02-28 14:30:00"
      },
      {
        "step": "Manager-Genehmigung",
        "status": "in_progress",
        "assigned_to": "Klaus Weber"
      }
    ]
  }
}
```

---

### 3️⃣ Workflows abrufen
**`GET /api/get_workflows.php`**

#### Request
```bash
curl -H "Authorization: Bearer sk_live_abc123xyz789" \
  http://localhost/easyONBOARDING/api/get_workflows.php
```

#### Response
```json
{
  "success": true,
  "workflows": [
    {
      "id": 1,
      "name": "Standard Onboarding",
      "description": "Regulärer Onboarding-Prozess",
      "is_active": true,
      "steps": 4,
      "created_at": "2025-02-01"
    },
    {
      "id": 2,
      "name": "IT-Only Onboarding",
      "description": "Für IT-Mitarbeiter",
      "is_active": true,
      "steps": 3
    }
  ]
}
```

---

### 4️⃣ Workflow-Schritte abrufen
**`GET /api/get_steps.php?workflow_id=1`**

#### Request
```bash
curl -H "Authorization: Bearer sk_live_abc123xyz789" \
  http://localhost/easyONBOARDING/api/get_steps.php?workflow_id=1
```

#### Response
```json
{
  "success": true,
  "steps": [
    {
      "id": 1,
      "title": "HR-Genehmigung",
      "description": "HR prüft und genehmigt",
      "role": "HR",
      "order": 1,
      "required": true,
      "time_limit": 2
    },
    {
      "id": 2,
      "title": "Manager-Genehmigung",
      "role": "Manager",
      "order": 2,
      "required": true,
      "time_limit": 1
    }
  ]
}
```

---

### 5️⃣ Webhook registrieren
**`POST /api/webhook.php`**

#### Request
```bash
curl -X POST http://localhost/easyONBOARDING/api/webhook.php \
  -H "Authorization: Bearer sk_live_abc123xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "register",
    "event": "case_completed",
    "url": "https://your-system.com/webhooks/onboarding",
    "secret": "your-webhook-secret"
  }'
```

#### Response
```json
{
  "success": true,
  "webhook_id": 5,
  "event": "case_completed",
  "status": "active"
}
```

#### Webhook Events
| Event | Trigger | Payload |
|-------|---------|---------|
| `case_created` | Neuer Fall erstellt | case_id, case_number, employee_name |
| `step_completed` | Schritt genehmigt | case_id, step_id, completed_by |
| `case_completed` | Fall abgeschlossen | case_id, case_number, employee_data |
| `overdue_step` | Überfällige Task | case_id, step_id, days_overdue |

---

## 💻 Integration Beispiele

### PowerShell - Fall erstellen
```powershell
$apiUrl = "http://localhost/easyONBOARDING/api/create_case.php"
$apiKey = "sk_live_abc123xyz789"

# CSV-Datei mit Mitarbeitern einlesen
$employees = Import-Csv "C:\employees.csv"

foreach ($emp in $employees) {
    $data = @{
        employee_first_name = $emp.FirstName
        employee_last_name = $emp.LastName
        employee_email = $emp.Email
        job_title = $emp.Position
        department = $emp.Department
        start_date = $emp.StartDate
        workflow_id = 1
    } | ConvertTo-Json

    $headers = @{
        "Authorization" = "Bearer $apiKey"
        "Content-Type" = "application/json"
    }

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $data
        Write-Host "✅ $($emp.FirstName) - Fall: $($response.case_number)"
    } catch {
        Write-Host "❌ $($emp.FirstName) - Fehler: $($_.Exception.Message)"
    }
}
```

### Python - Fall-Status prüfen
```python
import requests
import json

API_KEY = "sk_live_abc123xyz789"
BASE_URL = "http://localhost/easyONBOARDING/api"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# Fall-Status abrufen
response = requests.get(
    f"{BASE_URL}/get_case_status.php?id=42",
    headers=headers
)

if response.status_code == 200:
    case = response.json()["case"]
    print(f"Fall: {case['case_number']}")
    print(f"Status: {case['status']}")
    print(f"Fortschritt: {case['progress']}%")
    print(f"Aktueller Schritt: {case['current_step']['title']}")
else:
    print(f"Fehler: {response.status_code}")
```

### JavaScript/Node.js - Fall erstellen
```javascript
const axios = require('axios');

const apiUrl = 'http://localhost/easyONBOARDING/api/create_case.php';
const apiKey = 'sk_live_abc123xyz789';

const employeeData = {
  employee_first_name: 'Anna',
  employee_last_name: 'Schmidt',
  employee_email: 'anna.schmidt@company.de',
  job_title: 'Product Manager',
  department: 'Management',
  start_date: '2025-03-15',
  workflow_id: 1
};

const config = {
  headers: {
    'Authorization': `Bearer ${apiKey}`,
    'Content-Type': 'application/json'
  }
};

axios.post(apiUrl, employeeData, config)
  .then(response => {
    console.log('✅ Fall erstellt!');
    console.log('Fall-Nummer:', response.data.case_number);
    console.log('Username:', response.data.generated_username);
  })
  .catch(error => {
    console.error('❌ Fehler:', error.response.data);
  });
```

---

## 🔄 Webhook Beispiel

### Webhook-Payload empfangen
```php
// webhook_handler.php in Ihrem System

$payload = file_get_contents('php://input');
$event = json_decode($payload, true);

// Signatur überprüfen
$secret = 'your-webhook-secret';
$signature = hash_hmac('sha256', $payload, $secret);
if ($_SERVER['HTTP_X_SIGNATURE'] !== $signature) {
    die('Signature invalid');
}

// Event verarbeiten
switch ($event['event']) {
    case 'case_completed':
        // Neuen Mitarbeiter in Active Directory erstellen
        exec("powershell.exe New-ADUser -Name {$event['employee_name']}");
        break;
    
    case 'step_completed':
        // Email an Slack senden
        sendSlackNotification($event);
        break;
}
```

---

## 📊 Error Handling

### Error-Codes

| Code | Beschreibung | HTTP Status |
|------|------------|-----------|
| `UNAUTHORIZED` | API-Key fehlt oder ungültig | 401 |
| `VALIDATION_ERROR` | Input-Validierung fehlgeschlagen | 400 |
| `NOT_FOUND` | Ressource nicht gefunden | 404 |
| `DUPLICATE_EMAIL` | Email existiert bereits | 409 |
| `DATABASE_ERROR` | Datenbank-Fehler | 500 |
| `INVALID_WORKFLOW` | Workflow-ID ungültig | 400 |

### Fehler-Response
```json
{
  "success": false,
  "error": "Duplicate email: max@company.de",
  "code": "DUPLICATE_EMAIL",
  "details": {
    "field": "employee_email",
    "value": "max@company.de"
  }
}
```

---

## 🔒 Best Practices

### 1. API-Key Sicherheit
```
✅ API-Keys in Umgebungsvariablen speichern
✅ Keys regelmäßig rotieren
✅ Unterschiedliche Keys für Dev/Prod
✅ Rate Limiting aktivieren
❌ Keys hardcoden
❌ Keys in Git committen
```

### 2. Fehlerbehandlung
```powershell
try {
    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body
    if (-not $response.success) {
        Write-Error "API Error: $($response.error)"
        continue
    }
    Write-Host "✅ Success: $($response.case_number)"
} catch {
    Write-Error "Request failed: $($_.Exception.Message)"
    continue
}
```

### 3. Rate Limiting beachten
```
- Max. 100 Requests pro Minute
- Max. 1000 Requests pro Stunde
- Bei Limit: Retry nach 60 Sekunden
```

---

## 📖 Weitere Ressourcen

- 📖 Siehe **HOWTO.md** für praktische Beispiele
- 📖 Siehe **README.md** für Überblick
- 📖 Siehe **INSTALLATION.md** für Setup

---

**Version:** 3.0.0  
**Letzte Aktualisierung:** 2025
