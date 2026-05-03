# Offboarding-Handbuch

Dieses Handbuch beschreibt den aktuell implementierten Offboarding-Dry-Run in der V2-Weboberfläche.

## Ziel des Formulars

Das Formular sammelt alle wesentlichen Informationen für sichere Austritte und bereitet daraus einen technischen Vertrag für spätere Connectoren vor.

## Wichtige Eingaben

- Benutzer / Anzeigename
- primäre E-Mail
- Abteilung
- verantwortlicher Manager
- Austrittsdatum
- Austrittsart
- optionale Mailweiterleitung und Delegation

## Sicherheitsrelevante Optionen

- Anmeldung sofort sperren
- Assets einsammeln
- mobiles Gerät zurücksetzen
- Home-Drive sichern

## Validierungslogik

| Regel | Wirkung |
| --- | --- |
| Sofort-Austritt ohne Sofortsperre | Formular wird abgelehnt |
| ungültige Weiterleitungsadresse | Formular wird abgelehnt |
| Weiterleitung auf gleiche Mailadresse | Formular wird abgelehnt |

## Ergebnis im aktuellen Stand

Nach erfolgreichem Submit wird ein Dry-Run-Contract angezeigt, aber noch keine produktive Zielsystemänderung ausgeführt.
