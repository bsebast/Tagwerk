import Foundation
import UserNotifications
import CoreLocation

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

    // MARK: Orts-Mitteilungen

    /// Ein Orts-Tag mit „Mitteilung beim Ankommen“.
    struct LocationPayload {
        let tagID: UUID
        let name: String
        let latitude: Double
        let longitude: Double
        let radius: Double
        let openCount: Int
    }

    static let locationPrefix = "loc-"
    static let maxLocationReminders = 20

    static func locationIdentifier(for tagID: UUID) -> String { "\(locationPrefix)\(tagID.uuidString)" }

    /// Meldet sich jedes Mal, wenn das iPhone den Umkreis betritt (benötigt nur „Beim Verwenden der App“).
    static func scheduleLocation(_ payload: LocationPayload) {
        let identifier = locationIdentifier(for: payload.tagID)
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: payload.latitude, longitude: payload.longitude),
            radius: max(payload.radius, 100),
            identifier: identifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false

        let content = UNMutableNotificationContent()
        content.title = "In der Nähe: \(payload.name)"
        content.body = payload.openCount == 1 ? "1 offene Aufgabe" : "\(payload.openCount) offene Aufgaben"
        content.sound = .default
        content.userInfo = ["tagID": payload.tagID.uuidString]

        let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }

    /// Ersetzt nur die Orts-Mitteilungen (z. B. nachdem sich die Zahl offener Aufgaben geändert hat).
    static func replaceLocationReminders(_ locations: [LocationPayload]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let old = requests.map(\.identifier).filter { $0.hasPrefix(locationPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for payload in locations.prefix(maxLocationReminders) {
                scheduleLocation(payload)
            }
        }
    }

    /// Plant alle Erinnerungen neu (beim App-Start und nach Änderung des Intervalls).
    /// Die am frühesten fälligen Aufgaben bekommen Vorrang vor dem 64er-Limit.
    static func rescheduleAll(_ payloads: [Payload], locations: [LocationPayload] = [], interval: TimeInterval, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let activeLocations = Array(locations.prefix(maxLocationReminders))
        activeLocations.forEach(scheduleLocation)

        var budget = globalLimit - activeLocations.count
        for payload in payloads.sorted(by: { $0.due < $1.due }) where budget > 0 {
            if !payload.remindUntilDone && payload.due <= now { continue }
            let count = payload.remindUntilDone ? min(repeatsPerItem, budget) : 1
            schedule(payload, interval: interval, now: now, maxCount: count)
            budget -= count
        }
    }
}
