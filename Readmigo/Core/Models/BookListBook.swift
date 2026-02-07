import Foundation

/// Book model specifically for book list items (matches API response from /booklists/:id)
struct BookListBook: Codable, Identifiable {
    let id: String
    let title: String
    let author: String
    let authorId: String?
    let description: String?
    let coverUrl: String?
    let coverThumbUrl: String?
    let difficultyScore: Double?
    let wordCount: Int?
    let genres: [String]?
    let doubanRating: Double?
    let goodreadsRating: Double?
    let rank: Int?
    let customDescription: String?

    var displayCoverUrl: String? {
        coverThumbUrl ?? coverUrl
    }

    var formattedWordCount: String? {
        guard let wc = wordCount else { return nil }
        if wc >= 1_000_000 { return String(format: "%.1fM", Double(wc) / 1_000_000) }
        if wc >= 1000 { return "\(wc / 1000)K" }
        return "\(wc)"
    }

    var difficultyLevel: String {
        guard let score = difficultyScore else { return "-" }
        switch score {
        case 0..<3: return "Easy"
        case 3..<5: return "Medium"
        case 5..<7: return "Challenging"
        default: return "Advanced"
        }
    }

    /// Convert to Book for navigation to BookDetailView
    func toBook() -> Book {
        Book(
            id: id,
            title: title,
            author: author,
            authorId: authorId,
            description: description,
            coverUrl: coverUrl,
            coverThumbUrl: coverThumbUrl,
            subjects: nil,
            genres: genres,
            difficultyScore: difficultyScore,
            fleschScore: nil,
            wordCount: wordCount,
            chapterCount: nil,
            source: nil,
            status: "ACTIVE",
            publishedAt: nil,
            createdAt: nil,
            hasAudiobook: nil,
            audiobookId: nil,
            stylesUrl: nil,
            doubanRating: doubanRating,
            goodreadsRating: goodreadsRating
        )
    }
}
