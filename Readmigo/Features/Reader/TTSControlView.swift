import SwiftUI
import AVFoundation

struct TTSControlView: View {
    @ObservedObject var ttsEngine: TTSEngine
    @Binding var isExpanded: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            handleBar

            if isExpanded {
                expandedView
            } else {
                minimizedView
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
    }

    // MARK: - Handle Bar

    private var handleBar: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            HStack {
                // Minimize/Expand button
                Button {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Time remaining
                if let timeRemaining = ttsEngine.progress?.formattedTimeRemaining {
                    Text(timeRemaining)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Close button
                Button {
                    ttsEngine.stop()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Minimized View

    private var minimizedView: some View {
        HStack(spacing: 16) {
            // Current sentence preview
            VStack(alignment: .leading, spacing: 2) {
                if let sentence = ttsEngine.currentSentenceText {
                    Text(sentence)
                        .font(.subheadline)
                        .lineLimit(1)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 3)

                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * (ttsEngine.progress?.progressPercentage ?? 0), height: 3)
                    }
                    .cornerRadius(1.5)
                }
                .frame(height: 3)
            }

            // Play/Pause button
            Button {
                ttsEngine.togglePlayPause()
            } label: {
                Image(systemName: ttsEngine.state.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
            }
        }
        .padding()
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        VStack(spacing: 20) {
            // Current sentence
            if let sentence = ttsEngine.currentSentenceText {
                Text(sentence)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .lineLimit(3)
            }

            // Progress bar
            progressSection

            // Playback controls
            playbackControls

            // Speed control
            speedControl

            // Settings buttons
            settingsButtons
        }
        .padding()
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * (ttsEngine.progress?.progressPercentage ?? 0), height: 4)
                }
                .cornerRadius(2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let percentage = value.location.x / geometry.size.width
                            // Seek to position (implement seeking logic)
                        }
                )
            }
            .frame(height: 4)

            // Time labels
            HStack {
                Text(formatTime(elapsed: ttsEngine.progress?.characterOffset ?? 0))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                if let remaining = ttsEngine.progress?.formattedTimeRemaining {
                    Text("-\(remaining)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func formatTime(elapsed: Int) -> String {
        let seconds = elapsed / 15 // Approximate based on reading speed
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 32) {
            // Previous
            Button {
                ttsEngine.skipBackward()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .foregroundColor(.primary)
            }

            // Previous sentence
            Button {
                ttsEngine.previousSentence()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
                    .foregroundColor(.primary)
            }

            // Play/Pause
            Button {
                ttsEngine.togglePlayPause()
            } label: {
                Image(systemName: ttsEngine.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.accentColor)
            }

            // Next sentence
            Button {
                ttsEngine.nextSentence()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundColor(.primary)
            }

            // Skip forward
            Button {
                ttsEngine.skipForward()
            } label: {
                Image(systemName: "goforward.15")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Speed Control

    private var speedControl: some View {
        VStack(spacing: 8) {
            HStack {
                Text("tts.speed".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(ttsEngine.settings.displayRate)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack(spacing: 16) {
                Button {
                    ttsEngine.decreaseRate()
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                }
                .disabled(ttsEngine.settings.rate <= 0)

                Slider(value: Binding(
                    get: { ttsEngine.settings.rate },
                    set: { ttsEngine.setRate($0) }
                ), in: 0...1)
                .tint(.accentColor)

                Button {
                    ttsEngine.increaseRate()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .disabled(ttsEngine.settings.rate >= 1)
            }
        }
    }

    // MARK: - Settings Buttons

    private var settingsButtons: some View {
        HStack(spacing: 20) {
            // Voice selector
            NavigationLink {
                VoicePickerView(ttsEngine: ttsEngine)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "person.wave.2")
                        .font(.title3)
                    Text("tts.voice".localized)
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }

            // Sleep timer
            Menu {
                ForEach(SleepTimerOption.allCases, id: \.self) { option in
                    Button {
                        ttsEngine.setSleepTimer(option)
                    } label: {
                        HStack {
                            Text(option.displayName)
                            if ttsEngine.settings.sleepTimerMinutes == option.rawValue ||
                               (option == .off && ttsEngine.settings.sleepTimerMinutes == nil) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Image(systemName: "moon.fill")
                            .font(.title3)

                        if ttsEngine.sleepTimerRemaining != nil {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                        }
                    }
                    Text(sleepTimerText)
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }

            // Highlight mode
            Menu {
                ForEach(TTSHighlightMode.allCases, id: \.self) { mode in
                    Button {
                        ttsEngine.settings.highlightMode = mode
                        ttsEngine.saveSettings()
                    } label: {
                        HStack {
                            Text(mode.displayName)
                            if ttsEngine.settings.highlightMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "text.word.spacing")
                        .font(.title3)
                    Text("tts.highlight".localized)
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }

            // More settings
            NavigationLink {
                TTSSettingsView(ttsEngine: ttsEngine)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                    Text("tts.settings".localized)
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }
        }
        .padding(.top, 8)
    }

    private var sleepTimerText: String {
        if let remaining = ttsEngine.sleepTimerRemaining {
            let minutes = Int(remaining / 60)
            return "\(minutes)m"
        } else if ttsEngine.settings.sleepTimerMinutes == -1 {
            return "tts.chapter".localized
        }
        return "tts.timer".localized
    }
}

// MARK: - Voice Picker View

struct VoicePickerView: View {
    @ObservedObject var ttsEngine: TTSEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(ttsEngine.availableVoices) { voice in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(voice.name)
                                .font(.subheadline)

                            if let badge = voice.quality.badge {
                                Text(badge)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }

                        Text(voice.language)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Preview button
                    Button {
                        previewVoice(voice)
                    } label: {
                        Image(systemName: "play.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)

                    if ttsEngine.currentVoice?.id == voice.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    ttsEngine.setVoice(voice)
                    dismiss()
                }
            }
        }
        .navigationTitle("tts.selectVoice".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func previewVoice(_ voice: TTSVoice) {
        // Preview the voice with sample text
        let utterance = AVSpeechUtterance(string: "Hello, this is how I sound when reading.")
        if let avVoice = AVSpeechSynthesisVoice(identifier: voice.id) {
            utterance.voice = avVoice
        }
        AVSpeechSynthesizer().speak(utterance)
    }
}

// MARK: - TTS Settings View

struct TTSSettingsView: View {
    @ObservedObject var ttsEngine: TTSEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // Pitch
            Section("tts.pitch".localized) {
                HStack {
                    Text("tts.low".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: Binding(
                        get: { ttsEngine.settings.pitch },
                        set: {
                            ttsEngine.settings.pitch = $0
                            ttsEngine.saveSettings()
                        }
                    ), in: 0.5...2.0)

                    Text("tts.high".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Pauses
            Section("tts.pauses".localized) {
                HStack {
                    Text("tts.betweenSentences".localized)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { ttsEngine.settings.pauseBetweenSentences },
                        set: {
                            ttsEngine.settings.pauseBetweenSentences = $0
                            ttsEngine.saveSettings()
                        }
                    )) {
                        Text("tts.short".localized).tag(0.2)
                        Text("tts.normal".localized).tag(0.3)
                        Text("tts.long".localized).tag(0.5)
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("tts.betweenParagraphs".localized)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { ttsEngine.settings.pauseBetweenParagraphs },
                        set: {
                            ttsEngine.settings.pauseBetweenParagraphs = $0
                            ttsEngine.saveSettings()
                        }
                    )) {
                        Text("tts.short".localized).tag(0.5)
                        Text("tts.normal".localized).tag(0.8)
                        Text("tts.long".localized).tag(1.2)
                    }
                    .pickerStyle(.menu)
                }
            }

            // Behavior
            Section("tts.behavior".localized) {
                Toggle("tts.autoScroll".localized, isOn: Binding(
                    get: { ttsEngine.settings.autoScroll },
                    set: {
                        ttsEngine.settings.autoScroll = $0
                        ttsEngine.saveSettings()
                    }
                ))

                Toggle("tts.autoPageTurn".localized, isOn: Binding(
                    get: { ttsEngine.settings.autoPageTurn },
                    set: {
                        ttsEngine.settings.autoPageTurn = $0
                        ttsEngine.saveSettings()
                    }
                ))
            }

            // Reading Mode
            Section("tts.readingMode".localized) {
                Picker("tts.mode".localized, selection: Binding(
                    get: { ttsEngine.settings.readingMode },
                    set: {
                        ttsEngine.settings.readingMode = $0
                        ttsEngine.saveSettings()
                    }
                )) {
                    ForEach(TTSReadingMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                        }.tag(mode)
                    }
                }
            }
        }
        .navigationTitle("tts.settingsTitle".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
