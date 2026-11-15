import SwiftUI
import SwiftData

/// Tag anlegen oder bearbeiten: Name, Symbol, Farbe, Stichwörter für Vorschläge und optional ein Ort.
struct TagEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTag.sortIndex) private var allTags: [TodoTag]

    let tag: TodoTag?
    var onCreate: ((TodoTag) -> Void)? = nil

    @State private var name: String
    @State private var symbol: String
    @State private var colorHex: String
    @State private var keywords: String
    @State private var place: TagLocationDraft

    init(tag: TodoTag?, onCreate: ((TodoTag) -> Void)? = nil) {
        self.tag = tag
        self.onCreate = onCreate
        _name = State(initialValue: tag?.name ?? "")
        _symbol = State(initialValue: tag?.symbol ?? "tag")
        _colorHex = State(initialValue: tag?.colorHex ?? Palette.tagColors.randomElement() ?? "#0F766E")
        _keywords = State(initialValue: tag?.keywordsRaw ?? "")
        _place = State(initialValue: TagLocationDraft(tag: tag))
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private let grid = [GridItem(.adaptive(minimum: 44), spacing: 10)]

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    TagChip(name: trimmedName.isEmpty ? "Vorschau" : trimmedName, symbol: symbol,
                            color: Color(hex: colorHex), isSelected: true)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Name") {
                TextField("z. B. Arbeit, Uni, Familie", text: $name)
            }

            Section("Farbe") {
                LazyVGrid(columns: grid, spacing: 10) {
                    ForEach(Palette.tagColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 34, height: 34)
                            .overlay {
                                if hex == colorHex {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { colorHex = hex }
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Symbol") {
                LazyVGrid(columns: grid, spacing: 10) {
                    ForEach(Palette.tagSymbols, id: \.self) { candidate in
                        Image(systemName: candidate)
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .foregroundStyle(candidate == symbol ? Color.white : Color(hex: colorHex))
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(candidate == symbol ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.12))
                            )
                            .onTapGesture { symbol = candidate }
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                TextField("z. B. meeting, büro, kunde", text: $keywords, axis: .vertical)
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Stichwörter")
            } footer: {
                Text("Enthält ein Aufgabentitel eines dieser Wörter, schlägt Tagwerk diesen Tag vor. Mehrere Wörter mit Komma trennen.")
            }

            TagLocationSection(draft: $place, color: Color(hex: colorHex), name: trimmedName)
        }
        .navigationTitle(tag == nil ? "Neuer Tag" : "Tag bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") { save() }
                    .disabled(trimmedName.isEmpty)
            }
        }
    }

    private func save() {
        if let tag {
            tag.name = trimmedName
            tag.symbol = symbol
            tag.colorHex = colorHex
            tag.keywordsRaw = keywords
            place.apply(to: tag)
        } else {
            let newTag = TodoTag(name: trimmedName, symbol: symbol, colorHex: colorHex, sortIndex: (allTags.map(\.sortIndex).max() ?? -1) + 1)
            newTag.keywordsRaw = keywords
            place.apply(to: newTag)
            context.insert(newTag)
            onCreate?(newTag)
        }
        try? context.save()
        if place.coordinate != nil {
            LocationService.shared.start()
        }
        TodoActions.refreshLocationReminders(in: context)
        dismiss()
    }
}
