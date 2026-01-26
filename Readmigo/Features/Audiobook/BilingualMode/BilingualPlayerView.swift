import SwiftUI
import AVFoundation
import Combine

// MARK: - Bilingual Sentence

struct BilingualSentence: Identifiable, Codable {
    var id: String { "\(startTime)" }
    let original: String
    let translated: String
    let originalAudioUrl: String?
    let translatedAudioUrl: String?
    let startTime: Double
    let endTime: Double
}

// MARK: - Bilingual Mode

enum BilingualPlayMode: String, CaseIterable {
    case englishOnly = "English Only"
    case chineseOnly = "Chinese Only"
    case englishThenChinese = "English → Chinese"
    case chineseThenEnglish = "Chinese → English"
    case alternating = "Alternating"

    var icon: String {
        switch self {
        case .englishOnly: return "e.circle"
        case .chineseOnly: return "c.circle"
        case .englishThenChinese: return "arrow.right"
        case .chineseThenEnglish: return "arrow.left"
        case .alternating: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - View Model

@MainActor
class BilingualPlayerViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var sentences: [BilingualSentence] = []
    @Published var currentSentenceIndex: Int = 0
    @Published var playMode: BilingualPlayMode = .englishThenChinese
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var showOriginal: Bool = true
    @Published var showTranslation: Bool = true
    @Published var playbackSpeed: Float = 1.0
    @Published var error: Error?

    // MARK: - Audio Players

    private var englishPlayer: AVPlayer?
    private var chinesePlayer: AVPlayer?
    private var ttsEngine = TTSEngine.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Data

    let audiobook: Audiobook
    let chapterIndex: Int
    let chapterText: String
    let targetLanguage: String

    private let apiClient = APIClient.shared

    // MARK: - Initialization

    init(
        audiobook: Audiobook,
        chapterIndex: Int,
        chapterText: String,
        targetLanguage: String = "zh-CN"
    ) {
        self.audiobook = audiobook
        self.chapterIndex = chapterIndex
        self.chapterText = chapterText
        self.targetLanguage = targetLanguage
    }

    // MARK: - Loading

    func loadBilingualContent() async {
        isLoading = true
        error = nil

        do {
            struct BilingualResponse: Decodable {
                let sentences: [BilingualSentence]
                let totalDuration: Double
            }

            let response: BilingualResponse = try await apiClient.post(
                "/ai/bilingual/chapter",
                body: [
                    "chapterText": chapterText,
                    "targetLanguage": targetLanguage,
                    "generateTTS": false
                ]
            )

            sentences = response.sentences
        } catch {
            self.error = error
            // Fall back to local parsing
            sentences = parseLocalSentences()
        }

        isLoading = false
    }

    private func parseLocalSentences() -> [BilingualSentence] {
        let sentenceTexts = chapterText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var currentTime: Double = 0
        return sentenceTexts.enumerated().map { index, text in
            let duration = Double(text.count) / 15 // Rough estimate: 15 chars per second
            let sentence = BilingualSentence(
                original: text,
                translated: "", // Will be translated on demand
                originalAudioUrl: nil,
                translatedAudioUrl: nil,
                startTime: currentTime,
                endTime: currentTime + duration
            )
            currentTime += duration
            return sentence
        }
    }

    // MARK: - Current Sentence

    var currentSentence: BilingualSentence? {
        sentences[safe: currentSentenceIndex]
    }

    var hasNext: Bool {
        currentSentenceIndex < sentences.count - 1
    }

    var hasPrevious: Bool {
        currentSentenceIndex > 0
    }

    // MARK: - Playback Controls

    func play() {
        isPlaying = true
        playCurrentSentence()
    }

    func pause() {
        isPlaying = false
        ttsEngine.pause()
        englishPlayer?.pause()
        chinesePlayer?.pause()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func next() {
        guard hasNext else { return }
        currentSentenceIndex += 1
        if isPlaying {
            playCurrentSentence()
        }
    }

    func previous() {
        guard hasPrevious else { return }
        currentSentenceIndex -= 1
        if isPlaying {
            playCurrentSentence()
        }
    }

    func goToSentence(_ index: Int) {
        guard index >= 0 && index < sentences.count else { return }
        currentSentenceIndex = index
        if isPlaying {
            playCurrentSentence()
        }
    }

    // MARK: - Sentence Playback

    private func playCurrentSentence() {
        guard let sentence = currentSentence else { return }

        switch playMode {
        case .englishOnly:
            playText(sentence.original, language: "en-US") { [weak self] in
                self?.onSentenceComplete()
            }

        case .chineseOnly:
            if sentence.translated.isEmpty {
                Task {
                    await translateAndPlay(sentence)
                }
            } else {
                playText(sentence.translated, language: "zh-CN") { [weak self] in
                    self?.onSentenceComplete()
                }
            }

        case .englishThenChinese:
            playText(sentence.original, language: "en-US") { [weak self] in
                guard let self = self else { return }
                if sentence.translated.isEmpty {
                    Task {
                        await self.translateAndPlay(sentence)
                    }
                } else {
                    // Small pause between languages
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.playText(sentence.translated, language: "zh-CN") { [weak self] in
                            self?.onSentenceComplete()
                        }
                    }
                }
            }

        case .chineseThenEnglish:
            if sentence.translated.isEmpty {
                Task {
                    let translated = await translateSentence(sentence.original)
                    sentences[currentSentenceIndex] = BilingualSentence(
                        original: sentence.original,
                        translated: translated,
                        originalAudioUrl: sentence.originalAudioUrl,
                        translatedAudioUrl: sentence.translatedAudioUrl,
                        startTime: sentence.startTime,
                        endTime: sentence.endTime
                    )
                    playText(translated, language: "zh-CN") { [weak self] in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.playText(sentence.original, language: "en-US") { [weak self] in
                                self?.onSentenceComplete()
                            }
                        }
                    }
                }
            } else {
                playText(sentence.translated, language: "zh-CN") { [weak self] in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.playText(sentence.original, language: "en-US") { [weak self] in
                            self?.onSentenceComplete()
                        }
                    }
                }
            }

        case .alternating:
            // Alternate between showing one language at a time
            let useEnglish = currentSentenceIndex % 2 == 0
            if useEnglish {
                playText(sentence.original, language: "en-US") { [weak self] in
                    self?.onSentenceComplete()
                }
            } else {
                if sentence.translated.isEmpty {
                    Task {
                        await translateAndPlay(sentence)
                    }
                } else {
                    playText(sentence.translated, language: "zh-CN") { [weak self] in
                        self?.onSentenceComplete()
                    }
                }
            }
        }
    }

    private func translateAndPlay(_ sentence: BilingualSentence) async {
        let translated = await translateSentence(sentence.original)

        // Update sentence with translation
        sentences[currentSentenceIndex] = BilingualSentence(
            original: sentence.original,
            translated: translated,
            originalAudioUrl: sentence.originalAudioUrl,
            translatedAudioUrl: sentence.translatedAudioUrl,
            startTime: sentence.startTime,
            endTime: sentence.endTime
        )

        playText(translated, language: "zh-CN") { [weak self] in
            self?.onSentenceComplete()
        }
    }

    private func translateSentence(_ text: String) async -> String {
        do {
            struct TranslateResponse: Decodable {
                let translated: String
            }

            let response: TranslateResponse = try await apiClient.post(
                "/ai/bilingual/translate",
                body: [
                    "text": text,
                    "targetLanguage": targetLanguage
                ]
            )

            return response.translated
        } catch {
            print("[Bilingual] Translation failed: \(error)")
            return ""
        }
    }

    private func playText(_ text: String, language: String, completion: @escaping () -> Void) {
        ttsEngine.speak(
            text: text,
            chapterId: "\(chapterIndex)",
            bookTitle: audiobook.title,
            chapterTitle: "Bilingual Mode",
            language: language,
            rate: playbackSpeed
        )

        // Monitor TTS completion
        ttsEngine.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if state == .stopped || state == .finished {
                    completion()
                }
            }
            .store(in: &cancellables)
    }

    private func onSentenceComplete() {
        guard isPlaying else { return }

        if hasNext {
            // Small pause between sentences
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.next()
            }
        } else {
            isPlaying = false
        }
    }

    // MARK: - Settings

    func setPlayMode(_ mode: BilingualPlayMode) {
        playMode = mode
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
    }
}

// MARK: - Bilingual Player View

struct BilingualPlayerView: View {
    @StateObject var viewModel: BilingualPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showModeSelector = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.indigo.opacity(0.8), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.isLoading {
                        loadingView
                    } else {
                        // Main content
                        sentenceDisplayArea
                            .padding()

                        Spacer()

                        // Progress
                        progressBar
                            .padding(.horizontal)

                        // Controls
                        controlsArea
                            .padding()
                    }
                }
            }
            .navigationTitle("bilingual.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(BilingualPlayMode.allCases, id: \.self) { mode in
                            Button {
                                viewModel.setPlayMode(mode)
                            } label: {
                                Label(mode.rawValue, systemImage: mode.icon)
                            }
                        }
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .task {
                await viewModel.loadBilingualContent()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("bilingual.preparingContent".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sentence Display

    private var sentenceDisplayArea: some View {
        VStack(spacing: 24) {
            // Mode indicator
            HStack {
                Image(systemName: viewModel.playMode.icon)
                Text(viewModel.playMode.rawValue)
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .cornerRadius(16)

            Spacer()

            if let sentence = viewModel.currentSentence {
                // Original text (English)
                if viewModel.showOriginal {
                    VStack(spacing: 8) {
                        Label("bilingual.english".localized, systemImage: "e.circle")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Text(sentence.original)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(16)
                }

                // Translation (Chinese)
                if viewModel.showTranslation && !sentence.translated.isEmpty {
                    VStack(spacing: 8) {
                        Label("bilingual.chinese".localized, systemImage: "c.circle")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Text(sentence.translated)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                }
            }

            Spacer()
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            // Progress slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(Color.white)
                        .frame(
                            width: viewModel.sentences.isEmpty ? 0 :
                                geometry.size.width * CGFloat(viewModel.currentSentenceIndex + 1) / CGFloat(viewModel.sentences.count),
                            height: 4
                        )
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)

            // Progress text
            HStack {
                Text("bilingual.sentence".localized(with: viewModel.currentSentenceIndex + 1, viewModel.sentences.count))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text("\(Int(Double(viewModel.currentSentenceIndex + 1) / Double(max(1, viewModel.sentences.count)) * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Controls

    private var controlsArea: some View {
        VStack(spacing: 20) {
            // Display toggles
            HStack(spacing: 16) {
                Toggle(isOn: $viewModel.showOriginal) {
                    Text("bilingual.english".localized)
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(.white.opacity(0.3))

                Toggle(isOn: $viewModel.showTranslation) {
                    Text("bilingual.chinese".localized)
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(.white.opacity(0.3))
            }

            // Main playback controls
            HStack(spacing: 40) {
                // Previous
                Button {
                    viewModel.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .disabled(!viewModel.hasPrevious)
                .opacity(viewModel.hasPrevious ? 1 : 0.5)

                // Play/Pause
                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                }

                // Next
                Button {
                    viewModel.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .disabled(!viewModel.hasNext)
                .opacity(viewModel.hasNext ? 1 : 0.5)
            }

            // Speed control
            HStack {
                Text("bilingual.speed".localized)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Picker("bilingual.speed".localized, selection: $viewModel.playbackSpeed) {
                    Text("0.5x").tag(Float(0.5))
                    Text("0.75x").tag(Float(0.75))
                    Text("1x").tag(Float(1.0))
                    Text("1.25x").tag(Float(1.25))
                    Text("1.5x").tag(Float(1.5))
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 250)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(20)
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
