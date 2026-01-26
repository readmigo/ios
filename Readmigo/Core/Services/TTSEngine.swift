import Foundation
import AVFoundation
import Combine
import MediaPlayer

@MainActor
class TTSEngine: NSObject, ObservableObject {
    static let shared = TTSEngine()

    // MARK: - Published Properties

    @Published var state: TTSState = .idle
    @Published var settings: TTSSettings = .default
    @Published var availableVoices: [TTSVoice] = []
    @Published var currentVoice: TTSVoice?
    @Published var progress: TTSProgress?
    @Published var currentHighlightRange: NSRange?
    @Published var currentSentenceText: String?
    @Published var currentWordText: String?
    @Published var sleepTimerRemaining: TimeInterval?

    // MARK: - Callbacks

    var onHighlightChange: ((NSRange, String?) -> Void)?
    var onSentenceChange: ((Int, String) -> Void)?
    var onParagraphChange: ((Int) -> Void)?
    var onChapterEnd: (() -> Void)?
    var onBookEnd: (() -> Void)?

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterances: [AVSpeechUtterance] = []
    private var currentUtteranceIndex = 0
    private var sentences: [String] = []
    private var currentSentenceIndex = 0
    private var chapterId: String?
    private var sleepTimer: Timer?
    private var sleepTimerEndTime: Date?
    private let userDefaultsKey = "ttsSettings"

    // MARK: - Audio Session

    private var audioSession: AVAudioSession {
        AVAudioSession.sharedInstance()
    }

    // MARK: - Initialization

    override init() {
        super.init()
        synthesizer.delegate = self
        loadSettings()
        loadAvailableVoices()
        setupAudioSession()
        setupRemoteControls()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Remote Controls (Lock Screen, Control Center)

    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextSentence()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousSentence()
            return .success
        }
    }

    private func updateNowPlayingInfo(title: String, chapter: String) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = chapter
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Readmigo"
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = state == .playing ? 1.0 : 0.0

        if let progress = progress {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(progress.characterOffset) / 15.0
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(progress.totalCharacters) / 15.0
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Settings

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(TTSSettings.self, from: data) {
            settings = decoded
        }
    }

    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func updateSettings(_ newSettings: TTSSettings) {
        settings = newSettings
        saveSettings()

        // Apply voice change if needed
        if let voiceId = newSettings.voiceIdentifier {
            currentVoice = availableVoices.first { $0.id == voiceId }
        }
    }

    // MARK: - Voice Management

    private func loadAvailableVoices() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        availableVoices = voices
            .filter { $0.language.hasPrefix(settings.language.prefix(2)) }
            .map { TTSVoice.fromAVVoice($0) }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }

        // Set default voice
        if let voiceId = settings.voiceIdentifier,
           let voice = availableVoices.first(where: { $0.id == voiceId }) {
            currentVoice = voice
        } else if let defaultVoice = availableVoices.first {
            currentVoice = defaultVoice
            settings.voiceIdentifier = defaultVoice.id
        }
    }

    func setVoice(_ voice: TTSVoice) {
        currentVoice = voice
        settings.voiceIdentifier = voice.id
        saveSettings()
    }

    func getVoices(for language: String) -> [TTSVoice] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices
            .filter { $0.language.hasPrefix(language.prefix(2)) }
            .map { TTSVoice.fromAVVoice($0) }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
    }

    // MARK: - Playback Control

    func speak(text: String, chapterId: String, bookTitle: String, chapterTitle: String) {
        stop()

        self.chapterId = chapterId
        self.sentences = splitIntoSentences(text)
        self.currentSentenceIndex = 0

        if sentences.isEmpty { return }

        state = .playing
        speakCurrentSentence()
        updateNowPlayingInfo(title: bookTitle, chapter: chapterTitle)

        // Update progress
        updateProgress(text: text)
    }

    func speakFromPosition(_ position: Int, text: String, chapterId: String, bookTitle: String, chapterTitle: String) {
        stop()

        self.chapterId = chapterId
        self.sentences = splitIntoSentences(text)

        // Find sentence containing position
        var charCount = 0
        for (index, sentence) in sentences.enumerated() {
            if charCount + sentence.count >= position {
                self.currentSentenceIndex = index
                break
            }
            charCount += sentence.count
        }

        state = .playing
        speakCurrentSentence()
        updateNowPlayingInfo(title: bookTitle, chapter: chapterTitle)
        updateProgress(text: text)
    }

    private func speakCurrentSentence() {
        guard currentSentenceIndex < sentences.count else {
            onChapterEnd?()
            state = .idle
            return
        }

        let sentence = sentences[currentSentenceIndex]
        currentSentenceText = sentence
        onSentenceChange?(currentSentenceIndex, sentence)

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.rate = settings.actualRate
        utterance.pitchMultiplier = settings.pitch
        utterance.volume = settings.volume
        utterance.postUtteranceDelay = settings.pauseBetweenSentences

        if let voiceId = settings.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: settings.language) {
            utterance.voice = voice
        }

        synthesizer.speak(utterance)
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text

        let range = NSRange(location: 0, length: text.utf16.count)
        var currentSentence = ""

        tagger.enumerateTags(in: range, unit: .sentence, scheme: .tokenType, options: []) { _, tokenRange, _ in
            if let range = Range(tokenRange, in: text) {
                let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
            }
        }

        // Fallback if no sentences detected
        if sentences.isEmpty && !text.isEmpty {
            sentences = [text]
        }

        return sentences
    }

    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
            state = .paused
        }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            state = .playing
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
        currentSentenceIndex = 0
        sentences = []
        currentHighlightRange = nil
        currentSentenceText = nil
        currentWordText = nil
        stopSleepTimer()
    }

    func togglePlayPause() {
        switch state {
        case .playing:
            pause()
        case .paused:
            resume()
        default:
            break
        }
    }

    // MARK: - Navigation

    func nextSentence() {
        synthesizer.stopSpeaking(at: .immediate)
        currentSentenceIndex = min(currentSentenceIndex + 1, sentences.count - 1)
        state = .playing
        speakCurrentSentence()
    }

    func previousSentence() {
        synthesizer.stopSpeaking(at: .immediate)
        currentSentenceIndex = max(currentSentenceIndex - 1, 0)
        state = .playing
        speakCurrentSentence()
    }

    func skipForward() {
        // Skip ~15 seconds worth of sentences (approximately 3-4 sentences)
        synthesizer.stopSpeaking(at: .immediate)
        currentSentenceIndex = min(currentSentenceIndex + 4, sentences.count - 1)
        state = .playing
        speakCurrentSentence()
    }

    func skipBackward() {
        synthesizer.stopSpeaking(at: .immediate)
        currentSentenceIndex = max(currentSentenceIndex - 4, 0)
        state = .playing
        speakCurrentSentence()
    }

    func goToSentence(_ index: Int) {
        guard index >= 0 && index < sentences.count else { return }
        synthesizer.stopSpeaking(at: .immediate)
        currentSentenceIndex = index
        state = .playing
        speakCurrentSentence()
    }

    // MARK: - Speed Control

    func setRate(_ rate: Float) {
        settings.rate = rate
        saveSettings()

        // If currently speaking, restart with new rate
        if state == .playing {
            let currentIndex = currentSentenceIndex
            synthesizer.stopSpeaking(at: .immediate)
            currentSentenceIndex = currentIndex
            speakCurrentSentence()
        }
    }

    func increaseRate() {
        settings.rate = min(settings.rate + 0.1, 1.0)
        saveSettings()
    }

    func decreaseRate() {
        settings.rate = max(settings.rate - 0.1, 0.0)
        saveSettings()
    }

    // MARK: - Sleep Timer

    func setSleepTimer(_ option: SleepTimerOption) {
        stopSleepTimer()

        guard option != .off else {
            settings.sleepTimerMinutes = nil
            sleepTimerRemaining = nil
            return
        }

        if option == .endOfChapter {
            settings.sleepTimerMinutes = -1
            sleepTimerRemaining = nil
            // Will stop at chapter end via callback
            return
        }

        settings.sleepTimerMinutes = option.rawValue
        let duration = TimeInterval(option.rawValue * 60)
        sleepTimerEndTime = Date().addingTimeInterval(duration)
        sleepTimerRemaining = duration

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSleepTimer()
            }
        }
    }

    private func updateSleepTimer() {
        guard let endTime = sleepTimerEndTime else { return }

        let remaining = endTime.timeIntervalSinceNow
        if remaining <= 0 {
            stopSleepTimer()
            pause()
        } else {
            sleepTimerRemaining = remaining
        }
    }

    private func stopSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndTime = nil
        sleepTimerRemaining = nil
    }

    // MARK: - Progress

    private func updateProgress(text: String) {
        let totalChars = text.count
        var currentOffset = 0

        for i in 0..<currentSentenceIndex {
            if i < sentences.count {
                currentOffset += sentences[i].count
            }
        }

        progress = TTSProgress(
            currentWord: currentWordText,
            currentSentence: currentSentenceText,
            currentParagraph: 0,
            totalParagraphs: 1,
            characterOffset: currentOffset,
            totalCharacters: totalChars
        )
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            state = .playing
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Move to next sentence
            currentSentenceIndex += 1

            // Check if end of chapter sleep timer
            if settings.sleepTimerMinutes == -1 && currentSentenceIndex >= sentences.count {
                stop()
                return
            }

            if currentSentenceIndex < sentences.count {
                speakCurrentSentence()
            } else {
                onChapterEnd?()
                state = .idle
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            state = .paused
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            state = .playing
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Highlight current word
            if settings.highlightMode == .word {
                currentHighlightRange = characterRange
                let nsString = utterance.speechString as NSString
                let word = nsString.substring(with: characterRange)
                currentWordText = word
                onHighlightChange?(characterRange, word)
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Don't change state here as it might be intentional stop
        }
    }
}
