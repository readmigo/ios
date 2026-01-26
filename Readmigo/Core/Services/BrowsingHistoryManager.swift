import Foundation
import SwiftUI

// MARK: - Data Models

/// Server response for browsing history list
struct BrowsingHistoryResponse: Codable {
    let items: [BrowsingHistoryItem]
    let total: Int
    let hasMore: Bool
}

/// Single browsing history item from server
struct BrowsingHistoryItem: Codable, Identifiable {
    let id: String
    let bookId: String
    let book: BrowsedBookInfo
    let browsedAt: Date
    var sortOrder: Int

    struct BrowsedBookInfo: Codable {
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
}

/// Sync request item
struct SyncItem: Codable {
    let bookId: String
    let browsedAt: Date
    let sortOrder: Int
}

/// Sync response
struct SyncResponse: Codable {
    let syncedCount: Int
    let items: [BrowsingHistoryItem]
}

/// Batch delete response
struct BatchDeleteResponse: Codable {
    let deletedCount: Int
}

/// Reorder request item
struct ReorderItem: Codable {
    let bookId: String
    let sortOrder: Int
}

/// Reorder request
struct ReorderRequest: Codable {
    let items: [ReorderItem]
}

/// Manages browsing history persistence for guest users and cloud sync for authenticated users
@MainActor
class BrowsingHistoryManager: ObservableObject {
    static let shared = BrowsingHistoryManager()

    private let userDefaultsKey = "browsingHistory"
    private let maxHistoryCount = 30

    // MARK: - Published Properties

    /// Cloud history (for authenticated users)
    @Published private(set) var cloudHistory: [BrowsingHistoryItem] = []

    /// Local history (for guest users)
    @Published private(set) var localHistory: [BrowsedBook] = []

    @Published var isLoading = false
    @Published var isSyncing = false

    // MARK: - Data Model (Local)

    struct BrowsedBook: Codable, Identifiable {
        let id: String
        let title: String
        let author: String
        let coverUrl: String?
        let coverThumbUrl: String?
        let difficultyScore: Double?
        let browsedAt: Date
        var sortOrder: Int

        /// Use thumbnail for display, fallback to full cover
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

    // MARK: - Computed Properties

    /// Check if history is empty
    var isEmpty: Bool {
        if AuthManager.shared.isAuthenticated {
            return mergedHistory.isEmpty
        } else {
            return localHistory.isEmpty
        }
    }

    /// Get all book IDs in local history (for merging to cloud)
    var localBookIds: [String] {
        localHistory.map { $0.id }
    }

    /// Merged history (local + cloud) for display
    /// - Deduplicates by bookId, keeps the one with newer browsedAt
    /// - Sorted by browsedAt descending (most recent first)
    var mergedHistory: [BrowsingHistoryDisplayItem] {
        var bookMap: [String: BrowsingHistoryDisplayItem] = [:]

        // Add local history
        for local in localHistory {
            let item = BrowsingHistoryDisplayItem(
                id: local.id,
                title: local.title,
                author: local.author,
                coverUrl: local.coverUrl,
                coverThumbUrl: local.coverThumbUrl,
                browsedAt: local.browsedAt
            )
            bookMap[local.id] = item
        }

        // Add/merge cloud history
        for cloud in cloudHistory {
            if let existing = bookMap[cloud.bookId] {
                // Keep the one with newer browsedAt
                if cloud.browsedAt > existing.browsedAt {
                    bookMap[cloud.bookId] = BrowsingHistoryDisplayItem(
                        id: cloud.bookId,
                        title: cloud.book.title,
                        author: cloud.book.author,
                        coverUrl: cloud.book.coverUrl,
                        coverThumbUrl: cloud.book.coverThumbUrl,
                        browsedAt: cloud.browsedAt
                    )
                }
            } else {
                bookMap[cloud.bookId] = BrowsingHistoryDisplayItem(
                    id: cloud.bookId,
                    title: cloud.book.title,
                    author: cloud.book.author,
                    coverUrl: cloud.book.coverUrl,
                    coverThumbUrl: cloud.book.coverThumbUrl,
                    browsedAt: cloud.browsedAt
                )
            }
        }

        // Sort by browsedAt descending
        return bookMap.values.sorted { $0.browsedAt > $1.browsedAt }
    }

    // MARK: - Initialization

    private init() {
        loadLocalHistory()
    }

    // MARK: - Public Methods

    /// Fetch browsing history from server (for authenticated users)
    func fetchFromServer() async {
        LoggingService.shared.debug(.books, "📚 [BrowsingHistory] fetchFromServer called", component: "BrowsingHistoryManager")
        LoggingService.shared.debug(.books, "📚 [BrowsingHistory] isAuthenticated: \(AuthManager.shared.isAuthenticated)", component: "BrowsingHistoryManager")
        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.books, "📚 [BrowsingHistory] Not authenticated, skipping", component: "BrowsingHistoryManager")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            LoggingService.shared.debug(.books, "📚 [BrowsingHistory] Making API request to \(APIEndpoints.browsingHistory)", component: "BrowsingHistoryManager")
            let response: BrowsingHistoryResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.browsingHistory,
                method: .get
            )
            cloudHistory = response.items
            LoggingService.shared.debug(.books, "📚 [BrowsingHistory] Received \(response.items.count) items", component: "BrowsingHistoryManager")
        } catch {
            LoggingService.shared.debug(.books, "📚 [BrowsingHistory] FAILED: \(error)", component: "BrowsingHistoryManager")
        }
    }

    /// Add a book to browsing history
    /// - Parameter book: The book that was browsed
    func addBook(_ book: Book) async {
        if AuthManager.shared.isAuthenticated {
            await addToServer(bookId: book.id)
        } else {
            addToLocal(book)
        }
    }

    /// Remove a specific book from history
    /// - Parameter id: The book ID to remove
    func removeBook(id: String) async {
        if AuthManager.shared.isAuthenticated {
            await removeFromServer(bookId: id)
        } else {
            removeFromLocal(id: id)
        }
    }

    /// Batch delete books from history
    /// - Parameter ids: Set of book IDs to delete
    func batchDelete(ids: Set<String>) async {
        if AuthManager.shared.isAuthenticated {
            await batchDeleteFromServer(bookIds: Array(ids))
        } else {
            for id in ids {
                removeFromLocal(id: id)
            }
        }
    }

    /// Reorder browsing history items (drag and drop)
    /// - Parameters:
    ///   - source: Source indices
    ///   - destination: Destination index
    func reorder(from source: IndexSet, to destination: Int) async {
        if AuthManager.shared.isAuthenticated {
            // Update local UI first
            var items = cloudHistory
            items.move(fromOffsets: source, toOffset: destination)

            // Recalculate sortOrder
            for index in items.indices {
                items[index].sortOrder = index
            }
            cloudHistory = items

            // Sync to server
            await reorderOnServer(items: items.map { (bookId: $0.bookId, sortOrder: $0.sortOrder) })
        } else {
            // Local reorder
            localHistory.move(fromOffsets: source, toOffset: destination)
            for index in localHistory.indices {
                localHistory[index].sortOrder = index
            }
            saveLocalHistory()
        }
    }

    /// Clear all browsing history
    func clearHistory() async {
        if AuthManager.shared.isAuthenticated {
            let allIds = cloudHistory.map { $0.bookId }
            await batchDeleteFromServer(bookIds: allIds)
        } else {
            localHistory = []
            saveLocalHistory()
        }
    }

    /// Merge local history to cloud after login
    func mergeAfterLogin() async {
        guard !localHistory.isEmpty else {
            await fetchFromServer()
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            // 1. Get server history
            let serverResponse: BrowsingHistoryResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.browsingHistory,
                method: .get
            )
            let serverHistory = serverResponse.items
            let serverBookIds = Set(serverHistory.map { $0.bookId })

            // 2. Build sync items
            var syncItems: [SyncItem] = []

            for local in localHistory {
                if serverBookIds.contains(local.id) {
                    // Both have it - use newer timestamp
                    if let serverItem = serverHistory.first(where: { $0.bookId == local.id }) {
                        let newerDate = max(local.browsedAt, serverItem.browsedAt)
                        syncItems.append(SyncItem(
                            bookId: local.id,
                            browsedAt: newerDate,
                            sortOrder: local.sortOrder
                        ))
                    }
                } else {
                    // Only local has it - add to server
                    syncItems.append(SyncItem(
                        bookId: local.id,
                        browsedAt: local.browsedAt,
                        sortOrder: local.sortOrder
                    ))
                }
            }

            // 3. Sync to server
            if !syncItems.isEmpty {
                let response: SyncResponse = try await APIClient.shared.request(
                    endpoint: APIEndpoints.browsingHistorySync,
                    method: .post,
                    body: ["items": syncItems]
                )
                cloudHistory = response.items
            }

            // 4. Clear local storage
            localHistory = []
            saveLocalHistory()

            // 5. Refresh from server
            await fetchFromServer()

        } catch {
            LoggingService.shared.debug(.books, "Failed to merge browsing history: \(error)", component: "BrowsingHistoryManager")
            // Still try to fetch from server
            await fetchFromServer()
        }
    }

    /// Called when user logs out - switch to local mode
    func handleLogout() {
        cloudHistory = []
    }

    // MARK: - Private Methods (Server)

    private func addToServer(bookId: String) async {
        do {
            let _: BrowsingHistoryItem = try await APIClient.shared.request(
                endpoint: APIEndpoints.browsingHistory,
                method: .post,
                body: ["bookId": bookId]
            )
            await fetchFromServer()
        } catch {
            LoggingService.shared.debug(.books, "Failed to add to browsing history: \(error)", component: "BrowsingHistoryManager")
        }
    }

    private func removeFromServer(bookId: String) async {
        // Update UI first
        cloudHistory.removeAll { $0.bookId == bookId }

        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.browsingHistoryItem(bookId),
                method: .delete
            )
        } catch {
            LoggingService.shared.debug(.books, "Failed to remove from browsing history: \(error)", component: "BrowsingHistoryManager")
            await fetchFromServer() // Rollback UI
        }
    }

    private func batchDeleteFromServer(bookIds: [String]) async {
        // Update UI first
        let originalHistory = cloudHistory
        cloudHistory.removeAll { bookIds.contains($0.bookId) }

        do {
            let _: BatchDeleteResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.browsingHistoryBatchDelete,
                method: .post,
                body: ["bookIds": bookIds]
            )
        } catch {
            LoggingService.shared.debug(.books, "Failed to batch delete from browsing history: \(error)", component: "BrowsingHistoryManager")
            cloudHistory = originalHistory // Rollback
        }
    }

    private func reorderOnServer(items: [(bookId: String, sortOrder: Int)]) async {
        let requestItems = items.map { ReorderItem(bookId: $0.bookId, sortOrder: $0.sortOrder) }
        let request = ReorderRequest(items: requestItems)

        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.browsingHistoryReorder,
                method: .patch,
                body: request
            )
        } catch {
            LoggingService.shared.debug(.books, "Failed to reorder browsing history: \(error)", component: "BrowsingHistoryManager")
            await fetchFromServer() // Rollback
        }
    }

    // MARK: - Private Methods (Local)

    private func loadLocalHistory() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            localHistory = try decoder.decode([BrowsedBook].self, from: data)
        } catch {
            LoggingService.shared.debug(.books, "Failed to load browsing history: \(error)", component: "BrowsingHistoryManager")
            localHistory = []
        }
    }

    private func saveLocalHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(localHistory)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            LoggingService.shared.debug(.books, "Failed to save browsing history: \(error)", component: "BrowsingHistoryManager")
        }
    }

    private func addToLocal(_ book: Book) {
        // Remove if already exists (will be re-added at top)
        localHistory.removeAll { $0.id == book.id }

        // Create browsed book record
        let browsedBook = BrowsedBook(
            id: book.id,
            title: book.title,
            author: book.author,
            coverUrl: book.coverUrl,
            coverThumbUrl: book.coverThumbUrl,
            difficultyScore: book.difficultyScore,
            browsedAt: Date(),
            sortOrder: 0
        )

        // Insert at beginning (most recent first)
        localHistory.insert(browsedBook, at: 0)

        // Update sortOrder
        for index in localHistory.indices {
            localHistory[index].sortOrder = index
        }

        // Limit history size
        if localHistory.count > maxHistoryCount {
            localHistory = Array(localHistory.prefix(maxHistoryCount))
        }

        saveLocalHistory()
    }

    private func removeFromLocal(id: String) {
        localHistory.removeAll { $0.id == id }
        saveLocalHistory()
    }
}
