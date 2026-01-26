import SwiftUI
import Kingfisher

/// Message bubble component for displaying individual messages
struct MessageBubbleView: View {
    let message: Message
    let showRating: Bool
    let isRated: Bool
    let onRate: ((FeedbackRating.Rating) -> Void)?

    init(
        message: Message,
        showRating: Bool = false,
        isRated: Bool = false,
        onRate: ((FeedbackRating.Rating) -> Void)? = nil
    ) {
        self.message = message
        self.showRating = showRating
        self.isRated = isRated
        self.onRate = onRate
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                // Message content
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(message.isFromUser ? .white : .primary)

                    // Attachments
                    if let attachments = message.attachments, !attachments.isEmpty {
                        attachmentsView(attachments)
                    }

                    // Device info (for first user message)
                    if let deviceInfo = message.deviceInfo {
                        deviceInfoView(deviceInfo)
                    }
                }
                .padding(12)
                .background(message.isFromUser ? Color.accentColor : Color(.systemGray5))
                .cornerRadius(16)

                // Timestamp and read status
                HStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if message.isFromUser && message.isRead {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Sender name for support messages
                if message.senderType == .support {
                    Text("Readmigo Team")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Rating buttons for support messages
                if showRating && message.senderType == .support && !isRated {
                    ratingView
                }

                if isRated {
                    Text("messaging.thanksFeedback".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func attachmentsView(_ attachments: [Attachment]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
            ForEach(attachments) { attachment in
                if attachment.isImage {
                    KFImage(URL(string: attachment.thumbnailUrl ?? attachment.url))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                )
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .clipped()
                }
            }
        }
    }

    @ViewBuilder
    private func deviceInfoView(_ info: MessageDeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
                .background(message.isFromUser ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))

            Text(info.displayString)
                .font(.caption2)
                .foregroundColor(message.isFromUser ? .white.opacity(0.8) : .secondary)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var ratingView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("messaging.helpful".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button {
                    onRate?(.helpful)
                } label: {
                    Label("messaging.yes".localized, systemImage: "hand.thumbsup")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(16)
                }

                Button {
                    onRate?(.notHelpful)
                } label: {
                    Label("messaging.no".localized, systemImage: "hand.thumbsdown")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(16)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.createdAt)
    }
}
