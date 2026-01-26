import Foundation

/// Message thread representing a conversation between user and support
struct MessageThread: Identifiable, Codable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    let id: String
    let userId: String
    let type: MessageType
    let subject: String
    let status: ThreadStatus
    let createdAt: Date
    let updatedAt: Date
    let lastMessagePreview: String
    let unreadCount: Int
    let messages: [Message]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case subject
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMessagePreview = "last_message_preview"
        case unreadCount = "unread_count"
        case messages
    }
}

/// Message type categories
enum MessageType: String, Codable, CaseIterable {
    case technicalIssue = "technical_issue"
    case featureSuggestion = "feature_suggestion"
    case generalInquiry = "general_inquiry"
    case problemReport = "problem_report"
    case complaint = "complaint"
    case businessInquiry = "business_inquiry"

    /// SF Symbol icon name for the message type
    var icon: String {
        switch self {
        case .technicalIssue:
            return "questionmark.circle.fill"
        case .featureSuggestion:
            return "lightbulb.fill"
        case .generalInquiry:
            return "bubble.left.fill"
        case .problemReport:
            return "exclamationmark.triangle.fill"
        case .complaint:
            return "megaphone.fill"
        case .businessInquiry:
            return "briefcase.fill"
        }
    }

    /// Icon color for the message type
    var iconColor: String {
        switch self {
        case .technicalIssue:
            return "orange"
        case .featureSuggestion:
            return "yellow"
        case .generalInquiry:
            return "blue"
        case .problemReport:
            return "red"
        case .complaint:
            return "purple"
        case .businessInquiry:
            return "green"
        }
    }

    /// Localized name key
    var localizedNameKey: String {
        switch self {
        case .technicalIssue:
            return "messaging.type.technicalIssue"
        case .featureSuggestion:
            return "messaging.type.featureSuggestion"
        case .generalInquiry:
            return "messaging.type.generalInquiry"
        case .problemReport:
            return "messaging.type.problemReport"
        case .complaint:
            return "messaging.type.complaint"
        case .businessInquiry:
            return "messaging.type.businessInquiry"
        }
    }
}

/// Thread status
enum ThreadStatus: String, Codable {
    case open = "open"
    case replied = "replied"
    case closed = "closed"
    case resolved = "resolved"

    /// Localized name key
    var localizedNameKey: String {
        switch self {
        case .open:
            return "messaging.status.open"
        case .replied:
            return "messaging.status.replied"
        case .closed:
            return "messaging.status.closed"
        case .resolved:
            return "messaging.status.resolved"
        }
    }

    /// Status color
    var color: String {
        switch self {
        case .open:
            return "orange"
        case .replied:
            return "blue"
        case .closed:
            return "gray"
        case .resolved:
            return "green"
        }
    }
}
