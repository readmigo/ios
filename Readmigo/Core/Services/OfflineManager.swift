import Foundation
import Network
import Combine

@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()

    // MARK: - Published Properties

    @Published var downloadedBooks: [DownloadedBook] = []
    @Published var downloadQueue: [DownloadTask] = []
    @Published var activeDownloads: [String: DownloadTask] = [:]
    @Published var networkStatus: NetworkStatus = .unknown
    @Published var syncStatus: SyncStatus = SyncStatus(
        lastSyncAt: nil,
        pendingUploads: 0,
        pendingDownloads: 0,
        isSyncing: false,
        lastError: nil
    )
    @Published var storageInfo: StorageInfo?
    @Published var settings: OfflineSettings = .default
    @Published var isInitialized = false

    // MARK: - Private Properties

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.readmigo.networkMonitor")
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let maxConcurrentDownloads = 3
    private let userDefaultsKey = "offlineSettings"

    // MARK: - Initialization

    private init() {
        setupNetworkMonitor()
        loadSettings()
        Task {
            await initialize()
        }
    }

    private func initialize() async {
        downloadedBooks = (try? await ContentCache.shared.loadAllBookMetadata()) ?? []
        storageInfo = await ContentCache.shared.getStorageInfo()
        isInitialized = true
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateNetworkStatus(path)
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func updateNetworkStatus(_ path: NWPath) {
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                networkStatus = .wifi
            } else if path.usesInterfaceType(.cellular) {
                networkStatus = .cellular
            } else {
                networkStatus = .wifi // Default to wifi for other types
            }
            // Resume downloads if appropriate
            Task {
                await resumeDownloadsIfNeeded()
            }
        } else {
            networkStatus = .notConnected
            pauseAllDownloads()
        }
    }

    // MARK: - Settings

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(OfflineSettings.self, from: data) {
            settings = decoded
        }
    }

    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func updateSettings(_ newSettings: OfflineSettings) {
        settings = newSettings
        saveSettings()
    }

    // MARK: - Download Book

    func downloadBook(_ book: Book, bookDetail: BookDetail, priority: DownloadPriority = .normal) async {
        // Check if already downloaded
        if let existing = downloadedBooks.first(where: { $0.bookId == book.id }) {
            if existing.isComplete { return }
        }

        // Create downloaded book entry
        let downloadedBook = DownloadedBook(
            id: UUID().uuidString,
            bookId: book.id,
            title: book.title,
            titleZh: nil,
            author: book.author,
            authorZh: nil,
            coverUrl: book.coverUrl,
            coverLocalPath: nil,
            totalChapters: bookDetail.chapters.count,
            downloadedChapters: 0,
            totalSizeBytes: Int64((book.wordCount ?? 0) * 10), // Estimate
            downloadedSizeBytes: 0,
            status: .queued,
            priority: priority,
            downloadStartedAt: nil,
            downloadCompletedAt: nil,
            lastAccessedAt: nil,
            expiresAt: settings.autoDeleteAfterDays.map { Calendar.current.date(byAdding: .day, value: $0, to: Date()) ?? Date() },
            errorMessage: nil
        )

        // Add to downloaded books
        if let index = downloadedBooks.firstIndex(where: { $0.bookId == book.id }) {
            downloadedBooks[index] = downloadedBook
        } else {
            downloadedBooks.append(downloadedBook)
        }

        // Save metadata
        try? await ContentCache.shared.saveBookMetadata(downloadedBook)

        // Queue chapter downloads
        for chapter in bookDetail.chapters {
            let task = DownloadTask(
                id: UUID().uuidString,
                bookId: book.id,
                chapterId: chapter.id,
                type: .chapter,
                status: .queued,
                priority: priority,
                progress: 0,
                bytesDownloaded: 0,
                totalBytes: Int64((chapter.wordCount ?? 0) * 10),
                retryCount: 0,
                maxRetries: 3,
                createdAt: Date(),
                startedAt: nil,
                completedAt: nil,
                errorMessage: nil
            )
            downloadQueue.append(task)
        }

        // Download cover
        if book.coverUrl != nil {
            let coverTask = DownloadTask(
                id: UUID().uuidString,
                bookId: book.id,
                chapterId: nil,
                type: .cover,
                status: .queued,
                priority: .high,
                progress: 0,
                bytesDownloaded: 0,
                totalBytes: 100_000,
                retryCount: 0,
                maxRetries: 3,
                createdAt: Date(),
                startedAt: nil,
                completedAt: nil,
                errorMessage: nil
            )
            downloadQueue.insert(coverTask, at: 0)
        }

        // Start processing queue
        await processDownloadQueue()
    }

    // MARK: - Download Queue Processing

    private func processDownloadQueue() async {
        guard canDownload() else { return }

        // Sort queue by priority
        downloadQueue.sort { $0.priority > $1.priority }

        // Start downloads up to max concurrent
        while activeDownloads.count < maxConcurrentDownloads,
              let nextTask = downloadQueue.first(where: { $0.status == .queued }) {

            if let index = downloadQueue.firstIndex(where: { $0.id == nextTask.id }) {
                downloadQueue[index].status = .downloading
                downloadQueue[index].startedAt = Date()
                activeDownloads[nextTask.id] = downloadQueue[index]

                Task {
                    await executeDownload(downloadQueue[index])
                }
            }
        }
    }

    private func canDownload() -> Bool {
        switch networkStatus {
        case .wifi:
            return true
        case .cellular:
            return !settings.downloadOnWifiOnly
        case .notConnected, .unknown:
            return false
        }
    }

    private func executeDownload(_ task: DownloadTask) async {
        switch task.type {
        case .chapter:
            await downloadChapter(task)
        case .cover:
            await downloadCover(task)
        case .book, .metadata:
            break
        }
    }

    private func downloadChapter(_ task: DownloadTask) async {
        guard let chapterId = task.chapterId else {
            await markTaskFailed(task, error: "Missing chapter ID")
            return
        }

        do {
            // Step 1: Fetch chapter metadata from API
            let meta: ChapterContentMeta = try await APIClient.shared.request(
                endpoint: APIEndpoints.bookContent(task.bookId, chapterId)
            )

            // Step 2: Get HTML content (direct or from R2 CDN)
            let htmlContent: String
            if let directContent = meta.htmlContent {
                // Local/dev mode: HTML content provided directly in API response
                htmlContent = directContent
            } else if let contentUrl = meta.contentUrl, let url = URL(string: contentUrl) {
                // Production mode: Fetch HTML content from R2 CDN
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NSError(domain: "OfflineManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch content from R2"])
                }
                guard let fetchedContent = String(data: data, encoding: .utf8) else {
                    throw NSError(domain: "OfflineManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML"])
                }
                htmlContent = fetchedContent
            } else {
                throw NSError(domain: "OfflineManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No content available"])
            }

            // Step 3: Construct ChapterContent and save
            let content = ChapterContent(meta: meta, htmlContent: htmlContent)
            try await ContentCache.shared.saveChapterContent(content, bookId: task.bookId)

            // Update task status
            await markTaskCompleted(task)

            // Update book progress
            await updateBookDownloadProgress(bookId: task.bookId)

        } catch {
            await markTaskFailed(task, error: error.localizedDescription)
        }
    }

    private func downloadCover(_ task: DownloadTask) async {
        guard let book = downloadedBooks.first(where: { $0.bookId == task.bookId }),
              let coverUrlString = book.coverUrl,
              let coverUrl = URL(string: coverUrlString) else {
            await markTaskCompleted(task)
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: coverUrl)
            let localPath = try await ContentCache.shared.saveCover(data, bookId: task.bookId)

            // Update book with local cover path
            if let index = downloadedBooks.firstIndex(where: { $0.bookId == task.bookId }) {
                let updatedBook = DownloadedBook(
                    id: downloadedBooks[index].id,
                    bookId: downloadedBooks[index].bookId,
                    title: downloadedBooks[index].title,
                    titleZh: downloadedBooks[index].titleZh,
                    author: downloadedBooks[index].author,
                    authorZh: downloadedBooks[index].authorZh,
                    coverUrl: downloadedBooks[index].coverUrl,
                    coverLocalPath: localPath,
                    totalChapters: downloadedBooks[index].totalChapters,
                    downloadedChapters: downloadedBooks[index].downloadedChapters,
                    totalSizeBytes: downloadedBooks[index].totalSizeBytes,
                    downloadedSizeBytes: downloadedBooks[index].downloadedSizeBytes,
                    status: downloadedBooks[index].status,
                    priority: downloadedBooks[index].priority,
                    downloadStartedAt: downloadedBooks[index].downloadStartedAt,
                    downloadCompletedAt: downloadedBooks[index].downloadCompletedAt,
                    lastAccessedAt: downloadedBooks[index].lastAccessedAt,
                    expiresAt: downloadedBooks[index].expiresAt,
                    errorMessage: downloadedBooks[index].errorMessage
                )
                downloadedBooks[index] = updatedBook
                try? await ContentCache.shared.saveBookMetadata(updatedBook)
            }

            await markTaskCompleted(task)
        } catch {
            await markTaskFailed(task, error: error.localizedDescription)
        }
    }

    // MARK: - Task Status Updates

    private func markTaskCompleted(_ task: DownloadTask) async {
        activeDownloads.removeValue(forKey: task.id)
        if let index = downloadQueue.firstIndex(where: { $0.id == task.id }) {
            downloadQueue[index].status = .completed
            downloadQueue[index].completedAt = Date()
            downloadQueue[index].progress = 1.0
        }

        // Remove completed tasks from queue
        downloadQueue.removeAll { $0.status == .completed }

        // Process next in queue
        await processDownloadQueue()
    }

    private func markTaskFailed(_ task: DownloadTask, error: String) async {
        activeDownloads.removeValue(forKey: task.id)

        if let index = downloadQueue.firstIndex(where: { $0.id == task.id }) {
            downloadQueue[index].retryCount += 1

            if downloadQueue[index].canRetry {
                downloadQueue[index].status = .queued
                downloadQueue[index].errorMessage = error
            } else {
                downloadQueue[index].status = .failed
                downloadQueue[index].errorMessage = error
            }
        }

        // Update book status if all chapter downloads failed
        await updateBookDownloadProgress(bookId: task.bookId)

        // Process next in queue
        await processDownloadQueue()
    }

    private func updateBookDownloadProgress(bookId: String) async {
        let downloadedChapterCount = await ContentCache.shared.getDownloadedChapterCount(bookId: bookId)

        guard let index = downloadedBooks.firstIndex(where: { $0.bookId == bookId }) else { return }

        let book = downloadedBooks[index]
        let isComplete = downloadedChapterCount == book.totalChapters
        let hasFailed = downloadQueue.contains { $0.bookId == bookId && $0.status == .failed }

        let status: DownloadStatus
        if isComplete {
            status = .completed
        } else if hasFailed {
            status = .failed
        } else if downloadQueue.contains(where: { $0.bookId == bookId && $0.status == .downloading }) {
            status = .downloading
        } else {
            status = .queued
        }

        let updatedBook = DownloadedBook(
            id: book.id,
            bookId: book.bookId,
            title: book.title,
            titleZh: book.titleZh,
            author: book.author,
            authorZh: book.authorZh,
            coverUrl: book.coverUrl,
            coverLocalPath: book.coverLocalPath,
            totalChapters: book.totalChapters,
            downloadedChapters: downloadedChapterCount,
            totalSizeBytes: book.totalSizeBytes,
            downloadedSizeBytes: Int64(downloadedChapterCount * 10000),
            status: status,
            priority: book.priority,
            downloadStartedAt: book.downloadStartedAt ?? (status == .downloading ? Date() : nil),
            downloadCompletedAt: isComplete ? Date() : nil,
            lastAccessedAt: book.lastAccessedAt,
            expiresAt: book.expiresAt,
            errorMessage: hasFailed ? "Some chapters failed to download" : nil
        )

        downloadedBooks[index] = updatedBook
        try? await ContentCache.shared.saveBookMetadata(updatedBook)

        // Update storage info
        storageInfo = await ContentCache.shared.getStorageInfo()
    }

    // MARK: - Download Control

    func pauseDownload(bookId: String) {
        for (id, task) in activeDownloads where task.bookId == bookId {
            activeDownloads.removeValue(forKey: id)
            if let index = downloadQueue.firstIndex(where: { $0.id == id }) {
                downloadQueue[index].status = .paused
            }
        }

        // Also pause queued tasks
        for index in downloadQueue.indices where downloadQueue[index].bookId == bookId && downloadQueue[index].status == .queued {
            downloadQueue[index].status = .paused
        }

        // Update book status
        if let index = downloadedBooks.firstIndex(where: { $0.bookId == bookId }) {
            let book = downloadedBooks[index]
            let updatedBook = DownloadedBook(
                id: book.id,
                bookId: book.bookId,
                title: book.title,
                titleZh: book.titleZh,
                author: book.author,
                authorZh: book.authorZh,
                coverUrl: book.coverUrl,
                coverLocalPath: book.coverLocalPath,
                totalChapters: book.totalChapters,
                downloadedChapters: book.downloadedChapters,
                totalSizeBytes: book.totalSizeBytes,
                downloadedSizeBytes: book.downloadedSizeBytes,
                status: .paused,
                priority: book.priority,
                downloadStartedAt: book.downloadStartedAt,
                downloadCompletedAt: nil,
                lastAccessedAt: book.lastAccessedAt,
                expiresAt: book.expiresAt,
                errorMessage: nil
            )
            downloadedBooks[index] = updatedBook
        }
    }

    func resumeDownload(bookId: String) async {
        // Resume paused tasks
        for index in downloadQueue.indices where downloadQueue[index].bookId == bookId && downloadQueue[index].status == .paused {
            downloadQueue[index].status = .queued
        }

        // Update book status
        if let index = downloadedBooks.firstIndex(where: { $0.bookId == bookId }) {
            let book = downloadedBooks[index]
            let updatedBook = DownloadedBook(
                id: book.id,
                bookId: book.bookId,
                title: book.title,
                titleZh: book.titleZh,
                author: book.author,
                authorZh: book.authorZh,
                coverUrl: book.coverUrl,
                coverLocalPath: book.coverLocalPath,
                totalChapters: book.totalChapters,
                downloadedChapters: book.downloadedChapters,
                totalSizeBytes: book.totalSizeBytes,
                downloadedSizeBytes: book.downloadedSizeBytes,
                status: .downloading,
                priority: book.priority,
                downloadStartedAt: book.downloadStartedAt,
                downloadCompletedAt: nil,
                lastAccessedAt: book.lastAccessedAt,
                expiresAt: book.expiresAt,
                errorMessage: nil
            )
            downloadedBooks[index] = updatedBook
        }

        await processDownloadQueue()
    }

    func cancelDownload(bookId: String) async {
        // Remove from active downloads
        for (id, task) in activeDownloads where task.bookId == bookId {
            activeDownloads.removeValue(forKey: id)
        }

        // Remove from queue
        downloadQueue.removeAll { $0.bookId == bookId }

        // Delete partial content
        try? await ContentCache.shared.deleteBookContent(bookId: bookId)

        // Remove from downloaded books
        downloadedBooks.removeAll { $0.bookId == bookId }

        // Update storage info
        storageInfo = await ContentCache.shared.getStorageInfo()
    }

    func pauseAllDownloads() {
        for (id, _) in activeDownloads {
            activeDownloads.removeValue(forKey: id)
            if let index = downloadQueue.firstIndex(where: { $0.id == id }) {
                downloadQueue[index].status = .paused
            }
        }
    }

    private func resumeDownloadsIfNeeded() async {
        guard canDownload() else { return }

        // Resume any paused downloads
        for index in downloadQueue.indices where downloadQueue[index].status == .paused {
            downloadQueue[index].status = .queued
        }

        await processDownloadQueue()
    }

    // MARK: - Delete Content

    func deleteBook(bookId: String) async {
        // Cancel any active downloads
        await cancelDownload(bookId: bookId)

        // Delete from storage
        try? await ContentCache.shared.deleteBookContent(bookId: bookId)

        // Remove from list
        downloadedBooks.removeAll { $0.bookId == bookId }

        // Update storage info
        storageInfo = await ContentCache.shared.getStorageInfo()
    }

    func deleteAllOfflineContent() async {
        // Cancel all downloads
        activeDownloads.removeAll()
        downloadQueue.removeAll()

        // Clear storage
        try? await ContentCache.shared.clearAllOfflineContent()

        // Clear list
        downloadedBooks.removeAll()

        // Update storage info
        storageInfo = await ContentCache.shared.getStorageInfo()
    }

    // MARK: - Offline Content Access

    func isBookAvailableOffline(_ bookId: String) -> Bool {
        downloadedBooks.first(where: { $0.bookId == bookId })?.isComplete ?? false
    }

    func isChapterAvailableOffline(bookId: String, chapterId: String) async -> Bool {
        await ContentCache.shared.hasChapterContent(bookId: bookId, chapterId: chapterId)
    }

    func getOfflineChapterContent(bookId: String, chapterId: String) async -> ChapterContent? {
        try? await ContentCache.shared.loadChapterContent(bookId: bookId, chapterId: chapterId)
    }

    func getDownloadedBook(_ bookId: String) -> DownloadedBook? {
        downloadedBooks.first { $0.bookId == bookId }
    }

    // MARK: - Pre-download

    func predownloadNextChapters(bookId: String, currentChapterIndex: Int, bookDetail: BookDetail) async {
        guard settings.autoDownloadEnabled, canDownload() else { return }

        let startIndex = currentChapterIndex + 1
        let endIndex = min(startIndex + settings.predownloadNextChapters, bookDetail.chapters.count)

        for index in startIndex..<endIndex {
            let chapter = bookDetail.chapters[index]
            let hasContent = await ContentCache.shared.hasChapterContent(bookId: bookId, chapterId: chapter.id)

            if !hasContent && !downloadQueue.contains(where: { $0.bookId == bookId && $0.chapterId == chapter.id }) {
                let task = DownloadTask(
                    id: UUID().uuidString,
                    bookId: bookId,
                    chapterId: chapter.id,
                    type: .chapter,
                    status: .queued,
                    priority: .low,
                    progress: 0,
                    bytesDownloaded: 0,
                    totalBytes: Int64((chapter.wordCount ?? 0) * 10),
                    retryCount: 0,
                    maxRetries: 3,
                    createdAt: Date(),
                    startedAt: nil,
                    completedAt: nil,
                    errorMessage: nil
                )
                downloadQueue.append(task)
            }
        }

        await processDownloadQueue()
    }

    // MARK: - Update Last Accessed

    func updateLastAccessed(bookId: String) async {
        guard let index = downloadedBooks.firstIndex(where: { $0.bookId == bookId }) else { return }

        let book = downloadedBooks[index]
        let updatedBook = DownloadedBook(
            id: book.id,
            bookId: book.bookId,
            title: book.title,
            titleZh: book.titleZh,
            author: book.author,
            authorZh: book.authorZh,
            coverUrl: book.coverUrl,
            coverLocalPath: book.coverLocalPath,
            totalChapters: book.totalChapters,
            downloadedChapters: book.downloadedChapters,
            totalSizeBytes: book.totalSizeBytes,
            downloadedSizeBytes: book.downloadedSizeBytes,
            status: book.status,
            priority: book.priority,
            downloadStartedAt: book.downloadStartedAt,
            downloadCompletedAt: book.downloadCompletedAt,
            lastAccessedAt: Date(),
            expiresAt: book.expiresAt,
            errorMessage: book.errorMessage
        )

        downloadedBooks[index] = updatedBook
        try? await ContentCache.shared.saveBookMetadata(updatedBook)
    }

    // MARK: - Cleanup Expired Content

    func cleanupExpiredContent() async {
        let expiredBooks = downloadedBooks.filter { $0.isExpired }

        for book in expiredBooks {
            await deleteBook(bookId: book.bookId)
        }
    }

    // MARK: - Refresh Storage Info

    func refreshStorageInfo() async {
        storageInfo = await ContentCache.shared.getStorageInfo()
    }

    // MARK: - Audiobook Timestamps

    /// Download timestamps for an audiobook (enables offline highlight sync)
    /// TODO: Enable when HighlightSync feature is integrated into project
    func downloadAudiobookTimestamps(audiobookId: String) async -> Bool {
        // Temporarily disabled - AudiobookTimestamps type not yet in project
        LoggingService.shared.info(.books, "[OfflineManager] Timestamp download not yet implemented for audiobook \(audiobookId)")
        return false
    }

    /// Check if timestamps are available offline for an audiobook
    func hasOfflineTimestamps(audiobookId: String) -> Bool {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }

        let timestampsPath = documentsDir
            .appendingPathComponent("audiobooks")
            .appendingPathComponent(audiobookId)
            .appendingPathComponent("timestamps.json")

        return fileManager.fileExists(atPath: timestampsPath.path)
    }

    /// Delete audiobook timestamps
    func deleteAudiobookTimestamps(audiobookId: String) async {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let timestampsPath = documentsDir
            .appendingPathComponent("audiobooks")
            .appendingPathComponent(audiobookId)
            .appendingPathComponent("timestamps.json")

        try? fileManager.removeItem(at: timestampsPath)
    }
}
