import Foundation
import Combine
import SwiftUI

// MARK: - Highlight Sync Manager

/// Manages real-time text highlighting synchronized with audiobook playback.
/// Observes AudiobookPlayer and updates highlight range based on timestamps.
@MainActor
class HighlightSyncManager: ObservableObject {

    // MARK: - Published Properties

    /// Current highlight range in the text (segment level)
    @Published var highlightRange: HighlightRange?

    /// Current word highlight range (for word-level highlighting)
    @Published var wordHighlightRange: HighlightRange?

    /// Current segment being played
    @Published var currentSegment: TimestampSegment?

    /// Whether sync is active
    @Published var isActive: Bool = false

    /// Whether timestamps are available for current chapter
    @Published var hasTimestamps: Bool = false

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message
    @Published var error: String?

    // MARK: - Private Properties

    private var timestamps: ChapterTimestamps?
    private var audiobookId: String?
    private var currentChapterNumber: Int?
    private let player: AudiobookPlayer
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    /// Cached offline timestamps
    private var offlineTimestampsCache: AudiobookTimestamps?

    // MARK: - Initialization

    init(player: AudiobookPlayer = .shared) {
        self.player = player
    }

    // MARK: - Public Methods

    /// Start syncing for an audiobook chapter
    func startSync(
        audiobookId: String,
        chapterNumber: Int,
        chapterContent: String? = nil
    ) async {
        self.audiobookId = audiobookId
        self.currentChapterNumber = chapterNumber

        isLoading = true
        error = nil

        // Try to load timestamps
        do {
            let timestamps = try await loadTimestamps(
                audiobookId: audiobookId,
                chapterNumber: chapterNumber
            )

            if let timestamps = timestamps {
                self.timestamps = timestamps
                self.hasTimestamps = true
                startObservingPlayback()
                LoggingService.shared.info(.books, "[HighlightSync] Started sync with \(timestamps.segments.count) segments")
            } else {
                self.hasTimestamps = false
                LoggingService.shared.info(.books, "[HighlightSync] No timestamps available for chapter \(chapterNumber)")
            }
        } catch {
            self.error = error.localizedDescription
            self.hasTimestamps = false
            LoggingService.shared.error(.books, "[HighlightSync] Failed to load timestamps: \(error)")
        }

        isLoading = false
    }

    /// Stop syncing
    func stopSync() {
        stopObservingPlayback()
        timestamps = nil
        audiobookId = nil
        currentChapterNumber = nil
        highlightRange = nil
        wordHighlightRange = nil
        currentSegment = nil
        hasTimestamps = false
        isActive = false
    }

    /// Seek to a position in the audio based on character offset
    func seekToText(at charOffset: Int) {
        guard let timestamps = timestamps else { return }

        // Find segment containing this character offset
        if let segment = timestamps.segments.first(where: {
            charOffset >= $0.charStart && charOffset < $0.charEnd
        }) {
            player.seek(to: segment.startTime)
            updateHighlight(for: segment.startTime)
        }
    }

    /// Get segment at a specific character offset
    func getSegment(at charOffset: Int) -> TimestampSegment? {
        timestamps?.segments.first {
            charOffset >= $0.charStart && charOffset < $0.charEnd
        }
    }

    // MARK: - Private Methods

    /// Load timestamps from offline cache or API
    private func loadTimestamps(
        audiobookId: String,
        chapterNumber: Int
    ) async throws -> ChapterTimestamps? {
        // Try offline cache first
        if let cached = loadOfflineTimestamps(for: audiobookId, chapter: chapterNumber) {
            return cached
        }

        // Fetch from API
        do {
            let response: ChapterTimestampsResponse = try await APIClient.shared.request(
                endpoint: "/audiobooks/\(audiobookId)/chapters/\(chapterNumber)/timestamps"
            )
            return response.timestamps
        } catch {
            // API error - might not have timestamps yet
            LoggingService.shared.warning(.books, "[HighlightSync] API error: \(error)")
            return nil
        }
    }

    /// Load from offline storage
    private func loadOfflineTimestamps(
        for audiobookId: String,
        chapter chapterNumber: Int
    ) -> ChapterTimestamps? {
        // Check memory cache first
        if let cached = offlineTimestampsCache,
           cached.audiobookId == audiobookId,
           let chapterTimestamps = cached.chapters[String(chapterNumber)] {
            return chapterTimestamps
        }

        // Try to load from disk
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let timestampsPath = documentsDir
            .appendingPathComponent("audiobooks")
            .appendingPathComponent(audiobookId)
            .appendingPathComponent("timestamps.json")

        guard fileManager.fileExists(atPath: timestampsPath.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: timestampsPath)
            let bundled = try JSONDecoder().decode(AudiobookTimestamps.self, from: data)
            offlineTimestampsCache = bundled
            return bundled.chapters[String(chapterNumber)]
        } catch {
            LoggingService.shared.error(.books, "[HighlightSync] Failed to load offline timestamps: \(error)")
            return nil
        }
    }

    /// Start observing player position
    private func startObservingPlayback() {
        stopObservingPlayback()
        isActive = true

        // Observe position changes
        player.$currentPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] position in
                self?.updateHighlight(for: position)
            }
            .store(in: &cancellables)

        // Observe chapter changes
        player.$currentChapterIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chapterIndex in
                guard let self = self,
                      let audiobookId = self.audiobookId else { return }

                // Check if chapter changed
                let newChapterNumber = chapterIndex + 1  // 1-indexed
                if newChapterNumber != self.currentChapterNumber {
                    Task {
                        await self.startSync(
                            audiobookId: audiobookId,
                            chapterNumber: newChapterNumber
                        )
                    }
                }
            }
            .store(in: &cancellables)

        // Also use a timer for more precise updates (every 100ms)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateHighlight(for: self?.player.currentPosition ?? 0)
            }
        }
    }

    /// Stop observing player
    private func stopObservingPlayback() {
        cancellables.removeAll()
        updateTimer?.invalidate()
        updateTimer = nil
        isActive = false
    }

    /// Update highlight based on current playback position
    private func updateHighlight(for time: TimeInterval) {
        guard let timestamps = timestamps else { return }

        // Binary search for current segment
        let segment = findSegment(at: time, in: timestamps.segments)

        if let segment = segment, segment.charStart >= 0 {
            currentSegment = segment
            highlightRange = HighlightRange(
                location: segment.charStart,
                length: segment.charEnd - segment.charStart
            )

            // Word-level highlight if available
            if let words = segment.words,
               let word = findWord(at: time, in: words) {
                wordHighlightRange = HighlightRange(
                    location: word.charStart,
                    length: word.charEnd - word.charStart
                )
            } else {
                wordHighlightRange = nil
            }
        } else {
            currentSegment = nil
            highlightRange = nil
            wordHighlightRange = nil
        }
    }

    /// Find segment at given time using binary search
    private func findSegment(at time: TimeInterval, in segments: [TimestampSegment]) -> TimestampSegment? {
        var low = 0
        var high = segments.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let segment = segments[mid]

            if time >= segment.startTime && time < segment.endTime {
                return segment
            } else if time < segment.startTime {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }

        return nil
    }

    /// Find word at given time
    private func findWord(at time: TimeInterval, in words: [WordTimestamp]) -> WordTimestamp? {
        words.first { time >= $0.startTime && time < $0.endTime }
    }
}

// MARK: - Highlight Sync Provider

/// Environment key for HighlightSyncManager
struct HighlightSyncManagerKey: EnvironmentKey {
    static let defaultValue: HighlightSyncManager? = nil
}

extension EnvironmentValues {
    var highlightSyncManager: HighlightSyncManager? {
        get { self[HighlightSyncManagerKey.self] }
        set { self[HighlightSyncManagerKey.self] = newValue }
    }
}
