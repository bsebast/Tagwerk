import Foundation
import SwiftData

/// Gemeinsamer Datenspeicher. Liegt immer lokal auf dem Gerät (offline, ohne Konto).
/// Ist in Xcode die iCloud-Fähigkeit (CloudKit) eingerichtet, synchronisiert SwiftData
/// automatisch über das private iCloud-Konto des Nutzers; ohne diese Einrichtung bleibt alles lokal.
enum Persistence {
    static let container: ModelContainer = {
        let schema = Schema([TodoItem.self, TodoTag.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Datenspeicher konnte nicht geöffnet werden: \(error)")
        }
    }()

    /// Für SwiftUI-Previews.
    @MainActor
    static let preview: ModelContainer = {
        let schema = Schema([TodoItem.self, TodoTag.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        SeedData.insertDefaults(into: container.mainContext, includeExamples: true)
        return container
    }()
}

/// Vorgeschlagene Tags ab der ersten Aufgabe, ohne Einrichtung.
@MainActor
enum SeedData {
    static func seedIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppSettings.didSeedKey) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<TodoTag>())) ?? 0
        if existing == 0 {
            insertDefaults(into: context, includeExamples: true)
        }
        defaults.set(true, forKey: AppSettings.didSeedKey)
    }

    /// Mit iCloud-Sync legt jedes neue Gerät beim ersten Start die Start-Tags an. Gleichnamige Tags
    /// werden deshalb zusammengeführt: Aufgaben wandern zum ältesten Tag, das Duplikat wird gelöscht.
    static func mergeDuplicateTags(_ context: ModelContext) {
        let descriptor = FetchDescriptor<TodoTag>(sortBy: [SortDescriptor(\.createdAt)])
        guard let tags = try? context.fetch(descriptor), tags.count > 1 else { return }
        var keepers: [String: TodoTag] = [:]
        var changed = false
        for tag in tags {
            let key = TagSuggester.fold(tag.name.trimmingCharacters(in: .whitespaces))
            guard let keep = keepers[key] else {
                keepers[key] = tag
                continue
            }
            for item in tag.items ?? [] {
                var itemTags = (item.tags ?? []).filter { $0.uuid != tag.uuid }
                if !itemTags.contains(where: { $0.uuid == keep.uuid }) { itemTags.append(keep) }
                item.tags = itemTags
            }
            if !keep.hasLocation && tag.hasLocation {
                keep.latitude = tag.latitude
                keep.longitude = tag.longitude
                keep.address = tag.address
                keep.radius = tag.radius
            }
            context.delete(tag)
            changed = true
        }
        if changed { try? context.save() }
    }

    static func insertDefaults(into context: ModelContext, includeExamples: Bool) {
        let work = TodoTag(name: "Arbeit", symbol: "briefcase", colorHex: "#3B82C4",
                           keywords: ["meeting", "büro", "kunde", "chef", "präsentation", "bericht", "mail", "projekt"], sortIndex: 0)
        let home = TodoTag(name: "Zuhause", symbol: "house", colorHex: "#0F766E",
                           keywords: ["putzen", "wäsche", "aufräumen", "reparieren", "garten", "müll"], sortIndex: 1)
        let shopping = TodoTag(name: "Einkauf", symbol: "cart", colorHex: "#E0A100",
                               keywords: ["kaufen", "einkauf", "supermarkt", "milch", "brot", "bestellen", "drogerie"], sortIndex: 2)
        let health = TodoTag(name: "Gesundheit", symbol: "heart", colorHex: "#E8604C",
                             keywords: ["arzt", "zahnarzt", "sport", "training", "apotheke", "laufen", "termin"], sortIndex: 3)
        let study = TodoTag(name: "Lernen", symbol: "graduationcap", colorHex: "#6D5BD0",
                            keywords: ["lernen", "klausur", "vorlesung", "hausarbeit", "kurs", "lesen", "uni"], sortIndex: 4)
        let money = TodoTag(name: "Finanzen", symbol: "eurosign.circle", colorHex: "#5E9E3A",
                            keywords: ["rechnung", "steuer", "bank", "überweisen", "versicherung", "vertrag", "kündigen"], sortIndex: 5)

        for tag in [work, home, shopping, health, study, money] {
            context.insert(tag)
        }

        if includeExamples {
            let now = Date()
            let welcome = TodoItem(title: "Willkommen bei Tagwerk – tippe auf den Kreis zum Abhaken",
                                   notes: "Alle Aufgaben stehen in einer Liste. Überfälliges kommt zuerst, dann alles, was bald fällig ist.",
                                   dueDate: now.addingTimeInterval(2 * 3_600), priority: .medium, remindUntilDone: false)
            let filterHint = TodoItem(title: "Tag oben antippen, um die Liste zu filtern",
                                      notes: "Mehrere Tags lassen sich mit UND oder ODER kombinieren.",
                                      priority: .low)
            let groceries = TodoItem(title: "Milch und Brot kaufen", dueDate: now.addingTimeInterval(26 * 3_600))
            for item in [welcome, filterHint, groceries] {
                context.insert(item)
            }
            filterHint.tags = [work]
            groceries.tags = [shopping, home]
        }
        try? context.save()
    }
}
