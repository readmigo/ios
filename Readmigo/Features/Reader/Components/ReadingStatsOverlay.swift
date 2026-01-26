import SwiftUI
import Combine

// MARK: - Reading Stats Overlay

struct ReadingStatsOverlay: View {
    @ObservedObject var tracker: StatsReadingSessionTracker
    let isVisible: Bool
    let position: OverlayPosition

    enum OverlayPosition {
        case topLeft, topRight, bottomLeft, bottomRight, floating
    }

    var body: some View {
        if isVisible {
            VStack(alignment: position == .topLeft || position == .bottomLeft ? .leading : .trailing, spacing: 4) {
                // Time reading
                StatRow(icon: "clock", value: tracker.formattedDuration, label: "reading")

                // Words read
                StatRow(icon: "text.word.spacing", value: "\(tracker.wordsRead)", label: "words")

                // Reading speed
                StatRow(icon: "speedometer", value: "\(tracker.currentWPM)", label: "wpm")

                // Estimated time remaining
                if tracker.estimatedTimeRemaining > 0 {
                    StatRow(
                        icon: "hourglass",
                        value: formatTime(tracker.estimatedTimeRemaining),
                        label: "left"
                    )
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct StatRow: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 14)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Reading Session Tracker

@MainActor
class StatsReadingSessionTracker: ObservableObject {
    static let shared = StatsReadingSessionTracker()

    @Published var sessionStartTime: Date?
    @Published var wordsRead: Int = 0
    @Published var pagesRead: Int = 0
    @Published var chaptersRead: Int = 0
    @Published var currentWPM: Int = 0
    @Published var totalWordsInBook: Int = 0
    @Published var scrollPositions: [Double] = []

    private var timer: Timer?
    private var wordCountSamples: [(time: Date, count: Int)] = []

    var sessionDuration: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var formattedDuration: String {
        let duration = Int(sessionDuration)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var estimatedTimeRemaining: Int {
        guard currentWPM > 0 else { return 0 }
        let wordsRemaining = totalWordsInBook - wordsRead
        return max(0, wordsRemaining / currentWPM)
    }

    var averageReadingSpeed: Double {
        guard sessionDuration > 60 else { return 0 } // Need at least 1 minute
        return Double(wordsRead) / (sessionDuration / 60)
    }

    func startSession(totalWords: Int) {
        sessionStartTime = Date()
        wordsRead = 0
        pagesRead = 0
        chaptersRead = 0
        currentWPM = 0
        totalWordsInBook = totalWords
        wordCountSamples.removeAll()
        scrollPositions.removeAll()

        // Update timer
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStats()
            }
        }
    }

    func endSession() {
        timer?.invalidate()
        timer = nil

        // Save session stats
        saveSessionToHistory()
    }

    func recordWordsRead(_ count: Int) {
        wordsRead += count
        wordCountSamples.append((Date(), wordsRead))

        // Keep only last 60 samples (1 minute of data at 1 sample/sec)
        if wordCountSamples.count > 60 {
            wordCountSamples.removeFirst()
        }
    }

    func recordScrollPosition(_ position: Double) {
        scrollPositions.append(position)

        // Keep last 100 positions
        if scrollPositions.count > 100 {
            scrollPositions.removeFirst()
        }
    }

    func recordPageRead() {
        pagesRead += 1
    }

    func recordChapterRead() {
        chaptersRead += 1
    }

    private func updateStats() {
        // Calculate current reading speed from recent samples
        calculateCurrentWPM()
    }

    private func calculateCurrentWPM() {
        // Use samples from last 30 seconds
        let now = Date()
        let recentSamples = wordCountSamples.filter { now.timeIntervalSince($0.time) <= 30 }

        guard recentSamples.count >= 2 else {
            currentWPM = 0
            return
        }

        let firstSample = recentSamples.first!
        let lastSample = recentSamples.last!
        let wordsInPeriod = lastSample.count - firstSample.count
        let timeInMinutes = lastSample.time.timeIntervalSince(firstSample.time) / 60

        if timeInMinutes > 0 {
            currentWPM = Int(Double(wordsInPeriod) / timeInMinutes)
        }
    }

    private func saveSessionToHistory() {
        let session = StatsReadingSession(
            id: UUID().uuidString,
            startTime: sessionStartTime ?? Date(),
            endTime: Date(),
            duration: sessionDuration,
            wordsRead: wordsRead,
            pagesRead: pagesRead,
            chaptersRead: chaptersRead,
            averageWPM: Int(averageReadingSpeed)
        )

        // Save to UserDefaults or backend
        var sessions = loadSessions()
        sessions.append(session)

        // Keep last 100 sessions
        if sessions.count > 100 {
            sessions = Array(sessions.suffix(100))
        }

        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "readingSessions")
        }
    }

    private func loadSessions() -> [StatsReadingSession] {
        guard let data = UserDefaults.standard.data(forKey: "readingSessions"),
              let sessions = try? JSONDecoder().decode([StatsReadingSession].self, from: data) else {
            return []
        }
        return sessions
    }
}

// MARK: - Reading Session Model

struct StatsReadingSession: Codable, Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let wordsRead: Int
    let pagesRead: Int
    let chaptersRead: Int
    let averageWPM: Int

    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}

// MARK: - Smart Auto-Scroll

struct SmartAutoScrollView<Content: View>: View {
    @Binding var isEnabled: Bool
    @Binding var speed: Double // Words per minute target
    let wordsPerScreen: Int
    @ViewBuilder let content: () -> Content

    @State private var scrollOffset: CGFloat = 0
    @State private var timer: Timer?
    @State private var isPaused = false

    // Calculated scroll speed (pixels per second)
    private var pixelsPerSecond: CGFloat {
        // Assuming average 50 words per screen height
        let screensPerMinute = speed / Double(wordsPerScreen)
        let screenHeight = UIScreen.main.bounds.height
        return screenHeight * CGFloat(screensPerMinute) / 60
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    content()
                        .id("content")
                        .offset(y: isEnabled ? -scrollOffset : 0)
                }
                .overlay(alignment: .bottom) {
                    if isEnabled {
                        autoScrollControls
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { _ in
                            // Pause on touch
                            isPaused = true
                        }
                        .onEnded { _ in
                            // Resume after touch
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isPaused = false
                            }
                        }
                )
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            if newValue {
                startAutoScroll()
            } else {
                stopAutoScroll()
            }
        }
        .onDisappear {
            stopAutoScroll()
        }
    }

    private var autoScrollControls: some View {
        HStack(spacing: 24) {
            // Slow down
            Button {
                speed = max(50, speed - 25)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
            }

            // Speed indicator
            VStack(spacing: 2) {
                Text("\(Int(speed))")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("WPM")
                    .font(.caption2)
            }

            // Speed up
            Button {
                speed = min(500, speed + 25)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }

            Divider()
                .frame(height: 30)

            // Pause/Play
            Button {
                isPaused.toggle()
            } label: {
                Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.title)
            }

            // Stop
            Button {
                isEnabled = false
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.black.opacity(0.7))
        .cornerRadius(25)
        .padding(.bottom, 20)
    }

    private func startAutoScroll() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !isPaused else { return }
            scrollOffset += pixelsPerSecond * 0.016
        }
    }

    private func stopAutoScroll() {
        timer?.invalidate()
        timer = nil
        scrollOffset = 0
    }
}

// MARK: - Speed Reader View (RSVP - Rapid Serial Visual Presentation)

struct SpeedReaderView: View {
    let words: [String]
    @Binding var currentWordIndex: Int
    @Binding var wordsPerMinute: Int
    @Binding var isPlaying: Bool

    @State private var timer: Timer?
    @State private var displayWord: String = ""

    private var msPerWord: Double {
        60000 / Double(wordsPerMinute)
    }

    var body: some View {
        VStack(spacing: 40) {
            // Word display
            ZStack {
                // Focus line
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 60)
                    .offset(x: focusOffset)

                // Current word
                Text(displayWord)
                    .font(.system(size: 48, weight: .medium, design: .monospaced))
                    .frame(minWidth: 200)
            }
            .padding(.vertical, 60)
            .background(Color(.systemGray6))
            .cornerRadius(16)

            // Controls
            VStack(spacing: 20) {
                // Speed control
                HStack {
                    Text("Speed:")
                        .foregroundColor(.secondary)

                    Slider(value: Binding(
                        get: { Double(wordsPerMinute) },
                        set: { wordsPerMinute = Int($0) }
                    ), in: 100...1000, step: 25)

                    Text("\(wordsPerMinute) WPM")
                        .monospacedDigit()
                        .frame(width: 80)
                }

                // Progress
                ProgressView(value: Double(currentWordIndex), total: Double(words.count))
                    .tint(.accentColor)

                HStack {
                    Text("\(currentWordIndex) / \(words.count) words")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(estimatedTimeRemaining)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Play controls
                HStack(spacing: 32) {
                    // Restart
                    Button {
                        currentWordIndex = 0
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                    }

                    // Skip back 10 words
                    Button {
                        currentWordIndex = max(0, currentWordIndex - 10)
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                    }

                    // Play/Pause
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 60))
                    }

                    // Skip forward 10 words
                    Button {
                        currentWordIndex = min(words.count - 1, currentWordIndex + 10)
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                    }

                    // Jump to end
                    Button {
                        currentWordIndex = words.count - 1
                        isPlaying = false
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                    }
                }
            }
            .padding()
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                startReading()
            } else {
                stopReading()
            }
        }
        .onChange(of: currentWordIndex) { _, newValue in
            if words.indices.contains(newValue) {
                displayWord = words[newValue]
            }
        }
        .onAppear {
            if words.indices.contains(currentWordIndex) {
                displayWord = words[currentWordIndex]
            }
        }
    }

    // Calculate optimal focus position (ORP - Optimal Recognition Point)
    private var focusOffset: CGFloat {
        guard !displayWord.isEmpty else { return 0 }

        // ORP is typically around 1/3 from the left of the word
        let orpIndex = max(0, min(displayWord.count - 1, displayWord.count / 3))
        let charWidth: CGFloat = 24 // Approximate char width at font size 48

        let totalWidth = CGFloat(displayWord.count) * charWidth
        let orpPosition = CGFloat(orpIndex) * charWidth

        return orpPosition - (totalWidth / 2)
    }

    private var estimatedTimeRemaining: String {
        let wordsRemaining = words.count - currentWordIndex
        let minutesRemaining = Double(wordsRemaining) / Double(wordsPerMinute)

        if minutesRemaining < 1 {
            return "\(Int(minutesRemaining * 60))s remaining"
        }
        return "\(Int(minutesRemaining))m remaining"
    }

    private func startReading() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: msPerWord / 1000, repeats: true) { _ in
            if currentWordIndex < words.count - 1 {
                currentWordIndex += 1
            } else {
                isPlaying = false
            }
        }
    }

    private func stopReading() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Reading Heat Map (Shows reading patterns)

struct ReadingHeatMap: View {
    let sessions: [StatsReadingSession]
    let weeksToShow: Int = 12

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading Activity")
                .font(.headline)

            // Days of week labels
            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 4) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                }

                // Heat map grid
                HStack(spacing: 4) {
                    ForEach(0..<weeksToShow, id: \.self) { week in
                        VStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { day in
                                let date = dateFor(week: week, day: day)
                                let intensity = intensityFor(date: date)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorFor(intensity: intensity))
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorFor(intensity: intensity))
                        .frame(width: 12, height: 12)
                }

                Text("More")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func dateFor(week: Int, day: Int) -> Date {
        let today = Date()
        let daysBack = (weeksToShow - 1 - week) * 7 + (6 - day)
        return calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
    }

    private func intensityFor(date: Date) -> Double {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let minutesRead = sessions
            .filter { $0.startTime >= dayStart && $0.startTime < dayEnd }
            .reduce(0) { $0 + $1.duration / 60 }

        // Normalize to 0-1 (assuming 60 minutes as max)
        return min(1.0, minutesRead / 60)
    }

    private func colorFor(intensity: Double) -> Color {
        if intensity == 0 {
            return Color(.systemGray5)
        }
        return Color.green.opacity(0.3 + intensity * 0.7)
    }
}
