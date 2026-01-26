import SwiftUI

/// Horizontal list row view for search results and compact lists
struct BookRowView: View {
    let book: Book
    let showProgress: Bool
    let progress: Double?
    let onTap: () -> Void

    private let dimensions = BookCoverDimensions.listRow

    init(
        book: Book,
        showProgress: Bool = false,
        progress: Double? = nil,
        onTap: @escaping () -> Void
    ) {
        self.book = book
        self.showProgress = showProgress
        self.progress = progress
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Cover
                BookCoverView(
                    coverUrl: book.coverUrl,
                    dimensions: dimensions,
                    cornerRadius: 6,
                    source: book.source
                )

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.localizedTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(book.localizedAuthor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        DifficultyBadge(score: book.difficultyScore)

                        if let wordCount = book.formattedWordCount {
                            Text(wordCount)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Progress bar (optional)
                    if showProgress, let progress = progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Book List Section

struct BookListSection: View {
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

            VStack(spacing: 0) {
                ForEach(books) { book in
                    BookRowView(book: book) {
                        onTap(book)
                    }
                    .padding(.horizontal)

                    if book.id != books.last?.id {
                        Divider()
                            .padding(.leading, 88) // Align with text after cover
                    }
                }
            }
        }
    }
}

// MARK: - Search Results Section (using BookRowView)

struct SearchResultsListSection: View {
    let results: [Book]
    let query: String
    let onTap: (Book) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(format: "search.resultsFor".localized, query))
                .font(.headline)
                .padding(.horizontal)

            if results.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(results) { book in
                        BookRowView(book: book) {
                            onTap(book)
                        }
                        .padding(.horizontal)

                        if book.id != results.last?.id {
                            Divider()
                                .padding(.leading, 88)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("search.noResults".localized)
                .font(.headline)
                .foregroundColor(.secondary)

            Text("search.tryDifferent".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

