# V2.0.0 – Risiken und Abhängigkeiten

## Ziel

Dieses Dokument sammelt die wichtigsten Projektrisiken, technischen Abhängigkeiten und Architekturentscheidungen mit hoher Tragweite.

## 1. Zentrale Projektrisiken

| Risiko | Beschreibung | Auswirkung | Gegenmaßnahme |
|---|---|---|---|
| Zu große Erstversion | zu viele Module gleichzeitig | Verzögerung, Unfertigkeit | strikte Release-Wellen und MVP-Grenzen |
| Legacy-Komplexität | alte Skripte sind uneinheitlich | hoher Migrationsaufwand | Connector-Verträge und schrittweise Übernahme |
| Rechte-/Security-Lücken | zu breite technische Konten | hohes Sicherheitsrisiko | getrennte technische Identitäten, RBAC, Audit |
| Drittsystem-Abhängigkeiten | APIs ändern sich oder fehlen | Modulinstabilität | modulare Kapselung, Fallback-Tasks |
| UI-Überladung | zu viele Funktionen in einer Oberfläche | geringe Bedienbarkeit | klare Navigation, Rollensichten, Schritt-für-Schritt-Wizards |
| Unklare Ownership | niemand fühlt sich für Module zuständig | langsame Pflege | Modul-Owner je Bereich definieren |

## 2. Technische Abhängigkeiten

### Pflichtabhängigkeiten
- Windows Server
- IIS
- Python 3.13
- PowerShell 5.1
- RSAT Active Directory Tools

### Häufige Zusatzabhängigkeiten
- Microsoft Graph / M365-Berechtigungen
- Exchange Tools
- Teams PowerShell / APIs
- Telefonie-APIs
- SQL Server / SQL Express
- SMTP / Benachrichtigungskanäle

## 3. Organisatorische Abhängigkeiten

- HR liefert verlässliche Eintritts-/Austrittsdaten
- IAM/AD-Admins definieren Rollenpakete
- Fachbereiche benennen Genehmiger
- Asset-Verantwortliche pflegen Geräteprozesse
- Security definiert Schutzstufen und sensible Aktionen

## 4. Risiken in der Migrationsphase

- Alt-INI-Konfigurationen sind inkonsistent
- Skripte haben implizite Annahmen statt dokumentierter Verträge
- Assets und Reportvorlagen sind verteilt oder uneinheitlich
- Begriffe und Prozesse unterscheiden sich je Firma / Mandant

## 5. Risiken im Produktivbetrieb

- langlaufende Jobs blockieren falsche Bereiche
- Auditdaten wachsen stark an
- Module werden aktiviert, ohne dass Voraussetzungen erfüllt sind
- Helpdesk erhält zu breite Rechte
- seltene Sonderfälle unterlaufen Standardprozesse

## 6. Architekturentscheidungen mit hoher Auswirkung

### Entscheidung 1 – SQL Express vs. SQL Server
- kleine Umgebungen: SQL Express gut genug
- größere Multi-Admin-Szenarien: eher SQL Server

### Entscheidung 2 – HTMX-first vs. Frontend-SPA
- HTMX-first für schnellen, wartbaren Start
- SPA nur für hochinteraktive Spezialmodule bei echtem Mehrwert

### Entscheidung 3 – zentrales technisches Konto vs. modulweise Trennung
- zentral einfach, aber riskanter
- modulweise Trennung sicherer und langfristig sauberer

## 7. Abhängigkeiten je Modulgruppe

### AD-/Identity-Module
- RSAT
- OU-/Rechtekonzept
- ggf. Fileserverzugriffe

### Cloud-Module
- Tenant-Berechtigungen
- API-Registrierungen
- Connector-Secrets

### Telefonie-Module
- Hersteller-API oder Scriptbarkeit
- Testumgebung oder Dummy-Profil
- saubere Nummern- und Benutzerlogik

### ITSM-/Doku-Module
- API-Zugänge
- Prozessmapping auf bestehende Ticketfelder
- abgestimmte Ticketvorlagen

## 8. Projektsteuerungsrisiken

- Funktionswünsche wachsen schneller als der Plattformkern
- Pilotfeedback wird zu spät eingeholt
- zu frühe Parallelisierung vieler Integrationen
- fehlende Negativtests bei Offboarding oder Rechteentzug

## 9. Empfohlene Gegenmaßnahmen

- Kernsystem zuerst hart priorisieren
- Integrationen in Wellen aktivieren
- Pilot früh starten
- Risiko- und Entscheidungsregister regelmäßig aktualisieren
- Sonderfälle bewusst als Sonderfälle dokumentieren statt heimlich in Standardpfade zu mischen

## 10. Offene Entscheidungen zum Nachhalten

- Standarddatenbank final festlegen
- Secretspeicher festlegen
- Approval-Engine zentral oder modulweise
- Ticketing-Primärsystem festlegen
- erstes Telefonie-Zielsystem priorisieren
- erstes HR-Importformat definieren

## 11. Empfehlung für das weitere Vorgehen

Die größten Risiken sinken, wenn als Nächstes **nicht sofort alle Integrationen** gebaut werden, sondern zuerst:

1. Projektstruktur
2. UI-Shell
3. Runner-Vertrag
4. AD-Kernfunktionen
5. Audit / Jobs / Reports

Erst danach sollten Telefonie, Ticketing und Spezialmodule aufgeschaltet werden.
