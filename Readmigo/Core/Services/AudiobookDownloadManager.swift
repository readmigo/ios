import Foundation
import Combine

/// Manages audiobook download operations, coordinating between BackgroundDownloadService and AudioCacheManager.
/// Supports downloading entire audiobooks or individual chapters.
@MainActor
class AudiobookDownloadManager: ObservableObject {
    static let shared = AudiobookDownloadManager()

    // MARK: - Published Properties

    @Published private(set) var downloadingAudiobooks: [String: AudiobookDownloadState] = [:]
    @Published private(set) var downloadedAudiobooks: [DownloadedAudiobook] = []
    @Published private(set) var isLoading = false

    // MARK: - Private Properties

    private let backgroundService = BackgroundDownloadService.shared
    private let cacheManager = AudioCacheManager.shared
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private static let downloadedAudiobooksKey = "AudiobookDownloadManager.downloadedAudiobooks"
    private static let downloadStatesKey = "AudiobookDownloadManager.downloadStates"

    // MARK: - Initialization

    private init() {
        loadDownloadedAudiobooks()
        loadDownloadStates()
        setupObservers()
    }

    // MARK: - Public Methods

    /// Download entire audiobook (all chapters)
    func downloadAudiobook(_ audiobook: Audiobook, priority: DownloadPriority = .normal) {
        // Check if already downloading
        if downloadingAudiobooks[audiobook.id] != nil {
            LoggingService.shared.warning("[AudiobookDownload] Already downloading: \(audiobook.id)")
            return
        }

        // Check storage availability
        let storageInfo = cacheManager.getStorageInfo()
        if storageInfo.hasStorageWarning {
            LoggingService.shared.warning("[AudiobookDownload] Storage warning - available: \(storageInfo.formattedAvailableSpace)")
        }

        // Create downloaded audiobook metadata
        var downloadedAudiobook = DownloadedAudiobook.from(audiobook)
        downloadedAudiobook.status = .downloading
        downloadedAudiobook.downloadStartedAt = Date()

        // Create download state
        var downloadState = AudiobookDownloadState(
            audiobookId: audiobook.id,
            overallProgress: 0,
            chapterProgress: [:],
            status: .downloading,
            currentlyDownloadingChapterId: nil,
            error: nil,
            downloadSpeed: nil,
            estimatedTimeRemaining: nil
        )

        // Initialize chapter progress
        for chapter in audiobook.chapters {
            downloadState.chapterProgress[chapter.id] = 0
        }

        downloadingAudiobooks[audiobook.id] = downloadState
        saveDownloadStates()

        // Save audiobook metadata
        saveAudiobookMetadata(downloadedAudiobook)

        // Start downloading chapters
        Task {
            await downloadChapters(audiobook.chapters, for: audiobook)
        }

        LoggingService.shared.info("[AudiobookDownload] Started downloading: \(audiobook.title)")
    }

    /// Download a single chapter
    func downloadChapter(_ chapter: AudiobookChapter, audiobookId: String) {
        let taskId = createTaskId(audiobookId: audiobookId, chapterId: chapter.id)

        guard let url = URL(string: chapter.audioUrl) else {
            LoggingService.shared.error("[AudiobookDownload] Invalid URL for chapter: \(chapter.id)")
            return
        }

        let destinationPath = cacheManager.getChapterDownloadPath(
            audiobookId: audiobookId,
            chapterId: chapter.id
        )

        // Create directory if needed
        let directory = URL(fileURLWithPath: destinationPath).deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        backgroundService.startDownload(
            url: url,
            taskId: taskId,
            audiobookId: audiobookId,
            chapterId: chapter.id,
            destinationPath: destinationPath
        ) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.handleChapterDownloadComplete(chapterId: chapter.id, audiobookId: audiobookId)
                case .failure(let error):
                    self?.handleChapterDownloadError(chapterId: chapter.id, audiobookId: audiobookId, error: error)
                }
            }
        }

        // Update download state
        if var state = downloadingAudiobooks[audiobookId] {
            state.currentlyDownloadingChapterId = chapter.id
            downloadingAudiobooks[audiobookId] = state
        }
    }

    /// Pause audiobook download
    func pauseDownload(audiobookId: String) {
        guard var state = downloadingAudiobooks[audiobookId] else { return }

        // Pause all active downloads for this audiobook
        backgroundService.cancelAllDownloads(audiobookId: audiobookId)

        state.status = .paused
        state.currentlyDownloadingChapterId = nil
        downloadingAudiobooks[audiobookId] = state
        saveDownloadStates()

        // Update metadata
        if var audiobook = downloadedAudiobooks.first(where: { $0.audiobookId == audiobookId }) {
            audiobook.status = .paused
            updateDownloadedAudiobook(audiobook)
        }

        LoggingService.shared.info("[AudiobookDownload] Paused: \(audiobookId)")
    }

    /// Resume audiobook download
    func resumeDownload(audiobookId: String) {
        guard var state = downloadingAudiobooks[audiobookId],
              let audiobook = downloadedAudiobooks.first(where: { $0.audiobookId == audiobookId }) else {
            return
        }

        state.status = .downloading
        downloadingAudiobooks[audiobookId] = state
        saveDownloadStates()

        // Find chapters that need downloading
        let pendingChapters = audiobook.chapters.filter { chapter in
            !cacheManager.isDownloaded(chapterId: chapter.chapterId) &&
            chapter.status != .completed
        }

        // Resume downloading
        Task {
            for chapter in pendingChapters {
                guard let url = URL(string: chapter.audioUrl) else { continue }

                let audioChapter = AudiobookChapter(
                    id: chapter.chapterId,
                    chapterNumber: chapter.chapterNumber,
                    title: chapter.title,
                    duration: chapter.duration,
                    audioUrl: chapter.audioUrl,
                    readerName: nil,
                    bookChapterId: nil
                )

                downloadChapter(audioChapter, audiobookId: audiobookId)

                // Wait for current download to complete before starting next
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            }
        }

        LoggingService.shared.info("[AudiobookDownload] Resumed: \(audiobookId)")
    }

    /// Cancel audiobook download
    func cancelDownload(audiobookId: String) {
        backgroundService.cancelAllDownloads(audiobookId: audiobookId)
        downloadingAudiobooks.removeValue(forKey: audiobookId)
        saveDownloadStates()

        // Remove partial downloads
        cacheManager.deleteAudiobookDownloads(audiobookId: audiobookId)

        // Remove from downloaded list
        downloadedAudiobooks.removeAll { $0.audiobookId == audiobookId }
        saveDownloadedAudiobooks()

        LoggingService.shared.info("[AudiobookDownload] Cancelled: \(audiobookId)")
    }

    /// Delete a downloaded audiobook
    func deleteAudiobook(audiobookId: String) {
        // Cancel any active downloads
        backgroundService.cancelAllDownloads(audiobookId: audiobookId)
        downloadingAudiobooks.removeValue(forKey: audiobookId)

        // Delete files
        cacheManager.deleteAudiobookDownloads(audiobookId: audiobookId)

        // Delete metadata file
        let metadataURL = cacheManager.getAudiobookDownloadsDirectory(audiobookId: audiobookId)
            .appendingPathComponent("metadata.json")
        try? fileManager.removeItem(at: metadataURL)

        // Remove from list
        downloadedAudiobooks.removeAll { $0.audiobookId == audiobookId }
        saveDownloadedAudiobooks()
        saveDownloadStates()

        LoggingService.shared.info("[AudiobookDownload] Deleted: \(audiobookId)")
    }

    /// Check if a chapter is downloaded
    func isChapterDownloaded(chapterId: String) -> Bool {
        cacheManager.isDownloaded(chapterId: chapterId)
    }

    /// Check if an audiobook is fully downloaded
    func isAudiobookDownloaded(audiobookId: String) -> Bool {
        guard let audiobook = downloadedAudiobooks.first(where: { $0.audiobookId == audiobookId }) else {
            return false
        }
        return audiobook.isComplete
    }

    /// Get download progress for an audiobook (0-1)
    func getDownloadProgress(audiobookId: String) -> Double {
        if let state = downloadingAudiobooks[audiobookId] {
            return state.overallProgress
        }

        if let audiobook = downloadedAudiobooks.first(where: { $0.audiobookId == audiobookId }) {
            return audiobook.progress
        }

        return 0
    }

    /// Get download status for an audiobook
    func getDownloadStatus(audiobookId: String) -> DownloadStatus {
        if let state = downloadingAudiobooks[audiobookId] {
            return state.status
        }

        if let audiobook = downloadedAudiobooks.first(where: { $0.audiobookId == audiobookId }) {
            return audiobook.status
        }

        return .notDownloaded
    }

    /// Get storage info
    func getStorageInfo() -> AudiobookStorageInfo {
        cacheManager.getStorageInfo()
    }

    /// Refresh downloaded audiobooks list
    func refreshDownloadedAudiobooks() {
        loadDownloadedAudiobooks()
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe download progress from background service
        backgroundService.$downloadProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.updateProgressFromBackgroundService(progress)
            }
            .store(in: &cancellables)

        backgroundService.$activeDownloads
            .receive(on: DispatchQueue.main)
            .sink { [weak self] downloads in
                self?.updateFromActiveDownloads(downloads)
            }
            .store(in: &cancellables)
    }

    private func updateProgressFromBackgroundService(_ progress: [String: Double]) {
        for (taskId, taskProgress) in progress {
            let components = parseTaskId(taskId)
            guard let audiobookId = components.audiobookId,
                  let chapterId = components.chapterId else { continue }

            if var state = downloadingAudiobooks[audiobookId] {
                state.chapterProgress[chapterId] = taskProgress
                state.overallProgress = calculateOverallProgress(state.chapterProgress)
                downloadingAudiobooks[audiobookId] = state
            }
        }
    }

    private func updateFromActiveDownloads(_ downloads: [String: AudiobookDownloadInfo]) {
        for (taskId, info) in downloads {
            let components = parseTaskId(taskId)
            guard let audiobookId = components.audiobookId else { continue }

            if var state = downloadingAudiobooks[audiobookId] {
                if info.status == .completed {
                    if let chapterId = components.chapterId {
                        state.chapterProgress[chapterId] = 1.0
                    }
                } else if info.status == .failed {
                    state.error = info.error
                }
                downloadingAudiobooks[audiobookId] = state
            }
        }
    }

    private func downloadChapters(_ chapters: [AudiobookChapter], for audiobook: Audiobook) async {
        for chapter in chapters {
            // Skip already downloaded chapters
            if cacheManager.isDownloaded(chapterId: chapter.id) {
                handleChapterDownloadComplete(chapterId: chapter.id, audiobookId: audiobook.id)
                continue
            }

            downloadChapter(chapter, audiobookId: audiobook.id)

            // Small delay between starting downloads to avoid overwhelming the system
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
    }

    private func handleChapterDownloadComplete(chapterId: String, audiobookId: String) {
        // Mark chapter as downloaded
        cacheManager.markAsDownloaded(chapterId: chapterId)

        // Update download state
        if var state = downloadingAudiobooks[audiobookId] {
            state.chapterProgress[chapterId] = 1.0
            state.overallProgress = calculateOverallProgress(state.chapterProgress)

            // Check if all chapters are downloaded
            let allComplete = state.chapterProgress.values.allSatisfy { $0 >= 1.0 }
            if allComplete {
                state.status = .completed
                downloadingAudiobooks.removeValue(forKey: audiobookId)
            } else {
                downloadingAudiobooks[audiobookId] = state
            }
        }

        // Update audiobook metadata
        if var audiobook = downloadedAudiobooks.first(where: { $0.audiobookId == audiobookId }) {
            if let index = audiobook.chapters.firstIndex(where: { $0.chapterId == chapterId }) {
                audiobook.chapters[index].status = .completed
                audiobook.chapters[index].downloadedAt = Date()
                audiobook.chapters[index].localPath = cacheManager.getChapterDownloadPath(
                    audiobookId: audiobookId,
                    chapterId: chapterId
                )
            }

            audiobook.downloadedChapters = audiobook.chapters.filter { $0.status == .completed }.count

            if audiobook.downloadedChapters == audiobook.totalChapters {
                audiobook.status = .completed
                audiobook.downloadCompletedAt = Date()
            }

            updateDownloadedAudiobook(audiobook)
        }

        saveDownloadStates()
        LoggingService.shared.info("[AudiobookDownload] Chapter completed: \(chapterId)")
    }

    private func handleChapterDownloadError(chapterId: String, audiobookId: String, error: Error) {
        LoggingService.shared.error("[AudiobookDownload] Chapter failed: \(chapterId), error: \(error)")

        if var state = downloadingAudiobooks[audiobookId] {
            state.error = error.localizedDescription
            downloadingAudiobooks[audiobookId] = state
        }

        // Update chapter status
        if var audiobook = downloadedAudiobooks.first(where: { $0.audiobookId == audiobookId }) {
            if let index = audiobook.chapters.firstIndex(where: { $0.chapterId == chapterId }) {
                audiobook.chapters[index].status = .failed
            }
            updateDownloadedAudiobook(audiobook)
        }

        saveDownloadStates()
    }

    private func calculateOverallProgress(_ chapterProgress: [String: Double]) -> Double {
        guard !chapterProgress.isEmpty else { return 0 }
        let total = chapterProgress.values.reduce(0, +)
        return total / Double(chapterProgress.count)
    }

    private func createTaskId(audiobookId: String, chapterId: String) -> String {
        "\(audiobookId)_\(chapterId)"
    }

    private func parseTaskId(_ taskId: String) -> (audiobookId: String?, chapterId: String?) {
        let components = taskId.split(separator: "_", maxSplits: 1)
        guard components.count == 2 else { return (nil, nil) }
        return (String(components[0]), String(components[1]))
    }

    // MARK: - Persistence

    private func loadDownloadedAudiobooks() {
        isLoading = true
        defer { isLoading = false }

        // Load from metadata files in downloads directory
        let downloadsDir = cacheManager.getDownloadsDirectory()

        guard let contents = try? fileManager.contentsOfDirectory(
            at: downloadsDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return
        }

        var audiobooks: [DownloadedAudiobook] = []

        for url in contents where url.hasDirectoryPath {
            let metadataURL = url.appendingPathComponent("metadata.json")
            if let data = try? Data(contentsOf: metadataURL),
               let audiobook = try? decoder.decode(DownloadedAudiobook.self, from: data) {
                audiobooks.append(audiobook)
            }
        }

        downloadedAudiobooks = audiobooks.sorted { ($0.lastPlayedAt ?? $0.downloadStartedAt ?? Date.distantPast) > ($1.lastPlayedAt ?? $1.downloadStartedAt ?? Date.distantPast) }
    }

    private func saveDownloadedAudiobooks() {
        // Audiobooks are saved individually via saveAudiobookMetadata
    }

    private func saveAudiobookMetadata(_ audiobook: DownloadedAudiobook) {
        let audiobookDir = cacheManager.getAudiobookDownloadsDirectory(audiobookId: audiobook.audiobookId)
        let metadataURL = audiobookDir.appendingPathComponent("metadata.json")

        if let data = try? encoder.encode(audiobook) {
            try? data.write(to: metadataURL)
        }

        // Update in-memory list
        if let index = downloadedAudiobooks.firstIndex(where: { $0.audiobookId == audiobook.audiobookId }) {
            downloadedAudiobooks[index] = audiobook
        } else {
            downloadedAudiobooks.append(audiobook)
        }
    }

    private func updateDownloadedAudiobook(_ audiobook: DownloadedAudiobook) {
        saveAudiobookMetadata(audiobook)
    }

    private func loadDownloadStates() {
        guard let data = UserDefaults.standard.data(forKey: Self.downloadStatesKey),
              let states = try? decoder.decode([String: AudiobookDownloadState].self, from: data) else {
            return
        }

        // Only restore non-completed states
        downloadingAudiobooks = states.filter { $0.value.status != .completed }
    }

    private func saveDownloadStates() {
        if let data = try? encoder.encode(downloadingAudiobooks) {
            UserDefaults.standard.set(data, forKey: Self.downloadStatesKey)
        }
    }
}
