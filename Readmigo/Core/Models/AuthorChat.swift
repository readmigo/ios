import Foundation

// MARK: - Chat Session

struct ChatSession: Codable, Identifiable {
    let id: String
    let authorId: String
    let authorName: String
    let authorNameZh: String?
    let authorAvatarUrl: String?
    var title: String?
    var lastMessage: String?
    let messageCount: Int
    let createdAt: Date
    var updatedAt: Date

    /// Get author's initials for avatar placeholder
    var authorInitials: String {
        let parts = authorName.split(separator: " ")
        if parts.count >= 2 {
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.last?.prefix(1) ?? ""
            return "\(first)\(last)".uppercased()
        }
        return String(authorName.prefix(2)).uppercased()
    }

    /// Generate a consistent color based on author name
    var authorColorIndex: Int {
        var hash = 0
        for char in authorName.unicodeScalars {
            hash = Int(char.value) &+ (hash << 5) &- hash
        }
        return abs(hash) % 8
    }
}

// MARK: - Chat Message

struct ChatMessage: Codable, Identifiable {
    let id: String
    let role: MessageRole
    let content: String
    let createdAt: Date

    enum MessageRole: String, Codable {
        case user = "USER"
        case assistant = "ASSISTANT"
    }

    var isUser: Bool {
        role == .user
    }

    var isAssistant: Bool {
        role == .assistant
    }
}

// MARK: - Chat Session Detail

struct ChatSessionDetail: Codable {
    let id: String
    let authorId: String
    let authorName: String
    let authorNameZh: String?
    let authorAvatarUrl: String?
    var title: String?
    let messageCount: Int
    let createdAt: Date
    var updatedAt: Date
    let messages: [ChatMessage]

    /// Convert to ChatSession
    var asSession: ChatSession {
        ChatSession(
            id: id,
            authorId: authorId,
            authorName: authorName,
            authorNameZh: authorNameZh,
            authorAvatarUrl: authorAvatarUrl,
            title: title,
            lastMessage: messages.last?.content,
            messageCount: messageCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Response DTOs

struct ChatSessionListResponse: Codable {
    let data: [ChatSession]
    let total: Int
}

struct SendMessageResponse: Codable {
    let userMessage: ChatMessage
    let assistantMessage: ChatMessage
}

// MARK: - Request DTOs

struct CreateSessionRequest: Codable {
    let authorId: String
    var title: String?
}

struct SendMessageRequest: Codable {
    let content: String
}

