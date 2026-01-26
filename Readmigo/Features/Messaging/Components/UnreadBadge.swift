import SwiftUI

/// Unread message count badge
struct UnreadBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(displayCount)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, count > 9 ? 6 : 0)
                .frame(minWidth: 18, minHeight: 18)
                .background(Color.red)
                .clipShape(Capsule())
        }
    }

    private var displayCount: String {
        if count > 99 {
            return "99+"
        }
        return "\(count)"
    }
}

/// Tab bar badge for unread messages
struct MessagingTabBadge: View {
    @ObservedObject var messagingService = MessagingService.shared

    var body: some View {
        if messagingService.unreadCount > 0 {
            UnreadBadge(count: messagingService.unreadCount)
        }
    }
}
