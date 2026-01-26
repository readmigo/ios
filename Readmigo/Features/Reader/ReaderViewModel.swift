import Foundation
import Combine

// MARK: - Timeout Error

enum LoadingTimeoutError: Error, LocalizedError {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "reader.error.timeout".localized
        }
    }
}

@MainActor
class ReaderViewModel: ObservableObject {
    let book: Book
    @Published private(set) var bookDetail: BookDetail?

    @Published var currentChapterIndex: Int = 0
    @Published var currentChapter: Chapter?
    @Published var chapterContent: ChapterContent?
    @Published var isLoading = false
    @Published var isLoadingBookDetail = false
    @Published var error: String?

    // Reading progress
    @Published var scrollProgress: Double = 0
    @Published var overallProgress: Double = 0

    // Page tracking
    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 1
    @Published var shouldStartFromLastPage: Bool = false  // For cross-chapter navigation

    // UI State
    @Published var showSettings = false
    @Published var showChapterList = false
    @Published var showAIPanel = false

    // Text Selection
    @Published var selectedText: String?
    @Published var selectedSentence: String?

    // Offline State
    @Published var isOfflineMode = false
    @Published var isChapterAvailableOffline = false

    // Session tracking for server reporting
    private var sessionStartTime: Date?
    private var sessionStartProgress: Double = 0
    private var hasSubmittedSession = false

    private var progressSaveTask: Task<Void, Never>?
    private let libraryManager = LibraryManager.shared
    private let progressStore = ReadingProgressStore.shared

    /// Loading timeout in seconds (10 seconds max)
    private let loadingTimeoutSeconds: Double = 10.0

    /// Initialize with Book only - will load BookDetail automatically
    init(book: Book) {
        self.book = book
        self.bookDetail = nil

        // Restore local progress if available
        if let savedProgress = progressStore.getProgress(for: book.id) {
            self.currentChapterIndex = savedProgress.currentChapter
            self.scrollProgress = savedProgress.scrollPosition
            self.currentPage = savedProgress.currentPage
            self.totalPages = savedProgress.totalPages
            self.sessionStartProgress = savedProgress.scrollPosition
            LoggingService.shared.info(.reading, "ReaderViewModel initialized for book: \(book.title) with restored progress (chapter \(savedProgress.currentChapter + 1))", component: "ReaderViewModel")
        } else {
            LoggingService.shared.info(.reading, "ReaderViewModel initialized for book: \(book.title) (will load details)", component: "ReaderViewModel")
        }

        // Start session tracking
        self.sessionStartTime = Date()
    }

    /// Initialize with both Book and BookDetail (when already loaded)
    init(book: Book, bookDetail: BookDetail) {
        self.book = book
        self.bookDetail = bookDetail

        // Restore local progress if available
        if let savedProgress = progressStore.getProgress(for: book.id) {
            self.currentChapterIndex = savedProgress.currentChapter
            self.scrollProgress = savedProgress.scrollPosition
            self.currentPage = savedProgress.currentPage
            self.totalPages = savedProgress.totalPages
            self.sessionStartProgress = savedProgress.scrollPosition
            if savedProgress.currentChapter < bookDetail.chapters.count {
                self.currentChapter = bookDetail.chapters[savedProgress.currentChapter]
            } else {
                self.currentChapter = bookDetail.chapters.first
            }
            LoggingService.shared.info(.reading, "ReaderViewModel initialized for book: \(book.title) with restored progress (chapter \(savedProgress.currentChapter + 1))", component: "ReaderViewModel")
        } else {
            self.currentChapter = bookDetail.chapters.first
            LoggingService.shared.info(.reading, "ReaderViewModel initialized for book: \(book.title) (details provided)", component: "ReaderViewModel")
        }

        // Start session tracking
        self.sessionStartTime = Date()
    }

    // MARK: - Load Book Detail

    /// Load book detail if not already loaded
    func loadBookDetailIfNeeded() async {
        // Check if bookDetail is loaded and valid (has chapters)
        if let detail = bookDetail, !detail.chapters.isEmpty {
            LoggingService.shared.debug(.reading, "BookDetail already loaded with \(detail.chapters.count) chapters, skipping", component: "ReaderViewModel")
            return
        }

        // If bookDetail exists but has no chapters, clear it and reload
        if let detail = bookDetail, detail.chapters.isEmpty {
            LoggingService.shared.warning(.reading, "BookDetail exists but has empty chapters, forcing reload", component: "ReaderViewModel")
            self.bookDetail = nil
        }

        LoggingService.shared.info(.reading, "Loading book detail for: \(book.id)", component: "ReaderViewModel")
        isLoadingBookDetail = true
        error = nil

        let cacheKey = CacheKeys.bookDetailKey(book.id)
        let cacheService = ResponseCacheService.shared

        do {
            let detail: BookDetail = try await APIClient.shared.request(
                endpoint: APIEndpoints.bookDetail(book.id)
            )

            LoggingService.shared.info(.reading, "API returned BookDetail with \(detail.chapters.count) chapters", component: "ReaderViewModel")

            self.bookDetail = detail
            self.currentChapter = detail.chapters.first

            // Cache the response
            await cacheService.set(detail, for: cacheKey, ttl: .bookDetail)

            LoggingService.shared.info(.reading, "BookDetail loaded: \(detail.chapters.count) chapters", component: "ReaderViewModel")

            // Debug: Print all chapters info
            LoggingService.shared.debug(.reading, "📚 [ReaderDebug] ========== 章节列表 ==========", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📚 [ReaderDebug] 书籍: \(book.title)", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📚 [ReaderDebug] 总章节数: \(detail.chapters.count)", component: "ReaderViewModel")
            for (index, chapter) in detail.chapters.enumerated() {
                LoggingService.shared.debug(.reading, "📚 [ReaderDebug] 章节[\(index)]: order=\(chapter.order), id=\(chapter.id), title=\(chapter.title)", component: "ReaderViewModel")
            }
            LoggingService.shared.debug(.reading, "📚 [ReaderDebug] ================================", component: "ReaderViewModel")
        } catch {
            LoggingService.shared.error(.reading, "API request failed: \(error.localizedDescription)", component: "ReaderViewModel")

            // Try to load from cache on network failure
            if let cachedDetail: BookDetail = await cacheService.get(cacheKey, type: BookDetail.self) {
                // Validate cached data
                if cachedDetail.chapters.isEmpty {
                    LoggingService.shared.error(.reading, "Cached bookDetail has empty chapters, clearing invalid cache", component: "ReaderViewModel")
                    await cacheService.invalidate(cacheKey)
                    self.error = "reader.error.loadBookDetail".localized
                } else {
                    self.bookDetail = cachedDetail
                    self.currentChapter = cachedDetail.chapters.first
                    LoggingService.shared.info(.reading, "Loaded book detail from cache (\(cachedDetail.chapters.count) chapters)", component: "ReaderViewModel")
                }
            } else {
                self.error = "reader.error.loadBookDetail".localized
                LoggingService.shared.error(.reading, "Failed to load book detail: \(error.localizedDescription)", component: "ReaderViewModel")
            }
        }

        isLoadingBookDetail = false
    }

    /// Check if ready to read (book detail loaded)
    var isReadyToRead: Bool {
        bookDetail != nil
    }

    /// Get chapters safely
    var chapters: [Chapter] {
        bookDetail?.chapters ?? []
    }

    // MARK: - Load Chapter Content

    func loadChapter(at index: Int) async {
        guard let bookDetail = bookDetail else {
            LoggingService.shared.warning(.reading, "Cannot load chapter: bookDetail not loaded", component: "ReaderViewModel")
            return
        }

        guard index >= 0 && index < bookDetail.chapters.count else {
            LoggingService.shared.warning(.reading, "Invalid chapter index: \(index), total chapters: \(bookDetail.chapters.count)", component: "ReaderViewModel")
            return
        }

        LoggingService.shared.info(.reading, "Loading chapter \(index + 1)/\(bookDetail.chapters.count) for book: \(book.title)", component: "ReaderViewModel")

        isLoading = true
        error = nil
        currentChapterIndex = index
        currentChapter = bookDetail.chapters[index]

        let chapterId = bookDetail.chapters[index].id
        LoggingService.shared.debug(.reading, "Chapter ID: \(chapterId), Title: \(bookDetail.chapters[index].title)", component: "ReaderViewModel")

        // Check if chapter is available offline
        isChapterAvailableOffline = await ContentCache.shared.hasChapterContent(bookId: book.id, chapterId: chapterId)

        // Try to load from offline storage first (offline-first approach)
        if let offlineContent = await loadOfflineContent(chapterId: chapterId) {
            LoggingService.shared.debug(.reading, "Loaded chapter from offline cache", component: "ReaderViewModel")

            // Debug: Print offline chapter content details
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] ========== 章节内容(离线缓存) ==========", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 章节ID: \(offlineContent.id)", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 章节标题: \(offlineContent.title)", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 章节序号: \(offlineContent.order)", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 字数: \(offlineContent.wordCount)", component: "ReaderViewModel")
            let htmlPreview = String(offlineContent.htmlContent.prefix(500))
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] HTML内容预览(前500字符):\n\(htmlPreview)", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] HTML总长度: \(offlineContent.htmlContent.count) 字符", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] ================================", component: "ReaderViewModel")

            self.chapterContent = offlineContent
            self.scrollProgress = 0
            // Note: isLoading will be set to false when WebView sends contentReady message

            // Trigger smart predownload for next chapters
            await triggerSmartPredownload()
            return
        }

        // Check network status
        let networkStatus = OfflineManager.shared.networkStatus
        if networkStatus == .notConnected {
            isOfflineMode = true
            self.error = "reader.offline.noConnection".localized
            isLoading = false
            return
        }

        // Load from API (returns metadata with contentUrl or direct htmlContent)
        let endpoint = APIEndpoints.bookContent(book.id, chapterId)
        LoggingService.shared.debug(.reading, "Fetching chapter metadata from API (timeout: \(loadingTimeoutSeconds)s)", component: "ReaderViewModel")

        do {
            // Use timeout mechanism to prevent infinite loading
            let timeoutNanoseconds = UInt64(loadingTimeoutSeconds * 1_000_000_000)
            let content = try await withThrowingTaskGroup(of: ChapterContent.self) { group in
                // Task 1: Actual API request
                group.addTask {
                    // Step 1: Get chapter metadata from API
                    let meta: ChapterContentMeta = try await APIClient.shared.request(
                        endpoint: endpoint
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
                            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500, "Failed to fetch chapter content from R2")
                        }
                        guard let fetchedContent = String(data: data, encoding: .utf8) else {
                            throw APIError.decodingError(NSError(domain: "ReaderViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML content"]))
                        }
                        htmlContent = fetchedContent
                    } else {
                        throw APIError.invalidURL
                    }

                    // Step 3: Construct ChapterContent from meta + HTML
                    return ChapterContent(meta: meta, htmlContent: htmlContent)
                }

                // Task 2: Timeout after loadingTimeoutSeconds
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                    throw LoadingTimeoutError.timeout
                }

                // Wait for the first task to complete (either success or timeout)
                guard let result = try await group.next() else {
                    throw LoadingTimeoutError.timeout
                }

                // Cancel the remaining task (timeout task if API succeeded, or vice versa)
                group.cancelAll()

                return result
            }

            LoggingService.shared.info(.reading, "Got chapter content: \(content.title), wordCount: \(content.wordCount)", component: "ReaderViewModel")

            LoggingService.shared.info(.reading, "Successfully loaded chapter: \(content.title), wordCount: \(content.wordCount)", component: "ReaderViewModel")

            // Debug: Print chapter content details
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] ========== 章节内容 ==========", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 章节ID: \(content.id)", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 章节标题: \(content.title)", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 章节序号: \(content.order)", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 字数: \(content.wordCount)", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 上一章ID: \(content.previousChapterId ?? "无")", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 下一章ID: \(content.nextChapterId ?? "无")", component: "ReaderViewModel")
            let htmlPreview = String(content.htmlContent.prefix(500))
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] HTML内容预览(前500字符):\n\(htmlPreview)", component: "ReaderViewModel")
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] HTML总长度: \(content.htmlContent.count) 字符", component: "ReaderViewModel")

            // Debug: Check for images in HTML
            let imgCount = content.htmlContent.components(separatedBy: "<img").count - 1
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] HTML中的<img>标签数量: \(imgCount)", component: "ReaderViewModel")
            if imgCount > 0 {
                // Find and print first image src
                if let range = content.htmlContent.range(of: "<img[^>]*src=\"([^\"]*)\"", options: .regularExpression) {
                    let imgTag = String(content.htmlContent[range])
                    LoggingService.shared.debug(.reading, "📖 [ReaderDebug] 第一个<img>标签: \(imgTag)", component: "ReaderViewModel")
                }
            }
            LoggingService.shared.debug(.reading, "📖 [ReaderDebug] ================================", component: "ReaderViewModel")

            self.chapterContent = content
            self.scrollProgress = 0
            isLoading = false  // Allow WebView to be created and render content

            // Cache the content for offline use
            try? await ContentCache.shared.saveChapterContent(content, bookId: book.id)
            isChapterAvailableOffline = true

            // Trigger smart predownload for next chapters
            await triggerSmartPredownload()
        } catch is LoadingTimeoutError {
            LoggingService.shared.error(.reading, "Loading timeout after \(loadingTimeoutSeconds) seconds", component: "ReaderViewModel")
            self.error = "reader.error.timeout".localized
            isLoading = false
        } catch let apiError as APIError {
            LoggingService.shared.error(.reading, "API Error loading chapter: \(apiError)", component: "ReaderViewModel")
            // Handle specific API errors
            switch apiError {
            case .unauthorized:
                // Check if user is authenticated
                if await AuthManager.shared.isAuthenticated {
                    self.error = "Session expired. Please sign in again to continue reading."
                } else {
                    self.error = "Please sign in to read this book."
                }
            case .decodingError(let decodeError):
                LoggingService.shared.error(.reading, "Decoding error details: \(decodeError)", component: "ReaderViewModel")
                self.error = "Failed to parse chapter content"
            case .serverError(let code, let message):
                LoggingService.shared.error(.reading, "Server error \(code): \(message ?? "no message")", component: "ReaderViewModel")
                self.error = "Server error: \(message ?? "Unknown error")"
            default:
                self.error = "Failed to load chapter: \(apiError.localizedDescription)"
            }
            isLoading = false
        } catch {
            LoggingService.shared.error(.reading, "Unexpected error loading chapter: \(error.localizedDescription)", component: "ReaderViewModel")
            self.error = "Failed to load chapter: \(error.localizedDescription)"
            isLoading = false
        }

        // Note: isLoading is set to false after successful content load to allow WebView to be created

        // Reset the flag after content is loaded - it's a one-time navigation trigger
        if shouldStartFromLastPage {
            // Small delay to ensure SwiftUI has rendered with the flag set to true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.shouldStartFromLastPage = false
            }
        }
    }

    private func loadOfflineContent(chapterId: String) async -> ChapterContent? {
        // Try to load from cache
        return await ContentCache.shared.getChapterContent(bookId: book.id, chapterId: chapterId)
    }

    private func triggerSmartPredownload() async {
        // Pre-download next chapters in background
        guard let bookDetail = bookDetail else { return }
        await OfflineManager.shared.predownloadNextChapters(
            bookId: book.id,
            currentChapterIndex: currentChapterIndex,
            bookDetail: bookDetail
        )
    }

    /// Load chapter content for preloading (doesn't update current state)
    /// Returns ChapterContent if successful, nil otherwise
    func loadChapterContent(at index: Int) async -> ChapterContent? {
        guard let bookDetail = bookDetail else {
            LoggingService.shared.warning(.reading, "Cannot preload chapter: bookDetail not loaded", component: "ReaderViewModel")
            return nil
        }

        guard index >= 0 && index < bookDetail.chapters.count else {
            LoggingService.shared.warning(.reading, "Invalid preload chapter index: \(index)", component: "ReaderViewModel")
            return nil
        }

        let chapterId = bookDetail.chapters[index].id
        LoggingService.shared.debug(.reading, "Preloading chapter \(index + 1): \(chapterId)", component: "ReaderViewModel")

        // Try to load from offline storage first (offline-first approach)
        if let offlineContent = await loadOfflineContent(chapterId: chapterId) {
            LoggingService.shared.debug(.reading, "Preloaded chapter from offline cache", component: "ReaderViewModel")
            return offlineContent
        }

        // Check network status
        let networkStatus = OfflineManager.shared.networkStatus
        if networkStatus == .notConnected {
            LoggingService.shared.debug(.reading, "Cannot preload: no network connection", component: "ReaderViewModel")
            return nil
        }

        // Load from API
        let endpoint = APIEndpoints.bookContent(book.id, chapterId)

        do {
            let content: ChapterContent = try await APIClient.shared.request(
                endpoint: endpoint
            )
            LoggingService.shared.debug(.reading, "Successfully preloaded chapter: \(content.title)", component: "ReaderViewModel")

            // Cache the content for offline use
            try? await ContentCache.shared.saveChapterContent(content, bookId: book.id)

            return content
        } catch {
            LoggingService.shared.error(.reading, "Error preloading chapter: \(error.localizedDescription)", component: "ReaderViewModel")
            return nil
        }
    }

    // MARK: - Navigation

    func goToNextChapter() async {
        guard currentChapterIndex < chapters.count - 1 else {
            LoggingService.shared.debug(.reading, "Already at last chapter", component: "ReaderViewModel")
            return
        }
        LoggingService.shared.info(.reading, "Navigating to next chapter", component: "ReaderViewModel")
        shouldStartFromLastPage = false  // Always start from first page when going forward
        await loadChapter(at: currentChapterIndex + 1)
    }

    func goToPreviousChapter(toLastPage: Bool = false) async {
        guard currentChapterIndex > 0 else {
            LoggingService.shared.debug(.reading, "Already at first chapter", component: "ReaderViewModel")
            return
        }
        LoggingService.shared.info(.reading, "Navigating to previous chapter (toLastPage: \(toLastPage))", component: "ReaderViewModel")
        shouldStartFromLastPage = toLastPage
        await loadChapter(at: currentChapterIndex - 1)
    }

    func goToChapter(_ chapter: Chapter) async {
        if let index = chapters.firstIndex(where: { $0.id == chapter.id }) {
            LoggingService.shared.info(.reading, "Jumping to chapter: \(chapter.title) (index: \(index))", component: "ReaderViewModel")
            await loadChapter(at: index)
        } else {
            LoggingService.shared.warning(.reading, "Chapter not found: \(chapter.id)", component: "ReaderViewModel")
        }
    }

    func navigateToChapter(chapterId: String, position: Int?) async {
        if let index = chapters.firstIndex(where: { $0.id == chapterId }) {
            LoggingService.shared.info(.reading, "Navigating to chapter: \(chapterId) (index: \(index)), position: \(position ?? -1)", component: "ReaderViewModel")
            await loadChapter(at: index)
            // If position is provided, it could be used to scroll to a specific location
            // For now, we just navigate to the chapter
        } else {
            LoggingService.shared.warning(.reading, "Chapter not found for search result: \(chapterId)", component: "ReaderViewModel")
        }
    }

    func navigateToBookmark(_ bookmark: Bookmark) async {
        let targetChapterIndex = bookmark.position.chapterIndex

        LoggingService.shared.info(
            .reading,
            "Navigating to bookmark at chapter \(targetChapterIndex + 1), position: \(bookmark.position.scrollPercentage)",
            component: "ReaderViewModel"
        )

        // Load the chapter if it's different from current
        if targetChapterIndex != currentChapterIndex {
            await loadChapter(at: targetChapterIndex)
        }

        // Update scroll progress to bookmark position
        // Note: The actual scrolling to position would need to be handled by the content view
        scrollProgress = bookmark.position.scrollPercentage

        // Add to navigation history
        BookmarkManager.shared.addToHistory(
            bookId: book.id,
            chapterId: bookmark.chapterId,
            position: bookmark.position,
            chapterTitle: currentChapter?.title
        )
    }

    var hasNextChapter: Bool {
        currentChapterIndex < chapters.count - 1
    }

    var hasPreviousChapter: Bool {
        currentChapterIndex > 0
    }

    // MARK: - Progress Tracking

    func updateScrollProgress(_ progress: Double) {
        scrollProgress = progress
        calculateOverallProgress()
        scheduleProgressSave()
    }

    func updatePageProgress(current: Int, total: Int) {
        currentPage = current
        totalPages = total
        // Calculate scroll progress based on page position
        scrollProgress = total > 1 ? Double(current - 1) / Double(total - 1) : 0
        calculateOverallProgress()
        scheduleProgressSave()
    }

    private func calculateOverallProgress() {
        let totalChapters = Double(chapters.count)
        guard totalChapters > 0 else {
            overallProgress = 0
            return
        }
        let chapterWeight = 1.0 / totalChapters
        let completedChapters = Double(currentChapterIndex) * chapterWeight
        let currentChapterProgress = scrollProgress * chapterWeight
        overallProgress = completedChapters + currentChapterProgress
    }

    private func scheduleProgressSave() {
        // Progress saving is now only done on exit, not during reading
        // This method is kept for compatibility but does nothing
    }

    /// Save reading progress to local Core Data storage
    /// Called when exiting the reader or when app enters background
    func saveLocalProgress() {
        let chapterId = currentChapter?.id

        progressStore.saveProgressAndSetCurrentlyReading(
            book: book,
            chapterId: chapterId,
            chapter: currentChapterIndex,
            position: scrollProgress,
            page: currentPage,
            totalPages: totalPages
        )

        LoggingService.shared.info(.reading, "Local progress saved: book=\(book.id), chapter=\(currentChapterIndex + 1), position=\(Int(scrollProgress * 100))%", component: "ReaderViewModel")

        // Submit reading session to server (fire and forget)
        submitReadingSession()
    }

    /// Submit reading session to server for analytics
    /// Called when exiting reader or app goes to background
    private func submitReadingSession() {
        guard !hasSubmittedSession else { return }

        guard let startTime = sessionStartTime else {
            LoggingService.shared.warning(.reading, "No session start time, skipping session submit", component: "ReaderViewModel")
            return
        }

        let durationSeconds = Date().timeIntervalSince(startTime)
        let durationMinutes = max(1, Int(durationSeconds / 60)) // Minimum 1 minute for API

        // Only submit if reading time >= 10 seconds
        guard durationSeconds >= 10 else {
            LoggingService.shared.debug(.reading, "Reading session too short (\(Int(durationSeconds))s), skipping submit", component: "ReaderViewModel")
            return
        }

        hasSubmittedSession = true

        // Calculate pages read (rough estimate based on progress change)
        let progressChange = max(0, scrollProgress - sessionStartProgress)
        let estimatedPagesRead = max(1, Int(progressChange * Double(totalPages)))

        let request = CreateReadingSessionRequest(
            bookId: book.id,
            durationMinutes: durationMinutes,
            pagesRead: estimatedPagesRead
        )

        Task {
            do {
                let _: CreateReadingSessionResponse = try await APIClient.shared.request(
                    endpoint: APIEndpoints.readingSessions,
                    method: .post,
                    body: request
                )
                LoggingService.shared.info(.reading, "Reading session submitted: book=\(book.id), duration=\(durationMinutes)min, pages=\(estimatedPagesRead)", component: "ReaderViewModel")
            } catch {
                LoggingService.shared.warning(.reading, "Failed to submit reading session: \(error.localizedDescription)", component: "ReaderViewModel")
                // Reset flag so it can retry on next save
                hasSubmittedSession = false
            }
        }
    }

    // MARK: - Text Selection

    func handleTextSelection(text: String, sentence: String) {
        selectedText = text
        selectedSentence = sentence
        showAIPanel = true
    }

    func clearSelection() {
        selectedText = nil
        selectedSentence = nil
        showAIPanel = false
    }
}

// MARK: - Request Model

struct SaveProgressRequest: Codable {
    let bookId: String
    let chapterId: String
    let progress: Double
    let position: String?
}

// MARK: - Response Model

struct SaveProgressResponse: Codable {
    let bookId: String
    let chapterId: String
    let progress: Double
}

// MARK: - Reading Session Models

struct CreateReadingSessionRequest: Codable {
    let bookId: String
    let durationMinutes: Int
    let pagesRead: Int?
    let wordsLookedUp: Int?
    let aiInteractions: Int?

    init(bookId: String, durationMinutes: Int, pagesRead: Int? = nil, wordsLookedUp: Int? = nil, aiInteractions: Int? = nil) {
        self.bookId = bookId
        self.durationMinutes = durationMinutes
        self.pagesRead = pagesRead
        self.wordsLookedUp = wordsLookedUp
        self.aiInteractions = aiInteractions
    }
}

struct CreateReadingSessionResponse: Codable {
    let id: String
    let userBookId: String
    let durationMinutes: Int
}
