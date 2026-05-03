# Rollenpakete und Bundles

Diese Dokumentation beschreibt die Rolle von Rollen- und Provisionierungspaketen im aktuellen V2-Stand.

## Aktuell sichtbare Rollenpakete im Webformular

- `standard-user`
- `sales-user`
- `finance-user`
- `it-admin`

## Fachliche Idee

Ein Rollenpaket fasst wiederkehrende Entscheidungen zusammen, damit Onboarding- und Mover-Prozesse nicht jedes Zielsystem einzeln konfigurieren müssen.

## Spätere Inhalte eines Rollenpakets

- AD-Gruppen
- M365-Lizenzpakete
- Kommunikationsoptionen
- Asset-Defaults
- Freigabepflichten

## Wichtige Regeln

- Rollenpakete sind fachliche Vorlagen, keine Freifahrtscheine.
- Kritische Pakete wie `it-admin` brauchen später zusätzliche Freigabe- und Auditregeln.
- Jede Änderung an einem Paket muss versioniert und dokumentiert werden.
