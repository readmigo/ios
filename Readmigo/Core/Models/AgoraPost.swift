import Foundation

// MARK: - Post Type

enum PostType: String, Codable {
    case author = "AUTHOR"
    case user = "USER"
}

// MARK: - Post User (用于用户发布的帖子)

struct PostUser: Codable {
    let id: String
    let name: String
    let avatarUrl: String?
}

// MARK: - Post Media (媒体附件)

struct PostMedia: Codable, Identifiable {
    let id: String
    let type: MediaType
    let url: String
    let thumbnailUrl: String?
    let width: Int?
    let height: Int?
    let duration: Int? // 秒

    enum MediaType: String, Codable {
        case image = "IMAGE"
        case video = "VIDEO"
        case audio = "AUDIO"
    }
}

// MARK: - AgoraPost

struct AgoraPost: Codable, Identifiable {
    let id: String
    let postType: PostType

    // 作者帖子字段（历史人物）- 可选
    let author: Author?
    let quote: Quote?

    // 用户帖子字段 - 可选
    let user: PostUser?
    let content: String?
    let media: [PostMedia]?

    // 通用字段
    let simulatedPostTime: Date
    var likeCount: Int
    var commentCount: Int
    var shareCount: Int
    var isLiked: Bool
    var isBookmarked: Bool
    var hasUserComment: Bool
    var comments: [Comment]?

    // MARK: - Computed Properties

    /// 是否为作者帖子
    var isAuthorPost: Bool {
        postType == .author
    }

    /// 是否为用户帖子
    var isUserPost: Bool {
        postType == .user
    }

    /// 显示名称
    var displayName: String {
        if isAuthorPost {
            return author?.name ?? "Unknown"
        } else {
            return user?.name ?? "Anonymous"
        }
    }

    /// 显示头像URL
    var displayAvatarUrl: String? {
        if isAuthorPost {
            return author?.avatarUrl
        } else {
            return user?.avatarUrl
        }
    }

    var relativeTimeString: String {
        simulatedPostTime.relativeTimeString
    }

    var sourceString: String {
        guard let quote = quote else { return "" }

        // Only show bookTitle if available and not "Various Works" placeholder
        if let bookTitle = quote.bookTitle,
           !bookTitle.isEmpty,
           bookTitle.lowercased() != "various works" {
            return "《\(bookTitle)》"
        }

        return ""
    }

    var locationString: String? {
        if let nationality = author?.nationality {
            return "来自\(nationality)"
        }
        return nil
    }

    /// Get preview comments (first 3)
    var previewComments: [Comment] {
        Array((comments ?? []).prefix(3))
    }

    var hasMoreComments: Bool {
        commentCount > 3
    }

    // MARK: - Memberwise Initializer

    init(
        id: String,
        postType: PostType,
        author: Author?,
        quote: Quote?,
        user: PostUser?,
        content: String?,
        media: [PostMedia]?,
        simulatedPostTime: Date,
        likeCount: Int,
        commentCount: Int,
        shareCount: Int,
        isLiked: Bool,
        isBookmarked: Bool,
        hasUserComment: Bool,
        comments: [Comment]?
    ) {
        self.id = id
        self.postType = postType
        self.author = author
        self.quote = quote
        self.user = user
        self.content = content
        self.media = media
        self.simulatedPostTime = simulatedPostTime
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.shareCount = shareCount
        self.isLiked = isLiked
        self.isBookmarked = isBookmarked
        self.hasUserComment = hasUserComment
        self.comments = comments
    }

    // MARK: - CodingKeys with default value for postType

    enum CodingKeys: String, CodingKey {
        case id, postType, author, quote, user, content, media
        case simulatedPostTime, likeCount, commentCount, shareCount
        case isLiked, isBookmarked, hasUserComment, comments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        // 默认值为 .author 以兼容旧数据
        postType = try container.decodeIfPresent(PostType.self, forKey: .postType) ?? .author
        author = try container.decodeIfPresent(Author.self, forKey: .author)
        quote = try container.decodeIfPresent(Quote.self, forKey: .quote)
        user = try container.decodeIfPresent(PostUser.self, forKey: .user)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        media = try container.decodeIfPresent([PostMedia].self, forKey: .media)
        simulatedPostTime = try container.decode(Date.self, forKey: .simulatedPostTime)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
        shareCount = try container.decode(Int.self, forKey: .shareCount)
        isLiked = try container.decode(Bool.self, forKey: .isLiked)
        isBookmarked = try container.decode(Bool.self, forKey: .isBookmarked)
        hasUserComment = try container.decodeIfPresent(Bool.self, forKey: .hasUserComment) ?? false
        comments = try container.decodeIfPresent([Comment].self, forKey: .comments)
    }
}

// MARK: - Like Response

struct AgoraLikeResponse: Codable {
    let success: Bool
    let likeCount: Int
    let isLiked: Bool
}

// MARK: - Share Response

struct AgoraShareResponse: Codable {
    let success: Bool
    let shareCount: Int
}

// MARK: - Block Types

enum BlockType: String, Codable {
    case post = "POST"
    case author = "AUTHOR"
}

struct BlockedItem: Codable, Identifiable {
    let id: String
    let type: BlockType
    let targetId: String
    let reason: String?
    let createdAt: Date
}


