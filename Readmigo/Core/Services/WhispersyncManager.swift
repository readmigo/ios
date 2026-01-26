import Foundation
import Combine

// MARK: - Sync Mode

enum SyncMode: String, Codable {
    case reading = "READING"
    case listening = "LISTENING"

    var displayName: String {
        switch self {
        case .reading: return "Reading"
        case .listening: return "Listening"
        }
    }

    var icon: String {
        switch self {
        case .reading: return "book"
        case .listening: return "headphones"
        }
    }
}

// MARK: - Sync Progress Models

struct ReadingProgressSync: Codable {
    let bookId: String
    let currentChapterIndex: Int
    let chapterProgress: Double
    let overallProgress: Double
    let lastReadAt: Date
}

struct ListeningProgressSync: Codable {
    let audiobookId: String
    let currentChapterIndex: Int
    let positionSeconds: Int
    let totalListened: Int
    let lastListenedAt: Date
}

struct ContinueFrom: Codable {
    let mode: SyncMode
    let chapterIndex: Int
    let position: Double? // seconds for listening, percentage for reading
    let lastActivityAt: Date
}

struct SyncProgress: Codable {
    let bookId: String
    let audiobookId: String?
    let hasAudiobook: Bool
    let readingProgress: ReadingProgressSync?
    let listeningProgress: ListeningProgressSync?
    let recommendedMode: SyncMode
    let continueFrom: ContinueFrom?
}

struct ChapterMapping: Codable {
    let bookChapterId: String
    let bookChapterIndex: Int
    let audiobookChapterId: String?
    let audiobookChapterIndex: Int?
}

struct SyncMapping: Codable {
    let bookId: String
    let audiobookId: String
    let chapters: [ChapterMapping]
}

// MARK: - WhispersyncManager

@MainActor
class WhispersyncManager: ObservableObject {
    static let shared = WhispersyncManager()

    // MARK: - Published Properties

    @Published var currentSyncProgress: SyncProgress?
    @Published var showContinuePrompt: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - Private Properties

    private let apiClient: APIClient
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks

    var onSwitchToReading: ((Int, Double) -> Void)? // chapterIndex, progress
    var onSwitchToListening: ((String, Int, Int) -> Void)? // audiobookId, chapterIndex, position

    // MARK: - Initialization

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Public Methods

    /// Fetch sync progress for a book
    func fetchSyncProgress(for bookId: String) async {
        // Skip sync in guest mode (not authenticated)
        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.sync, "[Whispersync] Skipping fetch sync progress in guest mode", component: "WhispersyncManager")
            return
        }

        isLoading = true
        error = nil

        do {
            let progress: SyncProgress = try await apiClient.request(
                endpoint: "\(APIEndpoints.syncProgress)?bookId=\(bookId)",
                method: .get
            )
            currentSyncProgress = progress

            // Show continue prompt if there's progress to resume
            if progress.continueFrom != nil {
                showContinuePrompt = true
            }
        } catch {
            self.error = error
            LoggingService.shared.debug(.sync, "[Whispersync] Failed to fetch sync progress: \(error)", component: "WhispersyncManager")
        }

        isLoading = false
    }

    /// Check if we should show a sync prompt when entering reader or player
    func checkSyncPrompt(for bookId: String, currentMode: SyncMode) async -> ContinueFrom? {
        await fetchSyncProgress(for: bookId)

        guard let progress = currentSyncProgress,
              let continueFrom = progress.continueFrom else {
            return nil
        }

        // Only show prompt if recommended mode differs from current
        if progress.recommendedMode != currentMode {
            return continueFrom
        }

        return nil
    }

    /// Get audiobook for a book if available
    func getAudiobook(for bookId: String) async -> Audiobook? {
        do {
            let audiobook: Audiobook = try await apiClient.request(
                endpoint: APIEndpoints.audiobookForBook(bookId),
                method: .get
            )
            return audiobook
        } catch {
            LoggingService.shared.debug(.sync, "[Whispersync] No audiobook found for book: \(error)", component: "WhispersyncManager")
            return nil
        }
    }

    /// Switch from reading to listening
    func switchToListening(
        from bookId: String,
        chapterIndex: Int,
        chapterProgress: Double
    ) async {
        guard let syncProgress = currentSyncProgress,
              let audiobookId = syncProgress.audiobookId else {
            return
        }

        // Convert reading position to listening position
        do {
            struct ConvertResponse: Codable {
                let audiobookId: String
                let chapterIndex: Int
                let positionSeconds: Int
            }

            struct ConvertRequest: Codable {
                let bookId: String
                let chapterIndex: Int
                let chapterProgress: Double
            }

            let request = ConvertRequest(
                bookId: bookId,
                chapterIndex: chapterIndex,
                chapterProgress: chapterProgress
            )

            let result: ConvertResponse = try await apiClient.request(
                endpoint: "/sync/convert/to-listening",
                method: .post,
                body: request
            )

            onSwitchToListening?(result.audiobookId, result.chapterIndex, result.positionSeconds)
        } catch {
            LoggingService.shared.debug(.sync, "[Whispersync] Failed to convert position: \(error)", component: "WhispersyncManager")
            // Fallback: start from same chapter at beginning
            onSwitchToListening?(audiobookId, chapterIndex, 0)
        }
    }

    /// Switch from listening to reading
    func switchToReading(
        from audiobookId: String,
        chapterIndex: Int,
        positionSeconds: Int
    ) async {
        do {
            struct ConvertResponse: Codable {
                let bookId: String
                let chapterIndex: Int
                let chapterProgress: Double
            }

            struct ConvertRequest: Codable {
                let audiobookId: String
                let chapterIndex: Int
                let positionSeconds: Int
            }

            let request = ConvertRequest(
                audiobookId: audiobookId,
                chapterIndex: chapterIndex,
                positionSeconds: positionSeconds
            )

            let result: ConvertResponse = try await apiClient.request(
                endpoint: "/sync/convert/to-reading",
                method: .post,
                body: request
            )

            onSwitchToReading?(result.chapterIndex, result.chapterProgress)
        } catch {
            LoggingService.shared.debug(.sync, "[Whispersync] Failed to convert position: \(error)", component: "WhispersyncManager")
            // Fallback: start from same chapter at beginning
            onSwitchToReading?(chapterIndex, 0)
        }
    }

    /// Continue from recommended position
    func continueFromRecommended() {
        guard let progress = currentSyncProgress,
              let continueFrom = progress.continueFrom else {
            return
        }

        switch continueFrom.mode {
        case .reading:
            onSwitchToReading?(continueFrom.chapterIndex, continueFrom.position ?? 0)
        case .listening:
            if let audiobookId = progress.audiobookId {
                onSwitchToListening?(audiobookId, continueFrom.chapterIndex, Int(continueFrom.position ?? 0))
            }
        }

        showContinuePrompt = false
    }

    /// Dismiss the continue prompt
    func dismissContinuePrompt() {
        showContinuePrompt = false
    }

    /// Get chapter mapping between book and audiobook
    func getChapterMapping(for bookId: String) async -> SyncMapping? {
        do {
            let mapping: SyncMapping = try await apiClient.request(
                endpoint: "/sync/mapping/\(bookId)",
                method: .get
            )
            return mapping
        } catch {
            LoggingService.shared.debug(.sync, "[Whispersync] Failed to get chapter mapping: \(error)", component: "WhispersyncManager")
            return nil
        }
    }

    /// Update sync progress after reading/listening activity
    func updateProgress(
        bookId: String,
        mode: SyncMode,
        chapterIndex: Int,
        position: Double // seconds for listening, progress percentage for reading
    ) async {
        // Skip sync in guest mode (not authenticated)
        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.sync, "[Whispersync] Skipping progress sync in guest mode", component: "WhispersyncManager")
            return
        }

        do {
            struct SyncProgressUpdateRequest: Codable {
                let bookId: String
                let mode: String
                let readingChapterIndex: Int?
                let readingProgress: Double?
                let listeningChapterIndex: Int?
                let listeningPositionSeconds: Int?
            }

            let request: SyncProgressUpdateRequest
            switch mode {
            case .reading:
                request = SyncProgressUpdateRequest(
                    bookId: bookId,
                    mode: mode.rawValue,
                    readingChapterIndex: chapterIndex,
                    readingProgress: position,
                    listeningChapterIndex: nil,
                    listeningPositionSeconds: nil
                )
            case .listening:
                request = SyncProgressUpdateRequest(
                    bookId: bookId,
                    mode: mode.rawValue,
                    readingChapterIndex: nil,
                    readingProgress: nil,
                    listeningChapterIndex: chapterIndex,
                    listeningPositionSeconds: Int(position)
                )
            }

            let _: SyncProgress = try await apiClient.request(
                endpoint: APIEndpoints.syncProgress,
                method: .post,
                body: request
            )
        } catch {
            LoggingService.shared.debug(.sync, "[Whispersync] Failed to update progress: \(error)", component: "WhispersyncManager")
        }
    }
}

// MARK: - Continue Prompt View

import SwiftUI

struct ContinuePromptView: View {
    @ObservedObject var syncManager: WhispersyncManager = .shared
    let currentMode: SyncMode
    let onContinue: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if syncManager.showContinuePrompt,
           let continueFrom = syncManager.currentSyncProgress?.continueFrom,
           continueFrom.mode != currentMode {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("whispersync.continueFrom".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(continueFromDescription(continueFrom))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        onContinue()
                        syncManager.continueFromRecommended()
                    } label: {
                        Text("whispersync.continue".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }

                    Button {
                        onDismiss()
                        syncManager.dismissContinuePrompt()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private func continueFromDescription(_ continueFrom: ContinueFrom) -> String {
        let modeText = continueFrom.mode == .reading ? "reading" : "listening"
        let timeAgo = RelativeDateTimeFormatter().localizedString(for: continueFrom.lastActivityAt, relativeTo: Date())
        return "Chapter \(continueFrom.chapterIndex + 1) (\(modeText)) - \(timeAgo)"
    }
}
