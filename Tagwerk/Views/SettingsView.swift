import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @AppStorage(AppSettings.reminderIntervalKey) private var reminderMinutes = AppSettings.defaultReminderMinutes
    @AppStorage(AppSettings.upcomingHoursKey) private var upcomingHours = AppSettings.defaultUpcomingHours
    @AppStorage(AppSettings.showCompletedKey) private var showCompleted = false

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmCleanup = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Wiederholen alle", selection: $reminderMinutes) {
                        ForEach(AppSettings.reminderOptions, id: \.self) { Text(AppSettings.reminderLabel($0)).tag($0) }
                    }
                    notificationRow
                } header: {
                    Text("Erinnern bis erledigt")
                } footer: {
                    Text("Ab dem Fälligkeitszeitpunkt erinnert Tagwerk in diesem Abstand erneut, bis du die Aufgabe abhakst oder löschst.")
                }

                Section {
                    Picker("Zeitraum „Demnächst“", selection: $upcomingHours) {
                        ForEach(AppSettings.upcomingOptions, id: \.self) { Text("\($0) Stunden").tag($0) }
                    }
                    Toggle("Erledigte anzeigen", isOn: $showCompleted)
                } header: {
                    Text("Sortierung")
                } footer: {
                    Text("Reihenfolge: Überfälliges, dann alles im gewählten Zeitraum, dann der Rest – jeweils nach Priorität.")
                }

                Section {
                    Button("Erledigte Aufgaben löschen", role: .destructive) { confirmCleanup = true }
                        .confirmationDialog("Alle erledigten Aufgaben löschen?", isPresented: $confirmCleanup, titleVisibility: .visible) {
                            Button("Löschen", role: .destructive) { TodoActions.deleteCompleted(in: context) }
                        }
                } footer: {
                    Text("Deine Daten bleiben auf diesem iPhone. Kein Konto nötig.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task { notificationStatus = await ReminderScheduler.authorizationStatus() }
            .onChange(of: reminderMinutes) { _, _ in
                TodoActions.rescheduleAll(in: context)
            }
        }
    }

    @ViewBuilder
    private var notificationRow: some View {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            Label("Mitteilungen aktiv", systemImage: "bell.fill")
                .foregroundStyle(Palette.teal)
        case .denied:
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Label("Mitteilungen in den iOS-Einstellungen erlauben", systemImage: "bell.slash")
            }
        default:
            Button {
                Task {
                    _ = await ReminderScheduler.requestAuthorization()
                    notificationStatus = await ReminderScheduler.authorizationStatus()
                    TodoActions.rescheduleAll(in: context)
                }
            } label: {
                Label("Mitteilungen erlauben", systemImage: "bell.badge")
            }
        }
    }
}
