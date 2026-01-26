import SwiftUI

struct PostcardPreviewView: View {
    @StateObject private var manager = PostcardsManager.shared
    @Environment(\.dismiss) private var dismiss

    let postcard: Postcard
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var generatedImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Postcard Display
                    PostcardDisplayView(postcard: postcard)
                        .padding(.horizontal)

                    // Quote Info
                    if let quote = postcard.quote {
                        QuoteInfoCard(quote: quote)
                            .padding(.horizontal)
                    }

                    // Actions
                    VStack(spacing: 12) {
                        Button(action: sharePostcard) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Postcard")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: saveToPhotos) {
                            HStack {
                                Image(systemName: "photo")
                                Text("Save to Photos")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }

                        Button(action: { showDeleteConfirmation = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)

                    // Meta Info
                    MetaInfoCard(postcard: postcard)
                        .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Postcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = generatedImage {
                    ShareSheet(items: [image])
                }
            }
            .confirmationDialog(
                "Delete Postcard",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await manager.deletePostcard(id: postcard.id) {
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this postcard? This action cannot be undone.")
            }
        }
    }

    private func sharePostcard() {
        // Generate image for sharing
        let size = CGSize(width: 600, height: 800)
        let view = PostcardImageView(postcard: postcard)

        if let image = manager.generatePostcardImage(from: view, size: size) {
            generatedImage = image
            showShareSheet = true
        }

        // Also track share via API
        Task {
            _ = await manager.sharePostcard(id: postcard.id, platform: .other)
        }
    }

    private func saveToPhotos() {
        let size = CGSize(width: 600, height: 800)
        let view = PostcardImageView(postcard: postcard)

        if let image = manager.generatePostcardImage(from: view, size: size) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            // Show success feedback
        }
    }
}

// MARK: - Postcard Display View

struct PostcardDisplayView: View {
    let postcard: Postcard

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(postcard.bgColor)

            if let imageUrl = postcard.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
                .clipped()
            }

            VStack(spacing: 16) {
                Spacer()

                Text(postcard.displayText)
                    .font(fontFromFamily(postcard.fontFamily, size: 20))
                    .foregroundColor(postcard.txtColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let author = postcard.quote?.author {
                    Text("— \(author)")
                        .font(.subheadline)
                        .foregroundColor(postcard.txtColor.opacity(0.8))
                }

                Spacer()
            }
            .padding()
        }
        .aspectRatio(3/4, contentMode: .fit)
        .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
    }

    private func fontFromFamily(_ family: String?, size: CGFloat) -> Font {
        guard let family = family else { return .system(size: size) }
        switch family {
        case "Georgia": return .custom("Georgia", size: size)
        case "Menlo": return .custom("Menlo", size: size)
        case "SF Pro Rounded": return .system(size: size, design: .rounded)
        default: return .system(size: size)
        }
    }
}

// MARK: - Postcard Image View (for export)

struct PostcardImageView: View {
    let postcard: Postcard

    var body: some View {
        ZStack {
            Rectangle()
                .fill(postcard.bgColor)

            VStack(spacing: 24) {
                Spacer()

                Text(postcard.displayText)
                    .font(.system(size: 24))
                    .foregroundColor(postcard.txtColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)

                if let author = postcard.quote?.author {
                    Text("— \(author)")
                        .font(.system(size: 16))
                        .foregroundColor(postcard.txtColor.opacity(0.8))
                }

                Spacer()

                // Branding
                Text("readmigo")
                    .font(.caption)
                    .foregroundColor(postcard.txtColor.opacity(0.4))
                    .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Quote Info Card

struct QuoteInfoCard: View {
    let quote: PostcardQuote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quote Details")
                .font(.headline)

            if let author = quote.author {
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    Text(author)
                }
                .font(.subheadline)
            }

            if let source = quote.source {
                HStack {
                    Image(systemName: "book")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    Text(source)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Meta Info Card

struct MetaInfoCard: View {
    let postcard: Postcard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            HStack {
                Text("Created")
                Spacer()
                Text(formatDate(postcard.createdAt))
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            HStack {
                Text("Visibility")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: postcard.isPublic ? "globe" : "lock")
                    Text(postcard.isPublic ? "Public" : "Private")
                }
                .foregroundColor(.secondary)
            }
            .font(.subheadline)

            HStack {
                Text("Shares")
                Spacer()
                Text("\(postcard.shareCount)")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
