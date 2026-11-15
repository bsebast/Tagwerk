import SwiftUI
import SwiftData

/// Anlegen und Bearbeiten einer Aufgabe mit allen Details.
struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTag.sortIndex) private var allTags: [TodoTag]
    @AppStorage(AppSettings.reminderIntervalKey) private var reminderMinutes = AppSettings.defaultReminderMinutes

    let item: TodoItem?

    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var priority: Priority
    @State private var recurrence: Recurrence
    @State private var remindUntilDone: Bool
    @State private var selectedTagIDs: Set<UUID>
    @State private var showNewTag = false
    @State private var confirmDelete = false

    init(item: TodoItem?, presetTagIDs: Set<UUID> = []) {
        self.item = item
        _title = State(initialValue: item?.title ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        _hasDueDate = State(initialValue: item?.dueDate != nil)
        _dueDate = State(initialValue: item?.dueDate ?? Self.defaultDueDate())
        _priority = State(initialValue: item?.priority ?? Priority.none)
        _recurrence = State(initialValue: item?.recurrence ?? Recurrence.none)
        _remindUntilDone = State(initialValue: item?.remindUntilDone ?? true)
        _selectedTagIDs = State(initialValue: item?.tagIDs ?? presetTagIDs)
    }

    /// Nächste volle Stunde.
    private static func defaultDueDate() -> Date {
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var suggestedIDs: Set<UUID> {
        guard !trimmedTitle.isEmpty else { return [] }
        return Set(TagSuggester.suggestions(for: trimmedTitle, candidates: allTags.map(\.candidate),
                                            excluding: selectedTagIDs, limit: 3))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Was ist zu tun?", text: $title, axis: .vertical)
                        .font(.title3)
                    TextField("Notizen", text: $notes, axis: .vertical)
                        .lineLimit(2...8)
                }

                Section {
                    FlowLayout(spacing: 8) {
                        ForEach(allTags) { tag in
                            let isSelected = selectedTagIDs.contains(tag.uuid)
                            Button {
                                if isSelected { selectedTagIDs.remove(tag.uuid) } else { selectedTagIDs.insert(tag.uuid) }
                            } label: {
                                TagChip(tag: tag, isSelected: isSelected, isSuggested: suggestedIDs.contains(tag.uuid))
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            showNewTag = true
                        } label: {
                            TagChip(name: "Neu", symbol: "plus", color: .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Tags")
                } footer: {
                    if !suggestedIDs.isEmpty {
                        Text("Gestrichelt markierte Tags passen zum Titel.")
                    }
                }

                Section("Fälligkeit") {
                    Toggle("Fälligkeitsdatum", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Fällig am", selection: $dueDate)
                        Picker("Wiederholen", selection: $recurrence) {
                            ForEach(Recurrence.allCases) { Text($0.label).tag($0) }
                        }
                        Toggle("Erinnern bis erledigt", isOn: $remindUntilDone)
                    }
                }

                Section {
                    Picker("Priorität", selection: $priority) {
                        ForEach(Priority.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Priorität")
                } footer: {
                    if hasDueDate && remindUntilDone {
                        Text("Tagwerk erinnert ab dem Fälligkeitszeitpunkt alle \(AppSettings.reminderLabel(reminderMinutes)), bis die Aufgabe erledigt oder gelöscht ist.")
                    }
                }

                if let item {
                    Section {
                        Button("Aufgabe löschen", role: .destructive) { confirmDelete = true }
                            .confirmationDialog("Aufgabe wirklich löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                                Button("Löschen", role: .destructive) {
                                    TodoActions.delete(item, in: context)
                                    dismiss()
                                }
                            }
                    }
                }
            }
            .navigationTitle(item == nil ? "Neue Aufgabe" : "Aufgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .sheet(isPresented: $showNewTag) {
                NavigationStack {
                    TagEditorView(tag: nil) { newTag in
                        selectedTagIDs.insert(newTag.uuid)
                    }
                }
            }
        }
    }

    private func save() {
        let target: TodoItem
        if let item {
            target = item
        } else {
            target = TodoItem(title: trimmedTitle)
            context.insert(target)
        }
        target.title = trimmedTitle
        target.notes = notes
        target.dueDate = hasDueDate ? dueDate : nil
        target.priority = priority
        target.recurrence = hasDueDate ? recurrence : .none
        target.remindUntilDone = remindUntilDone
        target.tags = allTags.filter { selectedTagIDs.contains($0.uuid) }
        try? context.save()
        TodoActions.refreshReminders(for: target)
        dismiss()
    }
}
