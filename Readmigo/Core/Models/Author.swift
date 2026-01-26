import Foundation

// MARK: - Author

struct Author: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let avatarUrl: String?
    let bio: String?
    let era: String?
    let nationality: String?
    let bookCount: Int
    let quoteCount: Int?
    let followerCount: Int?
    var isFollowed: Bool?

    // MARK: - Computed Properties

    /// Get author's initials for avatar placeholder
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.last?.prefix(1) ?? ""
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    /// Generate a consistent color based on author name
    var avatarColorIndex: Int {
        var hash = 0
        for char in name.unicodeScalars {
            hash = Int(char.value) &+ (hash << 5) &- hash
        }
        return abs(hash) % 8
    }

    // MARK: - Localized Accessors
    // Note: The server now returns pre-localized data based on Accept-Language header.
    // This computed property is kept for backward compatibility but now simply returns
    // the main field which is already localized by the server.

    /// Returns name - now pre-localized by server based on Accept-Language header
    var localizedName: String {
        name
    }
}

// MARK: - Author Response

struct AuthorsResponse: Codable {
    let data: [Author]
    let total: Int
    let page: Int?
    let limit: Int?
    let totalPages: Int?
}

// MARK: - Author Detail

struct AuthorDetail: Codable, Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
    let bio: String?
    let era: String?
    let nationality: String?
    let birthPlace: String?
    let writingStyle: String?
    let literaryPeriod: String?
    let famousWorks: [String]
    let wikipediaUrl: String?
    let bookCount: Int
    let quoteCount: Int
    let followerCount: Int
    var isFollowed: Bool
    let timelineEvents: [AuthorTimelineEvent]
    let quotes: [AuthorQuote]
    let books: [BookSummary]
    let writingStyles: [WritingStyle]
    let civilizationMap: CivilizationMap?

    // MARK: - Custom Decoder (for API compatibility)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        era = try container.decodeIfPresent(String.self, forKey: .era)
        nationality = try container.decodeIfPresent(String.self, forKey: .nationality)
        birthPlace = try container.decodeIfPresent(String.self, forKey: .birthPlace)
        writingStyle = try container.decodeIfPresent(String.self, forKey: .writingStyle)
        literaryPeriod = try container.decodeIfPresent(String.self, forKey: .literaryPeriod)
        famousWorks = try container.decodeIfPresent([String].self, forKey: .famousWorks) ?? []
        wikipediaUrl = try container.decodeIfPresent(String.self, forKey: .wikipediaUrl)
        bookCount = try container.decodeIfPresent(Int.self, forKey: .bookCount) ?? 0
        quoteCount = try container.decodeIfPresent(Int.self, forKey: .quoteCount) ?? 0
        followerCount = try container.decodeIfPresent(Int.self, forKey: .followerCount) ?? 0
        isFollowed = try container.decodeIfPresent(Bool.self, forKey: .isFollowed) ?? false
        timelineEvents = try container.decodeIfPresent([AuthorTimelineEvent].self, forKey: .timelineEvents) ?? []
        quotes = try container.decodeIfPresent([AuthorQuote].self, forKey: .quotes) ?? []
        books = try container.decodeIfPresent([BookSummary].self, forKey: .books) ?? []
        writingStyles = try container.decodeIfPresent([WritingStyle].self, forKey: .writingStyles) ?? []
        civilizationMap = try container.decodeIfPresent(CivilizationMap.self, forKey: .civilizationMap)
    }

    // MARK: - Manual Init

    init(
        id: String,
        name: String,
        avatarUrl: String?,
        bio: String?,
        era: String?,
        nationality: String?,
        birthPlace: String?,
        writingStyle: String?,
        literaryPeriod: String?,
        famousWorks: [String],
        wikipediaUrl: String?,
        bookCount: Int,
        quoteCount: Int,
        followerCount: Int,
        isFollowed: Bool,
        timelineEvents: [AuthorTimelineEvent],
        quotes: [AuthorQuote],
        books: [BookSummary],
        writingStyles: [WritingStyle] = [],
        civilizationMap: CivilizationMap? = nil
    ) {
        self.id = id
        self.name = name
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.era = era
        self.nationality = nationality
        self.birthPlace = birthPlace
        self.writingStyle = writingStyle
        self.literaryPeriod = literaryPeriod
        self.famousWorks = famousWorks
        self.wikipediaUrl = wikipediaUrl
        self.bookCount = bookCount
        self.quoteCount = quoteCount
        self.followerCount = followerCount
        self.isFollowed = isFollowed
        self.timelineEvents = timelineEvents
        self.quotes = quotes
        self.books = books
        self.writingStyles = writingStyles
        self.civilizationMap = civilizationMap
    }

    // MARK: - Computed Properties

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.last?.prefix(1) ?? ""
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var avatarColorIndex: Int {
        var hash = 0
        for char in name.unicodeScalars {
            hash = Int(char.value) &+ (hash << 5) &- hash
        }
        return abs(hash) % 8
    }

    // MARK: - Localized Accessors
    // Note: The server now returns pre-localized data based on Accept-Language header.
    // These computed properties are kept for backward compatibility but now simply return
    // the main fields which are already localized by the server.

    /// Returns name - now pre-localized by server based on Accept-Language header
    var localizedName: String {
        name
    }

    /// Returns bio - now pre-localized by server based on Accept-Language header
    var localizedBio: String? {
        bio
    }

    /// Convert to basic Author
    var asAuthor: Author {
        Author(
            id: id,
            name: name,
            avatarUrl: avatarUrl,
            bio: bio,
            era: era,
            nationality: nationality,
            bookCount: bookCount,
            quoteCount: quoteCount,
            followerCount: followerCount,
            isFollowed: isFollowed
        )
    }
}

// MARK: - Author Timeline Event

struct AuthorTimelineEvent: Codable, Identifiable {
    let id: String
    let year: Int
    let title: String
    let description: String?
    let category: TimelineCategory

    // MARK: - Localized Accessors

    /// Returns title - now pre-localized by server based on Accept-Language header
    var localizedTitle: String {
        title
    }

    /// Returns description - now pre-localized by server based on Accept-Language header
    var localizedDescription: String? {
        description
    }

    enum TimelineCategory: String, Codable {
        case birth = "BIRTH"
        case education = "EDUCATION"
        case work = "WORK"
        case majorEvent = "MAJOR_EVENT"
        case award = "AWARD"
        case death = "DEATH"

        var icon: String {
            switch self {
            case .birth: return "star.fill"
            case .education: return "book.fill"
            case .work: return "doc.text.fill"
            case .majorEvent: return "flag.fill"
            case .award: return "trophy.fill"
            case .death: return "heart.fill"
            }
        }

        var color: String {
            switch self {
            case .birth: return "yellow"
            case .education: return "blue"
            case .work: return "green"
            case .majorEvent: return "purple"
            case .award: return "orange"
            case .death: return "gray"
            }
        }
    }
}

// MARK: - Author Quote

struct AuthorQuote: Codable, Identifiable {
    let id: String
    let text: String
    let source: String?
    let likeCount: Int

    // MARK: - Localized Accessors

    /// Returns text - now pre-localized by server based on Accept-Language header
    var localizedText: String {
        text
    }

    /// Returns source - now pre-localized by server based on Accept-Language header
    var localizedSource: String? {
        source
    }
}

// MARK: - Writing Style

struct WritingStyle: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String  // SF Symbol name or emoji

    // MARK: - Localized Accessors

    /// Returns title - now pre-localized by server based on Accept-Language header
    var localizedTitle: String {
        title
    }

    /// Returns description - now pre-localized by server based on Accept-Language header
    var localizedDescription: String {
        description
    }
}

// MARK: - Book Summary

struct BookSummary: Codable, Identifiable {
    let id: String
    let title: String
    let coverUrl: String?
    let difficultyScore: Double?

    // MARK: - Localized Accessors

    /// Returns title - now pre-localized by server based on Accept-Language header
    var localizedTitle: String {
        title
    }
}

// MARK: - Civilization Map

/// 文明地图主结构 - 展示作者在文学史中的位置
struct CivilizationMap: Codable {
    // 文学坐标
    let literaryMovement: String?       // 文学流派
    let historicalPeriod: String?       // 历史时期
    let primaryGenres: [String]?        // 主要体裁
    let themes: [String]?               // 核心主题

    // 影响网络
    let influences: InfluenceNetwork

    // 跨领域贡献
    let domains: [DomainPosition]?

    // 历史背景
    let historicalContext: [CivilizationHistoricalEvent]?
}

/// 影响网络
struct InfluenceNetwork: Codable {
    let predecessors: [AuthorLink]      // 前驱作家（深受影响）
    let successors: [AuthorLink]        // 后继作家（影响后人）
    let contemporaries: [AuthorLink]    // 同时代作家
    let mentors: [AuthorLink]?          // 导师
    let students: [AuthorLink]?         // 学生
}

/// 作家链接（简化的作者信息）
struct AuthorLink: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let avatarUrl: String?
    let era: String?
    let nationality: String?
    let relationship: String?           // 关系描述

    // MARK: - Computed Properties

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.last?.prefix(1) ?? ""
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var avatarColorIndex: Int {
        var hash = 0
        for char in name.unicodeScalars {
            hash = Int(char.value) &+ (hash << 5) &- hash
        }
        return abs(hash) % 8
    }

    /// Returns name - now pre-localized by server based on Accept-Language header
    var localizedName: String {
        name
    }
}

/// 跨领域贡献
struct DomainPosition: Codable, Identifiable {
    var id: String { domain }
    let domain: String                  // 领域：文学、哲学、政治、科学等
    let significance: DomainSignificance
    let contributions: [String]         // 具体贡献列表

    /// Returns domain - now pre-localized by server based on Accept-Language header
    var localizedDomain: String {
        domain
    }

    /// Returns contributions - now pre-localized by server based on Accept-Language header
    var localizedContributions: [String] {
        contributions
    }
}

enum DomainSignificance: String, Codable {
    case major                          // 重大
    case moderate                       // 显著
    case minor                          // 一般

    var displayName: String {
        switch self {
        case .major: return "civilizationMap.significance.major".localized
        case .moderate: return "civilizationMap.significance.moderate".localized
        case .minor: return "civilizationMap.significance.minor".localized
        }
    }
}

/// 历史事件（文明地图专用，避免与 AuthorTimelineEvent 冲突）
struct CivilizationHistoricalEvent: Codable, Identifiable {
    var id: String { "\(year)-\(title)" }
    let year: Int
    let title: String
    let category: HistoricalEventCategory

    /// Returns title - now pre-localized by server based on Accept-Language header
    var localizedTitle: String {
        title
    }
}

enum HistoricalEventCategory: String, Codable {
    case war                            // 战争
    case revolution                     // 革命
    case cultural                       // 文化
    case political                      // 政治
    case scientific                     // 科学

    var displayName: String {
        switch self {
        case .war: return "civilizationMap.eventCategory.war".localized
        case .revolution: return "civilizationMap.eventCategory.revolution".localized
        case .cultural: return "civilizationMap.eventCategory.cultural".localized
        case .political: return "civilizationMap.eventCategory.political".localized
        case .scientific: return "civilizationMap.eventCategory.scientific".localized
        }
    }

    var icon: String {
        switch self {
        case .war: return "flame.fill"
        case .revolution: return "flag.fill"
        case .cultural: return "theatermasks.fill"
        case .political: return "building.columns.fill"
        case .scientific: return "atom"
        }
    }
}


