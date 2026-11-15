import SwiftUI
import SwiftData

/// Übersicht aller Tags: sortieren, bearbeiten, löschen.
struct TagManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTag.sortIndex) private var tags: [TodoTag]
    @State private var showNewTag = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tags) { tag in
                        NavigationLink {
                            TagEditorView(tag: tag)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: tag.symbol)
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tag.color))
                                Text(tag.name)
                                Spacer()
                                Text("\(tag.openItemCount)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                } footer: {
                    Text("Tags ersetzen Listen. Eine Aufgabe kann mehrere Tags haben. Gelöschte Tags entfernen keine Aufgaben.")
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Neuer Tag", systemImage: "plus") { showNewTag = true }
                        .labelStyle(.titleAndIcon)
                }
            }
            .sheet(isPresented: $showNewTag) {
                NavigationStack { TagEditorView(tag: nil) }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = tags
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, tag) in ordered.enumerated() {
            tag.sortIndex = index
        }
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(tags[index])
        }
        try? context.save()
    }
}
