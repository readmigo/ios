import Foundation

// MARK: - Discover Tab Model

/// Tab type for discover page
enum DiscoverTabType: String, Codable {
    case recommendation
    case category
}

/// Discover tab configuration from backend
struct DiscoverTab: Codable, Identifiable, Equatable {
    let id: String
    let slug: String
    let name: String
    let type: DiscoverTabType
    let categoryId: String?
    let icon: String?
    let sortOrder: Int

    /// Localized display name - uses server-returned name directly
    /// Server handles localization based on Accept-Language header
    var displayName: String {
        name
    }

    /// SF Symbol name for the icon
    var sfSymbolName: String {
        switch icon {
        case "sparkles": return "sparkles"
        case "book-open": return "book"
        case "clock": return "clock"
        case "lightbulb": return "lightbulb"
        case "beaker": return "flask"
        case "face-smile": return "face.smiling"
        case "chart-line": return "chart.line.uptrend.xyaxis"
        case "book": return "book.closed"
        default: return "book"
        }
    }
}

/// Response wrapper for discover tabs
struct DiscoverTabsResponse: Codable {
    let tabs: [DiscoverTab]
}

// MARK: - Book With Score

/// Book with recommendation scores
struct BookWithScore: Codable, Identifiable, Equatable {
    let book: Book
    let scores: BookScores
    let source: String

    var id: String { book.id }

    static func == (lhs: BookWithScore, rhs: BookWithScore) -> Bool {
        lhs.book.id == rhs.book.id
    }
}

/// Recommendation scores for a book
struct BookScores: Codable, Equatable {
    let final: Double
    let quality: Double
    let popularity: Double
    let freshness: Double
}

/// Response for discover books API
struct DiscoverBooksResponse: Codable {
    let books: [BookWithScore]
    let total: Int
    let page: Int
    let pageSize: Int

    var hasMore: Bool {
        page * pageSize < total
    }
}
