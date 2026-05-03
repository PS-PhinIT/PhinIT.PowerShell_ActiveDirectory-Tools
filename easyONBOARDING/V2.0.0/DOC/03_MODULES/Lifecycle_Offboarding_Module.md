# Modulreferenz – Lifecycle Offboarding

Das Modul `Lifecycle Offboarding` deckt den sensiblen Abschalt- und Übergabeprozess für austretende Benutzer ab.

## Aktueller Funktionsumfang

- serverseitig validiertes HTML-Formular
- Austrittsart `standard`, `immediate`, `internal-transfer`
- Sicherheitsregel für Sofort-Austritt
- Dry-Run-Vertrag mit technischer Zusammenfassung
- Anzeige nächster Umsetzungsschritte in der GUI

## Reifegrad

**Prototype / Sensitive Flow Prepared**

Das Fachmodell ist vorbereitet, produktive Abschaltaktionen sind noch nicht aktiviert.

## Besondere Validierungsregeln

| Regel | Bedeutung |
| --- | --- |
| `immediate` ohne Sofortsperre ist unzulässig | verhindert fachlich unsichere Notfallabläufe |
| Weiterleitung auf gleiche Mailadresse ist unzulässig | vermeidet fehlerhafte Mail-Loops |

## Geplante produktive Folgeschritte

1. AD-Sperre und Kennwort-Randomisierung
2. Lizenzentzug und Gruppenbereinigung
3. Mailbox-Übergabe / Delegation / Shared Mailbox
4. Asset-Rückgabe und Abschlussbericht
5. revisionssicherer Audit-Abschluss
