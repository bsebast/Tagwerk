import Foundation

/// Reine Daten eines Tags für die Vorschlagslogik.
struct TagCandidate: Equatable {
    let id: UUID
    let name: String
    let keywords: [String]
    let usageCount: Int
}

/// Schlägt passende Tags vor, während der Titel getippt wird.
/// Ohne Titel werden die am häufigsten genutzten Tags vorgeschlagen.
enum TagSuggester {
    static func suggestions(
        for title: String,
        candidates: [TagCandidate],
        excluding: Set<UUID> = [],
        limit: Int = 4
    ) -> [UUID] {
        let available = candidates.filter { !excluding.contains($0.id) }
        let words = tokenize(title).filter { $0.count >= 3 }

        guard !words.isEmpty else {
            // Stabile Sortierung: häufig genutzt zuerst, sonst Reihenfolge der Tags.
            return available.enumerated()
                .sorted { lhs, rhs in
                    lhs.element.usageCount != rhs.element.usageCount
                        ? lhs.element.usageCount > rhs.element.usageCount
                        : lhs.offset < rhs.offset
                }
                .prefix(limit)
                .map(\.element.id)
        }

        var scored: [(id: UUID, score: Int, offset: Int)] = []
        for (offset, candidate) in available.enumerated() {
            let name = fold(candidate.name)
            let keywords = candidate.keywords.map(fold).filter { $0.count >= 3 }
            var score = 0
            for word in words {
                if name.count >= 3, keywordMatches(word: word, keyword: name) {
                    score += 3
                }
                for keyword in keywords where keywordMatches(word: word, keyword: keyword) {
                    score += 2
                }
            }
            if score > 0 {
                scored.append((candidate.id, score * 1_000 + min(candidate.usageCount, 999), offset))
            }
        }

        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.offset < $1.offset }
            .prefix(limit)
            .map(\.id)
    }

    /// „zahn“ passt (während des Tippens) zu „zahnarzt“, „zahnarzttermin“ und „wocheneinkauf“ zu „einkauf“.
    static func keywordMatches(word: String, keyword: String) -> Bool {
        if keyword.hasPrefix(word) || word.hasPrefix(keyword) { return true }
        return keyword.count >= 4 && word.contains(keyword)
    }

    static func tokenize(_ text: String) -> [String] {
        fold(text)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: "ß", with: "ss")
    }
}
