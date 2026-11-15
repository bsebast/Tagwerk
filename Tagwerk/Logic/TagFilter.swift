import Foundation

/// Wie mehrere ausgewählte Tags kombiniert werden.
enum FilterMode: String, CaseIterable, Identifiable {
    case all = "and"
    case any = "or"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Alle Tags (UND)"
        case .any: return "Mind. ein Tag (ODER)"
        }
    }

    var shortLabel: String {
        switch self {
        case .all: return "UND"
        case .any: return "ODER"
        }
    }

    var toggled: FilterMode { self == .all ? .any : .all }
}

/// Filtern statt Trennen: Tags blenden nur aus, nichts wird verschoben.
enum TagFilter {
    static func matches(itemTagIDs: Set<UUID>, selected: Set<UUID>, mode: FilterMode) -> Bool {
        guard !selected.isEmpty else { return true }
        switch mode {
        case .all: return selected.isSubset(of: itemTagIDs)
        case .any: return !selected.isDisjoint(with: itemTagIDs)
        }
    }

    static func matches(title: String, notes: String, search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(query) || notes.localizedCaseInsensitiveContains(query)
    }
}
