import SwiftUI

/// Message thread detail view (对话页)
struct MessageThreadView: View {
    @StateObject private var viewModel: MessageThreadViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isReplyFocused: Bool

    init(threadId: String) {
        _viewModel = StateObject(wrappedValue: MessageThreadViewModel(threadId: threadId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Thread info header
                        if let thread = viewModel.thread {
                            threadHeaderView(thread)
                        }

                        // Messages
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                showRating: shouldShowRating(for: message),
                                isRated: viewModel.ratedMessageIds.contains(message.id),
                                onRate: { rating in
                                    Task {
                                        await viewModel.submitRating(messageId: message.id, rating: rating)
                                    }
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    // Scroll to bottom when new message added
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Reply input (if thread is not closed)
            if !viewModel.isThreadClosed {
                replyInputView
            } else {
                closedThreadBanner
            }
        }
        .navigationTitle(viewModel.thread?.type.localizedNameKey.localized ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Only show menu for authenticated users (guest feedback doesn't support close)
                if AuthManager.shared.isAuthenticated && !viewModel.isThreadClosed {
                    Menu {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.closeThread()
                            }
                        } label: {
                            Label("Close Thread", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.loadThread()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func threadHeaderView(_ thread: MessageThread) -> some View {
        VStack(spacing: 8) {
            // Status badge
            HStack {
                Text("Status:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(thread.status.localizedNameKey.localized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor(thread.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor(thread.status).opacity(0.1))
                    .cornerRadius(4)

                Spacer()

                Text(formattedDate(thread.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Subject
            Text(thread.subject)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var replyInputView: some View {
        VStack(spacing: 8) {
            // Pending attachments preview
            if !viewModel.pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.pendingAttachments) { attachment in
                            ZStack(alignment: .topTrailing) {
                                if let image = attachment.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                        .clipped()
                                }

                                Button {
                                    viewModel.removeAttachment(id: attachment.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Input row
            HStack(spacing: 12) {
                // Attachment button
                AttachmentButton(
                    canAdd: viewModel.pendingAttachments.count < viewModel.maxAttachments,
                    onImageSelected: { image in
                        viewModel.addAttachment(image: image)
                    }
                )

                // Text field
                TextField("messaging.replyPlaceholder".localized, text: $viewModel.replyText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .focused($isReplyFocused)

                // Send button
                Button {
                    Task {
                        await viewModel.sendReply()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(viewModel.canSendReply ? .accentColor : .gray)
                }
                .disabled(!viewModel.canSendReply)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var closedThreadBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)

            Text("This conversation has been closed")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Helpers

    private func shouldShowRating(for message: Message) -> Bool {
        // Don't show rating for guest feedback (no backend endpoint)
        guard AuthManager.shared.isAuthenticated else { return false }
        // Show rating for the last support message
        guard message.senderType == .support else { return false }
        guard let lastSupportMessage = viewModel.messages.last(where: { $0.senderType == .support }) else { return false }
        return message.id == lastSupportMessage.id
    }

    private func statusColor(_ status: ThreadStatus) -> Color {
        switch status {
        case .open: return .orange
        case .replied: return .blue
        case .closed: return .gray
        case .resolved: return .green
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Attachment button with photo picker
struct AttachmentButton: View {
    let canAdd: Bool
    let onImageSelected: (UIImage) -> Void

    @State private var showingPicker = false
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundColor(canAdd ? .accentColor : .gray)
        }
        .disabled(!canAdd)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let item = newItem,
                   let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onImageSelected(image)
                }
                selectedItem = nil
            }
        }
    }
}

import PhotosUI
