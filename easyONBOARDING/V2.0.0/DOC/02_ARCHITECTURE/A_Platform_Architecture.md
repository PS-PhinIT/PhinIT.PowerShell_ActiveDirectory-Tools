# Plattform-Architektur

Die aktuelle Zielarchitektur für `easyONBOARDING V2.0.0` folgt einem webbasierten, modularen Mehrschichtansatz.

## Schichtenmodell

1. **IIS** als Front Door und Reverse Proxy
2. **FastAPI-Anwendung** für GUI, Routing und Validierung
3. **Worker-/Job-Schicht** für asynchrone Aufgaben
4. **PowerShell-Runner** für AD-, RSAT- und Windows-nahe Operationen
5. **optionale API-Connectoren** für Cloud- und Drittsysteme
6. **Datenhaltung** für Konfiguration, Audit, Jobs und Reports

## Aktuell bereits im Code sichtbar

- App-Factory mit Lifespan in `app/main.py`
- modulare Router für Web und API
- zentrale Settings mit `.env`-Support
- Template-Rendering mit gemeinsamen Kontextdaten
- PowerShell-Contract-Vorbereitung in einem dedizierten Service
- Dateisystembasierte Live-Dokumentation aus `/DOC`

## Request-Flow im aktuellen V2-Stand

```text
Browser -> FastAPI Route -> Validierung -> Dry-Run Contract -> HTML Response
```

## Geplanter produktiver Flow

```text
Browser -> FastAPI Route -> Workflow/Service -> Job Queue -> PowerShell/API Connector -> Audit/Status -> GUI
```

## Wichtige Architekturregeln

- UI, Orchestrierung und Ausführung bleiben getrennt.
- Legacy-PowerShell wird nur über kontrollierte JSON-Verträge angebunden.
- Langlaufende oder schreibende Prozesse werden später asynchron über Jobs abgewickelt.
- Dokumentation wird als lebender Bestandteil der Plattform geführt.
