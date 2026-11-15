import Foundation

/// Zeitliche Gruppe einer offenen Aufgabe.
enum DueBucket: Int, CaseIterable, Comparable, Hashable {
    case overdue = 0
    case upcoming = 1
    case later = 2

    static func < (lhs: DueBucket, rhs: DueBucket) -> Bool { lhs.rawValue < rhs.rawValue }

    func title(upcomingHours: Int) -> String {
        switch self {
        case .overdue: return "Überfällig"
        case .upcoming: return "Nächste \(upcomingHours) Std."
        case .later: return "Alles andere"
        }
    }

    var symbol: String {
        switch self {
        case .overdue: return "exclamationmark.circle.fill"
        case .upcoming: return "clock.fill"
        case .later: return "tray.full.fill"
        }
    }
}

/// Alles, was die automatische Sortierung braucht. So lässt sich die Logik ohne SwiftData testen.
protocol SmartSortable {
    var sortDueDate: Date? { get }
    var sortPriority: Int { get }
    var sortCreatedAt: Date { get }
}

struct BucketGroup<Element>: Identifiable {
    let bucket: DueBucket
    let items: [Element]
    var id: Int { bucket.rawValue }
}

/// Automatische Sortierung: Überfälliges zuerst, dann alles in den nächsten Stunden,
/// dann der Rest. Innerhalb jeder Gruppe: höhere Priorität zuerst, dann früheres Datum
/// (Aufgaben mit Datum vor solchen ohne), dann ältere Aufgaben zuerst.
enum SmartSort {
    static func bucket(for due: Date?, now: Date, window: TimeInterval) -> DueBucket {
        guard let due else { return .later }
        if due < now { return .overdue }
        if due <= now.addingTimeInterval(window) { return .upcoming }
        return .later
    }

    static func areInIncreasingOrder<T: SmartSortable>(_ a: T, _ b: T, now: Date, window: TimeInterval) -> Bool {
        let bucketA = bucket(for: a.sortDueDate, now: now, window: window)
        let bucketB = bucket(for: b.sortDueDate, now: now, window: window)
        if bucketA != bucketB { return bucketA < bucketB }

        if a.sortPriority != b.sortPriority { return a.sortPriority > b.sortPriority }

        switch (a.sortDueDate, b.sortDueDate) {
        case let (dateA?, dateB?) where dateA != dateB:
            return dateA < dateB
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            break
        }
        return a.sortCreatedAt < b.sortCreatedAt
    }

    static func sorted<T: SmartSortable>(_ items: [T], now: Date, window: TimeInterval) -> [T] {
        items.sorted { areInIncreasingOrder($0, $1, now: now, window: window) }
    }

    static func grouped<T: SmartSortable>(_ items: [T], now: Date, window: TimeInterval) -> [BucketGroup<T>] {
        let sortedItems = sorted(items, now: now, window: window)
        return DueBucket.allCases.compactMap { bucket in
            let members = sortedItems.filter {
                self.bucket(for: $0.sortDueDate, now: now, window: window) == bucket
            }
            return members.isEmpty ? nil : BucketGroup(bucket: bucket, items: members)
        }
    }
}
