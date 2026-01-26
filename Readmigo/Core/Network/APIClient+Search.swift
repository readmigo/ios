import Foundation

// MARK: - Search API Extension

extension APIClient {

    /// Perform unified search across authors, books, and quotes
    func unifiedSearch(query: String, limit: Int = 5) async throws -> UnifiedSearchResponse {
        guard !query.isEmpty else {
            return UnifiedSearchResponse(
                query: "",
                authors: SearchResultSection(items: [], total: 0, hasMore: false),
                books: SearchResultSection(items: [], total: 0, hasMore: false),
                quotes: SearchResultSection(items: [], total: 0, hasMore: false)
            )
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let endpoint = "/search?q=\(encodedQuery)&limit=\(limit)"

        return try await request(
            endpoint: endpoint,
            headers: ["X-Client-Type": "ios"]
        )
    }

    /// Get search suggestions for autocomplete
    func getSearchSuggestions(query: String, limit: Int = 5) async throws -> [SearchSuggestion] {
        guard query.count >= 2 else {
            return []
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let endpoint = "/search/suggestions?q=\(encodedQuery)&limit=\(limit)"

        return try await request(
            endpoint: endpoint,
            headers: ["X-Client-Type": "ios"]
        )
    }

    /// Get popular search terms
    func getPopularSearches(limit: Int = 10) async throws -> [PopularSearch] {
        let endpoint = "/search/popular?limit=\(limit)"
        return try await request(endpoint: endpoint)
    }

    /// Get trending search terms (today)
    func getTrendingSearches(limit: Int = 10) async throws -> [PopularSearch] {
        let endpoint = "/search/trending?limit=\(limit)"
        return try await request(endpoint: endpoint)
    }
}
