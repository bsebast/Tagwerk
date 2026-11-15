import Foundation

/// Eine Aufgabe, wie sie aus einer Datei gelesen wurde (noch nicht gespeichert).
struct ImportedTask: Equatable {
    var title: String
    var notes: String = ""
    var due: Date?
    var tags: [String] = []
    var priority: Priority = .none
}

/// Ergebnis eines Imports, für die Anzeige.
struct ImportResult: Equatable {
    var imported = 0
    var skipped = 0
    var newTags = 0

    var summary: String {
        var parts = ["\(imported) \(imported == 1 ? "Aufgabe" : "Aufgaben") importiert"]
        if skipped > 0 { parts.append("\(skipped) übersprungen (schon vorhanden oder erledigt)") }
        if newTags > 0 { parts.append("\(newTags) neue Tags") }
        return parts.joined(separator: ", ")
    }
}

/// Liest Aufgaben aus Text, CSV (z. B. Todoist-, TickTick-Export) und .ics (VTODO, z. B. Outlook).
enum TextImport {
    static func parse(_ text: String, fileExtension: String = "txt", calendar: Calendar = .current) -> [ImportedTask] {
        let ext = fileExtension.lowercased()
        if ext == "ics" || text.contains("BEGIN:VTODO") {
            return parseICS(text, calendar: calendar)
        }
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        if ext == "csv" || looksLikeCSVHeader(lines.first ?? "") {
            return parseCSV(lines, calendar: calendar)
        }
        return parseLines(lines)
    }

    // MARK: Text (eine Aufgabe pro Zeile)

    /// „- [ ] Milch kaufen #einkauf“ → Titel „Milch kaufen“, Tag „einkauf“. Abgehakte Zeilen („[x]“) werden übersprungen.
    static func parseLines(_ lines: [String]) -> [ImportedTask] {
        lines.compactMap { raw in
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }

            let lower = line.lowercased()
            for done in ["- [x]", "* [x]", "[x]", "☑", "✓", "✔"] where lower.hasPrefix(done) {
                return nil
            }
            for prefix in ["- [ ]", "* [ ]", "[ ]", "☐", "- ", "* ", "• ", "– "] where line.hasPrefix(prefix) {
                line = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
            // Nummerierung „1. “ / „1) “ entfernen.
            if let match = line.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
                line.removeSubrange(match)
            }

            var tags: [String] = []
            var words: [String] = []
            for word in line.split(separator: " ") {
                if word.hasPrefix("#"), word.count > 1 {
                    tags.append(String(word.dropFirst()))
                } else {
                    words.append(String(word))
                }
            }
            let title = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { return nil }
            return ImportedTask(title: title, tags: tags)
        }
    }

    // MARK: CSV

    static let titleColumns = ["title", "titel", "aufgabe", "task", "name", "content", "subject", "betreff"]
    static let dueColumns = ["due", "due date", "fällig", "fälligkeit", "datum", "date", "fällig am", "duedate"]
    static let tagColumns = ["tags", "tag", "liste", "list", "list name", "project", "projekt", "labels", "folder", "ordner"]
    static let priorityColumns = ["priority", "priorität", "prio"]
    static let notesColumns = ["notes", "notizen", "description", "beschreibung", "note", "notiz"]
    static let statusColumns = ["status", "completed", "erledigt", "done"]

    static func looksLikeCSVHeader(_ line: String) -> Bool {
        let separator: Character = line.contains(";") ? ";" : ","
        let header = splitCSVLine(line, separator: separator).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        return header.count > 1 && header.contains { titleColumns.contains($0) }
    }

    static func parseCSV(_ lines: [String], calendar: Calendar) -> [ImportedTask] {
        guard let headerLine = lines.first else { return [] }
        let separator: Character = headerLine.contains(";") ? ";" : ","
        let header = splitCSVLine(headerLine, separator: separator).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        func index(_ names: [String]) -> Int? { header.firstIndex { names.contains($0) } }
        guard let titleIndex = index(titleColumns) else { return [] }
        let dueIndex = index(dueColumns)
        let tagIndex = index(tagColumns)
        let priorityIndex = index(priorityColumns)
        let notesIndex = index(notesColumns)
        let statusIndex = index(statusColumns)

        return lines.dropFirst().compactMap { line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let fields = splitCSVLine(line, separator: separator)
            func field(_ i: Int?) -> String {
                guard let i, i < fields.count else { return "" }
                return fields[i].trimmingCharacters(in: .whitespaces)
            }
            let title = field(titleIndex)
            guard !title.isEmpty else { return nil }
            let status = field(statusIndex).lowercased()
            if ["completed", "done", "erledigt", "true", "yes", "ja", "x", "1"].contains(status) { return nil }

            let tags = field(tagIndex)
                .split(whereSeparator: { ",;|".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return ImportedTask(
                title: title,
                notes: field(notesIndex),
                due: parseDate(field(dueIndex), calendar: calendar),
                tags: tags,
                priority: parsePriority(field(priorityIndex))
            )
        }
    }

    /// Trennt eine CSV-Zeile; Felder in Anführungszeichen dürfen Trennzeichen und doppelte Anführungszeichen enthalten.
    static func splitCSVLine(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let char = chars[i]
            if char == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    current.append("\"")
                    i += 1
                } else {
                    inQuotes.toggle()
                }
            } else if char == separator && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
            i += 1
        }
        fields.append(current)
        return fields
    }

    static func parsePriority(_ value: String) -> Priority {
        switch value.lowercased().trimmingCharacters(in: .whitespaces) {
        case "hoch", "high", "p1", "3", "!!!", "urgent", "dringend": return .high
        case "mittel", "medium", "p2", "2", "!!": return .medium
        case "niedrig", "low", "p3", "1", "!": return .low
        default: return .none
        }
    }

    static func parseDate(_ value: String, calendar: Calendar) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let iso = ISO8601DateFormatter().date(from: trimmed) { return iso }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let withTime = ["yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "dd.MM.yyyy HH:mm", "dd.MM.yy HH:mm", "MM/dd/yyyy HH:mm"]
        for format in withTime {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        // Reines Datum: 9:00 Uhr als sinnvolle Uhrzeit.
        for format in ["yyyy-MM-dd", "dd.MM.yyyy", "dd.MM.yy", "MM/dd/yyyy", "yyyyMMdd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)
            }
        }
        return nil
    }

    // MARK: iCalendar (.ics, VTODO)

    static func parseICS(_ text: String, calendar: Calendar) -> [ImportedTask] {
        // Gefaltete Zeilen (Fortsetzung beginnt mit Leerzeichen/Tab) zusammenfügen.
        let unfolded = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
        var tasks: [ImportedTask] = []
        var current: ImportedTask?
        var completed = false

        for line in unfolded.components(separatedBy: "\n") {
            if line == "BEGIN:VTODO" {
                current = ImportedTask(title: "")
                completed = false
                continue
            }
            if line == "END:VTODO" {
                if let task = current, !task.title.isEmpty, !completed { tasks.append(task) }
                current = nil
                continue
            }
            guard current != nil, let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].split(separator: ";").first.map(String.init)?.uppercased() ?? ""
            let params = String(line[..<colon]).uppercased()
            let value = unescapeICS(String(line[line.index(after: colon)...]))

            switch key {
            case "SUMMARY": current?.title = value
            case "DESCRIPTION": current?.notes = value
            case "CATEGORIES": current?.tags += value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "DUE": current?.due = parseICSDate(value, dateOnly: params.contains("VALUE=DATE") && !params.contains("DATE-TIME"), calendar: calendar)
            case "PRIORITY":
                // iCalendar: 1 = höchste, 9 = niedrigste, 0 = keine
                current?.priority = ImportMapping.priority(fromICalendar: Int(value) ?? 0)
            case "STATUS": completed = value.uppercased() == "COMPLETED"
            case "COMPLETED": completed = true
            default: break
            }
        }
        return tasks
    }

    static func unescapeICS(_ value: String) -> String {
        value.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    static func parseICSDate(_ value: String, dateOnly: Bool, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        if dateOnly || value.count == 8 {
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyyMMdd"
            guard let date = formatter.date(from: String(value.prefix(8))) else { return nil }
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)
        }
        if value.hasSuffix("Z") {
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        } else {
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        }
        return formatter.date(from: value)
    }
}

/// Übersetzt Prioritäten und Wiederholungen anderer Apps.
enum ImportMapping {
    /// iCalendar/EventKit: 1–4 hoch, 5 mittel, 6–9 niedrig, 0 keine.
    static func priority(fromICalendar value: Int) -> Priority {
        switch value {
        case 1...4: return .high
        case 5: return .medium
        case 6...9: return .low
        default: return .none
        }
    }

    enum Frequency { case daily, weekly, monthly, yearly }

    static func recurrence(frequency: Frequency?, interval: Int) -> Recurrence {
        switch (frequency, interval) {
        case (.daily?, 1): return .daily
        case (.weekly?, 1): return .weekly
        case (.weekly?, 2): return .biweekly
        case (.daily?, 7): return .weekly
        case (.daily?, 14): return .biweekly
        case (.monthly?, 1): return .monthly
        case (.yearly?, 1): return .yearly
        default: return .none
        }
    }
}
