import Foundation
import Combine

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

    // MARK: - Callbacks (for ReaderView)

    var onChapterAdvance: ((String) -> Void)?  // newChapterId
    var onParagraphHighlight: ((Int) -> Void)?  // paragraphIndex

    // MARK: - Init

    init() {
        observeEngine()
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
                case .paused: self.state = .paused
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
        guard mode == .continuous, let next = nextChapter() else {
            state = .idle
            savePosition()
            return
        }

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
        savePosition()
        ttsEngine.onChapterEnd = nil
        ttsEngine.stop()
        state = .idle
        bookId = nil
        chapters = []
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
