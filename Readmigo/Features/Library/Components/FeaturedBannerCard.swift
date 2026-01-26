import SwiftUI

/// Full-width featured banner card for spotlight books
struct FeaturedBannerCard: View {
    let book: Book
    let tag: String
    let onTap: () -> Void
    let onAction: (() -> Void)?

    private let dimensions = BookCoverDimensions.featuredBanner

    init(
        book: Book,
        tag: String = "Today's Pick",
        onTap: @escaping () -> Void,
        onAction: (() -> Void)? = nil
    ) {
        self.book = book
        self.tag = tag
        self.onTap = onTap
        self.onAction = onAction
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Book Cover
                BookCoverView(
                    coverUrl: book.coverUrl,
                    dimensions: dimensions,
                    cornerRadius: 10,
                    source: book.source
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Tag
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text(tag)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white.opacity(0.9))

                    // Title
                    Text(book.localizedTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)

                    // Author
                    Text("by \(book.localizedAuthor)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)

                    // Book info summary (genres + word count + subjects)
                    let infoComponents = buildBookInfoComponents(book: book)
                    if !infoComponents.isEmpty {
                        Text(infoComponents.joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }

                    Spacer()

                    // Bottom row
                    HStack(spacing: 12) {
                        DifficultyBadge(score: book.difficultyScore)

                        if let onAction = onAction {
                            Spacer()
                            Button(action: onAction) {
                                HStack(spacing: 4) {
                                    Text("Read Now")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(14)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .frame(height: 200)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var gradientColors: [Color] {
        let genre = book.genres?.first?.lowercased() ?? ""

        switch genre {
        case let g where g.contains("fiction"):
            return [Color(red: 0.2, green: 0.4, blue: 0.8), Color(red: 0.5, green: 0.3, blue: 0.7)]
        case let g where g.contains("classic"):
            return [Color(red: 0.6, green: 0.4, blue: 0.2), Color(red: 0.4, green: 0.3, blue: 0.2)]
        case let g where g.contains("romance"):
            return [Color(red: 0.9, green: 0.4, blue: 0.5), Color(red: 0.7, green: 0.2, blue: 0.4)]
        case let g where g.contains("mystery"):
            return [Color(red: 0.3, green: 0.3, blue: 0.4), Color(red: 0.1, green: 0.1, blue: 0.2)]
        case let g where g.contains("science"):
            return [Color(red: 0.2, green: 0.6, blue: 0.8), Color(red: 0.1, green: 0.4, blue: 0.6)]
        case let g where g.contains("fantasy"):
            return [Color(red: 0.6, green: 0.3, blue: 0.7), Color(red: 0.4, green: 0.2, blue: 0.5)]
        default:
            return [Color(red: 0.3, green: 0.5, blue: 0.7), Color(red: 0.2, green: 0.3, blue: 0.5)]
        }
    }

    /// Build book info components for display (genres + word count + subjects)
    private func buildBookInfoComponents(book: Book) -> [String] {
        var components: [String] = []

        // Add word count
        if let wordCount = book.wordCount {
            if wordCount >= 10000 {
                components.append("\(wordCount / 10000)万字")
            } else if wordCount >= 1000 {
                components.append("\(wordCount / 1000)k words")
            }
        }

        // Add subjects (first 2, excluding duplicates with genres)
        if let subjects = book.subjects, !subjects.isEmpty {
            let genreSet = Set((book.genres ?? []).map { $0.lowercased() })
            let filteredSubjects = subjects
                .filter { !genreSet.contains($0.lowercased()) }
                .prefix(2)
            if !filteredSubjects.isEmpty {
                components.append(contentsOf: filteredSubjects)
            }
        }

        return components
    }
}

