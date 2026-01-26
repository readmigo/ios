import SwiftUI

/// Message preview card for the message list
struct MessagePreviewCard: View {
    let thread: MessageThread

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: thread.type.icon)
                    .font(.body)
                    .foregroundColor(iconBackgroundColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(thread.type.localizedNameKey.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(thread.subject)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(thread.lastMessagePreview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Status indicator
            VStack {
                if thread.unreadCount > 0 {
                    UnreadBadge(count: thread.unreadCount)
                } else {
                    statusIcon
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusIcon: some View {
        switch thread.status {
        case .open:
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
        case .replied:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.blue)
        case .closed, .resolved:
            Image(systemName: "checkmark.circle")
                .font(.caption2)
                .foregroundColor(.green)
        }
    }

    // MARK: - Helpers

    private var iconBackgroundColor: Color {
        switch thread.type.iconColor {
        case "orange": return .orange
        case "yellow": return .yellow
        case "blue": return .blue
        case "red": return .red
        case "purple": return .purple
        case "green": return .green
        default: return .accentColor
        }
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(thread.updatedAt) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: thread.updatedAt)
        } else if calendar.isDateInYesterday(thread.updatedAt) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: thread.updatedAt, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: thread.updatedAt)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: thread.updatedAt)
        }
    }
}
