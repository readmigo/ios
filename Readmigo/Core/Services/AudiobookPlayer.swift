import Foundation
import AVFoundation
import Combine
import MediaPlayer

// MARK: - Player State

enum AudiobookPlayerState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case error(String)

    var isPlaying: Bool {
        self == .playing
    }

    var isActive: Bool {
        switch self {
        case .playing, .paused, .loading:
            return true
        default:
            return false
        }
    }
}

// MARK: - AudiobookPlayer

@MainActor
class AudiobookPlayer: NSObject, ObservableObject {
    static let shared = AudiobookPlayer()

    // MARK: - Published Properties

    @Published var state: AudiobookPlayerState = .idle
    @Published var currentAudiobook: Audiobook?
    @Published var currentChapterIndex: Int = 0
    @Published var currentPosition: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0
    @Published var sleepTimerRemaining: TimeInterval?
    @Published var isBuffering: Bool = false

    // MARK: - Callbacks

    var onChapterChange: ((Int) -> Void)?
    var onProgressUpdate: ((Int, Int) -> Void)? // chapterIndex, positionSeconds
    var onPlaybackComplete: (() -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var sleepTimer: Timer?
    private var sleepTimerEndTime: Date?
    private var sleepTimerOption: SleepTimerOption = .off
    private var progressSaveTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let userDefaultsKey = "audiobookPlayerSettings"

    // MARK: - Audio Session

    private var audioSession: AVAudioSession {
        AVAudioSession.sharedInstance()
    }

    // MARK: - Initialization

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteControls()
        loadSettings()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("[AudiobookPlayer] Failed to setup audio session: \(error)")
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
                        self.play()
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
            Task { @MainActor in
                self?.play()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            Task { @MainActor in
                let skipEvent = event as? MPSkipIntervalCommandEvent
                let interval = skipEvent?.interval ?? 15
                self?.seek(by: interval)
            }
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            Task { @MainActor in
                let skipEvent = event as? MPSkipIntervalCommandEvent
                let interval = skipEvent?.interval ?? 15
                self?.seek(by: -interval)
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.nextChapter()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.previousChapter()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.seek(to: event.positionTime)
            }
            return .success
        }

        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackRateCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.setPlaybackSpeed(event.playbackRate)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let audiobook = currentAudiobook else { return }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentChapter?.title ?? "Chapter \(currentChapterIndex + 1)"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = audiobook.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = audiobook.author
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = state.isPlaying ? Double(playbackSpeed) : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPosition
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration

        // Load artwork if available
        if let coverUrl = audiobook.coverUrl, let url = URL(string: coverUrl) {
            // Note: In production, you'd want to cache this
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    info[MPMediaItemPropertyArtwork] = artwork
                    DispatchQueue.main.async {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                    }
                }
            }.resume()
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Settings

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let settings = try? JSONDecoder().decode(AudiobookPlayerSettings.self, from: data) {
            playbackSpeed = settings.playbackSpeed
        }
    }

    private func saveSettings() {
        let settings = AudiobookPlayerSettings(playbackSpeed: playbackSpeed)
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    // MARK: - Playback Control

    var currentChapter: AudiobookChapter? {
        guard let audiobook = currentAudiobook,
              currentChapterIndex >= 0,
              currentChapterIndex < audiobook.chapters.count else {
            return nil
        }
        return audiobook.chapters[currentChapterIndex]
    }

    func load(audiobook: Audiobook, startChapter: Int = 0, startPosition: TimeInterval = 0) {
        // Stop TTS if playing (mutual exclusion)
        if TTSEngine.shared.state == .playing || TTSEngine.shared.state == .paused {
            TTSEngine.shared.stop()
        }

        stop()

        self.currentAudiobook = audiobook
        self.currentChapterIndex = startChapter
        self.currentPosition = startPosition

        loadChapter(at: startChapter, seekTo: startPosition, autoPlay: false)
    }

    func loadAndPlay(audiobook: Audiobook, startChapter: Int = 0, startPosition: TimeInterval = 0) {
        // Stop TTS if playing (mutual exclusion)
        if TTSEngine.shared.state == .playing || TTSEngine.shared.state == .paused {
            TTSEngine.shared.stop()
        }

        stop()

        self.currentAudiobook = audiobook
        self.currentChapterIndex = startChapter
        self.currentPosition = startPosition

        loadChapter(at: startChapter, seekTo: startPosition, autoPlay: true)
    }

    private func loadChapter(at index: Int, seekTo position: TimeInterval = 0, autoPlay: Bool = true) {
        guard let audiobook = currentAudiobook,
              index >= 0,
              index < audiobook.chapters.count else {
            state = .error("Invalid chapter index")
            return
        }

        let chapter = audiobook.chapters[index]
        guard let remoteURL = URL(string: chapter.audioUrl) else {
            state = .error("Invalid audio URL")
            return
        }

        state = .loading
        isBuffering = true

        // Check cache and get playable URL
        let cacheManager = AudioCacheManager.shared
        cacheManager.getPlayableURL(chapterId: chapter.id, remoteURL: remoteURL) { [weak self] playableURL in
            guard let self = self else { return }

            // Log cache status
            if cacheManager.isCached(chapterId: chapter.id) {
                print("[AudiobookPlayer] Playing from cache: \(chapter.title)")
            } else {
                print("[AudiobookPlayer] Streaming from remote: \(chapter.title)")
            }

            // Create player item with the URL (local or remote)
            let asset = AVURLAsset(url: playableURL)
            self.playerItem = AVPlayerItem(asset: asset)

            // Enable variable speed playback with pitch correction for spoken audio
            self.playerItem?.audioTimePitchAlgorithm = .timeDomain

            // Observe player item status
            self.playerItem?.publisher(for: \.status)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    self?.handlePlayerItemStatus(status, seekTo: position, autoPlay: autoPlay)
                }
                .store(in: &self.cancellables)

            // Observe buffering state (only relevant for streaming)
            self.playerItem?.publisher(for: \.isPlaybackBufferEmpty)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isEmpty in
                    // Local files won't buffer
                    if !cacheManager.isCached(chapterId: chapter.id) {
                        self?.isBuffering = isEmpty
                    }
                }
                .store(in: &self.cancellables)

            self.playerItem?.publisher(for: \.isPlaybackLikelyToKeepUp)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isLikely in
                    if isLikely {
                        self?.isBuffering = false
                    }
                }
                .store(in: &self.cancellables)

            // Create player if needed
            if self.player == nil {
                self.player = AVPlayer()
            }

            self.player?.replaceCurrentItem(with: self.playerItem)
            self.player?.rate = self.playbackSpeed

            // Add time observer
            self.setupTimeObserver()

            // Observe when playback ends
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: self.playerItem
            )

            self.currentChapterIndex = index
            self.onChapterChange?(index)
            self.updateNowPlayingInfo()

            // Pre-download next chapters in background
            cacheManager.predownloadNextChapters(chapters: audiobook.chapters, currentIndex: index)
        }
    }

    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status, seekTo position: TimeInterval, autoPlay: Bool) {
        switch status {
        case .readyToPlay:
            isBuffering = false
            duration = playerItem?.duration.seconds ?? 0

            if position > 0 {
                seek(to: position, completion: { [weak self] in
                    if autoPlay {
                        self?.play()
                    }
                })
            } else if autoPlay {
                play()
            } else {
                state = .paused
            }

        case .failed:
            state = .error(playerItem?.error?.localizedDescription ?? "Playback failed")
            onError?(playerItem?.error ?? NSError(domain: "AudiobookPlayer", code: -1))

        case .unknown:
            break

        @unknown default:
            break
        }
    }

    private func setupTimeObserver() {
        removeTimeObserver()

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.handleTimeUpdate(time)
            }
        }

        // Also set up progress save timer (debounced every 5 seconds)
        progressSaveTimer?.invalidate()
        progressSaveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveProgress()
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        progressSaveTimer?.invalidate()
        progressSaveTimer = nil
    }

    private func handleTimeUpdate(_ time: CMTime) {
        guard time.isValid && !time.isIndefinite else { return }
        currentPosition = time.seconds
        updateNowPlayingInfo()
    }

    private func saveProgress() {
        guard currentAudiobook != nil else { return }
        onProgressUpdate?(currentChapterIndex, Int(currentPosition))
    }

    func play() {
        guard player != nil else { return }
        // Use playImmediately(atRate:) for reliable variable speed playback
        player?.playImmediately(atRate: playbackSpeed)
        state = .playing
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        state = .paused
        updateNowPlayingInfo()
        saveProgress()
    }

    func togglePlayPause() {
        if state.isPlaying {
            pause()
        } else {
            play()
        }
    }

    func stop() {
        saveProgress()
        removeTimeObserver()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerItem = nil
        cancellables.removeAll()

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        state = .idle
        currentAudiobook = nil
        currentChapterIndex = 0
        currentPosition = 0
        duration = 0

        stopSleepTimer()

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Seeking

    func seek(to time: TimeInterval, completion: (() -> Void)? = nil) {
        let cmTime = CMTime(seconds: max(0, time), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.currentPosition = time
                self?.updateNowPlayingInfo()
                completion?()
            }
        }
    }

    func seek(by seconds: TimeInterval) {
        let newTime = max(0, min(currentPosition + seconds, duration))
        seek(to: newTime)
    }

    // MARK: - Chapter Navigation

    func nextChapter() {
        guard let audiobook = currentAudiobook else { return }

        let nextIndex = currentChapterIndex + 1
        if nextIndex < audiobook.chapters.count {
            loadChapter(at: nextIndex, autoPlay: state.isPlaying)
        } else {
            // End of audiobook
            onPlaybackComplete?()
            stop()
        }
    }

    func previousChapter() {
        // If more than 3 seconds into chapter, restart current chapter
        if currentPosition > 3 {
            seek(to: 0)
            return
        }

        let prevIndex = currentChapterIndex - 1
        if prevIndex >= 0 {
            loadChapter(at: prevIndex, autoPlay: state.isPlaying)
        }
    }

    func goToChapter(_ index: Int) {
        guard let audiobook = currentAudiobook,
              index >= 0,
              index < audiobook.chapters.count else {
            return
        }
        loadChapter(at: index, autoPlay: state.isPlaying)
    }

    @objc private func playerDidFinishPlaying() {
        // Check if end-of-chapter sleep timer
        if sleepTimerOption == .endOfChapter {
            stopSleepTimer()
            pause()
            return
        }

        // Auto-advance to next chapter
        nextChapter()
    }

    // MARK: - Playback Speed

    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = max(0.5, min(3.5, speed))
        if state.isPlaying {
            // Apply rate change immediately while playing
            player?.rate = playbackSpeed
        }
        // Also update the playerItem's algorithm for best quality at different speeds
        if playbackSpeed < 0.8 || playbackSpeed > 2.0 {
            playerItem?.audioTimePitchAlgorithm = .spectral  // Better for extreme speeds
        } else {
            playerItem?.audioTimePitchAlgorithm = .timeDomain  // Better for normal speeds
        }
        saveSettings()
        updateNowPlayingInfo()
    }

    func cyclePlaybackSpeed() {
        let speeds: [Float] = [1.0, 1.25, 1.5, 1.75, 2.0, 0.75]
        if let currentIndex = speeds.firstIndex(of: playbackSpeed) {
            let nextIndex = (currentIndex + 1) % speeds.count
            setPlaybackSpeed(speeds[nextIndex])
        } else {
            setPlaybackSpeed(1.0)
        }
    }

    // MARK: - Sleep Timer

    func setSleepTimer(_ option: SleepTimerOption) {
        stopSleepTimer()
        sleepTimerOption = option

        guard option != .off else {
            sleepTimerRemaining = nil
            return
        }

        if option == .endOfChapter {
            sleepTimerRemaining = nil
            // Will pause at chapter end via playerDidFinishPlaying
            return
        }

        guard let seconds = option.seconds else { return }

        let duration = TimeInterval(seconds)
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
        sleepTimerOption = .off
    }

    // MARK: - Computed Properties

    var progressPercentage: Double {
        guard duration > 0 else { return 0 }
        return (currentPosition / duration) * 100
    }

    var totalProgress: Double {
        guard let audiobook = currentAudiobook else { return 0 }

        var totalDuration = 0
        var listenedDuration = 0

        for (index, chapter) in audiobook.chapters.enumerated() {
            totalDuration += chapter.duration

            if index < currentChapterIndex {
                listenedDuration += chapter.duration
            } else if index == currentChapterIndex {
                listenedDuration += Int(currentPosition)
            }
        }

        guard totalDuration > 0 else { return 0 }
        return Double(listenedDuration) / Double(totalDuration) * 100
    }

    var remainingTime: TimeInterval {
        guard let audiobook = currentAudiobook else { return 0 }

        var remaining: TimeInterval = 0

        // Remaining time in current chapter
        if let chapter = currentChapter {
            remaining += max(0, TimeInterval(chapter.duration) - currentPosition)
        }

        // Add remaining chapters
        for index in (currentChapterIndex + 1)..<audiobook.chapters.count {
            remaining += TimeInterval(audiobook.chapters[index].duration)
        }

        return remaining
    }

    var formattedRemainingTime: String {
        let seconds = Int(remainingTime)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        }
        return "\(minutes)m remaining"
    }

    /// Check if current chapter is playing from local cache
    var isPlayingFromCache: Bool {
        guard let chapter = currentChapter else { return false }
        return AudioCacheManager.shared.isCached(chapterId: chapter.id)
    }
}

// MARK: - Settings Model

private struct AudiobookPlayerSettings: Codable {
    let playbackSpeed: Float
}
