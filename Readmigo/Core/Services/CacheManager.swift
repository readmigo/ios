import Foundation
import Kingfisher

/// Unified cache management interface
/// Coordinates all caching operations across the app
@MainActor
class CacheManager: ObservableObject {
    static let shared = CacheManager()

    // MARK: - Published Properties

    @Published var totalCacheSize: Int64 = 0
    @Published var imageCacheSize: Int64 = 0
    @Published var responseCacheSize: Int64 = 0
    @Published var contentCacheSize: Int64 = 0

    // MARK: - Cache References

    private let imageCache = ImageCache.default
    private let responseCache = ResponseCacheService.shared
    private let contentCache = ContentCache.shared

    // MARK: - Configuration

    struct Config {
        static let imageMemoryLimit = 50 * 1024 * 1024      // 50MB
        static let imageDiskLimit = 200 * 1024 * 1024       // 200MB
        static let urlCacheMemory = 20 * 1024 * 1024        // 20MB
        static let urlCacheDisk = 100 * 1024 * 1024         // 100MB
        static let cleanupThresholdPercent: Double = 0.9    // 90% full triggers cleanup
        static let cleanupTargetPercent: Double = 0.7       // Clean to 70%
    }

    private init() {
        Task {
            await calculateStorageUsage()
        }
    }

    // MARK: - Storage Usage

    /// Calculate total storage usage across all caches
    func calculateStorageUsage() async {
        // Image cache size (Kingfisher)
        imageCache.calculateDiskStorageSize { result in
            Task { @MainActor in
                switch result {
                case .success(let size):
                    self.imageCacheSize = Int64(size)
                case .failure:
                    self.imageCacheSize = 0
                }
                self.updateTotalSize()
            }
        }

        // Response cache stats
        let stats = await responseCache.getStats()
        responseCacheSize = Int64(stats.totalSize)

        // Content cache size
        contentCacheSize = await contentCache.totalCacheSize()

        updateTotalSize()
    }

    private func updateTotalSize() {
        totalCacheSize = imageCacheSize + responseCacheSize + contentCacheSize
    }

    // MARK: - Clear Caches

    /// Clear all caches
    func clearAllCaches() async {
        await clearImageCache()
        await clearResponseCache()
        await clearContentCache()
        await calculateStorageUsage()
        LoggingService.shared.info("All caches cleared")
    }

    /// Clear image cache (Kingfisher)
    func clearImageCache() async {
        imageCache.clearMemoryCache()
        await withCheckedContinuation { continuation in
            imageCache.clearDiskCache {
                continuation.resume()
            }
        }
        imageCacheSize = 0
        updateTotalSize()
        LoggingService.shared.info("Image cache cleared")
    }

    /// Clear response cache
    func clearResponseCache() async {
        await responseCache.invalidateAll()
        responseCacheSize = 0
        updateTotalSize()
        LoggingService.shared.info("Response cache cleared")
    }

    /// Clear content cache (offline books)
    func clearContentCache() async {
        await contentCache.clearAll()
        contentCacheSize = 0
        updateTotalSize()
        LoggingService.shared.info("Content cache cleared")
    }

    /// Clear expired entries from all caches
    func clearExpiredCaches() async {
        // Clean expired image cache (synchronous call)
        await withCheckedContinuation { continuation in
            imageCache.cleanExpiredDiskCache {
                continuation.resume()
            }
        }

        // Clean expired response cache
        await responseCache.cleanupExpired()

        await calculateStorageUsage()
        LoggingService.shared.debug("Expired cache entries cleaned")
    }

    // MARK: - Prefetching

    /// Prefetch book covers for a list of books
    func prefetchBookCovers(_ books: [Book]) {
        let urls = books.compactMap { book -> URL? in
            guard let urlString = book.coverUrl, !urlString.isEmpty else { return nil }
            return URL(string: urlString)
        }

        let prefetcher = ImagePrefetcher(urls: urls)
        prefetcher.start()
        LoggingService.shared.debug("Prefetching \(urls.count) book covers")
    }

    /// Prefetch content for a specific book (for offline reading)
    func prefetchBookContent(_ bookId: String) async {
        // This would integrate with OfflineManager to download book content
        LoggingService.shared.debug("Prefetching content for book: \(bookId)")
    }

    // MARK: - Cache Invalidation

    /// Invalidate cache for a specific book
    func invalidateBookCache(_ bookId: String) async {
        await responseCache.invalidate(ResponseCacheService.bookDetailKey(bookId))
        LoggingService.shared.debug("Invalidated cache for book: \(bookId)")
    }

    /// Invalidate user library cache
    func invalidateUserLibraryCache() async {
        await responseCache.invalidate(ResponseCacheService.userLibraryKey())
        LoggingService.shared.debug("Invalidated user library cache")
    }

    /// Invalidate all book lists cache
    func invalidateBookListsCache() async {
        await responseCache.invalidatePrefix("books_list")
        await responseCache.invalidatePrefix("book_list")
        LoggingService.shared.debug("Invalidated book lists cache")
    }

    // MARK: - Formatted Sizes

    /// Get formatted total cache size string
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalCacheSize, countStyle: .file)
    }

    /// Get formatted image cache size string
    var formattedImageSize: String {
        ByteCountFormatter.string(fromByteCount: imageCacheSize, countStyle: .file)
    }

    /// Get formatted response cache size string
    var formattedResponseSize: String {
        ByteCountFormatter.string(fromByteCount: responseCacheSize, countStyle: .file)
    }

    /// Get formatted content cache size string
    var formattedContentSize: String {
        ByteCountFormatter.string(fromByteCount: contentCacheSize, countStyle: .file)
    }
}

// MARK: - ContentCache Extension

extension ContentCache {
    /// Calculate total cache size
    func totalCacheSize() async -> Int64 {
        let fileManager = FileManager.default
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("BookContent") else {
            return 0
        }

        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }

    /// Clear all cached content
    func clearAll() async {
        let fileManager = FileManager.default
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("BookContent") else {
            return
        }

        try? fileManager.removeItem(at: cacheDir)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
}
