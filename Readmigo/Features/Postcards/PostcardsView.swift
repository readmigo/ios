import SwiftUI

struct PostcardsView: View {
    @StateObject private var manager = PostcardsManager.shared
    @EnvironmentObject var authManager: AuthManager
    @State private var showEditor = false
    @State private var selectedPostcard: Postcard?
    @State private var showDeleteConfirmation = false
    @State private var postcardToDelete: Postcard?

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            // Show login required view for guests
            if !authManager.isAuthenticated {
                LoginRequiredView(feature: "postcards")
            } else {
                postcardsContent
            }
        }
    }

    @ViewBuilder
    private var postcardsContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                if manager.postcards.isEmpty && !manager.isLoading {
                    EmptyPostcardsView(onCreateTapped: { showEditor = true })
                } else {
                    // Stats Header
                    StatsHeader(count: manager.totalCount)

                    // Postcards Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(manager.postcards) { postcard in
                            PostcardGridItem(postcard: postcard)
                                .onTapGesture {
                                    selectedPostcard = postcard
                                }
                                .contextMenu {
                                    Button {
                                        sharePostcard(postcard)
                                    } label: {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }

                                    Button(role: .destructive) {
                                        postcardToDelete = postcard
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)

                    // Load More
                    if manager.hasMorePages {
                        Button("Load More") {
                            Task {
                                await manager.fetchPostcards()
                            }
                        }
                        .padding()
                    }

                    if manager.isLoading {
                        ProgressView()
                            .padding()
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("My Postcards")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showEditor = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .elegantRefreshable {
            await manager.fetchPostcards(refresh: true)
        }
        .sheet(isPresented: $showEditor) {
            PostcardEditorView()
        }
        .sheet(item: $selectedPostcard) { postcard in
            PostcardPreviewView(postcard: postcard)
        }
        .confirmationDialog(
            "Delete Postcard",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let postcard = postcardToDelete {
                    Task {
                        await manager.deletePostcard(id: postcard.id)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this postcard? This action cannot be undone.")
        }
        .task {
            if manager.postcards.isEmpty {
                await manager.fetchPostcards(refresh: true)
            }
        }
    }

    private func sharePostcard(_ postcard: Postcard) {
        Task {
            if let response = await manager.sharePostcard(id: postcard.id, platform: .other) {
                // Share via system sheet
                if let url = URL(string: response.shareUrl) {
                    await MainActor.run {
                        let activityVC = UIActivityViewController(
                            activityItems: [url],
                            applicationActivities: nil
                        )

                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            rootVC.present(activityVC, animated: true)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Stats Header

private struct StatsHeader: View {
    let count: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Postcards Created")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "photo.stack")
                .font(.title)
                .foregroundColor(.accentColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Postcard Grid Item

struct PostcardGridItem: View {
    let postcard: Postcard

    var body: some View {
        VStack(spacing: 0) {
            // Postcard Preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(postcard.bgColor)

                if let imageUrl = postcard.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .clipped()
                }

                // Quote overlay
                VStack {
                    Spacer()
                    Text(postcard.displayText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(postcard.txtColor)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(12)
                    Spacer()
                }
            }
            .aspectRatio(3/4, contentMode: .fit)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            // Meta info
            HStack {
                Text(formatDate(postcard.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                if postcard.shareCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "square.and.arrow.up")
                        Text("\(postcard.shareCount)")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Empty State

struct EmptyPostcardsView: View {
    let onCreateTapped: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Postcards Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Create beautiful postcards from your favorite quotes and share them with the world.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: onCreateTapped) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Your First Postcard")
                }
                .fontWeight(.semibold)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding()
    }
}
