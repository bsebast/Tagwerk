import Foundation

/// Schlüssel und Standardwerte für @AppStorage / UserDefaults.
enum AppSettings {
    static let reminderIntervalKey = "reminderIntervalMinutes"
    static let upcomingHoursKey = "upcomingHours"
    static let filterModeKey = "filterMode"
    static let showCompletedKey = "showCompleted"
    static let didSeedKey = "didSeedDefaults"

    static let defaultReminderMinutes = 15
    static let defaultUpcomingHours = 24

    static let reminderOptions = [15, 30, 60, 120, 240]
    static let upcomingOptions = [6, 12, 24, 48, 72]

    static var reminderInterval: TimeInterval {
        let minutes = UserDefaults.standard.object(forKey: reminderIntervalKey) as? Int ?? defaultReminderMinutes
        return TimeInterval(max(minutes, 1) * 60)
    }

    static func reminderLabel(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) Minuten" : (minutes == 60 ? "1 Stunde" : "\(minutes / 60) Stunden")
    }
}
