import Foundation

@MainActor
class QuotesManager: ObservableObject {
    static let shared = QuotesManager()

    @Published var dailyQuote: Quote?
    @Published var trendingQuotes: [Quote] = []
    @Published var quotes: [Quote] = []
    @Published var favoriteQuotes: [Quote] = []
    @Published var availableTags: [String] = []
    @Published var availableAuthors: [String] = []
    @Published var isLoading = false
    @Published var error: String?

    private var currentPage = 1
    private var hasMorePages = true

    private init() {}

    // MARK: - Fetch Daily Quote

    func fetchDailyQuote() async {
        do {
            dailyQuote = try await APIClient.shared.request(
                endpoint: APIEndpoints.quotesDaily
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch Trending Quotes

    func fetchTrendingQuotes() async {
        do {
            let response: QuotesResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.quotesTrending
            )
            trendingQuotes = response.data
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch Quotes

    func fetchQuotes(
        page: Int = 1,
        limit: Int = 20,
        tag: String? = nil,
        author: String? = nil,
        search: String? = nil
    ) async {
        isLoading = true
        error = nil

        var endpoint = "\(APIEndpoints.quotes)?page=\(page)&limit=\(limit)"
        if let tag = tag {
            endpoint += "&tag=\(tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tag)"
        }
        if let author = author {
            endpoint += "&author=\(author.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? author)"
        }
        if let search = search, !search.isEmpty {
            endpoint += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        }

        do {
            let response: QuotesResponse = try await APIClient.shared.request(endpoint: endpoint)

            if page == 1 {
                quotes = response.data
            } else {
                quotes.append(contentsOf: response.data)
            }

            currentPage = page
            hasMorePages = page < response.totalPages
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Load More

    func loadMoreIfNeeded(currentItem: Quote) async {
        guard let lastItem = quotes.last,
              lastItem.id == currentItem.id,
              hasMorePages,
              !isLoading else {
            return
        }

        await fetchQuotes(page: currentPage + 1)
    }

    // MARK: - Fetch Favorites

    func fetchFavorites() async {
        isLoading = true
        error = nil

        do {
            let response: QuotesResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.quotesFavorites
            )
            favoriteQuotes = response.data
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Fetch Quotes by Book

    func fetchQuotes(forBookId bookId: String) async -> [Quote] {
        do {
            let response: QuotesResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.quotesBook(bookId)
            )
            return response.data
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    // MARK: - Fetch Quotes by Author

    func fetchQuotes(byAuthor author: String) async -> [Quote] {
        do {
            let endpoint = APIEndpoints.quotesAuthor(author.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? author)
            let response: QuotesResponse = try await APIClient.shared.request(endpoint: endpoint)
            return response.data
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    // MARK: - Fetch Tags

    func fetchTags() async {
        do {
            let response: QuoteTagsResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.quotesTags
            )
            availableTags = response.tags
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch Authors

    func fetchAuthors() async {
        do {
            let response: QuoteAuthorsResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.quotesAuthors
            )
            availableAuthors = response.authors
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Like Quote

    func likeQuote(id: String) async {
        do {
            let _: QuoteLikeResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.quoteLike(id),
                method: .post
            )

            // Update local state
            updateQuoteLikeStatus(id: id, isLiked: true)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Unlike Quote

    func unlikeQuote(id: String) async {
        do {
            let _: QuoteLikeResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.quoteLike(id),
                method: .delete
            )

            // Update local state
            updateQuoteLikeStatus(id: id, isLiked: false)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Toggle Like

    func toggleLike(quote: Quote) async {
        if quote.isLiked == true {
            await unlikeQuote(id: quote.id)
        } else {
            await likeQuote(id: quote.id)
        }
    }

    // MARK: - Get Random Quote

    func getRandomQuote() async -> Quote? {
        do {
            return try await APIClient.shared.request(
                endpoint: APIEndpoints.quotesRandom
            )
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    // MARK: - Private Helpers

    private func updateQuoteLikeStatus(id: String, isLiked: Bool) {
        // Update in quotes list
        if let index = quotes.firstIndex(where: { $0.id == id }) {
            var updated = quotes[index]
            updated = Quote(
                id: updated.id,
                text: updated.text,
                author: updated.author,
                source: updated.source,
                sourceType: updated.sourceType,
                bookId: updated.bookId,
                bookTitle: updated.bookTitle,
                chapterId: updated.chapterId,
                tags: updated.tags,
                likeCount: updated.likeCount + (isLiked ? 1 : -1),
                shareCount: updated.shareCount,
                isLiked: isLiked,
                createdAt: updated.createdAt,
                updatedAt: updated.updatedAt
            )
            quotes[index] = updated
        }

        // Update daily quote if it matches
        if dailyQuote?.id == id {
            if var updated = dailyQuote {
                dailyQuote = Quote(
                    id: updated.id,
                    text: updated.text,
                    author: updated.author,
                    source: updated.source,
                    sourceType: updated.sourceType,
                    bookId: updated.bookId,
                    bookTitle: updated.bookTitle,
                    chapterId: updated.chapterId,
                    tags: updated.tags,
                    likeCount: updated.likeCount + (isLiked ? 1 : -1),
                    shareCount: updated.shareCount,
                    isLiked: isLiked,
                    createdAt: updated.createdAt,
                    updatedAt: updated.updatedAt
                )
            }
        }

        // Update in trending
        if let index = trendingQuotes.firstIndex(where: { $0.id == id }) {
            var updated = trendingQuotes[index]
            trendingQuotes[index] = Quote(
                id: updated.id,
                text: updated.text,
                author: updated.author,
                source: updated.source,
                sourceType: updated.sourceType,
                bookId: updated.bookId,
                bookTitle: updated.bookTitle,
                chapterId: updated.chapterId,
                tags: updated.tags,
                likeCount: updated.likeCount + (isLiked ? 1 : -1),
                shareCount: updated.shareCount,
                isLiked: isLiked,
                createdAt: updated.createdAt,
                updatedAt: updated.updatedAt
            )
        }

        // Update favorites
        if isLiked {
            // Add to favorites if not already there
            if !favoriteQuotes.contains(where: { $0.id == id }),
               let quote = quotes.first(where: { $0.id == id }) ?? trendingQuotes.first(where: { $0.id == id }) ?? dailyQuote {
                favoriteQuotes.insert(quote, at: 0)
            }
        } else {
            // Remove from favorites
            favoriteQuotes.removeAll { $0.id == id }
        }
    }
}
