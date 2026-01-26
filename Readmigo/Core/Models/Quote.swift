import Foundation

// MARK: - Quote Source Type

enum QuoteSourceType: String, Codable {
    case book = "BOOK"
    case author = "AUTHOR"
}

// MARK: - Quote

struct Quote: Codable, Identifiable {
    let id: String
    let text: String
    let author: String
    let source: String?
    let sourceType: QuoteSourceType?
    let bookId: String?
    let bookTitle: String?
    let chapterId: String?
    let tags: [String]?
    let likeCount: Int
    let shareCount: Int?
    let isLiked: Bool?
    let createdAt: Date?
    let updatedAt: Date?
}

// MARK: - Quotes Response

struct QuotesResponse: Codable {
    let data: [Quote]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}

// MARK: - Single Quote Response

struct QuoteResponse: Codable {
    let quote: Quote
}

// MARK: - Tags Response

struct QuoteTagsResponse: Codable {
    let tags: [String]
}

// MARK: - Authors Response

struct QuoteAuthorsResponse: Codable {
    let authors: [String]
}

// MARK: - Quote Like Response

struct QuoteLikeResponse: Codable {
    let success: Bool
    let likeCount: Int
}
