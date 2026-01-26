import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Import state machine
enum ImportState: Equatable {
    case idle
    case checkingPermission
    case selectingFile
    case preparing(filename: String)
    case uploading(filename: String, progress: Double)
    case processing(filename: String, progress: Int)
    case completed(ImportedBookSummary)
    case failed(String)

    var isActive: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }

    var displayMessage: String {
        switch self {
        case .idle:
            return ""
        case .checkingPermission:
            return "import.state.checkingPermission".localized
        case .selectingFile:
            return "import.state.selectingFile".localized
        case .preparing(let filename):
            return String(format: "import.state.preparing".localized, filename)
        case .uploading(let filename, let progress):
            return String(format: "import.state.uploading".localized, filename, Int(progress * 100))
        case .processing(let filename, let progress):
            return String(format: "import.state.processing".localized, filename, progress)
        case .completed:
            return "import.state.completed".localized
        case .failed(let error):
            return error
        }
    }
}

/// ViewModel for handling book import
@MainActor
class ImportViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var state: ImportState = .idle
    @Published var quota: ImportQuota?
    @Published var showFilePicker = false
    @Published var showUpgradePrompt = false
    @Published var showQuotaExceeded = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let importService = ImportService.shared
    private let subscriptionManager = SubscriptionManager.shared
    private var currentJobId: String?
    private var pollingTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Overall progress (0.0 - 1.0)
    var progress: Double {
        switch state {
        case .uploading(_, let progress):
            return progress * 0.4 // Upload is 40% of total
        case .processing(_, let progress):
            return 0.4 + Double(progress) / 100 * 0.6 // Processing is 60%
        case .completed:
            return 1.0
        default:
            return 0
        }
    }

    /// Supported file types for document picker
    var supportedTypes: [UTType] {
        [.epub, .plainText, .pdf]
    }

    /// Check if can import (based on subscription)
    var canImport: Bool {
        subscriptionManager.currentTier != .free
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Start the import flow
    func startImport() async {
        state = .checkingPermission

        // Check subscription
        if !canImport {
            showUpgradePrompt = true
            state = .idle
            return
        }

        // Check quota
        do {
            let quota = try await importService.fetchQuota()
            self.quota = quota

            if !quota.hasBookQuota {
                showQuotaExceeded = true
                state = .idle
                return
            }

            state = .selectingFile
            showFilePicker = true
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Handle file selected from picker
    func handleFileSelected(url: URL) async {
        // Validate file access
        guard url.startAccessingSecurityScopedResource() else {
            state = .failed("import.error.accessDenied".localized)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let filename = url.lastPathComponent

        // Validate format
        guard let format = ImportFileFormat.from(filename: filename) else {
            state = .failed(ImportError.invalidFormat(url.pathExtension).localizedDescription ?? "")
            return
        }

        // Get file size
        guard let fileSize = url.fileSize else {
            state = .failed("import.error.cannotReadFile".localized)
            return
        }

        // Check quota for this file
        if let quota = quota, !quota.canImport(fileSize: fileSize) {
            showQuotaExceeded = true
            state = .idle
            return
        }

        state = .preparing(filename: filename)

        do {
            // Step 1: Initiate import
            let initResponse = try await importService.initiateImport(
                filename: filename,
                fileSize: fileSize,
                contentType: url.mimeType,
                md5: nil // Skip MD5 for faster start
            )

            currentJobId = initResponse.jobId

            // Step 2: Upload file
            state = .uploading(filename: filename, progress: 0)

            try await FileUploadService.shared.uploadFile(
                from: url,
                to: initResponse.uploadUrl,
                contentType: url.mimeType,
                progress: { [weak self] progress in
                    Task { @MainActor in
                        self?.state = .uploading(filename: filename, progress: progress)
                    }
                }
            )

            // Step 3: Complete upload
            _ = try await importService.completeUpload(jobId: initResponse.jobId)

            // Step 4: Poll for completion
            state = .processing(filename: filename, progress: 0)
            try await pollJobStatus(jobId: initResponse.jobId, filename: filename)

        } catch {
            if case ImportError.cancelled = error {
                state = .idle
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    /// Cancel current import
    func cancelImport() {
        pollingTask?.cancel()
        pollingTask = nil
        FileUploadService.shared.cancelAllUploads()
        state = .idle
        currentJobId = nil
    }

    /// Retry failed import
    func retry() {
        state = .idle
        Task {
            await startImport()
        }
    }

    /// Reset state
    func reset() {
        cancelImport()
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func pollJobStatus(jobId: String, filename: String) async throws {
        var lastProgress = 0

        while true {
            // Check for cancellation
            try Task.checkCancellation()

            let status = try await importService.getJobStatus(jobId: jobId)

            switch status.status {
            case .pending, .uploading:
                // Still waiting
                break

            case .processing:
                lastProgress = status.progress
                state = .processing(filename: filename, progress: status.progress)

            case .completed:
                if let book = status.book {
                    state = .completed(book)
                    // Refresh quota
                    _ = try? await importService.fetchQuota()
                    return
                }

            case .failed:
                throw ImportError.processingFailed(status.errorMessage ?? "Unknown error")
            }

            // Wait before next poll
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        }
    }
}

// MARK: - UTType Extension

extension UTType {
    static var epub: UTType {
        UTType(filenameExtension: "epub") ?? .data
    }
}
