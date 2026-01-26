import Foundation

/// Feedback rating for support responses
struct FeedbackRating: Codable {
    let threadId: String
    let messageId: String
    let rating: Rating
    let comment: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case messageId = "message_id"
        case rating
        case comment
        case createdAt = "created_at"
    }

    /// Rating value
    enum Rating: String, Codable {
        case helpful = "helpful"
        case notHelpful = "not_helpful"
    }
}

// MARK: - API Request/Response Models

/// Request to create a new message thread
struct CreateThreadRequest: Codable {
    let type: String
    let subject: String
    let content: String
    let attachmentIds: [String]?
    let includeDeviceInfo: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case subject
        case content
        case attachmentIds = "attachment_ids"
        case includeDeviceInfo = "include_device_info"
    }
}

/// Request to send a reply in a thread
struct SendReplyRequest: Codable {
    let content: String
    let attachmentIds: [String]?

    enum CodingKeys: String, CodingKey {
        case content
        case attachmentIds = "attachment_ids"
    }
}

/// Request to submit a rating
struct SubmitRatingRequest: Codable {
    let messageId: String
    let rating: String
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case rating
        case comment
    }
}

/// Response for thread list
struct ThreadListResponse: Codable {
    let threads: [MessageThread]
    let total: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case threads
        case total
        case hasMore
    }
}

/// Response for single thread
struct ThreadResponse: Codable {
    let thread: MessageThread
}

/// Response for message
struct MessageResponse: Codable {
    let message: Message
}

/// Response for unread count
struct UnreadCountResponse: Codable {
    let count: Int
}

/// Response for success operations
struct SuccessResponse: Codable {
    let success: Bool
}
