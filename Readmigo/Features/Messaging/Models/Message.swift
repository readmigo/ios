import Foundation

/// Individual message within a thread
struct Message: Identifiable, Codable, Equatable {
    let id: String
    let threadId: String
    let senderId: String
    let senderType: SenderType
    let content: String
    let attachments: [Attachment]?
    let deviceInfo: MessageDeviceInfo?
    let createdAt: Date
    let readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case senderId = "sender_id"
        case senderType = "sender_type"
        case content
        case attachments
        case deviceInfo = "device_info"
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    /// Sender type enumeration
    enum SenderType: String, Codable {
        case user = "user"
        case support = "support"
        case system = "system"
    }

    /// Check if message is from user
    var isFromUser: Bool {
        senderType == .user
    }

    /// Check if message has been read
    var isRead: Bool {
        readAt != nil
    }
}

/// Device information attached to messages
struct MessageDeviceInfo: Codable, Equatable {
    let model: String
    let systemVersion: String
    let appVersion: String
    let language: String

    enum CodingKeys: String, CodingKey {
        case model
        case systemVersion
        case appVersion
        case language
    }

    /// Create from current device
    static var current: MessageDeviceInfo {
        MessageDeviceInfo(
            model: UIDevice.current.modelName,
            systemVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            language: Locale.current.language.languageCode?.identifier ?? "Unknown"
        )
    }

    /// Formatted display string
    var displayString: String {
        "\(model) | \(systemVersion) | App \(appVersion)"
    }
}

import UIKit
