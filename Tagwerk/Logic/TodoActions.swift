import Foundation
import SwiftData

/// Zentrale Aktionen auf Aufgaben, damit Liste, Editor, Import und Mitteilungen dasselbe tun.
@MainActor
enum TodoActions {
    static func payload(for item: TodoItem) -> ReminderScheduler.Payload? {
        guard !item.isDone, let due = item.dueDate else { return nil }
        return .init(id: item.uuid, title: item.title, due: due, remindUntilDone: item.remindUntilDone)
    }

    static func refreshReminders(for item: TodoItem) {
        if let payload = payload(for: item) {
            ReminderScheduler.schedule(payload, interval: AppSettings.reminderInterval)
        } else {
            ReminderScheduler.cancel(item.uuid)
        }
    }

    /// Nach jeder Änderung an einer Aufgabe: Erinnerungen, Kalendertermin und Orts-Mitteilungen aktualisieren.
    static func didChange(_ item: TodoItem, in context: ModelContext) {
        refreshReminders(for: item)
        CalendarSync.sync(item)
        refreshLocationReminders(in: context)
    }

    static func toggleDone(_ item: TodoItem, in context: ModelContext) {
        if item.isDone {
            item.isDone = false
            item.completedAt = nil
        } else {
            complete(item, in: context)
        }
        try? context.save()
        didChange(item, in: context)
    }

    /// Markiert als erledigt; bei Wiederholung entsteht die nächste Aufgabe automatisch.
    private static func complete(_ item: TodoItem, in context: ModelContext, now: Date = Date()) {
        item.isDone = true
        item.completedAt = now

        guard item.recurrence != .none,
              let due = item.dueDate,
              let nextDue = item.recurrence.nextOccurrence(from: due, now: now) else { return }

        let next = TodoItem(
            title: item.title,
            notes: item.notes,
            dueDate: nextDue,
            priority: item.priority,
            recurrence: item.recurrence,
            remindUntilDone: item.remindUntilDone
        )
        context.insert(next)
        next.tags = item.tags ?? []
        refreshReminders(for: next)
        CalendarSync.sync(next)
    }

    static func markDone(id: UUID, in context: ModelContext) {
        guard let item = fetch(id: id, in: context), !item.isDone else { return }
        toggleDone(item, in: context)
    }

    static func snooze(id: UUID, by interval: TimeInterval = 3_600, in context: ModelContext) {
        guard let item = fetch(id: id, in: context), !item.isDone else { return }
        item.dueDate = Date().addingTimeInterval(interval)
        try? context.save()
        didChange(item, in: context)
    }

    static func delete(_ item: TodoItem, in context: ModelContext) {
        ReminderScheduler.cancel(item.uuid)
        CalendarSync.remove(itemID: item.uuid)
        context.delete(item)
        try? context.save()
        refreshLocationReminders(in: context)
    }

    static func deleteCompleted(in context: ModelContext) {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.isDone })
        for item in (try? context.fetch(descriptor)) ?? [] {
            CalendarSync.remove(itemID: item.uuid)
            context.delete(item)
        }
        try? context.save()
    }

    // MARK: Orts-Tags

    static func locationPayloads(in context: ModelContext) -> [ReminderScheduler.LocationPayload] {
        let tags = (try? context.fetch(FetchDescriptor<TodoTag>(predicate: #Predicate { $0.locationNotify }))) ?? []
        return tags.compactMap { tag in
            guard let latitude = tag.latitude, let longitude = tag.longitude else { return nil }
            let open = tag.openItemCount
            guard open > 0 else { return nil }
            return .init(tagID: tag.uuid, name: tag.name, latitude: latitude, longitude: longitude,
                         radius: tag.radius, openCount: open)
        }
    }

    static func refreshLocationReminders(in context: ModelContext) {
        ReminderScheduler.replaceLocationReminders(locationPayloads(in: context))
    }

    // MARK: Alles neu planen

    static func rescheduleAll(in context: ModelContext) {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { !$0.isDone })
        let items = (try? context.fetch(descriptor)) ?? []
        ReminderScheduler.rescheduleAll(
            items.compactMap(payload(for:)),
            locations: locationPayloads(in: context),
            interval: AppSettings.reminderInterval
        )
    }

    static func fetch(id: UUID, in context: ModelContext) -> TodoItem? {
        var descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
