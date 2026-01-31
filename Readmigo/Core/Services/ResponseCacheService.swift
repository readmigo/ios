import Foundation
import os.log

private let cacheLog = OSLog(subsystem: "com.readmigo.app", category: "Cache")

/// Unified log format helper for Cache module
/// Format: [Readmigo][Cache][LEVEL] emoji message
private func cacheLogMessage(_ level: String, _ emoji: String, _ message: String) -> String {
    return "[Readmigo][Cache][\(level)] \(emoji) \(message)"
}

/// Service for caching API responses with TTL-based expiration
/// Provides memory caching for fast access to frequently used data
/// Supports persistent cache for critical data that survives app restarts
actor ResponseCacheService {
    static let shared = ResponseCacheService()

    // MARK: - Types

    struct CachedResponse: Codable {
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }

        var remainingTTL: TimeInterval {
            max(0, ttl - Date().timeIntervalSince(timestamp))
        }
    }

    /// Keys that should be persisted to disk for instant app startup
    /// Note: Uses prefix matching, so "bookstore_books_category_" matches "bookstore_books_category_123"
    private static let persistentKeys: Set<String> = [
        // 书城 (Bookstore) tab
        "bookstore_tabs",
        "bookstore_books_recommendation",
        "bookstore_books_category_",
        // 书架 (Library) tab
        "user_library",
        "recommendations",
        "books_list_1_50",  // First page of all books (page 1, limit 50)
        // 城邦 (Agora) tab
        "agora_posts_1"     // First page of agora posts
    ]

    /// Directory for persistent cache
    private var persistentCacheURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("ResponseCache", isDirectory: true)
    }

    /// TTL Configuration by endpoint type
    enum CacheTTL {
        case bookList           // 15 minutes
        case bookDetail         // 1 hour
        case categories         // 24 hours
        case recommendations    // 1 hour
        case userLibrary        // 5 minutes
        case author             // 1 hour
        case search             // 5 minutes

        var seconds: TimeInterval {
            switch self {
            case .bookList: return 900
            case .bookDetail: return 3600
            case .categories: return 86400
            case .recommendations: return 3600
            case .userLibrary: return 300
            case .author: return 3600
            case .search: return 300
            }
        }
    }

    // MARK: - Properties

    private var cache: [String: CachedResponse] = [:]
    private let maxCacheSize = 100 // Maximum number of cached responses

    /// Flag to track if persistent cache has been loaded
    private var hasLoadedPersistentCache = false

    private init() {
        os_log(.info, log: cacheLog, "%{public}@", cacheLogMessage("INFO", "ℹ️", "ResponseCacheService initialized"))
    }

    /// Ensure persistent cache is loaded (call this before accessing cache)
    private func ensurePersistentCacheLoaded() {
        guard !hasLoadedPersistentCache else { return }
        hasLoadedPersistentCache = true
        os_log(.info, log: cacheLog, "%{public}@", cacheLogMessage("INFO", "ℹ️", "Loading persistent cache from disk..."))

        // Create persistent cache directory if needed
        try? FileManager.default.createDirectory(at: persistentCacheURL, withIntermediateDirectories: true)
        // Load persistent cache
        loadPersistentCacheSync()
    }

    /// Synchronous version of loadPersistentCache for use within actor
    private func loadPersistentCacheSync() {
        guard FileManager.default.fileExists(atPath: persistentCacheURL.path) else {
            os_log(.info, log: cacheLog, "%{public}@", cacheLogMessage("INFO", "ℹ️", "Persistent cache directory does not exist yet"))
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: persistentCacheURL, includingPropertiesForKeys: nil)
            var loadedCount = 0
            for file in files where file.pathExtension == "cache" {
                // Use filename as-is (without extension) as the cache key
                // Note: fileURL(for:) replaces "/" with "_" when saving, but our keys use "_" natively
                let key = file.deletingPathExtension().lastPathComponent
                if let cached = loadFromDisk(key) {
                    cache[key] = cached
                    loadedCount += 1
                }
            }
            os_log(.info, log: cacheLog, "%{public}@", cacheLogMessage("INFO", "✅", "Loaded \(loadedCount) cache entries from disk"))
        } catch {
            os_log(.error, log: cacheLog, "%{public}@", cacheLogMessage("ERROR", "❌", "Failed to load persistent cache: \(error.localizedDescription)"))
        }
    }

    // MARK: - Persistent Cache Methods

    /// Check if a key should be persisted
    private func shouldPersist(_ key: String) -> Bool {
        for persistentKey in Self.persistentKeys {
            if key == persistentKey || key.hasPrefix(persistentKey) {
                return true
            }
        }
        return false
    }

    /// File URL for a cache key
    private func fileURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
        return persistentCacheURL.appendingPathComponent("\(safeKey).cache")
    }

    /// Save a cached response to disk (synchronous for reliability)
    private func saveToDisk(_ cached: CachedResponse, for key: String) {
        guard shouldPersist(key) else { return }

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: persistentCacheURL, withIntermediateDirectories: true)

        let url = fileURL(for: key)
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cached)
            try data.write(to: url, options: .atomic)
            os_log(.info, log: cacheLog, "%{public}@", cacheLogMessage("INFO", "✅", "Saved to disk: \(key), \(data.count) bytes"))
        } catch {
            os_log(.error, log: cacheLog, "%{public}@", cacheLogMessage("ERROR", "❌", "Failed to save: \(key), \(error.localizedDescription)"))
        }
    }

    /// Load a cached response from disk
    private func loadFromDisk(_ key: String) -> CachedResponse? {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let cached = try decoder.decode(CachedResponse.self, from: data)
            // Check if expired
            if cached.isExpired {
                os_log(.debug, log: cacheLog, "%{public}@", cacheLogMessage("DEBUG", "⏰", "Cache expired: \(key)"))
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            os_log(.debug, log: cacheLog, "%{public}@", cacheLogMessage("DEBUG", "✅", "Loaded from disk: \(key), TTL: \(Int(cached.remainingTTL))s"))
            return cached
        } catch {
            os_log(.error, log: cacheLog, "%{public}@", cacheLogMessage("ERROR", "❌", "Failed to decode: \(key)"))
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    // MARK: - Public Methods

    /// Get cached value for a key
    func get<T: Decodable>(_ key: String, type: T.Type) -> T? {
        // Ensure persistent cache is loaded on first access
        ensurePersistentCacheLoaded()

        guard let cached = cache[key], !cached.isExpired else {
            os_log(.debug, log: cacheLog, "%{public}@", cacheLogMessage("DEBUG", "🔍", "Cache miss: \(key)"))
            // Remove expired entry
            cache.removeValue(forKey: key)
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let result = try decoder.decode(T.self, from: cached.data)
            os_log(.debug, log: cacheLog, "%{public}@", cacheLogMessage("DEBUG", "✅", "Cache hit: \(key)"))
            return result
        } catch {
            os_log(.error, log: cacheLog, "%{public}@", cacheLogMessage("ERROR", "❌", "Decode failed: \(key)"))
            cache.removeValue(forKey: key)
            return nil
        }
    }

    /// Set cached value for a key with TTL
    func set<T: Encodable>(_ value: T, for key: String, ttl: CacheTTL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)

            let cached = CachedResponse(
                data: data,
                timestamp: Date(),
                ttl: ttl.seconds
            )

            cache[key] = cached

            // Save to disk for persistent keys
            saveToDisk(cached, for: key)

            // Cleanup if cache is too large
            if cache.count > maxCacheSize {
                cleanupOldestEntries()
            }

            os_log(.debug, log: cacheLog, "%{public}@", cacheLogMessage("DEBUG", "💾", "Cached: \(key), TTL: \(Int(ttl.seconds))s"))
        } catch {
            os_log(.default, log: cacheLog, "%{public}@", cacheLogMessage("WARNING", "⚠️", "Failed to encode: \(key)"))
        }
    }

    /// Invalidate a specific cache entry
    func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
        os_log(.debug, log: cacheLog, "%{public}@", cacheLogMessage("DEBUG", "🗑️", "Invalidated: \(key)"))
    }

    /// Invalidate all cache entries matching a prefix
    func invalidatePrefix(_ prefix: String) {
        let keysToRemove = cache.keys.filter { $0.hasPrefix(prefix) }
        keysToRemove.forEach { cache.removeValue(forKey: $0) }
        os_log(.debug, log: cacheLog, "%{public}@", cacheLogMessage("DEBUG", "🗑️", "Invalidated \(keysToRemove.count) entries with prefix: \(prefix)"))
    }

    /// Invalidate all cache entries (memory and disk)
    func invalidateAll() {
        cache.removeAll()
        clearPersistentCache()
        os_log(.info, log: cacheLog, "%{public}@", cacheLogMessage("INFO", "🗑️", "Invalidated all cached responses (memory + disk)"))
    }

    /// Clear all persistent cache files from disk
    private func clearPersistentCache() {
        guard FileManager.default.fileExists(atPath: persistentCacheURL.path) else { return }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: persistentCacheURL, includingPropertiesForKeys: nil)
            var deletedCount = 0
            for file in files where file.pathExtension == "cache" {
                try FileManager.default.removeItem(at: file)
                deletedCount += 1
            }
            os_log(.info, log: cacheLog, "%{public}@", cacheLogMessage("INFO", "🗑️", "Cleared \(deletedCount) persistent cache files from disk"))
        } catch {
            os_log(.error, log: cacheLog, "%{public}@", cacheLogMessage("ERROR", "❌", "Failed to clear persistent cache: \(error.localizedDescription)"))
        }
    }

    /// Get cache statistics
    func getStats() -> (count: Int, totalSize: Int, expiredCount: Int) {
        var totalSize = 0
        var expiredCount = 0

        for (_, cached) in cache {
            totalSize += cached.data.count
            if cached.isExpired {
                expiredCount += 1
            }
        }

        return (cache.count, totalSize, expiredCount)
    }

    /// Remove all expired entries
    func cleanupExpired() {
        let expiredKeys = cache.filter { $0.value.isExpired }.map { $0.key }
        expiredKeys.forEach { cache.removeValue(forKey: $0) }

        if !expiredKeys.isEmpty {
            os_log(.debug, log: cacheLog, "%{public}@", cacheLogMessage("DEBUG", "🧹", "Cleaned up \(expiredKeys.count) expired entries"))
        }
    }

    // MARK: - Private Methods

    private func cleanupOldestEntries() {
        // Sort by timestamp and remove oldest 20%
        let sortedKeys = cache.sorted { $0.value.timestamp < $1.value.timestamp }
        let removeCount = max(1, cache.count / 5)

        for i in 0..<removeCount {
            cache.removeValue(forKey: sortedKeys[i].key)
        }

        os_log(.debug, log: cacheLog, "%{public}@", cacheLogMessage("DEBUG", "🧹", "Cleaned up \(removeCount) oldest entries"))
    }
}

// MARK: - Cache Key Helpers

/// Type alias for convenient access to cache keys
typealias CacheKeys = ResponseCacheService

extension ResponseCacheService {
    /// Generate cache key for books list
    static func booksListKey(page: Int, limit: Int, search: String? = nil) -> String {
        if let search = search {
            return "books_list_search_\(search)_\(page)_\(limit)"
        }
        return "books_list_\(page)_\(limit)"
    }

    /// Generate cache key for book detail
    static func bookDetailKey(_ bookId: String) -> String {
        "book_detail_\(bookId)"
    }

    /// Generate cache key for categories
    static func categoriesKey() -> String {
        "categories"
    }

    /// Generate cache key for category books
    static func categoryBooksKey(_ categoryId: String) -> String {
        "category_books_\(categoryId)"
    }

    /// Generate cache key for recommendations
    static func recommendationsKey() -> String {
        "recommendations"
    }

    /// Generate cache key for user library
    static func userLibraryKey() -> String {
        "user_library"
    }

    /// Generate cache key for author
    static func authorKey(_ authorId: String) -> String {
        "author_\(authorId)"
    }

    /// Generate cache key for author books
    static func authorBooksKey(_ authorName: String) -> String {
        "author_books_\(authorName.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }

    /// Generate cache key for book lists
    static func bookListsKey() -> String {
        "book_lists"
    }

    /// Generate cache key for book list detail
    static func bookListDetailKey(_ listId: String) -> String {
        "book_list_detail_\(listId)"
    }

    /// Generate cache key for agora posts
    static func agoraPostsKey(page: Int) -> String {
        "agora_posts_\(page)"
    }

    /// Generate cache key for popular searches
    static func popularSearchesKey() -> String {
        "popular_searches"
    }

    /// Generate cache key for search suggestions
    static func searchSuggestionsKey(_ query: String) -> String {
        "search_suggestions_\(query.lowercased())"
    }

    /// Generate cache key for unified search
    static func unifiedSearchKey(_ query: String) -> String {
        "unified_search_\(query.lowercased())"
    }

    /// Generate cache key for related authors
    static func relatedAuthorsKey(_ authorId: String) -> String {
        "related_authors_\(authorId)"
    }

    /// Generate cache key for bookstore tabs (persisted)
    static func bookstoreTabsKey() -> String {
        "bookstore_tabs"
    }

    /// Generate cache key for bookstore books by category (persisted)
    static func bookstoreBooksKey(categoryId: String?) -> String {
        if let categoryId = categoryId {
            return "bookstore_books_category_\(categoryId)"
        }
        return "bookstore_books_recommendation"
    }
}

// MARK: - Fetch with Cache Fallback

extension ResponseCacheService {
    /// Result type for cached fetch operations
    struct CachedFetchResult<T> {
        let data: T
        let source: CacheSource
        let cachedAt: Date?
    }

    enum CacheSource {
        case network
        case cache
    }

    /// Fetch data with automatic cache fallback
    /// - Tries to fetch from network first
    /// - On success, caches the result and returns it
    /// - On failure, returns cached data if available
    /// - Parameters:
    ///   - key: Cache key for the data
    ///   - ttl: Time-to-live for cache
    ///   - fetch: Async closure that fetches data from network
    /// - Returns: CachedFetchResult containing data and source info
    func fetchWithCache<T: Codable>(
        key: String,
        ttl: CacheTTL,
        fetch: () async throws -> T
    ) async -> CachedFetchResult<T>? {
        do {
            // Try network first
            let data = try await fetch()
            // Cache the result
            await set(data, for: key, ttl: ttl)
            return CachedFetchResult(data: data, source: .network, cachedAt: nil)
        } catch {
            // Network failed, try cache
            if let cached: T = await get(key, type: T.self) {
                let cachedResponse = await getCachedResponse(key)
                return CachedFetchResult(data: cached, source: .cache, cachedAt: cachedResponse?.timestamp)
            }
            return nil
        }
    }

    /// Get the raw cached response for a key (for timestamp info)
    func getCachedResponse(_ key: String) -> CachedResponse? {
        cache[key]
    }

    /// Check if valid cache exists for a key
    func hasValidCache(_ key: String) -> Bool {
        guard let cached = cache[key] else { return false }
        return !cached.isExpired
    }

    /// Get cached data or fetch from network
    /// - Prefers cache if valid, otherwise fetches from network
    func getOrFetch<T: Codable>(
        key: String,
        ttl: CacheTTL,
        fetch: () async throws -> T
    ) async throws -> CachedFetchResult<T> {
        // Check cache first
        if let cached: T = await get(key, type: T.self) {
            let cachedResponse = await getCachedResponse(key)
            return CachedFetchResult(data: cached, source: .cache, cachedAt: cachedResponse?.timestamp)
        }

        // Fetch from network
        let data = try await fetch()
        await set(data, for: key, ttl: ttl)
        return CachedFetchResult(data: data, source: .network, cachedAt: nil)
    }
}
