import Foundation
import SwiftData

/// Eine Aufgabe. Alle Aufgaben leben in einer einzigen Liste und werden über Tags gefiltert.
@Model
final class TodoItem {
    var uuid: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var dueDate: Date?
    var priorityRaw: Int = 0
    var isDone: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()
    var recurrenceRaw: String = "none"
    var remindUntilDone: Bool = true
    var tags: [TodoTag]? = []

    init(
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        priority: Priority = .none,
        recurrence: Recurrence = .none,
        remindUntilDone: Bool = true
    ) {
        self.uuid = UUID()
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priorityRaw = priority.rawValue
        self.recurrenceRaw = recurrence.rawValue
        self.remindUntilDone = remindUntilDone
        self.createdAt = Date()
        // Tags erst nach `context.insert(_:)` setzen (SwiftData-Beziehungen brauchen einen Kontext).
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? Priority.none }
        set { priorityRaw = newValue.rawValue }
    }

    var recurrence: Recurrence {
        get { Recurrence(rawValue: recurrenceRaw) ?? Recurrence.none }
        set { recurrenceRaw = newValue.rawValue }
    }

    var tagList: [TodoTag] {
        (tags ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var tagIDs: Set<UUID> {
        Set((tags ?? []).map(\.uuid))
    }
}

extension TodoItem: SmartSortable {
    var sortDueDate: Date? { dueDate }
    var sortPriority: Int { priorityRaw }
    var sortCreatedAt: Date { createdAt }
}
