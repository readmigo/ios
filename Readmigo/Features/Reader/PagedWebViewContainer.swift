import SwiftUI

/// View state for a loaded chapter - uses chapterId as stable identity
struct ChapterViewState: Identifiable {
    let id: String              // chapterId - stable identity for SwiftUI
    let chapterIndex: Int
    let content: ChapterContent
    var offset: CGFloat
    var isReady: Bool = false
    var isLoading: Bool = true
    var startFromLastPage: Bool
    var isCurrent: Bool = false // Whether this is the currently displayed chapter
}

/// Container managing WebViews for chapters with preloading
/// Uses ForEach + stable ID to preserve WebView instances during navigation
struct PagedWebViewContainer: View {
    // ViewModel reference
    @ObservedObject var viewModel: ReaderViewModel

    // Theme and settings
    @ObservedObject var themeManager: ThemeManager

    // Callbacks
    let onProgressUpdate: (Double) -> Void
    let onTextSelected: (String, String) -> Void
    let onTap: () -> Void
    let onPageChange: ((Int, Int) -> Void)?
    let onContentReady: () -> Void

    // Typography settings
    var lineSpacing: LineSpacing
    var letterSpacing: CGFloat
    var wordSpacing: CGFloat
    var paragraphSpacing: CGFloat
    var textAlignment: ReaderTextAlignment
    var hyphenation: Bool
    var fontWeight: ReaderFontWeight

    // Chapter views array - max 3 elements, keyed by chapterId
    @State private var chapterViews: [ChapterViewState] = []

    // Animation state
    @State private var isTransitioning = false

    // Internal navigation flag - prevents onChange from clearing views during chapter transitions
    @State private var isInternalNavigation = false

    // Screen width for offset calculation
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width

    // Performance optimization
    @State private var performanceLevel: PerformanceLevel = .full
    @State private var lastProgressCheck: Double = 0

    // Performance levels for degradation
    enum PerformanceLevel {
        case full        // 3 WebViews, preload both
        case medium      // 3 WebViews, preload next only
        case minimal     // 1 WebView, no preload
    }

    // Memory monitoring
    private var availableMemoryMB: Double {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        return Double(physicalMemory) / 1024 / 1024
    }

    private var isLowPowerModeEnabled: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    // DEBUG: Enable colored backgrounds for debugging
    private let debugColorsEnabled = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Render all loaded chapter WebViews using ForEach
                // SwiftUI will preserve view identity based on chapterId
                ForEach($chapterViews) { $chapterView in
                    ZStack {
                        // DEBUG: Border color based on position
                        if debugColorsEnabled {
                            let borderColor = getBorderColor(for: chapterView)
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(borderColor, lineWidth: 4)
                        }

                        ReaderContentView(
                            content: chapterView.content,
                            theme: themeManager.readerTheme,
                            fontSize: themeManager.fontSize,
                            font: themeManager.readerFont,
                            readingMode: themeManager.readingMode,
                            autoPageEnabled: themeManager.autoPageEnabled,
                            autoPageInterval: themeManager.autoPageInterval,
                            onProgressUpdate: { progress in
                                if chapterView.isCurrent {
                                    onProgressUpdate(progress)
                                    checkProgressAndPreload(progress: progress)
                                }
                            },
                            onTextSelected: { text, context in
                                if chapterView.isCurrent {
                                    onTextSelected(text, context)
                                }
                            },
                            onTap: onTap,
                            onPageChange: chapterView.isCurrent ? onPageChange : nil,
                            onReachChapterStart: chapterView.isCurrent ? {
                                handleReachChapterStart()
                            } : nil,
                            onReachChapterEnd: chapterView.isCurrent ? {
                                handleReachChapterEnd()
                            } : nil,
                            onAutoPageEnd: nil,
                            onContentReady: {
                                LoggingService.shared.debug(.reading, "📗 [ChapterView] contentReady - chapter:\(chapterView.chapterIndex), id:\(chapterView.id.prefix(8)), isCurrent:\(chapterView.isCurrent)", component: "PagedWebViewContainer")
                                chapterView.isReady = true
                                chapterView.isLoading = false
                                if chapterView.isCurrent {
                                    onContentReady()
                                    // Start preloading immediately after current chapter is ready
                                    Task {
                                        await startPreloading()
                                    }
                                }
                            },
                            lineSpacing: lineSpacing,
                            letterSpacing: letterSpacing,
                            wordSpacing: wordSpacing,
                            paragraphSpacing: paragraphSpacing,
                            textAlignment: textAlignment,
                            hyphenation: hyphenation,
                            fontWeight: fontWeight,
                            startFromLastPage: chapterView.startFromLastPage
                        )

                        // DEBUG: Yellow overlay when loading
                        if debugColorsEnabled && chapterView.isLoading {
                            Color.yellow.opacity(0.5)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: chapterView.offset)
                }

                // DEBUG: Status overlay
                if debugColorsEnabled {
                    VStack {
                        Text("DEBUG MODE (ForEach)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)

                        let sortedViews = chapterViews.sorted { $0.chapterIndex < $1.chapterIndex }
                        Text("chapters: \(sortedViews.map { "\($0.chapterIndex)" }.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)

                        if let current = chapterViews.first(where: { $0.isCurrent }) {
                            Text("current: \(current.chapterIndex)")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }

                        Text("isTransitioning: \(isTransitioning ? "YES" : "NO")")
                            .font(.caption2)
                            .foregroundColor(isTransitioning ? .yellow : .white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)

                        Spacer()
                    }
                    .padding(.top, 60)
                }
            }
            .onAppear {
                screenWidth = geometry.size.width
                evaluatePerformanceLevel()
                initializeChapterViews()
            }
            .onChange(of: viewModel.currentChapterIndex) { newIndex in
                handleExternalChapterChange(newIndex: newIndex)
            }
            .onChange(of: viewModel.chapterContent?.id) { _ in
                if let content = viewModel.chapterContent {
                    handleContentLoaded(content: content)
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func getBorderColor(for chapterView: ChapterViewState) -> Color {
        if chapterView.isCurrent {
            return .green
        } else if chapterView.chapterIndex < viewModel.currentChapterIndex {
            return .red
        } else {
            return .blue
        }
    }

    // MARK: - Initialization

    private func initializeChapterViews() {
        LoggingService.shared.debug(.reading, "⚪️ [Init] ========== initializeChapterViews ==========", component: "PagedWebViewContainer")
        LoggingService.shared.debug(.reading, "⚪️ [Init] viewModel.currentChapterIndex: \(viewModel.currentChapterIndex)", component: "PagedWebViewContainer")

        guard let content = viewModel.chapterContent else {
            LoggingService.shared.debug(.reading, "⚪️ [Init] No content available", component: "PagedWebViewContainer")
            return
        }

        // Create initial current chapter view
        let currentView = ChapterViewState(
            id: content.id,
            chapterIndex: viewModel.currentChapterIndex,
            content: content,
            offset: 0,
            startFromLastPage: viewModel.shouldStartFromLastPage,
            isCurrent: true
        )

        chapterViews = [currentView]
        LoggingService.shared.debug(.reading, "⚪️ [Init] Created current chapter view: index=\(viewModel.currentChapterIndex), id=\(content.id.prefix(8))", component: "PagedWebViewContainer")
    }

    private func handleContentLoaded(content: ChapterContent) {
        // Check if this content is already in our views
        if let index = chapterViews.firstIndex(where: { $0.id == content.id }) {
            // Update existing view
            chapterViews[index].isLoading = true
            chapterViews[index].isReady = false
        } else if chapterViews.first(where: { $0.isCurrent })?.chapterIndex != viewModel.currentChapterIndex {
            // External chapter change - create new current view
            let newView = ChapterViewState(
                id: content.id,
                chapterIndex: viewModel.currentChapterIndex,
                content: content,
                offset: 0,
                startFromLastPage: viewModel.shouldStartFromLastPage,
                isCurrent: true
            )

            // Mark all others as not current
            for i in chapterViews.indices {
                chapterViews[i].isCurrent = false
            }

            chapterViews.append(newView)
            cleanupDistantChapters()
        }
    }

    // MARK: - Preloading

    private func startPreloading() async {
        guard performanceLevel != .minimal else { return }

        // Preload next chapter first (higher priority)
        if viewModel.hasNextChapter {
            await preloadChapter(at: viewModel.currentChapterIndex + 1, startFromLastPage: false)
        }

        // Then preload previous chapter (only in full mode, shorter delay)
        if performanceLevel == .full && viewModel.hasPreviousChapter {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms delay
            await preloadChapter(at: viewModel.currentChapterIndex - 1, startFromLastPage: true)
        }
    }

    private func preloadChapter(at index: Int, startFromLastPage: Bool) async {
        LoggingService.shared.debug(.reading, "🔷 [Preload] preloadChapter - index:\(index), startFromLastPage:\(startFromLastPage)", component: "PagedWebViewContainer")

        // Check if already loaded
        if chapterViews.contains(where: { $0.chapterIndex == index }) {
            LoggingService.shared.debug(.reading, "🔷 [Preload] Chapter \(index) already loaded, skipping", component: "PagedWebViewContainer")
            return
        }

        // Load chapter content
        if let content = await viewModel.loadChapterContent(at: index) {
            await MainActor.run {
                let offset: CGFloat = index < viewModel.currentChapterIndex ? -screenWidth : screenWidth

                let newView = ChapterViewState(
                    id: content.id,
                    chapterIndex: index,
                    content: content,
                    offset: offset,
                    startFromLastPage: startFromLastPage,
                    isCurrent: false
                )

                chapterViews.append(newView)
                LoggingService.shared.debug(.reading, "🔷 [Preload] Added chapter \(index), id=\(content.id.prefix(8)), offset=\(offset)", component: "PagedWebViewContainer")

                cleanupDistantChapters()
            }
        } else {
            LoggingService.shared.debug(.reading, "🔷 [Preload] Failed to load chapter \(index)", component: "PagedWebViewContainer")
        }
    }

    /// Remove chapters that are more than 1 away from current
    private func cleanupDistantChapters() {
        let currentIndex = viewModel.currentChapterIndex
        chapterViews.removeAll { view in
            let distance = abs(view.chapterIndex - currentIndex)
            if distance > 1 {
                LoggingService.shared.debug(.reading, "🗑️ [Cleanup] Removing chapter \(view.chapterIndex) (distance=\(distance))", component: "PagedWebViewContainer")
                return true
            }
            return false
        }
    }

    // MARK: - Navigation

    private func handleReachChapterStart() {
        LoggingService.shared.debug(.reading, "🔶 [ChapterNav] handleReachChapterStart - hasPrev:\(viewModel.hasPreviousChapter), isTransitioning:\(isTransitioning)", component: "PagedWebViewContainer")
        guard viewModel.hasPreviousChapter else {
            LoggingService.shared.debug(.reading, "🔶 [ChapterNav] No previous chapter, ignoring", component: "PagedWebViewContainer")
            return
        }
        Task {
            await goToPreviousChapter()
        }
    }

    private func handleReachChapterEnd() {
        LoggingService.shared.debug(.reading, "🔶 [ChapterNav] handleReachChapterEnd - hasNext:\(viewModel.hasNextChapter), isTransitioning:\(isTransitioning)", component: "PagedWebViewContainer")
        guard viewModel.hasNextChapter else {
            LoggingService.shared.debug(.reading, "🔶 [ChapterNav] No next chapter, ignoring", component: "PagedWebViewContainer")
            return
        }
        Task {
            await goToNextChapter()
        }
    }

    private func goToNextChapter() async {
        guard !isTransitioning else {
            LoggingService.shared.debug(.reading, "🟡 [GoNext] Already transitioning, skipping", component: "PagedWebViewContainer")
            return
        }

        let nextIndex = viewModel.currentChapterIndex + 1
        LoggingService.shared.debug(.reading, "🟡 [GoNext] ========== START ==========", component: "PagedWebViewContainer")
        LoggingService.shared.debug(.reading, "🟡 [GoNext] Current: \(viewModel.currentChapterIndex), Next: \(nextIndex)", component: "PagedWebViewContainer")

        // Check if next chapter is preloaded and ready
        guard let nextView = chapterViews.first(where: { $0.chapterIndex == nextIndex }),
              nextView.isReady else {
            LoggingService.shared.debug(.reading, "🟡 [GoNext] Next chapter NOT ready, falling back to loading", component: "PagedWebViewContainer")
            await MainActor.run {
                viewModel.isLoading = true
            }
            await viewModel.goToNextChapter()
            return
        }

        LoggingService.shared.debug(.reading, "🟡 [GoNext] Next chapter IS ready, proceeding with animation", component: "PagedWebViewContainer")

        await MainActor.run {
            isTransitioning = true
            isInternalNavigation = true  // Mark as internal navigation

            // Animate offset changes
            withAnimation(.easeInOut(duration: 0.25)) {
                for i in chapterViews.indices {
                    chapterViews[i].offset -= screenWidth
                }
            }

            // Use DispatchQueue to sync with animation completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                // Update current chapter
                viewModel.currentChapterIndex = nextIndex
                viewModel.shouldStartFromLastPage = false

                // Update isCurrent flags
                for i in chapterViews.indices {
                    chapterViews[i].isCurrent = (chapterViews[i].chapterIndex == nextIndex)
                    // Update startFromLastPage for chapters that are now "previous"
                    if chapterViews[i].chapterIndex < nextIndex {
                        chapterViews[i].startFromLastPage = true
                    }
                }

                isTransitioning = false
                isInternalNavigation = false  // Reset flag
                LoggingService.shared.debug(.reading, "🟡 [GoNext] ========== END ==========", component: "PagedWebViewContainer")

                // Cleanup and preload
                cleanupDistantChapters()
                Task {
                    await preloadChapter(at: nextIndex + 1, startFromLastPage: false)
                }
            }
        }
    }

    private func goToPreviousChapter() async {
        guard !isTransitioning else {
            LoggingService.shared.debug(.reading, "🟠 [GoPrev] Already transitioning, skipping", component: "PagedWebViewContainer")
            return
        }

        let prevIndex = viewModel.currentChapterIndex - 1
        LoggingService.shared.debug(.reading, "🟠 [GoPrev] ========== START ==========", component: "PagedWebViewContainer")
        LoggingService.shared.debug(.reading, "🟠 [GoPrev] Current: \(viewModel.currentChapterIndex), Prev: \(prevIndex)", component: "PagedWebViewContainer")

        // Check if previous chapter is preloaded and ready
        guard let prevView = chapterViews.first(where: { $0.chapterIndex == prevIndex }),
              prevView.isReady else {
            LoggingService.shared.debug(.reading, "🟠 [GoPrev] Previous chapter NOT ready, falling back to loading", component: "PagedWebViewContainer")
            await MainActor.run {
                viewModel.isLoading = true
            }
            await viewModel.goToPreviousChapter(toLastPage: true)
            return
        }

        LoggingService.shared.debug(.reading, "🟠 [GoPrev] Previous chapter IS ready, proceeding with animation", component: "PagedWebViewContainer")

        await MainActor.run {
            isTransitioning = true
            isInternalNavigation = true  // Mark as internal navigation

            // Animate offset changes
            withAnimation(.easeInOut(duration: 0.25)) {
                for i in chapterViews.indices {
                    chapterViews[i].offset += screenWidth
                }
            }

            // Use DispatchQueue to sync with animation completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                // Update current chapter
                viewModel.currentChapterIndex = prevIndex
                viewModel.shouldStartFromLastPage = true

                // Update isCurrent flags
                for i in chapterViews.indices {
                    chapterViews[i].isCurrent = (chapterViews[i].chapterIndex == prevIndex)
                    // Update startFromLastPage for chapters that are now "next"
                    if chapterViews[i].chapterIndex > prevIndex {
                        chapterViews[i].startFromLastPage = false
                    }
                }

                isTransitioning = false
                isInternalNavigation = false  // Reset flag
                LoggingService.shared.debug(.reading, "🟠 [GoPrev] ========== END ==========", component: "PagedWebViewContainer")

                // Cleanup and preload
                cleanupDistantChapters()
                Task {
                    await preloadChapter(at: prevIndex - 1, startFromLastPage: true)
                }
            }
        }
    }

    private func handleExternalChapterChange(newIndex: Int) {
        // Skip if this is an internal navigation (triggered by goToNextChapter/goToPreviousChapter)
        if isInternalNavigation {
            LoggingService.shared.debug(.reading, "🔵 [External] Skipping - internal navigation in progress", component: "PagedWebViewContainer")
            return
        }

        // Check if we already have this chapter as current
        if let currentView = chapterViews.first(where: { $0.isCurrent }),
           currentView.chapterIndex == newIndex {
            return
        }

        LoggingService.shared.debug(.reading, "🔴 [External] Chapter changed externally to \(newIndex)", component: "PagedWebViewContainer")

        // Clear all views - will be rebuilt when content loads
        chapterViews.removeAll()
    }

    // MARK: - Performance

    private func evaluatePerformanceLevel() {
        if isLowPowerModeEnabled {
            performanceLevel = .minimal
            return
        }

        let memoryGB = availableMemoryMB / 1024
        if memoryGB >= 3.0 {
            performanceLevel = .full
        } else if memoryGB >= 2.0 {
            performanceLevel = .medium
        } else {
            performanceLevel = .minimal
        }
    }

    private func checkProgressAndPreload(progress: Double) {
        guard abs(progress - lastProgressCheck) > 0.05 else { return }
        lastProgressCheck = progress

        if progress > 0.8 && viewModel.hasNextChapter {
            let nextIndex = viewModel.currentChapterIndex + 1
            if !chapterViews.contains(where: { $0.chapterIndex == nextIndex && $0.isReady }) {
                Task {
                    await preloadChapter(at: nextIndex, startFromLastPage: false)
                }
            }
        }
    }
}
