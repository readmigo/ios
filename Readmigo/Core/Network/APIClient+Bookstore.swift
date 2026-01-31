import Foundation

// MARK: - Bookstore API Extension

extension APIClient {

    /// Get bookstore page tabs configuration
    /// - Returns: Array of bookstore tabs
    func getBookstoreTabs() async throws -> [BookstoreTab] {
        let response: BookstoreTabsResponse = try await request(
            endpoint: "/recommendation/discover/tabs"
        )
        return response.tabs
    }

    /// Get bookstore books with filtering
    /// - Parameters:
    ///   - categoryId: Optional category ID to filter by
    ///   - page: Page number (1-based)
    ///   - pageSize: Number of items per page
    /// - Returns: Paginated books with scores
    func getBookstoreBooks(
        categoryId: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> BookstoreBooksResponse {
        var endpoint = "/recommendation/discover?page=\(page)&pageSize=\(pageSize)"

        if let categoryId = categoryId {
            endpoint += "&categoryId=\(categoryId)"
        }

        return try await request(endpoint: endpoint)
    }
}
