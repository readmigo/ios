import Foundation
import AVFoundation
import Speech
import Combine

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case processing
    case finished
    case error(Error)

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparing, .preparing),
             (.recording, .recording),
             (.processing, .processing),
             (.finished, .finished):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

// MARK: - Recording Result

struct RecordingResult {
    let audioURL: URL
    let transcript: String
    let duration: TimeInterval
    let confidence: Float
    let segments: [TranscriptSegment]
}

struct TranscriptSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
}

// MARK: - Speech Recorder

@MainActor
class SpeechRecorder: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var state: RecordingState = .idle
    @Published var currentTranscript: String = ""
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var isAuthorized: Bool = false

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var audioRecorder: AVAudioRecorder?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    private var segments: [TranscriptSegment] = []
    private var levelTimer: Timer?

    private let audioSession = AVAudioSession.sharedInstance()

    // MARK: - Initialization

    override init() {
        super.init()
        setupSpeechRecognizer()
    }

    // MARK: - Setup

    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        // Request microphone permission
        let micStatus = await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micStatus else {
            isAuthorized = false
            return false
        }

        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        isAuthorized = speechStatus
        return speechStatus
    }

    // MARK: - Recording Controls

    func startRecording() async throws {
        if !isAuthorized {
            let authorized = await requestAuthorization()
            guard authorized else {
                state = .error(SpeechRecorderError.notAuthorized)
                return
            }
        }

        state = .preparing

        do {
            // Configure audio session
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Create recording URL
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
            recordingURL = documentsPath.appendingPathComponent(fileName)

            // Setup audio engine for real-time recognition
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else {
                throw SpeechRecorderError.audioEngineError
            }

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                throw SpeechRecorderError.recognitionRequestError
            }

            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false

            // Setup audio recorder for saving audio file
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.isMeteringEnabled = true

            // Start recognition task
            segments = []
            currentTranscript = ""

            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let result = result {
                        self.currentTranscript = result.bestTranscription.formattedString

                        // Extract segments
                        self.segments = result.bestTranscription.segments.map { segment in
                            TranscriptSegment(
                                text: segment.substring,
                                startTime: segment.timestamp,
                                endTime: segment.timestamp + segment.duration,
                                confidence: segment.confidence
                            )
                        }

                        if result.isFinal {
                            self.state = .processing
                        }
                    }

                    if let error = error {
                        print("[SpeechRecorder] Recognition error: \(error)")
                        if self.state == .recording {
                            // Don't set error state if we stopped intentionally
                        }
                    }
                }
            }

            // Install tap for recognition
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            // Start audio engine
            audioEngine.prepare()
            try audioEngine.start()

            // Start recorder
            audioRecorder?.record()
            recordingStartTime = Date()

            // Start level metering
            startLevelMetering()

            state = .recording

        } catch {
            state = .error(error)
            throw error
        }
    }

    func stopRecording() async -> RecordingResult? {
        guard state == .recording else { return nil }

        state = .processing

        // Stop level metering
        stopLevelMetering()

        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        // Stop recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        // Stop recorder
        audioRecorder?.stop()

        // Calculate duration
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())

        // Calculate average confidence
        let avgConfidence = segments.isEmpty ? 0 : segments.reduce(0) { $0 + $1.confidence } / Float(segments.count)

        // Deactivate audio session
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        state = .finished

        guard let url = recordingURL else { return nil }

        return RecordingResult(
            audioURL: url,
            transcript: currentTranscript,
            duration: duration,
            confidence: avgConfidence,
            segments: segments
        )
    }

    func cancelRecording() {
        stopLevelMetering()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioRecorder?.stop()

        // Delete recording file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        currentTranscript = ""
        segments = []
        state = .idle
    }

    // MARK: - Audio Level Metering

    private func startLevelMetering() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                // Normalize from dB (-160 to 0) to 0-1 range
                self.audioLevel = max(0, min(1, (power + 50) / 50))
                self.recordingDuration = Date().timeIntervalSince(self.recordingStartTime ?? Date())
            }
        }
    }

    private func stopLevelMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
    }

    // MARK: - Playback

    func playRecording() async throws {
        guard let url = recordingURL else {
            throw SpeechRecorderError.noRecording
        }

        let player = try AVAudioPlayer(contentsOf: url)
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        player.play()
    }

    // MARK: - Cleanup

    func reset() {
        cancelRecording()
        recordingURL = nil
        recordingDuration = 0
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecorder: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                state = .error(SpeechRecorderError.recognizerUnavailable)
            }
        }
    }
}

// MARK: - Errors

enum SpeechRecorderError: LocalizedError {
    case notAuthorized
    case audioEngineError
    case recognitionRequestError
    case recognizerUnavailable
    case noRecording

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Microphone and speech recognition permissions are required"
        case .audioEngineError:
            return "Failed to initialize audio engine"
        case .recognitionRequestError:
            return "Failed to create recognition request"
        case .recognizerUnavailable:
            return "Speech recognition is not available"
        case .noRecording:
            return "No recording available"
        }
    }
}

// MARK: - Text Comparison

struct TextComparisonResult {
    let originalText: String
    let spokenText: String
    let accuracy: Double
    let matchedWords: [WordMatch]
    let missedWords: [String]
    let extraWords: [String]
}

struct WordMatch {
    let word: String
    let isCorrect: Bool
    let spokenAs: String?
}

extension SpeechRecorder {
    /// Compare spoken text with original text
    static func compareTexts(original: String, spoken: String) -> TextComparisonResult {
        let originalWords = original.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }

        let spokenWords = spoken.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }

        var matchedWords: [WordMatch] = []
        var missedWords: [String] = []
        var spokenSet = Set(spokenWords)

        for word in originalWords {
            if spokenSet.contains(word) {
                matchedWords.append(WordMatch(word: word, isCorrect: true, spokenAs: nil))
                spokenSet.remove(word)
            } else {
                // Check for similar words (fuzzy match)
                let similarWord = findSimilarWord(word, in: Array(spokenSet))
                if let similar = similarWord {
                    matchedWords.append(WordMatch(word: word, isCorrect: false, spokenAs: similar))
                    spokenSet.remove(similar)
                } else {
                    missedWords.append(word)
                }
            }
        }

        let extraWords = Array(spokenSet)
        let correctCount = matchedWords.filter { $0.isCorrect }.count
        let accuracy = originalWords.isEmpty ? 0 : Double(correctCount) / Double(originalWords.count)

        return TextComparisonResult(
            originalText: original,
            spokenText: spoken,
            accuracy: accuracy,
            matchedWords: matchedWords,
            missedWords: missedWords,
            extraWords: extraWords
        )
    }

    private static func findSimilarWord(_ target: String, in words: [String]) -> String? {
        // Simple Levenshtein distance-based similarity
        for word in words {
            let distance = levenshteinDistance(target, word)
            let maxLen = max(target.count, word.count)
            if maxLen > 0 && Double(distance) / Double(maxLen) < 0.3 {
                return word
            }
        }
        return nil
    }

    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        let m = s1.count
        let n = s2.count

        if m == 0 { return n }
        if n == 0 { return m }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                if s1[i - 1] == s2[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]) + 1
                }
            }
        }

        return dp[m][n]
    }
}
