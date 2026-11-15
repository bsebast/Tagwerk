# Tagwerk – iOS To-do-App (SwiftUI)

Eine eigenständige To-do-App, inspiriert vom Konzept „eine Liste, Tags statt Listen, automatische Sortierung“.
Eigener Name, eigenes Icon, eigene Farben und Texte.

## Öffnen und starten

1. Repository in Xcode klonen (Schritt für Schritt: [ANLEITUNG.md](ANLEITUNG.md)) und `Tagwerk.xcodeproj` in **Xcode 16 oder neuer** öffnen.
2. Oben das Ziel **Tagwerk** und einen iPhone- oder iPad-Simulator wählen, dann **⌘R**.
3. Für ein echtes iPhone: Projekt → Target *Tagwerk* → *Signing & Capabilities* → eigenes Team wählen
   und ggf. die Bundle-ID `de.tagwerk.app` anpassen.
4. Tests: **⌘U** (Swift Testing, prüft Sortierung, Filter, Tag-Vorschläge, Erinnerungen, Wiederholung).

Universal-App für iPhone und iPad, Mindestversion iOS/iPadOS 17 (SwiftData). Neue Dateien in den Ordnern `Tagwerk/` und `TagwerkTests/`
erkennt Xcode automatisch (synchronisierte Ordner), eine manuelle Pflege der Projektdatei ist nicht nötig.

## Funktionen (MVP)

| Funktion | Umsetzung |
|---|---|
| **Eine Liste** | Alle Aufgaben in einer Ansicht, gruppiert in *Überfällig*, *Nächste 24 Std.* und *Alles andere*. |
| **Automatische Sortierung** | Pro Gruppe: Priorität ↓, dann Fälligkeit ↑, dann Erstellungsdatum. Zeitraum „Demnächst“ einstellbar (6–72 h). |
| **Tags statt Listen** | Beliebig viele Tags pro Aufgabe, jeweils mit SF-Symbol und Farbe. Tags sortieren, bearbeiten, löschen. |
| **Filtern statt Trennen** | Tags in der oberen Leiste antippen. Mehrere Tags per **UND/ODER** kombinierbar, „Alle“ hebt den Filter auf. |
| **Tag-Vorschläge** | Sechs Start-Tags mit Stichwörtern. Beim Tippen werden passende Tags vorgeschlagen (z. B. „Zahnarzttermin“ → *Gesundheit*). |
| **Schnelleingabe** | Eingabefeld unten; aktive Filter-Tags werden automatisch übernommen. |
| **Erinnern bis erledigt** | Lokale Mitteilung zur Fälligkeit, danach alle 15 Min. (einstellbar bis 4 h), bis die Aufgabe erledigt ist. Aktionen „Erledigt“ und „In 1 Stunde“ direkt in der Mitteilung. |
| **Wiederkehrende Aufgaben** | Täglich, wöchentlich, alle 2 Wochen, monatlich, jährlich. Beim Abhaken entsteht die nächste Aufgabe. |
| **Offline, ohne Konto** | Daten liegen per SwiftData auf dem Gerät; iCloud ist optional. |
| **iPad** | Seitenleiste mit allen Tags und Anzahl offener Aufgaben, Liste rechts, alle Ausrichtungen, Split View. Tastaturkürzel ⌘N (neue Aufgabe), ⌘⇧T (Tags), ⌘, (Einstellungen), Kontextmenü per Rechtsklick/langem Druck. |
| **Orts-Tags** | Pro Tag optional ein Ort (Adresse oder aktueller Standort, Umkreis 100–500 m). In der Nähe: Tag vorschlagen, Liste automatisch filtern und/oder Mitteilung mit Zahl offener Aufgaben – jeweils einzeln schaltbar. |
| **Import** | Apple Erinnerungen (Listen → Tags), Text (eine Aufgabe pro Zeile, `#tag`), CSV (Todoist, TickTick, Microsoft To Do, Excel), .ics (VTODO, z. B. Outlook). Wiederholbar, Duplikate werden übersprungen. |
| **Kalender** | Optional: offene Aufgaben mit Datum erscheinen im eigenen Kalender „Tagwerk“ und verschwinden beim Abhaken. |
| **iCloud-Sync** | SwiftData + CloudKit über das private iCloud-Konto, sobald die iCloud-Fähigkeit in Xcode eingerichtet ist (siehe ANLEITUNG). Ohne Einrichtung bleibt alles lokal. |
| Weitere Details | Notizen, Priorität (3 Stufen), Suche, erledigte ein-/ausblenden, Wischgesten, Dark Mode. |

## Aufbau

```
Tagwerk/
  TagwerkApp.swift        App-Einstieg, AppDelegate für Mitteilungsaktionen
  Models/                 TodoItem, TodoTag (SwiftData), Priority, Recurrence
  Logic/                  SmartSort, TagFilter, TagSuggester, ReminderPlan,
                          ReminderScheduler (UserNotifications), TodoActions
  Views/                  TaskListView, TaskRowView, QuickAddBar, TagFilterBar,
                          TaskEditorView, TagManagerView, TagEditorView, SettingsView
  Support/                Persistence (+ iCloud), Start-Tags, AppSettings, Palette
Tagwerk-Info.plist        Texte für die Berechtigungsabfragen (Standort, Erinnerungen, Kalender)
TagwerkTests/             Unit-Tests der Logik
```

## Mögliche nächste Schritte

- Widget und Siri-Kurzbefehl „Aufgabe hinzufügen“
