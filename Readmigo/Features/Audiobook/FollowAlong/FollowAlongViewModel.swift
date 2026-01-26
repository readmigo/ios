import Foundation
import Combine
import AVFoundation

// MARK: - Follow Along Mode

enum FollowAlongMode {
    case listening      // User listens to audiobook
    case recording      // User records their speech
    case reviewing      // User reviews comparison
}

// MARK: - Sentence

struct FollowAlongSentence: Identifiable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    var userRecording: RecordingResult?
    var comparisonResult: TextComparisonResult?
    var pronunciationScore: PronunciationScore?
}

// MARK: - Pronunciation Score

struct PronunciationScore: Codable {
    let overall: Double          // 0-100
    let accuracy: Double         // 0-100
    let fluency: Double          // 0-100
    let rhythm: Double           // 0-100
    let wordScores: [WordScore]
    let feedback: String
}

struct WordScore: Codable {
    let word: String
    let score: Double
    let feedback: String?
}

// MARK: - View Model

@MainActor
class FollowAlongViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var mode: FollowAlongMode = .listening
    @Published var sentences: [FollowAlongSentence] = []
    @Published var currentSentenceIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var isRecording: Bool = false
    @Published var showResults: Bool = false
    @Published var overallScore: Double = 0
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - Dependencies

    @Published var speechRecorder = SpeechRecorder()
    private let audiobookPlayer = AudiobookPlayer.shared
    private var audioPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Audiobook Data

    let audiobook: Audiobook
    let chapterIndex: Int
    let chapterText: String

    // MARK: - Initialization

    init(audiobook: Audiobook, chapterIndex: Int, chapterText: String) {
        self.audiobook = audiobook
        self.chapterIndex = chapterIndex
        self.chapterText = chapterText

        parseSentences()
        setupBindings()
    }

    // MARK: - Setup

    private func parseSentences() {
        // Parse chapter text into sentences
        let sentencePatterns = chapterText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Estimate timing based on chapter duration and sentence lengths
        guard let chapter = audiobook.chapters[safe: chapterIndex] else { return }

        let totalChars = sentencePatterns.reduce(0) { $0 + $1.count }
        let charsPerSecond = Double(totalChars) / Double(chapter.duration)

        var currentTime: TimeInterval = 0
        sentences = sentencePatterns.enumerated().map { index, text in
            let duration = Double(text.count) / charsPerSecond
            let sentence = FollowAlongSentence(
                text: text,
                startTime: currentTime,
                endTime: currentTime + duration
            )
            currentTime += duration
            return sentence
        }
    }

    private func setupBindings() {
        speechRecorder.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .recording:
                    self?.isRecording = true
                case .finished, .idle, .error:
                    self?.isRecording = false
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Current Sentence

    var currentSentence: FollowAlongSentence? {
        sentences[safe: currentSentenceIndex]
    }

    var hasNextSentence: Bool {
        currentSentenceIndex < sentences.count - 1
    }

    var hasPreviousSentence: Bool {
        currentSentenceIndex > 0
    }

    // MARK: - Playback Controls

    func playCurrentSentence() async {
        guard let sentence = currentSentence,
              let chapter = audiobook.chapters[safe: chapterIndex] else { return }

        isPlaying = true

        // Seek to sentence start and play
        audiobookPlayer.loadAndPlay(
            audiobook: audiobook,
            startChapter: chapterIndex,
            startPosition: sentence.startTime
        )

        // Schedule stop at sentence end
        let duration = sentence.endTime - sentence.startTime
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        if isPlaying {
            audiobookPlayer.pause()
            isPlaying = false
        }
    }

    func stopPlayback() {
        audiobookPlayer.pause()
        isPlaying = false
    }

    // MARK: - Recording Controls

    func startRecording() async {
        mode = .recording
        do {
            try await speechRecorder.startRecording()
        } catch {
            self.error = error
            mode = .listening
        }
    }

    func stopRecording() async {
        guard let result = await speechRecorder.stopRecording() else { return }

        // Store result
        sentences[currentSentenceIndex].userRecording = result

        // Compare with original text
        let comparison = SpeechRecorder.compareTexts(
            original: currentSentence?.text ?? "",
            spoken: result.transcript
        )
        sentences[currentSentenceIndex].comparisonResult = comparison

        mode = .reviewing
    }

    func cancelRecording() {
        speechRecorder.cancelRecording()
        mode = .listening
    }

    // MARK: - Navigation

    func nextSentence() {
        guard hasNextSentence else { return }
        currentSentenceIndex += 1
        mode = .listening
        speechRecorder.reset()
    }

    func previousSentence() {
        guard hasPreviousSentence else { return }
        currentSentenceIndex -= 1
        mode = .listening
        speechRecorder.reset()
    }

    func goToSentence(_ index: Int) {
        guard index >= 0 && index < sentences.count else { return }
        currentSentenceIndex = index
        mode = .listening
        speechRecorder.reset()
    }

    // MARK: - Play User Recording

    func playUserRecording() async {
        guard let recording = currentSentence?.userRecording else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recording.audioURL)
            audioPlayer?.play()
        } catch {
            self.error = error
        }
    }

    // MARK: - AI Pronunciation Scoring

    func requestPronunciationScore() async {
        guard let recording = currentSentence?.userRecording else { return }

        isLoading = true

        do {
            // Read audio file data
            let audioData = try Data(contentsOf: recording.audioURL)

            // Call AI service for pronunciation scoring
            let score = try await PronunciationScoringService.shared.score(
                audioData: audioData,
                originalText: currentSentence?.text ?? "",
                spokenText: recording.transcript
            )

            sentences[currentSentenceIndex].pronunciationScore = score
            updateOverallScore()

        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Overall Score

    private func updateOverallScore() {
        let scoredSentences = sentences.compactMap { $0.pronunciationScore }
        guard !scoredSentences.isEmpty else {
            overallScore = 0
            return
        }
        overallScore = scoredSentences.reduce(0) { $0 + $1.overall } / Double(scoredSentences.count)
    }

    // MARK: - Session Summary

    func getSessionSummary() -> FollowAlongSummary {
        let completed = sentences.filter { $0.userRecording != nil }
        let scored = sentences.compactMap { $0.pronunciationScore }

        return FollowAlongSummary(
            totalSentences: sentences.count,
            completedSentences: completed.count,
            averageAccuracy: scored.isEmpty ? 0 : scored.reduce(0) { $0 + $1.accuracy } / Double(scored.count),
            averageFluency: scored.isEmpty ? 0 : scored.reduce(0) { $0 + $1.fluency } / Double(scored.count),
            averageRhythm: scored.isEmpty ? 0 : scored.reduce(0) { $0 + $1.rhythm } / Double(scored.count),
            overallScore: overallScore,
            practiceTime: completed.reduce(0) { $0 + ($1.userRecording?.duration ?? 0) }
        )
    }
}

// MARK: - Session Summary

struct FollowAlongSummary {
    let totalSentences: Int
    let completedSentences: Int
    let averageAccuracy: Double
    let averageFluency: Double
    let averageRhythm: Double
    let overallScore: Double
    let practiceTime: TimeInterval
}

// MARK: - Pronunciation Scoring Service

class PronunciationScoringService {
    static let shared = PronunciationScoringService()
    private let apiClient = APIClient.shared

    private init() {}

    func score(audioData: Data, originalText: String, spokenText: String) async throws -> PronunciationScore {
        // Prepare multipart form data
        let base64Audio = audioData.base64EncodedString()

        struct ScoringRequest: Encodable {
            let audioBase64: String
            let originalText: String
            let spokenText: String
        }

        struct ScoringResponse: Decodable {
            let overall: Double
            let accuracy: Double
            let fluency: Double
            let rhythm: Double
            let wordScores: [WordScore]
            let feedback: String
        }

        let request = ScoringRequest(
            audioBase64: base64Audio,
            originalText: originalText,
            spokenText: spokenText
        )

        let response: ScoringResponse = try await apiClient.request(
            endpoint: "/ai/pronunciation/score",
            method: .post,
            body: request
        )

        return PronunciationScore(
            overall: response.overall,
            accuracy: response.accuracy,
            fluency: response.fluency,
            rhythm: response.rhythm,
            wordScores: response.wordScores,
            feedback: response.feedback
        )
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
