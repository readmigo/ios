import SwiftUI

struct ReaderView: View {
    let book: Book
    let bookDetail: BookDetail

    @StateObject private var viewModel: ReaderViewModel
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @StateObject private var sessionTracker = StatsReadingSessionTracker.shared
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var showTextSelectionMenu = false
    @State private var showBookmarkList = false
    @State private var showPageTurnSettings = false
    @State private var showReadingStats = false
    @State private var showSearch = false
    @State private var showLoginPrompt = false
    @State private var loginPromptFeature = ""
    @State private var selectedHighlight: Bookmark?
    @State private var showHighlightDetail = false
    @State private var showImageViewer = false
    @State private var imageViewerImages: [BookImage] = []
    @State private var imageViewerIndex: Int = 0

    // Translation sheet state
    @State private var showTranslationSheet = false
    @State private var translationParagraphIndex: Int = 0
    @State private var translationParagraphText: String = ""

    init(book: Book, bookDetail: BookDetail) {
        self.book = book
        self.bookDetail = bookDetail
        _viewModel = StateObject(wrappedValue: ReaderViewModel(book: book, bookDetail: bookDetail))
    }

    /// 是否使用高级翻页引擎（物理模拟、3D渲染）
    private var useAdvancedPageTurn: Bool {
        themeManager.pageTurnSettings.mode.hasPhysics
    }

    var body: some View {
        ZStack {
            // Background
            themeManager.readerTheme.backgroundColor
                .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    LoadingView(onClose: { dismiss() })
                } else if let content = viewModel.chapterContent {
                    // Choose reader view based on page turn mode
                    if useAdvancedPageTurn {
                        // Advanced physics-based page turn
                        PageTurnReaderView(
                            content: content,
                            theme: themeManager.readerTheme,
                            fontSize: themeManager.fontSize,
                            font: themeManager.readerFont,
                            settings: themeManager.pageTurnSettings,
                            onProgressUpdate: { progress in
                                viewModel.updateScrollProgress(progress)
                            },
                            onTextSelected: { text, sentence in
                                viewModel.handleTextSelection(text: text, sentence: sentence)
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showTextSelectionMenu = true
                                }
                            },
                            onTap: {
                                toggleControls()
                            },
                            onPageChange: { current, total in
                                viewModel.updatePageProgress(current: current, total: total)
                            },
                            onReachChapterStart: {
                                if viewModel.hasPreviousChapter {
                                    Task { await viewModel.goToPreviousChapter(toLastPage: true) }
                                }
                            },
                            onReachChapterEnd: {
                                if viewModel.hasNextChapter {
                                    Task { await viewModel.goToNextChapter() }
                                }
                            }
                        )
                    } else {
                        // Standard WebView-based reader
                        ReaderContentView(
                            content: content,
                            theme: themeManager.readerTheme,
                            fontSize: themeManager.fontSize,
                            font: themeManager.readerFont,
                            readingMode: themeManager.readingMode,
                            autoPageEnabled: themeManager.autoPageEnabled,
                            autoPageInterval: themeManager.autoPageInterval,
                            onProgressUpdate: { progress in
                                viewModel.updateScrollProgress(progress)
                            },
                            onTextSelected: { text, sentence in
                                viewModel.handleTextSelection(text: text, sentence: sentence)
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showTextSelectionMenu = true
                                }
                            },
                            onTap: {
                                toggleControls()
                            },
                            onPageChange: { current, total in
                                viewModel.updatePageProgress(current: current, total: total)
                            },
                            onReachChapterStart: {
                                // Navigate to previous chapter when swiping back on first page
                                if viewModel.hasPreviousChapter {
                                    Task { await viewModel.goToPreviousChapter(toLastPage: true) }
                                }
                            },
                            onReachChapterEnd: {
                                // Navigate to next chapter when swiping forward on last page
                                if viewModel.hasNextChapter {
                                    Task { await viewModel.goToNextChapter() }
                                }
                            },
                            onAutoPageEnd: {
                                // Auto page reached chapter end
                                if viewModel.hasNextChapter {
                                    Task { await viewModel.goToNextChapter() }
                                }
                            },
                            // Highlights for current chapter
                            highlights: currentChapterHighlights,
                            onHighlightTap: { highlight in
                                // Show highlight detail popup for editing
                                selectedHighlight = highlight
                                showHighlightDetail = true
                            },
                            // Image viewer
                            onImageTap: { src, caption, allImages in
                                imageViewerImages = allImages.map { imgInfo in
                                    BookImage(
                                        id: imgInfo.id,
                                        src: imgInfo.src,
                                        alt: imgInfo.alt,
                                        caption: imgInfo.caption,
                                        chapterId: viewModel.currentChapter?.id ?? "",
                                        orderInChapter: imgInfo.index
                                    )
                                }
                                // Find the tapped image index
                                imageViewerIndex = allImages.firstIndex { $0.src == src } ?? 0
                                showImageViewer = true
                            },
                            // Paragraph translation
                            onParagraphLongPress: { paragraphIndex, text in
                                translationParagraphIndex = paragraphIndex
                                translationParagraphText = text
                                showTranslationSheet = true
                            },
                            // Advanced typography settings
                            letterSpacing: themeManager.letterSpacing,
                            wordSpacing: themeManager.wordSpacing,
                            paragraphSpacing: themeManager.paragraphSpacing,
                            textAlignment: themeManager.textAlignment,
                            hyphenation: themeManager.hyphenation,
                            fontWeight: themeManager.fontWeight,
                            // SE native CSS
                            stylesUrl: book.stylesUrl
                        )
                    }
                } else if let error = viewModel.error {
                    ErrorView(message: error, onClose: { dismiss() }, onRetry: {
                        Task {
                            await viewModel.loadChapter(at: viewModel.currentChapterIndex)
                        }
                    })
                }
            }

            // Mini progress indicator (shown when controls are hidden)
            if !showControls {
                VStack {
                    // Tappable progress bar at top
                    ProgressView(value: viewModel.overallProgress)
                        .tint(.blue)
                        .frame(height: 3)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showReadingStats.toggle()
                            }
                        }
                    Spacer()
                }
            }

            // Controls Overlay
            if showControls {
                VStack {
                    // Top Bar
                    ReaderTopBar(
                        title: viewModel.currentChapter?.title ?? book.title,
                        onClose: { dismiss() },
                        onSearch: { showSearch = true },
                        onChapterList: { viewModel.showChapterList = true }
                    )

                    Spacer()

                    // Bottom Bar (minimal - no progress display)
                    ReaderBottomBar()
                }
            }

            // Text Selection Menu
            if showTextSelectionMenu, let selectedText = viewModel.selectedText {
                VStack {
                    Spacer()
                    TextSelectionMenu(
                        selectedText: selectedText,
                        sentence: viewModel.selectedSentence ?? selectedText,
                        bookId: book.id,
                        chapterId: viewModel.currentChapter?.id ?? "",
                        chapterIndex: viewModel.currentChapterIndex,
                        scrollPercentage: viewModel.scrollProgress,
                        onHighlight: { _ in
                            // Check login for highlight
                            guard requireLoginForHighlight() else { return }
                            dismissTextSelectionMenu()
                        },
                        onAddNote: {
                            // Check login for note
                            guard requireLoginForHighlight() else { return }
                        },
                        onAIExplain: {
                            dismissTextSelectionMenu()
                            viewModel.showAIPanel = true
                        },
                        onAISimplify: {
                            dismissTextSelectionMenu()
                            viewModel.showAIPanel = true
                        },
                        onAITranslate: {
                            dismissTextSelectionMenu()
                            viewModel.showAIPanel = true
                        },
                        onCopy: {
                            dismissTextSelectionMenu()
                        },
                        onDismiss: {
                            dismissTextSelectionMenu()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(.keyboard)
            }

            // AI Panel
            if viewModel.showAIPanel, let selectedText = viewModel.selectedText {
                AIInteractionPanel(
                    selectedText: selectedText,
                    sentence: viewModel.selectedSentence ?? selectedText,
                    bookId: book.id,
                    chapterId: viewModel.currentChapter?.id,
                    onDismiss: {
                        viewModel.clearSelection()
                    }
                )
            }

            // Image Viewer (fullscreen overlay)
            if showImageViewer && !imageViewerImages.isEmpty {
                ImageViewer(
                    images: imageViewerImages,
                    currentIndex: $imageViewerIndex,
                    onDismiss: {
                        showImageViewer = false
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }

            // Reading Stats Overlay (shown when controls are hidden and tapped on progress)
            VStack {
                HStack {
                    Spacer()
                    ReadingStatsOverlay(
                        tracker: sessionTracker,
                        isVisible: showReadingStats && !showControls,
                        position: .topRight
                    )
                    .padding(.trailing, 16)
                    .padding(.top, 50)
                }
                Spacer()
            }
            .animation(.easeInOut(duration: 0.2), value: showReadingStats)
        }
        .preferredColorScheme(themeManager.readerTheme == .dark ? .dark : .light)
        .sheet(isPresented: $viewModel.showSettings) {
            ReaderSettingsView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showPageTurnSettings) {
            PageTurnSettingsView(settingsManager: PageTurnSettingsManager.shared)
        }
        .sheet(isPresented: $viewModel.showChapterList) {
            ChapterListView(
                chapters: bookDetail.chapters,
                currentIndex: viewModel.currentChapterIndex
            ) { chapter in
                viewModel.showChapterList = false
                Task { await viewModel.goToChapter(chapter) }
            }
        }
        .sheet(isPresented: $showBookmarkList) {
            BookmarkListView(
                bookId: book.id,
                bookTitle: book.title,
                chapters: bookDetail.chapters,
                currentChapterIndex: viewModel.currentChapterIndex,
                onNavigate: { bookmark in
                    showBookmarkList = false
                    Task {
                        await viewModel.navigateToBookmark(bookmark)
                    }
                }
            )
        }
        .sheet(isPresented: $showSearch) {
            BookSearchView(
                bookId: book.id,
                chapters: bookDetail.chapters,
                onNavigate: { chapterId, position in
                    showSearch = false
                    Task {
                        await viewModel.navigateToChapter(chapterId: chapterId, position: position)
                    }
                }
            )
        }
        .sheet(isPresented: $showHighlightDetail) {
            if let highlight = selectedHighlight {
                HighlightDetailPopup(
                    highlight: highlight,
                    onDismiss: {
                        showHighlightDetail = false
                        selectedHighlight = nil
                    },
                    onEdit: { updatedHighlight in
                        Task {
                            await bookmarkManager.updateBookmark(
                                updatedHighlight,
                                title: updatedHighlight.title,
                                note: updatedHighlight.note,
                                highlightColor: updatedHighlight.highlightColor
                            )
                        }
                        showHighlightDetail = false
                        selectedHighlight = nil
                    },
                    onDelete: { highlightToDelete in
                        Task {
                            await bookmarkManager.deleteBookmark(highlightToDelete)
                        }
                        showHighlightDetail = false
                        selectedHighlight = nil
                    },
                    onChangeColor: { highlightToUpdate, newColor in
                        Task {
                            await bookmarkManager.updateBookmark(
                                highlightToUpdate,
                                title: highlightToUpdate.title,
                                note: highlightToUpdate.note,
                                highlightColor: newColor
                            )
                        }
                        // Haptic feedback for color change
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    },
                    onCopy: { text in
                        UIPasteboard.general.string = text
                        // Show brief feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }
        }
        .sheet(isPresented: $showTranslationSheet) {
            TranslationSheet(
                bookId: book.id,
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
            await viewModel.loadChapter(at: 0)
            await bookmarkManager.fetchBookmarks(bookId: book.id)
            // Start reading session
            sessionTracker.startSession(totalWords: book.wordCount ?? 0)
            // Auto-download book for offline reading (low priority, background)
            await OfflineManager.shared.downloadBook(book, bookDetail: bookDetail, priority: .low)
        }
        .onDisappear {
            // End reading session when leaving reader
            sessionTracker.endSession()
        }
        .statusBarHidden(!showControls)
        .loginPrompt(isPresented: $showLoginPrompt, feature: loginPromptFeature)
    }

    // MARK: - Guest Mode Helpers

    private func requireLoginForBookmark() -> Bool {
        if authManager.isAuthenticated {
            return true
        } else {
            loginPromptFeature = "bookmark"
            showLoginPrompt = true
            return false
        }
    }

    private func requireLoginForHighlight() -> Bool {
        if authManager.isAuthenticated {
            return true
        } else {
            loginPromptFeature = "highlight"
            showLoginPrompt = true
            return false
        }
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }

        if showControls {
            scheduleHideControls()
        } else {
            hideControlsTask?.cancel()
        }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation {
                    showControls = false
                }
            }
        }
    }

    private func dismissTextSelectionMenu() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showTextSelectionMenu = false
        }
        viewModel.clearSelection()
    }

    // MARK: - Bookmark Helpers

    private var currentBookmarkPosition: BookmarkPosition {
        BookmarkPosition(
            chapterIndex: viewModel.currentChapterIndex,
            paragraphIndex: nil,
            characterOffset: nil,
            scrollPercentage: viewModel.scrollProgress,
            cfiPath: nil
        )
    }

    private var isCurrentPositionBookmarked: Bool {
        bookmarkManager.hasBookmark(bookId: book.id, position: currentBookmarkPosition)
    }

    private var currentChapterHighlights: [Bookmark] {
        guard let chapterId = viewModel.currentChapter?.id else { return [] }
        return bookmarkManager.getHighlightsForChapter(bookId: book.id, chapterId: chapterId)
    }

    private func toggleBookmark() {
        // Check login for bookmark
        guard requireLoginForBookmark() else { return }

        Task {
            let chapterId = viewModel.currentChapter?.id ?? ""
            let wasBookmarked = await bookmarkManager.toggleBookmark(
                bookId: book.id,
                chapterId: chapterId,
                position: currentBookmarkPosition
            )

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            // Show brief feedback
            if wasBookmarked {
                // Bookmark was added
            } else {
                // Bookmark was removed
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var onClose: (() -> Void)?

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("reader.loading".localized)
                    .foregroundColor(.secondary)
            }

            // Close button always visible during loading
            if let onClose = onClose {
                VStack {
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    var onClose: (() -> Void)?
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)

                Text(message)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    if let onClose = onClose {
                        Button("reader.exit".localized) {
                            onClose()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("error.retry".localized, action: onRetry)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            // Close button always visible on error
            if let onClose = onClose {
                VStack {
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Top Bar

struct ReaderTopBar: View {
    let title: String
    let onClose: () -> Void
    let onSearch: () -> Void
    let onChapterList: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                // Search button
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }

                // Chapter list button
                Button(action: onChapterList) {
                    Image(systemName: "list.bullet")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            .ultraThinMaterial,
            in: Rectangle()
        )
    }
}

// MARK: - Bottom Bar

struct ReaderBottomBar: View {
    var body: some View {
        // Empty bottom bar - no progress display
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: 44)
    }
}

// MARK: - Bookmark List

struct BookmarkListView: View {
    let bookId: String
    let bookTitle: String
    let chapters: [Chapter]
    let currentChapterIndex: Int
    let onNavigate: (Bookmark) -> Void

    @StateObject private var bookmarkManager = BookmarkManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: BookmarkFilter = .all
    @State private var searchText = ""
    @State private var editingBookmark: Bookmark?

    enum BookmarkFilter: String, CaseIterable {
        case all
        case bookmarks
        case highlights
        case annotations

        var displayName: String {
            switch self {
            case .all: return "reader.bookmarks.filter.all".localized
            case .bookmarks: return "reader.bookmarks.filter.bookmarks".localized
            case .highlights: return "reader.bookmarks.filter.highlights".localized
            case .annotations: return "reader.bookmarks.filter.notes".localized
            }
        }

        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .bookmarks: return "bookmark.fill"
            case .highlights: return "highlighter"
            case .annotations: return "note.text"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(BookmarkFilter.allCases, id: \.self) { filter in
                        Label(filter.displayName, systemImage: filter.icon)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("reader.bookmarks.search".localized, text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)

                Divider()

                // Bookmarks List
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(groupedItems.keys.sorted(), id: \.self) { chapterIndex in
                            Section {
                                ForEach(groupedItems[chapterIndex] ?? []) { bookmark in
                                    ReaderBookmarkRow(
                                        bookmark: bookmark,
                                        chapterTitle: chapterTitle(for: bookmark.chapterId)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        onNavigate(bookmark)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteBookmark(bookmark)
                                        } label: {
                                            Label("common.delete".localized, systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button {
                                            editingBookmark = bookmark
                                        } label: {
                                            Label("common.edit".localized, systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            } header: {
                                Text(chapters[safe: chapterIndex]?.title ?? "Chapter \(chapterIndex + 1)")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("reader.bookmarks.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            clearAllBookmarks()
                        } label: {
                            Label("reader.bookmarks.clearAll".localized, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $editingBookmark) { bookmark in
                EditBookmarkView(bookmark: bookmark)
            }
        }
    }

    // MARK: - Computed Properties

    private var allItems: [Bookmark] {
        bookmarkManager.getAllItems(for: bookId)
    }

    private var filteredItems: [Bookmark] {
        var items: [Bookmark]

        switch selectedFilter {
        case .all:
            items = allItems
        case .bookmarks:
            items = bookmarkManager.getBookmarks(for: bookId)
        case .highlights:
            items = bookmarkManager.getHighlights(for: bookId)
        case .annotations:
            items = bookmarkManager.getAnnotations(for: bookId)
        }

        if !searchText.isEmpty {
            items = items.filter { bookmark in
                let searchLower = searchText.lowercased()
                return bookmark.title?.lowercased().contains(searchLower) == true ||
                    bookmark.note?.lowercased().contains(searchLower) == true ||
                    bookmark.selectedText?.lowercased().contains(searchLower) == true
            }
        }

        return items.sorted { $0.position.chapterIndex < $1.position.chapterIndex }
    }

    private var groupedItems: [Int: [Bookmark]] {
        Dictionary(grouping: filteredItems) { $0.position.chapterIndex }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: selectedFilter == .all ? "bookmark.slash" : selectedFilter.icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(emptyStateSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "reader.bookmarks.noResults".localized
        }

        switch selectedFilter {
        case .all:
            return "reader.bookmarks.empty".localized
        case .bookmarks:
            return "reader.bookmarks.noBookmarks".localized
        case .highlights:
            return "reader.bookmarks.noHighlights".localized
        case .annotations:
            return "reader.bookmarks.noNotes".localized
        }
    }

    private var emptyStateSubtitle: String {
        if !searchText.isEmpty {
            return "reader.bookmarks.tryDifferentSearch".localized
        }

        switch selectedFilter {
        case .all, .bookmarks:
            return "reader.bookmarks.tapToAdd".localized
        case .highlights:
            return "reader.bookmarks.selectTextToHighlight".localized
        case .annotations:
            return "reader.bookmarks.selectTextToAnnotate".localized
        }
    }

    // MARK: - Helper Methods

    private func chapterTitle(for chapterId: String) -> String {
        chapters.first { $0.id == chapterId }?.title ?? ""
    }

    private func deleteBookmark(_ bookmark: Bookmark) {
        Task {
            await bookmarkManager.deleteBookmark(bookmark)
        }
    }

    private func clearAllBookmarks() {
        Task {
            for bookmark in filteredItems {
                await bookmarkManager.deleteBookmark(bookmark)
            }
        }
    }
}

// MARK: - Reader Bookmark Row

struct ReaderBookmarkRow: View {
    let bookmark: Bookmark
    let chapterTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with type icon and chapter info
            HStack(spacing: 8) {
                Image(systemName: bookmark.type.icon)
                    .font(.caption)
                    .foregroundColor(iconColor)

                Text(chapterTitle.isEmpty ? bookmark.position.description : chapterTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(bookmark.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Selected text with highlight background (for highlights/annotations)
            if let selectedText = bookmark.selectedText, !selectedText.isEmpty {
                Text(selectedText)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(highlightBackgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(highlightBorderColor, lineWidth: 1)
                    )
            }

            // Note with quote styling
            if let note = bookmark.note, !note.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .italic()
                }
                .padding(.leading, 4)
            }

            // Title (for bookmarks with custom titles)
            if let title = bookmark.title, !title.isEmpty,
               bookmark.type == .bookmark {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }

    private var iconColor: Color {
        if let highlightColor = bookmark.highlightColor {
            return highlightColor.color
        }
        return bookmark.type.color
    }

    private var highlightBackgroundColor: Color {
        if let color = bookmark.highlightColor {
            return color.backgroundColor
        }
        switch bookmark.type {
        case .highlight:
            return Color.yellow.opacity(0.2)
        case .annotation:
            return Color.orange.opacity(0.1)
        case .bookmark:
            return Color.blue.opacity(0.1)
        }
    }

    private var highlightBorderColor: Color {
        if let color = bookmark.highlightColor {
            return color.color.opacity(0.3)
        }
        return Color.clear
    }
}

// MARK: - Edit Bookmark View

struct EditBookmarkView: View {
    let bookmark: Bookmark

    @StateObject private var bookmarkManager = BookmarkManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var note: String
    @State private var selectedColor: HighlightColor

    init(bookmark: Bookmark) {
        self.bookmark = bookmark
        _title = State(initialValue: bookmark.title ?? "")
        _note = State(initialValue: bookmark.note ?? "")
        _selectedColor = State(initialValue: bookmark.highlightColor ?? .yellow)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("reader.bookmarks.edit.title".localized) {
                    TextField("reader.bookmarks.edit.titlePlaceholder".localized, text: $title)
                }

                Section("reader.bookmarks.edit.note".localized) {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }

                if bookmark.type == .highlight || bookmark.type == .annotation {
                    Section("reader.bookmarks.edit.color".localized) {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(HighlightColor.allCases, id: \.self) { color in
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                if let selectedText = bookmark.selectedText {
                    Section("reader.bookmarks.edit.selectedText".localized) {
                        Text(selectedText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("reader.bookmarks.edit.heading".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
                        saveBookmark()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveBookmark() {
        Task {
            await bookmarkManager.updateBookmark(
                bookmark,
                title: title.isEmpty ? nil : title,
                note: note.isEmpty ? nil : note,
                highlightColor: selectedColor
            )
            dismiss()
        }
    }
}

// MARK: - Safe Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Chapter List

struct ChapterListView: View {
    let chapters: [Chapter]
    let currentIndex: Int
    let onSelect: (Chapter) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        onSelect(chapter)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .foregroundColor(index == currentIndex ? .blue : .primary)
                                    .fontWeight(index == currentIndex ? .semibold : .regular)

                                if let wordCount = chapter.wordCount {
                                    Text("\(wordCount) words")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if index == currentIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
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
