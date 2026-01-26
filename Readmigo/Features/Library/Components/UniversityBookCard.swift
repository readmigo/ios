import SwiftUI

/// University-style book card for 2-column academic layouts
struct UniversityBookCard: View {
    let book: Book
    let courseTag: String?
    let onTap: () -> Void

    init(
        book: Book,
        courseTag: String? = nil,
        onTap: @escaping () -> Void
    ) {
        self.book = book
        self.courseTag = courseTag
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Cover with fixed aspect ratio
                GeometryReader { geometry in
                    BookCoverView(
                        coverUrl: book.coverUrl,
                        dimensions: BookCoverDimensions(
                            width: geometry.size.width,
                            height: geometry.size.width * 1.5
                        ),
                        cornerRadius: 10,
                        source: book.source
                    )
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                }
                .aspectRatio(2/3, contentMode: .fit)

                // Title
                Text(book.localizedTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                // Author
                Text(book.localizedAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Difficulty progress bar
                DifficultyProgressBar(score: book.difficultyScore ?? 50.0)

                // Course tag (if available)
                if let courseTag = courseTag {
                    HStack(spacing: 4) {
                        Image(systemName: "graduationcap.fill")
                            .font(.caption2)
                        Text(courseTag)
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Difficulty level shown as a progress bar
struct DifficultyProgressBar: View {
    let score: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("difficulty.label".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(difficultyLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(difficultyColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))

                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(difficultyColor)
                        .frame(width: geometry.size.width * CGFloat(score) / 100)
                }
            }
            .frame(height: 4)
        }
    }

    private var difficultyLabel: String {
        switch score {
        case 0..<30: return "difficulty.easy".localized
        case 30..<50: return "difficulty.medium".localized
        case 50..<70: return "difficulty.challenging".localized
        default: return "difficulty.advanced".localized
        }
    }

    private var difficultyColor: Color {
        switch score {
        case 0..<30: return .green
        case 30..<50: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - University Grid Section

struct UniversityGridSection: View {
    let title: String
    let books: [Book]
    let onTap: (Book) -> Void
    let onSeeAll: (() -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

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
                HStack(spacing: 8) {
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()

                if let onSeeAll = onSeeAll {
                    Button("button.seeAll".localized, action: onSeeAll)
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(books) { book in
                    UniversityBookCard(
                        book: book,
                        courseTag: "Literature 101",
                        onTap: { onTap(book) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

