import Foundation

/// Manager for audiobook list and browsing functionality
@MainActor
class AudiobookManager: ObservableObject {
    static let shared = AudiobookManager()

    // MARK: - Published Properties

    @Published var audiobooks: [AudiobookListItem] = []
    @Published var recentlyListened: [AudiobookWithProgress] = []
    @Published var popularAudiobooks: [AudiobookListItem] = []
    @Published var currentPage = 1
    @Published var totalAudiobooks = 0
    @Published var hasMoreAudiobooks = true

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?

    // Feature availability
    @Published var featureNotAvailable = false
    @Published var requiredVersion: String?

    // Available languages for filtering
    @Published var availableLanguages: [String] = []

    // Data source for offline support
    @Published var dataSource: DataSourceType = .network
    @Published var lastSyncTime: Date?

    enum DataSourceType {
        case network
        case cache
    }

    private let cacheService = ResponseCacheService.shared
    private let audiobooksPerPage = 20

    private init() {}

    // MARK: - Fetch Audiobooks

    /// Fetch list of audiobooks with pagination
    func fetchAudiobooks(page: Int = 1, language: String? = nil, search: String? = nil) async {
        if page == 1 {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        error = nil

        var endpoint = "\(APIEndpoints.audiobooks)?page=\(page)&limit=\(audiobooksPerPage)"
        if let language = language, !language.isEmpty {
            endpoint += "&language=\(language)"
        }
        if let search = search, !search.isEmpty {
            endpoint += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        }

        let cacheKey = CacheKeys.audiobooksListKey(page: page, language: language)

        do {
            let response: PaginatedAudiobooks = try await APIClient.shared.request(endpoint: endpoint)

            if page == 1 {
                audiobooks = response.items
            } else {
                audiobooks.append(contentsOf: response.items)
            }
            currentPage = response.page
            totalAudiobooks = response.total
            hasMoreAudiobooks = audiobooks.count < response.total

            // Cache the response
            await cacheService.set(response, for: cacheKey, ttl: .bookList)
            dataSource = .network
            lastSyncTime = Date()
            featureNotAvailable = false
            requiredVersion = nil

            LoggingService.shared.info(.books, "Fetched \(response.items.count) audiobooks, page \(page)")
        } catch let apiError as APIError {
            // Handle feature not available error specifically
            if case .featureNotAvailable(_, let minVersion, _) = apiError {
                featureNotAvailable = true
                requiredVersion = minVersion
                hasMoreAudiobooks = false
                self.error = apiError.localizedDescription
                LoggingService.shared.warning(.books, "Audiobooks feature not available: \(apiError.localizedDescription)")
            } else {
                await handleFetchError(error: apiError, cacheKey: cacheKey, page: page)
            }
        } catch {
            await handleFetchError(error: error, cacheKey: cacheKey, page: page)
        }

        isLoading = false
        isLoadingMore = false
    }

    /// Load more audiobooks (pagination)
    func loadMoreAudiobooks(language: String? = nil) async {
        guard !isLoading && !isLoadingMore && hasMoreAudiobooks else { return }
        await fetchAudiobooks(page: currentPage + 1, language: language)
    }

    // MARK: - Recently Listened

    /// Fetch user's recently listened audiobooks
    /// Note: Backend returns AudiobookListItem[] for recently-listened, we convert to AudiobookWithProgress
    func fetchRecentlyListened(limit: Int = 10) async {
        let cacheKey = CacheKeys.audiobooksRecentlyListenedKey()

        do {
            // Backend returns array of AudiobookListItem directly (no wrapper)
            let items: [AudiobookListItem] = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.audiobooksRecentlyListened)?limit=\(limit)"
            )
            // Convert to AudiobookWithProgress (without actual progress data)
            recentlyListened = items.map { item in
                AudiobookWithProgress(
                    id: item.id,
                    title: item.title,
                    author: item.author,
                    narrator: item.narrator,
                    description: nil,
                    coverUrl: item.coverUrl,
                    totalDuration: item.totalDuration,
                    bookId: item.bookId,
                    source: "LIBRIVOX",
                    language: item.language,
                    genres: [],
                    status: "ACTIVE",
                    chapters: [],
                    progress: nil
                )
            }

            // Cache the response
            await cacheService.set(items, for: cacheKey, ttl: .userLibrary)
            LoggingService.shared.info(.books, "Fetched \(items.count) recently listened audiobooks")
        } catch {
            // Try cache on network failure
            if let cached: [AudiobookListItem] = await cacheService.get(cacheKey, type: [AudiobookListItem].self) {
                recentlyListened = cached.map { item in
                    AudiobookWithProgress(
                        id: item.id,
                        title: item.title,
                        author: item.author,
                        narrator: item.narrator,
                        description: nil,
                        coverUrl: item.coverUrl,
                        totalDuration: item.totalDuration,
                        bookId: item.bookId,
                        source: "LIBRIVOX",
                        language: item.language,
                        genres: [],
                        status: "ACTIVE",
                        chapters: [],
                        progress: nil
                    )
                }
                LoggingService.shared.info(.books, "Loaded recently listened from cache")
            } else {
                LoggingService.shared.error(.books, "Failed to fetch recently listened: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Popular Audiobooks

    /// Fetch popular audiobooks sorted by download count
    func fetchPopularAudiobooks(limit: Int = 10, language: String? = nil) async {
        let cacheKey = "audiobooks_popular_\(language ?? "all")_\(limit)"

        do {
            var endpoint = "\(APIEndpoints.audiobooksPopular)?limit=\(limit)"
            if let language = language, !language.isEmpty {
                endpoint += "&language=\(language)"
            }

            let items: [AudiobookListItem] = try await APIClient.shared.request(endpoint: endpoint)
            popularAudiobooks = items

            // Cache the response
            await cacheService.set(items, for: cacheKey, ttl: .bookList)
            LoggingService.shared.info(.books, "Fetched \(items.count) popular audiobooks")
        } catch {
            // Try cache on network failure
            if let cached: [AudiobookListItem] = await cacheService.get(cacheKey, type: [AudiobookListItem].self) {
                popularAudiobooks = cached
                LoggingService.shared.info(.books, "Loaded popular audiobooks from cache")
            } else {
                LoggingService.shared.error(.books, "Failed to fetch popular audiobooks: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Available Languages

    /// Fetch available audiobook languages
    func fetchAvailableLanguages() async {
        do {
            // Backend returns array of strings directly (no wrapper)
            let languages: [String] = try await APIClient.shared.request(
                endpoint: APIEndpoints.audiobooksLanguages
            )
            availableLanguages = languages
            LoggingService.shared.info(.books, "Fetched \(languages.count) available languages")
        } catch {
            LoggingService.shared.error(.books, "Failed to fetch languages: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch Single Audiobook

    /// Fetch audiobook by ID
    func fetchAudiobook(_ audiobookId: String) async -> Audiobook? {
        do {
            // Backend returns Audiobook directly (no wrapper)
            let audiobook: Audiobook = try await APIClient.shared.request(
                endpoint: APIEndpoints.audiobook(audiobookId)
            )
            return audiobook
        } catch {
            LoggingService.shared.error(.books, "Failed to fetch audiobook \(audiobookId): \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetch audiobook with progress
    func fetchAudiobookWithProgress(_ audiobookId: String) async -> AudiobookWithProgress? {
        do {
            // Backend returns AudiobookWithProgress directly (no wrapper)
            let audiobook: AudiobookWithProgress = try await APIClient.shared.request(
                endpoint: APIEndpoints.audiobookWithProgress(audiobookId)
            )
            return audiobook
        } catch {
            LoggingService.shared.error(.books, "Failed to fetch audiobook with progress: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Reset

    /// Reset state for refresh
    func reset() {
        audiobooks = []
        currentPage = 1
        totalAudiobooks = 0
        hasMoreAudiobooks = true
        error = nil
        featureNotAvailable = false
        requiredVersion = nil
    }

    // MARK: - Private Helpers

    /// Handle fetch errors with cache fallback
    private func handleFetchError(error: Error, cacheKey: String, page: Int) async {
        // Try cache on network failure
        if let cached: PaginatedAudiobooks = await cacheService.get(cacheKey, type: PaginatedAudiobooks.self) {
            if page == 1 {
                audiobooks = cached.items
            } else {
                audiobooks.append(contentsOf: cached.items)
            }
            currentPage = cached.page
            totalAudiobooks = cached.total
            hasMoreAudiobooks = audiobooks.count < cached.total

            if let cachedAt = await cacheService.getCachedResponse(cacheKey)?.timestamp {
                lastSyncTime = cachedAt
            }
            dataSource = .cache
            self.error = nil
            LoggingService.shared.info(.books, "Loaded audiobooks from cache, page \(page)")
        } else {
            self.error = error.localizedDescription
            hasMoreAudiobooks = false
            LoggingService.shared.error(.books, "Failed to fetch audiobooks: \(error.localizedDescription)")
        }
    }
}

// MARK: - Response Models
// Note: Backend returns data directly without wrapper objects

// MARK: - Cache Keys Extension

extension ResponseCacheService {
    static func audiobooksListKey(page: Int, language: String? = nil) -> String {
        if let language = language {
            return "audiobooks_list_\(language)_\(page)"
        }
        return "audiobooks_list_\(page)"
    }

    static func audiobooksRecentlyListenedKey() -> String {
        "audiobooks_recently_listened"
    }
}
