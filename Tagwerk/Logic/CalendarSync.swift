import Foundation
import SwiftData
import EventKit
import SwiftUI

/// Zeigt Aufgaben mit Fälligkeitsdatum als Termine im eigenen Kalender „Tagwerk“.
/// Die Richtung ist nur Tagwerk → Kalender. Erledigte oder gelöschte Aufgaben verschwinden wieder.
@MainActor
enum CalendarSync {
    static let enabledKey = "calendarSyncEnabled"
    private static let calendarIDKey = "calendarSyncCalendarID"
    /// Termin-IDs pro Aufgabe, nur auf diesem Gerät (Termine gehören zum Kalender dieses Geräts).
    private static let eventIDsKey = "calendarSyncEventIDs"
    static let eventDuration: TimeInterval = 30 * 60

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    static func requestAccess() async -> Bool {
        (try? await EventStore.shared.requestFullAccessToEvents()) ?? false
    }

    private static var eventIDs: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: eventIDsKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: eventIDsKey) }
    }

    /// Eigener Kalender „Tagwerk“, wird bei Bedarf angelegt.
    private static func tagwerkCalendar() -> EKCalendar? {
        let store = EventStore.shared
        if let id = UserDefaults.standard.string(forKey: calendarIDKey),
           let calendar = store.calendar(withIdentifier: id) {
            return calendar
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "Tagwerk"
        calendar.cgColor = UIColor(Palette.teal).cgColor
        guard let source = store.defaultCalendarForNewEvents?.source
                ?? store.sources.first(where: { $0.sourceType == .local })
                ?? store.sources.first else { return nil }
        calendar.source = source
        do {
            try store.saveCalendar(calendar, commit: true)
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIDKey)
            return calendar
        } catch {
            return nil
        }
    }

    /// Termin der Aufgabe anlegen, aktualisieren oder entfernen.
    static func sync(_ item: TodoItem) {
        guard isEnabled, hasAccess else { return }
        let store = EventStore.shared
        let key = item.uuid.uuidString
        var ids = eventIDs
        let existing = ids[key].flatMap { store.event(withIdentifier: $0) }

        guard !item.isDone, let due = item.dueDate else {
            if let existing { try? store.remove(existing, span: .thisEvent, commit: true) }
            ids[key] = nil
            eventIDs = ids
            return
        }
        guard let calendar = tagwerkCalendar() else { return }

        let event = existing ?? EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = item.title
        event.notes = item.notes.isEmpty ? nil : item.notes
        event.startDate = due
        event.endDate = due.addingTimeInterval(eventDuration)
        do {
            try store.save(event, span: .thisEvent, commit: true)
            ids[key] = event.eventIdentifier
            eventIDs = ids
        } catch {
            // Kalender nicht beschreibbar: still ignorieren, die Aufgabe selbst bleibt unverändert.
        }
    }

    static func remove(itemID: UUID) {
        guard hasAccess else { return }
        var ids = eventIDs
        if let eventID = ids[itemID.uuidString], let event = EventStore.shared.event(withIdentifier: eventID) {
            try? EventStore.shared.remove(event, span: .thisEvent, commit: true)
        }
        ids[itemID.uuidString] = nil
        eventIDs = ids
    }

    static func syncAll(in context: ModelContext) {
        guard isEnabled, hasAccess else { return }
        let items = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let liveIDs = Set(items.map(\.uuid.uuidString))
        // Termine zu Aufgaben, die es nicht mehr gibt, aufräumen.
        for (itemID, _) in eventIDs where !liveIDs.contains(itemID) {
            if let uuid = UUID(uuidString: itemID) { remove(itemID: uuid) }
        }
        items.forEach(sync)
    }

    /// Ausschalten: Kalender „Tagwerk“ samt Terminen entfernen.
    static func disable() {
        let store = EventStore.shared
        if hasAccess,
           let id = UserDefaults.standard.string(forKey: calendarIDKey),
           let calendar = store.calendar(withIdentifier: id) {
            try? store.removeCalendar(calendar, commit: true)
        }
        UserDefaults.standard.removeObject(forKey: calendarIDKey)
        eventIDs = [:]
    }
}
