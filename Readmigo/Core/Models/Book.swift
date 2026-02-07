import Foundation

// MARK: - Locale Helper

/// Supported languages for localization
enum SupportedLanguage: String {
    case english = "en"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
}

/// Helper for detecting system language
enum LocaleHelper {
    /// Current system language code (uses LocalizationManager for app language)
    static var currentLanguageCode: String? {
        // First check app's language setting from LocalizationManager
        // Fall back to system locale if not on main actor
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                LocalizationManager.shared.currentLanguage.rawValue
            }
        }
        return Locale.current.language.languageCode?.identifier
    }

    /// Current supported language based on app/system locale
    static var currentLanguage: SupportedLanguage {
        // Use LocalizationManager if on main thread
        if Thread.isMainThread {
            let isChinese = MainActor.assumeIsolated {
                LocalizationManager.shared.isChinese
            }
            if isChinese { return .chinese }
            return .english
        }

        // Fallback to system locale
        guard let code = Locale.current.language.languageCode?.identifier else { return .english }
        switch code {
        case "zh": return .chinese
        case "ja": return .japanese
        case "ko": return .korean
        default: return .english
        }
    }

    /// Check if current language is Chinese (uses LocalizationManager)
    static var isChineseLocale: Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                LocalizationManager.shared.isChinese
            }
        }
        return Locale.current.language.languageCode?.identifier == "zh"
    }

    /// Check if current system language is Japanese
    static var isJapaneseLocale: Bool {
        currentLanguage == .japanese
    }

    /// Check if current system language is Korean
    static var isKoreanLocale: Bool {
        currentLanguage == .korean
    }

    /// Check if current system language requires localized content (non-English)
    static var requiresLocalization: Bool {
        currentLanguage != .english
    }
}


// MARK: - Book Model

struct Book: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let author: String
    let authorId: String?
    let description: String?
    let coverUrl: String?
    let coverThumbUrl: String?
    let subjects: [String]?
    let genres: [String]?
    let difficultyScore: Double?
    let fleschScore: Double?
    let wordCount: Int?
    let chapterCount: Int?
    let source: String?
    let status: String?
    let publishedAt: Date?
    let createdAt: Date?
    let hasAudiobook: Bool?
    let audiobookId: String?
    let stylesUrl: String?  // SE native CSS URL
    let doubanRating: Double?
    let goodreadsRating: Double?

    // MARK: - Computed Properties

    // Computed property for backward compatibility
    var isActive: Bool {
        status == "ACTIVE"
    }

    // Use thumbnail for display, fallback to full cover
    var displayCoverUrl: String? {
        coverThumbUrl ?? coverUrl
    }

    var difficultyLevel: String {
        guard let score = difficultyScore else { return "Unknown" }
        switch score {
        case 0..<30: return "Easy"
        case 30..<50: return "Medium"
        case 50..<70: return "Challenging"
        default: return "Advanced"
        }
    }

    // Int accessor for compatibility
    var difficultyScoreInt: Int? {
        guard let score = difficultyScore else { return nil }
        return Int(score)
    }

    var formattedWordCount: String? {
        guard let wordCount = wordCount else { return nil }
        if wordCount >= 1000 {
            return "\(wordCount / 1000)k words"
        }
        return "\(wordCount) words"
    }

    // MARK: - Localized Accessors
    // Note: The server now returns pre-localized data based on Accept-Language header.
    // These computed properties are kept for backward compatibility but now simply return
    // the main fields which are already localized by the server.

    /// Returns title - now pre-localized by server based on Accept-Language header
    var localizedTitle: String {
        title
    }

    /// Returns author - now pre-localized by server based on Accept-Language header
    var localizedAuthor: String {
        author
    }

    /// Returns description - now pre-localized by server based on Accept-Language header
    var localizedDescription: String? {
        description
    }

    /// Returns genre names - server handles localization based on Accept-Language header
    var localizedGenres: [String] {
        genres ?? []
    }

    /// Returns the first genre - server handles localization
    var localizedFirstGenre: String? {
        genres?.first
    }

    /// Display rating based on locale: Douban for Chinese, Goodreads for English
    var displayRating: Double? {
        if LocaleHelper.isChineseLocale {
            return doubanRating
        }
        return goodreadsRating
    }

    /// Formatted rating string with source label
    var formattedRating: String? {
        if LocaleHelper.isChineseLocale {
            guard let rating = doubanRating else { return nil }
            return String(format: "%.1f", rating)
        } else {
            guard let rating = goodreadsRating else { return nil }
            return String(format: "%.2f", rating)
        }
    }

    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Book Detail

/// BookDetail represents the full book details returned from the API.
/// The API returns a flat structure (all Book fields at the root level with chapters),
/// so we use custom decoding to construct the nested `book` property.
struct BookDetail: Codable, Identifiable {
    let book: Book
    let chapters: [Chapter]
    let userProgress: UserProgress?

    var id: String { book.id }

    enum CodingKeys: String, CodingKey {
        case chapters
        case userProgress
        // Book fields (flat structure from API)
        case id, title, author, authorId, description, coverUrl, coverThumbUrl
        case subjects, genres, difficultyScore, fleschScore
        case wordCount, chapterCount, source, status, publishedAt, createdAt
        case hasAudiobook, audiobookId, stylesUrl
        case doubanRating, goodreadsRating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode chapters
        self.chapters = try container.decode([Chapter].self, forKey: .chapters)

        // userProgress is optional and may not be present
        self.userProgress = try container.decodeIfPresent(UserProgress.self, forKey: .userProgress)

        // Decode Book from flat structure
        self.book = Book(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            author: try container.decode(String.self, forKey: .author),
            authorId: try container.decodeIfPresent(String.self, forKey: .authorId),
            description: try container.decodeIfPresent(String.self, forKey: .description),
            coverUrl: try container.decodeIfPresent(String.self, forKey: .coverUrl),
            coverThumbUrl: try container.decodeIfPresent(String.self, forKey: .coverThumbUrl),
            subjects: try container.decodeIfPresent([String].self, forKey: .subjects),
            genres: try container.decodeIfPresent([String].self, forKey: .genres) ?? [],
            difficultyScore: try container.decodeIfPresent(Double.self, forKey: .difficultyScore),
            fleschScore: try container.decodeIfPresent(Double.self, forKey: .fleschScore),
            wordCount: try container.decodeIfPresent(Int.self, forKey: .wordCount),
            chapterCount: try container.decodeIfPresent(Int.self, forKey: .chapterCount),
            source: try container.decodeIfPresent(String.self, forKey: .source),
            status: try container.decodeIfPresent(String.self, forKey: .status),
            publishedAt: try container.decodeIfPresent(Date.self, forKey: .publishedAt),
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt),
            hasAudiobook: try container.decodeIfPresent(Bool.self, forKey: .hasAudiobook),
            audiobookId: try container.decodeIfPresent(String.self, forKey: .audiobookId),
            stylesUrl: try container.decodeIfPresent(String.self, forKey: .stylesUrl),
            doubanRating: try container.decodeIfPresent(Double.self, forKey: .doubanRating),
            goodreadsRating: try container.decodeIfPresent(Double.self, forKey: .goodreadsRating)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode chapters and userProgress
        try container.encode(chapters, forKey: .chapters)
        try container.encodeIfPresent(userProgress, forKey: .userProgress)

        // Encode Book fields as flat structure
        try container.encode(book.id, forKey: .id)
        try container.encode(book.title, forKey: .title)
        try container.encode(book.author, forKey: .author)
        try container.encodeIfPresent(book.authorId, forKey: .authorId)
        try container.encodeIfPresent(book.description, forKey: .description)
        try container.encodeIfPresent(book.coverUrl, forKey: .coverUrl)
        try container.encodeIfPresent(book.coverThumbUrl, forKey: .coverThumbUrl)
        try container.encodeIfPresent(book.subjects, forKey: .subjects)
        try container.encode(book.genres, forKey: .genres)
        try container.encodeIfPresent(book.difficultyScore, forKey: .difficultyScore)
        try container.encodeIfPresent(book.fleschScore, forKey: .fleschScore)
        try container.encodeIfPresent(book.wordCount, forKey: .wordCount)
        try container.encodeIfPresent(book.chapterCount, forKey: .chapterCount)
        try container.encodeIfPresent(book.source, forKey: .source)
        try container.encodeIfPresent(book.status, forKey: .status)
        try container.encodeIfPresent(book.publishedAt, forKey: .publishedAt)
        try container.encodeIfPresent(book.createdAt, forKey: .createdAt)
        try container.encodeIfPresent(book.hasAudiobook, forKey: .hasAudiobook)
        try container.encodeIfPresent(book.audiobookId, forKey: .audiobookId)
        try container.encodeIfPresent(book.stylesUrl, forKey: .stylesUrl)
        try container.encodeIfPresent(book.doubanRating, forKey: .doubanRating)
        try container.encodeIfPresent(book.goodreadsRating, forKey: .goodreadsRating)
    }

    // Convenience initializer for direct construction
    init(book: Book, chapters: [Chapter], userProgress: UserProgress? = nil) {
        self.book = book
        self.chapters = chapters
        self.userProgress = userProgress
    }
}

// MARK: - Chapter

struct Chapter: Codable, Identifiable {
    let id: String
    let title: String
    let order: Int
    let wordCount: Int?
}

// MARK: - Chapter Content (API Response - metadata only)

struct ChapterContentMeta: Codable, Identifiable {
    let id: String
    let title: String
    let order: Int
    let contentUrl: String? // Optional: URL to fetch content from R2
    let htmlContent: String? // Optional: Direct HTML content (local/dev mode)
    let wordCount: Int
    let previousChapterId: String?
    let nextChapterId: String?
}

// MARK: - Chapter Content (with fetched HTML, for caching and display)

struct ChapterContent: Codable, Identifiable {
    let id: String
    let title: String
    let order: Int
    let htmlContent: String
    let wordCount: Int
    let previousChapterId: String?
    let nextChapterId: String?

    init(meta: ChapterContentMeta, htmlContent: String) {
        self.id = meta.id
        self.title = meta.title
        self.order = meta.order
        self.htmlContent = htmlContent
        self.wordCount = meta.wordCount
        self.previousChapterId = meta.previousChapterId
        self.nextChapterId = meta.nextChapterId
    }
}

// MARK: - User Progress

struct UserProgress: Codable {
    let currentChapterId: String?
    let currentChapterIndex: Int
    let chapterProgress: Double
    let overallProgress: Double
}

// MARK: - User Book (for Library)

struct UserBook: Codable, Identifiable {
    let id: String
    let book: Book
    let status: BookStatus
    let progress: Double?
    let currentChapterIndex: Int?
    let addedAt: Date
    let lastReadAt: Date?

    // Computed properties for safe access
    var safeProgress: Double {
        progress ?? 0
    }

    var safeCurrentChapterIndex: Int {
        currentChapterIndex ?? 0
    }
}

// MARK: - Book Status

enum BookStatus: String, Codable, CaseIterable {
    case wantToRead = "WANT_TO_READ"
    case reading = "READING"
    case finished = "FINISHED"

    var displayName: String {
        switch self {
        case .wantToRead: return "bookStatus.wantToRead".localized
        case .reading: return "bookStatus.reading".localized
        case .finished: return "bookStatus.finished".localized
        }
    }

    var icon: String {
        switch self {
        case .wantToRead: return "bookmark"
        case .reading: return "book"
        case .finished: return "checkmark.circle"
        }
    }
}

// MARK: - Favorite Book

/// Book info for favorites
struct FavoriteBookInfo: Codable {
    let id: String
    let title: String
    let author: String
    let coverUrl: String?
    let coverThumbUrl: String?
    let difficultyScore: Double?

    var displayCoverUrl: String? {
        coverThumbUrl ?? coverUrl
    }

    /// Returns title - should be pre-localized by server based on Accept-Language header
    var localizedTitle: String {
        title
    }

    /// Returns author - should be pre-localized by server based on Accept-Language header
    var localizedAuthor: String {
        author
    }
}

/// User's favorite book
struct FavoriteBook: Codable, Identifiable {
    let id: String
    let bookId: String
    let book: FavoriteBookInfo
    let createdAt: Date
}

/// Response for favorites list
struct FavoritesResponse: Codable {
    let items: [FavoriteBook]
    let total: Int
    let hasMore: Bool
}

// MARK: - Book Context (Creation Background, Historical Context, Themes)

/// Data source for book context information
enum BookContextSource: String, Codable {
    case wikipedia = "WIKIPEDIA"
    case standardEbooks = "STANDARD_EBOOKS"
    case openLibrary = "OPEN_LIBRARY"
    case wikidata = "WIKIDATA"
    case manual = "MANUAL"
}

/// Book context containing creation background, historical context, and themes
struct BookContext: Codable, Identifiable {
    let id: String
    let bookId: String
    let sourceType: BookContextSource
    let sourceUrl: String?
    let sourceId: String?
    let summary: String?
    let creationBackground: String?
    let historicalContext: String?
    let themes: String?
    let literaryStyle: String?
    let license: String
    let fetchedAt: Date
    let locale: String?
    let availableTranslations: [String]?

    /// Check if context has any meaningful content
    var hasContent: Bool {
        creationBackground != nil || historicalContext != nil || themes != nil || literaryStyle != nil
    }

    /// Get the primary content for display (first non-nil content)
    var primaryContent: String? {
        creationBackground ?? historicalContext ?? themes ?? literaryStyle
    }
}

// MARK: - Reading Guide (阅读指南)

/// Reading guide with AI-generated content for cross-cultural readers
struct ReadingGuide: Codable, Identifiable {
    let id: String
    let bookId: String
    let sourceType: String // AI_GENERATED, MANUAL
    let aiModel: String?
    let generatedAt: Date
    let readingWarnings: String?   // 阅读注意事项 (跨文化难点)
    let storyTimeline: String?     // 故事线/剧情梗概
    let quickStartGuide: String?   // 快速进入阅读状态
    let locale: String?
    let availableTranslations: [String]?

    /// Check if guide has any meaningful content
    var hasContent: Bool {
        readingWarnings != nil || storyTimeline != nil || quickStartGuide != nil
    }
}

// MARK: - Difficulty Badge View

import SwiftUI

struct DifficultyBadge: View {
    let score: Double?

    private var level: String {
        guard let score = score else { return "difficulty.unknown".localized }
        switch score {
        case 0..<30: return "difficulty.easy".localized
        case 30..<50: return "difficulty.medium".localized
        case 50..<70: return "difficulty.challenging".localized
        default: return "difficulty.advanced".localized
        }
    }

    private var color: Color {
        guard let score = score else { return .gray }
        switch score {
        case 0..<30: return .green
        case 30..<50: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }

    var body: some View {
        Text(level)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }
}

