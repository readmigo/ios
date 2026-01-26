import SwiftUI

struct QuoteDetailView: View {
    let quote: Quote
    @StateObject private var manager = QuotesManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Quote Card
                    VStack(alignment: .leading, spacing: 20) {
                        // Quote mark
                        Image(systemName: "quote.opening")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor.opacity(0.5))

                        // Quote text
                        Text(quote.text)
                            .font(.title2)
                            .fontWeight(.medium)
                            .italic()
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        // Author and source
                        VStack(alignment: .leading, spacing: 8) {
                            Text("— \(quote.author)")
                                .font(.headline)
                                .foregroundColor(.primary)

                            if let bookTitle = quote.bookTitle {
                                HStack(spacing: 4) {
                                    Image(systemName: "book.closed")
                                        .font(.caption)
                                    Text(bookTitle)
                                        .font(.subheadline)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)

                    // Tags
                    if let tags = quote.tags, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tags")
                                .font(.headline)
                                .foregroundColor(.primary)

                            FlowLayout(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }

                    // Stats
                    HStack(spacing: 32) {
                        StatItem(
                            icon: "heart.fill",
                            value: "\(quote.likeCount)",
                            label: "Likes",
                            color: .red
                        )

                        if let shareCount = quote.shareCount {
                            StatItem(
                                icon: "square.and.arrow.up.fill",
                                value: "\(shareCount)",
                                label: "Shares",
                                color: .blue
                            )
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)

                    // Actions
                    VStack(spacing: 12) {
                        // Like Button
                        Button(action: {
                            Task { await manager.toggleLike(quote: quote) }
                        }) {
                            HStack {
                                Image(systemName: quote.isLiked == true ? "heart.fill" : "heart")
                                Text(quote.isLiked == true ? "Liked" : "Like this quote")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(quote.isLiked == true ? Color.red.opacity(0.1) : Color(.systemGray6))
                            .foregroundColor(quote.isLiked == true ? .red : .primary)
                            .cornerRadius(12)
                        }

                        // Share Button
                        Button(action: shareQuote) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        // Create Postcard Button
                        NavigationLink {
                            // PostcardEditorView(quote: quote)
                            Text("Postcard Editor Coming Soon")
                        } label: {
                            HStack {
                                Image(systemName: "photo.artframe")
                                Text("Create Postcard")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func shareQuote() {
        let text = "\"\(quote.text)\"\n— \(quote.author)"
        if let bookTitle = quote.bookTitle {
            let fullText = "\(text)\nFrom: \(bookTitle)"
            share(fullText)
        } else {
            share(text)
        }
    }

    private func share(_ text: String) {
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(value)
                    .font(.headline)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
