import Foundation

/// Guest feedback model for unauthenticated users
struct GuestFeedback: Identifiable, Codable, Equatable {
    let id: String
    let deviceId: String
    let type: MessageType
    let subject: String
    let content: String
    let status: ThreadStatus
    let deviceInfo: MessageDeviceInfo?
    let adminReply: String?
    let repliedAt: Date?
    let repliedBy: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId
        case type
        case subject
        case content
        case status
        case deviceInfo
        case adminReply
        case repliedAt
        case repliedBy
        case createdAt
        case updatedAt
    }

    // Custom decoder to handle uppercase fields from server
    // Server returns: GENERAL_INQUIRY, OPEN
    // Client expects: general_inquiry, open
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        subject = try container.decode(String.self, forKey: .subject)
        content = try container.decode(String.self, forKey: .content)
        deviceInfo = try container.decodeIfPresent(MessageDeviceInfo.self, forKey: .deviceInfo)
        adminReply = try container.decodeIfPresent(String.self, forKey: .adminReply)
        repliedAt = try container.decodeIfPresent(Date.self, forKey: .repliedAt)
        repliedBy = try container.decodeIfPresent(String.self, forKey: .repliedBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Handle type conversion: server returns uppercase (GENERAL_INQUIRY)
        // but MessageType uses lowercase (general_inquiry)
        let typeString = try container.decode(String.self, forKey: .type)
        let lowercaseType = typeString.lowercased()

        Task { @MainActor in LoggingService.shared.debug(.other, "[GuestFeedback] Decoding type: '\(typeString)' -> '\(lowercaseType)'", component: "GuestFeedback") }

        if let messageType = MessageType(rawValue: lowercaseType) {
            type = messageType
            Task { @MainActor in LoggingService.shared.debug(.other, "[GuestFeedback] Type decoded successfully: \(messageType)", component: "GuestFeedback") }
        } else {
            // Fallback to generalInquiry if type is unknown
            type = .generalInquiry
            Task { @MainActor in LoggingService.shared.debug(.other, "[GuestFeedback] Unknown type '\(typeString)', using fallback: generalInquiry", component: "GuestFeedback") }
        }

        // Handle status conversion: server returns uppercase (OPEN)
        // but ThreadStatus uses lowercase (open)
        let statusString = try container.decode(String.self, forKey: .status)
        let lowercaseStatus = statusString.lowercased()

        Task { @MainActor in LoggingService.shared.debug(.other, "[GuestFeedback] Decoding status: '\(statusString)' -> '\(lowercaseStatus)'", component: "GuestFeedback") }

        if let threadStatus = ThreadStatus(rawValue: lowercaseStatus) {
            status = threadStatus
            Task { @MainActor in LoggingService.shared.debug(.other, "[GuestFeedback] Status decoded successfully: \(threadStatus)", component: "GuestFeedback") }
        } else {
            // Fallback to open if status is unknown
            status = .open
            Task { @MainActor in LoggingService.shared.debug(.other, "[GuestFeedback] Unknown status '\(statusString)', using fallback: open", component: "GuestFeedback") }
        }
    }

    // Custom encoder to match standard Codable behavior
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(type, forKey: .type)
        try container.encode(subject, forKey: .subject)
        try container.encode(content, forKey: .content)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(deviceInfo, forKey: .deviceInfo)
        try container.encodeIfPresent(adminReply, forKey: .adminReply)
        try container.encodeIfPresent(repliedAt, forKey: .repliedAt)
        try container.encodeIfPresent(repliedBy, forKey: .repliedBy)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

/// Request to create guest feedback
struct CreateGuestFeedbackRequest: Codable {
    let deviceId: String
    let type: String
    let subject: String
    let content: String
    let deviceInfo: MessageDeviceInfo?
}

/// Response containing list of guest feedbacks
struct GuestFeedbackListResponse: Codable {
    let feedbacks: [GuestFeedback]
    let total: Int
    let hasMore: Bool
}

// MARK: - Local Read State Management

enum GuestFeedbackReadState {
    private static let readFeedbackIdsKey = "guest_feedback_read_ids"

    static func isRead(_ feedbackId: String) -> Bool {
        let readIds = UserDefaults.standard.stringArray(forKey: readFeedbackIdsKey) ?? []
        return readIds.contains(feedbackId)
    }

    static func markAsRead(_ feedbackId: String) {
        var readIds = UserDefaults.standard.stringArray(forKey: readFeedbackIdsKey) ?? []
        if !readIds.contains(feedbackId) {
            readIds.append(feedbackId)
            UserDefaults.standard.set(readIds, forKey: readFeedbackIdsKey)
        }
    }
}

// MARK: - Conversion to MessageThread for display

extension GuestFeedback {
    /// Convert guest feedback to MessageThread for unified display in message list
    func toMessageThread() -> MessageThread {
        // Check if this feedback has been read locally
        let hasUnread = adminReply != nil && status == .replied && !GuestFeedbackReadState.isRead(id)

        return MessageThread(
            id: id,
            userId: deviceId,
            type: type,
            subject: subject,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastMessagePreview: adminReply ?? content,
            unreadCount: hasUnread ? 1 : 0,
            messages: nil
        )
    }

    /// Convert guest feedback to MessageThread with messages for detail view
    func toMessageThreadWithMessages() -> MessageThread {
        var messages: [Message] = []

        // User's original message
        let userMessage = Message(
            id: "\(id)-user",
            threadId: id,
            senderId: deviceId,
            senderType: .user,
            content: content,
            attachments: nil,
            deviceInfo: deviceInfo,
            createdAt: createdAt,
            readAt: nil
        )
        messages.append(userMessage)

        // Admin reply (if exists)
        if let reply = adminReply, let replyDate = repliedAt {
            let adminMessage = Message(
                id: "\(id)-admin",
                threadId: id,
                senderId: repliedBy ?? "admin",
                senderType: .support,
                content: reply,
                attachments: nil,
                deviceInfo: nil,
                createdAt: replyDate,
                readAt: nil
            )
            messages.append(adminMessage)
        }

        return MessageThread(
            id: id,
            userId: deviceId,
            type: type,
            subject: subject,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastMessagePreview: adminReply ?? content,
            unreadCount: 0,
            messages: messages
        )
    }
}
