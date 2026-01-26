import Foundation
import Network

// MARK: - Search Response Models

struct SearchMatch: Codable, Identifiable {
    var id: String { "\(position)" }
    let position: Int
    let beforeContext: String
    let matchedText: String
    let afterContext: String
}

struct SearchResultItem: Codable, Identifiable {
    var id: String { chapterId }
    let chapterId: String
    let chapterTitle: String
    let chapterOrder: Int
    let matches: [SearchMatch]
    let matchCount: Int
}

struct BookSearchResponse: Codable {
    let bookId: String
    let query: String
    let totalMatches: Int
    let matchingChapters: Int
    let page: Int
    let limit: Int
    let totalPages: Int
    let results: [SearchResultItem]
}

// MARK: - Book Search Service

@MainActor
class BookSearchService: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResultItem] = []
    @Published var totalMatches: Int = 0
    @Published var matchingChapters: Int = 0
    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 0
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var isOfflineMode: Bool = false

    private let bookId: String
    private let contextLength: Int
    private let limit: Int
    private var cachedChapters: [(id: String, title: String, order: Int, content: String)] = []

    init(bookId: String, contextLength: Int = 50, limit: Int = 20) {
        self.bookId = bookId
        self.contextLength = contextLength
        self.limit = limit
    }

    func search() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }

        isLoading = true
        error = nil
        isOfflineMode = false

        // Try API search first
        do {
            let response = try await performAPISearch(query: query, page: 1)
            results = response.results
            totalMatches = response.totalMatches
            matchingChapters = response.matchingChapters
            currentPage = response.page
            totalPages = response.totalPages
        } catch {
            // Fall back to local search
            await performLocalSearch()
        }

        isLoading = false
    }

    func loadMore() async {
        guard currentPage < totalPages, !isLoading else { return }

        // Local search returns all results at once, no pagination
        if isOfflineMode { return }

        isLoading = true
        error = nil

        do {
            let response = try await performAPISearch(query: query, page: currentPage + 1)
            results.append(contentsOf: response.results)
            currentPage = response.page
        } catch {
            self.error = "Failed to load more: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func clearResults() {
        query = ""
        results = []
        totalMatches = 0
        matchingChapters = 0
        currentPage = 1
        totalPages = 0
        error = nil
        isOfflineMode = false
    }

    // MARK: - API Search

    private func performAPISearch(query: String, page: Int) async throws -> BookSearchResponse {
        let baseURLString = await APIClient.shared.baseURL
        guard let baseURL = URL(string: baseURLString) else {
            throw URLError(.badURL)
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("books/\(bookId)/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "contextLength", value: "\(contextLength)")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token if available
        if let token = AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(BookSearchResponse.self, from: data)
    }

    // MARK: - Local Search (Offline Fallback)

    private func performLocalSearch() async {
        isOfflineMode = true

        // Load cached chapters if not already loaded
        if cachedChapters.isEmpty {
            await loadCachedChapters()
        }

        guard !cachedChapters.isEmpty else {
            error = "No cached content available for offline search"
            results = []
            return
        }

        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var allResults: [SearchResultItem] = []
        var totalMatchCount = 0

        for chapter in cachedChapters {
            let matches = searchInContent(
                content: chapter.content,
                query: searchQuery,
                contextLength: contextLength
            )

            if !matches.isEmpty {
                let resultItem = SearchResultItem(
                    chapterId: chapter.id,
                    chapterTitle: chapter.title,
                    chapterOrder: chapter.order,
                    matches: matches,
                    matchCount: matches.count
                )
                allResults.append(resultItem)
                totalMatchCount += matches.count
            }
        }

        results = allResults
        totalMatches = totalMatchCount
        matchingChapters = allResults.count
        currentPage = 1
        totalPages = 1
        error = nil
    }

    private func loadCachedChapters() async {
        // Get all cached chapter content for this book
        guard let downloadedBook = OfflineManager.shared.getDownloadedBook(bookId) else {
            return
        }

        var chapters: [(id: String, title: String, order: Int, content: String)] = []

        // Load chapter metadata from ContentCache
        for order in 0..<downloadedBook.totalChapters {
            // Try to get chapter content from cache
            if let content = await OfflineManager.shared.getOfflineChapterContent(
                bookId: bookId,
                chapterId: "\(order)"  // This might need adjustment based on actual chapter ID format
            ) {
                chapters.append((
                    id: content.id,
                    title: content.title,
                    order: order,
                    content: stripHTML(content.htmlContent)
                ))
            }
        }

        // If no chapters found by order, try to get all available chapters
        if chapters.isEmpty {
            let allChapterIds = await getAllCachedChapterIds()
            for (index, chapterId) in allChapterIds.enumerated() {
                if let content = await OfflineManager.shared.getOfflineChapterContent(
                    bookId: bookId,
                    chapterId: chapterId
                ) {
                    chapters.append((
                        id: content.id,
                        title: content.title,
                        order: index,
                        content: stripHTML(content.htmlContent)
                    ))
                }
            }
        }

        cachedChapters = chapters.sorted { $0.order < $1.order }
    }

    private func getAllCachedChapterIds() async -> [String] {
        // Get list of cached chapter IDs from ContentCache
        // This is a simplified implementation - adjust based on actual ContentCache API
        var chapterIds: [String] = []

        // Check common chapter ID formats
        for i in 0..<200 {  // Reasonable limit for chapter count
            let chapterId = "\(i)"
            if await OfflineManager.shared.isChapterAvailableOffline(bookId: bookId, chapterId: chapterId) {
                chapterIds.append(chapterId)
            }
        }

        return chapterIds
    }

    private func searchInContent(content: String, query: String, contextLength: Int) -> [SearchMatch] {
        var matches: [SearchMatch] = []
        let lowercaseContent = content.lowercased()

        var searchIndex = lowercaseContent.startIndex

        while searchIndex < lowercaseContent.endIndex {
            guard let range = lowercaseContent.range(of: query, range: searchIndex..<lowercaseContent.endIndex) else {
                break
            }

            let matchStart = range.lowerBound
            let matchEnd = range.upperBound

            // Get before context
            let beforeStart = content.index(matchStart, offsetBy: -contextLength, limitedBy: content.startIndex) ?? content.startIndex
            let beforeContext = String(content[beforeStart..<matchStart])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Get matched text (preserve original case)
            let matchedText = String(content[matchStart..<matchEnd])

            // Get after context
            let afterEnd = content.index(matchEnd, offsetBy: contextLength, limitedBy: content.endIndex) ?? content.endIndex
            let afterContext = String(content[matchEnd..<afterEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Calculate position (character offset)
            let position = content.distance(from: content.startIndex, to: matchStart)

            let match = SearchMatch(
                position: position,
                beforeContext: beforeContext,
                matchedText: matchedText,
                afterContext: afterContext
            )
            matches.append(match)

            // Move search index forward
            searchIndex = matchEnd

            // Limit matches per chapter
            if matches.count >= 50 {
                break
            }
        }

        return matches
    }

    private func stripHTML(_ html: String) -> String {
        // Remove HTML tags for text search
        var result = html

        // Remove script and style tags with content
        result = result.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )

        // Remove HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        // Decode HTML entities
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")

        // Normalize whitespace
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
