import SwiftUI

/// Kompakte Darstellung eines Tags.
struct TagChip: View {
    let name: String
    let symbol: String
    let color: Color
    var isSelected: Bool = false
    var isSuggested: Bool = false
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if isSuggested && !isSelected {
                Image(systemName: "sparkles")
                    .font(.caption2)
            }
            Image(systemName: symbol)
                .font(compact ? .caption2 : .caption)
            Text(name)
                .font(compact ? .caption2.weight(.medium) : .subheadline.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 2 : 6)
        .foregroundStyle(isSelected ? Color.white : color)
        .background(
            Capsule().fill(isSelected ? color : color.opacity(0.14))
        )
        .overlay(
            Capsule().strokeBorder(color.opacity(isSuggested && !isSelected ? 0.7 : 0), style: StrokeStyle(lineWidth: 1, dash: [3]))
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension TagChip {
    init(tag: TodoTag, isSelected: Bool = false, isSuggested: Bool = false, compact: Bool = false) {
        self.init(name: tag.name, symbol: tag.symbol, color: tag.color,
                  isSelected: isSelected, isSuggested: isSuggested, compact: compact)
    }
}

/// Bricht Elemente in mehrere Zeilen um (für Tag-Auswahl).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > bounds.width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Lesbare Fälligkeitsangabe: „Heute, 14:00“, „Morgen, 9:30“, „Fr., 21. Nov., 8:00“.
enum DueFormatter {
    static func string(for date: Date, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "Heute, \(time)" }
        if calendar.isDateInTomorrow(date) { return "Morgen, \(time)" }
        if calendar.isDateInYesterday(date) { return "Gestern, \(time)" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }
}
