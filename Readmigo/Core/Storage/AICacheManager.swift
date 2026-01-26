import Foundation
import CryptoKit

/// Manages local caching of AI responses to reduce API calls and improve response times
actor AICacheManager {
    static let shared = AICacheManager()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Maximum cache size in bytes (50MB)
    private let maxCacheSize: Int64 = 50 * 1024 * 1024

    /// Cache version - increment when prompt changes require cache invalidation
    static let cacheVersion = "v1"

    private var cacheDirectory: URL {
        let cachePath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cachePath.appendingPathComponent("AICache", isDirectory: true)
    }

    private var indexFilePath: URL {
        cacheDirectory.appendingPathComponent("index.json")
    }

    /// In-memory index for faster lookups
    private var cacheIndex: [String: CacheEntry] = [:]

    private init() {
        Task {
            await initialize()
        }
    }

    // MARK: - Initialization

    private func initialize() {
        ensureDirectoryExists()
        loadIndex()
        Task {
            await cleanupExpiredEntries()
        }
    }

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func loadIndex() {
        guard fileManager.fileExists(atPath: indexFilePath.path),
              let data = try? Data(contentsOf: indexFilePath),
              let index = try? decoder.decode([String: CacheEntry].self, from: data) else {
            cacheIndex = [:]
            return
        }
        cacheIndex = index
    }

    private func saveIndex() {
        guard let data = try? encoder.encode(cacheIndex) else { return }
        try? data.write(to: indexFilePath)
    }

    // MARK: - Public API

    /// Get cached AI response for the given key
    /// - Parameter key: The cache key (use AICacheKeys to generate)
    /// - Returns: Cached content if exists and not expired, nil otherwise
    func get(key: String) async -> String? {
        guard let entry = cacheIndex[key] else { return nil }

        // Check expiration
        if entry.expiresAt < Date() {
            await delete(key: key)
            return nil
        }

        // Load content from file
        let filePath = cacheDirectory.appendingPathComponent(entry.filename)
        guard let data = fileManager.contents(atPath: filePath.path),
              let content = String(data: data, encoding: .utf8) else {
            // File missing, remove from index
            cacheIndex.removeValue(forKey: key)
            saveIndex()
            return nil
        }

        // Update last accessed time
        cacheIndex[key] = CacheEntry(
            key: key,
            filename: entry.filename,
            createdAt: entry.createdAt,
            expiresAt: entry.expiresAt,
            lastAccessedAt: Date(),
            sizeBytes: entry.sizeBytes
        )
        saveIndex()

        return content
    }

    /// Store AI response in cache
    /// - Parameters:
    ///   - key: The cache key (use AICacheKeys to generate)
    ///   - content: The AI response content
    ///   - ttlDays: Time to live in days
    func set(key: String, content: String, ttlDays: Int) async {
        let data = Data(content.utf8)
        let filename = "\(key.sha256Hash).txt"
        let filePath = cacheDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: filePath)

            let entry = CacheEntry(
                key: key,
                filename: filename,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(TimeInterval(ttlDays * 24 * 3600)),
                lastAccessedAt: Date(),
                sizeBytes: Int64(data.count)
            )

            cacheIndex[key] = entry
            saveIndex()

            // Enforce max size
            await enforceMaxSize()
        } catch {
            // Silently fail - caching is optional
        }
    }

    /// Delete a specific cache entry
    func delete(key: String) async {
        guard let entry = cacheIndex[key] else { return }

        let filePath = cacheDirectory.appendingPathComponent(entry.filename)
        try? fileManager.removeItem(at: filePath)

        cacheIndex.removeValue(forKey: key)
        saveIndex()
    }

    /// Clear all AI cache
    func clearAll() async {
        // Remove all files
        if fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.removeItem(at: cacheDirectory)
        }
        ensureDirectoryExists()
        cacheIndex = [:]
        saveIndex()
    }

    /// Get current cache size in bytes
    func getCacheSize() async -> Int64 {
        cacheIndex.values.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Get cache statistics
    func getStats() async -> CacheStats {
        let totalSize = cacheIndex.values.reduce(0) { $0 + $1.sizeBytes }
        let entryCount = cacheIndex.count

        return CacheStats(
            entryCount: entryCount,
            totalSizeBytes: totalSize,
            maxSizeBytes: maxCacheSize
        )
    }

    // MARK: - Private Methods

    private func cleanupExpiredEntries() async {
        let now = Date()
        let expiredKeys = cacheIndex.filter { $0.value.expiresAt < now }.map { $0.key }

        for key in expiredKeys {
            await delete(key: key)
        }
    }

    private func enforceMaxSize() async {
        var currentSize = await getCacheSize()

        guard currentSize > maxCacheSize else { return }

        // Sort by last accessed time (LRU)
        let sortedEntries = cacheIndex.values.sorted { $0.lastAccessedAt < $1.lastAccessedAt }

        for entry in sortedEntries {
            guard currentSize > maxCacheSize else { break }

            await delete(key: entry.key)
            currentSize -= entry.sizeBytes
        }
    }
}

// MARK: - Cache Entry Model

struct CacheEntry: Codable {
    let key: String
    let filename: String
    let createdAt: Date
    let expiresAt: Date
    let lastAccessedAt: Date
    let sizeBytes: Int64
}

// MARK: - Cache Statistics

struct CacheStats {
    let entryCount: Int
    let totalSizeBytes: Int64
    let maxSizeBytes: Int64

    var usagePercentage: Double {
        guard maxSizeBytes > 0 else { return 0 }
        return Double(totalSizeBytes) / Double(maxSizeBytes) * 100
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
}

// MARK: - String Extension for SHA256

extension String {
    var sha256Hash: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(32).description
    }
}
