import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Aufgaben aus anderen Apps übernehmen. Wiederholbar, Duplikate werden übersprungen.
struct ImportView: View {
    @Environment(\.modelContext) private var context

    @State private var showFilePicker = false
    @State private var isWorking = false
    @State private var resultText: String?
    @State private var errorText: String?

    private static let fileTypes: [UTType] = {
        var types: [UTType] = [.plainText, .commaSeparatedText, .text, .utf8PlainText]
        if let ics = UTType(filenameExtension: "ics") { types.append(ics) }
        return types
    }()

    var body: some View {
        Form {
            Section {
                Button {
                    Task { await importReminders() }
                } label: {
                    Label("Aus Apple Erinnerungen", systemImage: "checklist")
                }
            } footer: {
                Text("Übernimmt alle offenen Erinnerungen. Listen werden zu Tags, Fälligkeit, Notizen, Priorität und Wiederholung werden mitgenommen.")
            }

            Section {
                Button {
                    showFilePicker = true
                } label: {
                    Label("Aus Datei (Text, CSV, .ics)", systemImage: "doc.text")
                }
            } footer: {
                Text("""
                **Text:** eine Aufgabe pro Zeile, z. B. aus Notizen. „#einkauf“ wird zum Tag, abgehakte Zeilen („[x]“) werden übersprungen.
                **CSV:** Exporte aus Todoist, TickTick, Microsoft To Do oder Excel. Spalten wie Titel, Datum, Tags/Projekt, Priorität und Notizen werden erkannt.
                **.ics:** Aufgaben (VTODO) aus Outlook oder anderen Kalendern.
                """)
            }

            if let resultText {
                Section {
                    Label(resultText, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Palette.teal)
                }
            }
            if let errorText {
                Section {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.coral)
                }
            }

            Section {
                Text("Der Import kann jederzeit wiederholt werden; bereits übernommene Aufgaben werden übersprungen. Änderungen in Tagwerk wirken nicht zurück auf die Quelle.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Importieren")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isWorking)
        .overlay {
            if isWorking { ProgressView("Importiere …").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: Self.fileTypes, allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                run { try ImportService.importFile(at: url, into: context) }
            case .failure(let error):
                errorText = error.localizedDescription
            }
        }
    }

    private func importReminders() async {
        isWorking = true
        resultText = nil
        errorText = nil
        defer { isWorking = false }
        do {
            resultText = try await ImportService.importReminders(into: context).summary
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func run(_ work: () throws -> ImportResult) {
        resultText = nil
        errorText = nil
        do {
            resultText = try work().summary
        } catch {
            errorText = error.localizedDescription
        }
    }
}
