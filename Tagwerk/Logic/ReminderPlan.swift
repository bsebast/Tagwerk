import Foundation

/// Berechnet, wann Erinnerungen ausgelöst werden („Erinnern bis erledigt“).
enum ReminderPlan {
    /// - Parameters:
    ///   - due: Fälligkeitszeitpunkt.
    ///   - interval: Abstand zwischen Wiederholungen (Sekunden).
    ///   - remindUntilDone: `false` = nur eine Erinnerung zum Fälligkeitszeitpunkt.
    ///   - maxCount: Obergrenze, da iOS nur 64 ausstehende Mitteilungen pro App erlaubt.
    ///     Beim nächsten App-Start wird nachgeplant.
    static func dates(due: Date, now: Date, interval: TimeInterval, remindUntilDone: Bool, maxCount: Int) -> [Date] {
        guard maxCount > 0 else { return [] }
        guard remindUntilDone, interval > 0 else {
            return due > now ? [due] : []
        }

        var first = due
        if first <= now {
            let missed = Int((now.timeIntervalSince(due) / interval).rounded(.down)) + 1
            first = due.addingTimeInterval(Double(missed) * interval)
        }
        return (0..<maxCount).map { first.addingTimeInterval(Double($0) * interval) }
    }
}
