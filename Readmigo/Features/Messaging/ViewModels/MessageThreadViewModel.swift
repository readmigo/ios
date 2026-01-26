import Foundation
import SwiftUI

/// ViewModel for message thread detail view
@MainActor
class MessageThreadViewModel: ObservableObject {
    @Published var thread: MessageThread?
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var replyText = ""
    @Published var pendingAttachments: [PendingAttachment] = []
    @Published var ratedMessageIds: Set<String> = []

    private let threadId: String
    private let messagingService = MessagingService.shared

    /// Maximum attachments allowed
    let maxAttachments = MessagingService.maxAttachments

    /// Maximum content length
    let maxContentLength = MessagingService.maxContentLength

    /// Check if can send reply
    var canSendReply: Bool {
        !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        replyText.count <= maxContentLength &&
        !isSending
    }

    /// Character count for reply
    var replyCharacterCount: Int {
        replyText.count
    }

    /// Check if thread is closed
    var isThreadClosed: Bool {
        thread?.status == .closed || thread?.status == .resolved
    }

    init(threadId: String) {
        self.threadId = threadId
    }

    /// Load thread details with messages
    func loadThread() async {
        isLoading = true
        errorMessage = nil

        do {
            if AuthManager.shared.isAuthenticated {
                // Authenticated user: use message thread endpoint
                let loadedThread = try await messagingService.fetchThread(id: threadId)
                thread = loadedThread
                messages = loadedThread.messages ?? []

                // Mark as read
                try await messagingService.markAsRead(threadId: threadId)
            } else {
                // Guest user: use guest feedback endpoint
                let feedback = try await messagingService.fetchGuestFeedback(id: threadId)
                let loadedThread = feedback.toMessageThreadWithMessages()
                thread = loadedThread
                messages = loadedThread.messages ?? []

                // Mark as read locally
                GuestFeedbackReadState.markAsRead(threadId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Send a reply
    func sendReply() async {
        guard canSendReply else { return }

        isSending = true
        errorMessage = nil

        do {
            // Upload pending attachments first
            var attachmentIds: [String] = []
            for attachment in pendingAttachments {
                if let image = attachment.image {
                    let uploaded = try await messagingService.uploadAttachment(image: image)
                    attachmentIds.append(uploaded.id)
                }
            }

            // Send the reply
            let message = try await messagingService.sendReply(
                threadId: threadId,
                content: replyText.trimmingCharacters(in: .whitespacesAndNewlines),
                attachmentIds: attachmentIds.isEmpty ? nil : attachmentIds
            )

            // Add to local messages
            messages.append(message)

            // Clear input
            replyText = ""
            pendingAttachments = []
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    /// Add an attachment
    func addAttachment(image: UIImage) {
        guard pendingAttachments.count < maxAttachments else { return }

        let attachment = PendingAttachment(id: UUID().uuidString, image: image)
        pendingAttachments.append(attachment)
    }

    /// Remove a pending attachment
    func removeAttachment(id: String) {
        pendingAttachments.removeAll { $0.id == id }
    }

    /// Submit rating for a message
    func submitRating(messageId: String, rating: FeedbackRating.Rating) async {
        do {
            try await messagingService.submitRating(
                threadId: threadId,
                messageId: messageId,
                rating: rating
            )
            ratedMessageIds.insert(messageId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Close the thread
    func closeThread() async {
        do {
            try await messagingService.closeThread(threadId: threadId)
            // Reload to get updated status
            await loadThread()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Clear error
    func clearError() {
        errorMessage = nil
    }
}

/// Pending attachment model
struct PendingAttachment: Identifiable {
    let id: String
    let image: UIImage?
}
