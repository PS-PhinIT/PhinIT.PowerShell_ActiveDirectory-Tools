# Konfigurationsübersicht

Diese Dokumentation beschreibt den geplanten Zuschnitt der Konfigurationsebenen in V2.

## Konfigurationsebenen

1. **global** – technische Standardwerte und Plattformoptionen
2. **Mandant** – Firmen-, Domain- und Branding-spezifische Werte
3. **Modul** – Aktivierung, Connectoren und Health-Definitionen
4. **Policy** – Freigaben, Klassifikationen und Prüfregeln

## Bereits vorhandene technische Basis

- `.env` für lokale Entwicklungswerte
- zentrale Settings-Klasse in Python
- Pfaddefinitionen für Templates, Static Files und `DOC`

## Geplante nächste Konfigurationsobjekte

- Rollenpakete
- Lizenzpakete
- Connector-Mapping
- Freigabematrizen
- Branding je Mandant

## Grundregel

Planung bleibt im Ordner `/PLAN`, der jeweils aktuelle Ist-Stand gehört in `/DOC`.
