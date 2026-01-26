import Foundation
import SwiftUI

/// ViewModel for creating a new message
@MainActor
class NewMessageViewModel: ObservableObject {
    @Published var selectedType: MessageType = .generalInquiry
    @Published var subject = ""
    @Published var content = ""
    @Published var pendingAttachments: [PendingAttachment] = []
    @Published var includeDeviceInfo = true
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var createdThread: MessageThread?
    @Published var createdGuestFeedback: GuestFeedback?

    private let messagingService = MessagingService.shared

    /// Maximum attachments allowed
    let maxAttachments = MessagingService.maxAttachments

    /// Maximum content length
    let maxContentLength = MessagingService.maxContentLength

    /// Check if form is valid
    var isValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.count <= maxContentLength
    }

    /// Character count for content
    var contentCharacterCount: Int {
        content.count
    }

    /// Check if can add more attachments (only for authenticated users)
    var canAddMoreAttachments: Bool {
        pendingAttachments.count < maxAttachments
    }

    /// Current device info for preview
    var deviceInfo: MessageDeviceInfo {
        MessageDeviceInfo.current
    }

    /// Send the message (uses guest feedback for unauthenticated users)
    func sendMessage() async -> Bool {
        guard isValid && !isSending else { return false }

        isSending = true
        errorMessage = nil

        // Check if user is authenticated
        let isAuthenticated = AuthManager.shared.isAuthenticated

        do {
            if isAuthenticated {
                // Authenticated user: use regular messaging with attachments
                var attachmentIds: [String] = []
                for attachment in pendingAttachments {
                    if let image = attachment.image {
                        let uploaded = try await messagingService.uploadAttachment(image: image)
                        attachmentIds.append(uploaded.id)
                    }
                }

                let thread = try await messagingService.createThread(
                    type: selectedType,
                    subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    attachmentIds: attachmentIds.isEmpty ? nil : attachmentIds,
                    includeDeviceInfo: includeDeviceInfo
                )

                createdThread = thread
            } else {
                // Guest user: use guest feedback API (no attachments support)
                let feedback = try await messagingService.submitGuestFeedback(
                    type: selectedType,
                    subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    includeDeviceInfo: includeDeviceInfo
                )

                createdGuestFeedback = feedback
            }

            isSending = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSending = false
            return false
        }
    }

    /// Add an attachment
    func addAttachment(image: UIImage) {
        guard canAddMoreAttachments else { return }

        let attachment = PendingAttachment(id: UUID().uuidString, image: image)
        pendingAttachments.append(attachment)
    }

    /// Remove a pending attachment
    func removeAttachment(id: String) {
        pendingAttachments.removeAll { $0.id == id }
    }

    /// Reset form
    func reset() {
        selectedType = .generalInquiry
        subject = ""
        content = ""
        pendingAttachments = []
        includeDeviceInfo = true
        errorMessage = nil
        createdThread = nil
        createdGuestFeedback = nil
    }

    /// Clear error
    func clearError() {
        errorMessage = nil
    }
}
