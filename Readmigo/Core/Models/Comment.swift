import Foundation

// MARK: - Comment

struct Comment: Codable, Identifiable {
    let id: String
    let postId: String
    let userId: String
    let userName: String
    let userAvatar: String?
    let content: String
    let createdAt: Date
    var likeCount: Int
    var isLiked: Bool
    let replyTo: String?
    let replyToUserName: String?

    // MARK: - Computed Properties

    var relativeTimeString: String {
        createdAt.relativeTimeString
    }

    var userInitials: String {
        let parts = userName.split(separator: " ")
        if parts.count >= 2 {
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.last?.prefix(1) ?? ""
            return "\(first)\(last)".uppercased()
        }
        return String(userName.prefix(2)).uppercased()
    }
}

// MARK: - Comments Response

struct CommentsResponse: Codable {
    let data: [Comment]
    let total: Int
    let page: Int
    let limit: Int
    let hasMore: Bool
}

// MARK: - Comment Like Response

struct CommentLikeResponse: Codable {
    let success: Bool
    let likeCount: Int
}

// MARK: - Create Comment Request

struct CreateCommentRequest: Codable {
    let content: String
    let replyTo: String?
}

// MARK: - Date Extension for Relative Time

extension Date {
    var relativeTimeString: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        switch interval {
        case ..<0:
            return "刚刚"
        case 0..<60:
            return "刚刚"
        case 60..<3600:
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        case 3600..<86400:
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        case 86400..<172800:
            return "昨天"
        case 172800..<604800:
            let days = Int(interval / 86400)
            return "\(days)天前"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MM月dd日"
            return formatter.string(from: self)
        }
    }
}

