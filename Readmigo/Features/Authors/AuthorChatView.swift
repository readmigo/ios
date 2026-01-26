import SwiftUI

/// Chat view for conversing with AI-simulated author personas
struct AuthorChatView: View {
    let authorId: String
    @StateObject private var manager = AuthorManager.shared
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var sessionId: String?
    @State private var showVoiceChat = false
    @State private var showVideoChat = false
    @FocusState private var isInputFocused: Bool

    init(authorId: String) {
        self.authorId = authorId
    }

    private let avatarColors: [Color] = [
        Color(red: 0.91, green: 0.30, blue: 0.24),
        Color(red: 0.90, green: 0.49, blue: 0.13),
        Color(red: 0.18, green: 0.80, blue: 0.44),
        Color(red: 0.20, green: 0.60, blue: 0.86),
        Color(red: 0.56, green: 0.27, blue: 0.68),
        Color(red: 0.10, green: 0.74, blue: 0.61),
        Color(red: 0.95, green: 0.77, blue: 0.06),
        Color(red: 0.40, green: 0.50, blue: 0.60),
    ]

    var body: some View {
        NavigationStack {
            // Show login required view for guests
            if !authManager.isAuthenticated {
                LoginRequiredView(feature: "chat")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                dismiss()
                            }
                        }
                    }
            } else {
                chatContent
            }
        }
    }

    @ViewBuilder
    private var chatContent: some View {
        VStack(spacing: 0) {
            // Messages
            messagesView

            // Input bar
            inputBar
        }
        .navigationTitle(authorName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                authorAvatar
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Voice chat button
                    Button {
                        showVoiceChat = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                    }

                    // Video chat button
                    Button {
                        showVideoChat = true
                    } label: {
                        Image(systemName: "video.fill")
                            .foregroundColor(.blue)
                    }

                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showVoiceChat) {
            if let sessionId = sessionId {
                VoiceChatView(authorId: authorId, sessionId: sessionId)
            }
        }
        .sheet(isPresented: $showVideoChat) {
            if let sessionId = sessionId {
                VideoChatView(authorId: authorId, sessionId: sessionId)
            }
        }
        .task {
            await initializeChat()
        }
        .onDisappear {
            manager.clearCurrentSession()
        }
    }

    // MARK: - Computed Properties

    private var authorName: String {
        manager.currentAuthorDetail?.name ?? "Author"
    }

    private var authorInitials: String {
        manager.currentAuthorDetail?.initials ?? "AU"
    }

    private var authorColorIndex: Int {
        manager.currentAuthorDetail?.avatarColorIndex ?? 0
    }

    // MARK: - Author Avatar

    private var authorAvatar: some View {
        ZStack {
            Circle()
                .fill(avatarColors[authorColorIndex])
                .frame(width: 32, height: 32)

            if let avatarUrl = manager.currentAuthorDetail?.avatarUrl,
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

    // MARK: - Messages View

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Welcome message
                    if manager.currentMessages.isEmpty && !manager.isLoadingChat {
                        welcomeMessage
                    }

                    // Chat messages
                    ForEach(manager.currentMessages) { message in
                        ChatBubble(
                            message: message,
                            authorName: authorName,
                            authorInitials: authorInitials,
                            avatarColor: avatarColors[authorColorIndex]
                        )
                        .id(message.id)
                    }

                    // Loading indicator
                    if manager.isSendingMessage {
                        typingIndicator
                    }
                }
                .padding()
            }
            .onChange(of: manager.currentMessages.count) { _ in
                if let lastMessage = manager.currentMessages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var welcomeMessage: some View {
        VStack(spacing: 16) {
            // Author avatar large
            ZStack {
                Circle()
                    .fill(avatarColors[authorColorIndex])
                    .frame(width: 80, height: 80)

                Text(authorInitials)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            VStack(spacing: 8) {
                Text("Chat with \(authorName)")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Ask questions about their life, works, writing style, or anything else you're curious about.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Suggested questions
            VStack(spacing: 8) {
                Text("Try asking:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(suggestedQuestions, id: \.self) { question in
                    Button {
                        messageText = question
                    } label: {
                        Text(question)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }

    private var suggestedQuestions: [String] {
        [
            "What inspired you to become a writer?",
            "Tell me about your most famous work.",
            "What was life like in your time?",
        ]
    }

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Author avatar
            ZStack {
                Circle()
                    .fill(avatarColors[authorColorIndex])
                    .frame(width: 32, height: 32)

                Text(authorInitials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            // Typing dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .opacity(0.6)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: manager.isSendingMessage
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .cornerRadius(16)

            Spacer()
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
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
                    .lineLimit(1...5)
                    .focused($isInputFocused)

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
            && !manager.isSendingMessage
    }

    // MARK: - Actions

    private func initializeChat() async {
        // Create a new session if we don't have one
        if sessionId == nil {
            sessionId = await manager.createChatSession(authorId: authorId)
        }
    }

    private func sendMessage() {
        guard canSend, let sessionId = sessionId else { return }

        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isInputFocused = false

        Task {
            await manager.sendMessage(sessionId, content: content)
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    let authorName: String
    let authorInitials: String
    let avatarColor: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
                userBubble
            } else {
                authorBubble
                Spacer(minLength: 60)
            }
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(16)

            Text(formatTime(message.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var authorBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Author avatar
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 32, height: 32)

                Text(authorInitials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(authorName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .cornerRadius(16)

                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
