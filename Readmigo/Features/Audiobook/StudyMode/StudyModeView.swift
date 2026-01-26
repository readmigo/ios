import SwiftUI
import Combine

// MARK: - Study Mode Settings

struct StudyModeSettings: Codable {
    var autoPauseOnNewWords: Bool = true
    var showSubtitles: Bool = true
    var highlightNewWords: Bool = true
    var slowPlaybackForNewWords: Bool = false
    var vocabularyPreviewEnabled: Bool = true
    var repeatSentenceOnTap: Bool = true
}

// MARK: - Study Mode View Model

@MainActor
class StudyModeViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var settings = StudyModeSettings()
    @Published var currentSubtitle: String = ""
    @Published var currentWords: [SubtitleWord] = []
    @Published var highlightedWordIndex: Int?
    @Published var isPaused: Bool = false
    @Published var showVocabularyPreview: Bool = true
    @Published var chapterVocabulary: [VocabularyWord] = []
    @Published var masteredWords: Set<String> = []
    @Published var isLoading: Bool = false

    // MARK: - Dependencies

    private let audiobookPlayer = AudiobookPlayer.shared
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    private var sentenceTimer: Timer?

    // MARK: - Audiobook Data

    let audiobook: Audiobook
    let chapterIndex: Int
    let chapterText: String

    // Parsed sentences with timestamps
    private var sentences: [SentenceData] = []
    private var currentSentenceIndex: Int = 0

    // MARK: - Initialization

    init(audiobook: Audiobook, chapterIndex: Int, chapterText: String) {
        self.audiobook = audiobook
        self.chapterIndex = chapterIndex
        self.chapterText = chapterText

        loadSettings()
        parseSentences()
        setupBindings()
    }

    // MARK: - Setup

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "studyModeSettings"),
           let settings = try? JSONDecoder().decode(StudyModeSettings.self, from: data) {
            self.settings = settings
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "studyModeSettings")
        }
    }

    private func parseSentences() {
        // Parse chapter text into sentences with estimated timestamps
        let sentenceTexts = chapterText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let chapter = audiobook.chapters[safe: chapterIndex] else { return }

        let totalChars = sentenceTexts.reduce(0) { $0 + $1.count }
        let charsPerSecond = Double(totalChars) / chapter.duration

        var currentTime: TimeInterval = 0
        sentences = sentenceTexts.map { text in
            let duration = Double(text.count) / charsPerSecond
            let sentence = SentenceData(
                text: text,
                startTime: currentTime,
                endTime: currentTime + duration,
                words: parseWords(text)
            )
            currentTime += duration
            return sentence
        }
    }

    private func parseWords(_ text: String) -> [SubtitleWord] {
        text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { word in
                let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
                return SubtitleWord(
                    text: word,
                    isNewWord: !masteredWords.contains(cleanWord),
                    definition: nil
                )
            }
    }

    private func setupBindings() {
        // Monitor playback position
        audiobookPlayer.$currentPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] position in
                self?.updateSubtitle(for: position)
            }
            .store(in: &cancellables)

        audiobookPlayer.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isPaused = state == .paused
            }
            .store(in: &cancellables)
    }

    // MARK: - Subtitle Updates

    private func updateSubtitle(for position: TimeInterval) {
        // Find current sentence
        guard let sentenceIndex = sentences.firstIndex(where: {
            position >= $0.startTime && position < $0.endTime
        }) else { return }

        if sentenceIndex != currentSentenceIndex {
            currentSentenceIndex = sentenceIndex
            let sentence = sentences[sentenceIndex]
            currentSubtitle = sentence.text
            currentWords = sentence.words

            // Check for new words and auto-pause if enabled
            if settings.autoPauseOnNewWords {
                let hasNewWords = sentence.words.contains { $0.isNewWord }
                if hasNewWords && !isPaused {
                    audiobookPlayer.pause()
                }
            }
        }

        // Update word highlighting based on position within sentence
        if !currentWords.isEmpty {
            let sentence = sentences[currentSentenceIndex]
            let sentenceProgress = (position - sentence.startTime) / (sentence.endTime - sentence.startTime)
            highlightedWordIndex = Int(sentenceProgress * Double(currentWords.count))
        }
    }

    // MARK: - Vocabulary Preview

    func loadChapterVocabulary() async {
        isLoading = true

        do {
            // Get vocabulary for this chapter
            struct VocabularyResponse: Decodable {
                let words: [VocabularyWord]
            }

            let response: VocabularyResponse = try await apiClient.get(
                "/vocabulary/chapter",
                queryParams: [
                    "bookId": audiobook.bookId ?? "",
                    "chapterIndex": String(chapterIndex)
                ]
            )
            chapterVocabulary = response.words
        } catch {
            print("[StudyMode] Failed to load vocabulary: \(error)")
            // Extract vocabulary from text locally
            chapterVocabulary = extractLocalVocabulary()
        }

        isLoading = false
    }

    private func extractLocalVocabulary() -> [VocabularyWord] {
        // Extract unique words and identify potentially difficult ones
        let words = chapterText.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 6 } // Longer words are often more difficult
            .reduce(into: Set<String>()) { $0.insert($1) }

        return words.prefix(20).map { word in
            VocabularyWord(
                word: word,
                definition: nil,
                pronunciation: nil,
                difficulty: .medium
            )
        }
    }

    // MARK: - Word Actions

    func markWordAsMastered(_ word: String) {
        masteredWords.insert(word.lowercased())
        // Update current words
        currentWords = currentWords.map { w in
            var updated = w
            if w.text.lowercased().trimmingCharacters(in: .punctuationCharacters) == word.lowercased() {
                updated.isNewWord = false
            }
            return updated
        }
        // Save to server
        Task {
            await saveMasteredWord(word)
        }
    }

    private func saveMasteredWord(_ word: String) async {
        do {
            let _: EmptyResponse = try await apiClient.post(
                "/vocabulary/mastered",
                body: ["word": word]
            )
        } catch {
            print("[StudyMode] Failed to save mastered word: \(error)")
        }
    }

    func lookupWord(_ word: String) async -> WordDefinition? {
        do {
            let definition: WordDefinition = try await apiClient.get(
                "/ai/explain",
                queryParams: ["word": word]
            )
            return definition
        } catch {
            print("[StudyMode] Failed to lookup word: \(error)")
            return nil
        }
    }

    // MARK: - Playback Controls

    func startStudyMode() {
        showVocabularyPreview = false
        audiobookPlayer.loadAndPlay(
            audiobook: audiobook,
            startChapter: chapterIndex,
            startPosition: 0
        )

        // Apply slow playback if enabled
        if settings.slowPlaybackForNewWords {
            audiobookPlayer.setPlaybackSpeed(.slow)
        }
    }

    func repeatCurrentSentence() {
        guard let sentence = sentences[safe: currentSentenceIndex] else { return }
        audiobookPlayer.seek(to: sentence.startTime)
        audiobookPlayer.play()
    }

    func skipToNextSentence() {
        let nextIndex = currentSentenceIndex + 1
        guard let sentence = sentences[safe: nextIndex] else { return }
        audiobookPlayer.seek(to: sentence.startTime)
    }

    func togglePlayPause() {
        audiobookPlayer.togglePlayPause()
    }

    func dismissVocabularyPreview() {
        showVocabularyPreview = false
    }
}

// MARK: - Supporting Types

struct SentenceData {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let words: [SubtitleWord]
}

struct SubtitleWord: Identifiable {
    let id = UUID()
    let text: String
    var isNewWord: Bool
    var definition: String?
}

struct VocabularyWord: Identifiable, Codable {
    var id: String { word }
    let word: String
    let definition: String?
    let pronunciation: String?
    let difficulty: WordDifficulty
}

enum WordDifficulty: String, Codable {
    case easy
    case medium
    case hard
}

struct WordDefinition: Codable {
    let word: String
    let definition: String
    let pronunciation: String?
    let examples: [String]?
}

struct EmptyResponse: Decodable {}

// MARK: - Study Mode View

struct StudyModeView: View {
    @StateObject var viewModel: StudyModeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var selectedWord: SubtitleWord?
    @State private var wordDefinition: WordDefinition?
    @State private var showWordPopover = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Vocabulary preview
                    if viewModel.showVocabularyPreview && viewModel.settings.vocabularyPreviewEnabled {
                        VocabularyPreviewView(
                            vocabulary: viewModel.chapterVocabulary,
                            isLoading: viewModel.isLoading,
                            onStart: {
                                viewModel.startStudyMode()
                            },
                            onSkip: {
                                viewModel.dismissVocabularyPreview()
                                viewModel.startStudyMode()
                            },
                            onMarkMastered: { word in
                                viewModel.markWordAsMastered(word)
                            }
                        )
                    } else {
                        // Main study mode content
                        studyModeContent
                    }
                }
            }
            .navigationTitle("Study Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                StudyModeSettingsView(settings: $viewModel.settings) {
                    viewModel.saveSettings()
                }
            }
            .sheet(isPresented: $showWordPopover) {
                if let word = selectedWord {
                    WordDetailSheet(
                        word: word.text,
                        definition: wordDefinition,
                        onMarkMastered: {
                            viewModel.markWordAsMastered(word.text)
                            showWordPopover = false
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .task {
                await viewModel.loadChapterVocabulary()
            }
        }
    }

    // MARK: - Study Mode Content

    private var studyModeContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Subtitles area
            if viewModel.settings.showSubtitles {
                subtitlesView
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }

            // Playback controls
            playbackControls
                .padding()
                .background(Color.black.opacity(0.8))
        }
    }

    private var subtitlesView: some View {
        VStack(spacing: 16) {
            // Sentence number indicator
            Text("Sentence \(viewModel.sentences.firstIndex(where: { $0.text == viewModel.currentSubtitle }) ?? 0 + 1)")
                .font(.caption)
                .foregroundColor(.gray)

            // Interactive subtitle with tappable words
            FlowLayout(spacing: 8) {
                ForEach(Array(viewModel.currentWords.enumerated()), id: \.element.id) { index, word in
                    Text(word.text)
                        .font(.title2)
                        .fontWeight(index == viewModel.highlightedWordIndex ? .bold : .regular)
                        .foregroundColor(wordColor(for: word, isHighlighted: index == viewModel.highlightedWordIndex))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            word.isNewWord && viewModel.settings.highlightNewWords
                                ? Color.yellow.opacity(0.3)
                                : Color.clear
                        )
                        .cornerRadius(4)
                        .onTapGesture {
                            handleWordTap(word)
                        }
                }
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
        }
    }

    private func wordColor(for word: SubtitleWord, isHighlighted: Bool) -> Color {
        if isHighlighted {
            return .white
        } else if word.isNewWord && viewModel.settings.highlightNewWords {
            return .yellow
        } else {
            return .gray
        }
    }

    private func handleWordTap(_ word: SubtitleWord) {
        if viewModel.settings.repeatSentenceOnTap {
            viewModel.repeatCurrentSentence()
        }

        selectedWord = word
        Task {
            wordDefinition = await viewModel.lookupWord(word.text)
            showWordPopover = true
        }
    }

    private var playbackControls: some View {
        VStack(spacing: 20) {
            // Progress indicator
            HStack {
                Text(viewModel.currentSubtitle.isEmpty ? "--" : "Playing...")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }

            // Main controls
            HStack(spacing: 40) {
                // Repeat sentence
                Button {
                    viewModel.repeatCurrentSentence()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                // Play/Pause
                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                }

                // Skip to next sentence
                Button {
                    viewModel.skipToNextSentence()
                } label: {
                    Image(systemName: "forward.end")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + lineHeight
        }
    }
}

// MARK: - Word Detail Sheet

struct WordDetailSheet: View {
    let word: String
    let definition: WordDefinition?
    let onMarkMastered: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Word
                Text(word)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Pronunciation
                if let pronunciation = definition?.pronunciation {
                    Text(pronunciation)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Definition
                if let def = definition?.definition {
                    Text(def)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ProgressView()
                        .padding()
                }

                // Examples
                if let examples = definition?.examples, !examples.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Examples")
                            .font(.headline)

                        ForEach(examples, id: \.self) { example in
                            Text("• \(example)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }

                Spacer()

                // Mark as mastered
                Button {
                    onMarkMastered()
                } label: {
                    Label("I know this word", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Word Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Study Mode Settings View

struct StudyModeSettingsView: View {
    @Binding var settings: StudyModeSettings
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    Toggle("Auto-pause on new words", isOn: $settings.autoPauseOnNewWords)
                    Toggle("Slow playback for new words", isOn: $settings.slowPlaybackForNewWords)
                    Toggle("Repeat sentence on word tap", isOn: $settings.repeatSentenceOnTap)
                }

                Section("Display") {
                    Toggle("Show subtitles", isOn: $settings.showSubtitles)
                    Toggle("Highlight new words", isOn: $settings.highlightNewWords)
                }

                Section("Vocabulary") {
                    Toggle("Show vocabulary preview", isOn: $settings.vocabularyPreviewEnabled)
                }
            }
            .navigationTitle("Study Mode Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
