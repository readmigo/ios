import Foundation
import Combine

@MainActor
class SearchManager: ObservableObject {
    static let shared = SearchManager()

    // MARK: - Published Properties

    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var error: String?
    @Published var recentSearches: [RecentSearch] = []
    @Published var searchHistory: [SearchHistoryItem] = []
    @Published var totalMatches = 0
    @Published var searchTime: Double = 0

    // MARK: - Private Properties

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let recentSearchesKey = "recentSearches"
    private let searchHistoryKey = "searchHistory"
    private let maxRecentSearches = 10
    private let maxHistory = 50
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        loadLocalData()
    }

    private func loadLocalData() {
        // Load recent searches
        if let data = UserDefaults.standard.data(forKey: recentSearchesKey),
           let searches = try? decoder.decode([RecentSearch].self, from: data) {
            recentSearches = searches
        }

        // Load search history
        if let data = UserDefaults.standard.data(forKey: searchHistoryKey),
           let history = try? decoder.decode([SearchHistoryItem].self, from: data) {
            searchHistory = history
        }
    }

    private func saveLocalData() {
        if let data = try? encoder.encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: recentSearchesKey)
        }
        if let data = try? encoder.encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: searchHistoryKey)
        }
    }

    // MARK: - Search

    func search(query: SearchQuery) async {
        guard !query.query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        // Cancel previous search
        searchTask?.cancel()

        isSearching = true
        error = nil

        searchTask = Task {
            do {
                // Add to recent searches
                addToRecentSearches(query.query)

                let startTime = Date()

                // Perform search based on type
                let response: SearchResponse
                switch query.searchType {
                case .keyword:
                    response = try await performKeywordSearch(query)
                case .semantic:
                    response = try await performSemanticSearch(query)
                case .regex:
                    response = try await performRegexSearch(query)
                }

                guard !Task.isCancelled else { return }

                searchResults = response.results
                totalMatches = response.totalMatches
                searchTime = Date().timeIntervalSince(startTime)

                // Add to history
                addToHistory(query: query, resultsCount: response.totalMatches)

            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                    searchResults = []
                }
            }

            isSearching = false
        }
    }

    private func performKeywordSearch(_ query: SearchQuery) async throws -> SearchResponse {
        var endpoint = "/search?q=\(query.query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query.query)"

        if let bookId = query.bookId {
            endpoint += "&bookId=\(bookId)"
        }
        if let chapterId = query.chapterId {
            endpoint += "&chapterId=\(chapterId)"
        }
        endpoint += "&type=keyword"
        endpoint += "&caseSensitive=\(query.caseSensitive)"
        endpoint += "&wholeWord=\(query.wholeWord)"
        endpoint += "&limit=\(query.maxResults)"

        return try await APIClient.shared.request(endpoint: endpoint)
    }

    private func performSemanticSearch(_ query: SearchQuery) async throws -> SearchResponse {
        var endpoint = "/search?q=\(query.query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query.query)"

        if let bookId = query.bookId {
            endpoint += "&bookId=\(bookId)"
        }
        endpoint += "&type=semantic"
        endpoint += "&limit=\(query.maxResults)"

        return try await APIClient.shared.request(endpoint: endpoint)
    }

    private func performRegexSearch(_ query: SearchQuery) async throws -> SearchResponse {
        var endpoint = "/search?q=\(query.query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query.query)"

        if let bookId = query.bookId {
            endpoint += "&bookId=\(bookId)"
        }
        endpoint += "&type=regex"
        endpoint += "&limit=\(query.maxResults)"

        return try await APIClient.shared.request(endpoint: endpoint)
    }

    // MARK: - Local Search (Offline)

    func searchLocally(
        query: String,
        in content: String,
        chapterId: String,
        chapterTitle: String,
        chapterIndex: Int,
        bookId: String
    ) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []
        let lowercaseQuery = query.lowercased()
        let lowercaseContent = content.lowercased()

        var searchRange = lowercaseContent.startIndex..<lowercaseContent.endIndex

        while let range = lowercaseContent.range(of: lowercaseQuery, range: searchRange) {
            let matchStart = range.lowerBound
            let matchEnd = range.upperBound

            // Get context
            let contextStart = content.index(matchStart, offsetBy: -50, limitedBy: content.startIndex) ?? content.startIndex
            let contextEnd = content.index(matchEnd, offsetBy: 50, limitedBy: content.endIndex) ?? content.endIndex

            let contextBefore = String(content[contextStart..<matchStart])
            let matchedText = String(content[matchStart..<matchEnd])
            let contextAfter = String(content[matchEnd..<contextEnd])

            // Calculate position
            let offset = content.distance(from: content.startIndex, to: matchStart)
            let scrollPercentage = Double(offset) / Double(content.count)

            let result = SearchResult(
                id: UUID().uuidString,
                bookId: bookId,
                bookTitle: nil,
                chapterId: chapterId,
                chapterTitle: chapterTitle,
                chapterIndex: chapterIndex,
                matchedText: matchedText,
                contextBefore: contextBefore,
                contextAfter: contextAfter,
                position: SearchPosition(
                    paragraphIndex: 0,
                    characterOffset: offset,
                    length: matchedText.count,
                    scrollPercentage: scrollPercentage
                ),
                relevanceScore: nil,
                highlightRanges: [HighlightRange(start: 0, length: matchedText.count)]
            )

            results.append(result)

            // Move search range forward
            searchRange = matchEnd..<lowercaseContent.endIndex

            // Limit results
            if results.count >= 100 {
                break
            }
        }

        return results
    }

    // MARK: - Search Within Book (using cached content)

    func searchWithinBook(
        query: String,
        bookId: String,
        bookDetail: BookDetail,
        searchType: SearchType = .keyword
    ) async -> [SearchResult] {
        var allResults: [SearchResult] = []

        for (index, chapter) in bookDetail.chapters.enumerated() {
            // Try to get cached content
            if let content = try? await ContentCache.shared.loadChapterContent(
                bookId: bookId,
                chapterId: chapter.id
            ) {
                let results = searchLocally(
                    query: query,
                    in: content.htmlContent,
                    chapterId: chapter.id,
                    chapterTitle: content.title,
                    chapterIndex: index,
                    bookId: bookId
                )
                allResults.append(contentsOf: results)
            }
        }

        return allResults
    }

    // MARK: - Recent Searches

    private func addToRecentSearches(_ query: String) {
        // Remove if already exists
        recentSearches.removeAll { $0.query.lowercased() == query.lowercased() }

        // Add at the beginning
        recentSearches.insert(RecentSearch(query: query), at: 0)

        // Limit size
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }

        saveLocalData()
    }

    func removeRecentSearch(_ search: RecentSearch) {
        recentSearches.removeAll { $0.id == search.id }
        saveLocalData()
    }

    func clearRecentSearches() {
        recentSearches.removeAll()
        saveLocalData()
    }

    // MARK: - Search History

    private func addToHistory(query: SearchQuery, resultsCount: Int) {
        let item = SearchHistoryItem(
            query: query.query,
            searchType: query.searchType,
            bookId: query.bookId,
            resultsCount: resultsCount
        )

        searchHistory.insert(item, at: 0)

        if searchHistory.count > maxHistory {
            searchHistory = Array(searchHistory.prefix(maxHistory))
        }

        saveLocalData()
    }

    func clearHistory() {
        searchHistory.removeAll()
        saveLocalData()
    }

    // MARK: - Cancel Search

    func cancelSearch() {
        searchTask?.cancel()
        isSearching = false
    }

    // MARK: - Clear Results

    func clearResults() {
        searchResults = []
        totalMatches = 0
        searchTime = 0
        error = nil
    }
}
