import SwiftUI
import AVFoundation

/// Voice chat view for conversing with AI-simulated author personas using voice
struct VoiceChatView: View {
    let authorId: String
    let sessionId: String

    @StateObject private var voiceManager = VoiceChatManager()
    @StateObject private var authorManager = AuthorManager.shared
    @Environment(\.dismiss) private var dismiss

    init(authorId: String, sessionId: String) {
        self.authorId = authorId
        self.sessionId = sessionId
    }

    private let avatarColors: [Color] = [
        Color(red: 0.91, green: 0.30, blue: 0.24),
        Color(red: 0.90, green: 0.49, blue: 0.13),
        Color(red: 0.18, green: 0.80, blue: 0.44),
        Color(red: 0.20, green: 0.60, blue: 0.86),
        Color(red: 0.56, green: 0.27, blue: 0.68),
        Color(red: 0.10, green: 0.74, blue: 0.61),
        Color(red: 0.95, green: 0.77, blue: 0.06),
        Color(red: 0.40, green: 0.50, blue: 0.60),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Usage indicator
                    usageBadge

                    Spacer()

                    // Author avatar with animation
                    authorAvatarSection

                    // Status text
                    statusText

                    // Transcription/Response display
                    if !voiceManager.currentTranscription.isEmpty || !voiceManager.currentResponse.isEmpty {
                        conversationBubbles
                    }

                    Spacer()

                    // Voice waveform
                    if voiceManager.isRecording || voiceManager.isProcessing {
                        VoiceWaveform(
                            isRecording: voiceManager.isRecording,
                            audioLevel: voiceManager.audioLevel
                        )
                        .frame(height: 60)
                        .padding(.horizontal, 40)
                    }

                    // Push-to-talk button
                    pushToTalkButton

                    // Hint text
                    Text("Hold to speak, release to send")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationTitle("Voice Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        voiceManager.stopPlayback()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(hex: "1A1A2E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            voiceManager.authorId = authorId
            voiceManager.sessionId = sessionId
            Task {
                await voiceManager.fetchUsage()
            }
        }
        .onDisappear {
            voiceManager.cleanup()
        }
        .alert("Voice Chat", isPresented: $voiceManager.showError) {
            Button("OK") { voiceManager.showError = false }
        } message: {
            Text(voiceManager.errorMessage)
        }
    }

    // MARK: - Usage Badge

    private var usageBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.caption)

            if let usage = voiceManager.usage {
                Text("\(String(format: "%.1f", usage.remaining)) min remaining")
                    .font(.caption)
            } else {
                Text("Loading...")
                    .font(.caption)
            }
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Author Avatar Section

    private var authorAvatarSection: some View {
        ZStack {
            // Pulsing rings when speaking
            if voiceManager.isPlayingAudio {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.blue.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                        .frame(width: 150 + CGFloat(index * 30), height: 150 + CGFloat(index * 30))
                        .scaleEffect(voiceManager.isPlayingAudio ? 1.1 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: voiceManager.isPlayingAudio
                        )
                }
            }

            // Avatar circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [avatarColors[authorColorIndex], avatarColors[authorColorIndex].opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: avatarColors[authorColorIndex].opacity(0.5), radius: 20, x: 0, y: 10)

            // Avatar image or initials
            if let avatarUrl = authorManager.currentAuthorDetail?.avatarUrl,
               let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text(authorInitials)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 110, height: 110)
                .clipShape(Circle())
            } else {
                Text(authorInitials)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private var authorName: String {
        authorManager.currentAuthorDetail?.name ?? "Author"
    }

    private var authorInitials: String {
        authorManager.currentAuthorDetail?.initials ?? "AU"
    }

    private var authorColorIndex: Int {
        authorManager.currentAuthorDetail?.avatarColorIndex ?? 0
    }

    // MARK: - Status Text

    private var statusText: some View {
        VStack(spacing: 4) {
            Text(authorName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(voiceManager.statusText)
                .font(.subheadline)
                .foregroundColor(voiceManager.isRecording ? .red : .white.opacity(0.7))
                .animation(.easeInOut, value: voiceManager.statusText)
        }
    }

    // MARK: - Conversation Bubbles

    private var conversationBubbles: some View {
        VStack(spacing: 12) {
            // User's transcription
            if !voiceManager.currentTranscription.isEmpty {
                HStack {
                    Spacer()
                    Text(voiceManager.currentTranscription)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(16)
                        .frame(maxWidth: 280, alignment: .trailing)
                }
            }

            // AI response
            if !voiceManager.currentResponse.isEmpty {
                HStack {
                    Text(voiceManager.currentResponse)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(16)
                        .frame(maxWidth: 280, alignment: .leading)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Push to Talk Button

    private var pushToTalkButton: some View {
        Button {
            // Tap does nothing, we use long press
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        voiceManager.isRecording ? Color.red : Color.white.opacity(0.3),
                        lineWidth: 4
                    )
                    .frame(width: 90, height: 90)

                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: voiceManager.isRecording ? [Color.red, Color.red] : [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .scaleEffect(voiceManager.isRecording ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: voiceManager.isRecording)

                // Icon
                Image(systemName: voiceManager.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .symbolEffect(.variableColor, isActive: voiceManager.isRecording)
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onEnded { _ in
                    voiceManager.startRecording()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if voiceManager.isRecording {
                        voiceManager.stopRecordingAndSend()
                    }
                }
        )
        .disabled(voiceManager.isProcessing || voiceManager.isPlayingAudio)
        .opacity((voiceManager.isProcessing || voiceManager.isPlayingAudio) ? 0.5 : 1.0)
    }
}

// MARK: - Voice Waveform

struct VoiceWaveform: View {
    let isRecording: Bool
    let audioLevel: Float

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { index in
                    WaveformBar(
                        index: index,
                        totalBars: 20,
                        isRecording: isRecording,
                        audioLevel: audioLevel,
                        animationPhase: animationPhase
                    )
                }
            }
            .frame(maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationPhase = 1
            }
        }
    }
}

struct WaveformBar: View {
    let index: Int
    let totalBars: Int
    let isRecording: Bool
    let audioLevel: Float
    let animationPhase: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 4)
            .frame(height: barHeight)
            .animation(.easeInOut(duration: 0.1), value: audioLevel)
    }

    private var barHeight: CGFloat {
        let baseHeight: CGFloat = 10
        let maxHeight: CGFloat = 50

        if isRecording {
            // Create wave pattern based on audio level
            let phase = Double(index) / Double(totalBars) + Double(animationPhase)
            let sineValue = sin(phase * .pi * 2) * 0.5 + 0.5
            let levelMultiplier = CGFloat(audioLevel) * 2 + 0.2
            return baseHeight + (maxHeight - baseHeight) * CGFloat(sineValue) * levelMultiplier
        } else {
            // Idle animation
            let phase = Double(index) / Double(totalBars) + Double(animationPhase)
            let sineValue = sin(phase * .pi * 2) * 0.3 + 0.3
            return baseHeight + CGFloat(sineValue) * 10
        }
    }
}

// MARK: - Voice Chat Manager

@MainActor
class VoiceChatManager: NSObject, ObservableObject {
    // State
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var isPlayingAudio = false
    @Published var audioLevel: Float = 0
    @Published var statusText = "Tap and hold to speak"
    @Published var currentTranscription = ""
    @Published var currentResponse = ""
    @Published var usage: VoiceUsage?
    @Published var showError = false
    @Published var errorMessage = ""

    // Configuration
    var authorId: String = ""
    var sessionId: String = ""

    // Audio
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    private var levelTimer: Timer?

    override init() {
        super.init()
        setupAudioSession()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording && !isProcessing else { return }

        // Check usage
        if let usage = usage, !usage.allowed {
            errorMessage = "Voice chat limit reached. Upgrade to Premium for more time."
            showError = true
            return
        }

        // Create recording URL
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("voice_message_\(UUID().uuidString).m4a")

        // Recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

            isRecording = true
            statusText = "Listening..."
            currentTranscription = ""
            currentResponse = ""

            // Start level monitoring
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAudioLevel()
                }
            }
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            showError = true
        }
    }

    func stopRecordingAndSend() {
        guard isRecording else { return }

        // Stop recording
        audioRecorder?.stop()
        levelTimer?.invalidate()
        levelTimer = nil
        isRecording = false
        audioLevel = 0

        guard let recordingURL = recordingURL else { return }

        isProcessing = true
        statusText = "Processing..."

        // Send to server
        Task {
            await sendVoiceMessage(audioURL: recordingURL)
        }
    }

    private func updateAudioLevel() {
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // Convert dB to linear scale (0-1)
        let normalizedLevel = max(0, (level + 50) / 50)
        audioLevel = normalizedLevel
    }

    // MARK: - API Calls

    func fetchUsage() async {
        do {
            usage = try await APIClient.shared.request(
                endpoint: APIEndpoints.voiceChatUsage
            )
        } catch {
            // Default to allowing with full usage on error
            usage = VoiceUsage(allowed: true, remaining: 3, limit: 3)
        }
    }

    private func sendVoiceMessage(audioURL: URL) async {
        do {
            let audioData = try Data(contentsOf: audioURL)

            // Create multipart form data request
            let baseURL = await APIClient.shared.baseURL
            var request = URLRequest(url: URL(string: baseURL + APIEndpoints.voiceChatChat(sessionId))!)
            request.httpMethod = "POST"

            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            if let token = AuthManager.shared.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server error"])
            }

            let voiceResponse = try JSONDecoder().decode(VoiceMessageResponse.self, from: data)

            currentTranscription = voiceResponse.userMessage.content
            currentResponse = voiceResponse.assistantMessage.content
            statusText = "Speaking..."
            isProcessing = false

            // Play audio response
            if let audioData = Data(base64Encoded: voiceResponse.audioUrl.replacingOccurrences(of: "data:audio/mpeg;base64,", with: "")) {
                playAudio(data: audioData)
            }

        } catch {
            isProcessing = false
            statusText = "Tap and hold to speak"
            errorMessage = "Failed to send voice message: \(error.localizedDescription)"
            showError = true
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: audioURL)
    }

    // MARK: - Audio Playback

    private func playAudio(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlayingAudio = true
        } catch {
            statusText = "Tap and hold to speak"
            isPlayingAudio = false
        }
    }

    private func simulatePlayback() {
        isPlayingAudio = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.isPlayingAudio = false
            self?.statusText = "Tap and hold to speak"
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlayingAudio = false
    }

    func cleanup() {
        stopPlayback()
        audioRecorder?.stop()
        audioRecorder = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceChatManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlayingAudio = false
            statusText = "Tap and hold to speak"
        }
    }
}

// MARK: - Models

struct VoiceUsage: Codable {
    let allowed: Bool
    let remaining: Double
    let limit: Double
}

struct VoiceMessageResponse: Codable {
    let userMessage: VoiceMessageContent
    let assistantMessage: VoiceMessageContent
    let audioUrl: String
    let duration: Double
}

struct VoiceMessageContent: Codable {
    let id: String
    let content: String
}
