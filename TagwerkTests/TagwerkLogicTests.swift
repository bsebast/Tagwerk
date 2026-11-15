import Foundation
import Testing
@testable import Tagwerk

private struct Stub: SmartSortable {
    let name: String
    var sortDueDate: Date?
    var sortPriority: Int = 0
    var sortCreatedAt: Date = Date(timeIntervalSince1970: 0)
}

@Suite("Automatische Sortierung")
struct SmartSortTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let window: TimeInterval = 24 * 3_600

    @Test func overdueThenUpcomingThenRest() {
        let items = [
            Stub(name: "später", sortDueDate: now.addingTimeInterval(3 * 86_400), sortPriority: 3),
            Stub(name: "ohne Datum", sortDueDate: nil, sortPriority: 3),
            Stub(name: "bald", sortDueDate: now.addingTimeInterval(3_600)),
            Stub(name: "überfällig", sortDueDate: now.addingTimeInterval(-60)),
        ]
        let sorted = SmartSort.sorted(items, now: now, window: window).map(\.name)
        #expect(sorted == ["überfällig", "bald", "später", "ohne Datum"])
    }

    @Test func priorityWinsInsideBucket() {
        let items = [
            Stub(name: "niedrig früh", sortDueDate: now.addingTimeInterval(600), sortPriority: 1),
            Stub(name: "hoch spät", sortDueDate: now.addingTimeInterval(7_200), sortPriority: 3),
        ]
        #expect(SmartSort.sorted(items, now: now, window: window).map(\.name) == ["hoch spät", "niedrig früh"])
    }

    @Test func groupsSkipEmptyBuckets() {
        let items = [Stub(name: "a", sortDueDate: nil)]
        let groups = SmartSort.grouped(items, now: now, window: window)
        #expect(groups.map(\.bucket) == [.later])
    }
}

@Suite("Tag-Filter")
struct TagFilterTests {
    let a = UUID(), b = UUID(), c = UUID()

    @Test func andRequiresAllTags() {
        #expect(TagFilter.matches(itemTagIDs: [a, b], selected: [a, b], mode: .all))
        #expect(!TagFilter.matches(itemTagIDs: [a], selected: [a, b], mode: .all))
    }

    @Test func orRequiresOneTag() {
        #expect(TagFilter.matches(itemTagIDs: [a], selected: [a, c], mode: .any))
        #expect(!TagFilter.matches(itemTagIDs: [b], selected: [a, c], mode: .any))
    }

    @Test func emptySelectionShowsEverything() {
        #expect(TagFilter.matches(itemTagIDs: [], selected: [], mode: .all))
    }
}

@Suite("Tag-Vorschläge")
struct TagSuggesterTests {
    let shopping = TagCandidate(id: UUID(), name: "Einkauf", keywords: ["kaufen", "milch"], usageCount: 0)
    let health = TagCandidate(id: UUID(), name: "Gesundheit", keywords: ["zahnarzt", "arzt"], usageCount: 5)

    @Test func keywordMatch() {
        let ids = TagSuggester.suggestions(for: "Milch holen", candidates: [shopping, health])
        #expect(ids == [shopping.id])
    }

    @Test func compoundWordAndUmlautFolding() {
        #expect(TagSuggester.suggestions(for: "Zahnarzttermin", candidates: [shopping, health]) == [health.id])
        #expect(TagSuggester.suggestions(for: "Wocheneinkauf", candidates: [shopping, health]) == [shopping.id])
    }

    @Test func emptyTitleSuggestsMostUsed() {
        #expect(TagSuggester.suggestions(for: "", candidates: [shopping, health], limit: 1) == [health.id])
    }

    @Test func excludesAlreadySelected() {
        #expect(TagSuggester.suggestions(for: "Milch", candidates: [shopping], excluding: [shopping.id]).isEmpty)
    }
}

@Suite("Erinnerungen & Wiederholung")
struct ReminderAndRecurrenceTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func remindsRepeatedlyFromDueDate() {
        let due = now.addingTimeInterval(600)
        let dates = ReminderPlan.dates(due: due, now: now, interval: 900, remindUntilDone: true, maxCount: 3)
        #expect(dates == [due, due.addingTimeInterval(900), due.addingTimeInterval(1_800)])
    }

    @Test func overdueContinuesOnTheGrid() {
        let due = now.addingTimeInterval(-1_000)
        let dates = ReminderPlan.dates(due: due, now: now, interval: 900, remindUntilDone: true, maxCount: 1)
        #expect(dates == [due.addingTimeInterval(1_800)])
    }

    @Test func singleReminderInThePastIsDropped() {
        #expect(ReminderPlan.dates(due: now.addingTimeInterval(-1), now: now, interval: 900, remindUntilDone: false, maxCount: 5).isEmpty)
    }

    @Test func recurrenceSkipsMissedPeriods() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let due = now.addingTimeInterval(-2.5 * 86_400)
        let next = Recurrence.daily.nextOccurrence(from: due, now: now, calendar: calendar)
        #expect(next == due.addingTimeInterval(3 * 86_400))
    }
}
