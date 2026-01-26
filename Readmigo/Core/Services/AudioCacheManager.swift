import Foundation

/// Manages local caching and downloading of audiobook audio files.
/// Uses dual storage strategy:
/// - ~/Library/Caches/AudiobookCache/ for streaming cache (system-managed, can be purged)
/// - ~/Documents/AudiobookDownloads/ for user-initiated downloads (persistent)
@MainActor
class AudioCacheManager: ObservableObject {
    static let shared = AudioCacheManager()

    // MARK: - Published Properties

    @Published var downloadProgress: [String: Double] = [:] // chapterId -> progress (0-1)
    @Published var cachedChapters: Set<String> = [] // Set of cached chapter IDs (in Caches)
    @Published var downloadedChapters: Set<String> = [] // Set of downloaded chapter IDs (in Documents)
    @Published var currentlyDownloading: Set<String> = [] // Set of currently downloading chapter IDs

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var pendingCompletions: [String: [(URL?) -> Void]] = [:]

    /// Cache directory for streaming (system can purge)
    private lazy var cacheDirectory: URL = {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let audioCache = paths[0].appendingPathComponent("AudiobookCache", isDirectory: true)

        if !fileManager.fileExists(atPath: audioCache.path) {
            try? fileManager.createDirectory(at: audioCache, withIntermediateDirectories: true)
        }

        return audioCache
    }()

    /// Downloads directory for user-initiated downloads (persistent)
    private lazy var downloadsDirectory: URL = {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let audioDownloads = paths[0].appendingPathComponent("AudiobookDownloads", isDirectory: true)

        if !fileManager.fileExists(atPath: audioDownloads.path) {
            try? fileManager.createDirectory(at: audioDownloads, withIntermediateDirectories: true)
        }

        return audioDownloads
    }()

    // MARK: - Initialization

    init() {
        loadCachedChapterIds()
        loadDownloadedChapterIds()
    }

    // MARK: - Public Methods

    /// Check if a chapter is cached locally (in Caches directory)
    func isCached(chapterId: String) -> Bool {
        cachedChapters.contains(chapterId)
    }

    /// Check if a chapter is downloaded (in Documents directory - persistent)
    func isDownloaded(chapterId: String) -> Bool {
        downloadedChapters.contains(chapterId)
    }

    /// Check if a chapter is available locally (either cached or downloaded)
    func isAvailableLocally(chapterId: String) -> Bool {
        isDownloaded(chapterId: chapterId) || isCached(chapterId: chapterId)
    }

    /// Get local URL for a cached chapter (checks Downloads first, then Cache)
    func localURL(for chapterId: String) -> URL? {
        // Check downloads directory first (persistent storage)
        let downloadURL = downloadsDirectory.appendingPathComponent("\(chapterId).mp3")
        if fileManager.fileExists(atPath: downloadURL.path) {
            return downloadURL
        }

        // Fall back to cache directory
        let cacheURL = cacheDirectory.appendingPathComponent("\(chapterId).mp3")
        if fileManager.fileExists(atPath: cacheURL.path) {
            return cacheURL
        }

        return nil
    }

    /// Get the downloads directory URL
    func getDownloadsDirectory() -> URL {
        downloadsDirectory
    }

    /// Get the downloads directory for a specific audiobook
    func getAudiobookDownloadsDirectory(audiobookId: String) -> URL {
        let directory = downloadsDirectory.appendingPathComponent(audiobookId, isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    /// Get the destination path for a chapter download
    func getChapterDownloadPath(audiobookId: String, chapterId: String) -> String {
        let audiobookDir = getAudiobookDownloadsDirectory(audiobookId: audiobookId)
        return audiobookDir.appendingPathComponent("chapters/\(chapterId).mp3").path
    }

    /// Get URL for playing - returns local if available, otherwise remote
    /// If not cached, starts download in background
    func getPlayableURL(chapterId: String, remoteURL: URL, completion: @escaping (URL) -> Void) {
        // If available locally, return local URL immediately
        if let localURL = localURL(for: chapterId) {
            completion(localURL)
            return
        }

        // Start background download and return remote URL for streaming
        downloadChapter(chapterId: chapterId, from: remoteURL) { _ in
            // Download completes in background, next play will use cache
        }

        // Return remote URL for immediate streaming
        completion(remoteURL)
    }

    /// Download and cache a chapter
    func downloadChapter(chapterId: String, from remoteURL: URL, completion: @escaping (URL?) -> Void) {
        // Already cached
        if let localURL = localURL(for: chapterId) {
            completion(localURL)
            return
        }

        // Already downloading - add to pending completions
        if currentlyDownloading.contains(chapterId) {
            if pendingCompletions[chapterId] == nil {
                pendingCompletions[chapterId] = []
            }
            pendingCompletions[chapterId]?.append(completion)
            return
        }

        // Start new download
        currentlyDownloading.insert(chapterId)
        downloadProgress[chapterId] = 0

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
        let task = session.downloadTask(with: remoteURL) { [weak self] tempURL, response, error in
            Task { @MainActor in
                self?.handleDownloadComplete(
                    chapterId: chapterId,
                    tempURL: tempURL,
                    response: response,
                    error: error,
                    completion: completion
                )
            }
        }

        // Observe download progress
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.downloadProgress[chapterId] = progress.fractionCompleted
            }
        }

        // Store task for potential cancellation
        downloadTasks[chapterId] = task
        task.resume()

        // Clean up observation when task completes
        Task {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                task.progress.observe(\.isFinished) { progress, _ in
                    if progress.isFinished {
                        observation.invalidate()
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Pre-download next chapters for seamless playback
    func predownloadNextChapters(chapters: [AudiobookChapter], currentIndex: Int, count: Int = 2) {
        let startIndex = currentIndex + 1
        let endIndex = min(startIndex + count, chapters.count)

        for index in startIndex..<endIndex {
            let chapter = chapters[index]
            guard let url = URL(string: chapter.audioUrl) else { continue }

            if !isCached(chapterId: chapter.id) && !currentlyDownloading.contains(chapter.id) {
                downloadChapter(chapterId: chapter.id, from: url) { _ in
                    print("[AudioCache] Pre-downloaded chapter: \(chapter.title)")
                }
            }
        }
    }

    /// Cancel a download
    func cancelDownload(chapterId: String) {
        downloadTasks[chapterId]?.cancel()
        downloadTasks.removeValue(forKey: chapterId)
        currentlyDownloading.remove(chapterId)
        downloadProgress.removeValue(forKey: chapterId)
        pendingCompletions.removeValue(forKey: chapterId)
    }

    /// Delete cached file for a chapter
    func deleteCache(for chapterId: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(chapterId).mp3")
        try? fileManager.removeItem(at: fileURL)
        cachedChapters.remove(chapterId)
        saveCachedChapterIds()
    }

    /// Delete all cached audio files
    func clearAllCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        cachedChapters.removeAll()
        saveCachedChapterIds()
    }

    /// Get total cache size in bytes (Caches directory only)
    func getCacheSize() -> Int64 {
        calculateDirectorySize(cacheDirectory)
    }

    /// Get total downloads size in bytes (Documents directory)
    func getDownloadsSize() -> Int64 {
        calculateDirectorySize(downloadsDirectory)
    }

    /// Get total size for a specific audiobook's downloads
    func getAudiobookDownloadSize(audiobookId: String) -> Int64 {
        let audiobookDir = downloadsDirectory.appendingPathComponent(audiobookId)
        return calculateDirectorySize(audiobookDir)
    }

    /// Calculate directory size
    private func calculateDirectorySize(_ directory: URL) -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }

    /// Get formatted cache size string
    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: getCacheSize(), countStyle: .file)
    }

    /// Get formatted downloads size string
    var formattedDownloadsSize: String {
        ByteCountFormatter.string(fromByteCount: getDownloadsSize(), countStyle: .file)
    }

    /// Move a cached chapter to downloads (for persistence)
    func moveToDownloads(chapterId: String, audiobookId: String) throws {
        let sourceURL = cacheDirectory.appendingPathComponent("\(chapterId).mp3")
        let destDir = getAudiobookDownloadsDirectory(audiobookId: audiobookId).appendingPathComponent("chapters", isDirectory: true)

        if !fileManager.fileExists(atPath: destDir.path) {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        }

        let destURL = destDir.appendingPathComponent("\(chapterId).mp3")

        if fileManager.fileExists(atPath: sourceURL.path) {
            // Remove existing destination file if present
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }

            try fileManager.moveItem(at: sourceURL, to: destURL)

            // Update tracking sets
            cachedChapters.remove(chapterId)
            downloadedChapters.insert(chapterId)
            saveCachedChapterIds()
            saveDownloadedChapterIds()

            print("[AudioCache] Moved chapter to downloads: \(chapterId)")
        }
    }

    /// Delete downloaded chapter
    func deleteDownload(for chapterId: String) {
        // Find and delete the file
        if let enumerator = fileManager.enumerator(at: downloadsDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == "\(chapterId).mp3" {
                    try? fileManager.removeItem(at: fileURL)
                    break
                }
            }
        }

        downloadedChapters.remove(chapterId)
        saveDownloadedChapterIds()
    }

    /// Delete all downloads for an audiobook
    func deleteAudiobookDownloads(audiobookId: String) {
        let audiobookDir = downloadsDirectory.appendingPathComponent(audiobookId)
        try? fileManager.removeItem(at: audiobookDir)

        // Remove from downloaded chapters set
        let chapterIds = downloadedChapters.filter { chapterId in
            let path = audiobookDir.appendingPathComponent("chapters/\(chapterId).mp3").path
            return !fileManager.fileExists(atPath: path)
        }
        downloadedChapters = Set(chapterIds)
        saveDownloadedChapterIds()
    }

    /// Clear all downloads
    func clearAllDownloads() {
        try? fileManager.removeItem(at: downloadsDirectory)
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        downloadedChapters.removeAll()
        saveDownloadedChapterIds()
    }

    /// Get storage info for audiobooks
    func getStorageInfo() -> AudiobookStorageInfo {
        let downloadedSize = getDownloadsSize()
        let cachedSize = getCacheSize()

        // Get available device space
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let availableSpace: Int64
        if let values = try? documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage {
            availableSpace = capacity
        } else {
            availableSpace = 0
        }

        return AudiobookStorageInfo(
            totalDownloadedBytes: downloadedSize,
            totalCachedBytes: cachedSize,
            downloadedAudiobookCount: countDownloadedAudiobooks(),
            downloadedChapterCount: downloadedChapters.count,
            availableSpace: availableSpace,
            maxStorageBytes: OfflineSettings.defaultMaxAudiobookStorageBytes
        )
    }

    /// Count number of downloaded audiobooks
    private func countDownloadedAudiobooks() -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(at: downloadsDirectory, includingPropertiesForKeys: nil) else {
            return 0
        }
        return contents.filter { $0.hasDirectoryPath }.count
    }

    /// Mark a chapter as downloaded (called after background download completes)
    func markAsDownloaded(chapterId: String) {
        downloadedChapters.insert(chapterId)
        saveDownloadedChapterIds()
    }

    // MARK: - Private Methods

    private func handleDownloadComplete(
        chapterId: String,
        tempURL: URL?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (URL?) -> Void
    ) {
        defer {
            currentlyDownloading.remove(chapterId)
            downloadTasks.removeValue(forKey: chapterId)
            downloadProgress.removeValue(forKey: chapterId)
        }

        guard error == nil, let tempURL = tempURL else {
            print("[AudioCache] Download failed for \(chapterId): \(error?.localizedDescription ?? "Unknown error")")
            completion(nil)
            notifyPendingCompletions(chapterId: chapterId, url: nil)
            return
        }

        let destinationURL = cacheDirectory.appendingPathComponent("\(chapterId).mp3")

        do {
            // Remove existing file if any
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            // Move downloaded file to cache
            try fileManager.moveItem(at: tempURL, to: destinationURL)

            // Update cached chapters set
            cachedChapters.insert(chapterId)
            saveCachedChapterIds()

            print("[AudioCache] Cached chapter: \(chapterId)")
            completion(destinationURL)
            notifyPendingCompletions(chapterId: chapterId, url: destinationURL)

        } catch {
            print("[AudioCache] Failed to save cached file: \(error)")
            completion(nil)
            notifyPendingCompletions(chapterId: chapterId, url: nil)
        }
    }

    private func notifyPendingCompletions(chapterId: String, url: URL?) {
        pendingCompletions[chapterId]?.forEach { $0(url) }
        pendingCompletions.removeValue(forKey: chapterId)
    }

    // MARK: - Persistence

    private let cachedChaptersKey = "AudioCacheManager.cachedChapters"
    private let downloadedChaptersKey = "AudioCacheManager.downloadedChapters"

    private func loadCachedChapterIds() {
        if let savedIds = UserDefaults.standard.stringArray(forKey: cachedChaptersKey) {
            // Verify files still exist
            cachedChapters = Set(savedIds.filter { chapterId in
                let fileURL = cacheDirectory.appendingPathComponent("\(chapterId).mp3")
                return fileManager.fileExists(atPath: fileURL.path)
            })

            // Save cleaned up list
            if cachedChapters.count != savedIds.count {
                saveCachedChapterIds()
            }
        }
    }

    private func saveCachedChapterIds() {
        UserDefaults.standard.set(Array(cachedChapters), forKey: cachedChaptersKey)
    }

    private func loadDownloadedChapterIds() {
        if let savedIds = UserDefaults.standard.stringArray(forKey: downloadedChaptersKey) {
            // Verify files still exist by scanning downloads directory
            var validIds = Set<String>()

            if let enumerator = fileManager.enumerator(at: downloadsDirectory, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension == "mp3" {
                        let chapterId = fileURL.deletingPathExtension().lastPathComponent
                        if savedIds.contains(chapterId) {
                            validIds.insert(chapterId)
                        }
                    }
                }
            }

            downloadedChapters = validIds

            // Save cleaned up list
            if downloadedChapters.count != savedIds.count {
                saveDownloadedChapterIds()
            }
        }
    }

    private func saveDownloadedChapterIds() {
        UserDefaults.standard.set(Array(downloadedChapters), forKey: downloadedChaptersKey)
    }
}
