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
    @Published var readAloudProgress: ReadAloudProgress?
    @Published var currentHighlightRange: NSRange?
    @Published var currentSentenceText: String?
    @Published var currentWordText: String?
    @Published var sleepTimerRemaining: TimeInterval?
    @Published var currentParagraphIndex: Int = 0

    // MARK: - Legacy Published (kept for TTSControlView compatibility)

    var progress: TTSProgress? {
        guard let p = readAloudProgress else { return nil }
        return TTSProgress(
            currentWord: currentWordText,
            currentSentence: currentSentenceText,
            currentParagraph: p.currentParagraphIndex,
            totalParagraphs: p.totalParagraphs,
            characterOffset: p.globalSentenceIndex,
            totalCharacters: p.totalSentences
        )
    }

    // MARK: - Callbacks

    var onHighlightChange: ((NSRange, String?) -> Void)?
    var onSentenceChange: ((Int, String) -> Void)?
    var onParagraphChange: ((Int) -> Void)?
    var onChapterEnd: (() -> Void)?
    var onBookEnd: (() -> Void)?

    // MARK: - Paragraph Structure

    private var paragraphs: [ChapterParagraph] = []
    private var paragraphSentences: [[String]] = []  // sentences per paragraph
    private var currentSentenceInParagraph: Int = 0

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
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

        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
                switch type {
                case .began:
                    self.pause()
                case .ended:
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                       AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                        self.resume()
                    }
                @unknown default:
                    break
                }
            }
        }

        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let userInfo = notification.userInfo,
                      let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
                if reason == .oldDeviceUnavailable {
                    self.pause()
                }
            }
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

        if let p = readAloudProgress {
            let elapsed = Double(p.globalSentenceIndex) * 3.0
            let total = Double(p.totalSentences) * 3.0
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = total
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

    // MARK: - Playback Control (Paragraph-based)

    /// Start reading from paragraph array (new API).
    func speakParagraphs(_ paragraphs: [ChapterParagraph], chapterId: String, bookTitle: String, chapterTitle: String) {
        stop()

        self.chapterId = chapterId
        self.paragraphs = paragraphs
        self.paragraphSentences = paragraphs.map { splitIntoSentences($0.text) }
        self.currentParagraphIndex = 0
        self.currentSentenceInParagraph = 0

        guard !paragraphs.isEmpty else { return }

        state = .playing
        speakCurrentSentence()
        updateNowPlayingInfo(title: bookTitle, chapter: chapterTitle)
        updateReadAloudProgress()
    }

    /// Start reading from a specific paragraph index.
    func speakFromParagraph(_ paragraphIndex: Int, paragraphs: [ChapterParagraph], chapterId: String, bookTitle: String, chapterTitle: String) {
        stop()

        self.chapterId = chapterId
        self.paragraphs = paragraphs
        self.paragraphSentences = paragraphs.map { splitIntoSentences($0.text) }
        self.currentParagraphIndex = min(paragraphIndex, paragraphs.count - 1)
        self.currentSentenceInParagraph = 0

        guard !paragraphs.isEmpty else { return }

        state = .playing
        speakCurrentSentence()
        updateNowPlayingInfo(title: bookTitle, chapter: chapterTitle)
        updateReadAloudProgress()
    }

    /// Legacy: start reading from flat text (kept for backward compatibility).
    func speak(text: String, chapterId: String, bookTitle: String, chapterTitle: String) {
        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let paras = lines.enumerated().map { ChapterParagraph(index: $0.offset, text: $0.element) }
        speakParagraphs(paras, chapterId: chapterId, bookTitle: bookTitle, chapterTitle: chapterTitle)
    }

    private func speakCurrentSentence() {
        guard currentParagraphIndex < paragraphSentences.count else {
            onChapterEnd?()
            state = .idle
            return
        }

        let sentencesInParagraph = paragraphSentences[currentParagraphIndex]

        // If we've finished all sentences in this paragraph, advance
        if currentSentenceInParagraph >= sentencesInParagraph.count {
            currentParagraphIndex += 1
            currentSentenceInParagraph = 0
            onParagraphChange?(currentParagraphIndex)

            // Recurse to handle next paragraph (or chapter end)
            speakCurrentSentence()
            return
        }

        let sentence = sentencesInParagraph[currentSentenceInParagraph]
        currentSentenceText = sentence
        onSentenceChange?(globalSentenceIndex, sentence)

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.rate = settings.actualRate
        utterance.pitchMultiplier = settings.pitch
        utterance.volume = settings.volume

        // Add extra pause between paragraphs (at first sentence of new paragraph)
        if currentSentenceInParagraph == 0 && currentParagraphIndex > 0 {
            utterance.preUtteranceDelay = settings.pauseBetweenParagraphs
        }
        utterance.postUtteranceDelay = settings.pauseBetweenSentences

        if let voiceId = settings.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: settings.language) {
            utterance.voice = voice
        }

        synthesizer.speak(utterance)
        updateReadAloudProgress()
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text

        let range = NSRange(location: 0, length: text.utf16.count)

        tagger.enumerateTags(in: range, unit: .sentence, scheme: .tokenType, options: []) { _, tokenRange, _ in
            if let range = Range(tokenRange, in: text) {
                let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
            }
        }

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
        paragraphs = []
        paragraphSentences = []
        currentParagraphIndex = 0
        currentSentenceInParagraph = 0
        currentHighlightRange = nil
        currentSentenceText = nil
        currentWordText = nil
        readAloudProgress = nil
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
        currentSentenceInParagraph += 1

        // Check if we need to advance to next paragraph
        if currentParagraphIndex < paragraphSentences.count &&
           currentSentenceInParagraph >= paragraphSentences[currentParagraphIndex].count {
            currentParagraphIndex += 1
            currentSentenceInParagraph = 0
            onParagraphChange?(currentParagraphIndex)
        }

        state = .playing
        speakCurrentSentence()
    }

    func previousSentence() {
        synthesizer.stopSpeaking(at: .immediate)

        if currentSentenceInParagraph > 0 {
            currentSentenceInParagraph -= 1
        } else if currentParagraphIndex > 0 {
            currentParagraphIndex -= 1
            currentSentenceInParagraph = max(0, paragraphSentences[currentParagraphIndex].count - 1)
            onParagraphChange?(currentParagraphIndex)
        }

        state = .playing
        speakCurrentSentence()
    }

    func nextParagraph() {
        synthesizer.stopSpeaking(at: .immediate)
        currentParagraphIndex = min(currentParagraphIndex + 1, paragraphs.count - 1)
        currentSentenceInParagraph = 0
        onParagraphChange?(currentParagraphIndex)
        state = .playing
        speakCurrentSentence()
    }

    func previousParagraph() {
        synthesizer.stopSpeaking(at: .immediate)
        currentParagraphIndex = max(currentParagraphIndex - 1, 0)
        currentSentenceInParagraph = 0
        onParagraphChange?(currentParagraphIndex)
        state = .playing
        speakCurrentSentence()
    }

    func goToParagraph(_ index: Int) {
        guard index >= 0 && index < paragraphs.count else { return }
        synthesizer.stopSpeaking(at: .immediate)
        currentParagraphIndex = index
        currentSentenceInParagraph = 0
        onParagraphChange?(currentParagraphIndex)
        state = .playing
        speakCurrentSentence()
    }

    func skipForward() {
        synthesizer.stopSpeaking(at: .immediate)
        // Skip ~15 seconds (~4 sentences)
        for _ in 0..<4 {
            currentSentenceInParagraph += 1
            if currentParagraphIndex < paragraphSentences.count &&
               currentSentenceInParagraph >= paragraphSentences[currentParagraphIndex].count {
                currentParagraphIndex += 1
                currentSentenceInParagraph = 0
                if currentParagraphIndex >= paragraphs.count { break }
            }
        }
        currentParagraphIndex = min(currentParagraphIndex, paragraphs.count - 1)
        onParagraphChange?(currentParagraphIndex)
        state = .playing
        speakCurrentSentence()
    }

    func skipBackward() {
        synthesizer.stopSpeaking(at: .immediate)
        for _ in 0..<4 {
            if currentSentenceInParagraph > 0 {
                currentSentenceInParagraph -= 1
            } else if currentParagraphIndex > 0 {
                currentParagraphIndex -= 1
                currentSentenceInParagraph = max(0, paragraphSentences[currentParagraphIndex].count - 1)
            } else {
                break
            }
        }
        onParagraphChange?(currentParagraphIndex)
        state = .playing
        speakCurrentSentence()
    }

    func goToSentence(_ index: Int) {
        // Legacy: map global sentence index to paragraph+sentence
        var remaining = index
        for (pIdx, sentences) in paragraphSentences.enumerated() {
            if remaining < sentences.count {
                currentParagraphIndex = pIdx
                currentSentenceInParagraph = remaining
                synthesizer.stopSpeaking(at: .immediate)
                onParagraphChange?(currentParagraphIndex)
                state = .playing
                speakCurrentSentence()
                return
            }
            remaining -= sentences.count
        }
    }

    // MARK: - Speed Control

    func setRate(_ rate: Float) {
        settings.rate = rate
        saveSettings()

        if state == .playing {
            let pIdx = currentParagraphIndex
            let sIdx = currentSentenceInParagraph
            synthesizer.stopSpeaking(at: .immediate)
            currentParagraphIndex = pIdx
            currentSentenceInParagraph = sIdx
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

    /// Current global sentence index across all paragraphs.
    var globalSentenceIndex: Int {
        var index = 0
        for i in 0..<currentParagraphIndex {
            if i < paragraphSentences.count {
                index += paragraphSentences[i].count
            }
        }
        return index + currentSentenceInParagraph
    }

    /// Total sentences across all paragraphs.
    var totalSentences: Int {
        paragraphSentences.reduce(0) { $0 + $1.count }
    }

    private func updateReadAloudProgress() {
        let sentencesInCurrent = currentParagraphIndex < paragraphSentences.count
            ? paragraphSentences[currentParagraphIndex].count : 0

        readAloudProgress = ReadAloudProgress(
            currentParagraphIndex: currentParagraphIndex,
            totalParagraphs: paragraphs.count,
            currentSentenceInParagraph: currentSentenceInParagraph,
            totalSentencesInParagraph: sentencesInCurrent,
            globalSentenceIndex: globalSentenceIndex,
            totalSentences: totalSentences
        )
    }

    /// Current reading position for persistence.
    func currentPosition(bookId: String) -> ReadAloudPosition? {
        guard let chapterId = chapterId else { return nil }
        return ReadAloudPosition(
            bookId: bookId,
            chapterId: chapterId,
            paragraphIndex: currentParagraphIndex,
            sentenceIndex: currentSentenceInParagraph
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
            currentSentenceInParagraph += 1

            // Check end-of-chapter sleep timer
            let isLastSentence = currentParagraphIndex >= paragraphSentences.count ||
                (currentParagraphIndex == paragraphSentences.count - 1 &&
                 currentSentenceInParagraph >= paragraphSentences[currentParagraphIndex].count)

            if settings.sleepTimerMinutes == -1 && isLastSentence {
                stop()
                return
            }

            speakCurrentSentence()
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
            // Intentional stop — no state change
        }
    }
}
