import Foundation

/// Service for managing background downloads using URLSession background configuration.
/// This service handles downloads that continue even when the app is in the background or terminated.
class BackgroundDownloadService: NSObject, ObservableObject {
    static let shared = BackgroundDownloadService()

    // MARK: - Constants

    private static let sessionIdentifier = "com.readmigo.audiobook.download"
    private static let activeDownloadsKey = "BackgroundDownloadService.activeDownloads"

    // MARK: - Published Properties

    @Published private(set) var activeDownloads: [String: AudiobookDownloadInfo] = [:]
    @Published private(set) var downloadProgress: [String: Double] = [:] // taskId -> progress

    // MARK: - Private Properties

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.allowsCellularAccess = true // Default to allowing cellular, can be updated later
        config.timeoutIntervalForResource = 60 * 60 * 24 // 24 hours
        config.httpMaximumConnectionsPerHost = 3

        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var backgroundCompletionHandler: (() -> Void)?
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var completionHandlers: [String: [(Result<URL, Error>) -> Void]] = [:]

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    private override init() {
        super.init()
        loadActiveDownloads()
    }

    // MARK: - Public Methods

    /// Restore downloads when app launches (reconnects to existing background session)
    func restoreDownloadsOnLaunch() {
        backgroundSession.getTasksWithCompletionHandler { [weak self] _, _, downloadTasks in
            guard let self = self else { return }

            for task in downloadTasks {
                if let taskId = task.taskDescription {
                    self.downloadTasks[taskId] = task

                    // Resume if paused
                    if task.state == .suspended {
                        task.resume()
                    }

                    Task { @MainActor in
                        LoggingService.shared.info("[BackgroundDownload] Restored task: \(taskId)")
                    }
                }
            }
        }
    }

    /// Handle background session events (called from AppDelegate)
    func handleBackgroundSessionEvents(identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == Self.sessionIdentifier else {
            completionHandler()
            return
        }

        backgroundCompletionHandler = completionHandler
        Task { @MainActor in
            LoggingService.shared.info("[BackgroundDownload] Handling background session events")
        }

        // Touching the session will deliver pending events
        _ = backgroundSession
    }

    /// Start a new download
    func startDownload(
        url: URL,
        taskId: String,
        audiobookId: String,
        chapterId: String,
        destinationPath: String,
        completion: ((Result<URL, Error>) -> Void)? = nil
    ) {
        // Check if already downloading
        if downloadTasks[taskId] != nil {
            Task { @MainActor in
                LoggingService.shared.warning("[BackgroundDownload] Task already exists: \(taskId)")
            }
            if let completion = completion {
                addCompletionHandler(taskId: taskId, completion: completion)
            }
            return
        }

        // Create download info
        let downloadInfo = AudiobookDownloadInfo(
            taskId: taskId,
            audiobookId: audiobookId,
            chapterId: chapterId,
            remoteUrl: url.absoluteString,
            destinationPath: destinationPath,
            resumeData: nil,
            bytesDownloaded: 0,
            totalBytes: 0,
            status: .downloading,
            createdAt: Date(),
            startedAt: Date(),
            completedAt: nil,
            error: nil
        )

        // Store download info
        DispatchQueue.main.async {
            self.activeDownloads[taskId] = downloadInfo
            self.saveActiveDownloads()
        }

        // Create and start download task
        let task = backgroundSession.downloadTask(with: url)
        task.taskDescription = taskId
        downloadTasks[taskId] = task

        if let completion = completion {
            addCompletionHandler(taskId: taskId, completion: completion)
        }

        task.resume()
        Task { @MainActor in
            LoggingService.shared.info("[BackgroundDownload] Started download: \(taskId)")
        }
    }

    /// Resume a paused download
    func resumeDownload(taskId: String, completion: ((Result<URL, Error>) -> Void)? = nil) {
        guard var downloadInfo = activeDownloads[taskId] else {
            Task { @MainActor in
                LoggingService.shared.warning("[BackgroundDownload] No download info for: \(taskId)")
            }
            completion?(.failure(BackgroundDownloadError.downloadNotFound))
            return
        }

        // Check for resume data
        if let resumeData = downloadInfo.resumeData {
            let task = backgroundSession.downloadTask(withResumeData: resumeData)
            task.taskDescription = taskId
            downloadTasks[taskId] = task

            downloadInfo.status = .downloading
            downloadInfo.resumeData = nil
            downloadInfo.startedAt = Date()

            DispatchQueue.main.async {
                self.activeDownloads[taskId] = downloadInfo
                self.saveActiveDownloads()
            }

            if let completion = completion {
                addCompletionHandler(taskId: taskId, completion: completion)
            }

            task.resume()
            Task { @MainActor in
                LoggingService.shared.info("[BackgroundDownload] Resumed download with resume data: \(taskId)")
            }
        } else if let existingTask = downloadTasks[taskId] {
            // Resume existing task
            existingTask.resume()

            downloadInfo.status = .downloading
            DispatchQueue.main.async {
                self.activeDownloads[taskId] = downloadInfo
                self.saveActiveDownloads()
            }

            if let completion = completion {
                addCompletionHandler(taskId: taskId, completion: completion)
            }

            Task { @MainActor in
                LoggingService.shared.info("[BackgroundDownload] Resumed existing task: \(taskId)")
            }
        } else {
            // Need to restart download from scratch
            guard let url = URL(string: downloadInfo.remoteUrl) else {
                completion?(.failure(BackgroundDownloadError.invalidURL))
                return
            }

            startDownload(
                url: url,
                taskId: taskId,
                audiobookId: downloadInfo.audiobookId,
                chapterId: downloadInfo.chapterId,
                destinationPath: downloadInfo.destinationPath,
                completion: completion
            )
        }
    }

    /// Pause a download
    func pauseDownload(taskId: String) {
        guard let task = downloadTasks[taskId] else {
            Task { @MainActor in
                LoggingService.shared.warning("[BackgroundDownload] No task to pause: \(taskId)")
            }
            return
        }

        task.cancel { [weak self] resumeData in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if var downloadInfo = self.activeDownloads[taskId] {
                    downloadInfo.status = .paused
                    downloadInfo.resumeData = resumeData
                    self.activeDownloads[taskId] = downloadInfo
                    self.saveActiveDownloads()
                }
            }

            self.downloadTasks.removeValue(forKey: taskId)
            Task { @MainActor in
                LoggingService.shared.info("[BackgroundDownload] Paused download: \(taskId)")
            }
        }
    }

    /// Cancel a download
    func cancelDownload(taskId: String) {
        downloadTasks[taskId]?.cancel()
        downloadTasks.removeValue(forKey: taskId)
        completionHandlers.removeValue(forKey: taskId)

        DispatchQueue.main.async {
            self.activeDownloads.removeValue(forKey: taskId)
            self.downloadProgress.removeValue(forKey: taskId)
            self.saveActiveDownloads()
        }

        Task { @MainActor in
            LoggingService.shared.info("[BackgroundDownload] Cancelled download: \(taskId)")
        }
    }

    /// Cancel all downloads for an audiobook
    func cancelAllDownloads(audiobookId: String) {
        let tasksToCancel = activeDownloads.filter { $0.value.audiobookId == audiobookId }
        for (taskId, _) in tasksToCancel {
            cancelDownload(taskId: taskId)
        }
    }

    /// Get download progress for a task
    func getProgress(taskId: String) -> Double {
        downloadProgress[taskId] ?? 0
    }

    /// Update WiFi-only setting
    func updateCellularAccess(allowed: Bool) {
        // Need to recreate session with new configuration for future downloads
        // Existing downloads will continue with their original settings
        Task { @MainActor in
            LoggingService.shared.info("[BackgroundDownload] Cellular access updated: \(allowed)")
        }
    }

    // MARK: - Private Methods

    private func addCompletionHandler(taskId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        if completionHandlers[taskId] == nil {
            completionHandlers[taskId] = []
        }
        completionHandlers[taskId]?.append(completion)
    }

    private func notifyCompletionHandlers(taskId: String, result: Result<URL, Error>) {
        completionHandlers[taskId]?.forEach { $0(result) }
        completionHandlers.removeValue(forKey: taskId)
    }

    private func loadActiveDownloads() {
        guard let data = UserDefaults.standard.data(forKey: Self.activeDownloadsKey),
              let downloads = try? decoder.decode([String: AudiobookDownloadInfo].self, from: data) else {
            return
        }

        // Filter out completed downloads
        activeDownloads = downloads.filter { $0.value.status != .completed }
    }

    private func saveActiveDownloads() {
        guard let data = try? encoder.encode(activeDownloads) else { return }
        UserDefaults.standard.set(data, forKey: Self.activeDownloadsKey)
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundDownloadService: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskId = downloadTask.taskDescription else {
            Task { @MainActor in
                LoggingService.shared.error("[BackgroundDownload] Task finished without taskDescription")
            }
            return
        }

        guard var downloadInfo = activeDownloads[taskId] else {
            Task { @MainActor in
                LoggingService.shared.error("[BackgroundDownload] No download info for completed task: \(taskId)")
            }
            return
        }

        let destinationURL = URL(fileURLWithPath: downloadInfo.destinationPath)

        do {
            // Create directory if needed
            let directory = destinationURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            // Move downloaded file to destination
            try fileManager.moveItem(at: location, to: destinationURL)

            // Update download info
            downloadInfo.status = .completed
            downloadInfo.completedAt = Date()

            if let fileSize = try? fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64 {
                downloadInfo.bytesDownloaded = fileSize
                downloadInfo.totalBytes = fileSize
            }

            DispatchQueue.main.async {
                self.activeDownloads[taskId] = downloadInfo
                self.downloadProgress[taskId] = 1.0
                self.saveActiveDownloads()
            }

            downloadTasks.removeValue(forKey: taskId)
            notifyCompletionHandlers(taskId: taskId, result: .success(destinationURL))

            Task { @MainActor in
                LoggingService.shared.info("[BackgroundDownload] Completed download: \(taskId)")
            }

        } catch {
            downloadInfo.status = .failed
            downloadInfo.error = error.localizedDescription

            DispatchQueue.main.async {
                self.activeDownloads[taskId] = downloadInfo
                self.saveActiveDownloads()
            }

            downloadTasks.removeValue(forKey: taskId)
            notifyCompletionHandlers(taskId: taskId, result: .failure(error))

            Task { @MainActor in
                LoggingService.shared.error("[BackgroundDownload] Failed to save file: \(error)")
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let taskId = downloadTask.taskDescription else { return }

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0

        DispatchQueue.main.async {
            self.downloadProgress[taskId] = progress

            if var downloadInfo = self.activeDownloads[taskId] {
                downloadInfo.bytesDownloaded = totalBytesWritten
                downloadInfo.totalBytes = totalBytesExpectedToWrite
                self.activeDownloads[taskId] = downloadInfo
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let taskId = downloadTask.taskDescription else {
            return
        }

        if let error = error {
            let nsError = error as NSError

            // Check if cancelled with resume data
            if nsError.code == NSURLErrorCancelled,
               let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                DispatchQueue.main.async {
                    if var downloadInfo = self.activeDownloads[taskId] {
                        downloadInfo.resumeData = resumeData
                        downloadInfo.status = .paused
                        self.activeDownloads[taskId] = downloadInfo
                        self.saveActiveDownloads()
                    }
                }
                return
            }

            // Handle other errors
            DispatchQueue.main.async {
                if var downloadInfo = self.activeDownloads[taskId] {
                    downloadInfo.status = .failed
                    downloadInfo.error = error.localizedDescription
                    self.activeDownloads[taskId] = downloadInfo
                    self.saveActiveDownloads()
                }
            }

            downloadTasks.removeValue(forKey: taskId)
            notifyCompletionHandlers(taskId: taskId, result: .failure(error))

            Task { @MainActor in
                LoggingService.shared.error("[BackgroundDownload] Task failed: \(taskId), error: \(error)")
            }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
            LoggingService.shared.info("[BackgroundDownload] Finished background session events")
        }
    }
}

// MARK: - Errors

enum BackgroundDownloadError: LocalizedError {
    case downloadNotFound
    case invalidURL
    case fileOperationFailed

    var errorDescription: String? {
        switch self {
        case .downloadNotFound:
            return "Download not found"
        case .invalidURL:
            return "Invalid download URL"
        case .fileOperationFailed:
            return "File operation failed"
        }
    }
}
