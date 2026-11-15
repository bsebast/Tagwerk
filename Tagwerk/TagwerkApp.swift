import SwiftUI
import SwiftData
import UserNotifications

@main
struct TagwerkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Persistence.container)
    }
}

/// Startet die App, legt beim ersten Start Tags an und hält Erinnerungen aktuell.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TaskListView()
            .tint(Palette.teal)
            .task {
                SeedData.seedIfNeeded(context)
                SeedData.mergeDuplicateTags(context)
                _ = await ReminderScheduler.requestAuthorization()
                TodoActions.rescheduleAll(in: context)
                CalendarSync.syncAll(in: context)
                startLocationIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    SeedData.mergeDuplicateTags(context)
                    TodoActions.rescheduleAll(in: context)
                    CalendarSync.syncAll(in: context)
                    startLocationIfNeeded()
                case .background:
                    LocationService.shared.stop()
                default:
                    break
                }
            }
    }

    /// Standort nur verwenden, wenn mindestens ein Tag einen Ort hat.
    private func startLocationIfNeeded() {
        let tags = (try? context.fetch(FetchDescriptor<TodoTag>())) ?? []
        if tags.contains(where: \.hasLocation) {
            LocationService.shared.start()
        }
    }
}

/// Reagiert auf die Aktionen „Erledigt“ und „In 1 Stunde“ direkt in der Mitteilung.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderScheduler.registerCategories()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        guard let idString = info[ReminderScheduler.userInfoKey] as? String,
              let id = UUID(uuidString: idString) else {
            completionHandler()
            return
        }
        let action = response.actionIdentifier
        Task { @MainActor in
            let context = Persistence.container.mainContext
            switch action {
            case ReminderScheduler.doneActionID:
                TodoActions.markDone(id: id, in: context)
            case ReminderScheduler.snoozeActionID:
                TodoActions.snooze(id: id, in: context)
            default:
                break
            }
            completionHandler()
        }
    }
}
