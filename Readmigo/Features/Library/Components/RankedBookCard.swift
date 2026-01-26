import SwiftUI

/// Ranked book card with position number overlay
struct RankedBookCard: View {
    let book: Book
    let rank: Int
    let onTap: () -> Void

    private let dimensions = BookCoverDimensions.rankedCarousel

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover with rank badge
                ZStack(alignment: .bottomLeading) {
                    BookCoverView(
                        coverUrl: book.coverUrl,
                        dimensions: dimensions,
                        cornerRadius: 8,
                        source: book.source
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    // Rank badge
                    RankBadge(rank: rank)
                        .offset(x: -8, y: 8)
                }

                // Title
                Text(book.localizedTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Author
                Text(book.localizedAuthor)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: dimensions.width + 10) // Extra width for rank badge overflow
        }
        .buttonStyle(.plain)
    }
}

/// Rank badge with gold/silver/bronze styling for top 3
struct RankBadge: View {
    let rank: Int

    var body: some View {
        ZStack {
            // Glow effect for top 3
            if rank <= 3 {
                Circle()
                    .fill(rankColor.opacity(0.3))
                    .frame(width: badgeSize + 8, height: badgeSize + 8)
                    .blur(radius: 4)
            }

            // Badge circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: badgeSize, height: badgeSize)
                .shadow(color: rankColor.opacity(0.5), radius: rank <= 3 ? 4 : 2)

            // Rank number
            Text("\(rank)")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Crown for #1
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
                    .offset(y: -badgeSize / 2 - 4)
            }
        }
    }

    private var badgeSize: CGFloat {
        switch rank {
        case 1: return 36
        case 2, 3: return 32
        default: return 28
        }
    }

    private var fontSize: CGFloat {
        switch rank {
        case 1: return 18
        case 2, 3: return 16
        default: return 14
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)      // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)    // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)    // Bronze
        default: return Color(red: 0.56, green: 0.56, blue: 0.58)   // Gray
        }
    }

    private var gradientColors: [Color] {
        switch rank {
        case 1:
            return [
                Color(red: 1.0, green: 0.90, blue: 0.4),
                Color(red: 1.0, green: 0.75, blue: 0.0)
            ]
        case 2:
            return [
                Color(red: 0.85, green: 0.85, blue: 0.90),
                Color(red: 0.65, green: 0.65, blue: 0.70)
            ]
        case 3:
            return [
                Color(red: 0.90, green: 0.65, blue: 0.35),
                Color(red: 0.70, green: 0.40, blue: 0.15)
            ]
        default:
            return [
                Color(red: 0.65, green: 0.65, blue: 0.68),
                Color(red: 0.45, green: 0.45, blue: 0.48)
            ]
        }
    }
}

// MARK: - Ranked Carousel Section

struct RankedCarouselSection: View {
    let title: String
    let books: [Book]
    let onTap: (Book) -> Void
    let onSeeAll: (() -> Void)?

    init(
        title: String,
        books: [Book],
        onTap: @escaping (Book) -> Void,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.title = title
        self.books = books
        self.onTap = onTap
        self.onSeeAll = onSeeAll
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)

                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.orange)

                Spacer()

                if let onSeeAll = onSeeAll {
                    Button("button.seeAll".localized, action: onSeeAll)
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                        RankedBookCard(
                            book: book,
                            rank: index + 1,
                            onTap: { onTap(book) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8) // Extra padding for rank badge overflow
            }
        }
    }
}

