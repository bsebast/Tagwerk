import SwiftUI
import SwiftData
import CoreLocation

/// Die eine Liste: alle Aufgaben, automatisch sortiert, per Tags gefiltert.
/// iPhone: Tag-Leiste oben. iPad (breite Ansicht): Tags in der Seitenleiste, Liste rechts.
struct TaskListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \TodoTag.sortIndex) private var tags: [TodoTag]
    @Query private var items: [TodoItem]

    @AppStorage(AppSettings.filterModeKey) private var filterModeRaw = FilterMode.all.rawValue
    @AppStorage(AppSettings.upcomingHoursKey) private var upcomingHours = AppSettings.defaultUpcomingHours
    @AppStorage(AppSettings.showCompletedKey) private var showCompleted = false

    @State private var selectedTagIDs: Set<UUID> = []
    @State private var searchText = ""
    @State private var editingItem: TodoItem?
    @State private var isCreating = false
    @State private var editingTag: TodoTag?
    @State private var showTagManager = false
    @State private var showSettings = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// Tags, die der Orts-Filter automatisch gesetzt hat (damit er sie beim Verlassen wieder entfernt).
    @State private var autoFilterTagIDs: Set<UUID> = []
    @ObservedObject private var location = LocationService.shared

    private var isWide: Bool { sizeClass == .regular }

    private var filterMode: Binding<FilterMode> {
        Binding(
            get: { FilterMode(rawValue: filterModeRaw) ?? .all },
            set: { filterModeRaw = $0.rawValue }
        )
    }

    private var window: TimeInterval { TimeInterval(upcomingHours) * 3_600 }

    private var visibleItems: [TodoItem] {
        items.filter {
            TagFilter.matches(itemTagIDs: $0.tagIDs, selected: selectedTagIDs, mode: filterMode.wrappedValue)
                && TagFilter.matches(title: $0.title, notes: $0.notes, search: searchText)
        }
    }

    /// Titel der Liste; auf dem iPad zeigt er den aktiven Filter.
    private var listTitle: String {
        guard isWide, !selectedTagIDs.isEmpty else { return "Tagwerk" }
        let names = tags.filter { selectedTagIDs.contains($0.uuid) }.map(\.name)
        let separator = filterMode.wrappedValue == .all ? " + " : " / "
        return names.joined(separator: separator)
    }

    var body: some View {
        Group {
            if isWide {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    TagSidebar(
                        tags: tags,
                        openCount: items.filter { !$0.isDone }.count,
                        selected: $selectedTagIDs,
                        mode: filterMode,
                        onEditTag: { editingTag = $0 },
                        onManageTags: { showTagManager = true }
                    )
                    .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
                } detail: {
                    NavigationStack { mainList }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack { mainList }
            }
        }
        .sheet(item: $editingItem) { item in
            TaskEditorView(item: item)
        }
        .sheet(isPresented: $isCreating) {
            TaskEditorView(item: nil, presetTagIDs: selectedTagIDs)
        }
        .sheet(item: $editingTag) { tag in
            NavigationStack { TagEditorView(tag: tag) }
        }
        .sheet(isPresented: $showTagManager) {
            TagManagerView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onReceive(location.$lastLocation) { applyLocationFilter($0) }
    }

    /// Orts-Tags mit „Liste automatisch filtern“: beim Ankommen filtern, beim Verlassen wieder lösen.
    /// Hebt man den Filter von Hand auf, bleibt er aus, bis man den Ort verlässt und wiederkommt.
    private func applyLocationFilter(_ current: CLLocation?) {
        let nearby = Set(tags.filter { $0.locationAutoFilter && $0.isNear(current) }.map(\.uuid))
        guard nearby != autoFilterTagIDs else { return }
        let left = autoFilterTagIDs.subtracting(nearby)
        let entered = nearby.subtracting(autoFilterTagIDs)
        withAnimation(.snappy) {
            selectedTagIDs.subtract(left)
            selectedTagIDs.formUnion(entered)
        }
        autoFilterTagIDs = nearby
    }

    private var mainList: some View {
        TimelineView(.everyMinute) { timeline in
            content(now: timeline.date)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !isWide {
                TagFilterBar(tags: tags, selected: $selectedTagIDs, mode: filterMode) { editingTag = $0 }
                    .background(.bar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QuickAddBar(presetTagIDs: selectedTagIDs, onOpenEditor: { isCreating = true })
                .frame(maxWidth: isWide ? 720 : .infinity)
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
        .navigationTitle(listTitle)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Aufgaben durchsuchen")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Einstellungen")
                    .keyboardShortcut(",", modifiers: .command)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Toggle("Erledigte anzeigen", systemImage: "checkmark.circle", isOn: $showCompleted)
                    Picker("Mehrere Tags kombinieren", selection: filterMode) {
                        ForEach(FilterMode.allCases) { Text($0.label).tag($0) }
                    }
                    Divider()
                    Button("Tags verwalten", systemImage: "tag") { showTagManager = true }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Ansicht")

                if isWide {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Neue Aufgabe")
                }
            }
        }
        // Tastaturkürzel (iPad mit Tastatur): ⌘N neue Aufgabe, ⌘⇧T Tags verwalten.
        .background {
            Group {
                Button("Neue Aufgabe") { isCreating = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Tags verwalten") { showTagManager = true }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let open = visibleItems.filter { !$0.isDone }
        let done = visibleItems
            .filter(\.isDone)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        let groups = SmartSort.grouped(open, now: now, window: window)

        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.items) { item in
                        row(item, now: now)
                    }
                } header: {
                    Label("\(group.bucket.title(upcomingHours: upcomingHours)) · \(group.items.count)",
                          systemImage: group.bucket.symbol)
                        .foregroundStyle(color(for: group.bucket))
                        .font(.footnote.weight(.semibold))
                }
            }

            if showCompleted && !done.isEmpty {
                Section("Erledigt · \(done.count)") {
                    ForEach(done) { item in
                        row(item, now: now)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if open.isEmpty && (done.isEmpty || !showCompleted) {
                emptyState
            }
        }
        .animation(.default, value: items.map(\.isDone))
    }

    private func row(_ item: TodoItem, now: Date) -> some View {
        TaskRowView(item: item, now: now) {
            withAnimation { TodoActions.toggleDone(item, in: context) }
        }
        .onTapGesture { editingItem = item }
        .contextMenu {
            Button(item.isDone ? "Als offen markieren" : "Erledigt", systemImage: item.isDone ? "arrow.uturn.backward" : "checkmark") {
                withAnimation { TodoActions.toggleDone(item, in: context) }
            }
            Button("Bearbeiten", systemImage: "pencil") { editingItem = item }
            Divider()
            Button("Löschen", systemImage: "trash", role: .destructive) {
                withAnimation { TodoActions.delete(item, in: context) }
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation { TodoActions.toggleDone(item, in: context) }
            } label: {
                Label(item.isDone ? "Offen" : "Erledigt", systemImage: item.isDone ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(Palette.teal)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { TodoActions.delete(item, in: context) }
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private func color(for bucket: DueBucket) -> Color {
        switch bucket {
        case .overdue: return Palette.coral
        case .upcoming: return Palette.amber
        case .later: return .secondary
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if !selectedTagIDs.isEmpty {
            ContentUnavailableView("Nichts mit diesen Tags",
                                   systemImage: "tag.slash",
                                   description: Text(isWide ? "Wähle links „Alle Aufgaben“, um wieder alles zu sehen."
                                                            : "Tippe auf „Alle“, um wieder alles zu sehen."))
        } else {
            ContentUnavailableView("Alles erledigt",
                                   systemImage: "checkmark.seal",
                                   description: Text("Neue Aufgaben einfach unten eintippen."))
        }
    }
}

#Preview("iPhone") {
    TaskListView()
        .modelContainer(Persistence.preview)
}
