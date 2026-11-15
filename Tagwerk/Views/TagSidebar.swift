import SwiftUI

/// Seitenleiste für das iPad: „Alle Aufgaben“ und alle Tags mit Anzahl offener Aufgaben.
/// Antippen eines Tags filtert die Liste (Mehrfachauswahl, UND/ODER).
struct TagSidebar: View {
    let tags: [TodoTag]
    let openCount: Int
    @Binding var selected: Set<UUID>
    @Binding var mode: FilterMode
    var onEditTag: (TodoTag) -> Void
    var onManageTags: () -> Void

    var body: some View {
        List {
            Section {
                Button {
                    withAnimation(.snappy) { selected.removeAll() }
                } label: {
                    row(name: "Alle Aufgaben", symbol: "square.stack", color: Palette.teal,
                        count: openCount, isSelected: selected.isEmpty)
                }
                .listRowBackground(selected.isEmpty ? Palette.teal.opacity(0.14) : nil)
            }

            Section {
                ForEach(tags) { tag in
                    Button {
                        withAnimation(.snappy) {
                            if selected.contains(tag.uuid) {
                                selected.remove(tag.uuid)
                            } else {
                                selected.insert(tag.uuid)
                            }
                        }
                    } label: {
                        row(name: tag.name, symbol: tag.symbol, color: tag.color,
                            count: tag.openItemCount, isSelected: selected.contains(tag.uuid))
                    }
                    .listRowBackground(selected.contains(tag.uuid) ? tag.color.opacity(0.14) : nil)
                    .contextMenu {
                        Button("Tag bearbeiten", systemImage: "pencil") { onEditTag(tag) }
                    }
                }
            } header: {
                Text("Tags")
            } footer: {
                if selected.count < 2 {
                    Text("Mehrere Tags antippen, um sie zu kombinieren.")
                }
            }

            if selected.count >= 2 {
                Section("Kombinieren") {
                    Picker("Kombinieren", selection: $mode) {
                        ForEach(FilterMode.allCases) { Text($0.shortLabel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
        .listStyle(.sidebar)
        .buttonStyle(.plain)
        .navigationTitle("Tagwerk")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Tags verwalten", systemImage: "slider.horizontal.3", action: onManageTags)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    private func row(name: String, symbol: String, color: Color, count: Int, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color))
            Text(name)
                .fontWeight(isSelected ? .semibold : .regular)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Image(systemName: "checkmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(color)
                .opacity(isSelected ? 1 : 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
