import Foundation
import UIKit

/// Error types for messaging operations
enum MessagingError: Error, LocalizedError {
    case invalidImage
    case uploadFailed
    case networkError
    case notAuthenticated
    case threadNotFound
    case messageTooLong
    case tooManyAttachments

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .uploadFailed:
            return "Failed to upload attachment"
        case .networkError:
            return "Network error occurred"
        case .notAuthenticated:
            return "Please login to send messages"
        case .threadNotFound:
            return "Message thread not found"
        case .messageTooLong:
            return "Message exceeds maximum length"
        case .tooManyAttachments:
            return "Too many attachments (maximum 5)"
        }
    }
}

/// Service for handling in-app messaging
@MainActor
class MessagingService: ObservableObject {
    static let shared = MessagingService()

    /// Total unread message count
    @Published var unreadCount: Int = 0

    /// List of message threads
    @Published var threads: [MessageThread] = []

    /// Loading state
    @Published var isLoading = false

    /// Error message
    @Published var errorMessage: String?

    /// Maximum message content length
    static let maxContentLength = 2000

    /// Maximum number of attachments
    static let maxAttachments = 5

    private init() {}

    // MARK: - Thread Operations

    /// Fetch message threads list
    /// - Parameters:
    ///   - page: Page number (1-indexed)
    ///   - status: Optional status filter
    /// - Returns: Thread list response
    func fetchThreads(page: Int = 1, status: ThreadStatus? = nil) async throws -> ThreadListResponse {
        isLoading = true
        defer { isLoading = false }

        var endpoint = "\(APIEndpoints.messageThreads)?page=\(page)"
        if let status = status {
            endpoint += "&status=\(status.rawValue)"
        }

        let response: ThreadListResponse = try await APIClient.shared.request(
            endpoint: endpoint,
            method: .get
        )

        if page == 1 {
            threads = response.threads
        } else {
            threads.append(contentsOf: response.threads)
        }

        return response
    }

    /// Fetch a single thread with messages
    /// - Parameter id: Thread ID
    /// - Returns: Message thread with messages
    func fetchThread(id: String) async throws -> MessageThread {
        let response: ThreadResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.messageThread(id),
            method: .get
        )
        return response.thread
    }

    /// Create a new message thread
    /// - Parameters:
    ///   - type: Message type
    ///   - subject: Subject line
    ///   - content: Message content
    ///   - attachmentIds: Optional attachment IDs
    ///   - includeDeviceInfo: Whether to include device info
    /// - Returns: Created thread
    func createThread(
        type: MessageType,
        subject: String,
        content: String,
        attachmentIds: [String]? = nil,
        includeDeviceInfo: Bool = true
    ) async throws -> MessageThread {
        guard content.count <= Self.maxContentLength else {
            throw MessagingError.messageTooLong
        }

        if let ids = attachmentIds, ids.count > Self.maxAttachments {
            throw MessagingError.tooManyAttachments
        }

        let request = CreateThreadRequest(
            type: type.rawValue,
            subject: subject,
            content: content,
            attachmentIds: attachmentIds,
            includeDeviceInfo: includeDeviceInfo
        )

        let response: ThreadResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.messageThreads,
            method: .post,
            body: request
        )

        // Add to local list
        threads.insert(response.thread, at: 0)

        return response.thread
    }

    /// Send a reply in an existing thread
    /// - Parameters:
    ///   - threadId: Thread ID
    ///   - content: Reply content
    ///   - attachmentIds: Optional attachment IDs
    /// - Returns: Created message
    func sendReply(
        threadId: String,
        content: String,
        attachmentIds: [String]? = nil
    ) async throws -> Message {
        guard content.count <= Self.maxContentLength else {
            throw MessagingError.messageTooLong
        }

        let request = SendReplyRequest(
            content: content,
            attachmentIds: attachmentIds
        )

        let response: MessageResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.messageThreadMessages(threadId),
            method: .post,
            body: request
        )

        return response.message
    }

    /// Close a message thread
    /// - Parameter threadId: Thread ID
    func closeThread(threadId: String) async throws {
        let _: SuccessResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.messageThreadClose(threadId),
            method: .post
        )

        // Update local state
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            // Note: We'd need to refetch to get updated status
            // For now, just trigger a refresh
            _ = try? await fetchThreads()
        }
    }

    // MARK: - Attachment Operations

    /// Upload an image attachment
    /// - Parameter image: Image to upload
    /// - Returns: Uploaded attachment
    func uploadAttachment(image: UIImage) async throws -> Attachment {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw MessagingError.invalidImage
        }

        let response: AttachmentUploadResponse = try await APIClient.shared.uploadMultipart(
            endpoint: APIEndpoints.messageAttachments,
            fileData: data,
            fileName: "image_\(Date().timeIntervalSince1970).jpg",
            mimeType: "image/jpeg"
        )

        return response.attachment
    }

    /// Delete an attachment (before sending)
    /// - Parameter attachmentId: Attachment ID
    func deleteAttachment(attachmentId: String) async throws {
        let _: SuccessResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.messageAttachment(attachmentId),
            method: .delete
        )
    }

    // MARK: - Unread Count

    /// Fetch unread message count
    func fetchUnreadCount() async throws {
        let response: UnreadCountResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.messageUnreadCount,
            method: .get
        )
        unreadCount = response.count
    }

    /// Mark a thread as read
    /// - Parameter threadId: Thread ID
    func markAsRead(threadId: String) async throws {
        let _: SuccessResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.messageThreadRead(threadId),
            method: .post
        )

        // Update unread count
        try await fetchUnreadCount()
    }

    // MARK: - Rating

    /// Submit a rating for a support reply
    /// - Parameters:
    ///   - threadId: Thread ID
    ///   - messageId: Message ID being rated
    ///   - rating: Rating value
    ///   - comment: Optional comment
    func submitRating(
        threadId: String,
        messageId: String,
        rating: FeedbackRating.Rating,
        comment: String? = nil
    ) async throws {
        let request = SubmitRatingRequest(
            messageId: messageId,
            rating: rating.rawValue,
            comment: comment
        )

        let _: SuccessResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.messageThreadRating(threadId),
            method: .post,
            body: request
        )
    }

    // MARK: - Guest Feedback (No Authentication Required)

    /// Submit guest feedback without authentication
    /// - Parameters:
    ///   - type: Feedback type
    ///   - subject: Subject line
    ///   - content: Feedback content
    ///   - includeDeviceInfo: Whether to include device info
    /// - Returns: Created guest feedback
    func submitGuestFeedback(
        type: MessageType,
        subject: String,
        content: String,
        includeDeviceInfo: Bool = true
    ) async throws -> GuestFeedback {
        guard content.count <= Self.maxContentLength else {
            throw MessagingError.messageTooLong
        }

        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        let request = CreateGuestFeedbackRequest(
            deviceId: deviceId,
            type: type.rawValue.uppercased(),
            subject: subject,
            content: content,
            deviceInfo: includeDeviceInfo ? MessageDeviceInfo.current : nil
        )

        let response: GuestFeedback = try await APIClient.shared.requestWithoutAuth(
            endpoint: APIEndpoints.guestFeedback,
            method: .post,
            body: request
        )

        return response
    }

    /// Fetch guest feedbacks for current device
    /// - Returns: Guest feedback list response
    func fetchGuestFeedbacks() async throws -> GuestFeedbackListResponse {
        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? ""

        let response: GuestFeedbackListResponse = try await APIClient.shared.requestWithoutAuth(
            endpoint: APIEndpoints.guestFeedbackByDevice(deviceId),
            method: .get
        )

        return response
    }

    /// Fetch a single guest feedback by ID
    /// - Parameter id: Feedback ID
    /// - Returns: Guest feedback
    func fetchGuestFeedback(id: String) async throws -> GuestFeedback {
        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? ""

        let response: GuestFeedback = try await APIClient.shared.requestWithoutAuth(
            endpoint: APIEndpoints.guestFeedbackDetail(id, deviceId: deviceId),
            method: .get
        )

        return response
    }

    // MARK: - Push Notifications

    /// Register push token for guest feedback notifications
    /// - Parameters:
    ///   - token: APNs device token
    ///   - deviceId: Device identifier
    func registerPushToken(_ token: String, deviceId: String) async throws {
        struct RegisterPushTokenRequest: Codable {
            let deviceId: String
            let pushToken: String
        }

        let request = RegisterPushTokenRequest(
            deviceId: deviceId,
            pushToken: token
        )

        let _: SuccessResponse = try await APIClient.shared.requestWithoutAuth(
            endpoint: APIEndpoints.guestFeedbackPushToken,
            method: .post,
            body: request
        )
    }

    // MARK: - Helpers

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    /// Refresh all data
    func refresh() async {
        do {
            async let threadsTask: () = { _ = try await self.fetchThreads() }()
            async let unreadTask: () = { try await self.fetchUnreadCount() }()
            _ = try await (threadsTask, unreadTask)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
