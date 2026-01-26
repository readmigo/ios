import SwiftUI
import PhotosUI

// MARK: - Create Post View

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: AgoraManager
    @EnvironmentObject private var authManager: AuthManager

    @State private var content = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedMedia: [MediaItem] = []
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""

    private let maxContentLength = 2000
    private let maxMediaCount = 9

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // User info header
                    userHeader

                    // Text input area
                    textInputArea

                    // Selected media preview
                    if !selectedMedia.isEmpty {
                        mediaPreviewGrid
                    }

                    // Add media button
                    mediaPickerSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("agora.createPost".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .disabled(isUploading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("agora.publish".localized) {
                        Task {
                            await publishPost()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidPost || isUploading)
                }
            }
            .overlay {
                if isUploading {
                    uploadingOverlay
                }
            }
            .alert("error.title".localized, isPresented: $showError) {
                Button("common.ok".localized, role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - User Header

    private var userHeader: some View {
        HStack(spacing: 12) {
            SmallAvatarView(
                userName: authManager.currentUser?.displayName ?? "Me",
                avatarUrl: authManager.currentUser?.avatarUrl,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(authManager.currentUser?.displayName ?? "Me")
                    .font(.headline)
                Text("agora.postingAs".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Text Input Area

    private var textInputArea: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("agora.writeContent".localized)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $content)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .onChange(of: content) { _, newValue in
                        if newValue.count > maxContentLength {
                            content = String(newValue.prefix(maxContentLength))
                        }
                    }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // Character count
            Text("\(content.count)/\(maxContentLength)")
                .font(.caption)
                .foregroundColor(content.count > maxContentLength - 100 ? .orange : .secondary)
        }
    }

    // MARK: - Media Preview Grid

    private var mediaPreviewGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("agora.selectedMedia".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(selectedMedia.enumerated()), id: \.element.id) { index, item in
                    mediaPreviewItem(item, at: index)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func mediaPreviewItem(_ item: MediaItem, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = item.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 100)
                    .cornerRadius(8)
                    .overlay {
                        Image(systemName: item.type == .video ? "video" : "photo")
                            .foregroundColor(.secondary)
                    }
            }

            // Remove button
            Button {
                withAnimation {
                    _ = selectedMedia.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            .padding(4)
        }
    }

    // MARK: - Media Picker Section

    private var mediaPickerSection: some View {
        HStack(spacing: 16) {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: maxMediaCount - selectedMedia.count,
                matching: .any(of: [.images, .videos])
            ) {
                Label("agora.addMedia".localized, systemImage: "photo.on.rectangle.angled")
                    .font(.subheadline)
            }
            .disabled(selectedMedia.count >= maxMediaCount)
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    await loadSelectedMedia(newItems)
                }
            }

            Spacer()

            Text("agora.mediaCount".localized(with: selectedMedia.count, maxMediaCount))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Uploading Overlay

    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("agora.publishing".localized)
                    .font(.headline)
                    .foregroundColor(.white)

                if uploadProgress > 0 {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                        .tint(.white)
                }
            }
            .padding(32)
            .background(Color(.systemGray2).opacity(0.9))
            .cornerRadius(16)
        }
    }

    // MARK: - Validation

    private var isValidPost: Bool {
        let hasContent = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !selectedMedia.isEmpty
        let validLength = content.count <= maxContentLength
        return (hasContent || hasMedia) && validLength
    }

    // MARK: - Load Selected Media

    private func loadSelectedMedia(_ items: [PhotosPickerItem]) async {
        for item in items {
            // Check if already loaded
            if selectedMedia.contains(where: { $0.pickerItemId == item.itemIdentifier }) {
                continue
            }

            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }

                    let mediaItem = MediaItem(
                        id: UUID().uuidString,
                        pickerItemId: item.itemIdentifier,
                        type: isVideo ? .video : .image,
                        data: data,
                        thumbnail: UIImage(data: data)
                    )

                    await MainActor.run {
                        if selectedMedia.count < maxMediaCount {
                            selectedMedia.append(mediaItem)
                        }
                    }
                }
            } catch {
                LoggingService.shared.error(.agora, "Failed to load media: \(error)", component: "CreatePostView")
            }
        }

        // Clear picker selection
        await MainActor.run {
            selectedItems = []
        }
    }

    // MARK: - Publish Post

    private func publishPost() async {
        isUploading = true
        uploadProgress = 0

        do {
            // Upload media files first
            var mediaIds: [String] = []
            let totalMedia = selectedMedia.count

            for (index, item) in selectedMedia.enumerated() {
                let response = try await manager.uploadMedia(
                    data: item.data,
                    fileName: "\(item.id).\(item.type == .video ? "mp4" : "jpg")",
                    mimeType: item.type == .video ? "video/mp4" : "image/jpeg",
                    type: item.type == .video ? "VIDEO" : "IMAGE"
                )
                mediaIds.append(response.id)

                await MainActor.run {
                    uploadProgress = Double(index + 1) / Double(totalMedia + 1)
                }
            }

            // Create post
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let success = await manager.createUserPost(
                content: trimmedContent.isEmpty ? nil : trimmedContent,
                mediaIds: mediaIds.isEmpty ? nil : mediaIds
            )

            await MainActor.run {
                isUploading = false
                if success {
                    dismiss()
                } else if let error = manager.createPostError {
                    errorMessage = error
                    showError = true
                }
            }
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Media Item Model

struct MediaItem: Identifiable {
    let id: String
    let pickerItemId: String?
    let type: MediaType
    let data: Data
    let thumbnail: UIImage?

    enum MediaType {
        case image
        case video
        case audio
    }
}
