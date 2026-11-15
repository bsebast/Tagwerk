import Foundation

/// Wiederholungsregel einer Aufgabe.
enum Recurrence: String, CaseIterable, Identifiable, Codable {
    case none
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Nie"
        case .daily: return "Täglich"
        case .weekly: return "Wöchentlich"
        case .biweekly: return "Alle 2 Wochen"
        case .monthly: return "Monatlich"
        case .yearly: return "Jährlich"
        }
    }

    /// Nächster Termin genau eine Periode nach `date`.
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .none: return nil
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly: return calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }

    /// Nächster Termin, der nach `now` liegt. Verpasste Perioden werden übersprungen,
    /// damit sich bei längerer Pause keine Aufgaben stapeln.
    func nextOccurrence(from due: Date, now: Date, calendar: Calendar = .current) -> Date? {
        guard var next = nextDate(after: due, calendar: calendar) else { return nil }
        var guardCounter = 0
        while next <= now && guardCounter < 10_000 {
            guard let candidate = nextDate(after: next, calendar: calendar) else { return nil }
            next = candidate
            guardCounter += 1
        }
        return next
    }
}
