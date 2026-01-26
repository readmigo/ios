import Foundation
import SwiftUI

/// Manages user's favorite books
@MainActor
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    // MARK: - Published Properties

    @Published private(set) var favorites: [FavoriteBook] = []
    @Published var isLoading = false
    @Published var total: Int = 0
    @Published var hasMore: Bool = false

    // MARK: - Computed Properties

    var isEmpty: Bool {
        favorites.isEmpty
    }

    var bookIds: Set<String> {
        Set(favorites.map { $0.bookId })
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Fetch favorites from server
    func fetchFavorites(limit: Int = 50, offset: Int = 0) async {
        guard AuthManager.shared.isAuthenticated else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: FavoritesResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.favorites)?limit=\(limit)&offset=\(offset)"
            )
            favorites = response.items
            total = response.total
            hasMore = response.hasMore
        } catch {
            LoggingService.shared.debug(.books, "Failed to fetch favorites: \(error)", component: "FavoritesManager")
        }
    }

    /// Add a book to favorites
    func addToFavorites(bookId: String) async -> Bool {
        LoggingService.shared.debug(.books, "❤️ [FavoritesManager] addToFavorites called for bookId: \(bookId)", component: "FavoritesManager")
        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] addToFavorites: Not authenticated", component: "FavoritesManager")
            return false
        }

        do {
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] addToFavorites: Making API request to \(APIEndpoints.favorites)", component: "FavoritesManager")
            let favorite: FavoriteBook = try await APIClient.shared.request(
                endpoint: APIEndpoints.favorites,
                method: .post,
                body: ["bookId": bookId]
            )
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] addToFavorites: API success, favorite id: \(favorite.id)", component: "FavoritesManager")

            // Add to local list if not already present
            if !favorites.contains(where: { $0.bookId == bookId }) {
                favorites.insert(favorite, at: 0)
                total += 1
                LoggingService.shared.debug(.books, "❤️ [FavoritesManager] addToFavorites: Added to local list, total: \(total)", component: "FavoritesManager")
            }
            return true
        } catch {
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] addToFavorites: FAILED - \(error)", component: "FavoritesManager")
            return false
        }
    }

    /// Remove a book from favorites
    func removeFromFavorites(bookId: String) async -> Bool {
        guard AuthManager.shared.isAuthenticated else { return false }

        // Update UI first
        let originalFavorites = favorites
        favorites.removeAll { $0.bookId == bookId }
        total = max(0, total - 1)

        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.favoriteItem(bookId),
                method: .delete
            )
            return true
        } catch {
            LoggingService.shared.debug(.books, "Failed to remove from favorites: \(error)", component: "FavoritesManager")
            favorites = originalFavorites // Rollback
            total = originalFavorites.count
            return false
        }
    }

    /// Check if a book is favorited
    func isFavorited(bookId: String) -> Bool {
        favorites.contains { $0.bookId == bookId }
    }

    /// Check if a book is favorited (server check)
    func checkFavorite(bookId: String) async -> Bool {
        guard AuthManager.shared.isAuthenticated else { return false }

        do {
            struct CheckResponse: Codable {
                let isFavorited: Bool
            }
            let response: CheckResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.favoriteCheck(bookId),
                method: .get
            )
            return response.isFavorited
        } catch {
            return false
        }
    }

    /// Toggle favorite status
    func toggleFavorite(bookId: String) async -> Bool {
        LoggingService.shared.debug(.books, "❤️ [FavoritesManager] ========== toggleFavorite START ==========", component: "FavoritesManager")
        LoggingService.shared.debug(.books, "❤️ [FavoritesManager] bookId: \(bookId)", component: "FavoritesManager")
        LoggingService.shared.debug(.books, "❤️ [FavoritesManager] isAuthenticated: \(AuthManager.shared.isAuthenticated)", component: "FavoritesManager")
        LoggingService.shared.debug(.books, "❤️ [FavoritesManager] current favorites count: \(favorites.count)", component: "FavoritesManager")
        LoggingService.shared.debug(.books, "❤️ [FavoritesManager] isFavorited: \(isFavorited(bookId: bookId))", component: "FavoritesManager")

        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] ERROR: Not authenticated, returning false", component: "FavoritesManager")
            return false
        }

        if isFavorited(bookId: bookId) {
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] Book is favorited, will remove...", component: "FavoritesManager")
            let result = await removeFromFavorites(bookId: bookId)
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] removeFromFavorites result: \(result)", component: "FavoritesManager")
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] ========== toggleFavorite END ==========", component: "FavoritesManager")
            return result
        } else {
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] Book is NOT favorited, will add...", component: "FavoritesManager")
            let result = await addToFavorites(bookId: bookId)
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] addToFavorites result: \(result)", component: "FavoritesManager")
            LoggingService.shared.debug(.books, "❤️ [FavoritesManager] ========== toggleFavorite END ==========", component: "FavoritesManager")
            return result
        }
    }

    /// Batch delete favorites
    func batchDelete(bookIds: [String]) async -> Int {
        guard AuthManager.shared.isAuthenticated else { return 0 }

        // Update UI first
        let originalFavorites = favorites
        favorites.removeAll { bookIds.contains($0.bookId) }
        let deletedCount = originalFavorites.count - favorites.count
        total = max(0, total - deletedCount)

        do {
            struct BatchDeleteResponse: Codable {
                let deletedCount: Int
            }
            let response: BatchDeleteResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.favoritesBatchDelete,
                method: .post,
                body: ["bookIds": bookIds]
            )
            return response.deletedCount
        } catch {
            LoggingService.shared.debug(.books, "Failed to batch delete favorites: \(error)", component: "FavoritesManager")
            favorites = originalFavorites // Rollback
            total = originalFavorites.count
            return 0
        }
    }

    /// Called when user logs out - clear data
    func handleLogout() {
        favorites = []
        total = 0
        hasMore = false
    }
}
