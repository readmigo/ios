import SwiftUI

/// Large hero book card for AI recommendations and personalized picks
struct HeroBookCard: View {
    let book: Book
    let showAITag: Bool
    let onTap: () -> Void

    private let dimensions = BookCoverDimensions.heroCarousel

    init(
        book: Book,
        showAITag: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.book = book
        self.showAITag = showAITag
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Cover with optional AI tag
                ZStack(alignment: .topTrailing) {
                    GradientBookCoverView(
                        coverUrl: book.coverUrl,
                        dimensions: dimensions,
                        genre: book.genres?.first,
                        cornerRadius: 12,
                        source: book.source
                    )
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                    if showAITag {
                        AIRecommendedTag()
                            .padding(8)
                    }
                }

                // Title
                Text(book.localizedTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Author
                Text(book.localizedAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Difficulty badge
                DifficultyBadge(score: book.difficultyScore)
            }
            .frame(width: dimensions.width)
        }
        .buttonStyle(.plain)
    }
}

/// AI Recommended tag badge
struct AIRecommendedTag: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 8))
            Text("AI")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(6)
    }
}

// MARK: - Hero Carousel Section

struct HeroCarouselSection: View {
    let title: String
    let books: [Book]
    let showAITag: Bool
    let onTap: (Book) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                if showAITag {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(books) { book in
                        HeroBookCard(
                            book: book,
                            showAITag: showAITag,
                            onTap: { onTap(book) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

