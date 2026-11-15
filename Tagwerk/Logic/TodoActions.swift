import Foundation
import SwiftData

/// Zentrale Aktionen auf Aufgaben, damit Liste, Editor und Mitteilungen dasselbe tun.
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

    static func toggleDone(_ item: TodoItem, in context: ModelContext) {
        if item.isDone {
            item.isDone = false
            item.completedAt = nil
        } else {
            complete(item, in: context)
        }
        refreshReminders(for: item)
        try? context.save()
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
    }

    static func markDone(id: UUID, in context: ModelContext) {
        guard let item = fetch(id: id, in: context), !item.isDone else { return }
        toggleDone(item, in: context)
    }

    static func snooze(id: UUID, by interval: TimeInterval = 3_600, in context: ModelContext) {
        guard let item = fetch(id: id, in: context), !item.isDone else { return }
        item.dueDate = Date().addingTimeInterval(interval)
        refreshReminders(for: item)
        try? context.save()
    }

    static func delete(_ item: TodoItem, in context: ModelContext) {
        ReminderScheduler.cancel(item.uuid)
        context.delete(item)
        try? context.save()
    }

    static func deleteCompleted(in context: ModelContext) {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.isDone })
        for item in (try? context.fetch(descriptor)) ?? [] {
            context.delete(item)
        }
        try? context.save()
    }

    static func rescheduleAll(in context: ModelContext) {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { !$0.isDone })
        let items = (try? context.fetch(descriptor)) ?? []
        ReminderScheduler.rescheduleAll(items.compactMap(payload(for:)), interval: AppSettings.reminderInterval)
    }

    static func fetch(id: UUID, in context: ModelContext) -> TodoItem? {
        var descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
