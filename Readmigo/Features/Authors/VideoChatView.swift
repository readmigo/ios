import SwiftUI
import AVKit

/// Video chat view for conversing with AI-generated author avatars
struct VideoChatView: View {
    let authorId: String
    let sessionId: String

    @StateObject private var manager = VideoChatManager()
    @StateObject private var authorManager = AuthorManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    private let avatarColors: [Color] = [
        Color(red: 0.91, green: 0.30, blue: 0.24),
        Color(red: 0.90, green: 0.49, blue: 0.13),
        Color(red: 0.18, green: 0.80, blue: 0.44),
        Color(red: 0.20, green: 0.60, blue: 0.86),
        Color(red: 0.56, green: 0.27, blue: 0.68),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if manager.requiresPremium {
                    premiumRequiredView
                } else if !manager.isAvailable {
                    unavailableView
                } else {
                    // Video display area
                    videoDisplayArea
                        .frame(maxHeight: .infinity)

                    // Chat history
                    if !manager.messages.isEmpty {
                        chatHistoryView
                    }

                    // Input area
                    inputArea
                }
            }
            .navigationTitle("Video Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    authorAvatar
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await manager.checkAvailability(authorId: authorId)
        }
    }

    // MARK: - Author Avatar

    private var authorAvatar: some View {
        ZStack {
            Circle()
                .fill(avatarColors[abs(authorId.hashValue) % avatarColors.count])
                .frame(width: 32, height: 32)

            if let avatarUrl = authorManager.currentAuthorDetail?.avatarUrl,
               let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text(authorInitials)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Text(authorInitials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private var authorInitials: String {
        authorManager.currentAuthorDetail?.initials ?? "AU"
    }

    private var authorName: String {
        authorManager.currentAuthorDetail?.name ?? "Author"
    }

    // MARK: - Premium Required View

    private var premiumRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "video.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("Premium Feature")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Video chat with AI-generated author avatars requires a premium subscription.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                // TODO: Show subscription options
            } label: {
                Text("Upgrade to Premium")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Unavailable View

    private var unavailableView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "video.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("Video Chat Unavailable")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Video chat is not yet available for this author. Try text or voice chat instead.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Video Display Area

    private var videoDisplayArea: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.black)

            if let videoURL = manager.currentVideoURL {
                // Video player
                VideoPlayerView(url: videoURL)
            } else if manager.isGenerating {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)

                    Text(manager.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    if manager.generationProgress > 0 {
                        ProgressView(value: manager.generationProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                            .tint(.blue)
                    }
                }
            } else {
                // Idle state - show author placeholder
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(avatarColors[abs(authorId.hashValue) % avatarColors.count])
                            .frame(width: 120, height: 120)

                        Text(authorInitials)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                    Text(authorName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text("Send a message to start video chat")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Usage indicator
            VStack {
                HStack {
                    Spacer()
                    usageIndicator
                }
                Spacer()
            }
            .padding()
        }
    }

    private var usageIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption2)
            Text("\(formatTime(manager.remainingSeconds)) left")
                .font(.caption2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Chat History

    private var chatHistoryView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(manager.messages) { message in
                    VideoChatBubble(message: message) {
                        // Replay video
                        if let videoURL = message.videoURL {
                            manager.playVideo(url: videoURL)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(height: 100)
        .background(Color(.systemGray6))
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // Text field
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...3)
                    .focused($isInputFocused)
                    .disabled(manager.isGenerating)

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSend ? .blue : .gray)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !manager.isGenerating
            && manager.remainingSeconds > 0
    }

    // MARK: - Actions

    private func sendMessage() {
        guard canSend else { return }

        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isInputFocused = false

        Task {
            await manager.sendMessage(
                sessionId: sessionId,
                content: content,
                authorId: authorId
            )
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: url)
                player?.play()
            }
            .onDisappear {
                player?.pause()
            }
    }
}

// MARK: - Video Chat Bubble

struct VideoChatBubble: View {
    let message: VideoChatMessage
    let onReplay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Thumbnail or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 60)

                if message.hasVideo {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            .onTapGesture {
                if message.hasVideo {
                    onReplay()
                }
            }

            // Message preview
            Text(message.content)
                .font(.caption2)
                .lineLimit(2)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
        }
    }
}

// MARK: - Video Chat Manager

// MARK: - API Response Types

struct VideoChatAvailabilityResponse: Decodable {
    let available: Bool
    let requiresPremium: Bool
    let remainingSeconds: Int
    let limitSeconds: Int
}

struct VideoChatResponse: Decodable {
    let id: String
    let content: String
    let videoUrl: String?
    let videoStatus: String
}

@MainActor
class VideoChatManager: ObservableObject {
    @Published var isAvailable = false
    @Published var requiresPremium = false
    @Published var remainingSeconds = 0
    @Published var limitSeconds = 0

    @Published var isGenerating = false
    @Published var statusMessage = "Generating video..."
    @Published var generationProgress: Double = 0

    @Published var currentVideoURL: URL?
    @Published var messages: [VideoChatMessage] = []

    private var statusCheckTimer: Timer?

    func checkAvailability(authorId: String) async {
        do {
            let response: VideoChatAvailabilityResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.videoChatAvailable(authorId)
            )

            requiresPremium = response.requiresPremium
            isAvailable = response.available
            remainingSeconds = response.remainingSeconds
            limitSeconds = response.limitSeconds
        } catch {
            // If API fails, show as unavailable
            requiresPremium = true
            isAvailable = false
            remainingSeconds = 0
            limitSeconds = 0
        }
    }

    func sendMessage(sessionId: String, content: String, authorId: String) async {
        isGenerating = true
        statusMessage = "Sending message..."
        generationProgress = 0.1

        // Add user message
        let userMessage = VideoChatMessage(
            id: UUID().uuidString,
            content: content,
            isUser: true,
            videoURL: nil,
            createdAt: Date()
        )
        messages.append(userMessage)

        do {
            statusMessage = "Getting AI response..."
            generationProgress = 0.3

            let request = SendMessageRequest(content: content)
            let response: VideoChatResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.videoChatChat(sessionId),
                method: .post,
                body: request
            )

            statusMessage = "Processing video..."
            generationProgress = 0.7

            // Create author message with video URL if available
            let videoURL = response.videoUrl.flatMap { URL(string: $0) }
            let authorMessage = VideoChatMessage(
                id: response.id,
                content: response.content,
                isUser: false,
                videoURL: videoURL,
                createdAt: Date()
            )
            messages.append(authorMessage)

            // Update current video if available
            if let url = videoURL {
                currentVideoURL = url
            }

            generationProgress = 1.0
            statusMessage = "Complete"
        } catch {
            statusMessage = "Failed to send message"
            // Remove the optimistic user message on failure
            messages.removeAll { $0.id == userMessage.id }
        }

        isGenerating = false
    }

    func playVideo(url: URL) {
        currentVideoURL = url
    }
}

// MARK: - Video Chat Message

struct VideoChatMessage: Identifiable {
    let id: String
    let content: String
    let isUser: Bool
    let videoURL: URL?
    let createdAt: Date

    var hasVideo: Bool {
        videoURL != nil
    }
}

