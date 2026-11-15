import Foundation
import SwiftData
import EventKit
import UIKit

/// Gemeinsamer EventKit-Speicher für Erinnerungen und Kalender.
@MainActor
enum EventStore {
    static let shared = EKEventStore()
}

enum ImportError: LocalizedError {
    case accessDenied
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Kein Zugriff. Bitte in den iOS-Einstellungen unter Datenschutz & Sicherheit erlauben."
        case .unreadableFile:
            return "Die Datei konnte nicht gelesen werden."
        }
    }
}

/// Legt importierte Aufgaben an. Wiederholte Importe überspringen bereits vorhandene Aufgaben.
/// Es ist ein einmaliges Übernehmen, kein Abgleich in beide Richtungen.
@MainActor
enum ImportService {
    // MARK: Apple Erinnerungen

    static func importReminders(into context: ModelContext) async throws -> ImportResult {
        let store = EventStore.shared
        let granted = (try? await store.requestFullAccessToReminders()) ?? false
        guard granted else { throw ImportError.accessDenied }

        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) }
        }

        var result = ImportResult()
        var knownIDs = existingExternalIDs(in: context)
        var tagsByName = existingTags(in: context)

        for reminder in reminders {
            let externalID = "reminders:" + (reminder.calendarItemExternalIdentifier ?? reminder.calendarItemIdentifier)
            guard !knownIDs.contains(externalID) else {
                result.skipped += 1
                continue
            }
            let title = (reminder.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let item = TodoItem(
                title: title,
                notes: reminder.notes ?? "",
                dueDate: dueDate(from: reminder.dueDateComponents),
                priority: ImportMapping.priority(fromICalendar: reminder.priority),
                recurrence: recurrence(from: reminder.recurrenceRules?.first)
            )
            item.externalID = externalID
            context.insert(item)

            if let list = reminder.calendar {
                let tag = findOrCreateTag(named: list.title, colorHex: hex(from: list.cgColor), symbol: "list.bullet",
                              in: context, cache: &tagsByName, result: &result)
                item.tags = [tag]
            }
            knownIDs.insert(externalID)
            result.imported += 1
        }
        try? context.save()
        TodoActions.rescheduleAll(in: context)
        CalendarSync.syncAll(in: context)
        return result
    }

    private static func dueDate(from components: DateComponents?) -> Date? {
        guard var components else { return nil }
        let calendar = components.calendar ?? .current
        if components.hour == nil {
            components.hour = 9
            components.minute = 0
        }
        return calendar.date(from: components)
    }

    private static func recurrence(from rule: EKRecurrenceRule?) -> Recurrence {
        guard let rule else { return .none }
        let frequency: ImportMapping.Frequency?
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: frequency = nil
        }
        return ImportMapping.recurrence(frequency: frequency, interval: rule.interval)
    }

    private static func hex(from cgColor: CGColor?) -> String {
        guard let cgColor else { return Palette.tagColors[0] }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(cgColor: cgColor).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func clamp(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", clamp(red), clamp(green), clamp(blue))
    }

    // MARK: Dateien (Text, CSV, .ics)

    static func importFile(at url: URL, into context: ModelContext) throws -> ImportResult {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.unreadableFile
        }
        let tasks = TextImport.parse(text, fileExtension: url.pathExtension)
        return apply(tasks, source: url.lastPathComponent, into: context)
    }

    static func apply(_ tasks: [ImportedTask], source: String, into context: ModelContext) -> ImportResult {
        var result = ImportResult()
        var knownIDs = existingExternalIDs(in: context)
        var tagsByName = existingTags(in: context)
        let openTitles = Set(
            ((try? context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { !$0.isDone }))) ?? [])
                .map { $0.title.lowercased() }
        )
        let paletteCount = Palette.tagColors.count

        for task in tasks {
            let dueKey = task.due.map { String(Int($0.timeIntervalSince1970)) } ?? "-"
            let externalID = "file:\(task.title.lowercased())|\(dueKey)"
            guard !knownIDs.contains(externalID), !openTitles.contains(task.title.lowercased()) else {
                result.skipped += 1
                continue
            }
            let item = TodoItem(title: task.title, notes: task.notes, dueDate: task.due, priority: task.priority)
            item.externalID = externalID
            context.insert(item)

            var tags: [TodoTag] = []
            for name in task.tags {
                let colorHex = Palette.tagColors[(tagsByName.count + result.newTags) % paletteCount]
                tags.append(findOrCreateTag(named: name, colorHex: colorHex, symbol: "tag", in: context, cache: &tagsByName, result: &result))
            }
            item.tags = tags
            knownIDs.insert(externalID)
            result.imported += 1
        }
        try? context.save()
        TodoActions.rescheduleAll(in: context)
        CalendarSync.syncAll(in: context)
        return result
    }

    // MARK: Hilfen

    private static func existingExternalIDs(in context: ModelContext) -> Set<String> {
        let items = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        return Set(items.compactMap(\.externalID))
    }

    private static func existingTags(in context: ModelContext) -> [String: TodoTag] {
        let tags = (try? context.fetch(FetchDescriptor<TodoTag>())) ?? []
        var map: [String: TodoTag] = [:]
        for tag in tags { map[TagSuggester.fold(tag.name)] = tag }
        return map
    }

    /// Projekte/Listen werden zu Tags; vorhandene Tags gleichen Namens werden wiederverwendet.
    private static func findOrCreateTag(
        named rawName: String,
        colorHex: String,
        symbol: String,
        in context: ModelContext,
        cache: inout [String: TodoTag],
        result: inout ImportResult
    ) -> TodoTag {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = TagSuggester.fold(name)
        if let existing = cache[key] { return existing }
        let tag = TodoTag(name: name.isEmpty ? "Import" : name, symbol: symbol, colorHex: colorHex, sortIndex: cache.count + 100)
        context.insert(tag)
        cache[key] = tag
        result.newTags += 1
        return tag
    }
}
