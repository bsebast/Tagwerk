import Foundation
import UserNotifications

/// Plant lokale Mitteilungen. Nichts verlässt das Gerät.
enum ReminderScheduler {
    static let categoryID = "TAGWERK_REMINDER"
    static let doneActionID = "TAGWERK_MARK_DONE"
    static let snoozeActionID = "TAGWERK_SNOOZE"
    static let userInfoKey = "todoID"

    /// Pro Aufgabe geplante Wiederholungen; insgesamt erlaubt iOS 64 ausstehende Mitteilungen.
    static let repeatsPerItem = 8
    static let globalLimit = 60

    struct Payload {
        let id: UUID
        let title: String
        let due: Date
        let remindUntilDone: Bool
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func registerCategories() {
        let done = UNNotificationAction(identifier: doneActionID, title: "Erledigt", options: [])
        let snooze = UNNotificationAction(identifier: snoozeActionID, title: "In 1 Stunde", options: [])
        let category = UNNotificationCategory(identifier: categoryID, actions: [done, snooze], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func identifiers(for id: UUID) -> [String] {
        (0..<repeatsPerItem).map { "\(id.uuidString)#\($0)" }
    }

    static func cancel(_ id: UUID) {
        let ids = identifiers(for: id)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    static func schedule(_ payload: Payload, interval: TimeInterval, now: Date = Date(), maxCount: Int = repeatsPerItem) {
        cancel(payload.id)
        let dates = ReminderPlan.dates(
            due: payload.due,
            now: now,
            interval: interval,
            remindUntilDone: payload.remindUntilDone,
            maxCount: min(maxCount, repeatsPerItem)
        )
        let center = UNUserNotificationCenter.current()
        for (index, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = payload.title
            content.body = index == 0 ? "Jetzt fällig" : "Immer noch offen – \(index + 1). Erinnerung"
            content.sound = .default
            content.categoryIdentifier = categoryID
            content.threadIdentifier = payload.id.uuidString
            content.userInfo = [userInfoKey: payload.id.uuidString]

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "\(payload.id.uuidString)#\(index)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    /// Plant alle Erinnerungen neu (beim App-Start und nach Änderung des Intervalls).
    /// Die am frühesten fälligen Aufgaben bekommen Vorrang vor dem 64er-Limit.
    static func rescheduleAll(_ payloads: [Payload], interval: TimeInterval, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        var budget = globalLimit
        for payload in payloads.sorted(by: { $0.due < $1.due }) where budget > 0 {
            let count = payload.remindUntilDone ? min(repeatsPerItem, budget) : 1
            if !payload.remindUntilDone && payload.due <= now { continue }
            schedule(payload, interval: interval, now: now, maxCount: count)
            budget -= count
        }
    }
}
