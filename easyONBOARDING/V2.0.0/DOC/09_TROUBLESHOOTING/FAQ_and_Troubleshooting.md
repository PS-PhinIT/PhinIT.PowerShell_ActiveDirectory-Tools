# FAQ und Troubleshooting

Diese Seite sammelt erste typische Fragen und Fehlerbilder für den aktuellen V2-Stand.

## Die Dokumentationsansicht ist leer

**Mögliche Ursache:** Unter `/DOC` existieren keine Markdown-Dateien oder es wurden nur leere Ordner angelegt.

**Prüfung:**

1. Existieren `.md`-Dateien unter einem Unterordner von `/DOC`?
2. Ist der Dateiname sauber und ohne exotische Zeichen?
3. Lässt sich die Seite `/documentation` neu laden?

## Ein Dokument lässt sich nicht öffnen

**Mögliche Ursache:** Ungültiger relativer Pfad oder Datei wurde verschoben.

**Hinweis:** Die GUI akzeptiert nur Markdown-Dateien innerhalb des tatsächlichen `/DOC`-Baums.

## Onboarding speichert nicht

**Mögliche Ursachen:**

- Pflichtfeld leer
- Startdatum liegt in der Vergangenheit
- E-Mail-Adresse ist ungültig
- Rollenpaket ist nicht zulässig

## Offboarding speichert nicht

**Mögliche Ursachen:**

- Sofort-Austritt ohne Sofortsperre
- ungültige Weiterleitungsadresse
- gleiche Adresse für Postfach und Weiterleitung

## Tests für V2 ausführen

Verwendete Prüfpfade im aktuellen Stand:

- `pytest`
- `ruff check app tests`
- `python -m compileall app tests`
