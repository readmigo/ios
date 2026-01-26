import Foundation

// MARK: - Book List Type

enum BookListType: String, Codable {
    case editorsPick = "EDITORS_PICK"
    case annualBest = "ANNUAL_BEST"
    case university = "UNIVERSITY"
    case celebrity = "CELEBRITY"
    case ranking = "RANKING"
    case collection = "COLLECTION"
    case aiRecommended = "AI_RECOMMENDED"
    case personalized = "PERSONALIZED"
    case aiFeatured = "AI_FEATURED"

    var displayName: String {
        switch self {
        case .editorsPick: return "Editor's Pick"
        case .annualBest: return "Best of the Year"
        case .university: return "University Reads"
        case .celebrity: return "Celebrity Picks"
        case .ranking: return "Top Ranked"
        case .collection: return "Collection"
        case .aiRecommended: return "AI Recommended"
        case .personalized: return "For You"
        case .aiFeatured: return "AI Featured"
        }
    }

    var icon: String {
        switch self {
        case .editorsPick: return "star.fill"
        case .annualBest: return "trophy.fill"
        case .university: return "graduationcap.fill"
        case .celebrity: return "person.fill.viewfinder"
        case .ranking: return "chart.bar.fill"
        case .collection: return "books.vertical.fill"
        case .aiRecommended: return "sparkles"
        case .personalized: return "heart.fill"
        case .aiFeatured: return "wand.and.stars"
        }
    }
}

// MARK: - Book List Display Style

enum BookListDisplayStyle: String, Codable {
    case featuredBanner = "FEATURED_BANNER"
    case heroCarousel = "HERO_CAROUSEL"
    case standardCarousel = "STANDARD_CAROUSEL"
    case rankedCarousel = "RANKED_CAROUSEL"
    case compactGrid = "COMPACT_GRID"
    case universityGrid = "UNIVERSITY_GRID"
    case listRow = "LIST_ROW"

    // Legacy support
    case grid = "grid"
    case list = "list"
    case carousel = "carousel"
    case featured = "featured"

    /// Map legacy styles to new styles
    var normalized: BookListDisplayStyle {
        switch self {
        case .grid: return .compactGrid
        case .list: return .listRow
        case .carousel: return .standardCarousel
        case .featured: return .heroCarousel
        default: return self
        }
    }
}

// MARK: - Book Cover Dimensions

struct BookCoverDimensions {
    let width: CGFloat
    let height: CGFloat

    static let featuredBanner = BookCoverDimensions(width: 100, height: 150)
    static let heroCarousel = BookCoverDimensions(width: 140, height: 210)
    static let standardCarousel = BookCoverDimensions(width: 100, height: 150)
    static let rankedCarousel = BookCoverDimensions(width: 90, height: 135)
    static let compactGrid = BookCoverDimensions(width: 109, height: 164)
    static let universityGrid = BookCoverDimensions(width: 170, height: 255)
    static let listRow = BookCoverDimensions(width: 60, height: 90)

    var aspectRatio: CGFloat { width / height }
}

// MARK: - Book List

struct BookList: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let description: String?
    let coverUrl: String?
    let type: BookListType
    let displayStyle: BookListDisplayStyle?
    let bookCount: Int
    let sortOrder: Int?
    let isActive: Bool?
    let books: [Book]?
    let createdAt: Date?
    let updatedAt: Date?
}

// MARK: - Category

struct Category: Codable, Identifiable {
    let id: String
    let name: String
    let nameEn: String?
    let slug: String
    let description: String?
    let iconUrl: String?
    let coverUrl: String?
    let parentId: String?
    let level: Int
    let children: [Category]?
    let bookCount: Int
    let sortOrder: Int?
    let isActive: Bool?

    /// Display name - prefers English name if available
    var displayName: String {
        nameEn ?? name
    }

    /// System icon name based on the category iconUrl (which stores icon identifiers)
    var systemIconName: String {
        switch iconUrl {
        case "book-open": return "book.fill"
        case "lightbulb": return "lightbulb.fill"
        case "clock": return "clock.fill"
        case "beaker": return "flask.fill"
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "chart-line": return "chart.line.uptrend.xyaxis"
        case "users": return "person.3.fill"
        case "palette": return "paintpalette.fill"
        case "sun": return "sun.max.fill"
        case "star": return "star.fill"
        case "globe": return "globe"
        case "heart": return "heart.fill"
        default: return "folder.fill"
        }
    }
}

// MARK: - Response Models

struct BookListsResponse: Codable {
    let items: [BookList]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int

    // Convenience accessor
    var data: [BookList] { items }
}

struct BookListResponse: Codable {
    let bookList: BookList
}

struct BookListTypesResponse: Codable {
    let types: [String]
}

struct CategoriesResponse: Codable {
    let categories: [Category]
}

struct CategoryBooksResponse: Codable {
    let books: [Book]
    let total: Int
    let page: Int
    let limit: Int
}
