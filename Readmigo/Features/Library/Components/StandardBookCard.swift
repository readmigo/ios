import SwiftUI

/// Standard book card for curated lists and collections
struct StandardBookCard: View {
    let book: Book
    let onTap: () -> Void

    private let dimensions = BookCoverDimensions.standardCarousel

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover
                BookCoverView(
                    coverUrl: book.coverUrl,
                    dimensions: dimensions,
                    cornerRadius: 8,
                    source: book.source
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

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
            .frame(width: dimensions.width)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Standard Carousel Section

struct StandardCarouselSection: View {
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

                Spacer()

                if let onSeeAll = onSeeAll {
                    Button("button.seeAll".localized, action: onSeeAll)
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(books) { book in
                        StandardBookCard(book: book) {
                            onTap(book)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

