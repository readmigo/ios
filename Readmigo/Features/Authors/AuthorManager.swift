import Foundation
import SwiftUI

/// Manager for author profiles and AI chat functionality
@MainActor
class AuthorManager: ObservableObject {
    static let shared = AuthorManager()

    // MARK: - Published Properties

    // Authors
    @Published var authors: [Author] = []
    @Published var followedAuthors: [Author] = []
    @Published var relatedAuthors: [Author] = []
    @Published var currentAuthorDetail: AuthorDetail?
    @Published var readingProgress: AuthorReadingProgress?

    // Chat
    @Published var chatSessions: [ChatSession] = []
    @Published var currentSession: ChatSessionDetail?
    @Published var currentMessages: [ChatMessage] = []

    // State
    @Published var isLoading = false
    @Published var isLoadingDetail = false
    @Published var isLoadingChat = false
    @Published var isSendingMessage = false
    @Published var errorMessage: String?

    /// Data source indicator for offline support
    @Published var dataSource: DataSourceType = .network
    @Published var lastSyncTime: Date?

    enum DataSourceType {
        case network
        case cache
    }

    private let cacheService = ResponseCacheService.shared

    /// Track when follow action occurred to prevent race condition with background refresh
    /// Only preserve local isFollowed status within this time window
    private var lastFollowActionTime: Date?
    private let followActionProtectionWindow: TimeInterval = 5.0 // 5 seconds

    private init() {}

    // MARK: - Authors API

    /// Fetch list of authors
    func fetchAuthors(page: Int = 1, search: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            var endpoint = "\(APIEndpoints.authors)?page=\(page)&limit=20"
            if let search = search, !search.isEmpty {
                endpoint += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
            }

            let response: AuthorsResponse = try await APIClient.shared.request(endpoint: endpoint)
            if page == 1 {
                authors = response.data
            } else {
                authors.append(contentsOf: response.data)
            }
        } catch {
            errorMessage = "Failed to fetch authors: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Fetch author detail by ID
    /// Shows cached data immediately if available, then refreshes from network
    func fetchAuthorDetail(_ authorId: String) async {
        errorMessage = nil
        let cacheKey = CacheKeys.authorKey(authorId)

        // If switching to a different author, clear old data first
        if currentAuthorDetail?.id != authorId {
            currentAuthorDetail = nil
            relatedAuthors = []
            readingProgress = nil
        }

        // Step 1: If we already have the correct author loaded, skip loading
        if currentAuthorDetail?.id == authorId {
            isLoadingDetail = false
        } else if let cachedDetail: AuthorDetail = await cacheService.get(cacheKey, type: AuthorDetail.self) {
            // Show cached data immediately
            currentAuthorDetail = cachedDetail
            if let cachedAt = await cacheService.getCachedResponse(cacheKey)?.timestamp {
                lastSyncTime = cachedAt
            }
            dataSource = .cache
            isLoadingDetail = false
        } else {
            // No cache, show loading
            isLoadingDetail = true
        }

        // Step 2: Fetch fresh data from network
        do {
            var freshDetail: AuthorDetail = try await APIClient.shared.request(
                endpoint: APIEndpoints.author(authorId)
            )

            // Preserve local isFollowed status only if a follow action occurred recently
            // This prevents race condition during follow/unfollow, but allows server state to update on page reopen
            if let lastAction = lastFollowActionTime,
               Date().timeIntervalSince(lastAction) < followActionProtectionWindow,
               let currentDetail = currentAuthorDetail,
               currentDetail.id == authorId {
                freshDetail.isFollowed = currentDetail.isFollowed
            }

            // Update with fresh data
            currentAuthorDetail = freshDetail
            await cacheService.set(freshDetail, for: cacheKey, ttl: .author)
            dataSource = .network
            lastSyncTime = Date()
        } catch {
            // Only show error if we don't have cached data
            if currentAuthorDetail == nil {
                errorMessage = "Failed to fetch author detail: \(error.localizedDescription)"
            }
            // Keep showing cached data if available
        }

        isLoadingDetail = false
    }

    /// Follow an author
    func followAuthor(_ authorId: String) async {
        // Mark follow action time to protect against race condition with background refresh
        lastFollowActionTime = Date()

        // Optimistic update
        updateFollowStatus(authorId: authorId, isFollowed: true)

        do {
            try await APIClient.shared.request(
                endpoint: APIEndpoints.authorFollow(authorId),
                method: .post
            ) as EmptyResponse

            // Update cache to persist the follow status
            await updateFollowStatusInCache(authorId: authorId, isFollowed: true)
        } catch {
            // Revert on failure
            updateFollowStatus(authorId: authorId, isFollowed: false)
            errorMessage = "Failed to follow author: \(error.localizedDescription)"
        }
    }

    /// Unfollow an author
    func unfollowAuthor(_ authorId: String) async {
        // Mark follow action time to protect against race condition with background refresh
        lastFollowActionTime = Date()

        // Optimistic update
        updateFollowStatus(authorId: authorId, isFollowed: false)

        do {
            try await APIClient.shared.request(
                endpoint: APIEndpoints.authorFollow(authorId),
                method: .delete
            ) as EmptyResponse

            // Update cache to persist the unfollow status
            await updateFollowStatusInCache(authorId: authorId, isFollowed: false)
        } catch {
            // Revert on failure
            updateFollowStatus(authorId: authorId, isFollowed: true)
            errorMessage = "Failed to unfollow author: \(error.localizedDescription)"
        }
    }

    /// Update cached author detail with new follow status
    private func updateFollowStatusInCache(authorId: String, isFollowed: Bool) async {
        let cacheKey = CacheKeys.authorKey(authorId)
        if var cachedDetail: AuthorDetail = await cacheService.get(cacheKey, type: AuthorDetail.self),
           cachedDetail.id == authorId {
            cachedDetail.isFollowed = isFollowed
            await cacheService.set(cachedDetail, for: cacheKey, ttl: .author)
        }
    }

    /// Fetch followed authors
    func fetchFollowedAuthors() async {
        do {
            followedAuthors = try await APIClient.shared.request(
                endpoint: APIEndpoints.authorsFollowing
            )
        } catch {
            errorMessage = "Failed to fetch followed authors: \(error.localizedDescription)"
        }
    }

    /// Fetch related authors (same era, nationality, literary period)
    /// Shows cached data immediately if available, then refreshes from network
    func fetchRelatedAuthors(_ authorId: String) async {
        let cacheKey = CacheKeys.relatedAuthorsKey(authorId)

        // Step 1: Show cached data immediately if available
        if let cached: [Author] = await cacheService.get(cacheKey, type: [Author].self) {
            relatedAuthors = cached
            LoggingService.shared.info(.authorChat, "Showing cached related authors: \(authorId)")
        }

        // Step 2: Fetch fresh data from network
        do {
            let freshAuthors: [Author] = try await APIClient.shared.request(
                endpoint: APIEndpoints.authorRelated(authorId)
            )
            relatedAuthors = freshAuthors
            await cacheService.set(freshAuthors, for: cacheKey, ttl: .author)
        } catch {
            // Only show error if we don't have cached data
            if relatedAuthors.isEmpty {
                errorMessage = "Failed to fetch related authors: \(error.localizedDescription)"
            }
        }
    }

    private func updateFollowStatus(authorId: String, isFollowed: Bool) {
        // Update in authors list
        if let index = authors.firstIndex(where: { $0.id == authorId }) {
            authors[index].isFollowed = isFollowed
        }

        // Update current detail
        if currentAuthorDetail?.id == authorId {
            currentAuthorDetail?.isFollowed = isFollowed
        }

        // Update followed list
        if isFollowed {
            if let author = authors.first(where: { $0.id == authorId }),
               !followedAuthors.contains(where: { $0.id == authorId }) {
                followedAuthors.insert(author, at: 0)
            }
        } else {
            followedAuthors.removeAll { $0.id == authorId }
        }
    }

    // MARK: - Chat API

    /// Create a new chat session
    func createChatSession(authorId: String, title: String? = nil) async -> String? {
        do {
            let request = CreateSessionRequest(authorId: authorId, title: title)
            let session: ChatSession = try await APIClient.shared.request(
                endpoint: APIEndpoints.authorChatSessions,
                method: .post,
                body: request
            )
            chatSessions.insert(session, at: 0)
            return session.id
        } catch {
            errorMessage = "Failed to create chat session: \(error.localizedDescription)"
            return nil
        }
    }

    /// Fetch all chat sessions
    func fetchChatSessions() async {
        isLoadingChat = true

        do {
            let response: ChatSessionListResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.authorChatSessions
            )
            chatSessions = response.data
        } catch {
            errorMessage = "Failed to fetch chat sessions: \(error.localizedDescription)"
        }

        isLoadingChat = false
    }

    /// Fetch a specific chat session with messages
    func fetchChatSession(_ sessionId: String) async {
        isLoadingChat = true

        do {
            currentSession = try await APIClient.shared.request(
                endpoint: APIEndpoints.authorChatSession(sessionId)
            )
            currentMessages = currentSession?.messages ?? []
        } catch {
            errorMessage = "Failed to fetch chat session: \(error.localizedDescription)"
        }

        isLoadingChat = false
    }

    /// Send a message in a chat session
    func sendMessage(_ sessionId: String, content: String) async {
        isSendingMessage = true

        // Add user message immediately for optimistic UI
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: content,
            createdAt: Date()
        )
        currentMessages.append(userMessage)

        do {
            let request = SendMessageRequest(content: content)
            let response: SendMessageResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.authorChatMessages(sessionId),
                method: .post,
                body: request
            )

            // Replace optimistic user message and add assistant response
            if let index = currentMessages.lastIndex(where: { $0.id == userMessage.id }) {
                currentMessages[index] = response.userMessage
            }
            currentMessages.append(response.assistantMessage)

            // Update session in list
            if let index = chatSessions.firstIndex(where: { $0.id == sessionId }) {
                chatSessions[index].lastMessage = response.assistantMessage.content
                chatSessions[index].updatedAt = Date()
            }
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            // Remove optimistic message on error
            currentMessages.removeAll { $0.id == userMessage.id }
        }

        isSendingMessage = false
    }

    /// Delete a chat session
    func deleteChatSession(_ sessionId: String) async {
        // Optimistic update
        chatSessions.removeAll { $0.id == sessionId }

        do {
            try await APIClient.shared.request(
                endpoint: APIEndpoints.authorChatSession(sessionId),
                method: .delete
            ) as EmptyResponse
        } catch {
            errorMessage = "Failed to delete chat session: \(error.localizedDescription)"
        }
    }

    /// Clear current session
    func clearCurrentSession() {
        currentSession = nil
        currentMessages = []
    }

    /// Clear current author detail
    func clearCurrentAuthor() {
        currentAuthorDetail = nil
        relatedAuthors = []
        readingProgress = nil
    }

    /// Fetch reading progress for an author (books read by current user)
    func fetchReadingProgress(_ authorId: String) async {
        do {
            readingProgress = try await APIClient.shared.request(
                endpoint: APIEndpoints.authorReadingProgress(authorId)
            )
        } catch {
            // Reading progress is optional, don't show error
            readingProgress = AuthorReadingProgress(booksRead: 0, totalBooks: 0, readBookIds: [])
        }
    }
}

// MARK: - Reading Progress Model

struct AuthorReadingProgress: Codable {
    let booksRead: Int
    let totalBooks: Int
    let readBookIds: [String]

    var progress: Double {
        guard totalBooks > 0 else { return 0 }
        return Double(booksRead) / Double(totalBooks)
    }

    var isComplete: Bool {
        totalBooks > 0 && booksRead >= totalBooks
    }
}
