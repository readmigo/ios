import Foundation
import SwiftUI

// MARK: - API Response Types

struct AgoraPostsResponse: Codable {
    let data: [AgoraPostAPIResponse]
    let total: Int
    let page: Int
    let limit: Int
    let hasMore: Bool
}

struct AgoraPostAPIResponse: Codable {
    let id: String
    let postType: String?  // "AUTHOR" | "USER"
    // Author post fields
    let author: AuthorAPIResponse?
    let quote: QuoteAPIResponse?
    // User post fields
    let user: UserAPIResponse?
    let content: String?
    let media: [MediaAPIResponse]?
    // Common fields
    let simulatedPostTime: Date
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let isLiked: Bool
    let isBookmarked: Bool
    let comments: [CommentAPIResponse]
}

struct UserAPIResponse: Codable {
    let id: String
    let name: String
    let avatarUrl: String?
}

struct MediaAPIResponse: Codable {
    let id: String
    let type: String  // "IMAGE" | "VIDEO" | "AUDIO"
    let url: String
    let thumbnailUrl: String?
    let width: Int?
    let height: Int?
    let duration: Int?
}

struct AuthorAPIResponse: Codable {
    let id: String
    let name: String
    let avatarUrl: String?
    let bio: String?
    let era: String?
    let nationality: String?
    let bookCount: Int
}

struct QuoteAPIResponse: Codable {
    let id: String
    let text: String
    let textEn: String?
    let source: String
    let bookId: String?
    let bookTitle: String?
    let author: String
    let chapter: String?
    let tags: [String]
}

struct CommentAPIResponse: Codable {
    let id: String
    let userId: String
    let userName: String
    let userAvatar: String?
    let content: String
    let replyToId: String?
    let replyToUserName: String?
    let likeCount: Int
    let isLiked: Bool
    let createdAt: Date
}

struct LikeResponse: Decodable {
    let success: Bool
    let likeCount: Int
    let isLiked: Bool?
}

struct CommentsPaginatedResponse: Decodable {
    let data: [CommentAPIResponse]
    let total: Int
    let page: Int
    let limit: Int
    let hasMore: Bool
}

struct ReportRequest: Encodable {
    let reason: String
}

struct BlockedItemsResponse: Decodable {
    let blockedAuthors: [AuthorAPIResponse]
    let hiddenPostCount: Int
}

// MARK: - AgoraManager

@MainActor
class AgoraManager: ObservableObject {
    static let shared = AgoraManager()

    // MARK: - Published Properties

    @Published var posts: [AgoraPost] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var hasMorePosts = true
    @Published var errorMessage: String?

    @Published var blockedAuthors: Set<String> = []
    @Published var blockedPosts: Set<String> = []
    @Published var hiddenPosts: Set<String> = []
    @Published var isCreatingPost = false
    @Published var createPostError: String?

    /// Data source indicator for offline support
    @Published var dataSource: DataSourceType = .network
    @Published var lastSyncTime: Date?

    enum DataSourceType {
        case network
        case cache
    }

    // MARK: - Private Properties

    private var currentPage = 1
    private let pageSize = 20
    private let cacheService = ResponseCacheService.shared

    /// Whether initial data has been loaded from cache
    @Published private(set) var hasLoadedFromCache = false

    // MARK: - Initialization

    private init() {
        LoggingService.shared.info(.agora, "AgoraManager initialized", component: "AgoraManager")
        loadBlockedItems()
        // Load from persistent cache on init
        Task {
            await loadFromCache()
        }
    }

    // MARK: - Cache First Loading

    /// Load data from persistent cache for instant startup
    private func loadFromCache() async {
        guard !hasLoadedFromCache else { return }

        LoggingService.shared.debug(.agora, "Loading agora posts from cache", component: "AgoraManager")

        let cacheKey = CacheKeys.agoraPostsKey(page: 1)

        if let cachedResponse: AgoraPostsResponse = await cacheService.get(cacheKey, type: AgoraPostsResponse.self) {
            let cachedPosts = cachedResponse.data.map { mapAPIResponseToPost($0) }
            self.posts = filterBlockedContent(cachedPosts)
            self.hasMorePosts = cachedResponse.hasMore
            self.currentPage = 2  // Next page to load
            self.dataSource = .cache

            if let cachedAt = await cacheService.getCachedResponse(cacheKey)?.timestamp {
                self.lastSyncTime = cachedAt
            }

            LoggingService.shared.info(.agora, "Loaded \(cachedPosts.count) posts from cache", component: "AgoraManager")
        } else {
            LoggingService.shared.debug(.agora, "No cached posts found", component: "AgoraManager")
        }

        hasLoadedFromCache = true
    }

    // MARK: - Posts Management

    func fetchPosts(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMorePosts = true
            LoggingService.shared.debug(.agora, "Refreshing posts feed", component: "AgoraManager")
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        LoggingService.shared.debug(.agora, "Fetching posts page=\(currentPage)", component: "AgoraManager")

        let cacheKey = CacheKeys.agoraPostsKey(page: currentPage)

        do {
            let endpoint = "\(APIEndpoints.agoraPosts)?page=\(currentPage)&limit=\(pageSize)"
            let response: AgoraPostsResponse = try await APIClient.shared.request(endpoint: endpoint)
            let newPosts = response.data.map { mapAPIResponseToPost($0) }

            if refresh {
                posts = filterBlockedContent(newPosts)
            } else {
                posts.append(contentsOf: filterBlockedContent(newPosts))
            }

            hasMorePosts = response.hasMore
            currentPage += 1

            // Cache the response
            await cacheService.set(response, for: cacheKey, ttl: .recommendations)
            dataSource = .network
            lastSyncTime = Date()

            LoggingService.shared.info(.agora, "Fetched \(newPosts.count) posts, total: \(posts.count), hasMore: \(hasMorePosts)", component: "AgoraManager")
        } catch {
            // Try to load from cache on network failure
            if let cachedResponse: AgoraPostsResponse = await cacheService.get(cacheKey, type: AgoraPostsResponse.self) {
                let cachedPosts = cachedResponse.data.map { mapAPIResponseToPost($0) }

                if refresh {
                    posts = filterBlockedContent(cachedPosts)
                } else {
                    posts.append(contentsOf: filterBlockedContent(cachedPosts))
                }

                hasMorePosts = cachedResponse.hasMore
                currentPage += 1

                // Get cache timestamp
                if let cachedAt = await cacheService.getCachedResponse(cacheKey)?.timestamp {
                    lastSyncTime = cachedAt
                }
                dataSource = .cache
                errorMessage = nil

                LoggingService.shared.info(.agora, "Loaded \(cachedPosts.count) posts from cache", component: "AgoraManager")
            } else {
                errorMessage = error.localizedDescription
                LoggingService.shared.error(.agora, "Failed to fetch posts: \(error.localizedDescription)", component: "AgoraManager")
            }
        }

        isLoading = false
    }

    func refreshPosts() async {
        LoggingService.shared.info(.agora, "Refreshing posts", component: "AgoraManager")
        isRefreshing = true
        await fetchPosts(refresh: true)
        isRefreshing = false
    }

    func loadMorePosts() async {
        guard hasMorePosts && !isLoading else { return }
        LoggingService.shared.debug(.agora, "Loading more posts", component: "AgoraManager")
        await fetchPosts(refresh: false)
    }

    // MARK: - Like/Unlike

    func likePost(_ postId: String) async {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        LoggingService.shared.debug(.agora, "Liking post: \(postId)", component: "AgoraManager")

        // Optimistic update
        posts[index].isLiked = true
        posts[index].likeCount += 1

        do {
            let _: LikeResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraPostLike(postId),
                method: .post
            )
            LoggingService.shared.debug(.agora, "Post liked successfully", component: "AgoraManager")
        } catch {
            // Revert on failure
            posts[index].isLiked = false
            posts[index].likeCount -= 1
            LoggingService.shared.error(.agora, "Failed to like post: \(error.localizedDescription)", component: "AgoraManager")
        }
    }

    func unlikePost(_ postId: String) async {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        LoggingService.shared.debug(.agora, "Unliking post: \(postId)", component: "AgoraManager")

        // Optimistic update
        posts[index].isLiked = false
        posts[index].likeCount = max(0, posts[index].likeCount - 1)

        do {
            let _: LikeResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraPostLike(postId),
                method: .delete
            )
            LoggingService.shared.debug(.agora, "Post unliked successfully", component: "AgoraManager")
        } catch {
            // Revert on failure
            posts[index].isLiked = true
            posts[index].likeCount += 1
            LoggingService.shared.error(.agora, "Failed to unlike post: \(error.localizedDescription)", component: "AgoraManager")
        }
    }

    func toggleLike(_ postId: String) async {
        guard let post = posts.first(where: { $0.id == postId }) else { return }

        if post.isLiked {
            await unlikePost(postId)
        } else {
            await likePost(postId)
        }
    }

    // MARK: - Comments

    func fetchComments(for postId: String) async -> [Comment] {
        LoggingService.shared.debug(.agora, "Fetching comments for post: \(postId)", component: "AgoraManager")
        do {
            struct CommentsResponse: Decodable {
                let data: [CommentAPIResponse]
                let hasMore: Bool
            }
            let response: CommentsResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraPostComments(postId)
            )
            LoggingService.shared.debug(.agora, "Fetched \(response.data.count) comments", component: "AgoraManager")
            return response.data.map { mapAPICommentToComment($0, postId: postId) }
        } catch {
            LoggingService.shared.error(.agora, "Failed to fetch comments: \(error.localizedDescription)", component: "AgoraManager")
            return []
        }
    }

    func fetchCommentsPaginated(for postId: String, page: Int = 1, limit: Int = 20) async -> (comments: [Comment], hasMore: Bool, total: Int) {
        LoggingService.shared.debug(.agora, "Fetching comments page \(page) for post: \(postId)", component: "AgoraManager")
        do {
            let endpoint = "\(APIEndpoints.agoraPostComments(postId))?page=\(page)&limit=\(limit)"
            let response: CommentsPaginatedResponse = try await APIClient.shared.request(endpoint: endpoint)
            LoggingService.shared.debug(.agora, "Fetched \(response.data.count) comments, total: \(response.total), hasMore: \(response.hasMore)", component: "AgoraManager")
            let comments = response.data.map { mapAPICommentToComment($0, postId: postId) }
            return (comments: comments, hasMore: response.hasMore, total: response.total)
        } catch {
            LoggingService.shared.error(.agora, "Failed to fetch comments: \(error.localizedDescription)", component: "AgoraManager")
            return (comments: [], hasMore: false, total: 0)
        }
    }

    func addComment(to postId: String, content: String, replyTo: String? = nil) async {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        LoggingService.shared.info(.agora, "Adding comment to post: \(postId)", component: "AgoraManager")

        let newComment = Comment(
            id: UUID().uuidString,
            postId: postId,
            userId: "current-user",
            userName: AuthManager.shared.currentUser?.displayName ?? "我",
            userAvatar: AuthManager.shared.currentUser?.avatarUrl,
            content: content,
            createdAt: Date(),
            likeCount: 0,
            isLiked: false,
            replyTo: replyTo,
            replyToUserName: nil
        )

        // Optimistic update
        if posts[index].comments == nil {
            posts[index].comments = []
        }
        posts[index].comments?.insert(newComment, at: 0)
        posts[index].commentCount += 1
        posts[index].hasUserComment = true

        do {
            let request = CreateCommentRequest(content: content, replyTo: replyTo)
            let _: CommentAPIResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraPostComments(postId),
                method: .post,
                body: request
            )
            LoggingService.shared.debug(.agora, "Comment added successfully", component: "AgoraManager")
        } catch {
            // Revert on failure
            posts[index].comments?.removeFirst()
            posts[index].commentCount -= 1
            // Check if user still has other comments
            let currentUserId = AuthManager.shared.currentUser?.id
            let hasOtherComments = posts[index].comments?.contains(where: { $0.userId == currentUserId }) ?? false
            posts[index].hasUserComment = hasOtherComments
            LoggingService.shared.error(.agora, "Failed to add comment: \(error.localizedDescription)", component: "AgoraManager")
        }
    }

    func likeComment(_ commentId: String, in postId: String) async {
        guard let postIndex = posts.firstIndex(where: { $0.id == postId }),
              let commentIndex = posts[postIndex].comments?.firstIndex(where: { $0.id == commentId }) else {
            return
        }

        let wasLiked = posts[postIndex].comments?[commentIndex].isLiked ?? false
        posts[postIndex].comments?[commentIndex].isLiked.toggle()
        if posts[postIndex].comments?[commentIndex].isLiked == true {
            posts[postIndex].comments?[commentIndex].likeCount += 1
        } else {
            posts[postIndex].comments?[commentIndex].likeCount -= 1
        }

        do {
            let _: LikeResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraCommentLike(commentId),
                method: wasLiked ? .delete : .post
            )
        } catch {
            // Revert on failure
            posts[postIndex].comments?[commentIndex].isLiked = wasLiked
            if wasLiked {
                posts[postIndex].comments?[commentIndex].likeCount += 1
            } else {
                posts[postIndex].comments?[commentIndex].likeCount -= 1
            }
        }
    }

    func deleteComment(_ commentId: String, in postId: String) async -> Bool {
        guard let postIndex = posts.firstIndex(where: { $0.id == postId }),
              let commentIndex = posts[postIndex].comments?.firstIndex(where: { $0.id == commentId }) else {
            return false
        }

        // Store for potential rollback
        let deletedComment = posts[postIndex].comments?[commentIndex]
        let previousHasUserComment = posts[postIndex].hasUserComment

        // Optimistic update
        posts[postIndex].comments?.remove(at: commentIndex)
        posts[postIndex].commentCount = max(0, posts[postIndex].commentCount - 1)

        // Check if user still has other comments after deletion
        let currentUserId = AuthManager.shared.currentUser?.id
        let hasOtherComments = posts[postIndex].comments?.contains(where: { $0.userId == currentUserId }) ?? false
        posts[postIndex].hasUserComment = hasOtherComments

        do {
            struct SuccessResponse: Decodable { let success: Bool }
            let _: SuccessResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraComment(commentId),
                method: .delete
            )
            return true
        } catch {
            // Revert on failure
            if let comment = deletedComment {
                posts[postIndex].comments?.insert(comment, at: commentIndex)
                posts[postIndex].commentCount += 1
                posts[postIndex].hasUserComment = previousHasUserComment
            }
            return false
        }
    }

    // MARK: - Share

    func sharePost(_ postId: String) async {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        posts[index].shareCount += 1

        do {
            struct SuccessResponse: Decodable { let success: Bool }
            let _: SuccessResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraPostShare(postId),
                method: .post
            )
        } catch {
            posts[index].shareCount -= 1
        }
    }

    // MARK: - Bookmark

    func toggleBookmark(_ postId: String) async {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        posts[index].isBookmarked.toggle()

        // TODO: API call for bookmark
    }

    // MARK: - Block/Hide

    func hidePost(_ postId: String) async {
        LoggingService.shared.info(.agora, "Hiding post: \(postId)", component: "AgoraManager")
        hiddenPosts.insert(postId)
        posts.removeAll { $0.id == postId }
        saveBlockedItems()

        do {
            struct SuccessResponse: Decodable { let success: Bool }
            let _: SuccessResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraPostHide(postId),
                method: .post
            )
            LoggingService.shared.debug(.agora, "Post hidden successfully", component: "AgoraManager")
        } catch {
            LoggingService.shared.warning(.agora, "Failed to sync hide post to server: \(error.localizedDescription)", component: "AgoraManager")
        }
    }

    func blockAuthor(_ authorId: String) async {
        LoggingService.shared.info(.agora, "Blocking author: \(authorId)", component: "AgoraManager")
        blockedAuthors.insert(authorId)
        posts.removeAll { $0.author?.id == authorId }
        saveBlockedItems()

        do {
            struct SuccessResponse: Decodable { let success: Bool }
            let _: SuccessResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraAuthorBlock(authorId),
                method: .post
            )
            LoggingService.shared.debug(.agora, "Author blocked successfully", component: "AgoraManager")
        } catch {
            LoggingService.shared.warning(.agora, "Failed to sync block author to server: \(error.localizedDescription)", component: "AgoraManager")
        }
    }

    func unblockAuthor(_ authorId: String) async {
        LoggingService.shared.info(.agora, "Unblocking author: \(authorId)", component: "AgoraManager")
        blockedAuthors.remove(authorId)
        saveBlockedItems()

        do {
            struct SuccessResponse: Decodable { let success: Bool }
            let _: SuccessResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraAuthorBlock(authorId),
                method: .delete
            )
            LoggingService.shared.debug(.agora, "Author unblocked successfully", component: "AgoraManager")
        } catch {
            LoggingService.shared.warning(.agora, "Failed to sync unblock author to server: \(error.localizedDescription)", component: "AgoraManager")
        }
    }

    func reportPost(_ postId: String, reason: String) async {
        LoggingService.shared.info(.agora, "Reporting post: \(postId), reason: \(reason)", component: "AgoraManager")
        await hidePost(postId)

        do {
            struct SuccessResponse: Decodable { let success: Bool }
            let request = ReportRequest(reason: reason)
            let _: SuccessResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraPostReport(postId),
                method: .post,
                body: request
            )
            LoggingService.shared.debug(.agora, "Post reported successfully", component: "AgoraManager")
        } catch {
            LoggingService.shared.warning(.agora, "Failed to sync report to server: \(error.localizedDescription)", component: "AgoraManager")
        }
    }

    // MARK: - Helper Methods

    private func filterBlockedContent(_ posts: [AgoraPost]) -> [AgoraPost] {
        posts.filter { post in
            let authorBlocked = post.author.map { blockedAuthors.contains($0.id) } ?? false
            return !authorBlocked &&
                !blockedPosts.contains(post.id) &&
                !hiddenPosts.contains(post.id)
        }
    }

    // MARK: - Persistence

    private func loadBlockedItems() {
        if let data = UserDefaults.standard.data(forKey: "agora_blocked_authors"),
           let authors = try? JSONDecoder().decode(Set<String>.self, from: data) {
            blockedAuthors = authors
        }

        if let data = UserDefaults.standard.data(forKey: "agora_hidden_posts"),
           let posts = try? JSONDecoder().decode(Set<String>.self, from: data) {
            hiddenPosts = posts
        }
    }

    private func saveBlockedItems() {
        if let data = try? JSONEncoder().encode(blockedAuthors) {
            UserDefaults.standard.set(data, forKey: "agora_blocked_authors")
        }

        if let data = try? JSONEncoder().encode(hiddenPosts) {
            UserDefaults.standard.set(data, forKey: "agora_hidden_posts")
        }
    }

    // MARK: - API Response Mapping

    private func mapAPIResponseToPost(_ response: AgoraPostAPIResponse) -> AgoraPost {
        // Map author if present
        var author: Author?
        if let authorResponse = response.author {
            author = Author(
                id: authorResponse.id,
                name: authorResponse.name,
                avatarUrl: authorResponse.avatarUrl,
                bio: authorResponse.bio,
                era: authorResponse.era,
                nationality: authorResponse.nationality,
                bookCount: authorResponse.bookCount,
                quoteCount: nil,
                followerCount: nil,
                isFollowed: nil
            )
        }

        // Map quote if present
        var quote: Quote?
        if let quoteResponse = response.quote {
            quote = Quote(
                id: quoteResponse.id,
                text: quoteResponse.text,
                author: quoteResponse.author,
                source: quoteResponse.source,
                sourceType: nil,
                bookId: quoteResponse.bookId,
                bookTitle: quoteResponse.bookTitle,
                chapterId: quoteResponse.chapter,
                tags: quoteResponse.tags,
                likeCount: 0,
                shareCount: nil,
                isLiked: nil,
                createdAt: nil,
                updatedAt: nil
            )
        }

        // Map user if present
        var user: PostUser?
        if let userResponse = response.user {
            user = PostUser(
                id: userResponse.id,
                name: userResponse.name,
                avatarUrl: userResponse.avatarUrl
            )
        }

        // Map media if present
        var media: [PostMedia]?
        if let mediaResponses = response.media {
            media = mediaResponses.map { mediaResponse in
                PostMedia(
                    id: mediaResponse.id,
                    type: PostMedia.MediaType(rawValue: mediaResponse.type) ?? .image,
                    url: mediaResponse.url,
                    thumbnailUrl: mediaResponse.thumbnailUrl,
                    width: mediaResponse.width,
                    height: mediaResponse.height,
                    duration: mediaResponse.duration
                )
            }
        }

        let comments = response.comments.map { mapAPICommentToComment($0, postId: response.id) }

        // Check if current user has commented
        let currentUserId = AuthManager.shared.currentUser?.id
        let hasUserComment = comments.contains(where: { $0.userId == currentUserId })

        // Determine post type
        let postType: PostType
        if let typeString = response.postType {
            postType = PostType(rawValue: typeString) ?? .author
        } else {
            postType = .author
        }

        return AgoraPost(
            id: response.id,
            postType: postType,
            author: author,
            quote: quote,
            user: user,
            content: response.content,
            media: media,
            simulatedPostTime: response.simulatedPostTime,
            likeCount: response.likeCount,
            commentCount: response.commentCount,
            shareCount: response.shareCount,
            isLiked: response.isLiked,
            isBookmarked: response.isBookmarked,
            hasUserComment: hasUserComment,
            comments: comments
        )
    }

    private func mapAPICommentToComment(_ response: CommentAPIResponse, postId: String) -> Comment {
        return Comment(
            id: response.id,
            postId: postId,
            userId: response.userId,
            userName: response.userName,
            userAvatar: response.userAvatar,
            content: response.content,
            createdAt: response.createdAt,
            likeCount: response.likeCount,
            isLiked: response.isLiked,
            replyTo: response.replyToId,
            replyToUserName: response.replyToUserName
        )
    }
}

// MARK: - Create User Post

struct MediaUploadResponse: Decodable {
    let id: String
    let url: String
    let thumbnailUrl: String?
    let type: String
    let width: Int?
    let height: Int?
    let duration: Int?
    let mimeType: String
    let fileSize: Int
}

struct CreatePostRequest: Encodable {
    let content: String?
    let mediaIds: [String]?
}

extension AgoraManager {
    /// Create a user post with optional content and media
    func createUserPost(content: String?, mediaIds: [String]?) async -> Bool {
        guard content != nil || !(mediaIds?.isEmpty ?? true) else {
            createPostError = "请输入内容或添加媒体"
            return false
        }

        isCreatingPost = true
        createPostError = nil

        LoggingService.shared.info(.agora, "Creating user post", component: "AgoraManager")

        do {
            let request = CreatePostRequest(content: content, mediaIds: mediaIds)
            let response: AgoraPostAPIResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.agoraPosts,
                method: .post,
                body: request
            )

            let newPost = mapAPIResponseToPost(response)

            // Insert at the beginning of the posts array
            posts.insert(newPost, at: 0)

            LoggingService.shared.info(.agora, "User post created successfully: \(newPost.id)", component: "AgoraManager")
            isCreatingPost = false
            return true
        } catch {
            createPostError = error.localizedDescription
            LoggingService.shared.error(.agora, "Failed to create user post: \(error.localizedDescription)", component: "AgoraManager")
            isCreatingPost = false
            return false
        }
    }

    /// Upload a media file and return the media ID
    func uploadMedia(data: Data, fileName: String, mimeType: String, type: String) async throws -> MediaUploadResponse {
        LoggingService.shared.info(.agora, "Uploading media: \(fileName), type: \(type)", component: "AgoraManager")

        let response: MediaUploadResponse = try await APIClient.shared.uploadMultipart(
            endpoint: APIEndpoints.agoraMediaUpload,
            fileData: data,
            fileName: fileName,
            mimeType: mimeType,
            additionalFields: ["type": type]
        )

        LoggingService.shared.info(.agora, "Media uploaded successfully: \(response.id)", component: "AgoraManager")
        return response
    }
}

// MARK: - Share Content Generator

extension AgoraManager {
    func generateShareImage(for post: AgoraPost) -> UIImage? {
        let view = ShareCardView(post: post)
        let controller = UIHostingController(rootView: view)
        let size = CGSize(width: 375, height: 500)

        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    func generateShareText(for post: AgoraPost) -> String {
        if post.isAuthorPost, let quote = post.quote, let author = post.author {
            var text = "\"\(quote.text)\"\n\n"
            text += "—— \(author.name)"
            if let bookTitle = quote.bookTitle {
                text += "\n《\(bookTitle)》"
            }
            text += "\n\n#Readmigo #\(author.name.replacingOccurrences(of: " ", with: ""))"
            return text
        } else if let content = post.content {
            var text = "\(content)\n\n"
            text += "—— \(post.displayName)"
            text += "\n\n#Readmigo"
            return text
        }
        return "#Readmigo"
    }
}

// MARK: - Share Card View (for image generation)

private struct ShareCardView: View {
    let post: AgoraPost

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if post.isAuthorPost, let quote = post.quote {
                Text("\"\(quote.text)\"")
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 32)

                VStack(spacing: 8) {
                    Text("—— \(post.displayName)")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if let bookTitle = quote.bookTitle {
                        Text("《\(bookTitle)》")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            } else if let content = post.content {
                Text(content)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 32)

                Text("—— \(post.displayName)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Text("Readmigo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 375, height: 500)
        .background(Color(.systemBackground))
    }
}
