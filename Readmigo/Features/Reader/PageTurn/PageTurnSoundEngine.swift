import AVFoundation
import Combine

// MARK: - Page Turn Sound Type

enum PageTurnSoundType: String, CaseIterable {
    case pageTurnSoft = "page_turn_soft"     // 柔和音
    case pageTurnCrisp = "page_turn_crisp"   // 清脆音
    case pageTurnThick = "page_turn_thick"   // 厚重音
    case pageRustle = "page_rustle"          // 沙沙声
    case bookOpen = "book_open"              // 开书声
    case bookClose = "book_close"            // 合书声

    var displayName: String {
        switch self {
        case .pageTurnSoft: return "柔和"
        case .pageTurnCrisp: return "清脆"
        case .pageTurnThick: return "厚重"
        case .pageRustle: return "沙沙声"
        case .bookOpen: return "开书"
        case .bookClose: return "合书"
        }
    }

    /// 音效文件名（不含扩展名）
    var fileName: String {
        rawValue
    }

    /// 音效时长（秒）
    var duration: TimeInterval {
        switch self {
        case .pageTurnSoft: return 0.3
        case .pageTurnCrisp: return 0.25
        case .pageTurnThick: return 0.4
        case .pageRustle: return 0.5
        case .bookOpen: return 0.6
        case .bookClose: return 0.5
        }
    }
}

// MARK: - Page Turn Sound Engine

/// 翻页声效引擎
class PageTurnSoundEngine: ObservableObject {

    // MARK: - Properties

    /// 是否启用声效
    @Published var isEnabled: Bool = true

    /// 音量 (0-1)
    @Published var volume: Float = 0.7 {
        didSet {
            updateVolume()
        }
    }

    /// 当前音效类型偏好
    @Published var preferredSoundType: PageTurnSoundType = .pageTurnSoft

    // MARK: - Private Properties

    private var audioPlayers: [PageTurnSoundType: AVAudioPlayer] = [:]
    private var rustlePlayer: AVAudioPlayer?
    private var isRustling: Bool = false
    private let audioSession = AVAudioSession.sharedInstance()

    // 合成音效参数
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    // MARK: - Initialization

    init() {
        setupAudioSession()
        preloadSounds()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Sound Preloading

    private func preloadSounds() {
        for soundType in PageTurnSoundType.allCases {
            loadSound(soundType)
        }
    }

    private func loadSound(_ soundType: PageTurnSoundType) {
        // 尝试从 Bundle 加载声音文件
        guard let url = Bundle.main.url(forResource: soundType.fileName, withExtension: "mp3")
                ?? Bundle.main.url(forResource: soundType.fileName, withExtension: "wav")
                ?? Bundle.main.url(forResource: soundType.fileName, withExtension: "aiff") else {
            // 如果没有预置音效文件，使用合成音效
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.volume = volume
            audioPlayers[soundType] = player
        } catch {
            print("Failed to load sound \(soundType.rawValue): \(error)")
        }
    }

    // MARK: - Public Methods

    /// 根据翻页速度播放音效
    /// - Parameter velocity: 翻页速度
    func playPageTurnSound(velocity: CGFloat) {
        guard isEnabled else { return }

        let soundType: PageTurnSoundType
        let absVelocity = abs(velocity)

        if absVelocity > 2.0 {
            soundType = .pageTurnCrisp  // 快速翻页 - 清脆音
        } else if absVelocity > 0.5 {
            soundType = .pageTurnSoft   // 正常翻页 - 柔和音
        } else {
            soundType = .pageRustle     // 慢速翻页 - 沙沙声
        }

        playSound(soundType)
    }

    /// 播放指定类型的音效
    /// - Parameter type: 音效类型
    func playSound(_ type: PageTurnSoundType) {
        guard isEnabled else { return }

        if let player = audioPlayers[type] {
            player.currentTime = 0
            player.play()
        } else {
            // 使用合成音效
            playSynthesizedSound(type)
        }
    }

    /// 实时纸张摩擦声（跟随手指）
    /// - Parameter intensity: 强度 (0-1)
    func playRealtimeRustle(intensity: CGFloat) {
        guard isEnabled, intensity > 0.1 else {
            stopRustle()
            return
        }

        if !isRustling {
            startRustle()
        }

        // 调整音量和音调
        rustlePlayer?.volume = Float(intensity) * volume
    }

    /// 停止摩擦声
    func stopRustle() {
        isRustling = false
        rustlePlayer?.stop()
    }

    /// 播放开书声
    func playBookOpen() {
        playSound(.bookOpen)
    }

    /// 播放合书声
    func playBookClose() {
        playSound(.bookClose)
    }

    // MARK: - Private Methods

    private func updateVolume() {
        for (_, player) in audioPlayers {
            player.volume = volume
        }
        rustlePlayer?.volume = volume
    }

    private func startRustle() {
        isRustling = true

        if let player = audioPlayers[.pageRustle] {
            player.numberOfLoops = -1 // 无限循环
            player.volume = 0.3 * volume
            player.play()
            rustlePlayer = player
        } else {
            playSynthesizedRustle()
        }
    }

    // MARK: - Synthesized Sounds

    /// 使用 Audio Engine 合成翻页声
    private func playSynthesizedSound(_ type: PageTurnSoundType) {
        // 初始化音频引擎
        if audioEngine == nil {
            setupAudioEngine()
        }

        guard let engine = audioEngine, let playerNode = playerNode else { return }

        // 生成音频缓冲
        let buffer = generateSoundBuffer(for: type)

        // 播放
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Failed to start audio engine: \(error)")
            }
        }

        playerNode.play()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        guard let engine = audioEngine, let node = playerNode else { return }

        engine.attach(node)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(node, to: engine.mainMixerNode, format: format)

        engine.mainMixerNode.outputVolume = volume
    }

    private func generateSoundBuffer(for type: PageTurnSoundType) -> AVAudioPCMBuffer {
        let sampleRate: Double = 44100
        let duration = type.duration
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let floatData = buffer.floatChannelData![0]

        switch type {
        case .pageTurnSoft:
            generateSoftPageTurn(buffer: floatData, frameCount: Int(frameCount), sampleRate: sampleRate)
        case .pageTurnCrisp:
            generateCrispPageTurn(buffer: floatData, frameCount: Int(frameCount), sampleRate: sampleRate)
        case .pageTurnThick:
            generateThickPageTurn(buffer: floatData, frameCount: Int(frameCount), sampleRate: sampleRate)
        case .pageRustle:
            generateRustle(buffer: floatData, frameCount: Int(frameCount), sampleRate: sampleRate)
        case .bookOpen, .bookClose:
            generateBookSound(buffer: floatData, frameCount: Int(frameCount), sampleRate: sampleRate)
        }

        return buffer
    }

    // MARK: - Sound Generation

    private func generateSoftPageTurn(buffer: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope = sin(.pi * t / 0.3) // 0.3秒的包络

            // 低频噪声 + 轻微摩擦声
            let noise = Float.random(in: -0.3...0.3)
            let lowFreq = sin(2 * .pi * 150 * t) * 0.1
            buffer[i] = Float(envelope) * (noise * 0.5 + Float(lowFreq)) * 0.3
        }
    }

    private func generateCrispPageTurn(buffer: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 10) // 快速衰减

            // 高频噪声 + 冲击声
            let noise = Float.random(in: -1...1)
            let impact = sin(2 * .pi * 2000 * t) * exp(-t * 20)
            buffer[i] = Float(envelope) * (noise * 0.4 + Float(impact) * 0.3) * 0.5
        }
    }

    private func generateThickPageTurn(buffer: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope = sin(.pi * t / 0.4) * (1 - t / 0.4)

            // 低沉的声音
            let lowFreq = sin(2 * .pi * 80 * t) * 0.3
            let midFreq = sin(2 * .pi * 200 * t) * 0.2
            let noise = Float.random(in: -0.2...0.2)
            buffer[i] = Float(envelope) * (Float(lowFreq) + Float(midFreq) + noise) * 0.4
        }
    }

    private func generateRustle(buffer: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate

            // 过滤后的白噪声
            let noise = Float.random(in: -1...1)
            let filter = sin(2 * .pi * 3000 * t) * 0.1
            let modulation = sin(2 * .pi * 10 * t) * 0.5 + 0.5

            buffer[i] = noise * Float(modulation) * 0.2 + Float(filter) * 0.1
        }
    }

    private func generateBookSound(buffer: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope = sin(.pi * t / 0.6) * exp(-t * 2)

            // 书本开合的低沉声音
            let thud = sin(2 * .pi * 60 * t) * exp(-t * 5)
            let rustle = Float.random(in: -0.3...0.3) * Float(exp(-t * 3))
            buffer[i] = Float(envelope) * (Float(thud) * 0.5 + rustle * 0.3) * 0.5
        }
    }

    private func playSynthesizedRustle() {
        // 对于连续的摩擦声，使用循环播放
        // 这里简化处理，实际可以使用 AVAudioUnitGenerator
    }
}
