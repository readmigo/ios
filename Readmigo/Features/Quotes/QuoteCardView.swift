import SwiftUI

struct QuoteCardView: View {
    let quote: Quote
    var onLike: (() -> Void)?
    var onShare: (() -> Void)?
    var onTap: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 16) {
                // Quote text
                Text("\"\(quote.text)\"")
                    .font(.body)
                    .italic()
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(5)

                // Author and source
                VStack(alignment: .leading, spacing: 4) {
                    Text("— \(quote.author)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if let bookTitle = quote.bookTitle {
                        Text(bookTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Tags
                if let tags = quote.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                // Actions
                HStack(spacing: 24) {
                    // Like button
                    Button(action: { onLike?() }) {
                        HStack(spacing: 4) {
                            Image(systemName: quote.isLiked == true ? "heart.fill" : "heart")
                                .foregroundColor(quote.isLiked == true ? .red : .secondary)
                            Text("\(quote.likeCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    // Share button
                    Button(action: { onShare?() }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Daily Quote Card (Featured Style)

struct DailyQuoteCardView: View {
    let quote: Quote
    var onLike: (() -> Void)?
    var onShare: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Daily Quote")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            // Quote text
            Text("\"\(quote.text)\"")
                .font(.title3)
                .fontWeight(.medium)
                .italic()
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)

            // Author
            Text("— \(quote.author)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            if let bookTitle = quote.bookTitle {
                Text(bookTitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            // Actions
            HStack(spacing: 24) {
                Button(action: { onLike?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: quote.isLiked == true ? "heart.fill" : "heart")
                            .foregroundColor(quote.isLiked == true ? .red : .white.opacity(0.8))
                        Text("\(quote.likeCount)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .buttonStyle(.plain)

                Button(action: { onShare?() }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}
