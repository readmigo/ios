import SwiftUI

struct FollowAlongView: View {
    @StateObject var viewModel: FollowAlongViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress header
                progressHeader

                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        // Current sentence card
                        sentenceCard

                        // Mode-specific controls
                        modeControls

                        // Results (when reviewing)
                        if viewModel.mode == .reviewing {
                            resultsView
                        }
                    }
                    .padding()
                }

                // Bottom controls
                bottomControls
            }
            .navigationTitle("Follow Along")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showResults = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showResults) {
                SessionSummaryView(summary: viewModel.getSessionSummary())
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(viewModel.currentSentenceIndex + 1) / CGFloat(max(1, viewModel.sentences.count)))
                }
            }
            .frame(height: 4)
            .cornerRadius(2)

            // Progress text
            HStack {
                Text("Sentence \(viewModel.currentSentenceIndex + 1) of \(viewModel.sentences.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.overallScore > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.0f%%", viewModel.overallScore))
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Sentence Card

    private var sentenceCard: some View {
        VStack(spacing: 16) {
            // Original text
            VStack(alignment: .leading, spacing: 8) {
                Label("Original Text", systemImage: "text.book.closed")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(viewModel.currentSentence?.text ?? "")
                    .font(.title3)
                    .fontWeight(.medium)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // User transcript (when available)
            if let recording = viewModel.currentSentence?.userRecording {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Your Speech", systemImage: "waveform")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            Task { await viewModel.playUserRecording() }
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                        }
                    }

                    highlightedTranscript(recording.transcript)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    private func highlightedTranscript(_ text: String) -> some View {
        guard let comparison = viewModel.currentSentence?.comparisonResult else {
            return Text(text).font(.body) as! Text
        }

        // Build attributed text with colors
        var result = Text("")
        let words = text.components(separatedBy: " ")

        for word in words {
            let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            let match = comparison.matchedWords.first { $0.word == cleanWord || $0.spokenAs == cleanWord }

            let color: Color
            if let match = match {
                color = match.isCorrect ? .green : .orange
            } else if comparison.missedWords.contains(cleanWord) {
                color = .red
            } else {
                color = .primary
            }

            result = result + Text(word + " ").foregroundColor(color)
        }

        return result.font(.body)
    }

    // MARK: - Mode Controls

    private var modeControls: some View {
        VStack(spacing: 16) {
            switch viewModel.mode {
            case .listening:
                listeningControls

            case .recording:
                recordingControls

            case .reviewing:
                reviewingControls
            }
        }
    }

    private var listeningControls: some View {
        VStack(spacing: 16) {
            // Listen button
            Button {
                Task { await viewModel.playCurrentSentence() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                    Text(viewModel.isPlaying ? "Playing..." : "Listen to Sentence")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isPlaying)

            // Record button
            Button {
                Task { await viewModel.startRecording() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                    Text("Record Your Voice")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }

    private var recordingControls: some View {
        VStack(spacing: 20) {
            // Recording indicator
            VStack(spacing: 12) {
                // Audio level visualization
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(for: i))
                            .frame(width: 8, height: barHeight(for: i))
                    }
                }
                .frame(height: 40)

                // Duration
                Text(formatDuration(viewModel.speechRecorder.recordingDuration))
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()

                // Live transcript
                if !viewModel.speechRecorder.currentTranscript.isEmpty {
                    Text(viewModel.speechRecorder.currentTranscript)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(16)

            // Controls
            HStack(spacing: 32) {
                Button {
                    viewModel.cancelRecording()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("Cancel")
                            .font(.caption)
                    }
                }

                Button {
                    Task { await viewModel.stopRecording() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 72, height: 72)

                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private var reviewingControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Re-record
                Button {
                    viewModel.mode = .listening
                    viewModel.speechRecorder.reset()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text("Re-record")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                }

                // Get AI Score
                Button {
                    Task { await viewModel.requestPronunciationScore() }
                } label: {
                    VStack(spacing: 4) {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "sparkles")
                                .font(.title2)
                        }
                        Text("AI Score")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)
            }

            // Next sentence
            if viewModel.hasNextSentence {
                Button {
                    viewModel.nextSentence()
                } label: {
                    HStack(spacing: 8) {
                        Text("Next Sentence")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 16) {
            if let comparison = viewModel.currentSentence?.comparisonResult {
                // Accuracy score
                VStack(spacing: 8) {
                    Text("\(Int(comparison.accuracy * 100))%")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(scoreColor(comparison.accuracy))

                    Text("Word Accuracy")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            if let score = viewModel.currentSentence?.pronunciationScore {
                // AI Pronunciation Score
                VStack(spacing: 12) {
                    Text("AI Pronunciation Score")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // Score breakdown
                    HStack(spacing: 16) {
                        ScoreItem(title: "Accuracy", value: score.accuracy, icon: "checkmark.circle")
                        ScoreItem(title: "Fluency", value: score.fluency, icon: "waveform")
                        ScoreItem(title: "Rhythm", value: score.rhythm, icon: "metronome")
                    }

                    // Feedback
                    if !score.feedback.isEmpty {
                        Text(score.feedback)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 32) {
            Button {
                viewModel.previousSentence()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title)
            }
            .disabled(!viewModel.hasPreviousSentence)

            // Sentence navigator
            Menu {
                ForEach(Array(viewModel.sentences.enumerated()), id: \.offset) { index, sentence in
                    Button {
                        viewModel.goToSentence(index)
                    } label: {
                        HStack {
                            Text("Sentence \(index + 1)")
                            if sentence.userRecording != nil {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "list.bullet.circle.fill")
                    .font(.title)
            }

            Button {
                viewModel.nextSentence()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title)
            }
            .disabled(!viewModel.hasNextSentence)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Helper Methods

    private func barColor(for index: Int) -> Color {
        let threshold = Int(viewModel.speechRecorder.audioLevel * 20)
        return index < threshold ? .red : Color(.systemGray4)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base: CGFloat = 8
        let variation = sin(Double(index) * 0.5 + Double(viewModel.speechRecorder.recordingDuration) * 3) * 0.5 + 0.5
        let level = CGFloat(viewModel.speechRecorder.audioLevel)
        return base + CGFloat(variation) * level * 32
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.6 { return .orange }
        return .red
    }
}

// MARK: - Score Item

struct ScoreItem: View {
    let title: String
    let value: Double
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)

            Text("\(Int(value))%")
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Summary View

struct SessionSummaryView: View {
    let summary: FollowAlongSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall score
                    VStack(spacing: 8) {
                        Text("\(Int(summary.overallScore))%")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(.accentColor)

                        Text("Overall Score")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "Completed", value: "\(summary.completedSentences)/\(summary.totalSentences)", icon: "checkmark.circle.fill", color: .green)

                        StatCard(title: "Practice Time", value: formatTime(summary.practiceTime), icon: "clock.fill", color: .blue)

                        StatCard(title: "Accuracy", value: "\(Int(summary.averageAccuracy))%", icon: "target", color: .orange)

                        StatCard(title: "Fluency", value: "\(Int(summary.averageFluency))%", icon: "waveform", color: .purple)
                    }
                    .padding(.horizontal)

                    // Encouragement
                    Text(encouragementMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .padding(.vertical)
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var encouragementMessage: String {
        if summary.overallScore >= 90 {
            return "Excellent work! Your pronunciation is outstanding!"
        } else if summary.overallScore >= 75 {
            return "Great job! Keep practicing to reach even higher scores."
        } else if summary.overallScore >= 50 {
            return "Good effort! Regular practice will help you improve."
        } else {
            return "Keep going! Every practice session makes you better."
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
