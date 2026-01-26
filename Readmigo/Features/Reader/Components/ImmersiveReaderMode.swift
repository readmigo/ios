import SwiftUI
import Combine

// MARK: - Immersive Reader Mode

struct ImmersiveReaderMode: View {
    @Binding var isImmersive: Bool
    @Binding var content: String
    @Binding var currentChapter: Int
    let totalChapters: Int
    let themeManager: ThemeManager
    let onPreviousChapter: () -> Void
    let onNextChapter: () -> Void
    let onExit: () -> Void

    @State private var controlsOpacity: Double = 0
    @State private var lastTapTime: Date = .distantPast
    @State private var showQuickSettings = false
    @State private var scrollPosition: CGFloat = 0
    @State private var hideTimer: Timer?
    @State private var brightness: CGFloat = UIScreen.main.brightness
    @State private var originalBrightness: CGFloat = UIScreen.main.brightness

    @GestureState private var magnification: CGFloat = 1.0
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    // Swipe gesture state
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipingForChapter = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                themeManager.readerTheme.backgroundColor
                    .ignoresSafeArea()

                // Main scrollable content
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Content
                            Text(content)
                                .font(.system(size: themeManager.fontSize.size * currentScale))
                                .foregroundColor(themeManager.readerTheme.textColor)
                                .lineSpacing(themeManager.lineSpacing.value * currentScale)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 60)
                                .id("content")
                        }
                        .frame(minHeight: geometry.size.height)
                        .offset(x: swipeOffset)
                    }
                    .simultaneousGesture(
                        MagnificationGesture()
                            .updating($magnification) { value, state, _ in
                                state = value
                            }
                            .onEnded { value in
                                let newScale = lastScale * value
                                currentScale = min(max(0.8, newScale), 2.0)
                                lastScale = currentScale
                            }
                    )
                }

                // Touch areas overlay
                touchAreasOverlay(geometry: geometry)

                // Top gradient for visual comfort
                VStack {
                    LinearGradient(
                        colors: [
                            themeManager.readerTheme.backgroundColor,
                            themeManager.readerTheme.backgroundColor.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .opacity(0.8)

                    Spacer()

                    LinearGradient(
                        colors: [
                            themeManager.readerTheme.backgroundColor.opacity(0),
                            themeManager.readerTheme.backgroundColor
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .opacity(0.8)
                }
                .allowsHitTesting(false)

                // Controls overlay
                if controlsOpacity > 0 {
                    controlsOverlay(geometry: geometry)
                        .opacity(controlsOpacity)
                        .transition(.opacity)
                }

                // Quick settings panel
                if showQuickSettings {
                    quickSettingsPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Chapter swipe indicator
                if abs(swipeOffset) > 50 {
                    chapterSwipeIndicator(geometry: geometry)
                }
            }
        }
        .statusBar(hidden: controlsOpacity == 0)
        .gesture(edgeSwipeGesture)
        .onAppear {
            originalBrightness = UIScreen.main.brightness
        }
        .onDisappear {
            UIScreen.main.brightness = originalBrightness
        }
    }

    // MARK: - Touch Areas Overlay

    private func touchAreasOverlay(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left edge - Previous chapter/page
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geometry.size.width * 0.15)
                .onTapGesture {
                    handleEdgeTap(.leading)
                }

            // Center - Toggle controls
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    handleCenterTap()
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    withAnimation {
                        showQuickSettings = true
                    }
                }

            // Right edge - Next chapter/page
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geometry.size.width * 0.15)
                .onTapGesture {
                    handleEdgeTap(.trailing)
                }
        }
    }

    // MARK: - Controls Overlay

    private func controlsOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    withAnimation(.spring()) {
                        onExit()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                }

                Spacer()

                // Chapter indicator
                Text("Chapter \(currentChapter + 1) of \(totalChapters)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .shadow(radius: 4)

                Spacer()

                Button {
                    withAnimation(.spring()) {
                        showQuickSettings.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()

            // Bottom progress bar
            VStack(spacing: 12) {
                // Chapter navigation
                HStack(spacing: 40) {
                    Button {
                        onPreviousChapter()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Previous")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                    }
                    .disabled(currentChapter == 0)
                    .opacity(currentChapter == 0 ? 0.3 : 1)

                    Button {
                        onNextChapter()
                    } label: {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                    }
                    .disabled(currentChapter >= totalChapters - 1)
                    .opacity(currentChapter >= totalChapters - 1 ? 0.3 : 1)
                }

                // Progress indicator
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))

                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * CGFloat(currentChapter + 1) / CGFloat(totalChapters))
                    }
                }
                .frame(height: 4)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Quick Settings Panel

    private var quickSettingsPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Drag handle
                Capsule()
                    .fill(Color.gray)
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)

                // Brightness control
                VStack(alignment: .leading, spacing: 8) {
                    Label("Brightness", systemImage: "sun.max")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "sun.min")
                            .foregroundColor(.secondary)
                        Slider(value: $brightness, in: 0...1)
                            .tint(.orange)
                            .onChange(of: brightness) { _, newValue in
                                UIScreen.main.brightness = newValue
                            }
                        Image(systemName: "sun.max")
                            .foregroundColor(.secondary)
                    }
                }

                // Font size control
                VStack(alignment: .leading, spacing: 8) {
                    Label("Text Size", systemImage: "textformat.size")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("A")
                            .font(.caption)
                        Slider(value: $currentScale, in: 0.8...2.0)
                            .tint(.blue)
                        Text("A")
                            .font(.title)
                    }
                }

                // Theme selection
                VStack(alignment: .leading, spacing: 8) {
                    Label("Theme", systemImage: "paintbrush")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ForEach(ReaderTheme.allCases, id: \.self) { theme in
                            Circle()
                                .fill(theme.backgroundColor)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(themeManager.readerTheme == theme ? Color.accentColor : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    themeManager.readerTheme = theme
                                }
                        }
                    }
                }

                // Done button
                Button {
                    withAnimation(.spring()) {
                        showQuickSettings = false
                    }
                } label: {
                    Text("Done")
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
            .cornerRadius(20, corners: [.topLeft, .topRight])
        }
        .background(
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) {
                        showQuickSettings = false
                    }
                }
        )
    }

    // MARK: - Chapter Swipe Indicator

    private func chapterSwipeIndicator(geometry: GeometryProxy) -> some View {
        HStack {
            if swipeOffset > 50 && currentChapter > 0 {
                VStack {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.largeTitle)
                    Text("Previous Chapter")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
            }

            Spacer()

            if swipeOffset < -50 && currentChapter < totalChapters - 1 {
                VStack {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.largeTitle)
                    Text("Next Chapter")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Gestures

    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onChanged { value in
                // Only trigger on horizontal swipes
                if abs(value.translation.width) > abs(value.translation.height) {
                    swipeOffset = value.translation.width * 0.3
                    isSwipingForChapter = true
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 100
                let velocity = value.predictedEndTranslation.width - value.translation.width

                withAnimation(.spring()) {
                    if value.translation.width > threshold || velocity > 300 {
                        if currentChapter > 0 {
                            onPreviousChapter()
                        }
                    } else if value.translation.width < -threshold || velocity < -300 {
                        if currentChapter < totalChapters - 1 {
                            onNextChapter()
                        }
                    }
                    swipeOffset = 0
                    isSwipingForChapter = false
                }
            }
    }

    // MARK: - Tap Handlers

    private func handleCenterTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)

        if timeSinceLastTap < 0.3 {
            // Double tap - toggle immersive mode
            withAnimation(.spring()) {
                onExit()
            }
        } else {
            // Single tap - toggle controls
            withAnimation(.easeInOut(duration: 0.25)) {
                controlsOpacity = controlsOpacity > 0 ? 0 : 1
            }

            // Auto-hide controls after delay
            hideTimer?.invalidate()
            if controlsOpacity > 0 {
                hideTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        controlsOpacity = 0
                    }
                }
            }
        }

        lastTapTime = now
    }

    private func handleEdgeTap(_ edge: Edge) {
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        switch edge {
        case .leading:
            if currentChapter > 0 {
                onPreviousChapter()
            }
        case .trailing:
            if currentChapter < totalChapters - 1 {
                onNextChapter()
            }
        default:
            break
        }
    }
}

// MARK: - Focus Reading Mode

struct FocusReadingMode: View {
    let paragraphs: [String]
    @Binding var currentParagraphIndex: Int
    let themeManager: ThemeManager

    @State private var autoScrollEnabled = false
    @State private var scrollSpeed: Double = 1.0
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            Text(paragraph)
                                .font(.system(size: themeManager.fontSize.size))
                                .foregroundColor(
                                    index == currentParagraphIndex
                                        ? themeManager.readerTheme.textColor
                                        : themeManager.readerTheme.textColor.opacity(0.3)
                                )
                                .lineSpacing(themeManager.lineSpacing.value)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            index == currentParagraphIndex
                                                ? Color.yellow.opacity(0.1)
                                                : Color.clear
                                        )
                                )
                                .id(index)
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        currentParagraphIndex = index
                                    }
                                }
                        }
                    }
                    .padding(.vertical, geometry.size.height / 3)
                }
                .onChange(of: currentParagraphIndex) { _, newValue in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    if value.translation.height < -50 {
                        currentParagraphIndex = min(currentParagraphIndex + 1, paragraphs.count - 1)
                    } else if value.translation.height > 50 {
                        currentParagraphIndex = max(currentParagraphIndex - 1, 0)
                    }
                }
        )
    }
}

// MARK: - Zen Reading Mode (Distraction-free)

struct ZenReadingMode: View {
    let content: String
    let themeManager: ThemeManager

    @State private var showSingleSentence = true
    @State private var currentSentenceIndex = 0
    @State private var sentences: [String] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Pure background
                themeManager.readerTheme.backgroundColor
                    .ignoresSafeArea()

                if showSingleSentence {
                    // Single sentence mode
                    VStack {
                        Spacer()

                        Text(sentences.indices.contains(currentSentenceIndex) ? sentences[currentSentenceIndex] : "")
                            .font(.system(size: 24, weight: .medium, design: .serif))
                            .foregroundColor(themeManager.readerTheme.textColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .animation(.easeInOut, value: currentSentenceIndex)

                        Spacer()

                        // Minimal progress dots
                        HStack(spacing: 4) {
                            ForEach(0..<min(sentences.count, 20), id: \.self) { index in
                                Circle()
                                    .fill(
                                        index == currentSentenceIndex
                                            ? themeManager.readerTheme.textColor
                                            : themeManager.readerTheme.textColor.opacity(0.2)
                                    )
                                    .frame(width: index == currentSentenceIndex ? 8 : 4,
                                           height: index == currentSentenceIndex ? 8 : 4)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        TapGesture()
                            .onEnded { _ in
                                if currentSentenceIndex < sentences.count - 1 {
                                    withAnimation {
                                        currentSentenceIndex += 1
                                    }
                                }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    if currentSentenceIndex < sentences.count - 1 {
                                        currentSentenceIndex += 1
                                    }
                                } else if value.translation.width > 50 {
                                    if currentSentenceIndex > 0 {
                                        currentSentenceIndex -= 1
                                    }
                                }
                            }
                    )
                }
            }
        }
        .onAppear {
            sentences = splitIntoSentences(content)
        }
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { substring, _, _, _ in
            if let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines),
               !sentence.isEmpty {
                sentences.append(sentence)
            }
        }
        return sentences
    }
}
