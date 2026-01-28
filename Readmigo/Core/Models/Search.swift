import Foundation

// MARK: - Search Query

struct SearchQuery: Codable {
    let query: String
    let bookId: String?
    let chapterId: String?
    let searchType: SearchType
    let caseSensitive: Bool
    let wholeWord: Bool
    let maxResults: Int

    init(
        query: String,
        bookId: String? = nil,
        chapterId: String? = nil,
        searchType: SearchType = .keyword,
        caseSensitive: Bool = false,
        wholeWord: Bool = false,
        maxResults: Int = 100
    ) {
        self.query = query
        self.bookId = bookId
        self.chapterId = chapterId
        self.searchType = searchType
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.maxResults = maxResults
    }
}

// MARK: - Search Type

enum SearchType: String, Codable, CaseIterable {
    case keyword
    case semantic
    case regex

    var displayName: String {
        switch self {
        case .keyword: return "Keyword"
        case .semantic: return "AI Semantic"
        case .regex: return "Regular Expression"
        }
    }

    var icon: String {
        switch self {
        case .keyword: return "magnifyingglass"
        case .semantic: return "brain.head.profile"
        case .regex: return "chevron.left.forwardslash.chevron.right"
        }
    }

    var description: String {
        switch self {
        case .keyword: return "Find exact matches"
        case .semantic: return "Find by meaning using AI"
        case .regex: return "Advanced pattern matching"
        }
    }
}

// MARK: - Search Result

struct SearchResult: Codable, Identifiable {
    let id: String
    let bookId: String
    let bookTitle: String?
    let chapterId: String
    let chapterTitle: String
    let chapterIndex: Int
    let matchedText: String
    let contextBefore: String
    let contextAfter: String
    let position: SearchPosition
    let relevanceScore: Double?
    let highlightRanges: [HighlightRange]

    var fullContext: String {
        "\(contextBefore)\(matchedText)\(contextAfter)"
    }
}

// MARK: - Search Position

struct SearchPosition: Codable {
    let paragraphIndex: Int
    let characterOffset: Int
    let length: Int
    let scrollPercentage: Double

    func toBookmarkPosition(chapterIndex: Int) -> BookmarkPosition {
        BookmarkPosition(
            chapterIndex: chapterIndex,
            paragraphIndex: paragraphIndex,
            characterOffset: characterOffset,
            scrollPercentage: scrollPercentage,
            cfiPath: nil
        )
    }
}

// MARK: - Highlight Range

struct HighlightRange: Codable {
    let start: Int
    let length: Int
}

// MARK: - Search Response

struct SearchResponse: Codable {
    let results: [SearchResult]
    let totalMatches: Int
    let searchTime: Double
    let query: String
    let hasMore: Bool
}

// MARK: - Search History

struct SearchHistoryItem: Codable, Identifiable {
    let id: String
    let query: String
    let searchType: SearchType
    let bookId: String?
    let resultsCount: Int
    let timestamp: Date

    init(query: String, searchType: SearchType, bookId: String? = nil, resultsCount: Int) {
        self.id = UUID().uuidString
        self.query = query
        self.searchType = searchType
        self.bookId = bookId
        self.resultsCount = resultsCount
        self.timestamp = Date()
    }
}

// MARK: - Search Scope

enum SearchScope: String, CaseIterable {
    case currentBook
    case currentChapter
    case allBooks
    case library

    var displayName: String {
        switch self {
        case .currentBook: return "This Book"
        case .currentChapter: return "This Chapter"
        case .allBooks: return "All Books"
        case .library: return "My Library"
        }
    }

    var icon: String {
        switch self {
        case .currentBook: return "book"
        case .currentChapter: return "doc.text"
        case .allBooks: return "books.vertical"
        case .library: return "bookmark"
        }
    }
}

// MARK: - Search Filter

struct SearchFilter: Codable {
    var genres: [String]?
    var authors: [String]?
    var difficultyRange: ClosedRange<Int>?
    var dateRange: DateRange?

    struct DateRange: Codable {
        let start: Date?
        let end: Date?
    }

    var isEmpty: Bool {
        genres == nil && authors == nil && difficultyRange == nil && dateRange == nil
    }
}

// MARK: - Recent Search

struct RecentSearch: Codable, Identifiable {
    let id: String
    let query: String
    let timestamp: Date

    init(query: String) {
        self.id = UUID().uuidString
        self.query = query
        self.timestamp = Date()
    }
}

// MARK: - Unified Search (API Response)

/// Author result from unified search
struct SearchAuthor: Codable, Identifiable {
    let id: String
    let name: String
    let nameZh: String?
    let avatarUrl: String?
    let era: String?
    let bookCount: Int
    let followerCount: Int
}

/// Book result from unified search
struct SearchBook: Codable, Identifiable {
    let id: String
    let title: String
    let titleZh: String?
    let author: String?
    let authorZh: String?
    let coverUrl: String?
    let difficultyScore: Double?

    // MARK: - Localized Accessors

    var localizedTitle: String {
        switch LocaleHelper.currentLanguage {
        case .chinese:
            if let zhTitle = titleZh, !zhTitle.isEmpty {
                return zhTitle
            }
            return title
        case .japanese, .korean, .english:
            return title
        }
    }

    var localizedAuthor: String {
        switch LocaleHelper.currentLanguage {
        case .chinese:
            if let zhAuthor = authorZh, !zhAuthor.isEmpty {
                return zhAuthor
            }
            return author ?? ""
        case .japanese, .korean, .english:
            return author ?? ""
        }
    }
}

/// Quote result from unified search
struct SearchQuote: Codable, Identifiable {
    let id: String
    let text: String
    let textZh: String?
    let source: String?
    let authorName: String
    let authorId: String?
}

/// Search result section with pagination info
struct SearchResultSection<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let hasMore: Bool
}

/// Unified search response from API
struct UnifiedSearchResponse: Codable {
    let query: String
    let authors: SearchResultSection<SearchAuthor>
    let books: SearchResultSection<SearchBook>
    let quotes: SearchResultSection<SearchQuote>

    var isEmpty: Bool {
        authors.items.isEmpty && books.items.isEmpty && quotes.items.isEmpty
    }
}

/// Search suggestion for autocomplete
struct SearchSuggestion: Codable, Identifiable {
    let text: String
    let type: SuggestionType
    let icon: String

    var id: String { "\(type.rawValue)-\(text)" }

    enum SuggestionType: String, Codable {
        case author
        case book
        case popular
    }
}

/// Popular search term
struct PopularSearch: Codable, Identifiable {
    let term: String
    let count: Int

    var id: String { term }
}

// MARK: - SearchBook to Book Conversion

extension SearchBook {
    /// Convert SearchBook to Book for navigation to BookDetailView
    func toBook() -> Book {
        Book(
            id: id,
            title: title,
            author: author ?? "",
            authorId: nil,
            description: nil,
            coverUrl: coverUrl,
            coverThumbUrl: nil,
            subjects: nil,
            genres: [],
            difficultyScore: difficultyScore,
            fleschScore: nil,
            wordCount: nil,
            chapterCount: nil,
            source: nil,
            status: "ACTIVE",
            publishedAt: nil,
            createdAt: nil,
            hasAudiobook: nil,
            audiobookId: nil,
            stylesUrl: nil
        )
    }
}
