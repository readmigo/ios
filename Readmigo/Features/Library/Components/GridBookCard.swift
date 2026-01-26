import SwiftUI

/// Compact grid book card for 3-column layouts
struct GridBookCard: View {
    let book: Book
    let showDifficulty: Bool
    let onTap: () -> Void

    init(
        book: Book,
        showDifficulty: Bool = true,
        onTap: @escaping () -> Void
    ) {
        self.book = book
        self.showDifficulty = showDifficulty
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Cover with fixed aspect ratio
                GeometryReader { geometry in
                    BookCoverView(
                        coverUrl: book.coverUrl,
                        dimensions: BookCoverDimensions(
                            width: geometry.size.width,
                            height: geometry.size.width * 1.5
                        ),
                        cornerRadius: 6,
                        source: book.source
                    )
                }
                .aspectRatio(2/3, contentMode: .fit)

                // Title
                Text(book.localizedTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32) // Fixed height for 2 lines

                // Difficulty badge (optional)
                if showDifficulty {
                    DifficultyBadge(score: book.difficultyScore)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Grid Section

struct CompactGridSection: View {
    let title: String
    let books: [Book]
    let showDifficulty: Bool
    let onTap: (Book) -> Void
    let onSeeAll: (() -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(
        title: String,
        books: [Book],
        showDifficulty: Bool = true,
        onTap: @escaping (Book) -> Void,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.title = title
        self.books = books
        self.showDifficulty = showDifficulty
        self.onTap = onTap
        self.onSeeAll = onSeeAll
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                if let onSeeAll = onSeeAll {
                    Button("button.seeAll".localized, action: onSeeAll)
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(books) { book in
                    GridBookCard(
                        book: book,
                        showDifficulty: showDifficulty,
                        onTap: { onTap(book) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

