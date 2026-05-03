# GUI-Übersicht

Diese Dokumentation beschreibt den aktuell verfügbaren GUI-Stand von `easyONBOARDING V2.0.0`.

## Ziel der Oberfläche

Die Weboberfläche bündelt Joiner-, Mover- und Leaver-Prozesse sowie Betriebs- und Dokumentationsfunktionen in einer zentralen Admin-Konsole.

## Hauptnavigation

- `Dashboard` für Plattformstatus und Schnellzugriffe
- `Benutzer` für Vorschau auf Lifecycle-relevante Personenobjekte
- `Onboarding` für validierte Dry-Run-Anlageprozesse
- `Offboarding` für validierte Dry-Run-Abschaltprozesse
- `Dokumentation` für live aus `/DOC` geladene Markdown-Inhalte
- `Jobs` für Hintergrundaufgaben und spätere Queue-Sicht
- `Einstellungen` für Mandanten-, Modul- und Sicherheitsoptionen

## Aktueller Interaktionsstand

| Bereich | Status | Hinweis |
| --- | --- | --- |
| Dashboard | aktiv | Karten, Quick Actions und Metrik-Fragmente |
| Onboarding | aktiv | serverseitige Validierung und Contract-Dry-Run |
| Offboarding | aktiv | serverseitige Validierung und Sensitive-Checks |
| Dokumentation | aktiv | liest Unterordner und Markdown-Dateien live ein, inklusive Suche, Abschnitts-Index und Markdown-Vorschau |
| Jobs | Vorschau | aktuell statische Daten als UI-Platzhalter |
| Einstellungen | Vorschau | vorbereitet für spätere Konfigurationsmasken |

## Bedienprinzipien

- Formulare werden serverseitig validiert.
- Fehler bleiben sichtbar, ohne eingegebene Werte zu verlieren.
- Kritische Prozesse liefern zunächst nur einen Dry-Run-Vertrag.
- Dokumentationsseiten werden nicht hart im Code hinterlegt, sondern dynamisch aus dem Dateisystem gelesen.
- Formulare und Modulseiten bieten jetzt direkte Kontext-Hilfe in die passende Dokumentation.
- Dokumentationsordner lassen sich als Auto-Index im Browser öffnen.

## Nächste GUI-Ausbaustufen

1. echte Job-Erzeugung mit Statuspersistenz
2. Drilldown-Ansichten für Benutzer, Module und Fehlerbilder
3. differenzierte Rollen- und Freigabemasken
4. rollenbasierte Bearbeitung und Speichern von Dokumentationsinhalten
