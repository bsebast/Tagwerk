import SwiftUI

/// Horizontale Leiste mit allen Tags. Antippen filtert, ohne etwas zu verschieben.
struct TagFilterBar: View {
    let tags: [TodoTag]
    @Binding var selected: Set<UUID>
    @Binding var mode: FilterMode
    var onEditTag: (TodoTag) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.snappy) { selected.removeAll() }
                } label: {
                    TagChip(name: "Alle", symbol: "square.stack", color: Palette.teal, isSelected: selected.isEmpty)
                }

                if selected.count >= 2 {
                    Button {
                        withAnimation(.snappy) { mode = mode.toggled }
                    } label: {
                        Text(mode.shortLabel)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    .accessibilityLabel("Kombination: \(mode.label). Zum Wechseln tippen.")
                }

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
                        TagChip(tag: tag, isSelected: selected.contains(tag.uuid))
                    }
                    .contextMenu {
                        Button("Tag bearbeiten", systemImage: "pencil") { onEditTag(tag) }
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
