import SwiftUI

struct AudiobookPlayerView: View {
    @ObservedObject var player: AudiobookPlayer = .shared
    @StateObject private var downloadManager = AudiobookDownloadManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showChapterList = false
    @State private var showSpeedPicker = false
    @State private var showSleepTimer = false
    @State private var showDownloads = false
    @State private var isDraggingSlider = false
    @State private var dragPosition: TimeInterval = 0
    @State private var coverImage: UIImage?
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)

                    // Cover and info
                    coverSection

                    Spacer().frame(height: 40)

                    // Progress slider
                    progressSection
                        .padding(.horizontal, 24)

                    // Playback controls
                    playbackControls

                    // Additional controls
                    additionalControls
                        .padding(.horizontal, 24)

                    Spacer().frame(height: 40)
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle(player.currentAudiobook?.title ?? "audiobook.untitled".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showChapterList = true
                        } label: {
                            Label("audiobook.chapters".localized, systemImage: "list.bullet")
                        }

                        // Download options
                        if let audiobook = player.currentAudiobook {
                            Divider()

                            let status = downloadManager.getDownloadStatus(audiobookId: audiobook.id)

                            if status == .notDownloaded {
                                Button {
                                    downloadManager.downloadAudiobook(audiobook)
                                } label: {
                                    Label("audiobook.downloadAll".localized, systemImage: "arrow.down.circle")
                                }
                            } else if status == .downloading {
                                Button {
                                    downloadManager.pauseDownload(audiobookId: audiobook.id)
                                } label: {
                                    Label("audiobook.pauseDownload".localized, systemImage: "pause.circle")
                                }
                            } else if status == .paused {
                                Button {
                                    downloadManager.resumeDownload(audiobookId: audiobook.id)
                                } label: {
                                    Label("audiobook.resumeDownload".localized, systemImage: "play.circle")
                                }
                            } else if status == .completed {
                                Button(role: .destructive) {
                                    downloadManager.deleteAudiobook(audiobookId: audiobook.id)
                                } label: {
                                    Label("audiobook.deleteDownload".localized, systemImage: "trash")
                                }
                            }

                            Button {
                                showDownloads = true
                            } label: {
                                Label("audiobook.manageDownloads".localized, systemImage: "square.and.arrow.down")
                            }
                        }

                        if player.currentAudiobook?.hasBookSync == true {
                            Divider()

                            Button {
                                // Switch to reading mode
                            } label: {
                                Label("audiobook.switchToReading".localized, systemImage: "book")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            }
            .background(Color(.systemBackground))
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow right swipe from left edge
                        if value.startLocation.x < 30 && value.translation.width > 0 {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        if dragOffset > geometry.size.width * 0.3 {
                            // Dismiss with animation
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = geometry.size.width
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                dismiss()
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showChapterList) {
            AudiobookChapterListView(player: player)
        }
        .sheet(isPresented: $showDownloads) {
            AudiobookDownloadsView()
        }
    }

    // MARK: - Cover Section

    private var coverSection: some View {
        VStack(alignment: .center, spacing: 24) {
            // Cover image with reflection effect
            ZStack {
                // Shadow/glow effect
                AsyncImage(url: URL(string: player.currentAudiobook?.coverUrl ?? "")) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .blur(radius: 30)
                            .opacity(0.5)
                            .scaleEffect(0.95)
                            .offset(y: 20)
                    }
                }

                // Main cover
                AsyncImage(url: URL(string: player.currentAudiobook?.coverUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure, .empty:
                        placeholderCover
                    @unknown default:
                        placeholderCover
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
            }
            .frame(width: 300, height: 300)

            // Title and author
            VStack(spacing: 10) {
                Text(player.currentAudiobook?.title ?? "audiobook.untitled".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(player.currentAudiobook?.author ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let narrator = player.currentAudiobook?.narrator {
                    Text("audiobook.narratedBy".localized + " " + narrator)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Chapter indicator with cache status
                if let chapter = player.currentChapter {
                    HStack(spacing: 6) {
                        Text(chapter.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)

                        // Cache indicator
                        if player.isPlayingFromCache {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .clipShape(Capsule())
                    .padding(.top, 8)
                }
            }
        }
    }

    private var placeholderCover: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: "headphones")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)
            }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            // Custom progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(height: 6)

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth(in: geo.size.width), height: 6)

                    // Draggable thumb
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        .offset(x: thumbOffset(in: geo.size.width))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDraggingSlider = true
                                    let percentage = max(0, min(1, value.location.x / geo.size.width))
                                    dragPosition = percentage * player.duration
                                }
                                .onEnded { _ in
                                    player.seek(to: dragPosition)
                                    isDraggingSlider = false
                                }
                        )
                }
                .frame(height: 16)
            }
            .frame(height: 16)

            // Time labels
            HStack {
                Text(formatTime(isDraggingSlider ? dragPosition : player.currentPosition))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Spacer()

                Text("-" + formatTime(player.duration - (isDraggingSlider ? dragPosition : player.currentPosition)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 24)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard player.duration > 0 else { return 0 }
        let progress = (isDraggingSlider ? dragPosition : player.currentPosition) / player.duration
        return totalWidth * CGFloat(progress)
    }

    private func thumbOffset(in totalWidth: CGFloat) -> CGFloat {
        guard player.duration > 0 else { return 0 }
        let progress = (isDraggingSlider ? dragPosition : player.currentPosition) / player.duration
        return (totalWidth - 16) * CGFloat(progress)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 32) {
            // Previous chapter
            Button {
                player.previousChapter()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            // Skip backward 15s
            Button {
                player.seek(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.largeTitle)
                    .foregroundColor(.primary)
            }

            // Play/Pause - larger central button
            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 80, height: 80)
                        .shadow(color: .accentColor.opacity(0.3), radius: 20)

                    if player.isBuffering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: player.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .offset(x: player.state.isPlaying ? 0 : 3)
                    }
                }
            }

            // Skip forward 15s
            Button {
                player.seek(by: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.largeTitle)
                    .foregroundColor(.primary)
            }

            // Next chapter
            Button {
                player.nextChapter()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Additional Controls

    private var additionalControls: some View {
        HStack(spacing: 0) {
            // Chapters
            Button {
                showChapterList = true
            } label: {
                controlButton(icon: "list.bullet", label: "audiobook.chapters".localized)
            }

            Spacer()

            // Speed
            Button {
                showSpeedPicker = true
            } label: {
                VStack(spacing: 6) {
                    Text(String(format: "%.1fx", player.playbackSpeed))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("audiobook.speed".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 60)
            }
            .confirmationDialog("audiobook.playbackSpeed".localized, isPresented: $showSpeedPicker) {
                ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                    Button(speed.displayText) {
                        player.setPlaybackSpeed(Float(speed.rawValue))
                    }
                }
            }

            Spacer()

            // Sleep timer
            Button {
                showSleepTimer = true
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        Image(systemName: "moon.fill")
                            .font(.title3)
                            .foregroundColor(.primary)

                        if player.sleepTimerRemaining != nil {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                                .offset(x: 12, y: -10)
                        }
                    }
                    Text(sleepTimerText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 60)
            }
            .confirmationDialog("audiobook.sleepTimer".localized, isPresented: $showSleepTimer) {
                ForEach(SleepTimerOption.allCases, id: \.self) { option in
                    Button(option.displayText) {
                        player.setSleepTimer(option)
                    }
                }
            }

            Spacer()

            // Whispersync (if available)
            if player.currentAudiobook?.hasBookSync == true {
                Button {
                    // Navigate to book
                } label: {
                    controlButton(icon: "arrow.triangle.2.circlepath", label: "audiobook.sync".localized, tint: .accentColor)
                }
            } else {
                // Placeholder for layout balance
                controlButton(icon: "square.and.arrow.up", label: "common.share".localized)
                    .opacity(0.5)
            }
        }
        .padding(.horizontal, 8)
    }

    private func controlButton(icon: String, label: String, tint: Color = .primary) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(tint)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }

    // MARK: - Helpers

    private var sleepTimerText: String {
        if let remaining = player.sleepTimerRemaining {
            let minutes = Int(remaining / 60)
            if minutes >= 60 {
                let hours = minutes / 60
                let mins = minutes % 60
                return "\(hours)h \(mins)m"
            }
            return "\(minutes)m"
        }
        return "audiobook.timer".localized
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Audiobook Chapter List View

struct AudiobookChapterListView: View {
    @ObservedObject var player: AudiobookPlayer
    @ObservedObject var cacheManager: AudioCacheManager = .shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let chapters = player.currentAudiobook?.chapters {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        ChapterRow(
                            chapter: chapter,
                            isPlaying: index == player.currentChapterIndex && player.state.isPlaying,
                            isCurrent: index == player.currentChapterIndex,
                            isCached: cacheManager.isCached(chapterId: chapter.id),
                            downloadProgress: cacheManager.downloadProgress[chapter.id]
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.goToChapter(index)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("audiobook.chapters".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ChapterRow: View {
    let chapter: AudiobookChapter
    let isPlaying: Bool
    let isCurrent: Bool
    var isCached: Bool = false
    var downloadProgress: Double? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Chapter number or playing indicator
            ZStack {
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .symbolEffect(.variableColor.iterative.reversing)
                } else {
                    Text("\(chapter.chapterNumber)")
                        .font(.caption)
                        .foregroundColor(isCurrent ? .accentColor : .secondary)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.title)
                    .font(.subheadline)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundColor(isCurrent ? .accentColor : .primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(chapter.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let reader = chapter.readerName {
                        Text("• " + reader)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Cache status indicator
            if let progress = downloadProgress, progress < 1.0 {
                // Downloading
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(-90))
                }
            } else if isCached {
                // Cached
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            if isCurrent {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}
