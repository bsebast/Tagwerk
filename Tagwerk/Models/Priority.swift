import SwiftUI

/// Priorität einer Aufgabe. Höherer Rohwert = wichtiger.
enum Priority: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: return "Keine"
        case .low: return "Niedrig"
        case .medium: return "Mittel"
        case .high: return "Hoch"
        }
    }

    var shortLabel: String {
        switch self {
        case .none: return "–"
        case .low: return "!"
        case .medium: return "!!"
        case .high: return "!!!"
        }
    }

    var color: Color {
        switch self {
        case .none: return .secondary
        case .low: return Palette.sky
        case .medium: return Palette.amber
        case .high: return Palette.coral
        }
    }
}
