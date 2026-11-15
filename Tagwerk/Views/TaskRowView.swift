import SwiftUI

struct TaskRowView: View {
    let item: TodoItem
    let now: Date
    let onToggle: () -> Void

    private var isOverdue: Bool {
        guard let due = item.dueDate, !item.isDone else { return false }
        return due < now
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(item.priority == .none ? Color.secondary.opacity(0.6) : item.priority.color, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if item.isDone {
                        Circle().fill(Palette.teal).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 1)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isDone ? "Als offen markieren" : "Als erledigt markieren")

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if item.priority != .none && !item.isDone {
                        Text(item.priority.shortLabel)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(item.priority.color)
                    }
                    Text(item.title)
                        .font(.body)
                        .strikethrough(item.isDone)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                }

                if item.dueDate != nil || item.recurrence != .none {
                    HStack(spacing: 8) {
                        if let due = item.dueDate {
                            Label(DueFormatter.string(for: due), systemImage: "calendar")
                                .foregroundStyle(isOverdue ? Palette.coral : .secondary)
                        }
                        if item.recurrence != .none {
                            Label(item.recurrence.label, systemImage: "repeat")
                                .foregroundStyle(.secondary)
                        }
                        if item.remindUntilDone && item.dueDate != nil && !item.isDone {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Erinnert bis erledigt")
                        }
                    }
                    .font(.caption)
                    .labelStyle(.titleAndIcon)
                }

                if !item.tagList.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(item.tagList) { tag in
                            TagChip(tag: tag, compact: true)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
