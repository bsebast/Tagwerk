import SwiftUI
import SwiftData
import CoreLocation

/// Ein Tag ersetzt klassische Listen/Projekte. Eine Aufgabe kann beliebig viele Tags haben.
@Model
final class TodoTag {
    var uuid: UUID = UUID()
    var name: String = ""
    var symbol: String = "tag"
    var colorHex: String = "#0F766E"
    /// Stichwörter (kommagetrennt), aus denen Tag-Vorschläge beim Tippen entstehen.
    var keywordsRaw: String = ""
    var sortIndex: Int = 0
    var createdAt: Date = Date()

    // Orts-Tag (optional): Ort, Umkreis und gewünschtes Verhalten in der Nähe.
    var latitude: Double?
    var longitude: Double?
    var radius: Double = 150
    var address: String = ""
    var locationSuggest: Bool = true
    var locationAutoFilter: Bool = false
    var locationNotify: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \TodoItem.tags)
    var items: [TodoItem]? = []

    init(name: String, symbol: String, colorHex: String, keywords: [String] = [], sortIndex: Int = 0) {
        self.uuid = UUID()
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.keywordsRaw = keywords.joined(separator: ", ")
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }

    var color: Color { Color(hex: colorHex) }

    var keywords: [String] {
        keywordsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var openItemCount: Int {
        (items ?? []).filter { !$0.isDone }.count
    }

    var candidate: TagCandidate {
        TagCandidate(id: uuid, name: name, keywords: keywords, usageCount: items?.count ?? 0)
    }

    var hasLocation: Bool { latitude != nil && longitude != nil }

    func isNear(_ location: CLLocation?) -> Bool {
        LocationMatch.isNear(latitude: latitude, longitude: longitude, radius: radius, to: location)
    }
}
