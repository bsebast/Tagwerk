import SwiftUI
import SwiftData

/// Schnelles Erfassen am unteren Rand. Aktive Filter-Tags werden automatisch übernommen,
/// passende Tags werden beim Tippen vorgeschlagen.
struct QuickAddBar: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTag.sortIndex) private var tags: [TodoTag]
    @ObservedObject private var location = LocationService.shared

    let presetTagIDs: Set<UUID>
    let onOpenEditor: () -> Void

    @State private var title = ""
    @State private var chosenTagIDs: Set<UUID> = []
    @FocusState private var isFocused: Bool

    private var appliedTagIDs: Set<UUID> { presetTagIDs.union(chosenTagIDs) }

    /// Orts-Tags in der Nähe zuerst, dann Tags, die zum Titel passen.
    private var suggestions: [TodoTag] {
        let nearby = tags.filter {
            $0.locationSuggest && $0.isNear(location.lastLocation) && !appliedTagIDs.contains($0.uuid)
        }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nearby }
        let excluded = appliedTagIDs.union(nearby.map(\.uuid))
        let ids = TagSuggester.suggestions(for: trimmed, candidates: tags.map(\.candidate), excluding: excluded, limit: 3)
        return nearby + ids.compactMap { id in tags.first { $0.uuid == id } }
    }

    private var appliedTags: [TodoTag] {
        tags.filter { appliedTagIDs.contains($0.uuid) }
    }

    var body: some View {
        VStack(spacing: 8) {
            if isFocused && (!appliedTags.isEmpty || !suggestions.isEmpty) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(appliedTags) { tag in
                            Button {
                                chosenTagIDs.remove(tag.uuid)
                            } label: {
                                TagChip(tag: tag, isSelected: true, compact: true)
                            }
                            .disabled(presetTagIDs.contains(tag.uuid))
                        }
                        ForEach(suggestions) { tag in
                            Button {
                                chosenTagIDs.insert(tag.uuid)
                            } label: {
                                TagChip(tag: tag, isSuggested: true, compact: true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.teal)
                TextField("Neue Aufgabe …", text: $title)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(add)
                if !title.isEmpty {
                    Button(action: add) {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                    .accessibilityLabel("Hinzufügen")
                } else {
                    Button(action: onOpenEditor) {
                        Image(systemName: "slider.horizontal.3").font(.title3)
                    }
                    .accessibilityLabel("Aufgabe mit Details anlegen")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
        .animation(.snappy, value: isFocused)
    }

    private func add() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed)
        context.insert(item)
        item.tags = tags.filter { appliedTagIDs.contains($0.uuid) }
        try? context.save()
        TodoActions.didChange(item, in: context)
        title = ""
        chosenTagIDs.removeAll()
    }
}
