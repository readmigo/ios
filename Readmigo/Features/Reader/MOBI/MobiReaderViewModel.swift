import Foundation
import Combine

/// ViewModel for MOBI Reader
class MobiReaderViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var document: ParsedMobiDocument?
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentChapterIndex: Int = 0
    @Published var fontSize: CGFloat = 18

    // MARK: - Computed Properties

    var totalChapters: Int {
        document?.chapters.count ?? 0
    }

    var progress: Double {
        guard totalChapters > 0 else { return 0 }
        return Double(currentChapterIndex + 1) / Double(totalChapters)
    }

    var currentChapter: ParsedMobiChapter? {
        guard let document = document,
              currentChapterIndex >= 0,
              currentChapterIndex < document.chapters.count else {
            return nil
        }
        return document.chapters[currentChapterIndex]
    }

    var metadata: MobiMetadata? {
        document?.metadata
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Load document from URL
    func loadDocument(from url: URL) {
        isLoading = true
        error = nil

        Task { @MainActor in
            do {
                let doc = try await MobiParser.parse(url: url)
                self.document = doc
                self.isLoading = false
            } catch {
                self.error = "Failed to load document: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// Load document from data
    func loadDocument(from data: Data) {
        isLoading = true
        error = nil

        Task { @MainActor in
            do {
                let doc = try MobiParser.parse(data: data)
                self.document = doc
                self.isLoading = false
            } catch {
                self.error = "Failed to parse document: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// Navigate to specific chapter
    func goToChapter(_ index: Int) {
        guard index >= 0, index < totalChapters else { return }
        currentChapterIndex = index
    }

    /// Go to next chapter
    func nextChapter() {
        if currentChapterIndex < totalChapters - 1 {
            currentChapterIndex += 1
        }
    }

    /// Go to previous chapter
    func previousChapter() {
        if currentChapterIndex > 0 {
            currentChapterIndex -= 1
        }
    }

    /// Go to first chapter
    func firstChapter() {
        currentChapterIndex = 0
    }

    /// Go to last chapter
    func lastChapter() {
        if totalChapters > 0 {
            currentChapterIndex = totalChapters - 1
        }
    }

    /// Update font size
    func setFontSize(_ size: CGFloat) {
        fontSize = max(12, min(36, size))
    }

    /// Increase font size
    func increaseFontSize() {
        setFontSize(fontSize + 2)
    }

    /// Decrease font size
    func decreaseFontSize() {
        setFontSize(fontSize - 2)
    }

    /// Search for text in document
    func search(text: String) -> [(chapterIndex: Int, occurrences: [Range<String.Index>])] {
        guard let document = document, !text.isEmpty else { return [] }

        var results: [(chapterIndex: Int, occurrences: [Range<String.Index>])] = []

        for (index, chapter) in document.chapters.enumerated() {
            var occurrences: [Range<String.Index>] = []
            var searchRange = chapter.content.startIndex..<chapter.content.endIndex

            while let range = chapter.content.range(of: text, options: .caseInsensitive, range: searchRange) {
                occurrences.append(range)
                searchRange = range.upperBound..<chapter.content.endIndex
            }

            if !occurrences.isEmpty {
                results.append((chapterIndex: index, occurrences: occurrences))
            }
        }

        return results
    }

    /// Get text content for TTS
    func getTextForTTS() -> String? {
        return currentChapter?.content
    }
}
