import Foundation
import Combine
import UIKit

/// Coordinates a listen session: text supply → speech engine → UI sync.
/// Handles cross-chapter auto-advance and progress persistence.
@MainActor
class ReadAloudCoordinator: ObservableObject {

    // MARK: - Published State

    @Published var state: ReadAloudState = .idle
    @Published var currentChapterId: String?
    @Published var currentParagraphIndex: Int = 0

    // MARK: - Dependencies

    private let textProvider = ChapterTextProvider.shared
    private let ttsEngine = TTSEngine.shared

    // MARK: - Session Context

    private var bookId: String?
    private var bookTitle: String?
    private var chapters: [Chapter] = []
    private var currentChapterIndex: Int = 0
    private var mode: ReadAloudMode = .continuous
    private var cancellables = Set<AnyCancellable>()
    private var progressSaveTimer: Timer?

    // Analytics
    private var sessionStartTime: Date?
    private var sessionParagraphsRead: Int = 0
    private var sessionChaptersCompleted: Int = 0

    // MARK: - Callbacks (for ReaderView)

    var onChapterAdvance: ((String) -> Void)?  // newChapterId
    var onParagraphHighlight: ((Int) -> Void)?  // paragraphIndex

    // MARK: - Init

    init() {
        observeEngine()
        setupBackgroundObserver()
    }

    // MARK: - Observe TTS Engine

    private func observeEngine() {
        // Mirror engine state to coordinator state
        ttsEngine.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] engineState in
                guard let self, self.state != .idle || engineState != .idle else { return }
                switch engineState {
                case .playing: self.state = .playing
                case .paused:
                    self.state = .paused
                    self.savePosition()
                case .idle:
                    if self.state == .loadingNextChapter { return }
                    self.state = .idle
                default: break
                }
            }
            .store(in: &cancellables)

        // Track paragraph changes
        ttsEngine.$currentParagraphIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] index in
                self?.currentParagraphIndex = index
                self?.onParagraphHighlight?(index)
                if self?.sessionStartTime != nil {
                    self?.sessionParagraphsRead += 1
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Start Session

    /// Start a listen session for a book at a given chapter.
    func start(
        bookId: String,
        bookTitle: String,
        chapters: [Chapter],
        chapterIndex: Int,
        mode: ReadAloudMode = .continuous
    ) async {
        // Stop audiobook if playing (mutual exclusion)
        if AudiobookPlayer.shared.state.isPlaying || AudiobookPlayer.shared.state == .paused {
            AudiobookPlayer.shared.stop()
        }

        self.bookId = bookId
        self.bookTitle = bookTitle
        self.chapters = chapters
        self.currentChapterIndex = chapterIndex
        self.mode = mode
        self.state = .loading

        guard chapterIndex < chapters.count else {
            state = .idle
            return
        }

        startProgressSaveTimer()

        // Analytics: session start
        sessionStartTime = Date()
        sessionParagraphsRead = 0
        sessionChaptersCompleted = 0
        let voiceId = ttsEngine.currentVoice?.id ?? "default"
        LoggingService.shared.info(.reading, "[TTS] Session started - bookId=\(bookId), chapterIndex=\(chapterIndex), voiceId=\(voiceId)", component: "ReadAloudCoordinator")

        let chapter = chapters[chapterIndex]
        await loadAndSpeak(chapter: chapter)
    }

    /// Start from a specific paragraph within the current chapter.
    func startFromParagraph(
        bookId: String,
        bookTitle: String,
        chapters: [Chapter],
        chapterIndex: Int,
        paragraphIndex: Int,
        mode: ReadAloudMode = .continuous
    ) async {
        // Stop audiobook if playing (mutual exclusion)
        if AudiobookPlayer.shared.state.isPlaying || AudiobookPlayer.shared.state == .paused {
            AudiobookPlayer.shared.stop()
        }

        self.bookId = bookId
        self.bookTitle = bookTitle
        self.chapters = chapters
        self.currentChapterIndex = chapterIndex
        self.mode = mode
        self.state = .loading

        guard chapterIndex < chapters.count else {
            state = .idle
            return
        }

        startProgressSaveTimer()

        // Analytics: session start from paragraph
        sessionStartTime = Date()
        sessionParagraphsRead = 0
        sessionChaptersCompleted = 0
        let voiceId = ttsEngine.currentVoice?.id ?? "default"
        LoggingService.shared.info(.reading, "[TTS] Session started from paragraph - bookId=\(bookId), chapterIndex=\(chapterIndex), paragraphIndex=\(paragraphIndex), voiceId=\(voiceId)", component: "ReadAloudCoordinator")

        let chapter = chapters[chapterIndex]
        await loadAndSpeak(chapter: chapter, fromParagraph: paragraphIndex)
    }

    // MARK: - Load & Speak

    private func loadAndSpeak(chapter: Chapter, fromParagraph: Int? = nil) async {
        guard let bookId else { return }

        currentChapterId = chapter.id

        do {
            let paragraphs = try await textProvider.fetchParagraphs(
                bookId: bookId,
                chapterId: chapter.id
            )

            // Preload next chapter
            if let nextChapter = nextChapter() {
                textProvider.preloadNextChapter(bookId: bookId, chapterId: nextChapter.id)
            }

            // Set up chapter-end handler for auto-advance
            ttsEngine.onChapterEnd = { [weak self] in
                Task { @MainActor in
                    await self?.handleChapterEnd()
                }
            }

            if let fromParagraph {
                ttsEngine.speakFromParagraph(
                    fromParagraph,
                    paragraphs: paragraphs,
                    chapterId: chapter.id,
                    bookTitle: bookTitle ?? "",
                    chapterTitle: chapter.title
                )
            } else {
                ttsEngine.speakParagraphs(
                    paragraphs,
                    chapterId: chapter.id,
                    bookTitle: bookTitle ?? "",
                    chapterTitle: chapter.title
                )
            }
        } catch {
            state = .idle
        }
    }

    // MARK: - Chapter Navigation

    private func handleChapterEnd() async {
        sessionChaptersCompleted += 1

        guard mode == .continuous, let next = nextChapter() else {
            state = .idle
            savePosition()
            return
        }

        LoggingService.shared.info(.reading, "[TTS] Auto-advancing to next chapter - chapterIndex=\(currentChapterIndex + 1), chapterId=\(next.id)", component: "ReadAloudCoordinator")

        state = .loadingNextChapter
        currentChapterIndex += 1
        onChapterAdvance?(next.id)
        await loadAndSpeak(chapter: next)
    }

    private func nextChapter() -> Chapter? {
        let nextIndex = currentChapterIndex + 1
        guard nextIndex < chapters.count else { return nil }
        return chapters[nextIndex]
    }

    // MARK: - Controls (delegate to engine)

    func pause() { ttsEngine.pause() }
    func resume() { ttsEngine.resume() }
    func togglePlayPause() { ttsEngine.togglePlayPause() }
    func nextSentence() { ttsEngine.nextSentence() }
    func previousSentence() { ttsEngine.previousSentence() }
    func nextParagraph() { ttsEngine.nextParagraph() }
    func previousParagraph() { ttsEngine.previousParagraph() }
    func skipForward() { ttsEngine.skipForward() }
    func skipBackward() { ttsEngine.skipBackward() }

    func goToParagraph(_ index: Int) {
        ttsEngine.goToParagraph(index)
    }

    func stop() {
        // Analytics: session end
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            LoggingService.shared.info(.reading, "[TTS] Session ended - duration=\(Int(duration))s, paragraphsRead=\(sessionParagraphsRead), chaptersCompleted=\(sessionChaptersCompleted)", component: "ReadAloudCoordinator")
            sessionStartTime = nil
        }

        savePosition()
        stopProgressSaveTimer()
        ttsEngine.onChapterEnd = nil
        ttsEngine.stop()
        state = .idle
        bookId = nil
        chapters = []
    }

    // MARK: - Progress Save Timer

    private func startProgressSaveTimer() {
        stopProgressSaveTimer()
        progressSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.savePosition()
            }
        }
    }

    private func stopProgressSaveTimer() {
        progressSaveTimer?.invalidate()
        progressSaveTimer = nil
    }

    private func setupBackgroundObserver() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.savePosition()
            }
        }
    }

    // MARK: - Position Persistence

    private let positionKey = "readAloudLastPosition"

    private func savePosition() {
        guard let bookId else { return }
        if let position = ttsEngine.currentPosition(bookId: bookId),
           let data = try? JSONEncoder().encode(position) {
            UserDefaults.standard.set(data, forKey: positionKey)
        }
    }

    func loadSavedPosition() -> ReadAloudPosition? {
        guard let data = UserDefaults.standard.data(forKey: positionKey) else { return nil }
        return try? JSONDecoder().decode(ReadAloudPosition.self, from: data)
    }
}
