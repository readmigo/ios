import Foundation

@MainActor
class LibraryManager: ObservableObject {
    static let shared = LibraryManager()

    @Published var userBooks: [UserBook] = []
    @Published var recommendedBooks: [Book] = []
    @Published var allBooks: [Book] = []
    @Published var isLoading = false
    @Published var error: String?

    /// Data source indicator for offline support
    @Published var dataSource: DataSourceType = .network
    @Published var lastSyncTime: Date?

    /// Whether initial data has been loaded from cache
    @Published private(set) var hasLoadedFromCache = false

    enum DataSourceType {
        case network
        case cache
    }

    private let cacheService = ResponseCacheService.shared

    private init() {
        LoggingService.shared.info(.books, "LibraryManager initialized", component: "LibraryManager")
        // Load from persistent cache on init
        Task {
            await loadFromCache()
        }
    }

    // MARK: - Cache First Loading

    /// Load data from persistent cache for instant startup
    private func loadFromCache() async {
        guard !hasLoadedFromCache else { return }

        LoggingService.shared.debug(.books, "Loading library from cache", component: "LibraryManager")

        // Load cached user library
        if let cachedLibrary: UserLibraryResponse = await cacheService.get(CacheKeys.userLibraryKey(), type: UserLibraryResponse.self) {
            self.userBooks = cachedLibrary.books
            self.dataSource = .cache
            LoggingService.shared.info(.books, "Loaded \(cachedLibrary.books.count) user books from cache", component: "LibraryManager")
        }

        // Load cached recommendations
        if let cachedRecommendations: RecommendationsResponse = await cacheService.get(CacheKeys.recommendationsKey(), type: RecommendationsResponse.self) {
            self.recommendedBooks = cachedRecommendations.books
            LoggingService.shared.info(.books, "Loaded \(cachedRecommendations.books.count) recommendations from cache", component: "LibraryManager")
        }

        // Load cached all books
        let cacheKey = CacheKeys.booksListKey(page: 1, limit: 50)
        if let cachedBooks: BooksListResponse = await cacheService.get(cacheKey, type: BooksListResponse.self) {
            self.allBooks = cachedBooks.items
            self.currentPage = cachedBooks.page
            self.totalBooks = cachedBooks.total
            self.hasMoreBooks = self.allBooks.count < cachedBooks.total
            LoggingService.shared.info(.books, "Loaded \(cachedBooks.items.count) all books from cache", component: "LibraryManager")
        }

        hasLoadedFromCache = true
    }

    // MARK: - Fetch User Library

    func fetchUserLibrary() async {
        LoggingService.shared.debug(.books, "Fetching user library", component: "LibraryManager")
        isLoading = true
        error = nil

        do {
            let response: UserLibraryResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.readingLibrary
            )
            self.userBooks = response.books
            self.dataSource = .network
            self.lastSyncTime = Date()

            // Cache the response for persistence
            await cacheService.set(response, for: CacheKeys.userLibraryKey(), ttl: .userLibrary)

            LoggingService.shared.info(.books, "User library loaded: \(response.books.count) books", component: "LibraryManager")
        } catch {
            // Only show error if we don't have cached data
            if userBooks.isEmpty {
                self.error = error.localizedDescription
            }
            LoggingService.shared.error(.books, "Failed to fetch user library: \(error.localizedDescription)", component: "LibraryManager")
        }

        isLoading = false
    }

    // MARK: - Fetch All Books

    @Published var currentPage = 1
    @Published var totalBooks = 0
    @Published var hasMoreBooks = true
    private let booksPerPage = 50

    func fetchAllBooks(page: Int = 1, limit: Int = 50) async {
        LoggingService.shared.debug(.books, "Fetching all books page=\(page), limit=\(limit)", component: "LibraryManager")
        isLoading = true
        error = nil

        let cacheKey = CacheKeys.booksListKey(page: page, limit: limit)

        do {
            let response: BooksListResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.books)?page=\(page)&limit=\(limit)"
            )
            if page == 1 {
                self.allBooks = response.items
            } else {
                self.allBooks.append(contentsOf: response.items)
            }
            self.currentPage = response.page
            self.totalBooks = response.total
            self.hasMoreBooks = self.allBooks.count < response.total

            // Cache the response
            await cacheService.set(response, for: cacheKey, ttl: .bookList)
            dataSource = .network
            lastSyncTime = Date()

            LoggingService.shared.info(.books, "Fetched \(response.items.count) books, page \(page), total: \(response.total)", component: "LibraryManager")
        } catch {
            // Try to load from cache on network failure
            if let cachedResponse: BooksListResponse = await cacheService.get(cacheKey, type: BooksListResponse.self) {
                if page == 1 {
                    self.allBooks = cachedResponse.items
                } else {
                    self.allBooks.append(contentsOf: cachedResponse.items)
                }
                self.currentPage = cachedResponse.page
                self.totalBooks = cachedResponse.total
                self.hasMoreBooks = self.allBooks.count < cachedResponse.total

                if let cachedAt = await cacheService.getCachedResponse(cacheKey)?.timestamp {
                    lastSyncTime = cachedAt
                }
                dataSource = .cache
                self.error = nil

                LoggingService.shared.info(.books, "Loaded \(cachedResponse.items.count) books from cache, page \(page)", component: "LibraryManager")
            } else {
                self.error = error.localizedDescription
                self.hasMoreBooks = false  // Stop retrying on error
                LoggingService.shared.error(.books, "Failed to fetch books page \(page): \(error.localizedDescription)", component: "LibraryManager")
            }
        }

        isLoading = false
    }

    func loadMoreBooks() async {
        guard !isLoading && hasMoreBooks else { return }
        LoggingService.shared.debug(.books, "Loading more books, next page: \(currentPage + 1)", component: "LibraryManager")
        await fetchAllBooks(page: currentPage + 1, limit: booksPerPage)
    }

    // MARK: - Fetch Recommendations

    func fetchRecommendations() async {
        LoggingService.shared.debug(.books, "Fetching book recommendations", component: "LibraryManager")

        let cacheKey = CacheKeys.recommendationsKey()

        do {
            let response: RecommendationsResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.recommendations
            )
            self.recommendedBooks = response.books

            // Cache the response for persistence
            await cacheService.set(response, for: cacheKey, ttl: .recommendations)

            LoggingService.shared.info(.books, "Recommendations loaded: \(response.books.count) books", component: "LibraryManager")
        } catch {
            // Only show error if we don't have cached data
            if recommendedBooks.isEmpty {
                if let cachedResponse: RecommendationsResponse = await cacheService.get(cacheKey, type: RecommendationsResponse.self) {
                    self.recommendedBooks = cachedResponse.books
                    LoggingService.shared.info(.books, "Loaded \(cachedResponse.books.count) recommendations from cache", component: "LibraryManager")
                } else {
                    LoggingService.shared.error(.books, "Failed to fetch recommendations: \(error.localizedDescription)", component: "LibraryManager")
                }
            }
        }
    }

    // MARK: - Add Book to Library

    func addToLibrary(bookId: String, status: BookStatus? = nil) async throws {
        LoggingService.shared.info(.books, "Adding book to library: \(bookId), status: \(status?.rawValue ?? "default")", component: "LibraryManager")
        let body = AddToLibraryRequest(bookId: bookId, status: status?.rawValue)
        let _: UserBook = try await APIClient.shared.request(
            endpoint: APIEndpoints.addToLibrary,
            method: .post,
            body: body
        )
        LoggingService.shared.debug(.books, "Book added to library successfully", component: "LibraryManager")
        await fetchUserLibrary()
    }

    // MARK: - Update Book Status

    func updateBookStatus(bookId: String, status: BookStatus) async throws {
        LoggingService.shared.info(.books, "Updating book status: \(bookId) to \(status.rawValue)", component: "LibraryManager")
        let body = UpdateBookStatusRequest(status: status.rawValue)
        let _: UserBook = try await APIClient.shared.request(
            endpoint: APIEndpoints.updateBookStatus(bookId),
            method: .patch,
            body: body
        )
        LoggingService.shared.debug(.books, "Book status updated successfully", component: "LibraryManager")
        await fetchUserLibrary()
    }

    // MARK: - Remove from Library

    func removeFromLibrary(bookId: String) async throws {
        LoggingService.shared.info(.books, "Removing book from library: \(bookId)", component: "LibraryManager")
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.removeFromLibrary(bookId),
            method: .delete
        )
        userBooks.removeAll { $0.book.id == bookId }
        LoggingService.shared.debug(.books, "Book removed from library successfully", component: "LibraryManager")
    }

    // MARK: - Get Book by ID

    func getBook(id: String) -> Book? {
        if let userBook = userBooks.first(where: { $0.book.id == id }) {
            return userBook.book
        }
        return allBooks.first { $0.id == id } ?? recommendedBooks.first { $0.id == id }
    }

    // MARK: - Get User Book by ID

    func getUserBook(id: String) -> UserBook? {
        userBooks.first { $0.book.id == id }
    }

    // MARK: - Filter Books

    func filterBooks(by difficulty: ClosedRange<Double>? = nil, genre: String? = nil) -> [Book] {
        var filtered = allBooks

        if let difficulty = difficulty {
            filtered = filtered.filter { book in
                guard let score = book.difficultyScore else { return false }
                return difficulty.contains(score)
            }
        }

        if let genre = genre {
            filtered = filtered.filter { ($0.genres ?? []).contains(genre) }
        }

        return filtered
    }

    // MARK: - Search Books

    func searchBooks(query: String) async -> [Book] {
        guard !query.isEmpty else { return allBooks }

        LoggingService.shared.debug(.books, "Searching books with query: '\(query)'", component: "LibraryManager")
        do {
            let response: BooksListResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.books)?search=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
            )
            LoggingService.shared.info(.books, "Search completed: \(response.books.count) results for '\(query)'", component: "LibraryManager")
            return response.books
        } catch {
            LoggingService.shared.error(.books, "Search failed for '\(query)': \(error.localizedDescription)", component: "LibraryManager")
            return []
        }
    }

}

// MARK: - Response Models

struct UserLibraryResponse: Codable {
    let books: [UserBook]
}

struct BooksListResponse: Codable {
    let items: [Book]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int

    // Provide convenience access using 'books' name
    var books: [Book] { items }
}

struct RecommendationsResponse: Codable {
    let forYou: [Book]
    let popular: [Book]
    let newArrivals: [Book]

    // Convenience accessor - combines forYou recommendations
    var books: [Book] { forYou }
}


