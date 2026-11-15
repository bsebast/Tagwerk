import SwiftUI

/// Eigene Farbwelt von Tagwerk.
enum Palette {
    static let teal = Color(hex: "#0F766E")
    static let coral = Color(hex: "#E8604C")
    static let amber = Color(hex: "#E0A100")
    static let sky = Color(hex: "#3B82C4")

    /// Auswahl für Tags (Hex-Werte werden gespeichert).
    static let tagColors: [String] = [
        "#0F766E", "#3B82C4", "#6D5BD0", "#B4499B", "#E8604C",
        "#E0A100", "#5E9E3A", "#2A9DB0", "#8A6E4B", "#5B6472",
    ]

    /// Kuratierte SF Symbols für Tags.
    static let tagSymbols: [String] = [
        "tag", "briefcase", "house", "cart", "heart", "book", "graduationcap",
        "eurosign.circle", "figure.run", "fork.knife", "car", "airplane",
        "person.2", "phone", "envelope", "laptopcomputer", "wrench.and.screwdriver",
        "leaf", "pawprint", "gift", "calendar", "star", "flag", "lightbulb",
        "paintbrush", "music.note", "gamecontroller", "cross.case", "building.2", "mappin.and.ellipse",
    ]
}

extension Color {
    /// Erstellt eine Farbe aus „#RRGGBB“. Ungültige Werte ergeben Grau.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        var value: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            self = .gray
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
