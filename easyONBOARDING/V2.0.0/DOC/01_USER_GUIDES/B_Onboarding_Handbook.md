# Onboarding-Handbuch

Dieses Handbuch beschreibt den aktuell implementierten Onboarding-Dry-Run in der V2-Weboberfläche.

## Zweck des aktuellen Flows

Der aktuelle Stand erzeugt noch keine produktive AD- oder M365-Anlage, sondern validiert Fachdaten und baut daraus einen standardisierten Connector-Vertrag auf.

## Pflichtfelder im Formular

- Vorname
- Nachname
- primäre E-Mail-Adresse
- Abteilung
- Standort
- Startdatum
- fachlicher Manager
- Rollenpaket

## Zusätzliche Optionen

- Mailbox vorbereiten
- Endgerät reservieren
- Telefonie / UC anlegen
- Welcome-Unterlagen erzeugen

## Ergebnis nach erfolgreichem Submit

Nach dem Speichern zeigt die Oberfläche:

- eine Erfolgsrückmeldung
- eine Korrelations-ID
- eine komprimierte Zusammenfassung der Eingaben
- den generierten JSON-Dry-Run-Vertrag
- die nächsten technischen Schritte

## Typische Fehlerbilder

| Problem | Ursache | Reaktion |
| --- | --- | --- |
| ungültige E-Mail | Tippfehler oder falsches Format | Korrektur im Formular |
| Startdatum in der Vergangenheit | fachlich unzulässiger Wert | neues Datum wählen |
| ungültiges Rollenpaket | nicht zulässiger Wert | Auswahl aus Liste verwenden |

## Nächste Ausbaustufe

Der Dry-Run soll im nächsten Schritt in einen echten Job überführt werden, der PowerShell-Connectoren und Folgeaufgaben anstößt.
