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

    @AppStorage(CalendarSync.enabledKey) private var calendarEnabled = false
    @ObservedObject private var location = LocationService.shared

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmCleanup = false
    @State private var calendarMessage: String?

    private var iCloudSignedIn: Bool { FileManager.default.ubiquityIdentityToken != nil }

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
                    Toggle("Fällige Aufgaben im Kalender", isOn: $calendarEnabled)
                    if let calendarMessage {
                        Text(calendarMessage).font(.footnote).foregroundStyle(Palette.coral)
                    }
                } header: {
                    Text("Kalender")
                } footer: {
                    Text("Tagwerk legt einen eigenen Kalender „Tagwerk“ an und trägt jede offene Aufgabe mit Datum als 30-Minuten-Termin ein. Erledigte Aufgaben verschwinden wieder. Ausschalten entfernt den Kalender. Bei mehreren Geräten am besten nur auf einem einschalten.")
                }

                Section {
                    locationRow
                } header: {
                    Text("Orte")
                } footer: {
                    Text("Orte legst du pro Tag fest (Tags verwalten → Tag → Ort). Der Standort wird nur auf dem Gerät verwendet.")
                }

                Section {
                    NavigationLink {
                        ImportView()
                    } label: {
                        Label("Aufgaben importieren", systemImage: "square.and.arrow.down")
                    }
                    LabeledContent {
                        Text(iCloudSignedIn ? "Angemeldet" : "Nicht angemeldet")
                            .foregroundStyle(iCloudSignedIn ? Palette.teal : .secondary)
                    } label: {
                        Label("iCloud", systemImage: "icloud")
                    }
                    Button("Erledigte Aufgaben löschen", role: .destructive) { confirmCleanup = true }
                        .confirmationDialog("Alle erledigten Aufgaben löschen?", isPresented: $confirmCleanup, titleVisibility: .visible) {
                            Button("Löschen", role: .destructive) { TodoActions.deleteCompleted(in: context) }
                        }
                } header: {
                    Text("Daten")
                } footer: {
                    Text("Deine Aufgaben liegen immer auf dem Gerät und funktionieren offline. Ist die App mit iCloud eingerichtet, gleichen iPhone und iPad sie automatisch über dein privates iCloud-Konto ab.")
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
            .onChange(of: calendarEnabled) { _, enabled in
                Task { await updateCalendar(enabled: enabled) }
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

    private func updateCalendar(enabled: Bool) async {
        calendarMessage = nil
        guard enabled else {
            CalendarSync.disable()
            return
        }
        if await CalendarSync.requestAccess() {
            CalendarSync.syncAll(in: context)
        } else {
            calendarEnabled = false
            calendarMessage = "Kein Kalenderzugriff. Bitte in den iOS-Einstellungen unter Tagwerk → Kalender „Vollzugriff“ erlauben."
        }
    }

    @ViewBuilder
    private var locationRow: some View {
        switch location.authorization {
        case .authorizedWhenInUse, .authorizedAlways:
            Label("Standort erlaubt", systemImage: "location.fill")
                .foregroundStyle(Palette.teal)
        case .denied, .restricted:
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Label("Standort in den iOS-Einstellungen erlauben", systemImage: "location.slash")
            }
        default:
            Button {
                location.start()
            } label: {
                Label("Standort erlauben", systemImage: "location")
            }
        }
    }
}
