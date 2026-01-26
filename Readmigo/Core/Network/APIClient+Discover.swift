import Foundation

// MARK: - Discover API Extension

extension APIClient {

    /// Get discover page tabs configuration
    /// - Returns: Array of discover tabs
    func getDiscoverTabs() async throws -> [DiscoverTab] {
        let response: DiscoverTabsResponse = try await request(
            endpoint: "/recommendation/discover/tabs"
        )
        return response.tabs
    }

    /// Get discover books with filtering
    /// - Parameters:
    ///   - categoryId: Optional category ID to filter by
    ///   - page: Page number (1-based)
    ///   - pageSize: Number of items per page
    /// - Returns: Paginated books with scores
    func getDiscoverBooks(
        categoryId: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> DiscoverBooksResponse {
        var endpoint = "/recommendation/discover?page=\(page)&pageSize=\(pageSize)"

        if let categoryId = categoryId {
            endpoint += "&categoryId=\(categoryId)"
        }

        return try await request(endpoint: endpoint)
    }
}
