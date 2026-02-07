import SwiftUI

struct EnhancedReaderView: View {
    @StateObject var viewModel: ReaderViewModel
    @StateObject private var ttsEngine = TTSEngine.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var audiobookPlayer = AudiobookPlayer.shared
    @StateObject private var whispersyncManager = WhispersyncManager.shared

    @State private var showControls = false
    @State private var showSettings = false
    @State private var showChapterList = false
    @State private var showBookmarks = false
    @State private var showCharacterMap = false
    @State private var showTimeline = false
    @State private var showTTSControls = false
    @State private var isTTSExpanded = false
    @State private var showAIPanel = false
    @State private var controlsTimer: Timer?
    @State private var touchZone: TouchZone?
    @State private var showAudiobookPlayer = false
    @State private var hasAudiobook = false
    @State private var linkedAudiobook: Audiobook?

    // Paragraph translation
    @State private var showTranslationSheet = false
    @State private var translationParagraphIndex = 0
    @State private var translationParagraphText = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                themeManager.readerTheme.backgroundColor
                    .ignoresSafeArea()

                // Main content area (full screen, behind everything)
                ZStack {
                    // Show loading when book detail is being loaded
                    if viewModel.isLoadingBookDetail {
                        bookDetailLoadingView
                    } else if !viewModel.isReadyToRead {
                        // Error state - book detail failed to load
                        bookDetailErrorView
                    } else {
                        // Reader content (PagedReaderView handles gestures internally)
                        readerContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Offline indicator
                        if viewModel.isOfflineMode {
                            offlineIndicator
                        }

                        // Loading overlay (for chapter content)
                        if viewModel.isLoading {
                            loadingOverlay
                        }
                    }
                }

                // Always-visible chapter title (top-left) and progress (bottom-right)
                // These are in the outer ZStack so toolbars can cover them
                VStack {
                    HStack {
                        // Chapter title - top left (DEBUG: red background)
                        Text(viewModel.currentChapter?.title ?? "")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()
                }
                .allowsHitTesting(false)

                // Toolbars overlay (on top of indicators)
                VStack(spacing: 0) {
                    // Top bar (topBar) - contains back button
                    if showControls {
                        topBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    // Bottom bar (bottomBar) - contains chapter list & size settings
                    if showControls {
                        bottomBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // TTS Controls
                    if showTTSControls {
                        TTSControlView(
                            ttsEngine: ttsEngine,
                            isExpanded: $isTTSExpanded,
                            onClose: { showTTSControls = false }
                        )
                        .transition(.move(edge: .bottom))
                    }

                    // Whispersync Continue Prompt
                    if whispersyncManager.showContinuePrompt {
                        ContinuePromptView(
                            currentMode: .reading,
                            onContinue: {
                                if let audiobook = linkedAudiobook {
                                    showAudiobookPlayer = true
                                }
                            },
                            onDismiss: {}
                        )
                        .padding(.horizontal)
                    }

                    // Mini Audio Player
                    if audiobookPlayer.state.isActive && audiobookPlayer.currentAudiobook != nil {
                        MiniAudioPlayerView()
                            .onTapGesture { showAudiobookPlayer = true }
                    }
                }

                // AI Panel
                if showAIPanel, let text = viewModel.selectedText {
                    AIInteractionOverlay(
                        selectedText: text,
                        sentence: viewModel.selectedSentence ?? text,
                        onDismiss: {
                            showAIPanel = false
                            viewModel.clearSelection()
                        }
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showControls)
        .sheet(isPresented: $showSettings) {
            EnhancedReaderSettingsView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showChapterList) {
            EnhancedChapterListView(
                chapters: viewModel.bookDetail?.chapters ?? [],
                currentChapterIndex: viewModel.currentChapterIndex,
                onSelect: { chapter in
                    Task { await viewModel.goToChapter(chapter) }
                }
            )
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksView(bookId: viewModel.book.id) { position in
                Task {
                    await viewModel.loadChapter(at: position.chapterIndex)
                    // TODO: Scroll to position
                }
            }
        }
        // Search disabled - will be re-enabled after adding search index
        .sheet(isPresented: $showCharacterMap) {
            CharacterMapView(
                bookId: viewModel.book.id,
                bookTitle: viewModel.book.title
            )
        }
        .sheet(isPresented: $showTimeline) {
            StoryTimelineView(
                bookId: viewModel.book.id,
                bookTitle: viewModel.book.title,
                currentChapter: viewModel.currentChapterIndex
            ) { chapter, position in
                Task {
                    await viewModel.loadChapter(at: chapter)
                    // TODO: Scroll to position
                }
            }
        }
        .fullScreenCover(isPresented: $showAudiobookPlayer) {
            AudiobookPlayerView()
        }
        .sheet(isPresented: $showTranslationSheet) {
            TranslationSheet(
                bookId: viewModel.book.id,
                chapterId: viewModel.currentChapter?.id ?? "",
                paragraphIndex: translationParagraphIndex,
                originalText: translationParagraphText,
                onDismiss: {
                    showTranslationSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .task {
            // Load book detail first if not already loaded
            await viewModel.loadBookDetailIfNeeded()
            // Then load the chapter content
            if viewModel.isReadyToRead {
                await viewModel.loadChapter(at: viewModel.currentChapterIndex)
                await checkAudiobookAndSync()
                // Auto-download entire book in background
                await triggerAutoDownloadBook()
            }
        }
        .onDisappear {
            ttsEngine.stop()
            viewModel.saveLocalProgress()
            // Sync to server if authenticated
            Task {
                await ReadingProgressStore.shared.syncToServer(
                    bookId: viewModel.book.id,
                    chapter: viewModel.currentChapterIndex,
                    position: viewModel.scrollProgress
                )
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                viewModel.saveLocalProgress()
                // Sync to server if authenticated
                Task {
                    await ReadingProgressStore.shared.syncToServer(
                        bookId: viewModel.book.id,
                        chapter: viewModel.currentChapterIndex,
                        position: viewModel.scrollProgress
                    )
                }
            }
        }
        .onChange(of: viewModel.currentChapterIndex) { _, newIndex in
            Task {
                await whispersyncManager.updateProgress(
                    bookId: viewModel.book.id,
                    mode: .reading,
                    chapterIndex: newIndex,
                    position: viewModel.scrollProgress
                )
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 16) {
                // Audiobook button
                if hasAudiobook {
                    Button {
                        showAudiobookPlayer = true
                    } label: {
                        Image(systemName: "headphones")
                            .foregroundColor(audiobookPlayer.state.isActive ? .accentColor : .primary)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Reader Content

    private var readerContent: some View {
        Group {
            if viewModel.chapterContent != nil {
                // Three-WebView preloading container
                PagedWebViewContainer(
                    viewModel: viewModel,
                    themeManager: themeManager,
                    onProgressUpdate: { progress in
                        viewModel.updateScrollProgress(progress)
                    },
                    onTextSelected: { text, sentence in
                        // Disabled - using system text selection menu instead
                    },
                    onTap: {
                        withAnimation {
                            showControls.toggle()
                        }
                        resetControlsTimer()
                    },
                    onPageChange: { current, total in
                        viewModel.updatePageProgress(current: current, total: total)
                    },
                    onContentReady: {
                        // Content is ready and visible, hide loading overlay
                        viewModel.isLoading = false
                    },
                    onParagraphLongPress: { paragraphIndex, text in
                        translationParagraphIndex = paragraphIndex
                        translationParagraphText = text
                        showTranslationSheet = true
                    },
                    // Advanced typography settings
                    lineSpacing: themeManager.lineSpacing,
                    letterSpacing: themeManager.letterSpacing,
                    wordSpacing: themeManager.wordSpacing,
                    paragraphSpacing: themeManager.paragraphSpacing,
                    textAlignment: themeManager.textAlignment,
                    hyphenation: themeManager.hyphenation,
                    fontWeight: themeManager.fontWeight
                )
            } else if let error = viewModel.error {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("common.retry".localized) {
                        Task {
                            await viewModel.loadChapter(at: viewModel.currentChapterIndex)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 32) {
            // Chapter list (moved from top bar)
            Button {
                showChapterList = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
            }

            Spacer()

            // Settings (font size)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "textformat.size")
                    .font(.title3)
            }
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Touch Zones Overlay

    private func touchZonesOverlay(geometry: GeometryProxy) -> some View {
        ZStack {
            // Left zone - Previous page
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geometry.size.width * 0.25)
                .frame(maxHeight: .infinity)
                .position(x: geometry.size.width * 0.125, y: geometry.size.height / 2)
                .onTapGesture {
                    handleTouchZone(.left)
                }

            // Center zone - Toggle controls
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geometry.size.width * 0.5, height: geometry.size.height * 0.5)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .onTapGesture {
                    handleTouchZone(.center)
                }

            // Right zone - Next page
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geometry.size.width * 0.25)
                .frame(maxHeight: .infinity)
                .position(x: geometry.size.width * 0.875, y: geometry.size.height / 2)
                .onTapGesture {
                    handleTouchZone(.right)
                }

            // Show zone indicator when tapped (for visual feedback)
            if let zone = touchZone {
                zoneIndicator(for: zone, geometry: geometry)
            }
        }
        .allowsHitTesting(!showAIPanel)
    }

    private func zoneIndicator(for zone: TouchZone, geometry: GeometryProxy) -> some View {
        let icon: String
        let position: CGPoint

        switch zone {
        case .left:
            icon = "chevron.left"
            position = CGPoint(x: 50, y: geometry.size.height / 2)
        case .right:
            icon = "chevron.right"
            position = CGPoint(x: geometry.size.width - 50, y: geometry.size.height / 2)
        case .center:
            icon = "rectangle.and.hand.point.up.left"
            position = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        case .top, .bottom:
            icon = "arrow.up.and.down"
            position = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }

        return Image(systemName: icon)
            .font(.largeTitle)
            .foregroundColor(.white)
            .padding(20)
            .background(Circle().fill(Color.black.opacity(0.3)))
            .position(position)
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Offline Indicator

    private var offlineIndicator: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                Text("reader.offlineMode".localized)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
            .cornerRadius(16)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Loading Overlay

    private var bookDetailLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("reader.loadingBook".localized)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bookDetailErrorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text(viewModel.error ?? "reader.error.loadBookDetail".localized)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await viewModel.loadBookDetailIfNeeded()
                    if viewModel.isReadyToRead {
                        await viewModel.loadChapter(at: 0)
                    }
                }
            } label: {
                Text("common.retry".localized)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Button {
                dismiss()
            } label: {
                Text("common.close".localized)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            showControls = true  // Show controls when error occurs so user can exit
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("reader.loadingChapter".localized)
                    .font(.subheadline)
            }
            .foregroundColor(.white)
        }
    }

    // MARK: - Helper Methods

    private func handleTouchZone(_ zone: TouchZone) {
        withAnimation(.easeInOut(duration: 0.15)) {
            touchZone = zone
        }

        switch zone {
        case .left:
            // Scroll up or previous chapter
            if viewModel.scrollProgress <= 0.1 && viewModel.hasPreviousChapter {
                Task { await viewModel.goToPreviousChapter() }
            }
        case .right:
            // Scroll down or next chapter
            if viewModel.scrollProgress >= 0.9 && viewModel.hasNextChapter {
                Task { await viewModel.goToNextChapter() }
            }
        case .center:
            withAnimation {
                showControls.toggle()
            }
            resetControlsTimer()
        case .top, .bottom:
            break
        }

        // Clear zone indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                touchZone = nil
            }
        }
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        if showControls {
            controlsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                withAnimation {
                    showControls = false
                }
            }
        }
    }

    private func toggleBookmark() {
        Task {
            let position = BookmarkPosition(
                chapterIndex: viewModel.currentChapterIndex,
                paragraphIndex: nil,
                characterOffset: nil,
                scrollPercentage: viewModel.scrollProgress,
                cfiPath: nil
            )
            _ = await bookmarkManager.toggleBookmark(
                bookId: viewModel.book.id,
                chapterId: viewModel.currentChapter?.id ?? "",
                position: position
            )
        }
    }

    private var hasBookmarkAtCurrentPosition: Bool {
        let position = BookmarkPosition(
            chapterIndex: viewModel.currentChapterIndex,
            paragraphIndex: nil,
            characterOffset: nil,
            scrollPercentage: viewModel.scrollProgress,
            cfiPath: nil
        )
        return bookmarkManager.hasBookmark(bookId: viewModel.book.id, position: position)
    }

    private func getHighlightsForCurrentChapter() -> [Bookmark] {
        bookmarkManager.getHighlightsForChapter(
            bookId: viewModel.book.id,
            chapterId: viewModel.currentChapter?.id ?? ""
        )
    }

    private func startTTS() {
        guard let content = viewModel.chapterContent else { return }
        showTTSControls = true
        ttsEngine.speak(
            text: content.htmlContent,
            chapterId: content.id,
            bookTitle: viewModel.book.title,
            chapterTitle: content.title
        )
    }

    // MARK: - Audiobook & Whispersync Methods

    private func checkAudiobookAndSync() async {
        // Check if book has an audiobook
        if let audiobook = await whispersyncManager.getAudiobook(for: viewModel.book.id) {
            hasAudiobook = true
            linkedAudiobook = audiobook

            // Check for sync prompt
            await whispersyncManager.fetchSyncProgress(for: viewModel.book.id)
        }
    }

    /// Auto-download entire book in background when reader opens
    private func triggerAutoDownloadBook() async {
        guard let bookDetail = viewModel.bookDetail else { return }

        let offlineManager = OfflineManager.shared

        // Check if already downloaded or downloading
        if let existing = offlineManager.downloadedBooks.first(where: { $0.bookId == viewModel.book.id }) {
            if existing.isComplete {
                LoggingService.shared.debug(.reading, "📥 [AutoDownload] Book already downloaded: \(viewModel.book.title)", component: "EnhancedReaderView")
                return
            }
            if existing.status == .downloading {
                LoggingService.shared.debug(.reading, "📥 [AutoDownload] Book already downloading: \(viewModel.book.title)", component: "EnhancedReaderView")
                return
            }
        }

        // Check network status - respect user settings
        let networkStatus = offlineManager.networkStatus
        let settings = offlineManager.settings

        let shouldDownload: Bool
        switch networkStatus {
        case .wifi:
            shouldDownload = true
        case .cellular:
            // Allow cellular download only if user disabled "WiFi only" setting
            shouldDownload = !settings.downloadOnWifiOnly
        case .notConnected, .unknown:
            shouldDownload = false
        }

        guard shouldDownload else {
            LoggingService.shared.debug(.reading, "📥 [AutoDownload] Skipping auto-download due to network: \(networkStatus)", component: "EnhancedReaderView")
            return
        }

        LoggingService.shared.debug(.reading, "📥 [AutoDownload] Starting auto-download for book: \(viewModel.book.title)", component: "EnhancedReaderView")
        LoggingService.shared.debug(.reading, "📥 [AutoDownload] Total chapters: \(bookDetail.chapters.count)", component: "EnhancedReaderView")

        // Trigger background download with low priority
        await offlineManager.downloadBook(viewModel.book, bookDetail: bookDetail, priority: .low)

        LoggingService.shared.debug(.reading, "📥 [AutoDownload] Download queued successfully", component: "EnhancedReaderView")
    }

    private func switchToListening() async {
        guard let audiobook = linkedAudiobook else { return }

        // Load the audiobook at current reading position
        audiobookPlayer.loadAndPlay(
            audiobook: audiobook,
            startChapter: viewModel.currentChapterIndex,
            startPosition: 0
        )

        showAudiobookPlayer = true
    }

    private func syncAudioToReading() {
        // Update reading position from audiobook position
        if audiobookPlayer.state.isActive {
            let chapterIndex = audiobookPlayer.currentChapterIndex
            if chapterIndex != viewModel.currentChapterIndex {
                Task {
                    await viewModel.loadChapter(at: chapterIndex)
                }
            }
        }
    }
}

// MARK: - Touch Zone

enum TouchZone {
    case left, right, center, top, bottom
}

// MARK: - Selectable Text View

struct SelectableTextView: View {
    let content: String
    let highlights: [Bookmark]
    let ttsHighlightRange: NSRange?
    let settings: ThemeManager
    let onTextSelected: (String, String, NSRange) -> Void

    var body: some View {
        Text(content)
            .font(.system(size: settings.fontSize.size))
            .foregroundColor(settings.readerTheme.textColor)
            .lineSpacing(8)
            .textSelection(.disabled)
    }
}

// MARK: - AI Interaction Overlay

struct AIInteractionOverlay: View {
    let selectedText: String
    let sentence: String
    let onDismiss: () -> Void

    @StateObject private var aiService = AIService.shared
    @State private var action: AIAction = .explain

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                // Selected text preview
                Text("\"\(selectedText)\"")
                    .font(.subheadline)
                    .italic()
                    .lineLimit(2)
                    .padding()
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)

                // Action buttons
                HStack(spacing: 16) {
                    AIActionButton(icon: "lightbulb", title: "Explain", isSelected: action == .explain) {
                        action = .explain
                    }
                    AIActionButton(icon: "text.word.spacing", title: "Simplify", isSelected: action == .simplify) {
                        action = .simplify
                    }
                    AIActionButton(icon: "globe", title: "Translate", isSelected: action == .translate) {
                        action = .translate
                    }
                    AIActionButton(icon: "bookmark.fill", title: "Save", isSelected: false) {
                        // Save to vocabulary
                    }
                }

                // Result area
                if aiService.isLoading {
                    ProgressView()
                        .padding()
                } else if let result = aiService.lastResult {
                    ScrollView {
                        Text(result)
                            .font(.body)
                            .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                // Go button
                Button {
                    performAction()
                } label: {
                    Text("Go")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 20, y: -5)
            .padding()
        }
        .background(Color.black.opacity(0.3).onTapGesture(perform: onDismiss))
        .ignoresSafeArea()
    }

    private func performAction() {
        Task {
            switch action {
            case .explain:
                await aiService.explain(text: selectedText, context: sentence)
            case .simplify:
                await aiService.simplify(text: sentence)
            case .translate:
                await aiService.translate(text: selectedText)
            }
        }
    }

    enum AIAction {
        case explain, simplify, translate
    }
}

struct AIActionButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(width: 60, height: 60)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .cornerRadius(12)
        }
    }
}

// MARK: - Chapter List View

private struct EnhancedChapterListView: View {
    let chapters: [Chapter]
    let currentChapterIndex: Int
    let onSelect: (Chapter) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chapter.title)
                                .font(.subheadline)
                                .fontWeight(index == currentChapterIndex ? .semibold : .regular)

                            Text("\(chapter.wordCount ?? 0) words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if index == currentChapterIndex {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(chapter)
                        dismiss()
                    }
                }
            }
            .navigationTitle("reader.chapters".localized)
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

// MARK: - Enhanced Reader Settings View

struct EnhancedReaderSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Form {
                // Font Size
                Section("reader.settings.fontSize".localized) {
                    HStack {
                        ForEach(FontSize.allCases, id: \.self) { size in
                            Button {
                                LoggingService.shared.debug(.reading, "📖 [Settings] Font size button tapped: \(size.displayName)", component: "EnhancedReaderView")
                                LoggingService.shared.debug(.reading, "📖 [Settings] Current fontSize: \(themeManager.fontSize.displayName)", component: "EnhancedReaderView")
                                themeManager.fontSize = size
                                LoggingService.shared.debug(.reading, "📖 [Settings] New fontSize: \(themeManager.fontSize.displayName)", component: "EnhancedReaderView")
                            } label: {
                                Text(size.displayName)
                                    .font(.caption)
                                    .foregroundColor(themeManager.fontSize == size ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(themeManager.fontSize == size ? Color.accentColor : Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Theme
                Section("reader.settings.theme".localized) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ReaderTheme.allCases, id: \.self) { theme in
                            ThemeButton(
                                theme: theme,
                                isSelected: themeManager.readerTheme == theme
                            ) {
                                themeManager.readerTheme = theme
                            }
                        }
                    }
                }

                // Line Spacing
                Section("reader.settings.lineSpacing".localized) {
                    Picker("reader.settings.spacing".localized, selection: $themeManager.lineSpacing) {
                        Text("reader.spacing.compact".localized).tag(LineSpacing.compact)
                        Text("reader.spacing.normal".localized).tag(LineSpacing.normal)
                        Text("reader.spacing.relaxed".localized).tag(LineSpacing.relaxed)
                        Text("reader.spacing.extraRelaxed".localized).tag(LineSpacing.extraRelaxed)
                    }
                    .pickerStyle(.segmented)
                }

                // Auto Page
                Section("reader.settings.autoPage".localized) {
                    Toggle("reader.settings.enableAutoPage".localized, isOn: $themeManager.autoPageEnabled)

                    if themeManager.autoPageEnabled {
                        Picker("reader.settings.interval".localized, selection: $themeManager.autoPageInterval) {
                            ForEach(AutoPageInterval.allCases, id: \.self) { interval in
                                Text(interval.displayName).tag(interval)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.medium, .large])
    }
}

private struct ThemeButton: View {
    let theme: ReaderTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.backgroundColor)
                    .frame(height: 40)
                    .overlay(
                        Text("Aa")
                            .foregroundColor(theme.textColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )

                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Additional Models

struct EnhancedChapter: Codable, Identifiable {
    let id: String
    let bookId: String
    let title: String
    let orderIndex: Int
    let contentPath: String?
    let wordCount: Int
}
